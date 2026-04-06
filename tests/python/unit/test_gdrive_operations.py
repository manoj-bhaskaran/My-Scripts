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
