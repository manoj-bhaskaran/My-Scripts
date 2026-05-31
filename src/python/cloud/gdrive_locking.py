"""Lock-management helpers for the Google Drive recovery CLI."""

import sys
import time
from typing import Tuple

from gdrive_console import ConsoleHelper


def _read_lockfile_metadata(lockfile_path):
    """Read PID and run_id from the lockfile, return (owner_pid, run_id)."""
    owner_pid = "unknown"
    run_id = "unknown"
    try:
        with open(lockfile_path, "r") as fh:
            for line in fh.read().splitlines():
                if line.startswith("pid="):
                    owner_pid = line.split("=", 1)[1].strip()
                if line.startswith("run_id="):
                    run_id = line.split("=", 1)[1].strip()
    except Exception:
        pass
    return owner_pid, run_id


def _print_lockfile_messages(args, console, owner_pid, run_id, pid_alive_note, force):
    """Print user-facing messages about lockfile status."""
    console.print_err(f"Another run appears to be active for state '{args.state_file}'.")
    print(f"   Owner PID: {owner_pid}{pid_alive_note}   Run-ID: {run_id}", file=sys.stderr)
    if "(not running)" in pid_alive_note:
        print(
            "   The lock looks stale. If you're sure the previous process is gone, rerun with --force to take over.",
            file=sys.stderr,
        )
    else:
        print(
            "   Tip: If that run is still working, let it finish. Otherwise, confirm it's stopped and rerun with --force.",
            file=sys.stderr,
        )
    if force:
        if "(not running)" in pid_alive_note:
            console.print_warn(
                "--force supplied: taking over a **stale** lock (previous PID not detected)."
            )
        else:
            console.print_warn("--force supplied: bypassing concurrent-run guardrail.")


def _check_pid_alive(owner_pid, tool):
    """Check if the recorded PID is alive, return a note string."""
    pid_alive_note = ""
    try:
        pid_int = int(owner_pid)
        alive = tool.state_manager.pid_is_alive(pid_int)
        if not alive:
            pid_alive_note = " (not running)"
    except Exception:
        pass
    return pid_alive_note


def _acquire_or_bypass_lock(tool, args, console: ConsoleHelper) -> Tuple[bool, int]:
    start_wait = time.time()
    timeout = float(getattr(args, "lock_timeout", 0.0) or 0.0)
    poll = 0.5
    acquired = tool.state_manager.acquire_state_lock()
    while (not acquired) and timeout > 0 and (time.time() - start_wait) < timeout:
        remaining = max(0.0, timeout - (time.time() - start_wait))
        if remaining.is_integer():
            remaining_str = f"{int(remaining)}s"
        else:
            remaining_str = f"{remaining:.1f}s"
        print(f"Waiting for state lock (remaining {remaining_str})...", file=sys.stderr)
        time.sleep(poll)
        acquired = tool.state_manager.acquire_state_lock()
    if not acquired:
        lockfile_path = f"{args.state_file}.lock"
        owner_pid, run_id = _read_lockfile_metadata(lockfile_path)
        pid_alive_note = _check_pid_alive(owner_pid, tool)
        force = getattr(args, "force", False)
        if not force:
            _print_lockfile_messages(args, console, owner_pid, run_id, pid_alive_note, False)
            return False, 2
        else:
            _print_lockfile_messages(args, console, owner_pid, run_id, pid_alive_note, True)
    return True, 0
