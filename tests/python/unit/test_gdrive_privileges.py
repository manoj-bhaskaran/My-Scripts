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
from gdrive_privileges import DrivePrivilegeChecker


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
