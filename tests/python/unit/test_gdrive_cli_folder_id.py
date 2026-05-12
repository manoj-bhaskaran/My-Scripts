"""Unit tests for --folder-id CLI validation in gdrive_cli."""

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

# Stub gdrive_recover during the gdrive_cli import so that the real
# gdrive_recover → gdrive_download chain is not triggered here.  That chain
# would bind gdrive_download.HttpError to a local stub class, which would
# later mismatch the class registered by test_gdrive_discovery_retry_classification
# and cause test_http_error_during_download to fail.
# We delete the stub afterwards so subsequent tests can import the real module.
sys.modules["gdrive_recover"] = MagicMock()
from gdrive_cli import _validate_folder_id_args  # noqa: E402

del sys.modules["gdrive_recover"]


def _args(**kwargs):
    defaults = dict(
        folder_id=None, file_ids=None, mode="recover_and_download", no_emoji=True
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# _validate_folder_id_args
# ---------------------------------------------------------------------------


def test_no_folder_id_always_passes():
    ok, code = _validate_folder_id_args(_args(folder_id=None))
    assert ok and code == 0


def test_folder_id_with_file_ids_rejected():
    ok, code = _validate_folder_id_args(
        _args(folder_id="abc123", file_ids=["id1", "id2"])
    )
    assert not ok and code == 2


def test_folder_id_with_recover_only_rejected():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", mode="recover_only"))
    assert not ok and code == 2


def test_folder_id_with_recover_and_download_passes():
    ok, code = _validate_folder_id_args(
        _args(folder_id="abc123", mode="recover_and_download")
    )
    assert ok and code == 0


def test_folder_id_with_dry_run_passes():
    ok, code = _validate_folder_id_args(_args(folder_id="abc123", mode="dry_run"))
    assert ok and code == 0
