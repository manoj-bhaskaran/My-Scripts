"""Unit tests for lock management and run dispatch in gdrive_cli.

Covers the three correctness fixes from issue #1122:
  - _check_pid_alive returns " (not running)" when PID is not alive
  - _print_lockfile_messages stale-lock branches are reachable
  - _run_and_release_lock dispatches all commands through _run_tool
  - _acquire_or_bypass_lock surfaces real exceptions instead of swallowing them
"""

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch, call
import pytest

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

sys.modules["gdrive_recover"] = MagicMock()
from gdrive_cli import (  # noqa: E402
    _check_pid_alive,
    _print_lockfile_messages,
    _run_and_release_lock,
    _acquire_or_bypass_lock,
)
from gdrive_state import StateScopeMismatchError  # noqa: E402

del sys.modules["gdrive_recover"]


def _tool(acquired=True, pid_alive=True):
    """Return a minimal mock tool with a state_manager."""
    tool = MagicMock()
    tool.state_manager._acquire_state_lock.return_value = acquired
    tool.state_manager._pid_is_alive.return_value = pid_alive
    return tool


def _args(**kwargs):
    defaults = dict(
        state_file="/tmp/state.json",
        mode="dry_run",
        command="dry-run",
        force=False,
        lock_timeout=0,
        no_emoji=True,
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# _check_pid_alive
# ---------------------------------------------------------------------------


def test_check_pid_alive_returns_not_running_when_dead():
    tool = _tool(pid_alive=False)
    note = _check_pid_alive("1234", tool)
    assert note == " (not running)"


def test_check_pid_alive_returns_empty_when_alive():
    tool = _tool(pid_alive=True)
    note = _check_pid_alive("1234", tool)
    assert note == ""


def test_check_pid_alive_returns_empty_on_non_integer_pid():
    tool = _tool()
    note = _check_pid_alive("unknown", tool)
    assert note == ""


def test_check_pid_alive_returns_empty_on_pid_check_exception():
    tool = MagicMock()
    tool.state_manager._pid_is_alive.side_effect = OSError("permission denied")
    note = _check_pid_alive("1234", tool)
    assert note == ""


# ---------------------------------------------------------------------------
# _print_lockfile_messages — stale-lock branch (no force)
# ---------------------------------------------------------------------------


def test_print_lockfile_messages_stale_no_force_prints_stale_hint(capsys):
    args = _args()
    _print_lockfile_messages(args, "999", "run-abc", " (not running)", False)
    err = capsys.readouterr().err
    assert "stale" in err
    assert "--force" in err


def test_print_lockfile_messages_live_no_force_prints_tip(capsys):
    args = _args()
    _print_lockfile_messages(args, "999", "run-abc", "", False)
    err = capsys.readouterr().err
    assert "Tip:" in err
    assert "stale" not in err


def test_print_lockfile_messages_stale_with_force_prints_stale_warning(capsys):
    args = _args()
    _print_lockfile_messages(args, "999", "run-abc", " (not running)", True)
    err = capsys.readouterr().err
    assert "stale" in err
    assert "WARN" in err


def test_print_lockfile_messages_live_with_force_prints_generic_bypass(capsys):
    args = _args()
    _print_lockfile_messages(args, "999", "run-abc", "", True)
    err = capsys.readouterr().err
    assert "bypassing concurrent-run guardrail" in err
    assert "stale" not in err


# ---------------------------------------------------------------------------
# _run_and_release_lock — dispatch through _run_tool unconditionally
# ---------------------------------------------------------------------------


def test_run_and_release_lock_dry_run_calls_run_tool():
    tool = _tool()
    args = _args(command="dry-run", mode="dry_run")
    with patch("gdrive_cli._run_tool", return_value=True) as mock_run:
        result = _run_and_release_lock(tool, args)
    mock_run.assert_called_once_with(tool, args)
    assert result == 0


def test_run_and_release_lock_recover_only_calls_run_tool():
    tool = _tool()
    args = _args(command="recover-only", mode="recover_only")
    with patch("gdrive_cli._run_tool", return_value=True) as mock_run:
        result = _run_and_release_lock(tool, args)
    mock_run.assert_called_once_with(tool, args)
    assert result == 0


def test_run_and_release_lock_returns_1_on_run_tool_false():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=False):
        result = _run_and_release_lock(tool, args)
    assert result == 1


def test_run_and_release_lock_releases_lock_on_success():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=True):
        _run_and_release_lock(tool, args)
    tool.state_manager._release_state_lock.assert_called_once()


def test_run_and_release_lock_releases_lock_on_failure():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=False):
        _run_and_release_lock(tool, args)
    tool.state_manager._release_state_lock.assert_called_once()


def test_run_and_release_lock_scope_mismatch_returns_2(capsys):
    tool = _tool()
    args = _args(no_emoji=True)
    err = StateScopeMismatchError("saved", "current")
    with patch("gdrive_cli._run_tool", side_effect=err):
        result = _run_and_release_lock(tool, args)
    assert result == 2
    tool.state_manager._release_state_lock.assert_called_once()


def test_run_and_release_lock_releases_lock_even_on_scope_mismatch(capsys):
    tool = _tool()
    args = _args(no_emoji=True)
    err = StateScopeMismatchError("saved", "current")
    with patch("gdrive_cli._run_tool", side_effect=err):
        _run_and_release_lock(tool, args)
    tool.state_manager._release_state_lock.assert_called_once()


# ---------------------------------------------------------------------------
# _acquire_or_bypass_lock — exceptions now surface
# ---------------------------------------------------------------------------


def test_acquire_or_bypass_lock_succeeds_when_lock_acquired():
    tool = _tool(acquired=True)
    args = _args()
    ok, code = _acquire_or_bypass_lock(tool, args)
    assert ok and code == 0


def test_acquire_or_bypass_lock_fails_without_force_on_contention(capsys):
    tool = _tool(acquired=False)
    args = _args(force=False)
    with patch("gdrive_cli._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_cli._check_pid_alive", return_value=""):
            ok, code = _acquire_or_bypass_lock(tool, args)
    assert not ok and code == 2


def test_acquire_or_bypass_lock_succeeds_with_force_on_contention(capsys):
    tool = _tool(acquired=False)
    args = _args(force=True)
    with patch("gdrive_cli._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_cli._check_pid_alive", return_value=" (not running)"):
            ok, code = _acquire_or_bypass_lock(tool, args)
    assert ok and code == 0


def test_acquire_or_bypass_lock_raises_on_filesystem_error():
    tool = MagicMock()
    tool.state_manager._acquire_state_lock.side_effect = OSError("disk error")
    args = _args()
    with pytest.raises(OSError, match="disk error"):
        _acquire_or_bypass_lock(tool, args)


def test_acquire_or_bypass_lock_stale_lock_no_force_emits_stale_message(capsys):
    tool = _tool(acquired=False)
    args = _args(force=False)
    with patch("gdrive_cli._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_cli._check_pid_alive", return_value=" (not running)"):
            ok, code = _acquire_or_bypass_lock(tool, args)
    err = capsys.readouterr().err
    assert not ok
    assert "stale" in err
