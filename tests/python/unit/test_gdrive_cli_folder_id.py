"""Unit tests for --folder-id CLI validation and --download-dir parsing in gdrive_cli."""

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
from gdrive_cli import (  # noqa: E402
    _validate_folder_id_args,
    _validate_failed_file_arg,
    _validate_retry_failed_file_arg,
    _load_retry_failed_file,
    _apply_retry_failed_file,
    create_parser,
)

del sys.modules["gdrive_recover"]


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


# ---------------------------------------------------------------------------
# --download-dir accepted by dry-run (optional); required for recover-and-download
# ---------------------------------------------------------------------------


def test_dry_run_accepts_download_dir():
    parser = create_parser()
    args = parser.parse_args(["dry-run", "--download-dir", "./out"])
    assert args.download_dir == "./out"


def test_dry_run_download_dir_defaults_to_none():
    parser = create_parser()
    args = parser.parse_args(["dry-run"])
    assert args.download_dir is None


# ---------------------------------------------------------------------------
# _validate_failed_file_arg
# ---------------------------------------------------------------------------


def test_validate_failed_file_arg_empty_passes():
    ok, code = _validate_failed_file_arg(_args(failed_file=""))
    assert ok and code == 0


def test_validate_failed_file_arg_valid_path_creates_parent_dirs(tmp_path):
    path = tmp_path / "logs" / "failed.txt"
    ok, code = _validate_failed_file_arg(_args(failed_file=str(path)))
    assert ok and code == 0
    assert path.parent.exists()


def test_validate_failed_file_arg_existing_file_passes(tmp_path):
    path = tmp_path / "failed.txt"
    path.write_text("old entry\n")
    ok, code = _validate_failed_file_arg(_args(failed_file=str(path)))
    assert ok and code == 0


def test_validate_failed_file_arg_points_to_directory_rejected(tmp_path):
    ok, code = _validate_failed_file_arg(_args(failed_file=str(tmp_path)))
    assert not ok and code == 2


# ---------------------------------------------------------------------------
# Parser accepts --failed-file on all subcommands
# ---------------------------------------------------------------------------


def test_parser_accepts_failed_file_on_dry_run():
    parser = create_parser()
    args = parser.parse_args(["dry-run", "--failed-file", "./failed.txt"])
    assert args.failed_file == "./failed.txt"


def test_parser_accepts_failed_file_on_recover_only():
    parser = create_parser()
    args = parser.parse_args(["recover-only", "--failed-file", "./failed.txt"])
    assert args.failed_file == "./failed.txt"


def test_parser_failed_file_defaults_to_empty():
    parser = create_parser()
    args = parser.parse_args(["dry-run"])
    assert args.failed_file == ""


# ---------------------------------------------------------------------------
# _validate_retry_failed_file_arg
# ---------------------------------------------------------------------------


def test_validate_retry_failed_file_arg_empty_passes():
    ok, code = _validate_retry_failed_file_arg(_args(retry_failed_file=""))
    assert ok and code == 0


def test_validate_retry_failed_file_arg_nonexistent_file_rejected(tmp_path):
    path = tmp_path / "missing.csv"
    ok, code = _validate_retry_failed_file_arg(_args(retry_failed_file=str(path)))
    assert not ok and code == 2


def test_validate_retry_failed_file_arg_directory_rejected(tmp_path):
    ok, code = _validate_retry_failed_file_arg(_args(retry_failed_file=str(tmp_path)))
    assert not ok and code == 2


