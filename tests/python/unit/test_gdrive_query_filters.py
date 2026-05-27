from pathlib import Path
import sys

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_query_filters import (
    build_discovery_query,
    build_mime_conditions,
    matches_extension_filter,
    normalize_extension,
    normalize_extension_last_segment,
)


def test_normalize_extension_uses_last_segment():
    assert normalize_extension(".tar.gz") == "tar.gz"


def test_normalize_extension_last_segment_for_mime_lookup():
    assert normalize_extension_last_segment(".tar.gz") == "gz"


def test_build_mime_conditions_skips_unknown_extensions():
    conds = build_mime_conditions([".pdf", ".unknown"])
    assert len(conds) == 1
    assert "application/pdf" in conds[0]


def test_build_discovery_query_combines_filters():
    q = build_discovery_query(["pdf"], "2026-01-01T00:00:00+00:00")
    assert "trashed=true" in q
    assert "mimeType" in q
    assert "modifiedTime > '2026-01-01T00:00:00+00:00'" in q


def test_matches_extension_filter_accepts_mixed_extensions():
    assert matches_extension_filter("doc.PDF", ["pdf", ".txt"])
    assert not matches_extension_filter("doc.csv", ["pdf", "txt"])


def test_matches_extension_filter_preserves_multi_segment_suffix():
    assert matches_extension_filter("archive.tar.gz", ["tar.gz"])
    assert not matches_extension_filter("archive.gz", ["tar.gz"])
