"""Recovery operation helpers extracted from DriveTrashRecoveryTool."""

from __future__ import annotations

from pathlib import Path
from threading import Lock
from typing import Optional, Tuple

from gdrive_models import PostRestorePolicy, RecoveryItem
from gdrive_retry import with_retries


class DriveOperations:
    """Encapsulates recover/process/post-restore operations."""

    def __init__(self, args, logger, auth, downloader, state_manager, stats, stats_lock):
        self.args = args
        self.logger = logger
        self.auth = auth
        self.downloader = downloader
        self.state_manager = state_manager
        self.stats = stats
        self.stats_lock = stats_lock
        self._failed_file_path: str = getattr(args, "failed_file", None) or ""
        self._failed_files_lock = Lock()

    def _execute(self, request):
        return self.auth._execute(request)

    def _clear_failed_files(self) -> None:
        """Truncate the failed-file log to zero bytes (called when --overwrite is set)."""
        if not self._failed_file_path:
            return
        p = Path(self._failed_file_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("", encoding="utf-8")

    def _write_failed_file(self, item: RecoveryItem) -> None:
        """Append the item's local path (or Drive name) to the failed-file log."""
        if not self._failed_file_path:
            return
        entry = item.target_path if item.target_path else item.name
        p = Path(self._failed_file_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        with self._failed_files_lock:
            with open(self._failed_file_path, "a", encoding="utf-8") as fh:
                fh.write(entry + "\n")

    def _recover_file(self, item: RecoveryItem) -> bool:
        if not getattr(self.args, "overwrite", False) and self.state_manager._is_processed(item.id):
            with self.stats_lock:
                self.stats["skipped"] += 1
            return True

        service = self.auth._get_service()
        api_ctx = f"files.update(fileId={item.id}, trashed=False)"
        result, error, _ = with_retries(
            lambda: self._execute(service.files().update(fileId=item.id, body={"trashed": False})),
            terminal_statuses=(403, 404),
            logger=self.logger,
            ctx=api_ctx,
        )
        if error is not None:
            item.status = "failed"
            item.error_message = error
            with self.stats_lock:
                self.stats["errors"] += 1
            self.logger.error("Failed to recover %s: %s", item.name, error)
            return False

        _ = result
        item.status = "recovered"
        with self.stats_lock:
            self.stats["recovered"] += 1
        self.logger.info("Recovered: %s", item.name)
        return True

    def _get_post_restore_action_and_ctx(self, item: RecoveryItem) -> Tuple[str, Optional[str]]:
        action = PostRestorePolicy.normalize(item.post_restore_action)
        if action == PostRestorePolicy.RETAIN:
            return "retain", None
        if action == PostRestorePolicy.TRASH:
            return "trashed", f"files.update(fileId={item.id}, trashed=True)"
        if action == PostRestorePolicy.DELETE:
            return "deleted", f"files.delete(fileId={item.id})"
        return "retain", None

    def _do_post_restore_action(self, service, item: RecoveryItem, action: str):
        if action == "trashed":
            return self._execute(service.files().update(fileId=item.id, body={"trashed": True}))
        if action == "deleted":
            return self._execute(service.files().delete(fileId=item.id))
        return None

    def _log_post_restore_success(self, item: RecoveryItem, action: str):
        if action == "retain":
            with self.stats_lock:
                self.stats["post_restore_retained"] += 1
        elif action == "trashed":
            self.logger.info("Moved to trash: %s", item.name)
            with self.stats_lock:
                self.stats["post_restore_trashed"] += 1
        elif action == "deleted":
            self.logger.info("Permanently deleted: %s", item.name)
            with self.stats_lock:
                self.stats["post_restore_deleted"] += 1

    def _is_terminal_post_restore_error(self, status) -> bool:
        return status in (403, 404)

    def _handle_post_restore_retry(self, item: RecoveryItem, status: Optional[int], attempt: int):
        self.logger.warning(
            "Post-restore action for %s failed with HTTP %s (attempt %d). Retrying...",
            item.id,
            status,
            attempt + 1,
        )

    def _extract_http_error_detail(self, error_message: str) -> str:
        if ": " not in error_message:
            return error_message
        return error_message.split(": ", 1)[1]

    def _log_post_restore_terminal_error(
        self, item: RecoveryItem, detail: str, api_ctx: Optional[str]
    ):
        self.logger.error(
            "Post-restore action failed for %s via %s: %s",
            item.name,
            api_ctx or "N/A",
            detail,
        )

    def _log_post_restore_final_error(
        self, item: RecoveryItem, detail: str, api_ctx: Optional[str]
    ):
        self.logger.error(
            "Post-restore action failed after retries for %s via %s: %s",
            item.name,
            api_ctx or "N/A",
            detail,
        )

    def _apply_post_restore_policy(self, item: RecoveryItem) -> bool:
        service = self.auth._get_service()
        action, api_ctx = self._get_post_restore_action_and_ctx(item)

        if action == "retain":
            self._log_post_restore_success(item, action)
            return True

        _, error, status = with_retries(
            lambda: self._do_post_restore_action(service, item, action),
            terminal_statuses=(403, 404),
            logger=self.logger,
            ctx=api_ctx or "post-restore action",
        )

        if error is None:
            self._log_post_restore_success(item, action)
            return True

        detail = self._extract_http_error_detail(error)
        if self._is_terminal_post_restore_error(status):
            self._log_post_restore_terminal_error(item, detail, api_ctx)
        else:
            self._log_post_restore_final_error(item, detail, api_ctx)
        return False

    def _process_item(self, item: RecoveryItem) -> bool:
        if not getattr(self.args, "overwrite", False) and self.state_manager._is_processed(item.id):
            return True

        success = True
        if item.will_recover and not self._recover_file(item):
            success = False
        if success and item.will_download and not self.downloader.download(item):
            success = False
        if success and item.will_download and item.status == "downloaded":
            self._apply_post_restore_policy(item)

        if not success:
            self._write_failed_file(item)

        self.state_manager._mark_processed(item.id)
        return success
