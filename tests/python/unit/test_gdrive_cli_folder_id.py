"""Unit tests for --folder-id CLI validation in gdrive_cli."""

import sys
from pathlib import Path
from types import ModuleType, SimpleNamespace
from unittest.mock import MagicMock

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

# dateutil stub
if "dateutil" not in sys.modules:
    _dateutil = ModuleType("dateutil")
    _dateutil_parser = ModuleType("dateutil.parser")
    _dateutil_parser.parse = lambda v: v
    _dateutil.parser = _dateutil_parser
    sys.modules["dateutil"] = _dateutil
    sys.modules["dateutil.parser"] = _dateutil_parser

# googleapiclient stubs (unconditional, same pattern as existing tests)
_googleapiclient = ModuleType("googleapiclient")
_errors = ModuleType("googleapiclient.errors")
_discovery = ModuleType("googleapiclient.discovery")
_http = ModuleType("googleapiclient.http")


class _HttpError(Exception):
    def __init__(self, resp=None, content=b"", *args, **kwargs):
        super().__init__(*args)
        self.resp = resp
        self.content = content


_errors.HttpError = _HttpError
_discovery.build = lambda *a, **kw: None
_http.MediaIoBaseDownload = type("MediaIoBaseDownload", (), {"__init__": lambda s, *a, **kw: None})
_googleapiclient.errors = _errors
_googleapiclient.discovery = _discovery
_googleapiclient.http = _http
sys.modules["googleapiclient"] = _googleapiclient
sys.modules["googleapiclient.errors"] = _errors
sys.modules["googleapiclient.discovery"] = _discovery
sys.modules["googleapiclient.http"] = _http

# gdrive_cli imports gdrive_recover which imports DriveAuthManager; stub it out
sys.modules.setdefault("gdrive_auth", MagicMock())

from gdrive_cli import _validate_folder_id_args  # noqa: E402


def _args(**kwargs):
    defaults = dict(folder_id=None, file_ids=None, mode="recover_and_download", no_emoji=True)
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# _validate_folder_id_args
# ---------------------------------------------------------------------------

def test_no_folder_id_always_passes():
    ok, code = _validate_folder_id_args(_args(folder_id=None))
    assert ok and code == 0


def test_folder_id_with_file_ids_rejected():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", file_ids=["id1", "id2"]))
    assert not ok and code == 2


def test_folder_id_with_recover_only_rejected():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", mode="recover_only"))
    assert not ok and code == 2


def test_folder_id_with_recover_and_download_passes():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", mode="recover_and_download"))
    assert ok and code == 0


def test_folder_id_with_dry_run_passes():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", mode="dry_run"))
    assert ok and code == 0
