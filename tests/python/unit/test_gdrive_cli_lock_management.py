"""Unit tests for lock-adjacent helpers that remain in gdrive_cli.

Covers:
  - _run_and_release_lock dispatches all commands through _run_tool
  - _apply_retry_failed_file empty-CSV error (issue #1133)

Lock-management helpers (_check_pid_alive, _print_lockfile_messages,
_acquire_or_bypass_lock) have been extracted to gdrive_locking and are
tested in test_gdrive_locking.py.
"""

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import pytest

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

sys.modules["gdrive_recover"] = MagicMock()
from gdrive_cli import (  # noqa: E402
    _run_and_release_lock,
    _apply_retry_failed_file,
)
from gdrive_console import ConsoleHelper  # noqa: E402
from gdrive_state import StateScopeMismatchError  # noqa: E402
from gdrive_models import RecoveryStateScope  # noqa: E402

del sys.modules["gdrive_recover"]


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
# _run_and_release_lock — dispatch through _run_tool unconditionally
# ---------------------------------------------------------------------------


def test_run_and_release_lock_dry_run_calls_run_tool():
    tool = _tool()
    args = _args(command="dry-run", mode="dry_run")
    with patch("gdrive_cli._run_tool", return_value=True) as mock_run:
        result = _run_and_release_lock(tool, args, ConsoleHelper(args))
    mock_run.assert_called_once_with(tool, args)
    assert result == 0


def test_run_and_release_lock_recover_only_calls_run_tool():
    tool = _tool()
    args = _args(command="recover-only", mode="recover_only")
    with patch("gdrive_cli._run_tool", return_value=True) as mock_run:
        result = _run_and_release_lock(tool, args, ConsoleHelper(args))
    mock_run.assert_called_once_with(tool, args)
    assert result == 0


def test_run_and_release_lock_returns_1_on_run_tool_false():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=False):
        result = _run_and_release_lock(tool, args, ConsoleHelper(args))
    assert result == 1


def test_run_and_release_lock_releases_lock_on_success():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=True):
        _run_and_release_lock(tool, args, ConsoleHelper(args))
    tool.state_manager.release_state_lock.assert_called_once()


def test_run_and_release_lock_releases_lock_on_failure():
    tool = _tool()
    args = _args()
    with patch("gdrive_cli._run_tool", return_value=False):
        _run_and_release_lock(tool, args, ConsoleHelper(args))
    tool.state_manager.release_state_lock.assert_called_once()


def test_run_and_release_lock_scope_mismatch_returns_2(capsys):
    tool = _tool()
    args = _args(no_emoji=True)
    err = StateScopeMismatchError(RecoveryStateScope(), RecoveryStateScope())
    with patch("gdrive_cli._run_tool", side_effect=err):
        result = _run_and_release_lock(tool, args, ConsoleHelper(args))
    assert result == 2
    tool.state_manager.release_state_lock.assert_called_once()


def test_run_and_release_lock_releases_lock_even_on_scope_mismatch(capsys):
    tool = _tool()
    args = _args(no_emoji=True)
    err = StateScopeMismatchError(RecoveryStateScope(), RecoveryStateScope())
    with patch("gdrive_cli._run_tool", side_effect=err):
        _run_and_release_lock(tool, args, ConsoleHelper(args))
    tool.state_manager.release_state_lock.assert_called_once()


# ---------------------------------------------------------------------------
# _apply_retry_failed_file — empty-CSV error message (issue #1133)
# ---------------------------------------------------------------------------


def test_apply_retry_failed_file_empty_csv_error_on_stderr(tmp_path, capsys):
    """Empty retry CSV emits a single error to stderr and returns exit code 1."""
    csv_file = tmp_path / "empty.csv"
    csv_file.write_text("source_folder_id,file_id,target_path\n")
    args = _args(retry_failed_file=str(csv_file), failed_file="")
    ok, code = _apply_retry_failed_file(args, ConsoleHelper(args))
    assert not ok and code == 1
    err = capsys.readouterr().err
    assert "nothing to retry" in err
    # Confirm no duplicate message on stdout
    assert capsys.readouterr().out == ""
