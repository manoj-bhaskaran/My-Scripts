import csv
from pathlib import Path
from threading import Lock
from types import SimpleNamespace
from unittest.mock import MagicMock

import sys

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_models import RecoveryItem
from gdrive_operations import DriveOperations


def _make_ops():
    args = SimpleNamespace()
    logger = MagicMock()
    auth = MagicMock()
    downloader = MagicMock()
    state_manager = MagicMock()
    state_manager._is_processed.return_value = False
    stats = {
        "recovered": 0,
        "errors": 0,
        "skipped": 0,
        "post_restore_retained": 0,
        "post_restore_trashed": 0,
        "post_restore_deleted": 0,
    }
    return DriveOperations(args, logger, auth, downloader, state_manager, stats, Lock())


def _item(post_restore_action="retain"):
    return RecoveryItem(
        id="id-1",
        name="file.txt",
        size=1,
        mime_type="text/plain",
        created_time="",
        will_recover=True,
        will_download=False,
        post_restore_action=post_restore_action,
    )


def test_recover_file_success(monkeypatch):
    ops = _make_ops()
    item = _item()

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    ok = ops._recover_file(item)

    assert ok is True
    assert item.status == "recovered"
    assert ops.stats["recovered"] == 1


def test_recover_file_terminal_error(monkeypatch):
    ops = _make_ops()
    item = _item()

    monkeypatch.setattr(
        "gdrive_operations.with_retries",
        lambda *args, **kwargs: (
            None,
            "files.update(fileId=id-1, trashed=False) failed: HTTP 404: no",
            404,
        ),
    )

    ok = ops._recover_file(item)

    assert ok is False
    assert item.status == "failed"
    assert "HTTP 404" in (item.error_message or "")
    assert ops.stats["errors"] == 1


def test_apply_post_restore_policy_retain():
    ops = _make_ops()
    item = _item(post_restore_action="retain")

    ok = ops._apply_post_restore_policy(item)

    assert ok is True
    assert ops.stats["post_restore_retained"] == 1


def test_apply_post_restore_policy_trash_success():
    ops = _make_ops()
    item = _item(post_restore_action="trash")

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    ok = ops._apply_post_restore_policy(item)

    assert ok is True
    assert ops.stats["post_restore_trashed"] == 1


def test_apply_post_restore_policy_terminal_failure(monkeypatch):
    ops = _make_ops()
    item = _item(post_restore_action="delete")

    monkeypatch.setattr(
        "gdrive_operations.with_retries",
        lambda *args, **kwargs: (
            None,
            "files.delete(fileId=id-1) failed: HTTP 403: forbidden",
            403,
        ),
    )

    ok = ops._apply_post_restore_policy(item)

    assert ok is False
    ops.logger.error.assert_called()


def test_recover_file_skips_when_already_processed_no_overwrite():
    ops = _make_ops()
    ops.state_manager._is_processed.return_value = True
    # overwrite not set on args → defaults to False via getattr
    item = _item()

    ok = ops._recover_file(item)

    assert ok is True
    assert ops.stats["skipped"] == 1
    assert ops.stats["recovered"] == 0


def test_recover_file_proceeds_when_processed_items_cleared():
    """After issue #1028, --overwrite no longer gates the _is_processed check.

    The bypass is now achieved by clearing `processed_items` upfront in
    `_prepare_recovery` (via `_reset_state` on --fresh-run or
    `_clear_processed_items` on the --overwrite deprecation shim). Once
    cleared, `_is_processed` naturally returns False and the operation
    proceeds.
    """
    ops = _make_ops()
    # Simulate state cleared by _prepare_recovery: _is_processed returns False.
    ops.state_manager._is_processed.return_value = False

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    item = _item()
    ok = ops._recover_file(item)

    assert ok is True
    assert item.status == "recovered"
    assert ops.stats["recovered"] == 1
    assert ops.stats["skipped"] == 0


def test_process_item_skips_when_already_processed():
    """`_is_processed` short-circuit is no longer gated on args.overwrite."""
    ops = _make_ops()
    ops.state_manager._is_processed.return_value = True
    item = _item()

    ok = ops._process_item(item)

    assert ok is True
    ops.downloader.download.assert_not_called()
    ops.state_manager._mark_processed.assert_not_called()


def test_process_item_overwrite_does_not_bypass_short_circuit():
    """Setting args.overwrite alone does NOT bypass `_is_processed` anymore.

    State must be cleared upstream by `_prepare_recovery` for the item to
    be reprocessed. This test pins the new contract.
    """
    ops = _make_ops()
    ops.args.overwrite = True
    ops.state_manager._is_processed.return_value = True
    item = _item()

    ok = ops._process_item(item)

    assert ok is True
    ops.downloader.download.assert_not_called()
    ops.state_manager._mark_processed.assert_not_called()


