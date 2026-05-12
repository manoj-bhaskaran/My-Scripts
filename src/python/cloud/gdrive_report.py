"""Reporting and presentation helpers for Google Drive recovery flows."""

import sys
import time
from typing import Any, Dict, List, Optional

from gdrive_constants import (
    DEFAULT_BURST,
    DEFAULT_LOG_FILE,
    DEFAULT_MAX_RPS,
    DEFAULT_STATE_FILE,
)
from gdrive_models import PostRestorePolicy, RecoveryItem, RecoveryState


class ProgressBar:
    """Renders an in-place ASCII/Unicode progress bar for recovery operations.

    On a real terminal (TTY) the bar overwrites the current line via CR so it
    animates smoothly without scrolling.  On a non-TTY stream (log file, CI
    pipe) a plain line is printed at most every LOG_INTERVAL seconds so output
    stays readable.
    """

    BAR_WIDTH = 20
    TTY_INTERVAL = 0.5  # seconds between renders on a live terminal
    LOG_INTERVAL = 10.0  # seconds between lines on a non-TTY stream

    def __init__(self, args, total: Optional[int] = None) -> None:
        self.args = args
        self.total = total
        self._is_tty: bool = sys.stdout.isatty()
        self._last_render: float = 0.0

    def _use_emoji(self) -> bool:
        return not getattr(self.args, "no_emoji", False)

    def _fill_bar(self, count: int, total: int) -> str:
        pct = count / total if total > 0 else 0.0
        filled = round(self.BAR_WIDTH * pct)
        if self._use_emoji():
            bar = "█" * filled + "░" * (self.BAR_WIDTH - filled)
        else:
            bar = "#" * filled + "-" * (self.BAR_WIDTH - filled)
        return f"[{bar}]"

    def _format_line(self, count: int, start_time: float, discovered: int) -> str:
        elapsed = time.time() - start_time
        rate = count / elapsed if elapsed > 0 else 0.0
        sep = "│" if self._use_emoji() else "|"

        if self.total is not None and self.total > 0:
            bar = self._fill_bar(count, self.total)
            pct = count / self.total * 100
            eta = (self.total - count) / rate if rate > 0 else 0.0
            return (
                f"{bar} {count}/{self.total} ({pct:.1f}%) "
                f"{sep} {rate:.1f}/sec {sep} ETA: {eta:.0f}s"
            )

        sym = "▶" if self._use_emoji() else ">"
        if discovered > count:
            return (
                f"{sym} processed={count} discovered={discovered} {sep} {rate:.1f}/sec"
            )
        return f"{sym} processed={count} {sep} {rate:.1f}/sec"

    def update(self, count: int, start_time: float, discovered: int = 0) -> None:
        """Emit a progress update, throttled to avoid flooding output."""
        now = time.time()
        interval = self.TTY_INTERVAL if self._is_tty else self.LOG_INTERVAL
        if now - self._last_render < interval:
            return
        self._last_render = now
        line = self._format_line(count, start_time, discovered)
        if self._is_tty:
            print(f"\r{line:<79}", end="", flush=True)
        else:
            print(line)

    def close(self) -> None:
        """Move the cursor to a new line after the last in-place update."""
        if self._is_tty and self._last_render > 0.0:
            print()


