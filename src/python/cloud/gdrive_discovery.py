"""Discovery and ID validation helpers for Google Drive trash recovery."""

import io
import json
import logging
import re
import sys
import time
from collections import deque
from pathlib import Path
from threading import Lock
from typing import (
    Any,
    Callable,
    Deque,
    Dict,
    List,
    Mapping,
    Optional,
    Tuple,
    TYPE_CHECKING,
)

from gdrive_console import ConsoleHelper
from gdrive_constants import FOLDER_MIME_TYPE, PAGE_SIZE
from gdrive_models import FileMeta, RecoveryItem, PostRestorePolicy
from gdrive_id_prefetch import IdMetadataPrefetcher
from gdrive_query_filters import (
    build_discovery_query,
    matches_extension_filter,
    matches_time_filter,
)
from gdrive_retry import with_retries

if TYPE_CHECKING:
    from gdrive_auth import DriveAuthManager

HTTP_404_LABEL = "HTTP 404"
HTTP_403_LABEL = "HTTP 403"


class DriveTrashDiscovery:
    """Extracted discovery helper class for DriveTrashRecoveryTool.

    All dependencies on :class:`DriveTrashRecoveryTool` are injected at
    construction time so that neither class needs to define ``__getattr__``
    fallback delegation.
    """

    def __init__(
        self,
        args,
        logger: logging.Logger,
        auth: "DriveAuthManager",
        execute_fn: Callable[..., Any],
        *,
        stats: Dict[str, Any],
        stats_lock: Lock,
        seen_total_ref: List[int],
        generate_target_path: Callable[..., str],
        run_parallel_processing_for_batch: Callable[..., None],
    ) -> None:
        self.args = args
        self._console = ConsoleHelper(args)
        self.logger = logger
        self.auth = auth
        self._execute = execute_fn
        self._stats = stats
        self._stats_lock = stats_lock
        self._seen_total_ref = seen_total_ref
        self._generate_target_path = generate_target_path
        self._run_parallel_processing_for_batch = run_parallel_processing_for_batch
        self._with_retries = lambda *args, **kwargs: with_retries(*args, **kwargs)
        self._id_prefetcher = IdMetadataPrefetcher(self)
        self._last_discover_progress_ts: Optional[float] = None

    @property
    def _id_prefetch(self) -> Dict[str, Dict[str, Any]]:
        return self._id_prefetcher._id_prefetch

    @property
    def _id_prefetch_non_trashed(self) -> Dict[str, bool]:
        return self._id_prefetcher._id_prefetch_non_trashed

    @property
    def _id_prefetch_errors(self) -> Dict[str, str]:
        return self._id_prefetcher._id_prefetch_errors

    @staticmethod
    def _sanitize_path_component(name: str) -> str:
        """Sanitize a folder name for use as a local path component."""
        safe = "".join(c for c in name if c.isalnum() or c in (" ", "-", "_", ".")).rstrip()
        return safe or "unknown"

    def _matches_extension_filter(self, filename: str) -> bool:
        return matches_extension_filter(filename, self.args.extensions)

    def _matches_time_filter(self, item_data: Mapping[str, Any]) -> bool:
        try:
            return matches_time_filter(item_data, self.args.after_date)
        except (ValueError, TypeError, OverflowError) as e:
            self.logger.warning(f"Error applying time filter: {e}")
            return True

    def _progress_interval(self, total: int) -> int:
        if total <= 0:
            return 5
        return max(5, min(500, max(1, round(total * 0.02))))

    def _is_valid_file_id_format(self, file_id: str) -> bool:
        """Quick format check: Drive IDs are 25+ chars, [A-Za-z0-9_-]."""
        return re.match(r"[a-zA-Z0-9_-]{25,}$", file_id) is not None

    def _report_validation_outcome(
        self,
        buckets: Dict[str, List[str]],
        transient_errors: int,
        transient_ids: Optional[List[str]] = None,
    ) -> bool:
        """Print/log consolidated results and return overall success boolean."""
        if buckets["invalid"]:
            joined = ", ".join(buckets["invalid"])
            self.logger.error(f"Invalid file ID format: {joined}")
            self._console.print_err(f"Invalid file ID format: {joined}")
        if buckets["not_found"]:
            joined = ", ".join(buckets["not_found"])
            self.logger.error(f"File IDs not found: {joined}")
            self._console.print_err(f"File IDs not found: {joined}")
        if buckets["no_access"]:
            joined = ", ".join(buckets["no_access"])
            self.logger.error(f"Insufficient permissions for file IDs: {joined}")
            self._console.print_err(f"Insufficient permissions for file IDs: {joined}")
            print(
                "   Tip: Ensure the authenticated account has access, or re-authenticate with an account that does.",
                file=sys.stderr,
            )
        if transient_errors:
            self._console.print_warn(
                f"Validation encountered {transient_errors} transient error(s) (rate-limit/server)."
            )
            if transient_ids:
                joined = ", ".join(transient_ids)
                print(f"   Affected file IDs: {joined}")
                self.logger.warning(f"Transient validation errors for file IDs: {joined}")
            print(
                "   Suggestion: Re-run shortly, lower --concurrency, or re-try just the affected IDs.",
                file=sys.stderr,
            )

        success = (
            not buckets["invalid"]
            and not buckets["not_found"]
            and not buckets["no_access"]
            and transient_errors == 0
        )
        if success:
            self.logger.info(f"All {len(buckets['ok'])} file IDs validated successfully")
        return success

    def _validate_file_ids(self) -> bool:
        if not self.args.file_ids:
            return True
        result = self._id_prefetcher.prefetch_ids_metadata(self.args.file_ids)
        mismatch = False
        if getattr(self.args, "debug_parity", False):
            mismatch = self._id_prefetcher.emit_parity_metrics(result)
            if mismatch and getattr(self.args, "fail_on_parity_mismatch", False):
                self._console.print_err(
                    "Parity check failed during ID prefetch. See logs (use -vv) or --parity-metrics-file."
                )
                return False
        if getattr(self.args, "clear_id_cache", False):
            self._console.print_warn(
                "--clear-id-cache enabled: metadata cache will be cleared and IDs re-fetched during discovery/streaming."
            )
            self._clear_id_caches()
        buckets = {
            "ok": result.buckets.ok,
            "invalid": result.buckets.invalid,
            "not_found": result.buckets.not_found,
            "no_access": result.buckets.no_access,
        }
        return self._report_validation_outcome(
            buckets, result.counters.transient_errors, result.counters.transient_ids
        )

    def _clear_id_caches(self) -> None:
        self._id_prefetcher.clear_id_caches()

    def _fetch_and_handle_metadata(
        self,
        service,
        fid,
        fields,
        buckets,
        transient_errors,
        transient_ids,
        err_count,
    ):
        data, error, status = with_retries(
            lambda: self._execute(service.files().get(fileId=fid, fields=fields)),
            terminal_statuses=(403, 404),
            logger=self.logger,
            ctx=f"files.get(fileId={fid})",
        )
        if error is None:
            self._id_prefetcher._handle_prefetch_success(
                fid, data, self._id_prefetcher.prefetch_ids_metadata([])
            )
            return
        if status == 404:
            buckets["not_found"].append(fid)
            self._id_prefetch_errors[fid] = HTTP_404_LABEL
            return
        if status == 403:
            buckets["no_access"].append(fid)
            self._id_prefetch_errors[fid] = HTTP_403_LABEL
            return
        transient_errors[0] += 1
        transient_ids.append(fid)
        err_count[0] += 1
        self._id_prefetch_errors[fid] = error

    def _prefetch_ids_metadata(self, fids: List[str]):
        result = self._id_prefetcher.prefetch_ids_metadata(fids)
        buckets = {
            "ok": result.buckets.ok,
            "invalid": result.buckets.invalid,
            "not_found": result.buckets.not_found,
            "no_access": result.buckets.no_access,
        }
        return (
            buckets,
            result.counters.transient_errors,
            result.counters.transient_ids,
            result.counters.skipped_non_trashed,
            result.counters.err_count,
        )

    def _build_query(self) -> str:
        query = build_discovery_query(self.args.extensions, self.args.after_date)
        if self.args.after_date:
            self.logger.info(
                "Time-based filtering (--after-date) is applied server-side and revalidated client-side as a safety guard"
            )
        return query

    def _process_file_data(
        self, file_data: Mapping[str, Any] | FileMeta, relative_path: str = ""
    ) -> Optional[RecoveryItem]:
        if self.args.extensions and not self._matches_extension_filter(file_data.get("name", "")):
            return None

        if not self._matches_time_filter(file_data):
            return None

        file_id = file_data.get("id")
        if not file_id:
            self.logger.debug("Skipping file metadata without id: %s", file_data)
            return None

        # Files discovered via --folder-id or from a retry CSV are already live; skip untrash.
        will_recover = not bool(getattr(self.args, "folder_id", None)) and not bool(
            getattr(self.args, "_retry_mode", False)
        )

        dry_run_with_dir = self.args.mode == "dry_run" and bool(
            getattr(self.args, "download_dir", None)
        )
        will_download = self.args.mode == "recover_and_download" or dry_run_with_dir

        parents = file_data.get("parents") or []
        source_folder_id = parents[0] if parents else ""

        item = RecoveryItem(
            id=str(file_id),
            name=file_data.get("name", "Unknown"),
            size=int(file_data.get("size") or 0),
            mime_type=file_data.get("mimeType", ""),
            created_time=file_data.get("createdTime", ""),
            will_recover=will_recover,
            will_download=will_download,
            relative_path=relative_path,
            post_restore_action=PostRestorePolicy.normalize(self.args.post_restore_policy),
            source_folder_id=source_folder_id,
        )

        if self.args.mode == "recover_and_download" or dry_run_with_dir:
            item.target_path = self._generate_target_path(item)

        return item

    def _append_item_if_valid(
        self, items: List[RecoveryItem], file_data: Mapping[str, Any] | FileMeta
    ) -> None:
        item = self._process_file_data(file_data)
        if item:
            items.append(item)

    def _id_discovery_fields(self) -> str:
        base_fields = ["id", "name", "mimeType", "trashed", "createdTime", "parents"]
        dry_run_with_dir = self.args.mode == "dry_run" and bool(
            getattr(self.args, "download_dir", None)
        )
        if self.args.mode == "recover_and_download" or dry_run_with_dir:
            base_fields.append("size")
        if bool(self.args.after_date):
            base_fields.append("modifiedTime")
        return ", ".join(base_fields)

    def _maybe_print_discover_progress(self, idx, total, items, skipped, errors, start_time):
        if self.args.verbose < 1:
            return
        interval = self._progress_interval(total)
        now = time.time()
        due_count = (idx % interval) == 0
        due_time = (self._last_discover_progress_ts is None) or (
            (now - self._last_discover_progress_ts) >= 10
        )
        if due_count or due_time or idx == total:
            elapsed = max(0.001, now - start_time)
            rate = idx / elapsed
            remaining = max(0, total - idx)
            eta = (remaining / rate) if rate > 0 else 0
            print(
                f"Processing IDs: {idx}/{total} "
                f"(found: {len(items)}, skipped: {skipped}, errors: {errors}) "
                f"ETA: {eta:.0f}s"
            )
            self._last_discover_progress_ts = now

    def _print_discover_id_summary(self, items, skipped_non_trashed, errors):
        if skipped_non_trashed:
            self._console.print_info(f"Skipped {skipped_non_trashed} non-trashed file ID(s).")
        if errors:
            self._console.print_info(
                f"Encountered {errors} error(s) while fetching file ID metadata. See log for details."
            )
        if not items:
            self._console.print_warn(
                "No actionable trashed files were found from the provided --file-ids."
            )
            print("   All provided IDs may be invalid, not found, non-trashed, or inaccessible.")
            print(
                "   Tip: Re-check IDs from their Drive URLs and ensure they are currently in Trash."
            )

    def _discover_via_ids(self) -> List[RecoveryItem]:
        self.logger.info("Using per-ID lookups for discovery (--file-ids provided)")
        items: List[RecoveryItem] = []
        skipped_non_trashed = [0]
        errors = [0]
        total = len(self.args.file_ids)
        start_time = time.time()
        if not self._id_prefetch and self.args.file_ids:
            self._prefetch_ids_metadata(self.args.file_ids)
        for idx, fid in enumerate(self.args.file_ids, start=1):
            if fid in self._id_prefetch_errors:
                errors[0] += 1
                self.logger.error(f"Error fetching file {fid}: {self._id_prefetch_errors[fid]}")
                self._maybe_print_discover_progress(
                    idx, total, items, skipped_non_trashed[0], errors[0], start_time
                )
                continue
            if self._id_prefetch_non_trashed.get(fid, False):
                skipped_non_trashed[0] += 1
                self._maybe_print_discover_progress(
                    idx, total, items, skipped_non_trashed[0], errors[0], start_time
                )
                continue
            data = self._id_prefetch.get(fid)
            if data:
                self._append_item_if_valid(items, data)
            self._maybe_print_discover_progress(
                idx, total, items, skipped_non_trashed[0], errors[0], start_time
            )

        self._print_discover_id_summary(items, skipped_non_trashed[0], errors[0])
        return items

    def _iter_query_pages(self, query: str):
        page_token: Optional[str] = None
        page_count = 0
        while True:
            page_count += 1
            self.logger.debug(f"Fetching page {page_count}")
            files, page_token = self._fetch_files_page(query, page_token)
            yield page_count, files
            if not page_token:
                break

    def _fetch_files_page(
        self, query: str, page_token: Optional[str]
    ) -> Tuple[List[Dict[str, Any]], Optional[str]]:
        """Fetch one Drive files.list page for discovery paths."""
        service = self.auth._get_service()
        if service is None:
            raise RuntimeError("Drive service not initialized")
        fields = self._id_discovery_fields()
        response = self._execute(
            service.files().list(
                q=query,
                spaces="drive",
                fields=f"nextPageToken, files({fields})",
                pageToken=page_token,
                pageSize=PAGE_SIZE,
            )
        )
        return response.get("files", []), response.get("nextPageToken")

    def _discover_via_query(self, query: str) -> List[RecoveryItem]:
        items: List[RecoveryItem] = []
        try:
            for page_count, files in self._iter_query_pages(query):
                for file_data in files:
                    self._append_item_if_valid(items, file_data)
                    if self.args.limit and self.args.limit > 0 and len(items) >= self.args.limit:
                        break
                if self.args.verbose >= 1:
                    print(f"Found {len(files)} files in page {page_count} (total: {len(items)})")
                if self.args.limit and self.args.limit > 0 and len(items) >= self.args.limit:
                    break
        except Exception as e:
            self.logger.error(f"Error discovering files: {e}")
        return items

    def discover_trashed_files(self) -> List[RecoveryItem]:
        if self.args.file_ids:
            print(f"{self._console.sym_search()} Discovering trashed files...")
            items = self._discover_via_ids()
        elif getattr(self.args, "folder_id", None):
            print(
                f"{self._console.sym_search()} Discovering files in folder {self.args.folder_id} ..."
            )
            items = self._discover_folder_recursively()
        else:
            print(f"{self._console.sym_search()} Discovering trashed files...")
            query = self._build_query()
            self.logger.info(f"Using query: {query}")
            items = self._discover_via_query(query)
        if self.args.limit and self.args.limit > 0 and len(items) > self.args.limit:
            items = items[: self.args.limit]
            print(
                f"{self._console.sym_limit()} Limiting to first {self.args.limit} item(s) as requested."
            )
        self._stats["found"] = len(items)
        print(f"{self._console.sym_scope()} Total files discovered: {len(items)}")
        return items

    def _fetch_folder_page(
        self, folder_id: str, page_token: Optional[str]
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], Optional[str]]:
        """Fetch one page of a folder's direct children; return (files, subfolders, next_token)."""
        service = self.auth._get_service()
        if service is None:
            raise RuntimeError("Drive service not initialized")
        fields_str = self._id_discovery_fields()
        query = f"'{folder_id}' in parents and trashed=false"
        response = self._execute(
            service.files().list(
                q=query,
                spaces="drive",
                fields=f"nextPageToken, files({fields_str})",
                pageToken=page_token,
                pageSize=PAGE_SIZE,
            )
        )
        all_children = response.get("files", [])
        files = [f for f in all_children if f.get("mimeType") != FOLDER_MIME_TYPE]
        subfolders = [f for f in all_children if f.get("mimeType") == FOLDER_MIME_TYPE]
        return files, subfolders, response.get("nextPageToken")

    def _collect_items_from_page(
        self,
        files: List[Dict[str, Any]],
        items: List[RecoveryItem],
        prefix: str,
    ) -> bool:
        """Append valid items from one page of files. Returns True if the global limit is reached."""
        for fd in files:
            item = self._process_file_data(fd, relative_path=prefix)
            if item:
                items.append(item)
                if self.args.limit and self.args.limit > 0 and len(items) >= self.args.limit:
                    return True
        return False

    def _enqueue_subfolders(
        self,
        queue: Deque[Tuple[str, str]],
        subfolders: List[Dict[str, Any]],
        prefix: str,
    ) -> None:
        """Push each subfolder onto the BFS queue with an updated path prefix."""
        for sf in subfolders:
            sf_safe = self._sanitize_path_component(sf.get("name", sf.get("id", "unknown")))
            sub_prefix = f"{prefix}/{sf_safe}" if prefix else sf_safe
            queue.append((sf["id"], sub_prefix))

    def _traverse_folder_pages(
        self,
        folder_id: str,
        prefix: str,
        items: List[RecoveryItem],
        queue: Deque[Tuple[str, str]],
    ) -> bool:
        """Paginate through one folder, collecting items. Returns True when the limit is reached."""
        page_token: Optional[str] = None
        while True:
            try:
                files, subfolders, page_token = self._fetch_folder_page(folder_id, page_token)
            except Exception as e:
                self.logger.error("Error fetching folder %s: %s", folder_id, e)
                return False
            if self._collect_items_from_page(files, items, prefix):
                return True
            self._enqueue_subfolders(queue, subfolders, prefix)
            if not page_token:
                break
        return False

    def _bfs_traverse_folders(
        self,
        visit_folder: Callable[[str, str, Deque[Tuple[str, str]]], bool],
    ) -> None:
        """Shared BFS traversal for folder-scoped batch and streaming discovery."""
        queue: Deque[Tuple[str, str]] = deque([(self.args.folder_id, "")])
        while queue:
            folder_id, prefix = queue.popleft()
            if not visit_folder(folder_id, prefix, queue):
                break

    def _discover_folder_recursively(self) -> List[RecoveryItem]:
        """BFS traversal of a Drive folder tree; returns all matching non-trashed files."""
        items: List[RecoveryItem] = []

        def _visit(folder_id: str, prefix: str, queue: Deque[Tuple[str, str]]) -> bool:
            self.logger.info("Traversing folder %s (prefix=%r)", folder_id, prefix)
            return not self._traverse_folder_pages(folder_id, prefix, items, queue)

        self._bfs_traverse_folders(_visit)
        return items

    def _stream_files_from_page(
        self,
        files: List[Dict[str, Any]],
        prefix: str,
        batch: List[RecoveryItem],
        batch_n: int,
        start_time: float,
    ) -> None:
        """Enqueue valid items from one page of files into the streaming batch."""
        for fd in files:
            item = self._process_file_data(fd, relative_path=prefix)
            if item:
                self._enqueue_streaming_item(item, batch, batch_n, start_time)
            if self._should_stop_for_limit():
                break

    def _stream_folder_pages(
        self,
        folder_id: str,
        prefix: str,
        batch: List[RecoveryItem],
        batch_n: int,
        start_time: float,
        queue: Deque[Tuple[str, str]],
    ) -> bool:
        """Paginate through one folder in streaming mode. Returns False on fetch error."""
        page_token: Optional[str] = None
        while True:
            try:
                files, subfolders, page_token = self._fetch_folder_page(folder_id, page_token)
            except Exception as e:
                self.logger.error("Error fetching folder %s: %s", folder_id, e)
                return False
            self._stream_files_from_page(files, prefix, batch, batch_n, start_time)
            if not self._should_stop_for_limit():
                self._enqueue_subfolders(queue, subfolders, prefix)
            if not page_token or self._should_stop_for_limit():
                break
        return True

    def _stream_stream_folder(self, batch_n: int, start_time: float) -> bool:
        """BFS streaming traversal of a Drive folder tree, processing items in bounded batches."""
        ok = True
        batch: List[RecoveryItem] = []

        def _visit(folder_id: str, prefix: str, queue: Deque[Tuple[str, str]]) -> bool:
            nonlocal ok
            if self._should_stop_for_limit():
                return False
            self.logger.info("Streaming folder %s (prefix=%r)", folder_id, prefix)
            if not self._stream_folder_pages(folder_id, prefix, batch, batch_n, start_time, queue):
                ok = False
            return not self._should_stop_for_limit()

        self._bfs_traverse_folders(_visit)
        if batch:
            self._process_streaming_batch(batch, start_time)
        return ok

    def _stream_stream_query(self, batch_n: int, start_time: float) -> bool:
        ok = True
        query = self._build_query()
        self.logger.info(f"Using query (streaming): {query}")
        batch: List[RecoveryItem] = []
        try:
            for page_count, files in self._iter_query_pages(query):
                for fd in files:
                    self._handle_streaming_file(fd, batch, batch_n, start_time)
                    if self._should_stop_for_limit():
                        break
                if self.args.verbose >= 1:
                    print(
                        f"Found {len(files)} files in page {page_count} (streamed total: {self._seen_total_ref[0]})"
                    )
                if self._should_stop_for_limit():
                    break
        except Exception as e:
            ok = False
            self.logger.error(f"Error in streaming discovery: {e}")
        if batch:
            self._process_streaming_batch(batch, start_time)
        return ok

    def _should_stop_for_limit(self) -> bool:
        """Return True if the user-provided --limit has been reached."""
        return (
            self.args.limit and self.args.limit > 0 and self._seen_total_ref[0] >= self.args.limit
        )

    def _process_streaming_batch(self, batch: List[RecoveryItem], start_time: float) -> None:
        """Process the current streaming batch and clear in-memory references."""
        self._run_parallel_processing_for_batch(batch, start_time)
        batch.clear()

    def _handle_streaming_file(
        self, fd: Dict[str, Any], batch: List[RecoveryItem], batch_n: int, start_time: float
    ) -> None:
        """Process a single files.list item during streaming query discovery."""
        item = self._process_file_data(fd)
        if item:
            self._enqueue_streaming_item(item, batch, batch_n, start_time)

    def _should_flush_streaming_batch(self, batch: List[RecoveryItem], batch_n: int) -> bool:
        """Return True if the streaming batch should be processed now."""
        return len(batch) >= batch_n

    def _enqueue_streaming_item(
        self,
        item: RecoveryItem,
        batch: List[RecoveryItem],
        batch_n: int,
        start_time: float,
    ) -> None:
        """Append a validated item to the streaming batch and flush when ready."""
        if self.args.mode == "recover_and_download" and not item.target_path:
            item.target_path = self._generate_target_path(item)
        batch.append(item)
        with self._stats_lock:
            self._seen_total_ref[0] += 1
            self._stats["found"] += 1
        if self._should_flush_streaming_batch(batch, batch_n):
            self._process_streaming_batch(batch, start_time)

    def _handle_streaming_id_fetch(self, fid, fields, service):
        data = self._id_prefetch.get(fid)
        if data is None:
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
            except Exception as e:
                self.logger.error(f"Error fetching metadata for {fid}: {e}")
                with self._stats_lock:
                    self._stats["errors"] += 1
                return None
        return data

    def _handle_streaming_id_item(
        self,
        item: Optional[RecoveryItem],
        batch: List[RecoveryItem],
        batch_n: int,
        start_time: float,
    ) -> None:
        if item:
            self._enqueue_streaming_item(item, batch, batch_n, start_time)

    def _maybe_print_streaming_id_progress(self, idx, total_ids, start_ts):
        if self.args.verbose >= 1:
            now = time.time()
            if (now - start_ts) >= 10:
                print(
                    f"Processing IDs: {idx}/{total_ids} (streamed total: {self._seen_total_ref[0]})"
                )
                return now
        return start_ts

    def _stream_stream_ids(self, batch_n: int, start_time: float) -> bool:
        ok = True
        batch: List[RecoveryItem] = []
        fields = self._id_discovery_fields()
        service = self.auth._get_service()
        total_ids = len(self.args.file_ids or [])
        start_ts = time.time()
        for idx, fid in enumerate(self.args.file_ids, start=1):
            if fid in self._id_prefetch_errors:
                self.logger.error("Error fetching file %s: %s", fid, self._id_prefetch_errors[fid])
                with self._stats_lock:
                    self._stats["errors"] += 1
                ok = False
                start_ts = self._maybe_print_streaming_id_progress(idx, total_ids, start_ts)
                continue
            if self._id_prefetch_non_trashed.get(fid, False):
                start_ts = self._maybe_print_streaming_id_progress(idx, total_ids, start_ts)
                continue
            data = self._handle_streaming_id_fetch(fid, fields, service)
            if data is None:
                ok = False
            item = self._process_file_data(data) if data else None
            self._handle_streaming_id_item(item, batch, batch_n, start_time)
            start_ts = self._maybe_print_streaming_id_progress(idx, total_ids, start_ts)
        if batch:
            self._run_parallel_processing_for_batch(batch, start_time)
        return ok
