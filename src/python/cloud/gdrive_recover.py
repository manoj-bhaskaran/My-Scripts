r"""
Google Drive Recovery Tool
A comprehensive tool to recover and download files from Google Drive at scale with configurable options.

This tool provides:
- Bulk recovery of trashed files with optional extension filtering
- Folder-scoped download via --folder-id: download a Drive folder and all subfolders to a local
  directory with full subfolder hierarchy reconstruction
- Optional download to local directory with conflict-safe filenames
- Configurable post-restore policies (retain/trash/delete with aliases)
- Comprehensive Dry Run mode with full planning and privilege validation
- Resume capability for interrupted operations with **per-step granularity**
  (schema v3): each item carries a ``ProcessedRecord`` with three flags —
  ``recovered``, ``downloaded``, ``post_restored``. Only steps that actually
  succeeded are recorded, so a run interrupted between untrash and download
  will skip the untrash API call on rerun and retry only the download. Items
  whose all required steps are complete are skipped entirely. To ignore prior
  progress and start over (regenerating run identity and truncating the
  failed-file CSV), pass ``--fresh-run`` on either subcommand.
  State files are **scope-aware** (schema v3): each file records the source
  (trash query / folder / file-ids / retry CSV) and command (recover-only vs.
  recover-and-download) used to create it. Reusing a state file under a
  different scope is rejected with exit code 2 unless ``--fresh-run`` is
  passed; legacy v1/v2 state files are migrated transparently on first load
  (v1→v2 attaches a scope block; v2→v3 converts the flat ID list to per-step
  records — both migrations are automatic and non-destructive).
- Progress tracking and detailed summaries

Requirements:
- Python **3.10+** (uses PEP 604 `X | Y` union types across codebase, including `validators.py`)

See CHANGELOG-gdrive-recover.md in this directory for version history.

Examples
--------
Usage examples were moved to `docs/gdrive-recover-usage.md` to keep this module docstring focused on tool behavior and architecture.

"""

import time
import logging
import importlib
from datetime import datetime, timezone
from typing import List, Dict, Any, Tuple, Optional, Mapping
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
import sys
import uuid

# v1.9.0: static configuration constants extracted to dedicated module
from gdrive_constants import (
    VERSION,
    DEFAULT_PROCESS_BATCH,
)

__version__ = VERSION

# v1.10.0: data model types extracted to dedicated module
from gdrive_models import RecoveryItem, PostRestorePolicy
from gdrive_state import RecoveryStateManager

# v1.12.0: authentication extracted to dedicated module (issue #789)
from gdrive_auth import DriveAuthManager
from gdrive_rate_limiter import RateLimiter
from gdrive_operations import DriveOperations
from gdrive_privileges import DrivePrivilegeChecker
from gdrive_report import RecoveryReporter

try:
    # v1.12.3: discovery module uses googleapiclient.errors, so import under same guard.
    from gdrive_discovery import DriveTrashDiscovery, SeenTotalCounter

    # v1.14.0: download subsystem extracted to gdrive_download.py (issue #853).
    from gdrive_download import DriveDownloader
except ImportError:
    print("ERROR: Required Google API libraries not installed.")
    print(
        "Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib"
    )
    sys.exit(1)

# Add shared Python modules to sys.path for direct script execution from src/python/cloud.
_PYTHON_SRC_DIR = Path(__file__).resolve().parents[1]
if str(_PYTHON_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_PYTHON_SRC_DIR))
_MODULES_LOGGING = _PYTHON_SRC_DIR / "modules" / "logging"
if str(_MODULES_LOGGING) not in sys.path:
    sys.path.insert(0, str(_MODULES_LOGGING))
initialise_logger = importlib.import_module("python_logging_framework").initialise_logger
_file_operations = importlib.import_module("modules.utils.file_operations")
sanitize_filename = _file_operations.sanitize_filename
unique_path = _file_operations.unique_path