def test_validate_retry_failed_file_arg_with_file_ids_rejected(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    ok, code = _validate_retry_failed_file_arg(
        _args(retry_failed_file=str(csv_file), file_ids=["id1"])
    )
    assert not ok and code == 2


def test_validate_retry_failed_file_arg_with_folder_id_rejected(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    ok, code = _validate_retry_failed_file_arg(
        _args(retry_failed_file=str(csv_file), folder_id="folder123")
    )
    assert not ok and code == 2


def test_validate_retry_failed_file_arg_valid_file_passes(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    ok, code = _validate_retry_failed_file_arg(_args(retry_failed_file=str(csv_file)))
    assert ok and code == 0


def test_validate_retry_failed_file_same_as_failed_file_rejected(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    ok, code = _validate_retry_failed_file_arg(
        _args(retry_failed_file=str(csv_file), failed_file=str(csv_file))
    )
    assert not ok and code == 2


# ---------------------------------------------------------------------------
# _load_retry_failed_file
# ---------------------------------------------------------------------------


def test_load_retry_failed_file_parses_rows(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text(
        "source_folder_id,file_id,target_path\nfolder1,id1,/a/b.txt\nfolder2,id2,/c/d.jpg\n"
    )
    ok, code, overrides = _load_retry_failed_file(str(csv_file))
    assert ok and code == 0
    assert overrides == {"id1": "/a/b.txt", "id2": "/c/d.jpg"}


def test_load_retry_failed_file_missing_file_id_column_rejected(tmp_path):
    csv_file = tmp_path / "bad.csv"
    csv_file.write_text("source_folder_id,target_path\nfolder1,/a/b.txt\n")
    ok, code, overrides = _load_retry_failed_file(str(csv_file))
    assert not ok and code == 2


def test_load_retry_failed_file_empty_rows_returns_empty_overrides(tmp_path):
    csv_file = tmp_path / "empty.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\n")
    ok, code, overrides = _load_retry_failed_file(str(csv_file))
    # _load_retry_failed_file succeeds; main() is responsible for the early exit on empty result.
    assert ok and code == 0
    assert overrides == {}


# ---------------------------------------------------------------------------
# Parser accepts --retry-failed-file on recover-and-download
# ---------------------------------------------------------------------------


def test_parser_accepts_retry_failed_file_on_recover_and_download(tmp_path):
    parser = create_parser()
    args = parser.parse_args(
        ["recover-and-download", "--download-dir", str(tmp_path), "--retry-failed-file", "./f.csv"]
    )
    assert args.retry_failed_file == "./f.csv"


def test_parser_retry_failed_file_defaults_to_empty(tmp_path):
    parser = create_parser()
    args = parser.parse_args(["recover-and-download", "--download-dir", str(tmp_path)])
    assert args.retry_failed_file == ""


# ---------------------------------------------------------------------------
# _apply_retry_failed_file
# ---------------------------------------------------------------------------


def test_apply_retry_failed_file_no_path_sets_defaults():
    """No --retry-failed-file: sets safe defaults and returns True."""
    args = _args(retry_failed_file="", failed_file="")
    ok, code = _apply_retry_failed_file(args)
    assert ok and code == 0
    assert args._retry_mode is False
    assert args._target_path_overrides == {}


def test_apply_retry_failed_file_nonexistent_path_rejected(tmp_path):
    path = tmp_path / "missing.csv"
    args = _args(retry_failed_file=str(path), failed_file="")
    ok, code = _apply_retry_failed_file(args)
    assert not ok and code == 2


def test_apply_retry_failed_file_empty_csv_rejected(tmp_path):
    """An existing CSV with no data rows should return False with exit code 1."""
    csv_file = tmp_path / "empty.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\n")
    args = _args(retry_failed_file=str(csv_file), failed_file="")
    ok, code = _apply_retry_failed_file(args)
    assert not ok and code == 1


def test_apply_retry_failed_file_valid_csv_populates_args(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text(
        "source_folder_id,file_id,target_path\nfolder1,id1,/a/b.txt\nfolder2,id2,/c/d.jpg\n"
    )
    args = _args(retry_failed_file=str(csv_file), failed_file="")
    ok, code = _apply_retry_failed_file(args)
    assert ok and code == 0
    assert args._retry_mode is True
    assert args.file_ids == ["id1", "id2"]
    assert args._target_path_overrides == {"id1": "/a/b.txt", "id2": "/c/d.jpg"}


def test_apply_retry_failed_file_same_as_failed_file_rejected(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    args = _args(
        retry_failed_file=str(csv_file),
        failed_file=str(csv_file),
    )
    ok, code = _apply_retry_failed_file(args)
    assert not ok and code == 2


# ---------------------------------------------------------------------------
# --fresh-run flag (issue #1028)
# ---------------------------------------------------------------------------


def test_parser_accepts_fresh_run_on_recover_only():
    parser = create_parser()
    args = parser.parse_args(["recover-only", "--fresh-run"])
    assert args.fresh_run is True


def test_parser_accepts_fresh_run_on_recover_and_download(tmp_path):
    parser = create_parser()
    args = parser.parse_args(
        ["recover-and-download", "--download-dir", str(tmp_path), "--fresh-run"]
    )
    assert args.fresh_run is True


def test_parser_rejects_fresh_run_on_dry_run():
    """dry-run is preview-only and never calls _prepare_recovery, so --fresh-run
    would be silently ignored. The parser must reject it rather than accept and
    drop it on the floor."""
    import pytest

    parser = create_parser()
    with pytest.raises(SystemExit):
        parser.parse_args(["dry-run", "--fresh-run"])


def test_parser_fresh_run_defaults_to_false():
    parser = create_parser()
    args = parser.parse_args(["recover-only"])
    assert args.fresh_run is False


def test_validate_retry_failed_file_arg_with_fresh_run_rejected(tmp_path):
    csv_file = tmp_path / "failed.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\nf1,id1,/p1\n")
    ok, code = _validate_retry_failed_file_arg(
        _args(retry_failed_file=str(csv_file), fresh_run=True)
    )
    assert not ok and code == 2
