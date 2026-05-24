"""ID metadata prefetching and validation helpers for Drive trash discovery."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional

from gdrive_retry import with_retries


class ValidationBucket(str, Enum):
    OK = "ok"
    INVALID = "invalid"
    NOT_FOUND = "not_found"
    NO_ACCESS = "no_access"


@dataclass
class ValidationBuckets:
    ok: List[str] = field(default_factory=list)
    invalid: List[str] = field(default_factory=list)
    not_found: List[str] = field(default_factory=list)
    no_access: List[str] = field(default_factory=list)

    def add(self, bucket: ValidationBucket, file_id: str) -> None:
        getattr(self, bucket.value).append(file_id)


@dataclass
class PrefetchCounters:
    transient_errors: int = 0
    skipped_non_trashed: int = 0
    err_count: int = 0
    transient_ids: List[str] = field(default_factory=list)


@dataclass
class PrefetchResult:
    buckets: ValidationBuckets = field(default_factory=ValidationBuckets)
    counters: PrefetchCounters = field(default_factory=PrefetchCounters)


def classify_http_status(status: Optional[int]) -> Optional[ValidationBucket]:
    if status == 404:
        return ValidationBucket.NOT_FOUND
    if status == 403:
        return ValidationBucket.NO_ACCESS
    return None


class IdMetadataPrefetcher:
    def __init__(self, parent):
        self.parent = parent
        self._id_prefetch: Dict[str, Dict[str, Any]] = {}
        self._id_prefetch_non_trashed: Dict[str, bool] = {}
        self._id_prefetch_errors: Dict[str, str] = {}

    def clear_id_caches(self) -> None:
        self._id_prefetch.clear(); self._id_prefetch_non_trashed.clear(); self._id_prefetch_errors.clear()

    def _handle_prefetch_success(self, fid: str, data: Dict[str, Any], result: PrefetchResult) -> None:
        self._id_prefetch[fid] = data
        if data.get("trashed", False): result.buckets.add(ValidationBucket.OK, fid); self._id_prefetch_non_trashed[fid]=False
        else: self._id_prefetch_non_trashed[fid]=True; result.counters.skipped_non_trashed += 1

    def _should_skip_invalid_id(self, fid: str, result: PrefetchResult) -> bool:
        if not self.parent._is_valid_file_id_format(fid):
            result.buckets.add(ValidationBucket.INVALID, fid); return True
        return False

    def _classify_prefetched_id(self, fid: str, result: PrefetchResult) -> bool:
        if fid in self._id_prefetch_errors:
            err=self._id_prefetch_errors[fid]
            if err=="HTTP 404": result.buckets.add(ValidationBucket.NOT_FOUND, fid)
            elif err=="HTTP 403": result.buckets.add(ValidationBucket.NO_ACCESS, fid)
            else: result.counters.transient_errors += 1; result.counters.transient_ids.append(fid); result.counters.err_count += 1
            return True
        if self._id_prefetch_non_trashed.get(fid, False): result.counters.skipped_non_trashed += 1; return True
        if fid in self._id_prefetch: result.buckets.add(ValidationBucket.OK, fid); return True
        return False

    def _fetch_and_handle_metadata(self, service, fid: str, fields: str, result: PrefetchResult) -> None:
        data,error,status=self.parent._with_retries(lambda: self.parent._execute(service.files().get(fileId=fid, fields=fields)), terminal_statuses=(403,404), logger=self.parent.logger, ctx=f"files.get(fileId={fid})")
        if error is None:
            self._handle_prefetch_success(fid,data,result); return
        cls=classify_http_status(status)
        if cls is ValidationBucket.NOT_FOUND:
            result.buckets.add(ValidationBucket.NOT_FOUND,fid); self._id_prefetch_errors[fid]="HTTP 404"; return
        if cls is ValidationBucket.NO_ACCESS:
            result.buckets.add(ValidationBucket.NO_ACCESS,fid); self._id_prefetch_errors[fid]="HTTP 403"; return
        result.counters.transient_errors += 1; result.counters.transient_ids.append(fid); self._id_prefetch_errors[fid]=error; result.counters.err_count += 1

    def prefetch_ids_metadata(self, fids: List[str]) -> PrefetchResult:
        service=self.parent.auth._get_service(); fields=self.parent._id_discovery_fields(); result=PrefetchResult()
        for fid in fids:
            if self._should_skip_invalid_id(fid,result): continue
            if self._classify_prefetched_id(fid,result): continue
            self._fetch_and_handle_metadata(service,fid,fields,result)
        return result

    def emit_parity_metrics(self, result: PrefetchResult) -> bool:
        try:
            total_input = len(self.parent.args.file_ids or [])
            buckets = result.buckets
            classified = len(buckets.ok)+len(buckets.invalid)+len(buckets.not_found)+len(buckets.no_access)
            c = result.counters
            seen = classified + c.skipped_non_trashed + c.err_count
            mismatch = total_input != seen
            metrics = {"metric":"parity_check","total_input":total_input,"classified":classified,"skipped_non_trashed":c.skipped_non_trashed,"errors":c.err_count,"seen":seen,"mismatch":mismatch}
            self.parent.logger.debug("METRIC %s", json.dumps(metrics))
            out_file = getattr(self.parent.args, "parity_metrics_file", None)
            if out_file:
                with open(out_file, "w", encoding="utf-8") as fh: json.dump(metrics, fh, indent=2)
            if mismatch:
                self.parent.logger.warning("Parity check mismatch: input=%d, seen=%d (classified=%d, skipped_non_trashed=%d, errors=%d).", total_input, seen, classified, c.skipped_non_trashed, c.err_count)
            return mismatch
        except Exception as e:
            self.parent.logger.debug("Parity metrics emission failed: %s", e); return False
