"""Discovery and ID validation helpers for Google Drive trash recovery."""

import io
import json
import random
import re
import sys
import time
from datetime import timezone
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Tuple

from dateutil import parser as date_parser

from gdrive_constants import EXTENSION_MIME_TYPES, MAX_RETRIES, PAGE_SIZE, RETRY_DELAY
from gdrive_models import FileMeta, RecoveryItem, PostRestorePolicy
from googleapiclient.errors import HttpError


class DriveTrashDiscovery:
    """Extracted discovery helper class for DriveTrashRecoveryTool."""

    def __init__(self, tool):
        self.tool = tool
        self.args = tool.args
        self.logger = tool.logger
        self.auth = tool.auth
        self._execute = tool._execute
        self._id_prefetch: Dict[str, Dict[str, Any]] = {}
        self._id_prefetch_non_trashed: Dict[str, bool] = {}
        self._id_prefetch_errors: Dict[str, str] = {}
        self._last_discover_progress_ts: Optional[float] = None

    def __getattr__(self, name: str):
        return getattr(self.tool, name)

    def _print_err(self, msg: str) -> None:
        self.tool._print_err(msg)

    def _print_warn(self, msg: str) -> None:
        self.tool._print_warn(msg)

    def _print_info(self, msg: str) -> None:
        self.tool._print_info(msg)

    def _is_valid_file_id_format(self, file_id: str) -> bool:
        """Quick format check: Drive IDs are 25+ chars, [A-Za-z0-9_-]."""
        return re.match(r"[a-zA-Z0-9_-]{25,}$", file_id) is not None

    def _extract_status_from_http_error(self, e: Exception):
        return getattr(getattr(e, "resp", None), "status", None)

    def _log_terminal_id_validation_error(self, e, file_id, status):
        if isinstance(e, HttpError):
            self.logger.error(
                f"files.get(fileId={file_id}) failed during validation: HTTP {status}: {e}"
            )
        else:
            self.logger.error(f"Validation error for fileId {file_id}: {e}")

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
            self._print_err(f"Invalid file ID format: {joined}")
        if buckets["not_found"]:
            joined = ", ".join(buckets["not_found"])
            self.logger.error(f"File IDs not found: {joined}")
            self._print_err(f"Invalid file ID format: {joined}")
        if buckets["no_access"]:
            joined = ", ".join(buckets["no_access"])
            self.logger.error(f"Insufficient permissions for file IDs: {joined}")
            self._print_err(f"Insufficient permissions for file IDs: {joined}")
            print(
                "   Tip: Ensure the authenticated account has access, or re-authenticate with an account that does.",
                file=sys.stderr,
            )
        if transient_errors:
            self._print_warn(
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

    def _handle_prefetch_success(self, fid, data, buckets, skipped_non_trashed):
        self._id_prefetch[fid] = data
        if data.get("trashed", False):
            buckets["ok"].append(fid)
            self._id_prefetch_non_trashed[fid] = False
        else:
            self._id_prefetch_non_trashed[fid] = True
            skipped_non_trashed[0] += 1

    def _handle_prefetch_error(
        self,
        fid,
        status,
        e,
        attempt,
        buckets,
        transient_errors,
        transient_ids,
        err_count,
    ):
        if status == 404:
            buckets["not_found"].append(fid)
            self._id_prefetch_errors[fid] = "HTTP 404"
            return True
        if status == 403:
            buckets["no_access"].append(fid)
            self._id_prefetch_errors[fid] = "HTTP 403"
            return True
        should_retry = status in (429, 500, 502, 503, 504)
        if should_retry and attempt < MAX_RETRIES - 1:
            self._log_fetch_metadata_retry(fid, e, status, attempt)
            return False
        transient_errors[0] += 1
        transient_ids.append(fid)
        self._id_prefetch_errors[fid] = self._format_fetch_metadata_error_with_context(
            e, status, fid
        )
        err_count[0] += 1
        return True

    def _should_skip_invalid_id(self, fid, buckets):
        if not self._is_valid_file_id_format(fid):
            buckets["invalid"].append(fid)
            return True
        return False

    def _fetch_and_handle_metadata(
        self,
        service,
        fid,
        fields,
        buckets,
        skipped_non_trashed,
        transient_errors,
        transient_ids,
        err_count,
    ):
        for attempt in range(MAX_RETRIES):
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
                self._handle_prefetch_success(fid, data, buckets, skipped_non_trashed)
                return
            except Exception as e:
                status = getattr(e, "resp", None)
                status = getattr(status, "status", None) if status else None
                handled = self._handle_prefetch_error(
                    fid,
                    status,
                    e,
                    attempt,
                    buckets,
                    transient_errors,
                    transient_ids,
                    err_count,
                )
                if handled:
                    return

    def _prefetch_ids_metadata(
        self, fids: List[str]
    ) -> Tuple[Dict[str, List[str]], int, List[str], int, int]:
        service = self.auth._get_service()
        fields = self._id_discovery_fields()
        buckets: Dict[str, List[str]] = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
        transient_errors = [0]
        transient_ids: List[str] = []
        skipped_non_trashed = [0]
        err_count = [0]

        for fid in fids:
            if self._should_skip_invalid_id(fid, buckets):
                continue
            self._fetch_and_handle_metadata(
                service,
                fid,
                fields,
                buckets,
                skipped_non_trashed,
                transient_errors,
                transient_ids,
                err_count,
            )

        return (
            buckets,
            transient_errors[0],
            transient_ids,
            skipped_non_trashed[0],
            err_count[0],
        )

    def _emit_parity_metrics(
        self, buckets: Dict[str, List[str]], skipped_non_trashed: int, err_count: int
    ) -> bool:
        try:
            total_input = len(self.args.file_ids or [])
            classified = sum(len(v) for v in buckets.values())
            seen = classified + skipped_non_trashed + err_count
            mismatch = total_input != seen
            metrics = {
                "metric": "parity_check",
                "total_input": total_input,
                "classified": classified,
                "skipped_non_trashed": skipped_non_trashed,
                "errors": err_count,
                "seen": seen,
                "mismatch": mismatch,
            }
            self.logger.debug("METRIC %s", json.dumps(metrics))
            out_file = getattr(self.args, "parity_metrics_file", None)
            if out_file:
                try:
                    with open(out_file, "w") as fh:
                        json.dump(metrics, fh, indent=2)
                except Exception as e:
                    self.logger.warning(
                        "Failed to write --parity-metrics-file '%s': %s", out_file, e
                    )
            if mismatch:
                self.logger.warning(
                    "Parity check mismatch: input=%d, seen=%d (classified=%d, skipped_non_trashed=%d, errors=%d).",
                    total_input,
                    seen,
                    classified,
                    skipped_non_trashed,
                    err_count,
                )
            return mismatch
        except Exception as e:
            self.logger.debug("Parity metrics emission failed: %s", e)
            return False

    def _validate_file_ids(self) -> bool:
        if not self.args.file_ids:
            return True
        buckets, transient_errors, transient_ids, skipped_non_trashed, err_count = (
            self._prefetch_ids_metadata(self.args.file_ids)
        )
        mismatch = False
        if getattr(self.args, "debug_parity", False):
            mismatch = self._emit_parity_metrics(buckets, skipped_non_trashed, err_count)
            if mismatch and getattr(self.args, "fail_on_parity_mismatch", False):
                self._print_err(
                    "Parity check failed during ID prefetch. See logs (use -vv) or --parity-metrics-file."
                )
                return False
        if getattr(self.args, "clear_id_cache", False):
            self._clear_id_caches()
        return self._report_validation_outcome(buckets, transient_errors, transient_ids)

    def _clear_id_caches(self) -> None:
        self._id_prefetch.clear()
        self._id_prefetch_non_trashed.clear()
        self._id_prefetch_errors.clear()

    def _build_query(self) -> str:
        base_query = "trashed=true"

        if self.args.extensions:
            mime_conditions = []
            for ext in self.args.extensions:
                ext_normalized = ext.lower().strip(".")
                last_seg = ext_normalized.split(".")[-1] if ext_normalized else ext_normalized
                if last_seg in EXTENSION_MIME_TYPES:
                    mime_type = EXTENSION_MIME_TYPES[last_seg]
                    mime_conditions.append(f"mimeType = '{mime_type}'")
            if mime_conditions:
                extensions_query = f"({' or '.join(mime_conditions)})"
                base_query += f" and {extensions_query}"

        if self.args.after_date:
            self.logger.warning(
                "Time-based filtering (--after-date) will be applied client-side due to Drive API limitations"
            )

        return base_query

    def _process_file_data(self, file_data: Mapping[str, Any] | FileMeta) -> Optional[RecoveryItem]:
        if self.args.extensions and not self._matches_extension_filter(file_data.get("name", "")):
            return None

        if not self._matches_time_filter(file_data):
            return None

        item = RecoveryItem(
            id=file_data["id"],
            name=file_data.get("name", "Unknown"),
            size=int(file_data.get("size", 0)),
            mime_type=file_data.get("mimeType", ""),
            created_time=file_data.get("createdTime", ""),
            will_download=self.args.mode == "recover_and_download",
            post_restore_action=PostRestorePolicy.normalize(self.args.post_restore_policy),
        )

        if self.args.mode == "recover_and_download":
            item.target_path = self.tool._generate_target_path(item)

        return item

    def _append_item_if_valid(
        self, items: List[RecoveryItem], file_data: Mapping[str, Any] | FileMeta
    ) -> None:
        item = self._process_file_data(file_data)
        if item:
            items.append(item)

    def _id_discovery_fields(self) -> str:
        base_fields = ["id", "name", "mimeType", "trashed", "createdTime"]
        if self.args.mode == "recover_and_download":
            base_fields.append("size")
        if bool(self.args.after_date):
            base_fields.append("modifiedTime")
        return ", ".join(base_fields)

    def _format_fetch_metadata_error_with_context(
        self, e: Exception, status: Optional[int], fid: str
    ) -> str:
        if status is not None:
            detail = getattr(e, "content", b"")
            detail_str = detail.decode(errors="ignore") if hasattr(detail, "decode") else str(e)
            return f"files.get(fileId={fid}) failed: HTTP {status}: {detail_str}"
        else:
            return f"files.get(fileId={fid}) failed: {e}"

    def _log_fetch_metadata_retry(
        self, fid: str, e: Exception, status: Optional[int], attempt: int
    ):
        delay = (RETRY_DELAY**attempt) * random.uniform(0.5, 1.5)
        if status is not None:
            self.logger.warning(
                f"Rate/Server error for {fid} (HTTP {status}). Retrying in {delay:.2f}s..."
            )
        else:
            self.logger.warning(f"Error fetching file {fid} ({e}). Retrying in {delay:.2f}s...")
        time.sleep(delay)

    def _fetch_file_metadata(
        self, service, fid: str, fields: str
    ) -> Tuple[Optional[Dict[str, Any]], bool, Optional[str]]:
        for attempt in range(MAX_RETRIES):
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
                if data.get("trashed", False):
                    return data, False, None
                return None, True, None
            except Exception as e:
                status = getattr(getattr(e, "resp", None), "status", None)
                retryable = status in (429, 500, 502, 503, 504)
                if retryable and attempt < MAX_RETRIES - 1:
                    self._log_fetch_metadata_retry(fid, e, status, attempt)
                    continue
                return (
                    None,
                    False,
                    self._format_fetch_metadata_error_with_context(e, status, fid),
                )
        return None, False, "Unknown error"

    def _handle_discover_id_result(
        self, items, data, non_trashed, err, fid, skipped_non_trashed_ref, errors_ref
    ):
        if non_trashed:
            skipped_non_trashed_ref[0] += 1
            self.logger.debug(f"Skipping non-trashed file {fid}")
            return
        if err:
            errors_ref[0] += 1
            self.logger.error(f"Error fetching file {fid}: {err}")
            return
        self._append_item_if_valid(items, data)  # type: ignore[arg-type]

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
            print(f"ℹ️  Skipped {skipped_non_trashed} non-trashed file ID(s).")
        if errors:
            self._print_info(
                f"Encountered {errors} error(s) while fetching file ID metadata. See log for details."
            )
        if not items:
            self._print_warn("No actionable trashed files were found from the provided --file-ids.")
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
            return []
        return items

    def discover_trashed_files(self) -> List[RecoveryItem]:
        print("🔍 Discovering trashed files...")
        if self.args.file_ids:
            items = self._discover_via_ids()
        else:
            query = self._build_query()
            self.logger.info(f"Using query: {query}")
            items = self._discover_via_query(query)
        if self.args.limit and self.args.limit > 0 and len(items) > self.args.limit:
            items = items[: self.args.limit]
            print(f"⛳ Limiting to first {self.args.limit} item(s) as requested.")
        self.tool.stats["found"] = len(items)
        print(f"📊 Total files discovered: {len(items)}")
        return items

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
                        f"Found {len(files)} files in page {page_count} (streamed total: {self.tool._seen_total})"
                    )
                if self._should_stop_for_limit():
                    break
        except Exception as e:
            ok = False
            self.logger.error(f"Error in streaming discovery: {e}")
        if batch:
            self._process_streaming_batch(batch, start_time)
        return ok

    def _handle_streaming_id_fetch(self, fid, fields, service):
        data = self._id_prefetch.get(fid)
        if data is None:
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
            except Exception as e:
                self.logger.error(f"Error fetching metadata for {fid}: {e}")
                with self.tool.stats_lock:
                    self.tool.stats["errors"] += 1
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
            if self.args.mode == "recover_and_download" and not item.target_path:
                item.target_path = self.tool._generate_target_path(item)
            batch.append(item)
            self.tool._seen_total += 1
            self.tool.stats["found"] += 1
            if self._should_flush_streaming_batch(batch, batch_n):
                self.tool._run_parallel_processing_for_batch(batch, start_time)

    def _maybe_print_streaming_id_progress(self, idx, total_ids, start_ts):
        if self.args.verbose >= 1:
            now = time.time()
            if (now - start_ts) >= 10:
                print(
                    f"Processing IDs: {idx}/{total_ids} (streamed total: {self.tool._seen_total})"
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
            data = self._handle_streaming_id_fetch(fid, fields, service)
            item = self._process_file_data(data) if data else None
            self._handle_streaming_id_item(item, batch, batch_n, start_time)
            start_ts = self._maybe_print_streaming_id_progress(idx, total_ids, start_ts)
        if batch:
            self.tool._run_parallel_processing_for_batch(batch, start_time)
        return ok
