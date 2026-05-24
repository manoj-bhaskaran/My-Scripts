"""Unit tests for ConsoleHelper integration in gdrive_cli.

Covers the refactored functions that replaced inline _sym_* helpers with
ConsoleHelper, as introduced in issue #1124:
  - _validate_concurrency_arg (sym_fail + sym_warn paths)
  - _normalize_and_validate_extensions (sym_fail + sym_info paths)
  - _load_retry_failed_file exception path (sym_fail)
"""

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

sys.modules["gdrive_recover"] = MagicMock()
from gdrive_cli import (  # noqa: E402
    _validate_concurrency_arg,
    _normalize_and_validate_extensions,
    _load_retry_failed_file,
)

del sys.modules["gdrive_recover"]


def _args(**kwargs):
    defaults = dict(no_emoji=True)
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# _validate_concurrency_arg
# ---------------------------------------------------------------------------


def test_validate_concurrency_arg_below_one_fails(capsys):
    args = _args(concurrency=0)
    ok, code = _validate_concurrency_arg(args)
    assert not ok and code == 2
    out = capsys.readouterr().out
    assert "Invalid --concurrency" in out


def test_validate_concurrency_arg_below_one_emoji(capsys):
    args = _args(concurrency=0, no_emoji=False)
    ok, code = _validate_concurrency_arg(args)
    assert not ok and code == 2
    assert "❌" in capsys.readouterr().out


def test_validate_concurrency_arg_below_one_no_emoji(capsys):
    args = _args(concurrency=0, no_emoji=True)
    ok, code = _validate_concurrency_arg(args)
    assert not ok and code == 2
    assert "ERROR" in capsys.readouterr().out


def test_validate_concurrency_arg_above_ceiling_caps_and_warns(capsys):
    args = _args(concurrency=9999)
    ok, code = _validate_concurrency_arg(args)
    assert ok and code == 0
    assert args.concurrency <= 64
    assert "high" in capsys.readouterr().out


def test_validate_concurrency_arg_above_ceiling_warn_emoji(capsys):
    args = _args(concurrency=9999, no_emoji=False)
    _validate_concurrency_arg(args)
    assert "⚠️" in capsys.readouterr().out


def test_validate_concurrency_arg_above_ceiling_warn_no_emoji(capsys):
    args = _args(concurrency=9999, no_emoji=True)
    _validate_concurrency_arg(args)
    assert "WARN" in capsys.readouterr().out


def test_validate_concurrency_arg_valid_passes():
    args = _args(concurrency=4)
    ok, code = _validate_concurrency_arg(args)
    assert ok and code == 0
    assert args.concurrency == 4


def test_validate_concurrency_arg_one_passes():
    args = _args(concurrency=1)
    ok, code = _validate_concurrency_arg(args)
    assert ok and code == 0


# ---------------------------------------------------------------------------
# _normalize_and_validate_extensions
# ---------------------------------------------------------------------------


def test_normalize_and_validate_extensions_none_passes():
    args = _args(extensions=None)
    ok, code = _normalize_and_validate_extensions(args)
    assert ok and code == 0


def test_normalize_and_validate_extensions_valid_list_passes():
    args = _args(extensions=["jpg", "png", "pdf"])
    ok, code = _normalize_and_validate_extensions(args)
    assert ok and code == 0
    assert "jpg" in args.extensions


def test_normalize_and_validate_extensions_multi_segment_emits_info_warning(capsys):
    # Multi-segment extensions (e.g. tar.gz) produce an info warning — not an error —
    # because the last segment may not narrow server-side MIME queries.
    args = _args(extensions=["tar.gz"], no_emoji=True)
    ok, code = _normalize_and_validate_extensions(args)
    assert ok and code == 0
    assert "INFO" in capsys.readouterr().out


def test_normalize_and_validate_extensions_multi_segment_info_emoji(capsys):
    args = _args(extensions=["tar.gz"], no_emoji=False)
    ok, code = _normalize_and_validate_extensions(args)
    assert ok and code == 0
    assert "ℹ️" in capsys.readouterr().out


def test_normalize_and_validate_extensions_invalid_ext_fails(capsys):
    # Extensions with wildcards or illegal chars are rejected.
    args = _args(extensions=["*.jpg"], no_emoji=True)
    ok, code = _normalize_and_validate_extensions(args)
    assert not ok and code == 2
    err = capsys.readouterr().err
    assert "ERROR" in err


def test_normalize_and_validate_extensions_invalid_ext_emoji(capsys):
    args = _args(extensions=["*.jpg"], no_emoji=False)
    ok, code = _normalize_and_validate_extensions(args)
    assert not ok and code == 2
    assert "❌" in capsys.readouterr().err


# ---------------------------------------------------------------------------
# _load_retry_failed_file — exception path (unreadable / missing file)
# ---------------------------------------------------------------------------


def test_load_retry_failed_file_nonexistent_path_fails(capsys):
    ok, code, overrides = _load_retry_failed_file(
        "/nonexistent/path/does_not_exist.csv", _args()
    )
    assert not ok and code == 2
    assert overrides == {}
    assert "Could not read" in capsys.readouterr().err


def test_load_retry_failed_file_exception_path_no_emoji(capsys):
    ok, code, _ = _load_retry_failed_file(
        "/nonexistent/path/does_not_exist.csv", _args(no_emoji=True)
    )
    assert not ok
    assert "ERROR" in capsys.readouterr().err


def test_load_retry_failed_file_exception_path_emoji(capsys):
    ok, code, _ = _load_retry_failed_file(
        "/nonexistent/path/does_not_exist.csv", _args(no_emoji=False)
    )
    assert not ok
    assert "❌" in capsys.readouterr().err