class DriveTrashRecoveryTool:
    """Main recovery tool class."""

    def __init__(self, args):
        self.args = args
        self.logger = self._setup_logging()
        self.stats = {
            "found": 0,
            "recovered": 0,
            "downloaded": 0,
            "errors": 0,
            "skipped": 0,
            "skipped_existing": 0,  # Target file already present on disk (--skip-existing)
            "post_restore_retained": 0,  # Files kept on Drive
            "post_restore_trashed": 0,  # Files moved to trash
            "post_restore_deleted": 0,  # Files permanently deleted
        }
        self.stats_lock = Lock()
        self.state_manager = RecoveryStateManager(
            args, self.logger, on_state_load_error=self._record_state_load_error
        )
        self.state = self.state_manager.state
        self.items: List[RecoveryItem] = []
        # progress throttles
        self._streaming: bool = False
        self._processed_total: int = 0
        self._seen_total_counter = SeenTotalCounter()
        self._last_exec_progress_ts: Optional[float] = None
        # v1.12.0: authentication delegated to DriveAuthManager (issue #789)
        self.rate_limiter = RateLimiter(args, self.logger)
        self.auth = DriveAuthManager(args, self.logger, execute_fn=self._execute)
        # v1.12.2: discovery was extracted to gdrive_discovery.py (issue #791)
        # v1.13.0: DriveTrashDiscovery no longer holds a self.tool reference;
        #          all dependencies are injected explicitly (issue #852).
        self.discovery = DriveTrashDiscovery(
            self.args,
            self.logger,
            self.auth,
            self._execute,
            stats=self.stats,
            stats_lock=self.stats_lock,
            seen_total=self._seen_total_counter,
            generate_target_path=self._generate_target_path,
            run_parallel_processing_for_batch=self._run_parallel_processing_for_batch,
        )
        # v1.14.0: download subsystem extracted to DriveDownloader (issue #853).
        self.downloader = DriveDownloader(
            self.args,
            self.logger,
            self.rate_limiter,
            self.auth,
            self.stats,
            self.stats_lock,
        )
        # v1.15.0: recovery operations extracted to DriveOperations (issue #854).
        self.ops = DriveOperations(
            self.args,
            self.logger,
            self.auth,
            self.downloader,
            self.state_manager,
            self.stats,
            self.stats_lock,
        )
        self.reporter = RecoveryReporter(self.args, self.logger, self.stats)
        # v1.17.0: privilege checks extracted to DrivePrivilegeChecker (issue #856).
        self.privileges = DrivePrivilegeChecker(self.auth, self._execute, self.logger, self.items)

    @property
    def _seen_total(self) -> int:
        return self._seen_total_counter.value

    @_seen_total.setter
    def _seen_total(self, value: int) -> None:
        self._seen_total_counter.value = value

    def _record_state_load_error(self) -> None:
        with self.stats_lock:
            self.stats["errors"] += 1

    def _execute(self, request):
        """Execute a googleapiclient request with rate limiting."""
        self.rate_limiter.wait()
        return request.execute()

    def _setup_logging(self) -> logging.Logger:
        """Configure recovery logging through the shared logging framework."""
        console_level = logging.WARNING
        if self.args.verbose >= 2:
            console_level = logging.DEBUG
        elif self.args.verbose == 1:
            console_level = logging.INFO

        return initialise_logger(
            script_name=__name__,
            log_level=logging.DEBUG,
            console_level=console_level,
            log_file_path=getattr(self.args, "log_file", None) or None,
            file_level=logging.DEBUG,
            create_default_file=False,
            configure_root=True,
        )

    # -------------------- Discovery helpers delegated to DriveTrashDiscovery --------------------
    # discover_trashed_files is the public entry point; all other discovery internals
    # live in DriveTrashDiscovery and are accessed directly via self.discovery.

    def discover_trashed_files(self) -> List[RecoveryItem]:
        return self.discovery.discover_trashed_files()

    def _generate_target_path(self, item: Mapping[str, Any] | RecoveryItem) -> str:
        if not self.args.download_dir:
            return ""
        item_name = item.get("name", "") if isinstance(item, Mapping) else item.name
        item_id = item.get("id", "") if isinstance(item, Mapping) else item.id
        overrides: dict = getattr(self.args, "_target_path_overrides", {})
        if overrides and item_id in overrides:
            return overrides[item_id]
        relative_path = "" if isinstance(item, Mapping) else item.relative_path
        safe_name = sanitize_filename(str(item_name), fallback=f"file_{item_id}")
        if relative_path:
            base_path = Path(self.args.download_dir) / relative_path / safe_name
        else:
            base_path = Path(self.args.download_dir) / safe_name
        if (
            base_path.exists()
            and not getattr(self.args, "overwrite", False)
            and not getattr(self.args, "skip_existing", False)
        ):
            base_path = unique_path(base_path, fallback_stem=f"file_{item_id}")
        return str(base_path)

    def _check_privileges(self) -> Dict[str, Any]:
        self.privileges.items = self.items
        return self.privileges._check_privileges(self.args)

    def dry_run(self) -> bool:
        self.reporter.print_dry_run_banner()
        # Authenticate up front; dry-run still needs list access
        try:
            if not self.auth.authenticate():
                self.reporter._print_err(
                    "Authentication failed. Ensure your credentials are configured and try again."
                )
                return False
        except Exception as e:
            self.reporter._print_err(f"Authentication failed: {e}")
            return False
        self.items = self.discover_trashed_files()
        if not self.items:
            self.reporter.print_no_files_found_matching()
            return True
        checks = self._check_privileges()
        self.reporter._print_privilege_checks(checks)
        self.reporter._print_scope_summary(self.items)
        if not self.reporter._show_detailed_plan(self.items):
            return False
        self.reporter._generate_execution_command(
            getattr(self.args, "_policy_warning_message", None)
        )
        return True

    def _process_item(self, item: RecoveryItem) -> bool:
        return self.ops._process_item(item)

    def _prepare_recovery(self, streaming_mode: bool) -> Tuple[bool, bool]:
        """
        Prepare auth/state. In streaming modes (recover-only / recover-and-download),
        DO NOT pre-discover items, because streaming discovery will do that and update
        stats incrementally. Pre-discovering here would double-count 'found'.

        State/failed-file reset is gated on --fresh-run; --overwrite is now
        strictly a local-file collision policy. The state load is also
        scope-aware: if the saved scope does not match the current invocation,
        StateScopeMismatchError propagates and is rendered by the CLI.
        """
        if not self.auth.authenticate():
            return False, False
        self.state_manager._load_state()
        self._apply_pre_run_reset()
        self.state = self.state_manager.state
        if streaming_mode:
            return True, self._init_streaming_counters()
        return True, self._eager_discover_and_report()

    def _apply_pre_run_reset(self) -> None:
        """Apply --fresh-run reset, if requested."""
        if getattr(self.args, "fresh_run", False):
            self._fresh_run_reset()

    def _fresh_run_reset(self) -> None:
        cleared = self.state_manager._reset_state()
        if cleared:
            self.reporter._print_info(
                f"--fresh-run: cleared {cleared} previously "
                "processed item(s) from state and regenerated run identity"
            )
        self.ops._clear_failed_files()

    def _init_streaming_counters(self) -> bool:
        """Reset counters for streaming; streaming discovery determines the count."""
        self.items = self.items or []
        self._seen_total = 0
        self._processed_total = 0
        self.stats["found"] = 0
        return True

    def _eager_discover_and_report(self) -> bool:
        if not self.items:
            self.items = self.discover_trashed_files()
        has_files = len(self.items) > 0
        if not has_files:
            self.reporter.print_no_files_to_process()
        return has_files

    def _get_safety_confirmation(self) -> bool:
        if self.args.yes:
            return True
        actions = self._build_action_list()
        action_text = ", ".join(actions)
        response = input(f"\nProceed to {action_text} for {len(self.items)} files? (y/N): ")
        if response.lower() != "y":
            self.reporter.print_operation_cancelled()
            return False
        return True

    def _build_action_list(self) -> List[str]:
        actions = []
        if any(item.will_recover for item in self.items):
            actions.append("recover from trash")
        if any(item.will_download for item in self.items):
            actions.append("download locally")
        normalized = PostRestorePolicy.normalize(self.args.post_restore_policy)
        if normalized != PostRestorePolicy.TRASH:
            actions.append(f"apply post-restore policy: {normalized}")
        return actions

    def _initialize_recovery_state(self):
        if not self.state.start_time:
            self.state.start_time = datetime.now(timezone.utc).isoformat()
            # In streaming mode total_found will be updated incrementally.
            self.state.total_found = len(self.items)
        if not getattr(self.state, "run_id", ""):
            self.state.run_id = str(uuid.uuid4())
        if getattr(self.state, "scope", None) is None:
            self.state.scope = self.state_manager._derive_scope_from_args()

    def _process_all_items(self) -> bool:
        self.reporter.print_processing_start(len(self.items), self.args.concurrency)
        start_time = time.time()
        try:
            self._run_parallel_processing(start_time)
        except KeyboardInterrupt:
            self.reporter.print_interrupted_state_saved()
            self.state_manager._save_state()
            return False
        self.state_manager._save_state()
        self.reporter._print_summary(time.time() - start_time, self.state)
        return True

    def _process_streaming(self) -> bool:
        """Stream discovery and process in bounded batches to limit memory usage."""
        self._streaming = True
        batch_n = int(
            getattr(self.args, "process_batch_size", DEFAULT_PROCESS_BATCH) or DEFAULT_PROCESS_BATCH
        )
        self.reporter.print_streaming_start(batch_n, self.args.concurrency)
        start_time = time.time()
        try:
            if self.args.file_ids:
                ok = self.discovery._stream_stream_ids(batch_n, start_time)
            elif getattr(self.args, "folder_id", None):
                ok = self.discovery._stream_stream_folder(batch_n, start_time)
            else:
                ok = self.discovery._stream_stream_query(batch_n, start_time)
        except KeyboardInterrupt:
            self.state.total_found = self._seen_total
            self._print_final_stream_progress(start_time)
            self.reporter.print_interrupted_state_saved()
            self.state_manager._save_state()
            return False
        self.state.total_found = self._seen_total
        self._print_final_stream_progress(start_time)
        self.state_manager._save_state()
        self.reporter._print_summary(time.time() - start_time, self.state)
        return ok

    def _print_final_stream_progress(self, start_time: float) -> None:
        """Force-render the streaming progress line with the true final totals.

        Progress updates are throttled to avoid flooding output; without this
        call the last render reflects whatever counts were live at the most
        recent throttle interval boundary, which can be off by up to one
        worker-batch from the true totals.
        """
        if not self.reporter._should_show_progress():
            return
        self.reporter._print_stream_progress(
            self._processed_total,
            start_time,
            self._seen_total,
            self.args.file_ids,
            force=True,
        )

    def _run_parallel_processing(self, start_time: float):
        processed_count = 0
        with ThreadPoolExecutor(max_workers=self.args.concurrency) as executor:
            future_to_item = {
                executor.submit(self._process_item, item): item for item in self.items
            }
            for future in as_completed(future_to_item):
                item = future_to_item[future]
                processed_count += 1
                self._handle_item_result(future, item, processed_count, start_time)

    def _run_parallel_processing_for_batch(self, batch: List[RecoveryItem], start_time: float):
        """Run the worker pool for a single batch and drop references afterward."""
        with ThreadPoolExecutor(max_workers=self.args.concurrency) as executor:
            future_to_item = {executor.submit(self._process_item, item): item for item in batch}
            for future in as_completed(future_to_item):
                item = future_to_item[future]
                self._processed_total += 1
                self._handle_item_result_stream(future, item, start_time)
        # Drop references to allow GC and keep RSS bounded
        batch.clear()

    def _handle_item_result_stream(self, future, item: RecoveryItem, start_time: float):
        try:
            future.result()
            if self.reporter._should_show_progress():
                self._print_stream_progress(start_time)
            if self._processed_total % 100 == 0:
                self.state.total_found = self._seen_total
                self.state_manager._save_state()
        except Exception as e:
            self.logger.error(f"Unexpected error processing {item.name}: {e}")
            with self.stats_lock:
                self.stats["errors"] += 1

    def _print_stream_progress(self, start_time: float):
        self.reporter._print_stream_progress(
            self._processed_total,
            start_time,
            self._seen_total,
            self.args.file_ids,
        )

    def _handle_item_result(
        self, future, item: RecoveryItem, processed_count: int, start_time: float
    ):
        try:
            future.result()
            if self.reporter._should_show_progress():
                interval = self._progress_interval(len(self.items))
                now = time.time()
                due_count = (processed_count % interval) == 0
                due_time = (self._last_exec_progress_ts is None) or (
                    (now - self._last_exec_progress_ts) >= 10
                )
                if due_count or due_time:
                    self._print_progress_update(processed_count, start_time)
                    self._last_exec_progress_ts = now
            if processed_count % 100 == 0:
                self.state_manager._save_state()
        except Exception as e:
            self.logger.error(f"Unexpected error processing {item.name}: {e}")
            with self.stats_lock:
                self.stats["errors"] += 1

    def _print_progress_update(self, processed_count: int, start_time: float):
        self.reporter.print_progress_update(processed_count, len(self.items), start_time)

    def _progress_interval(self, total: int) -> int:
        if total <= 0:
            return 5
        return max(5, min(500, max(1, round(total * 0.02))))

    def execute_recovery(self) -> bool:
        # In streaming mode we must avoid pre-discovery to prevent double counting.
        streaming_mode = self.args.mode != "dry_run"
        success, has_files = self._prepare_recovery(streaming_mode)
        if not success:
            return False
        if streaming_mode:
            # We may know the count if --file-ids is supplied
            est = len(self.args.file_ids) if self.args.file_ids else None
            if self.args.yes:
                confirmed = True
            else:
                msg = f"\nProceed to {', '.join(self._build_action_list())}"
                msg += f" for ~{est} files? (y/N): " if est else " in streaming mode? (y/N): "
                confirmed = input(msg).strip().lower() == "y"
            if not confirmed:
                self.reporter.print_operation_cancelled()
                return False
            self._initialize_recovery_state()
            try:
                return self._process_streaming()
            finally:
                self.state_manager._release_state_lock()
        if not has_files:  # non-streaming (dry-run) path
            return False
        return True


if __name__ == "__main__":
    from gdrive_cli import main

    raise SystemExit(main())
