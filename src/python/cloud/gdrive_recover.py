r"""
Google Drive Trash Recovery Tool
A comprehensive tool to recover files from Google Drive Trash at scale with configurable options.

This tool provides:
- Bulk recovery of trashed files with optional extension filtering
- Optional download to local directory with conflict-safe filenames
- Configurable post-restore policies (retain/trash/delete with aliases)
- Comprehensive Dry Run mode with full planning and privilege validation
- Resume capability for interrupted operations
- Progress tracking and detailed summaries

Requirements:
- Python **3.10+** (uses PEP 604 `X | Y` union types across codebase, including `validators.py`)

See CHANGELOG.md in this directory for version history.
"""

import os
import time
import logging
import shutil
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
    EXTENSION_MIME_TYPES,
    DEFAULT_PROCESS_BATCH,
    PAGE_SIZE,
    DEFAULT_WORKERS,
    INFERRED_MODIFY_ERROR,
)

__version__ = VERSION

# v1.10.0: data model types extracted to dedicated module
from gdrive_models import FileMeta, RecoveryItem, PostRestorePolicy
from gdrive_state import RecoveryStateManager

# v1.12.0: authentication extracted to dedicated module (issue #789)
from gdrive_auth import DriveAuthManager
from gdrive_rate_limiter import RateLimiter
from gdrive_operations import DriveOperations
from gdrive_report import RecoveryReporter

try:
    from googleapiclient.errors import HttpError

    # v1.12.3: discovery module uses googleapiclient.errors, so import under same guard.
    from gdrive_discovery import DriveTrashDiscovery

    # v1.14.0: download subsystem extracted to gdrive_download.py (issue #853).
    from gdrive_download import DriveDownloader
