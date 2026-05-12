"""Unit tests for folder-scoped discovery helpers in DriveTrashDiscovery."""

import sys
from collections import deque
from pathlib import Path
from threading import Lock
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

# googleapiclient stubs — use setdefault so that if an earlier test module
# already registered these (with its own HttpError class), we reuse those
# registrations rather than replacing them (which would break exception
# isinstance checks across test files collected in the same session).
for _gmod in (
    "googleapiclient",
    "googleapiclient.errors",
    "googleapiclient.discovery",
    "googleapiclient.http",
):
    sys.modules.setdefault(_gmod, ModuleType(_gmod))

_errors = sys.modules["googleapiclient.errors"]
_discovery_mod = sys.modules["googleapiclient.discovery"]
_http = sys.modules["googleapiclient.http"]
_googleapiclient = sys.modules["googleapiclient"]


class _HttpError(Exception):
    def __init__(self, resp=None, content=b"", *args, **kwargs):
        super().__init__(*args)
        self.resp = resp
        self.content = content


if not hasattr(_errors, "HttpError"):
    _errors.HttpError = _HttpError
if not hasattr(_discovery_mod, "build"):
    _discovery_mod.build = lambda *a, **kw: None
if not hasattr(_http, "MediaIoBaseDownload"):
    _http.MediaIoBaseDownload = type(
        "MediaIoBaseDownload", (), {"__init__": lambda s, *a, **kw: None}
    )
if not hasattr(_googleapiclient, "errors"):
    _googleapiclient.errors = _errors
if not hasattr(_googleapiclient, "discovery"):
    _googleapiclient.discovery = _discovery_mod
if not hasattr(_googleapiclient, "http"):
    _googleapiclient.http = _http

from gdrive_constants import FOLDER_MIME_TYPE  # noqa: E402
from gdrive_discovery import DriveTrashDiscovery  # noqa: E402

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_discovery(folder_id="root_id", mode="recover_and_download", limit=0):
    args = SimpleNamespace(
        folder_id=folder_id,
        file_ids=None,
        mode=mode,
        after_date=None,
        extensions=None,
        post_restore_policy="retain",
        download_dir="/tmp/dl",
        verbose=0,
        limit=limit,
    )
    processed: list = []
    disc = DriveTrashDiscovery(
        args,
        logger=MagicMock(),
        auth=MagicMock(),
        execute_fn=MagicMock(),
        stats={"found": 0, "errors": 0},
        stats_lock=Lock(),
        seen_total_ref=[0],
        generate_target_path=lambda item: f"/tmp/dl/{item.name}",
        run_parallel_processing_for_batch=lambda batch, ts: processed.extend(list(batch)),
    )
    disc._processed = processed
    return disc


def _file(name, fid, mime="text/plain"):
    return {
        "id": fid,
        "name": name,
        "mimeType": mime,
        "createdTime": "2024-01-01T00:00:00Z",
        "size": 0,
    }


def _folder(name, fid):
    return {"id": fid, "name": name, "mimeType": FOLDER_MIME_TYPE}


# ---------------------------------------------------------------------------
# _sanitize_path_component
# ---------------------------------------------------------------------------


def test_sanitize_keeps_safe_chars():
    assert DriveTrashDiscovery._sanitize_path_component("My-Folder_1.0") == "My-Folder_1.0"


def test_sanitize_strips_special_chars():
    assert DriveTrashDiscovery._sanitize_path_component("bad*name?") == "badname"


def test_sanitize_empty_falls_back():
    assert DriveTrashDiscovery._sanitize_path_component("***") == "unknown"
    assert DriveTrashDiscovery._sanitize_path_component("") == "unknown"


# ---------------------------------------------------------------------------
# _collect_items_from_page
# ---------------------------------------------------------------------------


def test_collect_items_no_limit():
    disc = _make_discovery()
    items = []
    reached = disc._collect_items_from_page(
        [_file("a.txt", "id1"), _file("b.txt", "id2")], items, ""
    )
    assert not reached
    assert len(items) == 2


def test_collect_items_limit_stops_early():
    disc = _make_discovery(limit=1)
    items = []
    reached = disc._collect_items_from_page(
        [_file("a.txt", "id1"), _file("b.txt", "id2")], items, ""
    )
    assert reached
    assert len(items) == 1


def test_collect_items_sets_relative_path():
    disc = _make_discovery()
    items = []
    disc._collect_items_from_page([_file("a.txt", "id1")], items, "sub/dir")
    assert items[0].relative_path == "sub/dir"