def test_process_item_proceeds_when_processed_items_cleared():
    """Once `_prepare_recovery` clears `processed_items`, items run as new."""
    ops = _make_ops()
    ops.state_manager._is_processed.return_value = False

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    item = _item()
    item.will_recover = True
    item.will_download = False

    ok = ops._process_item(item)

    assert ok is True
    assert item.status == "recovered"
    ops.state_manager._mark_processed.assert_called_once_with(item.id)


# ---------------------------------------------------------------------------
# Failed-file tracking
# ---------------------------------------------------------------------------


def _parse_csv_rows(path):
    """Return (header, list-of-row-dicts) from a CSV file."""
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)
    return reader.fieldnames, rows


def test_write_failed_file_appends_target_path(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = "/local/downloads/file.txt"
    item.source_folder_id = "folder-abc"
    ops._write_failed_file(item)

    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1
    assert rows[0]["source_folder_id"] == "folder-abc"
    assert rows[0]["file_id"] == item.id
    assert rows[0]["target_path"] == "/local/downloads/file.txt"


def test_write_failed_file_falls_back_to_name_when_no_target_path(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = ""
    ops._write_failed_file(item)

    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1
    assert rows[0]["target_path"] == "file.txt"


def test_write_failed_file_creates_parent_dirs(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "nested" / "dir" / "failed.csv"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = "/a/path.jpg"
    ops._write_failed_file(item)

    assert failed_file.exists()
    _, rows = _parse_csv_rows(str(failed_file))
    assert rows[0]["target_path"] == "/a/path.jpg"


def test_write_failed_file_appends_multiple_entries(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    ops._failed_file_path = str(failed_file)

    for i in range(3):
        item = _item()
        item.id = f"id-{i}"
        item.target_path = f"/path/file{i}.txt"
        ops._write_failed_file(item)

    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 3
    assert [r["target_path"] for r in rows] == [
        "/path/file0.txt",
        "/path/file1.txt",
        "/path/file2.txt",
    ]


def test_write_failed_file_writes_header_once_for_multiple_entries(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    ops._failed_file_path = str(failed_file)

    for i in range(2):
        item = _item()
        item.id = f"id-{i}"
        item.target_path = f"/path/file{i}.txt"
        ops._write_failed_file(item)

    lines = failed_file.read_text(encoding="utf-8").splitlines()
    header_count = sum(1 for ln in lines if ln.startswith("source_folder_id"))
    assert header_count == 1


def test_write_failed_file_noop_when_path_not_set(tmp_path):
    ops = _make_ops()
    ops._failed_file_path = ""

    item = _item()
    item.target_path = "/some/path.txt"
    ops._write_failed_file(item)  # should not raise or create any file


def test_clear_failed_files_writes_header(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    failed_file.write_text("stale content\n", encoding="utf-8")
    ops._failed_file_path = str(failed_file)

    ops._clear_failed_files()

    assert failed_file.exists()
    lines = failed_file.read_text(encoding="utf-8").splitlines()
    assert lines == ["source_folder_id,file_id,target_path"]


def test_clear_failed_files_creates_parent_dirs(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "new" / "dir" / "failed.csv"
    ops._failed_file_path = str(failed_file)

    ops._clear_failed_files()

    assert failed_file.exists()
    lines = failed_file.read_text(encoding="utf-8").splitlines()
    assert lines == ["source_folder_id,file_id,target_path"]


def test_clear_failed_files_noop_when_path_not_set():
    ops = _make_ops()
    ops._failed_file_path = ""
    ops._clear_failed_files()  # should not raise


def test_process_item_writes_failed_file_on_failure(tmp_path, monkeypatch):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    monkeypatch.setattr(
        "gdrive_operations.with_retries",
        lambda *args, **kwargs: (None, "HTTP 404: not found", 404),
    )

    item = _item()
    item.target_path = "/downloads/file.txt"
    ok = ops._process_item(item)

    assert ok is False
    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1 and rows[0]["target_path"] == "/downloads/file.txt"
    # Failed items must NOT be marked processed in state.
    ops.state_manager._mark_processed.assert_not_called()


def test_process_item_does_not_write_failed_file_on_success(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    item = _item()
    ok = ops._process_item(item)

    assert ok is True
    assert not failed_file.exists(), "failed-file should not be created on success"
    ops.state_manager._mark_processed.assert_called_once_with(item.id)


def test_process_item_does_not_mark_processed_when_recover_fails(monkeypatch):
    """Issue #1027: failed recover must not be recorded as processed."""
    ops = _make_ops()

    monkeypatch.setattr(
        "gdrive_operations.with_retries",
        lambda *args, **kwargs: (None, "HTTP 404: not found", 404),
    )

    item = _item()
    item.will_recover = True
    item.will_download = False

    ok = ops._process_item(item)

    assert ok is False
    ops.state_manager._mark_processed.assert_not_called()


def test_process_item_does_not_mark_processed_when_download_fails(tmp_path):
    """Issue #1027: a failed download produces a failed-file row but no processed_items entry."""
    ops = _make_ops()
    failed_file = tmp_path / "failed.csv"
    ops._failed_file_path = str(failed_file)

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()
    ops.downloader.download.return_value = False

    item = _item()
    item.will_recover = True
    item.will_download = True
    item.target_path = "/downloads/file.txt"

    ok = ops._process_item(item)

    assert ok is False
    ops.state_manager._mark_processed.assert_not_called()
    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1 and rows[0]["file_id"] == item.id


def test_process_item_writes_failed_file_on_post_restore_failure(tmp_path, monkeypatch):
    """A failed post-restore action (trash/delete) propagates into success=False."""
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    # Recovery succeeds
    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    # Download succeeds and sets status (mirrors real DriveDownloader behaviour)
    def _mock_download(item):
        item.status = "downloaded"
        return True

    ops.downloader.download.side_effect = _mock_download

    # Post-restore fails (403 on delete, for example)
    ops._apply_post_restore_policy = MagicMock(return_value=False)

    item = _item(post_restore_action="delete")
    item.will_recover = True
    item.will_download = True
    item.target_path = "/downloads/file.txt"

    ok = ops._process_item(item)

    assert ok is False
    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1 and rows[0]["target_path"] == "/downloads/file.txt"


# ---------------------------------------------------------------------------
# _do_post_restore_action branches
# ---------------------------------------------------------------------------


def test_do_post_restore_action_deleted():
    ops = _make_ops()
    service = MagicMock()
    item = _item()
    ops._do_post_restore_action(service, item, "deleted")
    service.files.return_value.delete.assert_called_once_with(fileId=item.id)


def test_do_post_restore_action_returns_none_for_unknown_action():
    ops = _make_ops()
    service = MagicMock()
    item = _item()
    result = ops._do_post_restore_action(service, item, "unknown_action")
    assert result is None


# ---------------------------------------------------------------------------
# _log_post_restore_success deleted branch
# ---------------------------------------------------------------------------


def test_log_post_restore_success_deleted():
    ops = _make_ops()
    item = _item()
    ops._log_post_restore_success(item, "deleted")
    assert ops.stats["post_restore_deleted"] == 1
    ops.logger.info.assert_called_once()


# ---------------------------------------------------------------------------
# _handle_post_restore_retry
# ---------------------------------------------------------------------------


def test_handle_post_restore_retry_logs_warning():
    ops = _make_ops()
    item = _item()
    ops._handle_post_restore_retry(item, 429, 0)
    ops.logger.warning.assert_called_once()


# ---------------------------------------------------------------------------
# _extract_http_error_detail — no ": " separator
# ---------------------------------------------------------------------------


def test_extract_http_error_detail_no_separator():
    ops = _make_ops()
    result = ops._extract_http_error_detail("plain error message")
    assert result == "plain error message"


# ---------------------------------------------------------------------------
# _log_post_restore_final_error
# ---------------------------------------------------------------------------


def test_log_post_restore_final_error_logs_error():
    ops = _make_ops()
    item = _item()
    ops._log_post_restore_final_error(item, "timed out", "files.delete(fileId=id-1)")
    ops.logger.error.assert_called_once()


# ---------------------------------------------------------------------------
# _apply_post_restore_policy — non-terminal failure (covers else branch)
# ---------------------------------------------------------------------------


def test_apply_post_restore_policy_non_terminal_failure(monkeypatch):
    ops = _make_ops()
    item = _item(post_restore_action="delete")

    monkeypatch.setattr(
        "gdrive_operations.with_retries",
        lambda *args, **kwargs: (
            None,
            "files.delete(fileId=id-1) failed: HTTP 500: server error",
            500,
        ),
    )

    ok = ops._apply_post_restore_policy(item)

    assert ok is False
    ops.logger.error.assert_called()


# ---------------------------------------------------------------------------
# _process_item — download failure path
# ---------------------------------------------------------------------------


def test_process_item_download_failure_sets_success_false(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    # Recovery succeeds
    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    # Download fails
    ops.downloader.download.return_value = False

    item = _item()
    item.will_recover = True
    item.will_download = True
    item.target_path = "/downloads/file.txt"

    ok = ops._process_item(item)

    assert ok is False
    _, rows = _parse_csv_rows(str(failed_file))
    assert len(rows) == 1 and rows[0]["target_path"] == "/downloads/file.txt"
