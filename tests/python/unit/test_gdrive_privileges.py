from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

import sys
from types import ModuleType

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

# Lightweight googleapiclient stub for environments where dependency is absent.
if "googleapiclient" not in sys.modules:
    googleapiclient_module = ModuleType("googleapiclient")
    errors_module = ModuleType("googleapiclient.errors")
    discovery_module = ModuleType("googleapiclient.discovery")
    http_module = ModuleType("googleapiclient.http")

    class HttpError(Exception):
        def __init__(self, resp=None, content=b"", *args, **kwargs):
            super().__init__(*args)
            self.resp = resp
            self.content = content

    errors_module.HttpError = HttpError
    discovery_module.build = lambda *args, **kwargs: None

    class MediaIoBaseDownload:
        def __init__(self, *args, **kwargs):
            pass

    http_module.MediaIoBaseDownload = MediaIoBaseDownload
    googleapiclient_module.errors = errors_module
    googleapiclient_module.discovery = discovery_module
    googleapiclient_module.http = http_module
    sys.modules["googleapiclient"] = googleapiclient_module
    sys.modules["googleapiclient.errors"] = errors_module
    sys.modules["googleapiclient.discovery"] = discovery_module
    sys.modules["googleapiclient.http"] = http_module

from gdrive_models import RecoveryItem
from gdrive_privileges import DrivePrivilegeChecker, HttpError


def _make_checker(tmp_path):
    auth = MagicMock()
    logger = MagicMock()
    execute_fn = MagicMock()
    items = [
        RecoveryItem(
            id="id1",
            name="name1",
            size=100,
            mime_type="text/plain",
            created_time="",
            will_download=True,
        )
    ]
    return DrivePrivilegeChecker(auth, execute_fn, logger, items), auth


def test_check_privileges_success_and_local_writable(tmp_path):
    checker, auth = _make_checker(tmp_path)
    args = SimpleNamespace(download_dir=str(tmp_path))

    service = MagicMock()
    service.files.return_value.list.return_value.execute.return_value = {"files": []}
    auth._get_service.return_value = service

    out = checker._check_privileges(args)

    assert out["drive_access"] is True
    assert out["local_writable"] is True
    assert out["estimated_needed"] == 100


def test_operation_privileges_empty_items():
    checker = DrivePrivilegeChecker(MagicMock(), MagicMock(), MagicMock(), [])
    out = checker._test_operation_privileges([])
    assert out["untrash"]["status"] == "unknown"
    assert out["download"]["status"] == "unknown"


def test_download_privilege_uses_capabilities(tmp_path):
    checker, _ = _make_checker(tmp_path)
    checker._get_file_info = MagicMock(
        return_value={"size": 12, "capabilities": {"canDownload": False}}
    )

    out = checker._check_download_privilege("fid")

    assert out["status"] == "fail"
    assert "download not allowed" in str(out["error"])


def test_get_file_info_handles_http_error(tmp_path):
    checker, auth = _make_checker(tmp_path)

    class FakeHttpError(HttpError):
        def __init__(self):
            self.resp = SimpleNamespace(status=403)
            self.content = b"denied"

    service = MagicMock()
    service.files.return_value.get.return_value = object()
    auth._get_service.return_value = service
    checker._execute = MagicMock(side_effect=FakeHttpError())

    out = checker._get_file_info("fid", "id")

    assert "error" in out
    assert "HTTP 403" in str(out["error"])


def test_get_file_info_handles_io_and_unexpected_error(tmp_path):
    checker, auth = _make_checker(tmp_path)
    service = MagicMock()
    service.files.return_value.get.return_value = object()
    auth._get_service.return_value = service

    checker._execute = MagicMock(side_effect=OSError("disk issue"))
    io_out = checker._get_file_info("fid", "id")
    assert "I/O error" in str(io_out["error"])

    checker._execute = MagicMock(side_effect=RuntimeError("boom"))
    generic_out = checker._get_file_info("fid", "id")
    assert "Unexpected error" in str(generic_out["error"])


def test_untrash_privilege_variants(tmp_path):
    checker, _ = _make_checker(tmp_path)

    checker._get_file_info = MagicMock(return_value={"error": "no access"})
    fail_out = checker._check_untrash_privilege("fid")
    assert fail_out["status"] == "fail"

    checker._get_file_info = MagicMock(return_value={"trashed": False, "capabilities": {}})
    skip_out = checker._check_untrash_privilege("fid")
    assert skip_out["status"] == "skip"

    checker._get_file_info = MagicMock(
        return_value={"trashed": True, "capabilities": {"canUntrash": False}}
    )
    denied_out = checker._check_untrash_privilege("fid")
    assert denied_out["status"] == "fail"

    checker._get_file_info = MagicMock(return_value={"trashed": True, "capabilities": {}})
    fallback_out = checker._check_untrash_privilege("fid")
    assert fallback_out["status"] == "pass"


def test_download_privilege_size_and_fallback(tmp_path):
    checker, _ = _make_checker(tmp_path)

    checker._get_file_info = MagicMock(return_value={"error": "bad"})
    fail_out = checker._check_download_privilege("fid")
    assert fail_out["status"] == "fail"

    checker._get_file_info = MagicMock(return_value={"capabilities": {"canDownload": True}})
    no_size_out = checker._check_download_privilege("fid")
    assert no_size_out["status"] == "fail"

    checker._get_file_info = MagicMock(return_value={"size": 12, "capabilities": {}})
    fallback_out = checker._check_download_privilege("fid")
    assert fallback_out["status"] == "pass"


def test_trash_delete_privilege_branches(tmp_path):
    checker, _ = _make_checker(tmp_path)

    checker._get_file_info = MagicMock(return_value={"error": "bad"})
    trash_out, delete_out = checker._check_trash_delete_privileges("fid", "fail")
    assert trash_out["status"] == "fail"
    assert delete_out["status"] == "fail"

    checker._get_file_info = MagicMock(
        return_value={"capabilities": {"canTrash": True, "canDelete": False}}
    )
    trash_out, delete_out = checker._check_trash_delete_privileges("fid", "pass")
    assert trash_out["status"] == "pass"
    assert delete_out["status"] == "fail"

    checker._get_file_info = MagicMock(return_value={"capabilities": {"canTrash": True}})
    trash_out, delete_out = checker._check_trash_delete_privileges("fid", "pass")
    assert trash_out["status"] == "pass"
    assert delete_out["status"] == "pass"


def test_check_privileges_drive_and_local_errors(tmp_path):
    checker, auth = _make_checker(tmp_path)

    auth._get_service.side_effect = RuntimeError("auth failed")
    out = checker._check_privileges(SimpleNamespace(download_dir=None))
    assert out["drive_access"] is False
    assert "auth failed" in str(out["drive_error"])

    auth._get_service.side_effect = None
    service = MagicMock()
    service.files.return_value.list.return_value.execute.return_value = {"files": []}
    auth._get_service.return_value = service
    bad_args = SimpleNamespace(download_dir=str(tmp_path / "file_as_dir"))
    (tmp_path / "file_as_dir").write_text("x")

    out = checker._check_privileges(bad_args)
    assert out["drive_access"] is True
    assert out["local_writable"] is False
    assert out["local_error"] is not None
