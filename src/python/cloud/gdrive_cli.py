"""CLI layer for Google Drive Trash Recovery Tool."""

import argparse
import json
import logging
import os
import sys
import time
from datetime import timezone
from pathlib import Path
from typing import Tuple

from dateutil import parser as date_parser

from gdrive_validators import validate_extensions, normalize_policy_token
from gdrive_constants import (
    VERSION,
    EXTENSION_MIME_TYPES,
    DEFAULT_BURST,
    DEFAULT_HTTP_POOL_MAXSIZE,
    DEFAULT_HTTP_TRANSPORT,
    DEFAULT_LOG_FILE,
    DEFAULT_MAX_RPS,
    DEFAULT_PROCESS_BATCH,
    DEFAULT_STATE_FILE,
    DEFAULT_WORKERS,
)
from gdrive_models import PostRestorePolicy
from gdrive_recover import DriveTrashRecoveryTool

__version__ = VERSION


def create_parser():
    parser = argparse.ArgumentParser(
        description=f"Google Drive Trash Recovery Tool v{__version__}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=r"""
Examples:
    %(prog)s dry-run --extensions jpg png --no-emoji
    %(prog)s recover-only --extensions pdf docx
    %(prog)s recover-and-download --download-dir ./recovered --post-restore-policy retain
    %(prog)s recover-and-download --download-dir ./recovered --state-file ./state.json

Policies: trash (default), retain, delete
For compatibility matrix, transport notes, and performance presets: see README.md and CHANGELOG.md.
""",
    )

    subparsers = parser.add_subparsers(dest="command", help="Operation mode")
    dry_run_parser = subparsers.add_parser(
        "dry-run", help="Show execution plan without making changes"
    )
    recover_parser = subparsers.add_parser("recover-only", help="Recover files from trash only")
    download_parser = subparsers.add_parser(
        "recover-and-download", help="Recover and download files"
    )
    download_parser.add_argument(
        "--download-dir", required=True, help="Local directory for downloads"
    )

    for subparser in [dry_run_parser, recover_parser, download_parser]:
        subparser.add_argument(
            "--no-emoji",
            action="store_true",
            help="Disable emoji in console output (use ASCII labels instead)",
        )
        subparser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
        subparser.add_argument(
            "--extensions", nargs="+", help="File extensions to filter (e.g., jpg png pdf)"
        )
        subparser.add_argument(
            "--after-date", help="Only process files trashed after this date (ISO format)"
        )
        subparser.add_argument("--file-ids", nargs="+", help="Process only specific file IDs")
        subparser.add_argument(
            "--folder-id",
            help=(
                "Scope operation to this Drive folder ID and all its subfolders. "
                "Discovers non-trashed files only; local subfolder hierarchy is reconstructed "
                "under --download-dir. Use --post-restore-policy retain to leave files in Drive."
            ),
        )
        subparser.add_argument(
            "--post-restore-policy",
            default=PostRestorePolicy.TRASH,
            help="Post-download handling in Drive (aliases accepted): retain|trash|delete",
        )
        subparser.add_argument(
            "--concurrency",
            type=int,
            default=DEFAULT_WORKERS,
            help="Number of concurrent operations",
        )
        subparser.add_argument(
            "--max-rps",
            type=float,
            default=DEFAULT_MAX_RPS,
            help="Max Drive API requests per second (0 = disable throttling)",
        )
        subparser.add_argument(
            "--burst",
            type=int,
            default=DEFAULT_BURST,
            help="Token-bucket burst capacity (opt-in). 0 = disabled (fixed pacing only)",
        )
        subparser.add_argument(
            "--debug-parity",
            action="store_true",
            help="Enable validation/discovery parity checks (diagnostic logging)",
        )
        subparser.add_argument(
            "--clear-id-cache",
            action="store_true",
            help="Clear file-id caches after validation (avoid cache reuse across phases)",
        )
        subparser.add_argument(
            "--fail-on-parity-mismatch",
            action="store_true",
            help="Exit non-zero if a parity mismatch is detected (use with --debug-parity; useful in CI)",
        )
        subparser.add_argument(
            "--parity-metrics-file", help="Write parity metrics JSON to this path"
        )
        subparser.add_argument(
            "--strict-policy",
            action="store_true",
            help="Treat unknown post-restore policy tokens as an error",
        )
        subparser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Cap the number of items to discover/process (0 = no cap)",
        )
        subparser.add_argument(
            "--state-file", default=DEFAULT_STATE_FILE, help="State file for resume capability"
        )
        subparser.add_argument(
            "--process-batch-size",
            type=int,
            default=DEFAULT_PROCESS_BATCH,
            help="Streaming batch size for execution; items are processed and released per-batch",
        )
        subparser.add_argument("--log-file", default=DEFAULT_LOG_FILE, help="Log file path")
        subparser.add_argument(
            "--verbose",
            "-v",
            action="count",
            default=0,
            help="Increase verbosity (-v for INFO, -vv for DEBUG)",
        )
        subparser.add_argument(
            "--yes", "-y", action="store_true", help="Skip confirmation prompts (for automation)"
        )
        subparser.add_argument(
            "--client-per-thread",
            dest="client_per_thread",
            action="store_true",
            default=True,
            help="Build a Drive API client per worker thread (default ON)",
        )
        subparser.add_argument(
            "--single-client",
            dest="client_per_thread",
            action="store_false",
            help="Use a single shared Drive API client (advanced)",
        )
        subparser.add_argument(
            "--rl-diagnostics",
            action="store_true",
            help="Emit sampled rate-limiter stats at DEBUG level",
        )
        subparser.add_argument(
            "--http-transport",
            choices=["auto", "httplib2", "requests"],
            default=DEFAULT_HTTP_TRANSPORT,
            help=(
                "HTTP transport implementation. "
                "'auto' tries requests (with pooling) and falls back to httplib2. "
                "To enable pooling explicitly: pip install requests google-auth[requests] "
                "and pass --http-transport requests."
            ),
        )
        subparser.add_argument(
            "--http-pool-maxsize",
            type=int,
            default=DEFAULT_HTTP_POOL_MAXSIZE,
            help=(
                "When using requests transport, sets per-thread session pool size. "
                "Rationale: effective pool ≈ min(--concurrency, --http-pool-maxsize). "
                "This is a heuristic for documentation only; code unchanged."
            ),
        )
        subparser.add_argument(
            "--force",
            action="store_true",
            help="Bypass concurrent-run guardrail when the lockfile is held",
        )
        subparser.add_argument(
            "--lock-timeout",
            type=float,
            default=0.0,
            help="If the state lock is held, wait up to this many seconds for it to be released (0 = no wait)",
        )
    download_parser.add_argument(
        "--direct-download",
        action="store_true",
        help=(
            'Write bytes directly to the final filename (no ".partial" and no rename). '
            "This can avoid destination-lock races from AV/thumbnailers/OneDrive, "
            "but an interruption may leave a partially written file."
        ),
    )
    return parser


def _set_mode(args) -> None:
    mode_map = {
        "dry-run": "dry_run",
        "recover-only": "recover_only",
        "recover-and-download": "recover_and_download",
    }
    args.mode = mode_map.get(args.command)


def _use_emoji(args) -> bool:
    return not getattr(args, "no_emoji", False)


def _sym_fail(args) -> str:
    return "❌" if _use_emoji(args) else "ERROR"


def _sym_warn(args) -> str:
    return "⚠️" if _use_emoji(args) else "WARN"


def _sym_info(args) -> str:
    return "ℹ️" if _use_emoji(args) else "INFO"


def _validate_concurrency_arg(args) -> Tuple[bool, int]:
    try:
        cpu = os.cpu_count() or 1
    except Exception:
        cpu = 1
    ceiling = min(cpu * 4, 64)
    if args.concurrency < 1:
        print(f"{_sym_fail(args)} Invalid --concurrency value. It must be >= 1.")
        return False, 2
    if args.concurrency > ceiling:
        print(
            f"WARN --concurrency {args.concurrency} is high; capping to {ceiling} to avoid resource exhaustion and 429s."
        )
        args.concurrency = ceiling
    return True, 0


def _validate_download_dir_arg(args) -> Tuple[bool, int]:
    if getattr(args, "mode", None) != "recover_and_download":
        return True, 0
    try:
        p = Path(args.download_dir)
        if p.exists() and not p.is_dir():
            print(f"ERROR --download-dir points to a file: {p}", file=sys.stderr)
            return False, 2
        p.mkdir(parents=True, exist_ok=True)
        probe = p / ".write_test"
        try:
            probe.write_text("ok")
        finally:
            try:
                if probe.exists():
                    probe.unlink()
            except Exception:
                pass
        return True, 0
    except Exception as e:
        print(f"ERROR --download-dir is not writable or cannot be created: {e}", file=sys.stderr)
        return False, 2


def _validate_after_date_arg(args) -> Tuple[bool, int]:
    if not getattr(args, "after_date", None):
        return True, 0
    try:
        parsed = date_parser.parse(args.after_date)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        args.after_date = parsed.isoformat()
        return True, 0
    except Exception as e:
        print(f"ERROR Invalid --after-date value '{args.after_date}': {e}", file=sys.stderr)
        return False, 2


def _run_tool(tool: "DriveTrashRecoveryTool", args) -> bool:
    return tool.dry_run() if args.mode == "dry_run" else tool.execute_recovery()


def _normalize_and_validate_policy(args) -> Tuple[bool, int]:
    """Normalize and validate post-restore policy, print errors/warnings, update args."""
    strict_env = os.getenv("GDRT_STRICT_POLICY", "").strip().lower()
    strict_from_env = strict_env in ("1", "true", "yes", "on")
    effective_strict = bool(getattr(args, "strict_policy", False) or strict_from_env)
    norm_policy, policy_warnings, policy_errors, telemetry = normalize_policy_token(
        args.post_restore_policy,
        strict=effective_strict,
        aliases=PostRestorePolicy.ALIASES,
        default_value=PostRestorePolicy.TRASH,
    )
    try:
        if telemetry and "unknown_policy" in telemetry:
            logging.getLogger(__name__).info(
                "METRIC %s",
                json.dumps(
                    {
                        "metric": "unknown_policy_token",
                        **telemetry["unknown_policy"],
                    }
                ),
            )
    except Exception:
        pass
    if policy_errors:
        for msg in policy_errors:
            print(f"{_sym_fail(args)} {msg}", file=sys.stderr)
            try:
                logging.getLogger(__name__).error(msg)
            except Exception:
                pass
        return False, 2
    for msg in policy_warnings:
        print(f"{_sym_warn(args)} {msg}", file=sys.stderr)
        try:
            logging.getLogger(__name__).warning(msg)
        except Exception:
            pass
        if not hasattr(args, "_policy_warning_message"):
            args._policy_warning_message = msg
    args.post_restore_policy = norm_policy
    return True, 0


def _normalize_and_validate_extensions(args) -> Tuple[bool, int]:
    cleaned_exts, ext_warnings, ext_errors = validate_extensions(
        getattr(args, "extensions", None),
        EXTENSION_MIME_TYPES,
    )
    if ext_errors:
        for msg in ext_errors:
            print(f"ERROR {msg}", file=sys.stderr)
        print("   Use space-separated extensions like: --extensions jpg png pdf tar.gz min.js")
        print("   Do not include wildcards, commas, spaces, or path characters.")
        return False, 2
    for msg in ext_warnings:
        print(f"{_sym_info(args)} {msg}")
    args.extensions = cleaned_exts
    return True, 0


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


def _print_lockfile_messages(args, owner_pid, run_id, pid_alive_note, force):
    """Print user-facing messages about lockfile status."""
    print(f"ERROR Another run appears to be active for state '{args.state_file}'.", file=sys.stderr)
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
            print(
                "WARN --force supplied: taking over a **stale** lock (previous PID not detected).",
                file=sys.stderr,
            )
        else:
            print("WARN --force supplied: bypassing concurrent-run guardrail.", file=sys.stderr)


def _check_pid_alive(owner_pid, tool):
    """Check if the recorded PID is alive, return a note string."""
    pid_alive_note = ""
    try:
        pid_int = int(owner_pid)
        alive = tool.state_manager._pid_is_alive(pid_int)
        if not alive:
            pid_alive_note = " (note: recorded PID not confirmed; may not be running)"
    except Exception:
        pass
    return pid_alive_note


def _acquire_or_bypass_lock(tool, args) -> Tuple[bool, int]:
    try:
        start_wait = time.time()
        timeout = float(getattr(args, "lock_timeout", 0.0) or 0.0)
        poll = 0.5
        acquired = tool.state_manager._acquire_state_lock()
        while (not acquired) and timeout > 0 and (time.time() - start_wait) < timeout:
            remaining = max(0.0, timeout - (time.time() - start_wait))
            if int(remaining) == remaining:
                remaining_str = f"{int(remaining)}s"
            else:
                remaining_str = f"{remaining:.1f}s"
            print(f"Waiting for state lock (remaining {remaining_str})...", file=sys.stderr)
            time.sleep(poll)
            acquired = tool.state_manager._acquire_state_lock()
        if not acquired:
            lockfile_path = f"{args.state_file}.lock"
            owner_pid, run_id = _read_lockfile_metadata(lockfile_path)
            pid_alive_note = _check_pid_alive(owner_pid, tool)
            force = getattr(args, "force", False)
            if not force:
                _print_lockfile_messages(args, owner_pid, run_id, pid_alive_note, False)
                return False, 2
            else:
                _print_lockfile_messages(args, owner_pid, run_id, pid_alive_note, True)
    except Exception:
        pass
    return True, 0


def _validate_folder_id_args(args) -> Tuple[bool, int]:
    """Reject flag combinations that are incompatible with --folder-id."""
    if not getattr(args, "folder_id", None):
        return True, 0
    if getattr(args, "file_ids", None):
        print(
            f"{_sym_fail(args)} --folder-id and --file-ids are mutually exclusive. "
            "Use one source at a time.",
            file=sys.stderr,
        )
        return False, 2
    if getattr(args, "mode", None) == "recover_only":
        print(
            f"{_sym_fail(args)} --folder-id cannot be used with recover-only: "
            "folder-scoped files are not in trash so no action would be taken, "
            "and items would still be recorded as processed in the state file. "
            "Use recover-and-download with --post-restore-policy retain instead.",
            file=sys.stderr,
        )
        return False, 2
    return True, 0


def _validate_file_ids_if_present(tool, args) -> Tuple[bool, int]:
    if hasattr(args, "file_ids") and args.file_ids:
        ok = tool._validate_file_ids()
        if not ok:
            return False, 2
    return True, 0


def _run_and_release_lock(tool, args) -> int:
    ran_ok = False
    try:
        if args.command == "dry-run":
            ran_ok = _run_tool(tool, args)
        else:
            ran_ok = tool.execute_recovery()
    finally:
        try:
            tool.state_manager._release_state_lock()
        except Exception:
            pass
    return 0 if ran_ok else 1


def main() -> int:
    parser = create_parser()
    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 2

    _set_mode(args)

    ok, code = _normalize_and_validate_policy(args)
    if not ok:
        return code

    ok, code = _validate_folder_id_args(args)
    if not ok:
        return code

    if getattr(args, "folder_id", None) and args.post_restore_policy == PostRestorePolicy.TRASH:
        print(
            f"{_sym_warn(args)} --folder-id is set with the default post-restore-policy 'trash'. "
            "Files will be moved to Drive Trash after downloading. "
            "Use --post-restore-policy retain to leave them in place.",
            file=sys.stderr,
        )

    ok, code = _validate_concurrency_arg(args)
    if not ok:
        return code

    ok, code = _validate_download_dir_arg(args)
    if not ok:
        return code

    ok, code = _validate_after_date_arg(args)
    if not ok:
        return code

    ok, code = _normalize_and_validate_extensions(args)
    if not ok:
        return code

    tool = DriveTrashRecoveryTool(args)

    ok, code = _acquire_or_bypass_lock(tool, args)
    if not ok:
        return code

    ok, code = _validate_file_ids_if_present(tool, args)
    if not ok:
        return code

    return _run_and_release_lock(tool, args)
