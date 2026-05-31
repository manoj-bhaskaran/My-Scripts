"""Unit tests for the gdrive_locking module.

Covers lock-management helpers extracted from gdrive_cli:
  - _check_pid_alive returns " (not running)" when PID is not alive
  - _print_lockfile_messages stale-lock and live-lock branches
  - _acquire_or_bypass_lock: immediate acquire, --force bypass, wait-loop paths
"""

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import pytest

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_locking import (  # noqa: E402
    _check_pid_alive,
    _print_lockfile_messages,
    _acquire_or_bypass_lock,
)
from gdrive_console import ConsoleHelper  # noqa: E402


def _tool(acquired=True, pid_alive=True):
    """Return a minimal mock tool with a state_manager."""
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.return_value = acquired
    tool.state_manager.pid_is_alive.return_value = pid_alive
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
    tool.state_manager.pid_is_alive.side_effect = OSError("permission denied")
    note = _check_pid_alive("1234", tool)
    assert note == ""


# ---------------------------------------------------------------------------
# _print_lockfile_messages
# ---------------------------------------------------------------------------


def test_print_lockfile_messages_stale_no_force_prints_stale_hint(capsys):
    args = _args()
    _print_lockfile_messages(args, ConsoleHelper(args), "999", "run-abc", " (not running)", False)
    err = capsys.readouterr().err
    assert "stale" in err
    assert "--force" in err


def test_print_lockfile_messages_live_no_force_prints_tip(capsys):
    args = _args()
    _print_lockfile_messages(args, ConsoleHelper(args), "999", "run-abc", "", False)
    err = capsys.readouterr().err
    assert "Tip:" in err
    assert "stale" not in err


def test_print_lockfile_messages_stale_with_force_prints_stale_warning(capsys):
    args = _args()
    _print_lockfile_messages(args, ConsoleHelper(args), "999", "run-abc", " (not running)", True)
    err = capsys.readouterr().err
    assert "stale" in err
    assert "WARN" in err


def test_print_lockfile_messages_live_with_force_prints_generic_bypass(capsys):
    args = _args()
    _print_lockfile_messages(args, ConsoleHelper(args), "999", "run-abc", "", True)
    err = capsys.readouterr().err
    assert "bypassing concurrent-run guardrail" in err
    assert "stale" not in err


# ---------------------------------------------------------------------------
# _acquire_or_bypass_lock
# ---------------------------------------------------------------------------


def test_acquire_or_bypass_lock_succeeds_when_lock_acquired():
    tool = _tool(acquired=True)
    args = _args()
    ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    assert ok and code == 0


def test_acquire_or_bypass_lock_fails_without_force_on_contention(capsys):
    tool = _tool(acquired=False)
    args = _args(force=False)
    with patch("gdrive_locking._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_locking._check_pid_alive", return_value=""):
            ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    assert not ok and code == 2


def test_acquire_or_bypass_lock_succeeds_with_force_on_contention(capsys):
    tool = _tool(acquired=False)
    args = _args(force=True)
    with patch("gdrive_locking._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_locking._check_pid_alive", return_value=" (not running)"):
            ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    assert ok and code == 0


def test_acquire_or_bypass_lock_raises_on_filesystem_error():
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.side_effect = OSError("disk error")
    args = _args()
    with pytest.raises(OSError, match="disk error"):
        _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))


def test_acquire_or_bypass_lock_stale_lock_no_force_emits_stale_message(capsys):
    tool = _tool(acquired=False)
    args = _args(force=False)
    with patch("gdrive_locking._read_lockfile_metadata", return_value=("999", "run-abc")):
        with patch("gdrive_locking._check_pid_alive", return_value=" (not running)"):
            ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    err = capsys.readouterr().err
    assert not ok
    assert "stale" in err


def test_acquire_or_bypass_lock_acquired_on_retry(capsys):
    """Lock fails on the first attempt but succeeds after one wait iteration."""
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.side_effect = [False, True]
    args = _args(lock_timeout=5.0)
    with patch("gdrive_locking.time") as mock_time:
        mock_time.time.side_effect = [100.0, 100.0, 100.0, 100.0]
        mock_time.sleep = MagicMock()
        ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    assert ok and code == 0
    mock_time.sleep.assert_called_once()


def test_acquire_or_bypass_lock_wait_loop_integer_remaining_display(capsys):
    """When remaining time is a whole number, display uses integer format ('5s')."""
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.side_effect = [False, True]
    args = _args(lock_timeout=5.0)
    with patch("gdrive_locking.time") as mock_time:
        mock_time.time.side_effect = [100.0, 100.0, 100.0, 100.0]
        mock_time.sleep = MagicMock()
        _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    err = capsys.readouterr().err
    assert "remaining 5s" in err


def test_acquire_or_bypass_lock_wait_loop_fractional_remaining_display(capsys):
    """When remaining time is fractional, display uses one-decimal format ('2.7s')."""
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.side_effect = [False, True]
    args = _args(lock_timeout=5.0)
    with patch("gdrive_locking.time") as mock_time:
        mock_time.time.side_effect = [100.0, 102.3, 102.3, 102.3]
        mock_time.sleep = MagicMock()
        _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    err = capsys.readouterr().err
    assert "remaining 2.7s" in err


def test_acquire_or_bypass_lock_timeout_expires_returns_failure(capsys):
    """When lock_timeout expires without acquiring, returns False with code 2."""
    tool = MagicMock()
    tool.state_manager.acquire_state_lock.side_effect = [False, False]
    args = _args(lock_timeout=5.0, force=False)
    with patch("gdrive_locking.time") as mock_time:
        mock_time.time.side_effect = [100.0, 100.0, 100.0, 106.0]
        mock_time.sleep = MagicMock()
        with patch("gdrive_locking._read_lockfile_metadata", return_value=("999", "run-abc")):
            with patch("gdrive_locking._check_pid_alive", return_value=""):
                ok, code = _acquire_or_bypass_lock(tool, args, ConsoleHelper(args))
    assert not ok and code == 2
