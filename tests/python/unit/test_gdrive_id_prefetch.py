from pathlib import Path
from threading import Lock
from types import SimpleNamespace
from unittest.mock import MagicMock

import sys
from types import ModuleType

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

# lightweight stubs required by gdrive_discovery import
if "dateutil" not in sys.modules:
    dateutil_module = ModuleType("dateutil")
    parser_module = ModuleType("dateutil.parser")
    parser_module.parse = lambda value: value
    dateutil_module.parser = parser_module
    sys.modules["dateutil"] = dateutil_module
    sys.modules["dateutil.parser"] = parser_module

from gdrive_discovery import DriveTrashDiscovery, SeenTotalCounter
from gdrive_id_prefetch import IdMetadataPrefetcher, ValidationBucket, classify_http_status


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
        seen_total=SeenTotalCounter(),
        generate_target_path=lambda *_: "",
        run_parallel_processing_for_batch=lambda *_: None,
    )


def test_classify_http_status_mappings():
    assert classify_http_status(404) is ValidationBucket.NOT_FOUND
    assert classify_http_status(403) is ValidationBucket.NO_ACCESS
    assert classify_http_status(500) is None
    assert classify_http_status(None) is None


def test_clear_id_caches_clears_all_maps():
    disc = _make_discovery()
    pf = IdMetadataPrefetcher(disc)
    pf._id_prefetch["a"] = {"id": "a"}
    pf._id_prefetch_non_trashed["b"] = True
    pf._id_prefetch_errors["c"] = "HTTP 404"

    pf.clear_id_caches()

    assert pf._id_prefetch == {}
    assert pf._id_prefetch_non_trashed == {}
    assert pf._id_prefetch_errors == {}


def test_classify_prefetched_id_uses_cached_entries():
    disc = _make_discovery()
    pf = IdMetadataPrefetcher(disc)
    result = pf.prefetch_ids_metadata([])

    pf._id_prefetch["okid"] = {"id": "okid", "trashed": True}
    assert pf._classify_prefetched_id("okid", result) is True
    assert result.buckets.ok == ["okid"]

    pf._id_prefetch_errors["e404"] = "HTTP 404"
    assert pf._classify_prefetched_id("e404", result) is True
    assert result.buckets.not_found == ["e404"]

    pf._id_prefetch_non_trashed["live"] = True
    assert pf._classify_prefetched_id("live", result) is True
    assert result.counters.skipped_non_trashed == 1


def test_should_skip_invalid_id_marks_invalid_bucket():
    disc = _make_discovery()
    pf = IdMetadataPrefetcher(disc)
    result = pf.prefetch_ids_metadata([])

    assert pf._should_skip_invalid_id("short", result) is True
    assert result.buckets.invalid == ["short"]


def test_fetch_and_handle_metadata_success_and_error_paths(monkeypatch):
    disc = _make_discovery()
    pf = IdMetadataPrefetcher(disc)
    result = pf.prefetch_ids_metadata([])
    service = MagicMock()
    fid = "abcdefghijklmnopqrstuvwxyz123"

    # success
    monkeypatch.setattr(
        disc,
        "_with_retries",
        lambda *args, **kwargs: ({"id": fid, "trashed": True}, None, None),
    )
    pf._fetch_and_handle_metadata(service, fid, "id,trashed", result)
    assert fid in pf._id_prefetch
    assert result.buckets.ok == [fid]

    # 404
    monkeypatch.setattr(
        disc,
        "_with_retries",
        lambda *args, **kwargs: (None, "not found", 404),
    )
    pf._fetch_and_handle_metadata(service, "abcdefghijklmnopqrstuvwxyz124", "id", result)
    assert result.buckets.not_found == ["abcdefghijklmnopqrstuvwxyz124"]

    # 403
    monkeypatch.setattr(
        disc,
        "_with_retries",
        lambda *args, **kwargs: (None, "denied", 403),
    )
    pf._fetch_and_handle_metadata(service, "abcdefghijklmnopqrstuvwxyz125", "id", result)
    assert result.buckets.no_access == ["abcdefghijklmnopqrstuvwxyz125"]

    # transient
    monkeypatch.setattr(
        disc,
        "_with_retries",
        lambda *args, **kwargs: (None, "boom", 500),
    )
    pf._fetch_and_handle_metadata(service, "abcdefghijklmnopqrstuvwxyz126", "id", result)
    assert result.counters.transient_errors == 1
    assert result.counters.err_count == 1
    assert result.counters.transient_ids == ["abcdefghijklmnopqrstuvwxyz126"]


def test_prefetch_ids_metadata_uses_cache_and_records_invalid(monkeypatch):
    disc = _make_discovery()
    pf = IdMetadataPrefetcher(disc)
    live_id = "abcdefghijklmnopqrstuvwxyz127"
    ok_id = "abcdefghijklmnopqrstuvwxyz128"
    pf._id_prefetch_non_trashed[live_id] = True
    pf._id_prefetch[ok_id] = {"id": ok_id, "trashed": True}

    monkeypatch.setattr(disc.auth, "_get_service", lambda: MagicMock())
    result = pf.prefetch_ids_metadata(["short", live_id, ok_id])

    assert result.buckets.invalid == ["short"]
    assert result.counters.skipped_non_trashed == 1
    assert result.buckets.ok == [ok_id]


def test_emit_parity_metrics_writes_file_and_reports_mismatch(tmp_path):
    disc = _make_discovery()
    disc.args.file_ids = ["a", "b", "c"]
    out = tmp_path / "parity.json"
    disc.args.parity_metrics_file = str(out)
    pf = IdMetadataPrefetcher(disc)
    result = pf.prefetch_ids_metadata([])
    result.buckets.ok.append("a")
    result.counters.err_count = 1
    result.counters.skipped_non_trashed = 0

    mismatch = pf.emit_parity_metrics(result)

    assert mismatch is True
    assert out.exists()
