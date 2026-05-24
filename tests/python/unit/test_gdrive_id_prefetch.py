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

from gdrive_discovery import DriveTrashDiscovery
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
        seen_total_ref=[0],
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
