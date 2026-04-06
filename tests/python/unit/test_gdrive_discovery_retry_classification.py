from pathlib import Path
from threading import Lock
from types import SimpleNamespace
from unittest.mock import MagicMock

import sys
from types import ModuleType

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

# gdrive_discovery requires dateutil at import time; provide a lightweight test stub.
if "dateutil" not in sys.modules:
    dateutil_module = ModuleType("dateutil")
    parser_module = ModuleType("dateutil.parser")
    parser_module.parse = lambda value: value
    dateutil_module.parser = parser_module
    sys.modules["dateutil"] = dateutil_module
    sys.modules["dateutil.parser"] = parser_module

googleapiclient_module = ModuleType("googleapiclient")
errors_module = ModuleType("googleapiclient.errors")


class HttpError(Exception):
    def __init__(self, resp=None, content=b"", *args, **kwargs):
        super().__init__(*args)
        self.resp = resp
        self.content = content


errors_module.HttpError = HttpError
googleapiclient_module.errors = errors_module
sys.modules["googleapiclient"] = googleapiclient_module
sys.modules["googleapiclient.errors"] = errors_module

from gdrive_discovery import DriveTrashDiscovery


def _make_discovery():
    args = SimpleNamespace(
        file_ids=None,
        mode="recover",
        after_date=None,
        extensions=None,
        post_restore_policy="retain",
        verbose=0,
        parity_metrics_file=None,
        debug_parity=False,
        fail_on_parity_mismatch=False,
        clear_id_cache=False,
    )
    logger = MagicMock()
    auth = MagicMock()
    execute_fn = MagicMock()
    return DriveTrashDiscovery(
        args,
        logger,
        auth,
        execute_fn,
        stats={"found": 0},
        stats_lock=Lock(),
        seen_total_ref=[0],
        generate_target_path=lambda *_: "",
        run_parallel_processing_for_batch=lambda *_: None,
    )


def test_fetch_and_handle_metadata_routes_using_status_not_message(monkeypatch):
    discovery = _make_discovery()

    monkeypatch.setattr(
        "gdrive_discovery.with_retries",
        lambda *args, **kwargs: (
            None,
            "files.get(fileId=fid) failed: HTTP 500: payload mentions HTTP 404",
            500,
        ),
    )

    buckets = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
    skipped_non_trashed = [0]
    transient_errors = [0]
    transient_ids = []
    err_count = [0]

    discovery._fetch_and_handle_metadata(
        service=MagicMock(),
        fid="fid",
        fields="id",
        buckets=buckets,
        skipped_non_trashed=skipped_non_trashed,
        transient_errors=transient_errors,
        transient_ids=transient_ids,
        err_count=err_count,
    )

    assert buckets["not_found"] == []
    assert buckets["no_access"] == []
    assert transient_errors[0] == 1
    assert transient_ids == ["fid"]
    assert err_count[0] == 1


def test_fetch_and_handle_metadata_routes_not_found_by_status(monkeypatch):
    discovery = _make_discovery()

    monkeypatch.setattr(
        "gdrive_discovery.with_retries",
        lambda *args, **kwargs: (None, "files.get(fileId=fid) failed: HTTP 404: missing", 404),
    )

    buckets = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
    discovery._fetch_and_handle_metadata(
        service=MagicMock(),
        fid="fid",
        fields="id",
        buckets=buckets,
        skipped_non_trashed=[0],
        transient_errors=[0],
        transient_ids=[],
        err_count=[0],
    )

    assert buckets["not_found"] == ["fid"]


def test_fetch_and_handle_metadata_routes_no_access_by_status(monkeypatch):
    discovery = _make_discovery()

    monkeypatch.setattr(
        "gdrive_discovery.with_retries",
        lambda *args, **kwargs: (None, "files.get(fileId=fid) failed: HTTP 403: denied", 403),
    )

    buckets = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
    discovery._fetch_and_handle_metadata(
        service=MagicMock(),
        fid="fid",
        fields="id",
        buckets=buckets,
        skipped_non_trashed=[0],
        transient_errors=[0],
        transient_ids=[],
        err_count=[0],
    )

    assert buckets["no_access"] == ["fid"]