except ImportError:
    print("ERROR: Required Google API libraries not installed.")
    print(
        "Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib"
    )
    sys.exit(1)


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
        self._seen_total_ref: List[int] = [0]
        self._last_discover_progress_ts: Optional[float] = None
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
            seen_total_ref=self._seen_total_ref,
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

    @property
    def _seen_total(self) -> int:
        return self._seen_total_ref[0]

    @_seen_total.setter
    def _seen_total(self, value: int) -> None:
        self._seen_total_ref[0] = value

    def _print_err(self, msg: str) -> None:
        self.reporter._print_err(msg)

    def _print_warn(self, msg: str) -> None:
        self.reporter._print_warn(msg)

    def _print_info(self, msg: str) -> None:
        self.reporter._print_info(msg)

    def _record_state_load_error(self) -> None:
        with self.stats_lock:
            self.stats["errors"] += 1

    def _execute(self, request):
        """Execute a googleapiclient request with rate limiting."""
        self.rate_limiter.wait()
        return request.execute()

    def _setup_logging(self) -> logging.Logger:
        """Configure logging based on verbosity level."""
        log_level = logging.WARNING
        if self.args.verbose >= 2:
            log_level = logging.DEBUG
        elif self.args.verbose == 1:
            log_level = logging.INFO

        logging.basicConfig(
            level=log_level,
            format="%(asctime)s - %(levelname)s - %(message)s",
            handlers=[logging.FileHandler(self.args.log_file), logging.StreamHandler()],
        )
        return logging.getLogger(__name__)

    # -------------------- Discovery helpers delegated to DriveTrashDiscovery --------------------
    # discover_trashed_files is the public entry point; all other discovery internals
    # live in DriveTrashDiscovery and are accessed directly via self.discovery.

    def discover_trashed_files(self) -> List[RecoveryItem]:
        return self.discovery.discover_trashed_files()

    def _generate_target_path(self, item: Mapping[str, Any] | RecoveryItem) -> str:
        if not self.args.download_dir:
            return ""
        safe_name = "".join(
            c for c in item.name if c.isalnum() or c in (" ", "-", "_", ".")
        ).rstrip()
        if not safe_name:
            safe_name = f"file_{item.id}"
        base_path = Path(self.args.download_dir) / safe_name
        if base_path.exists():
            stem = base_path.stem
            suffix = base_path.suffix
            counter = 1
            while base_path.exists():
                base_path = base_path.parent / f"{stem}_{counter}{suffix}"
                counter += 1
        return str(base_path)

    def _get_file_info(self, file_id: str, fields: str) -> FileMeta:
        api_ctx = f"files.get(fileId={file_id}, fields={fields})"
        try:
            service = self.auth._get_service()
            return self._execute(service.files().get(fileId=file_id, fields=fields))
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            payload = getattr(e, "content", b"")
            detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
            self.logger.error(f"{api_ctx} failed: HTTP {status}: {detail}")
            return {"error": f"HTTP {status}: {detail}"}
        except (OSError, IOError) as e:
            self.logger.error(f"{api_ctx} I/O error: {e}")
            return {"error": f"I/O error: {e}"}
        except Exception as e:
            self.logger.error(f"{api_ctx} unexpected error: {e}")
            return {"error": f"Unexpected error: {e}"}  # type: ignore[return-value]

    def _check_untrash_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {"status": "unknown", "error": None}
        file_info = self._get_file_info(file_id, "id,trashed,capabilities")
        if "error" in file_info:
            result["status"] = "fail"
            result["error"] = file_info["error"]
            return result
        if not file_info.get("trashed", False):
            result["status"] = "skip"
            result["error"] = "Test file is not trashed - cannot validate untrash permission"
            return result
        capabilities = file_info.get("capabilities", {})
        if "canUntrash" in capabilities:
            result["status"] = "pass" if capabilities["canUntrash"] else "fail"
            if not capabilities["canUntrash"]:
                result["error"] = "File capabilities indicate untrash not allowed"
        else:
            result["status"] = "pass"  # Fallback
        return result

    def _check_download_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {"status": "unknown", "error": None}
        file_info = self._get_file_info(file_id, "id,size,mimeType,capabilities")
        if "error" in file_info:
            result["status"] = "fail"
            result["error"] = file_info["error"]
            return result
        if "size" not in file_info:
            result["status"] = "fail"
            result["error"] = "File is not downloadable (Google Docs format or no size)"
            return result
        capabilities = file_info.get("capabilities", {})
        if "canDownload" in capabilities:
            result["status"] = "pass" if capabilities["canDownload"] else "fail"
            if not capabilities["canDownload"]:
                result["error"] = "File capabilities indicate download not allowed"
        else:
            result["status"] = "pass"  # Fallback
        return result

    def _check_trash_delete_privileges(
        self, file_id: str, untrash_status: str
    ) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        trash_result = {
            "status": untrash_status,
            "error": INFERRED_MODIFY_ERROR if untrash_status == "fail" else None,
        }
        delete_result = {
            "status": untrash_status,
            "error": INFERRED_MODIFY_ERROR if untrash_status == "fail" else None,
        }
        file_info = self._get_file_info(file_id, "id,capabilities")
        if "error" in file_info:
            trash_result["status"] = "fail"
            trash_result["error"] = file_info["error"]
            delete_result["status"] = "fail"
            delete_result["error"] = file_info["error"]
            return trash_result, delete_result
        capabilities = file_info.get("capabilities", {})
        if "canTrash" in capabilities:
            trash_result["status"] = "pass" if capabilities["canTrash"] else "fail"
            trash_result["error"] = (
                None if capabilities["canTrash"] else "File capabilities indicate trash not allowed"
            )
        if "canDelete" in capabilities:
            delete_result["status"] = "pass" if capabilities["canDelete"] else "fail"
            delete_result["error"] = (
                None
                if capabilities["canDelete"]
                else "File capabilities indicate delete not allowed"
            )
        elif trash_result["status"] == "pass":
            delete_result["status"] = "pass"
            delete_result["error"] = None
        return trash_result, delete_result

    def _test_operation_privileges(self, test_items: List[RecoveryItem]) -> Dict[str, Any]:
        privileges = {
            "untrash": {"status": "unknown", "error": None},
            "download": {"status": "unknown", "error": None},
            "trash": {"status": "unknown", "error": None},
            "delete": {"status": "unknown", "error": None},
        }
        if not test_items:
            return privileges
        test_item = test_items[0]
        privileges["untrash"] = self._check_untrash_privilege(test_item.id)
        privileges["download"] = self._check_download_privilege(test_item.id)
        privileges["trash"], privileges["delete"] = self._check_trash_delete_privileges(
            test_item.id, privileges["untrash"]["status"]
        )
        return privileges

    def _check_privileges(self) -> Dict[str, Any]:
        checks = {
            "drive_access": False,
            "drive_error": None,
            "operation_privileges": {},
            "local_writable": False,
            "local_error": None,
            "disk_space": 0,
            "estimated_needed": 0,
        }
        try:
            service = self.auth._get_service()
            service.files().list(pageSize=1).execute()
            checks["drive_access"] = True
            sample_items = self.items[:1] if self.items else []
            checks["operation_privileges"] = self._test_operation_privileges(sample_items)
        except Exception as e:
            checks["drive_error"] = str(e)
        dl_dir = getattr(self.args, "download_dir", None)
        if dl_dir:
            try:
                download_path = Path(dl_dir)
                download_path.mkdir(parents=True, exist_ok=True)
                test_file = download_path / ".write_test"
                test_file.write_text("test")
                test_file.unlink()
                checks["local_writable"] = True
                if hasattr(shutil, "disk_usage"):
                    _, _, free_bytes = shutil.disk_usage(download_path)
                    checks["disk_space"] = free_bytes
                    total_size = sum(item.size for item in self.items if item.will_download)
                    checks["estimated_needed"] = total_size
            except Exception as e:
                checks["local_error"] = str(e)
        return checks

    def dry_run(self) -> bool:
        self.reporter.print_dry_run_banner()
        # Authenticate up front; dry-run still needs list access
        try:
            if not self.auth.authenticate():
                self._print_err(
                    "Authentication failed. Ensure your credentials are configured and try again."
                )
                return False
        except Exception as e:
            self._print_err(f"Authentication failed: {e}")
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

    def _recover_file(self, item: RecoveryItem) -> bool:
        return self.ops._recover_file(item)

    def _get_post_restore_action_and_ctx(self, item: RecoveryItem) -> Tuple[str, Optional[str]]:
        return self.ops._get_post_restore_action_and_ctx(item)

    def _do_post_restore_action(self, service, item: RecoveryItem, action: str):
        return self.ops._do_post_restore_action(service, item, action)

    def _log_post_restore_success(self, item: RecoveryItem, action: str):
        return self.ops._log_post_restore_success(item, action)

    def _is_terminal_post_restore_error(self, status):
        return self.ops._is_terminal_post_restore_error(status)

    def _handle_post_restore_retry(self, item, status, attempt):
        return self.ops._handle_post_restore_retry(item, status, attempt)

    def _extract_http_error_detail(self, error_message: str):
        return self.ops._extract_http_error_detail(error_message)

    def _log_post_restore_terminal_error(self, item, detail, api_ctx):
        return self.ops._log_post_restore_terminal_error(item, detail, api_ctx)

    def _log_post_restore_final_error(self, item, detail, api_ctx):
        return self.ops._log_post_restore_final_error(item, detail, api_ctx)

    def _apply_post_restore_policy(self, item: RecoveryItem) -> bool:
        return self.ops._apply_post_restore_policy(item)

    def _process_item(self, item: RecoveryItem) -> bool:
        return self.ops._process_item(item)

    def _prepare_recovery(self, streaming_mode: bool) -> Tuple[bool, bool]:
        """
        Prepare auth/state. In streaming modes (recover-only / recover-and-download),
        DO NOT pre-discover items, because streaming discovery will do that and update
        stats incrementally. Pre-discovering here would double-count 'found'.
        """
        if not self.auth.authenticate():
            return False, False
        self.state_manager._load_state()
        self.state = self.state_manager.state
        if streaming_mode:
            # Ensure counters are clean for streaming; discovery will bump these.
            self.items = self.items or []
            self._seen_total = 0
            self._processed_total = 0
            self.stats["found"] = 0
            return True, True  # we can’t know yet; streaming will determine
        else:
            if not self.items:
                self.items = self.discover_trashed_files()
            has_files = len(self.items) > 0
            if not has_files:
                self.reporter.print_no_files_to_process()
            return True, has_files

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
        if not getattr(self.state, "owner_pid", None):
            self.state.owner_pid = os.getpid()

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
            else:
                ok = self.discovery._stream_stream_query(batch_n, start_time)
        except KeyboardInterrupt:
            self.reporter.print_interrupted_state_saved()
            self.state_manager._save_state()
            return False
        self.state_manager._save_state()
        self.reporter._print_summary(time.time() - start_time, self.state)
        return ok

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
            if self.args.verbose >= 1:
                now = time.time()
                due_time = (self._last_exec_progress_ts is None) or (
                    (now - self._last_exec_progress_ts) >= 10
                )
                if due_time:
                    self._print_stream_progress(start_time)
                    self._last_exec_progress_ts = now
            if self._processed_total % 100 == 0:
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
            if self.args.verbose >= 1:
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
