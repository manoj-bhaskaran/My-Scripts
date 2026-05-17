"""Unit tests for --timestamped-output / _apply_timestamped_output in gdrive_cli."""

import re
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from datetime import datetime

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

sys.modules["gdrive_recover"] = MagicMock()
from gdrive_cli import _apply_timestamped_output, create_parser  # noqa: E402

del sys.modules["gdrive_recover"]

# Regex matching the full suffix format: _YYYYMMDD_HHMMSS_ffffff
_STAMP_RE = re.compile(r"_\d{8}_\d{6}_\d{6}")


def _args(**kwargs):
    defaults = dict(timestamped_output=True, log_file="", failed_file="")
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# Flag disabled: no changes applied
# ---------------------------------------------------------------------------


def test_flag_off_leaves_log_file_unchanged():
    args = _args(timestamped_output=False, log_file="run.log")
    _apply_timestamped_output(args)
    assert args.log_file == "run.log"


def test_flag_off_leaves_failed_file_unchanged():
    args = _args(timestamped_output=False, failed_file="failed.csv")
    _apply_timestamped_output(args)
    assert args.failed_file == "failed.csv"


# ---------------------------------------------------------------------------
# Flag enabled: paths with extensions stamped correctly
# ---------------------------------------------------------------------------


def test_log_file_with_extension_gets_stamp():
    args = _args(log_file="run.log")
    _apply_timestamped_output(args)
    assert _STAMP_RE.search(args.log_file)
    assert args.log_file.endswith(".log")


def test_failed_file_with_extension_gets_stamp():
    args = _args(failed_file="failed.csv")
    _apply_timestamped_output(args)
    assert _STAMP_RE.search(args.failed_file)
    assert args.failed_file.endswith(".csv")


def test_stem_is_preserved_before_stamp():
    args = _args(log_file="run.log")
    _apply_timestamped_output(args)
    assert Path(args.log_file).name.startswith("run_")


def test_parent_directory_is_preserved():
    args = _args(log_file="logs/subdir/run.log")
    _apply_timestamped_output(args)
    result = Path(args.log_file)
    assert result.parent == Path("logs/subdir")
    assert result.suffix == ".log"


def test_absolute_path_parent_preserved(tmp_path):
    log_path = str(tmp_path / "run.log")
    args = _args(log_file=log_path)
    _apply_timestamped_output(args)
    result = Path(args.log_file)
    assert result.parent == tmp_path
    assert result.suffix == ".log"


# ---------------------------------------------------------------------------
# Extension-less names
# ---------------------------------------------------------------------------


def test_extension_less_log_file_gets_stamp_appended():
    args = _args(log_file="runlog")
    _apply_timestamped_output(args)
    assert _STAMP_RE.search(args.log_file)
    assert args.log_file.startswith("runlog_")
    assert "." not in args.log_file


def test_extension_less_failed_file_gets_stamp_appended():
    args = _args(failed_file="failed")
    _apply_timestamped_output(args)
    assert _STAMP_RE.search(args.failed_file)
    assert args.failed_file.startswith("failed_")


# ---------------------------------------------------------------------------
# Disabled (empty) paths left untouched
# ---------------------------------------------------------------------------


def test_empty_log_file_not_modified():
    args = _args(log_file="", failed_file="run.log")
    _apply_timestamped_output(args)
    assert args.log_file == ""


def test_empty_failed_file_not_modified():
    args = _args(log_file="run.log", failed_file="")
    _apply_timestamped_output(args)
    assert args.failed_file == ""


def test_both_empty_paths_unchanged():
    args = _args(log_file="", failed_file="")
    _apply_timestamped_output(args)
    assert args.log_file == ""
    assert args.failed_file == ""


# ---------------------------------------------------------------------------
# Shared timestamp: log_file and failed_file carry the same suffix
# ---------------------------------------------------------------------------


def test_both_files_share_the_same_timestamp():
    args = _args(log_file="run.log", failed_file="failed.csv")
    _apply_timestamped_output(args)
    log_stamp = _STAMP_RE.search(args.log_file)
    failed_stamp = _STAMP_RE.search(args.failed_file)
    assert log_stamp and failed_stamp
    assert log_stamp.group() == failed_stamp.group()


# ---------------------------------------------------------------------------
# Timestamp format: YYYYMMDD_HHMMSS_ffffff
# ---------------------------------------------------------------------------


def test_timestamp_format_is_microsecond_precision():
    """Stamp must be YYYYMMDD_HHMMSS_ffffff (8+6+6 digits separated by underscores)."""
    args = _args(log_file="run.log")
    _apply_timestamped_output(args)
    full_pattern = re.compile(r"_(\d{8})_(\d{6})_(\d{6})\.log$")
    m = full_pattern.search(args.log_file)
    assert m, f"Unexpected log filename: {args.log_file}"


def test_fixed_timestamp_values_appear_in_output():
    args = _args(log_file="run.log", failed_file="failed.csv")
    fixed = datetime(2026, 5, 17, 14, 25, 30, 123456)
    with patch("gdrive_cli.datetime") as mock_dt:
        mock_dt.now.return_value = fixed
        _apply_timestamped_output(args)
    assert "20260517_142530_123456" in args.log_file
    assert "20260517_142530_123456" in args.failed_file


# ---------------------------------------------------------------------------
# Parser: --timestamped-output accepted and defaults to False on all subcommands
# ---------------------------------------------------------------------------


def test_parser_accepts_timestamped_output_on_dry_run():
    parser = create_parser()
    args = parser.parse_args(["dry-run", "--timestamped-output"])
    assert args.timestamped_output is True


def test_parser_accepts_timestamped_output_on_recover_only():
    parser = create_parser()
    args = parser.parse_args(["recover-only", "--timestamped-output"])
    assert args.timestamped_output is True


def test_parser_accepts_timestamped_output_on_recover_and_download(tmp_path):
    parser = create_parser()
    args = parser.parse_args(
        ["recover-and-download", "--download-dir", str(tmp_path), "--timestamped-output"]
    )
    assert args.timestamped_output is True


def test_parser_timestamped_output_defaults_to_false_on_dry_run():
    parser = create_parser()
    args = parser.parse_args(["dry-run"])
    assert args.timestamped_output is False


def test_parser_timestamped_output_defaults_to_false_on_recover_only():
    parser = create_parser()
    args = parser.parse_args(["recover-only"])
    assert args.timestamped_output is False


def test_parser_timestamped_output_defaults_to_false_on_recover_and_download(tmp_path):
    parser = create_parser()
    args = parser.parse_args(["recover-and-download", "--download-dir", str(tmp_path)])
    assert args.timestamped_output is False