# ---------------------------------------------------------------------------
# _enqueue_subfolders
# ---------------------------------------------------------------------------


def test_enqueue_subfolders_root_level():
    disc = _make_discovery()
    queue = deque()
    disc._enqueue_subfolders(queue, [_folder("Child", "c1")], "")
    assert queue[0] == ("c1", "Child")


def test_enqueue_subfolders_nested():
    disc = _make_discovery()
    queue = deque()
    disc._enqueue_subfolders(queue, [_folder("Sub", "s1")], "Parent")
    assert queue[0] == ("s1", "Parent/Sub")


def test_enqueue_subfolders_sanitizes_name():
    disc = _make_discovery()
    queue = deque()
    disc._enqueue_subfolders(queue, [_folder("bad*name?", "s1")], "")
    _, prefix = queue[0]
    assert "*" not in prefix and "?" not in prefix


# ---------------------------------------------------------------------------
# _traverse_folder_pages
# ---------------------------------------------------------------------------


def test_traverse_folder_pages_collects_items():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(return_value=([_file("f.txt", "id1")], [], None))
    items = []
    result = disc._traverse_folder_pages("f1", "", items, deque())
    assert not result
    assert len(items) == 1


def test_traverse_folder_pages_fetch_error():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(side_effect=RuntimeError("network"))
    items = []
    result = disc._traverse_folder_pages("f1", "", items, deque())
    assert not result
    disc.logger.error.assert_called_once()


def test_traverse_folder_pages_limit_returns_true():
    disc = _make_discovery(limit=1)
    disc._fetch_folder_page = MagicMock(
        return_value=([_file("a.txt", "id1"), _file("b.txt", "id2")], [], None)
    )
    items = []
    result = disc._traverse_folder_pages("f1", "", items, deque())
    assert result
    assert len(items) == 1


def test_traverse_folder_pages_enqueues_subfolders():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(return_value=([], [_folder("Sub", "sub1")], None))
    queue = deque()
    disc._traverse_folder_pages("f1", "", [], queue)
    assert ("sub1", "Sub") in list(queue)


def test_traverse_folder_pages_paginates():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(
        side_effect=[
            ([_file("a.txt", "id1")], [], "tok"),
            ([_file("b.txt", "id2")], [], None),
        ]
    )
    items = []
    disc._traverse_folder_pages("f1", "", items, deque())
    assert len(items) == 2


# ---------------------------------------------------------------------------
# _discover_folder_recursively
# ---------------------------------------------------------------------------


def test_discover_flat_folder():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(
        return_value=([_file("a.txt", "id1"), _file("b.txt", "id2")], [], None)
    )
    items = disc._discover_folder_recursively()
    assert len(items) == 2
    assert all(item.relative_path == "" for item in items)


def test_discover_subfolder_paths():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(
        side_effect=[
            ([], [_folder("Docs", "docs_id")], None),
            ([_file("note.txt", "id1")], [], None),
        ]
    )
    items = disc._discover_folder_recursively()
    assert len(items) == 1
    assert items[0].relative_path == "Docs"


def test_discover_respects_limit():
    disc = _make_discovery(limit=2)
    disc._fetch_folder_page = MagicMock(
        return_value=([_file(f"f{i}.txt", f"id{i}") for i in range(5)], [], None)
    )
    items = disc._discover_folder_recursively()
    assert len(items) == 2


def test_discover_fetch_error_returns_empty():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(side_effect=RuntimeError("boom"))
    assert disc._discover_folder_recursively() == []


# ---------------------------------------------------------------------------
# _stream_stream_folder
# ---------------------------------------------------------------------------


def test_stream_folder_processes_items():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(
        return_value=([_file("a.txt", "id1"), _file("b.txt", "id2")], [], None)
    )
    ok = disc._stream_stream_folder(batch_n=10, start_time=0.0)
    assert ok
    assert len(disc._processed) == 2


def test_stream_folder_limit():
    disc = _make_discovery(limit=1)
    disc._fetch_folder_page = MagicMock(
        return_value=([_file(f"f{i}.txt", f"id{i}") for i in range(5)], [], None)
    )
    disc._stream_stream_folder(batch_n=10, start_time=0.0)
    assert len(disc._processed) == 1


def test_stream_folder_fetch_error_returns_false():
    disc = _make_discovery()
    disc._fetch_folder_page = MagicMock(side_effect=RuntimeError("fail"))
    ok = disc._stream_stream_folder(batch_n=10, start_time=0.0)
    assert not ok