class RecoveryReporter:
    """Owns user-facing console output for recovery/discovery execution."""

    def __init__(self, args, logger, stats: Dict[str, Any]):
        self.args = args
        self.logger = logger
        self.stats = stats
        self._progress_bar: Optional[ProgressBar] = None

    def _use_emoji(self) -> bool:
        return not getattr(self.args, "no_emoji", False)

    def _sym_ok(self) -> str:
        return "✓" if self._use_emoji() else "OK"

    def _sym_fail(self) -> str:
        return "❌" if self._use_emoji() else "ERROR"

    def _sym_warn(self) -> str:
        return "⚠️" if self._use_emoji() else "WARN"

    def _sym_info(self) -> str:
        return "ℹ️" if self._use_emoji() else "INFO"

    def _sym_progress(self) -> str:
        return "📈" if self._use_emoji() else "PROGRESS"

    def _sym_done(self) -> str:
        return "✅" if self._use_emoji() else "DONE"

    def _sym_scope(self) -> str:
        return "📊" if self._use_emoji() else "SCOPE"

    def _sym_plan(self) -> str:
        return "📋" if self._use_emoji() else "PLAN"

    def _sym_search(self) -> str:
        return "🔍" if self._use_emoji() else "SEARCH"

    def _should_show_progress(self) -> bool:
        """Return True when progress output should be emitted.

        Always True on a real terminal (progress bar animates without -v).
        Requires -v on non-TTY so log files and CI output stay tidy.
        """
        return sys.stdout.isatty() or getattr(self.args, "verbose", 0) >= 1

    def _start_progress(self, total: Optional[int] = None) -> None:
        self._progress_bar = ProgressBar(self.args, total=total)

    def _close_progress(self) -> None:
        if self._progress_bar is not None:
            self._progress_bar.close()
            self._progress_bar = None

    def _print_err(self, msg: str) -> None:
        print(f"{self._sym_fail()} {msg}", file=sys.stderr)

    def _print_warn(self, msg: str) -> None:
        print(f"{self._sym_warn()} {msg}", file=sys.stderr)

    def _print_info(self, msg: str) -> None:
        print(f"{self._sym_info()} {msg}")

    def _print_drive_access_status(self, checks: Dict[str, Any]) -> None:
        drive_status = (
            f"{self._sym_ok()} PASS" if checks["drive_access"] else f"{self._sym_fail()} FAIL"
        )
        print(f"Drive API Access: {drive_status}")
        if checks["drive_error"]:
            print(f"  Error: {checks['drive_error']}")

    def _print_operation_privileges(self, checks: Dict[str, Any]) -> None:
        if not checks.get("operation_privileges"):
            return
        print("\nOperation Privileges:")
        for operation, result in checks["operation_privileges"].items():
            self._print_single_operation_privilege(operation, result)

    def _print_single_operation_privilege(self, operation: str, result: Dict[str, Any]) -> None:
        status_symbol = {
            "pass": self._sym_ok(),
            "fail": self._sym_fail(),
        }.get(
            result["status"], "?"
        )  # nosec B105
        print(f"  {operation.title()}: {status_symbol} {result['status'].upper()}")
        if result["error"]:
            print(f"    Error: {result['error']}")

    def _print_local_directory_status(self, checks: Dict[str, Any]) -> None:
        dl_dir = getattr(self.args, "download_dir", None)
        if not dl_dir:
            return
        if getattr(self.args, "mode", None) == "dry_run":
            print(f"Download directory: {dl_dir} (informational — no write check in dry-run)")
            return
        local_status = (
            f"{self._sym_ok()} PASS" if checks["local_writable"] else f"{self._sym_fail()} FAIL"
        )
        print(f"Local Directory Writable: {local_status}")
        if checks["local_error"]:
            print(f"  Error: {checks['local_error']}")
        self._print_disk_space_info(checks)

    def _print_privilege_checks(self, checks: Dict[str, Any]) -> None:
        print(f"\n{self._sym_plan()} PRIVILEGE AND ENVIRONMENT CHECKS")
        print("-" * 50)
        self._print_drive_access_status(checks)
        self._print_operation_privileges(checks)
        self._print_local_directory_status(checks)

    def _print_disk_space_info(self, checks: Dict[str, Any]) -> None:
        if checks["disk_space"] > 0:
            free_gb = checks["disk_space"] / (1024**3)
            needed_gb = checks["estimated_needed"] / (1024**3)
            space_status = (
                f"{self._sym_ok()} SUFFICIENT"
                if checks["disk_space"] > checks["estimated_needed"]
                else f"{self._sym_warn()} INSUFFICIENT"
            )
            print(f"Disk Space: {space_status}")
            print(f"  Available: {free_gb:.2f} GB")
            print(f"  Estimated needed: {needed_gb:.2f} GB")

    def _print_scope_summary(self, items: List[RecoveryItem]) -> None:
        print(f"\n{self._sym_scope()} SCOPE SUMMARY")
        print("-" * 50)
        print(f"Total trashed files found: {len(items)}")
        if self.args.extensions:
            print(f"Extension filter: {', '.join(self.args.extensions)}")
        recover_count = sum(1 for item in items if item.will_recover)
        download_count = sum(1 for item in items if item.will_download)
        total_size_mb = sum(item.size for item in items) / (1024**2)
        print(f"Files to recover: {recover_count}")
        print(f"Files to download: {download_count}")
        print(f"Total size: {total_size_mb:.2f} MB")
        print(f"Post-restore policy: {PostRestorePolicy.normalize(self.args.post_restore_policy)}")

    def _print_item_details(self, item: RecoveryItem, index: int) -> None:
        print(f"{index:4d}. {item.name[:50]}")
        print(f"      ID: {item.id}")
        print(f"      Size: {item.size / 1024:.1f} KB")
        print(f"      Recover: {'Yes' if item.will_recover else 'No'}")
        if item.will_download:
            print(f"      Download: Yes -> {item.target_path}")
        else:
            print("      Download: No")
        print(f"      Post-restore: {item.post_restore_action}")
        print()

    def _show_detailed_plan(self, items: List[RecoveryItem]) -> bool:
        print(f"\n{self._sym_plan()} DETAILED EXECUTION PLAN")
        print("-" * 50)
        page_size = 20
        total_pages = (len(items) + page_size - 1) // page_size
        for page in range(total_pages):
            start_idx = page * page_size
            end_idx = min(start_idx + page_size, len(items))
            print(f"\nPage {page + 1}/{total_pages} (items {start_idx + 1}-{end_idx}):")
            print("-" * 80)
            for idx, item in enumerate(items[start_idx:end_idx], start_idx + 1):
                self._print_item_details(item, idx)
            if page < total_pages - 1:
                response = (
                    input(
                        "Press Enter for next page, 'q' to stop viewing, or 's' to skip to summary: "
                    )
                    .strip()
                    .lower()
                )
                if response == "q":
                    return False
                if response == "s":
                    break
        return True

    def _generate_execution_command(self, policy_warning_message: Optional[str] = None) -> None:
        print(f"\n{self._sym_plan()} EXECUTION COMMAND")
        print("-" * 50)
        cmd_parts = [sys.argv[0]]
        self._add_mode_arguments(cmd_parts)
        self._add_filter_arguments(cmd_parts)
        self._add_config_arguments(cmd_parts)
        self._add_file_arguments(cmd_parts)
        self._add_verbosity_arguments(cmd_parts)
        if getattr(self.args, "no_emoji", False):
            cmd_parts.append("--no-emoji")
        cmd_str = " ".join(cmd_parts)
        print("To execute this plan, run:")
        print(f"  {cmd_str}")
        if "<DOWNLOAD_DIR>" in cmd_str:
            self._print_warn(
                "Replace <DOWNLOAD_DIR> with the local path where files should be saved."
            )

        if policy_warning_message:
            try:
                self.logger.warning(policy_warning_message)
            except Exception:
                pass
            self._print_warn(policy_warning_message)

    def _add_file_arguments(self, cmd_parts: List[str]) -> None:
        if getattr(self.args, "folder_id", None):
            cmd_parts.extend(["--folder-id", self.args.folder_id])
        if self.args.after_date:
            cmd_parts.extend(["--after-date", self.args.after_date])
        if self.args.file_ids:
            cmd_parts.extend(["--file-ids"] + self.args.file_ids)
        if self.args.log_file != DEFAULT_LOG_FILE:
            cmd_parts.extend(["--log-file", self.args.log_file])
        if self.args.state_file != DEFAULT_STATE_FILE:
            cmd_parts.extend(["--state-file", self.args.state_file])

    def _add_verbosity_arguments(self, cmd_parts: List[str]) -> None:
        if self.args.verbose > 0:
            cmd_parts.append("-" + "v" * self.args.verbose)

    def _add_mode_arguments(self, cmd_parts: List[str]) -> None:
        if self.args.mode == "recover_and_download":
            cmd_parts.append("recover-and-download")
            cmd_parts.extend(["--download-dir", str(self.args.download_dir)])
        elif self.args.mode == "recover_only":
            cmd_parts.append("recover-only")
        else:
            # dry-run: emit the command that would actually execute the plan
            dl_dir = getattr(self.args, "download_dir", None)
            folder_id = getattr(self.args, "folder_id", None)
            if dl_dir:
                cmd_parts.append("recover-and-download")
                cmd_parts.extend(["--download-dir", str(dl_dir)])
            elif folder_id:
                # recover-only rejects --folder-id; recover-and-download is the only valid mode
                cmd_parts.append("recover-and-download")
                cmd_parts.extend(["--download-dir", "<DOWNLOAD_DIR>"])
            else:
                cmd_parts.append("recover-only")

    def _add_filter_arguments(self, cmd_parts: List[str]) -> None:
        if self.args.extensions:
            cmd_parts.extend(["--extensions"] + self.args.extensions)

    def _add_config_arguments(self, cmd_parts: List[str]) -> None:
        normalized = PostRestorePolicy.normalize(self.args.post_restore_policy)
        if normalized != PostRestorePolicy.TRASH:
            cmd_parts.extend(["--post-restore-policy", normalized])
        cmd_parts.extend(["--concurrency", str(self.args.concurrency)])
        if self.args.max_rps != DEFAULT_MAX_RPS:
            cmd_parts.extend(["--max-rps", str(self.args.max_rps)])
        if self.args.burst != DEFAULT_BURST:
            cmd_parts.extend(["--burst", str(self.args.burst)])
        if self.args.limit and self.args.limit > 0:
            cmd_parts.extend(["--limit", str(self.args.limit)])
        if self.args.yes:
            cmd_parts.append("--yes")

    def _print_stream_progress(
        self,
        processed_total: int,
        start_time: float,
        seen_total: int,
        file_ids: Optional[List[str]],
    ) -> None:
        if self._progress_bar is not None:
            self._progress_bar.update(processed_total, start_time, seen_total)
            return
        elapsed = time.time() - start_time
        rate = processed_total / elapsed if elapsed > 0 else 0
        if file_ids:
            pct = processed_total / max(1, len(file_ids)) * 100.0
            print(
                f"{self._sym_progress()} Progress: {processed_total}/{len(file_ids)} ({pct:.1f}%) Rate: {rate:.1f}/sec"
            )
        else:
            print(
                f"{self._sym_progress()} Progress: processed={processed_total} discovered={seen_total} Rate: {rate:.1f}/sec"
            )

    def print_progress_update(
        self, processed_count: int, total_items: int, start_time: float
    ) -> None:
        if self._progress_bar is not None:
            self._progress_bar.update(processed_count, start_time)
            return
        elapsed = time.time() - start_time
        rate = processed_count / elapsed if elapsed > 0 else 0
        eta = (total_items - processed_count) / rate if rate > 0 else 0
        pct = (processed_count / total_items * 100) if total_items else 100.0
        print(
            f"{self._sym_progress()} Progress: {processed_count}/{total_items} "
            f"({pct:.1f}%) Rate: {rate:.1f}/sec ETA: {eta:.0f}s"
        )

    def print_dry_run_banner(self) -> None:
        print("\n" + "=" * 80)
        print(f"{self._sym_search()} DRY RUN MODE - No changes will be made")
        print("=" * 80)

    def print_no_files_found_matching(self) -> None:
        print("No files found matching criteria.")

    def print_no_files_to_process(self) -> None:
        print("No files found to process.")

    def print_operation_cancelled(self) -> None:
        print("Operation cancelled.")

    def print_processing_start(self, count: int, concurrency: int) -> None:
        self._start_progress(total=count)
        print(f"\n{self._sym_plan()} Processing {count} files with {concurrency} workers...")

    def print_streaming_start(self, batch_n: int, concurrency: int) -> None:
        total = len(self.args.file_ids) if getattr(self.args, "file_ids", None) else None
        self._start_progress(total=total)
        print(
            f"\n{self._sym_plan()} Streaming execution with batch size {batch_n} and {concurrency} workers..."
        )

    def print_interrupted_state_saved(self) -> None:
        self._close_progress()
        self._print_warn("Operation interrupted. State saved for resume.")

    def _print_summary(self, elapsed_time: float, state: RecoveryState) -> None:
        self._close_progress()
        print("\n" + "=" * 80)
        print(f"{self._sym_scope()} EXECUTION SUMMARY")
        print("=" * 80)
        print(f"Total files found: {self.stats['found']}")
        print(f"Files recovered: {self.stats['recovered']}")
        print(f"Files downloaded: {self.stats['downloaded']}")
        total_post_restore = (
            self.stats["post_restore_retained"]
            + self.stats["post_restore_trashed"]
            + self.stats["post_restore_deleted"]
        )
        if total_post_restore > 0:
            print(f"Post-restore actions applied: {total_post_restore}")
            print(f"  - Retained on Drive: {self.stats['post_restore_retained']}")
            print(f"  - Moved to trash: {self.stats['post_restore_trashed']}")
            print(f"  - Permanently deleted: {self.stats['post_restore_deleted']}")
        print(f"Files skipped (already processed): {self.stats['skipped']}")
        print(f"Errors encountered: {self.stats['errors']}")
        print(f"Execution time: {elapsed_time:.1f} seconds")
        if self.stats["errors"] > 0:
            self._print_warn(f"Check log file for error details: {self.args.log_file}")
        if state.processed_items:
            state_symbol = "📂" if self._use_emoji() else "STATE"
            print(f"\n{state_symbol} State file: {self.args.state_file}")
            print("   Use same command to resume if interrupted")
        # For recover-and-download (including folder-id downloads), the final
        # measurable outcome is a file on disk; "recovered" stays 0 for live
        # (non-trashed) files even when every download succeeded, so using it
        # as the numerator gives a false 0 % in that path.
        if getattr(self.args, "mode", "") == "recover_only":
            success_count = self.stats["recovered"]
            success_label = "Recovery success rate"
        else:
            success_count = self.stats["downloaded"]
            success_label = "Download success rate"
        success_rate = (success_count / self.stats["found"] * 100) if self.stats["found"] > 0 else 0
        print(f"\n{self._sym_done()} {success_label}: {success_rate:.1f}%")
