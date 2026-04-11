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


def test_build_query_includes_server_side_after_date_filter():
    discovery = _make_discovery()
    discovery.args.after_date = "2026-01-01T00:00:00+00:00"

    q = discovery._build_query()

    assert "modifiedTime > '2026-01-01T00:00:00+00:00'" in q


def test_prefetch_reuses_cached_metadata_without_second_api_call():
    discovery = _make_discovery()
    discovery.args.file_ids = ["abcdefghijklmnopqrstuvwxyz123"]

    service = MagicMock()
    service.files.return_value.get.return_value = object()
    discovery.auth._get_service.return_value = service

    calls = {"n": 0}

    def _fake_with_retries(*args, **kwargs):
        calls["n"] += 1
        return ({"id": "fid", "trashed": True}, None, None)

    from gdrive_discovery import with_retries as _orig_with_retries

    try:
        import gdrive_discovery as module

        module.with_retries = _fake_with_retries
        discovery._prefetch_ids_metadata(discovery.args.file_ids)
        discovery._prefetch_ids_metadata(discovery.args.file_ids)
    finally:
        import gdrive_discovery as module

        module.with_retries = _orig_with_retries

    assert calls["n"] == 1


def test_validate_file_ids_clear_cache_warns(monkeypatch):
    discovery = _make_discovery()
    discovery.args.file_ids = ["abcdefghijklmnopqrstuvwxyz123"]
    discovery.args.clear_id_cache = True

    monkeypatch.setattr(
        discovery,
        "_prefetch_ids_metadata",
        lambda *_: ({"ok": [], "invalid": [], "not_found": [], "no_access": []}, 0, [], 0, 0),
    )

    discovery._print_warn = MagicMock()

    assert discovery._validate_file_ids() is True
    discovery._print_warn.assert_called_once()
