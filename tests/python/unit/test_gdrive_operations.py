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


def test_recover_file_proceeds_when_overwrite_and_already_processed():
    ops = _make_ops()
    ops.args.overwrite = True
    ops.state_manager._is_processed.return_value = True

    service = MagicMock()
    ops.auth._get_service.return_value = service
    service.files.return_value.update.return_value = MagicMock()

    item = _item()
    ok = ops._recover_file(item)

    assert ok is True
    assert item.status == "recovered"
    assert ops.stats["recovered"] == 1
    assert ops.stats["skipped"] == 0


def test_process_item_skips_when_already_processed_no_overwrite():
    ops = _make_ops()
    ops.state_manager._is_processed.return_value = True
    item = _item()

    ok = ops._process_item(item)

    assert ok is True
    ops.downloader.download.assert_not_called()
    ops.state_manager._mark_processed.assert_not_called()


def test_process_item_proceeds_when_overwrite_and_already_processed():
    ops = _make_ops()
    ops.args.overwrite = True
    ops.state_manager._is_processed.return_value = True

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


def test_write_failed_file_appends_target_path(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = "/local/downloads/file.txt"
    ops._write_failed_file(item)

    assert failed_file.read_text() == "/local/downloads/file.txt\n"


def test_write_failed_file_falls_back_to_name_when_no_target_path(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = ""
    ops._write_failed_file(item)

    assert failed_file.read_text() == "file.txt\n"


def test_write_failed_file_creates_parent_dirs(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "nested" / "dir" / "failed.txt"
    ops._failed_file_path = str(failed_file)

    item = _item()
    item.target_path = "/a/path.jpg"
    ops._write_failed_file(item)

    assert failed_file.exists()
    assert failed_file.read_text() == "/a/path.jpg\n"


def test_write_failed_file_appends_multiple_entries(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    ops._failed_file_path = str(failed_file)

    for i in range(3):
        item = _item()
        item.target_path = f"/path/file{i}.txt"
        ops._write_failed_file(item)

    lines = failed_file.read_text().splitlines()
    assert lines == ["/path/file0.txt", "/path/file1.txt", "/path/file2.txt"]


def test_write_failed_file_noop_when_path_not_set(tmp_path):
    ops = _make_ops()
    ops._failed_file_path = ""

    item = _item()
    item.target_path = "/some/path.txt"
    ops._write_failed_file(item)  # should not raise or create any file


def test_clear_failed_files_truncates_file(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "failed.txt"
    failed_file.write_text("/old/path.txt\n")
    ops._failed_file_path = str(failed_file)

    ops._clear_failed_files()

    assert failed_file.read_text() == ""


def test_clear_failed_files_creates_parent_dirs(tmp_path):
    ops = _make_ops()
    failed_file = tmp_path / "new" / "dir" / "failed.txt"
    ops._failed_file_path = str(failed_file)

    ops._clear_failed_files()

    assert failed_file.exists()
    assert failed_file.read_text() == ""


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
    assert failed_file.read_text() == "/downloads/file.txt\n"


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
