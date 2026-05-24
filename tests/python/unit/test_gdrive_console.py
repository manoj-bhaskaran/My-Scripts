"""Unit tests for ConsoleHelper in gdrive_console.py."""

import sys
from io import StringIO
from pathlib import Path
from types import SimpleNamespace

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_console import ConsoleHelper


def _helper(no_emoji: bool) -> ConsoleHelper:
    return ConsoleHelper(SimpleNamespace(no_emoji=no_emoji))


def _helper_no_attr() -> ConsoleHelper:
    """Args with no no_emoji attribute — should default to emoji enabled."""
    return ConsoleHelper(SimpleNamespace())


# ---------------------------------------------------------------------------
# use_emoji
# ---------------------------------------------------------------------------


def test_use_emoji_true_when_no_emoji_false():
    assert _helper(no_emoji=False).use_emoji() is True


def test_use_emoji_false_when_no_emoji_true():
    assert _helper(no_emoji=True).use_emoji() is False


def test_use_emoji_defaults_to_true_when_attr_absent():
    assert _helper_no_attr().use_emoji() is True


# ---------------------------------------------------------------------------
# sym_* — emoji mode
# ---------------------------------------------------------------------------


def test_sym_fail_emoji():
    assert _helper(False).sym_fail() == "❌"


def test_sym_warn_emoji():
    assert _helper(False).sym_warn() == "⚠️"


def test_sym_info_emoji():
    assert _helper(False).sym_info() == "ℹ️"


def test_sym_ok_emoji():
    assert _helper(False).sym_ok() == "✓"


def test_sym_scope_emoji():
    assert _helper(False).sym_scope() == "📊"


def test_sym_search_emoji():
    assert _helper(False).sym_search() == "🔍"


def test_sym_done_emoji():
    assert _helper(False).sym_done() == "✅"


def test_sym_limit_emoji():
    assert _helper(False).sym_limit() == "⛳"


def test_sym_progress_emoji():
    assert _helper(False).sym_progress() == "📈"


def test_sym_plan_emoji():
    assert _helper(False).sym_plan() == "📋"


# ---------------------------------------------------------------------------
# sym_* — no-emoji (ASCII) mode
# ---------------------------------------------------------------------------


def test_sym_fail_ascii():
    assert _helper(True).sym_fail() == "ERROR"


def test_sym_warn_ascii():
    assert _helper(True).sym_warn() == "WARN"


def test_sym_info_ascii():
    assert _helper(True).sym_info() == "INFO"


def test_sym_ok_ascii():
    assert _helper(True).sym_ok() == "OK"


def test_sym_scope_ascii():
    assert _helper(True).sym_scope() == "SCOPE"


def test_sym_search_ascii():
    assert _helper(True).sym_search() == "SEARCH"


def test_sym_done_ascii():
    assert _helper(True).sym_done() == "DONE"


def test_sym_limit_ascii():
    assert _helper(True).sym_limit() == "LIMIT"


def test_sym_progress_ascii():
    assert _helper(True).sym_progress() == "PROGRESS"


def test_sym_plan_ascii():
    assert _helper(True).sym_plan() == "PLAN"


# ---------------------------------------------------------------------------
# print_err / print_warn — write to stderr
# ---------------------------------------------------------------------------


def test_print_err_writes_to_stderr(capsys):
    _helper(True).print_err("something broke")
    captured = capsys.readouterr()
    assert "something broke" in captured.err
    assert "ERROR" in captured.err
    assert captured.out == ""


def test_print_warn_writes_to_stderr(capsys):
    _helper(True).print_warn("heads up")
    captured = capsys.readouterr()
    assert "heads up" in captured.err
    assert "WARN" in captured.err
    assert captured.out == ""


def test_print_err_emoji_prefix(capsys):
    _helper(False).print_err("oops")
    assert "❌" in capsys.readouterr().err


def test_print_warn_emoji_prefix(capsys):
    _helper(False).print_warn("careful")
    assert "⚠️" in capsys.readouterr().err


# ---------------------------------------------------------------------------
# print_info — writes to stdout
# ---------------------------------------------------------------------------


def test_print_info_writes_to_stdout(capsys):
    _helper(True).print_info("all good")
    captured = capsys.readouterr()
    assert "all good" in captured.out
    assert "INFO" in captured.out
    assert captured.err == ""


def test_print_info_emoji_prefix(capsys):
    _helper(False).print_info("note")
    captured = capsys.readouterr()
    assert "ℹ️" in captured.out
    assert captured.err == ""
