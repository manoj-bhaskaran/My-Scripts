"""CLI layer for Google Drive Trash Recovery Tool."""

import argparse
import csv
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Tuple

from dateutil import parser as date_parser

_CLOUD_DIR = Path(__file__).resolve().parent
_PYTHON_SRC_DIR = _CLOUD_DIR.parent
if str(_PYTHON_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_PYTHON_SRC_DIR))
from modules.utils.file_operations import ensure_directory, is_writable

from gdrive_console import ConsoleHelper
from gdrive_validators import validate_extensions, normalize_policy_token
from gdrive_constants import (
    VERSION,
    HELP_EPILOG,
    EXTENSION_MIME_TYPES,
    DEFAULT_BURST,
    DEFAULT_FAILED_FILE,
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
from gdrive_state import StateScopeMismatchError

__version__ = VERSION


def create_parser():
    parser = argparse.ArgumentParser(
        description=f"Google Drive Trash Recovery Tool v{__version__}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=HELP_EPILOG,
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
    dry_run_parser.add_argument(
        "--download-dir",
        default=None,
        help="Local directory for downloads (optional; shown in plan output when provided)",
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
        subparser.add_argument(
            "--log-file",
            default=DEFAULT_LOG_FILE,
            help=(
                "Write a detailed DEBUG-level log to this file.  "
                "The file and its parent directory are created automatically.  "
                "Optional: omit to disable file logging (console verbosity is unaffected)."
            ),
        )
        subparser.add_argument(
            "--failed-file",
            default=DEFAULT_FAILED_FILE,
            help=(
                "Append the local path (or Drive name for recover-only) of every failed item "
                "to this file, one entry per line.  "
                "The file and its parent directory are created automatically.  "
                "When --fresh-run is set the file is truncated before the run starts.  "
                "Optional: omit to disable."
            ),
        )
        subparser.add_argument(
            "--timestamped-output",
            action="store_true",
            help=(
                "Append a run timestamp (YYYYMMDD_HHMMSS_ffffff, microsecond "
                "precision) to the --log-file and --failed-file names so every "
                "run writes to its own files, even when explicit paths are "
                "provided and runs start within the same second. The timestamp "
                "is inserted before the file extension "
                "(e.g. run.log -> run_20260517_142530_123456.log). "
                "Paths that are left disabled (empty) are unaffected."
            ),
        )
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
    # --fresh-run is intentionally NOT added to dry-run: dry-run is preview-only
    # and never calls _prepare_recovery, so the flag would be silently ignored
    # and mislead users. Limit to the two state-mutating subcommands.
    for subparser in [recover_parser, download_parser]:
        subparser.add_argument(
            "--fresh-run",
            action="store_true",
            help=(
                "Start a fresh run: ignore prior progress in the state file, "
                "regenerate run identity (run_id/start_time) and the saved "
                "scope, and (if --failed-file is set) truncate it. Also "
                "bypasses the scope-mismatch guard, letting you reuse a state "
                "file under a different source/command. Mutually exclusive "
                "with --retry-failed-file."
            ),
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
    collision_group = download_parser.add_mutually_exclusive_group()
    collision_group.add_argument(
        "--overwrite",
        action="store_true",
        help=(
            "Overwrite existing local files instead of generating a conflict-safe name. "
            "By default, if a file already exists at the target path a short unique suffix "
            "is appended; this flag disables that behaviour and replaces the existing file. "
            "Mutually exclusive with --skip-existing."
        ),
    )
    collision_group.add_argument(
        "--skip-existing",
        action="store_true",
        help=(
            "Skip the download if a file already exists at the target path. The item is "
            "still counted as a successful operation (post-restore policy is applied as "
            "usual) but no bytes are written and the existing file is left untouched. "
            "Skips are reported in the summary under 'Files skipped (already on disk)'. "
            "Mutually exclusive with --overwrite. Without either flag, the default "
            "behaviour appends a short unique suffix to avoid the collision."
        ),
    )
    download_parser.add_argument(
        "--retry-failed-file",
        default="",
        help=(
            "Path to a failed-items CSV produced by a previous run (via --failed-file). "
            "When supplied, only the file IDs listed in the CSV are downloaded; "
            "the saved target paths from the CSV are used so files land in the same "
            "locations they would have in the original run. "
            "Mutually exclusive with --file-ids and --folder-id."
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


def _validate_concurrency_arg(args) -> Tuple[bool, int]:
    console = ConsoleHelper(args)
    try:
        cpu = os.cpu_count() or 1
    except Exception:
        cpu = 1
    ceiling = min(cpu * 4, 64)
    if args.concurrency < 1:
        print(
            f"{console.sym_fail()} Invalid --concurrency value. It must be >= 1.", file=sys.stderr
        )
        return False, 2
    if args.concurrency > ceiling:
        print(
            f"{console.sym_warn()} --concurrency {args.concurrency} is high; capping to {ceiling} to avoid resource exhaustion and 429s.",
            file=sys.stderr,
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
        ensure_directory(p)
        if not is_writable(p):
            print(f"ERROR --download-dir is not writable: {p}", file=sys.stderr)
            return False, 2
        return True, 0
    except Exception as e:
        print(f"ERROR --download-dir is not writable or cannot be created: {e}", file=sys.stderr)
        return False, 2


def _apply_timestamped_output(args) -> None:
    """When --timestamped-output is set, append a single run timestamp to the
    --log-file and --failed-file names so each run writes to its own files even
    when explicit/default paths are provided.

    The same timestamp is applied to both files so a run's log and failed-file
    share a correlatable suffix. The suffix includes microsecond precision
    (``YYYYMMDD_HHMMSS_ffffff``) so rapid sequential or parallel runs sharing
    the same base paths do not collide on a whole-second boundary. It is
    inserted before the final extension (``run.log`` ->
    ``run_20260517_142530_123456.log``); extension-less names just get the
    suffix appended. Disabled (empty) paths are left untouched so the feature
    never silently enables logging or failure tracking.
    """
    if not getattr(args, "timestamped_output", False):
        return
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")

    def _stamp(path_str: str) -> str:
        if not path_str:
            return path_str
        p = Path(path_str)
        return str(p.with_name(f"{p.stem}_{stamp}{p.suffix}"))

    args.log_file = _stamp(getattr(args, "log_file", "") or "")
    args.failed_file = _stamp(getattr(args, "failed_file", "") or "")


def _validate_failed_file_arg(args) -> Tuple[bool, int]:
    path_str = getattr(args, "failed_file", None) or ""
    if not path_str:
        return True, 0
    try:
        p = Path(path_str)
        if p.exists() and not p.is_file():
            print(f"ERROR --failed-file points to a non-file path: {p}", file=sys.stderr)
            return False, 2
        ensure_directory(p.parent)
        return True, 0
    except Exception as e:
        print(f"ERROR --failed-file path is not usable: {e}", file=sys.stderr)
        return False, 2


def _validate_retry_failed_file_arg(args) -> Tuple[bool, int]:
    """Validate --retry-failed-file and check it is not combined with conflicting flags."""
    path_str = getattr(args, "retry_failed_file", None) or ""
    if not path_str:
        return True, 0
    p = Path(path_str)
    if not p.exists():
        print(f"ERROR --retry-failed-file path does not exist: {p}", file=sys.stderr)
        return False, 2
    if not p.is_file():
        print(f"ERROR --retry-failed-file must be a file, not a directory: {p}", file=sys.stderr)
        return False, 2
    if getattr(args, "file_ids", None):
        print(
            "ERROR --retry-failed-file and --file-ids are mutually exclusive.",
            file=sys.stderr,
        )
        return False, 2
    if getattr(args, "folder_id", None):
        print(
            "ERROR --retry-failed-file and --folder-id are mutually exclusive.",
            file=sys.stderr,
        )
        return False, 2
    if getattr(args, "fresh_run", False):
        print(
            "ERROR --retry-failed-file and --fresh-run are mutually exclusive "
            "(fresh-run starts from nothing; retry resumes a specific list).",
            file=sys.stderr,
        )
        return False, 2
    failed_out = getattr(args, "failed_file", None) or ""
    if failed_out and Path(failed_out).resolve() == p.resolve():
        print(
            "ERROR --failed-file and --retry-failed-file cannot point to the same path "
            "(reading and writing the same CSV in one run would corrupt it).",
            file=sys.stderr,
        )
        return False, 2
    return True, 0


def _load_retry_failed_file(
    path_str: str,
    args,
) -> Tuple[bool, int, Dict[str, str]]:
    """Read a failed-items CSV and return (ok, exit_code, {file_id: target_path}).

    Expected columns: source_folder_id, file_id, target_path
    The header row is skipped automatically.
    """
    console = ConsoleHelper(args)
    target_path_overrides: Dict[str, str] = {}
    try:
        with open(path_str, newline="", encoding="utf-8") as fh:
            reader = csv.DictReader(fh)
            if reader.fieldnames is None or "file_id" not in reader.fieldnames:
                print(
                    f"{console.sym_fail()} --retry-failed-file does not look like a valid failed-items CSV "
                    f"(missing 'file_id' column): {path_str}",
                    file=sys.stderr,
                )
                return False, 2, {}
            for row in reader:
                fid = (row.get("file_id") or "").strip()
                tp = (row.get("target_path") or "").strip()
                if fid:
                    target_path_overrides[fid] = tp
    except Exception as e:
        print(
            f"{console.sym_fail()} Could not read --retry-failed-file '{path_str}': {e}",
            file=sys.stderr,
        )
        return False, 2, {}
    return True, 0, target_path_overrides


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
    console = ConsoleHelper(args)
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
            print(f"{console.sym_fail()} {msg}", file=sys.stderr)
            try:
                logging.getLogger(__name__).error(msg)
            except Exception:
                pass
        return False, 2
    for msg in policy_warnings:
        print(f"{console.sym_warn()} {msg}", file=sys.stderr)
        try:
            logging.getLogger(__name__).warning(msg)
        except Exception:
            pass
        if not hasattr(args, "_policy_warning_message"):
            args._policy_warning_message = msg
    args.post_restore_policy = norm_policy
    return True, 0


def _normalize_and_validate_extensions(args) -> Tuple[bool, int]:
    console = ConsoleHelper(args)
    cleaned_exts, ext_warnings, ext_errors = validate_extensions(
        getattr(args, "extensions", None),
        EXTENSION_MIME_TYPES,
    )
    if ext_errors:
        for msg in ext_errors:
            print(f"{console.sym_fail()} {msg}", file=sys.stderr)
        print("   Use space-separated extensions like: --extensions jpg png pdf tar.gz min.js")
        print("   Do not include wildcards, commas, spaces, or path characters.")
        return False, 2
    for msg in ext_warnings:
        print(f"{console.sym_info()} {msg}")
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
    console = ConsoleHelper(args)
    print(
        f"{console.sym_fail()} Another run appears to be active for state '{args.state_file}'.",
        file=sys.stderr,
    )
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
                f"{console.sym_warn()} --force supplied: taking over a **stale** lock (previous PID not detected).",
                file=sys.stderr,
            )
        else:
            print(
                f"{console.sym_warn()} --force supplied: bypassing concurrent-run guardrail.",
                file=sys.stderr,
            )


def _check_pid_alive(owner_pid, tool):
    """Check if the recorded PID is alive, return a note string."""
    pid_alive_note = ""
    try:
        pid_int = int(owner_pid)
        alive = tool.state_manager._pid_is_alive(pid_int)
        if not alive:
            pid_alive_note = " (not running)"
    except Exception:
        pass
    return pid_alive_note


def _acquire_or_bypass_lock(tool, args) -> Tuple[bool, int]:
    start_wait = time.time()
    timeout = float(getattr(args, "lock_timeout", 0.0) or 0.0)
    poll = 0.5
    acquired = tool.state_manager._acquire_state_lock()
    while (not acquired) and timeout > 0 and (time.time() - start_wait) < timeout:
        remaining = max(0.0, timeout - (time.time() - start_wait))
        if remaining.is_integer():
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
    return True, 0


def _validate_folder_id_args(args) -> Tuple[bool, int]:
    """Reject flag combinations that are incompatible with --folder-id."""
    if not getattr(args, "folder_id", None):
        return True, 0
    console = ConsoleHelper(args)
    if getattr(args, "file_ids", None):
        print(
            f"{console.sym_fail()} --folder-id and --file-ids are mutually exclusive. "
            "Use one source at a time.",
            file=sys.stderr,
        )
        return False, 2
    if getattr(args, "mode", None) == "recover_only":
        print(
            f"{console.sym_fail()} --folder-id cannot be used with recover-only: "
            "folder-scoped files are not in trash so no action would be taken, "
            "and items would still be recorded as processed in the state file. "
            "Use recover-and-download with --post-restore-policy retain instead.",
            file=sys.stderr,
        )
        return False, 2
    if getattr(args, "post_restore_policy", PostRestorePolicy.TRASH) == PostRestorePolicy.TRASH:
        print(
            f"{console.sym_warn()} --folder-id is set with the default post-restore-policy 'trash'. "
            "Files will be moved to Drive Trash after downloading. "
            "Use --post-restore-policy retain to leave them in place.",
            file=sys.stderr,
        )
    return True, 0


def _apply_retry_failed_file(args) -> Tuple[bool, int]:
    """Load the retry CSV and wire up args for a retry run.

    When --retry-failed-file is absent, sets safe defaults and returns True.
    When present, validates the path, loads file IDs and target-path overrides,
    and sets args._retry_mode = True so downstream code skips trash-specific logic.
    """
    retry_path = getattr(args, "retry_failed_file", None) or ""
    if not retry_path:
        args._target_path_overrides = {}
        args._retry_mode = False
        return True, 0
    ok, code = _validate_retry_failed_file_arg(args)
    if not ok:
        return False, code
    ok, code, target_path_overrides = _load_retry_failed_file(retry_path, args)
    if not ok:
        return False, code
    if not target_path_overrides:
        print(
            f"ERROR --retry-failed-file '{retry_path}' contains no actionable file IDs; "
            "nothing to retry.",
            file=sys.stderr,
        )
        return False, 1
    args.file_ids = list(target_path_overrides.keys())
    args._target_path_overrides = target_path_overrides
    args._retry_mode = True
    return True, 0


def _validate_file_ids_if_present(tool, args) -> Tuple[bool, int]:
    # Skip trash-specific prefetch validation when retrying from a failed-file CSV;
    # those IDs are already live (not in trash) so the non-trashed filter would drop them.
    if getattr(args, "_retry_mode", False):
        return True, 0
    if hasattr(args, "file_ids") and args.file_ids:
        ok = tool._validate_file_ids()
        if not ok:
            return False, 2
    return True, 0


def _print_scope_mismatch_error(args, exc: "StateScopeMismatchError") -> None:
    console = ConsoleHelper(args)
    saved = exc.saved_scope
    current = exc.current_scope
    print(
        f"{console.sym_fail()} State file '{args.state_file}' was created for a different scope; "
        "refusing to resume.",
        file=sys.stderr,
    )
    print(
        f"   Saved scope:   source={saved.source} command={saved.command} key={saved.key}",
        file=sys.stderr,
    )
    print(
        f"   Current scope: source={current.source} command={current.command} key={current.key}",
        file=sys.stderr,
    )
    print(
        "   Remediation: pass --fresh-run to reset this state file, or "
        "use --state-file <path> to keep a separate file for this invocation.",
        file=sys.stderr,
    )


def _run_and_release_lock(tool, args) -> int:
    ran_ok = False
    try:
        ran_ok = _run_tool(tool, args)
    except StateScopeMismatchError as e:
        _print_scope_mismatch_error(args, e)
        return 2
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

    ok, code = _validate_concurrency_arg(args)
    if not ok:
        return code

    ok, code = _validate_download_dir_arg(args)
    if not ok:
        return code

    ok, code = _validate_after_date_arg(args)
    if not ok:
        return code

    _apply_timestamped_output(args)

    ok, code = _validate_failed_file_arg(args)
    if not ok:
        return code

    ok, code = _apply_retry_failed_file(args)
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
