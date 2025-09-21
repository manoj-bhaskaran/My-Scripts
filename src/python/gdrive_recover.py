"""
Google Drive Trash Recovery Tool
A comprehensive tool to recover files from Google Drive Trash at scale with configurable options.

This tool provides:
- Bulk recovery of trashed files with optional extension filtering
- Optional download to local directory with conflict-safe filenames
- Configurable post-restore policies (retain/trash/delete with aliases)
- Comprehensive Dry Run mode with full planning and privilege validation
- Resume capability for interrupted operations
- Progress tracking and detailed summaries
"""

__version__ = "1.5.5"

# CHANGELOG
"""
## [1.5.5] - 2025-09-21

### Throughput & Safety
- **Rate limiter lock granularity:** token acquisition now uses a short critical section with
  double-checked token consumption; any required sleep happens **outside** the lock.
- **Monotonic timing:** switch limiter timestamps to `time.monotonic()` for correctness across clock changes.
- **Stable capacity:** token-bucket capacity is initialized once (no per-refill resets).
- **Diagnostics:** new `--rl-diagnostics` to emit sampled limiter stats at DEBUG (tokens, capacity, observed RPS).
  Helps validate that RPS stays within ±10% of `--max-rps` over a 60s window.

## [1.5.4] - 2025-09-20

### Safety & Hotfixes
- **Client-per-thread Drive service (default ON):** new `--client-per-thread` (on by default) and `--single-client` (to disable).
  Builds a Drive API client per worker thread to avoid shared-object contention.
- **State file durability:** atomic writes (`.tmp` + `os.replace`) and advisory lock (`.lock`) across POSIX/Windows.
  On lock contention, exit with a clear message.
- **Partial downloads:** write to `*.partial` and rename on success; remove partials on failure/interrupt.
- **Progress parity nudge:** execution progress now prints at least every 10s with `-v`, in addition to item-interval.
 
## [1.5.3] - 2025-09-20

### Fixed
- **Validation chain:** all argument validations now short-circuit on failure (main respected return codes).
- **No-command UX:** printing help and exiting with non-zero when no subcommand is provided.
- **Discovery verbosity:** noisy per-page discovery messages respect `-v` like execution progress.

### Polished
- Minor logging/context tweaks; small doc updates in help text.

## [1.5.2] - 2025-09-20

### Hardened
- **Rate limiting (quick hardening):** token-bucket wrapper (opt-in) via `--burst` on top of fixed RPS pacing.
  Still conservative by default; `--max-rps 0` disables pacing entirely.
- **Progress consistency:** execution-phase progress respects `-v` just like discovery; final summary always printed.
- **Parity & cache controls:** parity checks are now opt-in via `--debug-parity`; add `--clear-id-cache` to
  flush validation caches before discovery.

### Validation
- **Extensions:** accept multi-segment tokens (e.g., `tar.gz`, `min.js`) during input validation;
  segments must be `[a-z0-9]{1,10}`. Multi-segment tokens are matched client-side; server-side
  MIME narrowing still uses single-segment mapping when available.

### Policy UX
- **Unknown policy feedback:** warn once when an unknown token is normalized to `trash`. Use `--strict-policy`
  to treat unknown tokens as an error.

### Notes
- Backwards-compatible; new flags are optional.

## [1.5.1] - 2025-09-19

### Added
- **Rate limiting** behind conservative defaults: new `--max-rps` to cap Drive API requests-per-second
  across validation, discovery, recovery, post-restore actions, and downloads. Defaults to `5.0` RPS.
- **Streaming downloads**: chunked `MediaIoBaseDownload` with progress output (respects rate limiter).
- **Execution limiter**: new `--limit` to cap the number of items discovered/processed (useful for canary runs).

### Notes
- Non-breaking. Defaults are conservative. Set `--max-rps 0` to disable throttling.

## [1.5.0] - 2025-09-19

### Changed
- **Service simplification**: replace thread-local service factory with a single lazily-initialized Drive
  client (`self._service`) shared across the app.
- **Policy consolidation + aliases**: post-restore policies are now normalized to canonical short
  forms: `retain`, `trash`, `delete`. Backwards-compatible aliases like `RetainOnDrive`, `MoveToDriveTrash`,
  `RemoveFromDrive`, `Keep`, `Trash`, `Delete`, `Purge`, etc., are accepted.
- **Complexity reductions**: tightened small helpers and removed redundant conditionals around post-restore handling.

### Notes
- No breaking CLI changes; additional policy aliases are accepted. Minor bump due to refactors.
"""

import os
import io
import json
import time
import argparse
import logging
import shutil
import re
import random
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
from dataclasses import dataclass, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock, local
import sys

try:
    from dateutil import parser as date_parser
except ImportError:
    print("ERROR: Missing optional dependency 'python-dateutil' required for --after-date parsing.")
    print("Install with: pip install python-dateutil")
    sys.exit(1)

try:
    from googleapiclient.discovery import build
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.http import MediaIoBaseDownload
    from googleapiclient.errors import HttpError
except ImportError:
    print("ERROR: Required Google API libraries not installed.")
    print("Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib")
    sys.exit(1)

# Configuration constants
SCOPES = ['https://www.googleapis.com/auth/drive']
DEFAULT_STATE_FILE = 'gdrive_recovery_state.json'
DEFAULT_LOG_FILE = 'gdrive_recovery.log'
MAX_RETRIES = 3
RETRY_DELAY = 2  # seconds
PAGE_SIZE = 1000
DEFAULT_WORKERS = 5
INFERRED_MODIFY_ERROR = "Cannot modify file (inferred from untrash check)"
DEFAULT_MAX_RPS = 5.0  # conservative default; set 0 to disable
DEFAULT_BURST = 0      # token bucket capacity; 0 = disabled (legacy pacing)
DOWNLOAD_CHUNK_BYTES = 1024 * 1024  # 1 MiB

# Extension to MIME type mapping for robust server-side filtering
EXTENSION_MIME_TYPES = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg', 
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'tiff': 'image/tiff',
    'tif': 'image/tiff',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed'
}

@dataclass
class RecoveryItem:
    """Represents a file to be recovered."""
    id: str
    name: str
    size: int
    mime_type: str
    created_time: str
    will_recover: bool = True
    will_download: bool = False
    target_path: str = ""
    post_restore_action: str = "trash"  # canonical default
    status: str = "pending"  # pending, recovered, downloaded, failed
    error_message: str = ""

@dataclass
class RecoveryState:
    """Persistent state for resume capability."""
    total_found: int = 0
    processed_items: Optional[List[str]] = None  # List of processed file IDs
    start_time: str = ""
    last_checkpoint: str = ""
    
    def __post_init__(self):
        if self.processed_items is None:
            self.processed_items = []

class PostRestorePolicy:
    """Post-restore policy options."""
    # Canonical short forms used internally
    RETAIN = "retain"
    TRASH = "trash"
    DELETE = "delete"

    # Back-compat & friendly aliases → canonical
    ALIASES: Dict[str, str] = {
        # canonical
        "retain": RETAIN, "trash": TRASH, "delete": DELETE,
        # legacy long forms
        "retainondrive": RETAIN, "movetodrivetrash": TRASH, "removefromdrive": DELETE,
        # friendly
        "keep": RETAIN, "keepondrive": RETAIN, "move2trash": TRASH, "purge": DELETE,
        # common variants
        "move-to-drive-trash": TRASH, "move-to-trash": TRASH,
    }

    @staticmethod
    def normalize(token: Optional[str]) -> str:
        if not token:
            return PostRestorePolicy.TRASH
        key = re.sub(r'[\s_-]+', '', token.strip().lower())
        return PostRestorePolicy.ALIASES.get(key, PostRestorePolicy.TRASH)

class DriveTrashRecoveryTool:
    """Main recovery tool class."""
    
    def __init__(self, args):
        self.args = args
        # Service/credentials
        self._service = None  # used when single-client mode
        self._creds = None    # saved creds for per-thread builds
        self._thread_local = local()  # holds .service per thread
        self._client_per_thread = True if getattr(args, "client_per_thread", True) else False
        self.logger = self._setup_logging()
        self._authenticated = False
        # rate limiting
        self._tb_tokens: float = 0.0
        self._tb_capacity: float = 0.0
        self._tb_last_refill: Optional[float] = None  # monotonic seconds
        self._tb_initialized: bool = False
        self._rl_lock = Lock()
        self._last_request_ts: Optional[float] = None  # monotonic seconds
        # rl diagnostics
        self._rl_diag_enabled: bool = bool(getattr(args, "rl_diagnostics", False))
        self._rl_calls: int = 0
        self._rl_window_start: Optional[float] = None  # monotonic
        self._rl_diag_last_log: Optional[float] = None
        self.stats = {
            'found': 0,
            'recovered': 0,
            'downloaded': 0,
            'errors': 0,
            'skipped': 0,
            'post_restore_retained': 0,      # Files kept on Drive
            'post_restore_trashed': 0,       # Files moved to trash
            'post_restore_deleted': 0        # Files permanently deleted
        }
        self.stats_lock = Lock()
        self.state = RecoveryState()
        self.items: List[RecoveryItem] = []
        # progress throttles
        self._last_discover_progress_ts: Optional[float] = None
        self._last_exec_progress_ts: Optional[float] = None
        # cache for merged ID validation+discovery
        self._id_prefetch: Dict[str, Dict[str, Any]] = {}
        self._id_prefetch_non_trashed: Dict[str, bool] = {}
        self._id_prefetch_errors: Dict[str, str] = {}

    def _get_service(self):
        """Return the shared Google Drive service instance."""
        if not self._authenticated:
            raise RuntimeError("Service not initialized. Call authenticate() first.")
        if self._client_per_thread:
            svc = getattr(self._thread_local, "service", None)
            if svc is None:
                # Lazily build a client for this thread using saved creds
                svc = build('drive', 'v3', credentials=self._creds)
                self._thread_local.service = svc
            return svc
        return self._service

    # v1.5.2+: token-bucket bursting (opt-in) + legacy fixed-interval pacing
    def _rate_limit(self):
        """
        Global request pacing shared across threads.
        - Fixed-interval pacing (legacy, default) when --burst == 0
        - Token-bucket (opt-in) when --burst > 0
        """
        max_rps = float(getattr(self.args, "max_rps", DEFAULT_MAX_RPS) or 0)
        if max_rps <= 0:
            return  # disabled
        burst = int(getattr(self.args, "burst", DEFAULT_BURST) or 0)

        now = time.monotonic()
        if burst > 0:
            # Token bucket with short critical section; sleep outside lock.
            while True:
                sleep_for = 0.0
                with self._rl_lock:
                    if not self._tb_initialized:
                        self._tb_capacity = float(burst)
                        self._tb_tokens = self._tb_capacity
                        self._tb_last_refill = now
                        self._tb_initialized = True
                    # Refill
                    elapsed = max(0.0, now - (self._tb_last_refill or now))
                    self._tb_last_refill = now
                    self._tb_tokens = min(self._tb_capacity, self._tb_tokens + elapsed * max_rps)
                    if self._tb_tokens >= 1.0:
                        # Fast path: consume and go
                        self._tb_tokens -= 1.0
                        tokens_snapshot = self._tb_tokens
                        cap_snapshot = self._tb_capacity
                        break
                    # Need to wait for the next token; compute sleep without holding lock
                    deficit = 1.0 - self._tb_tokens
                    sleep_for = max(0.0, deficit / max_rps)
                if sleep_for > 0:
                    time.sleep(sleep_for)
                now = time.monotonic()
            self._rl_diag_tick(max_rps, tokens_snapshot, cap_snapshot)
            return
        # Legacy fixed-interval pacing with monotonic time and minimal lock
        min_interval = 1.0 / max_rps
        while True:
            delay = 0.0
            with self._rl_lock:
                last = self._last_request_ts
                if last is None or (now - last) >= min_interval:
                    self._last_request_ts = now
                    break
                delay = max(0.0, min_interval - (now - last))
            if delay > 0.0:
                time.sleep(delay)
            now = time.monotonic()
        self._rl_diag_tick(max_rps, -1.0, -1.0)

    def _rl_diag_tick(self, max_rps: float, tokens_snapshot: float, cap_snapshot: float) -> None:
        """Emit sampled diagnostics for the rate limiter when enabled and DEBUG logging is active."""
        if not self._rl_diag_enabled or not self.logger.isEnabledFor(logging.DEBUG):
            return
        now = time.monotonic()
        self._rl_calls += 1
        if self._rl_window_start is None:
            self._rl_window_start = now
            self._rl_diag_last_log = now
            return
        window = max(1e-6, now - self._rl_window_start)
        # Log every ~5s to avoid spam
        if (self._rl_diag_last_log is None) or (now - self._rl_diag_last_log >= 5.0):
            observed_rps = self._rl_calls / window
            if tokens_snapshot >= 0.0:
                self.logger.debug(
                    "RL diag: observed_rps=%.2f target=%.2f tokens=%.2f cap=%.2f window=%.1fs",
                    observed_rps, max_rps, tokens_snapshot, cap_snapshot, window
                )
            else:
                self.logger.debug(
                    "RL diag: observed_rps=%.2f target=%.2f mode=fixed-interval window=%.1fs",
                    observed_rps, max_rps, window
                )
            self._rl_diag_last_log = now

    def _execute(self, request):
        """Execute a googleapiclient request with rate limiting."""
        self._rate_limit()
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
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.args.log_file),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger(__name__)
    
    def authenticate(self) -> bool:
        """Authenticate with Google Drive API."""
        if self._authenticated:
            return True
        
        try:
            creds = None
            token_file = 'token.json'
            
            if os.path.exists(token_file):
                creds = Credentials.from_authorized_user_file(token_file, SCOPES)
                # Best-effort: mark token hidden on Windows
                self._harden_token_permissions_windows(token_file)
            
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                else:
                    if not os.path.exists('credentials.json'):
                        self.logger.error("credentials.json not found. Please download from Google Cloud Console.")
                        return False
                    
                    flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                    creds = flow.run_local_server(port=0)
                
                with open(token_file, 'w') as token:
                    token.write(creds.to_json())
                # Best-effort: mark token hidden on Windows
                self._harden_token_permissions_windows(token_file)
            
            # Keep creds for per-thread builds; also build a client in current thread
            self._creds = creds
            if self._client_per_thread:
                self._thread_local.service = build('drive', 'v3', credentials=creds)
                test_service = self._thread_local.service
            else:
                self._service = build('drive', 'v3', credentials=creds)
                test_service = self._service

            # Test the connection on the same client
            about = self._execute(test_service.about().get(fields='user'))
            self.logger.info(f"Authenticated as: {about.get('user', {}).get('emailAddress', 'Unknown')}")
            self._authenticated = True
            return True
            
        except Exception as e:
            self.logger.error(f"Authentication failed: {e}")
            return False

    # --- Windows token hardening (best-effort) ---
    def _harden_token_permissions_windows(self, token_path: str) -> None:
        """
        On Windows, POSIX 0600 is not meaningful. We at least hide the file to
        reduce casual discovery. Advanced ACL hardening is not attempted here.
        """
        try:
            if os.name != "nt":
                return
            import ctypes
            FILE_ATTRIBUTE_HIDDEN = 0x02
            attrs = ctypes.windll.kernel32.GetFileAttributesW(str(Path(token_path)))
            if attrs == -1:
                return
            if (attrs & FILE_ATTRIBUTE_HIDDEN) == 0:
                ctypes.windll.kernel32.SetFileAttributesW(str(Path(token_path)), attrs | FILE_ATTRIBUTE_HIDDEN)
                self.logger.info("Marked token.json as hidden (Windows). Note: use NTFS ACLs for stricter control.")
        except Exception as e:
            # Non-fatal; log at debug to avoid noise
            self.logger.debug(f"Could not mark token.json hidden on Windows: {e}")
    
    # -------------------- File-ID validation & merged discovery helpers --------------------
    def _is_valid_file_id_format(self, file_id: str) -> bool:
        """Quick format check: Drive IDs are 25+ chars, [A-Za-z0-9_-]."""
        return re.match(r'[a-zA-Z0-9_-]{25,}$', file_id) is not None

    def _extract_status_from_http_error(self, e):
        if isinstance(e, HttpError):
            return getattr(getattr(e, "resp", None), "status", None)
        return None

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
        transient_ids: Optional[List[str]] = None
    ) -> bool:
        """Print/log consolidated results and return overall success boolean."""
        if buckets["invalid"]:
            joined = ", ".join(buckets["invalid"])
            self.logger.error(f"Invalid file ID format: {joined}")
            print(f"❌ Error: Invalid file ID format: {joined}")
        if buckets["not_found"]:
            joined = ", ".join(buckets["not_found"])
            self.logger.error(f"File IDs not found: {joined}")
            print(f"❌ Error: File IDs not found: {joined}")
        if buckets["no_access"]:
            joined = ", ".join(buckets["no_access"])
            self.logger.error(f"Insufficient permissions for file IDs: {joined}")
            print(f"❌ Error: Insufficient permissions for file IDs: {joined}")
            print("   Tip: Ensure the authenticated account has access, or re-authenticate with an account that does.")
        if transient_errors:
            print(f"⚠️  Validation encountered {transient_errors} transient error(s) (rate-limit/server).")
            if transient_ids:
                joined = ", ".join(transient_ids)
                print(f"   Affected file IDs: {joined}")
                self.logger.warning(f"Transient validation errors for file IDs: {joined}")
            print("   Suggestion: Re-run shortly, lower --concurrency, or re-try just the affected IDs.")

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
        """Handle successful metadata fetch for a file ID."""
        self._id_prefetch[fid] = data
        if data.get("trashed", False):
            buckets["ok"].append(fid)
            self._id_prefetch_non_trashed[fid] = False
        else:
            self._id_prefetch_non_trashed[fid] = True
            skipped_non_trashed[0] += 1

    def _handle_prefetch_error(self, fid, status, e, attempt, buckets, transient_errors, transient_ids, err_count, fields):
        """Handle error during metadata fetch for a file ID."""
        if status == 404:
            buckets["not_found"].append(fid)
            self._id_prefetch_errors[fid] = "HTTP 404"
            return True
        if status == 403:
            buckets["no_access"].append(fid)
            self._id_prefetch_errors[fid] = "HTTP 403"
            return True
        should_retry = False
        if isinstance(e, HttpError):
            should_retry = (status in (429, 500, 502, 503, 504))
        if should_retry and attempt < MAX_RETRIES - 1:
            self._log_fetch_metadata_retry(fid, e, status, attempt)
            return False
        # terminal transient error
        transient_errors[0] += 1
        transient_ids.append(fid)
        self._id_prefetch_errors[fid] = self._format_fetch_metadata_error_with_context(e, status, fid, fields=fields)
        err_count[0] += 1
        return True

    def _should_skip_invalid_id(self, fid, buckets):
        """Return True if the file ID is invalid and should be skipped."""
        if not self._is_valid_file_id_format(fid):
            buckets["invalid"].append(fid)
            return True
        return False

    def _fetch_and_handle_metadata(self, service, fid, fields, buckets, skipped_non_trashed, transient_errors, transient_ids, err_count):
        """Try to fetch metadata for a file ID, handling errors and retries."""
        for attempt in range(MAX_RETRIES):
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
                self._handle_prefetch_success(fid, data, buckets, skipped_non_trashed)
                return
            except Exception as e:
                status = getattr(e, "resp", None)
                status = getattr(status, "status", None) if status else None
                handled = self._handle_prefetch_error(
                    fid, status, e, attempt, buckets, transient_errors, transient_ids, err_count, fields
                )
                if handled:
                    return

    def _prefetch_ids_metadata(self, fids: List[str]) -> Tuple[Dict[str, List[str]], int, List[str], int, int]:
        """
        Single-pass metadata fetch per ID.
        Populates caches for discovery; also returns validation buckets and simple counts
        needed by discovery summary.
        """
        service = self._get_service()
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
                service, fid, fields, buckets, skipped_non_trashed, transient_errors, transient_ids, err_count
            )

        return (
            buckets,
            transient_errors[0],
            transient_ids,
            skipped_non_trashed[0],
            err_count[0],
        )

    def _assert_id_path_parity(self, buckets: Dict[str, List[str]], skipped_non_trashed: int, err_count: int) -> None:
        """
        Lightweight parity checks to catch regressions between the old two-pass flow
        and the new merged path. Logs warnings if counts look inconsistent.
        """
        total_input = len(self.args.file_ids or [])
        classified = sum(len(v) for v in buckets.values())
        seen = classified + skipped_non_trashed + err_count
        if total_input != seen:
            self.logger.warning(
                "Merged ID path parity check mismatch: total=%d, seen=%d (classified=%d, skipped_non_trashed=%d, errors=%d)",
                total_input, seen, classified, skipped_non_trashed, err_count
            )

    def _validate_file_ids(self) -> bool:
        """Validate provided file IDs using single-pass metadata prefetch (merged path)."""
        if not self.args.file_ids:
            return True
        buckets, transient_errors, transient_ids, skipped_non_trashed, err_count = self._prefetch_ids_metadata(self.args.file_ids)
        # Parity assertions are opt-in for debugging only
        if getattr(self.args, "debug_parity", False):
            try:
                self._assert_id_path_parity(buckets, skipped_non_trashed, err_count)
            except Exception as e:
                self.logger.warning(f"Parity checker raised unexpectedly: {e}")
        # Optional cache flush to avoid reusing validation-era caches
        if getattr(self.args, "clear_id_cache", False):
            self._clear_id_caches()
        return self._report_validation_outcome(buckets, transient_errors, transient_ids)

    def _clear_id_caches(self) -> None:
        """Clear validation/discovery caches."""
        try:
            self._id_prefetch.clear()
            self._id_prefetch_non_trashed.clear()
            self._id_prefetch_errors.clear()
        except Exception:
            pass    

    def _build_query(self) -> str:
        """Build the Drive API query string using robust mimeType-based filtering."""
        base_query = "trashed=true"
        
        # Add extension filter using mimeType queries for better reliability
        if self.args.extensions:
            mime_conditions = []
            for ext in self.args.extensions:
                ext_normalized = ext.lower().strip('.')
                if ext_normalized in EXTENSION_MIME_TYPES:
                    mime_type = EXTENSION_MIME_TYPES[ext_normalized]
                    mime_conditions.append(f"mimeType = '{mime_type}'")
            if mime_conditions:
                extensions_query = f"({' or '.join(mime_conditions)})"
                base_query += f" and {extensions_query}"
        
        # Note: trashedTime filtering removed - not supported by Drive API v3
        if self.args.after_date:
            self.logger.warning("Time-based filtering (--after-date) will be applied client-side due to Drive API limitations")
        
        # We do not add file IDs to q
        return base_query
    
    def _process_file_data(self, file_data: Dict[str, Any]) -> Optional[RecoveryItem]:
        """Process a single file data entry and create RecoveryItem if valid."""
        # Apply client-side extension filtering for additional precision
        if self.args.extensions and not self._matches_extension_filter(file_data.get('name', '')):
            return None
        
        # Apply client-side time filtering (since server-side trashedTime is not supported)
        if not self._matches_time_filter(file_data):
            return None
        
        item = RecoveryItem(
            id=file_data['id'],
            name=file_data.get('name', 'Unknown'),
            size=int(file_data.get('size', 0)),
            mime_type=file_data.get('mimeType', ''),
            created_time=file_data.get('createdTime', ''),
            will_download=self.args.mode == 'recover_and_download',
            post_restore_action=PostRestorePolicy.normalize(self.args.post_restore_policy)
        )
        
        if self.args.mode == 'recover_and_download':
            item.target_path = self._generate_target_path(item)
        
        return item
    
    def _fetch_files_page(self, query: str, page_token: Optional[str]) -> Tuple[List[Dict], Optional[str]]:
        """Fetch a single page of files from the API."""
        service = self._get_service()
        response = self._execute(service.files().list(
            q=query,
            spaces='drive',
            fields='nextPageToken, files(id, name, mimeType, size, createdTime, modifiedTime)',
            pageSize=PAGE_SIZE,
            pageToken=page_token
        ))
        files = response.get('files', [])
        next_page_token = response.get('nextPageToken')
        return files, next_page_token

    # --- Discovery helpers ---
    def _append_item_if_valid(self, items: List[RecoveryItem], file_data: Dict[str, Any]) -> None:
        item = self._process_file_data(file_data)
        if item:
            items.append(item)

    # --- ID discovery helpers ---
    def _id_discovery_fields(self) -> str:
        base_fields = ['id', 'name', 'mimeType', 'trashed', 'createdTime']
        if self.args.mode == 'recover_and_download':
            base_fields.append('size')
        if bool(self.args.after_date):
            base_fields.append('modifiedTime')
        return ', '.join(base_fields)

    def _log_fetch_metadata_retry(self, fid: str, e: Exception, status: Optional[int], attempt: int):
        """Log retry for fetch metadata with exponential backoff and jitter."""
        delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)
        if status is not None:
            self.logger.warning(f"Rate/Server error for {fid} (HTTP {status}). Retrying in {delay:.2f}s...")
        else:
            self.logger.warning(f"Error fetching file {fid} ({e}). Retrying in {delay:.2f}s...")
        time.sleep(delay)

    def _fetch_file_metadata(self, service, fid: str, fields: str) -> Tuple[Optional[Dict[str, Any]], bool, Optional[str]]:
        """Fetch a single file's metadata with retries.

        Returns:
            (file_data, was_non_trashed, error_message)
        """
        for attempt in range(MAX_RETRIES):
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
                if data.get('trashed', False):
                    return data, False, None
                return None, True, None
            except Exception as e:
                status = getattr(getattr(e, "resp", None), "status", None)
                retryable = isinstance(e, HttpError) and status in (429, 500, 502, 503, 504)
                if retryable and attempt < MAX_RETRIES - 1:
                    self._log_fetch_metadata_retry(fid, e, status, attempt)
                    continue
                return None, False, self._format_fetch_metadata_error_with_context(e, status, fid, fields=fields)
        return None, False, "Unknown error"

    def _handle_discover_id_result(self, items, data, non_trashed, err, fid, skipped_non_trashed_ref, errors_ref):
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
        due_time = (self._last_discover_progress_ts is None) or ((now - self._last_discover_progress_ts) >= 10)
        if due_count or due_time or idx == total:
            elapsed = max(0.001, now - start_time)
            rate = idx / elapsed
            remaining = max(0, total - idx)
            eta = (remaining / rate) if rate > 0 else 0
            print(f"Processing IDs: {idx}/{total} "
                  f"(found: {len(items)}, skipped: {skipped}, errors: {errors}) "
                  f"ETA: {eta:.0f}s")
            self._last_discover_progress_ts = now

    def _print_discover_id_summary(self, items, skipped_non_trashed, errors):
        if skipped_non_trashed:
            print(f"ℹ️  Skipped {skipped_non_trashed} non-trashed file ID(s).")
        if errors:
            print(f"ℹ️  Encountered {errors} error(s) while fetching file ID metadata. See log for details.")
        if not items:
            print("❎ No actionable trashed files were found from the provided --file-ids.")
            print("   All provided IDs may be invalid, not found, non-trashed, or inaccessible.")
            print("   Tip: Re-check IDs from their Drive URLs and ensure they are currently in Trash.")

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
                self._maybe_print_discover_progress(idx, total, items, skipped_non_trashed[0], errors[0], start_time)
                continue
            if self._id_prefetch_non_trashed.get(fid, False):
                skipped_non_trashed[0] += 1
                self._maybe_print_discover_progress(idx, total, items, skipped_non_trashed[0], errors[0], start_time)
                continue
            data = self._id_prefetch.get(fid)
            if data:
                self._append_item_if_valid(items, data)
            self._maybe_print_discover_progress(idx, total, items, skipped_non_trashed[0], errors[0], start_time)

        self._print_discover_id_summary(items, skipped_non_trashed[0], errors[0])
        return items

    def _discover_via_query(self, query: str) -> List[RecoveryItem]:
        items: List[RecoveryItem] = []
        page_token: Optional[str] = None
        page_count = 0
        try:
            while True:
                page_count += 1
                self.logger.debug(f"Fetching page {page_count}")
                files, page_token = self._fetch_files_page(query, page_token)
                for file_data in files:
                    self._append_item_if_valid(items, file_data)
                    # honor --limit during discovery to stop early
                    if self.args.limit and self.args.limit > 0 and len(items) >= self.args.limit:
                        break
                if self.args.verbose >= 1:
                    print(f"Found {len(files)} files in page {page_count} (total: {len(items)})")
                if (self.args.limit and self.args.limit > 0 and len(items) >= self.args.limit) or (not page_token):
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
        self.stats['found'] = len(items)
        print(f"📊 Total files discovered: {len(items)}")
        return items
    
    def _matches_extension_filter(self, filename: str) -> bool:
        if not self.args.extensions or not filename:
            return True
        filename_lower = filename.lower()
        for ext in self.args.extensions:
            if filename_lower.endswith(f'.{ext.lower().strip(".")}'):
                return True
        return False
    
    def _matches_time_filter(self, item_data: Dict[str, Any]) -> bool:
        if not self.args.after_date:
            return True
        try:
            modified_dt = date_parser.parse(item_data.get('modifiedTime', ''))
            after_dt = date_parser.parse(self.args.after_date)
            if modified_dt.tzinfo is None:
                modified_dt = modified_dt.replace(tzinfo=timezone.utc)
            if after_dt.tzinfo is None:
                after_dt = after_dt.replace(tzinfo=timezone.utc)
            return modified_dt > after_dt
        except Exception as e:
            self.logger.warning(f"Error applying time filter: {e}")
            return True  # Include item if filter fails
    
    def _generate_target_path(self, item: RecoveryItem) -> str:
        if not self.args.download_dir:
            return ""
        safe_name = "".join(c for c in item.name if c.isalnum() or c in (' ', '-', '_', '.')).rstrip()
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
    
    def _get_file_info(self, file_id: str, fields: str) -> Dict[str, Any]:
        api_ctx = f"files.get(fileId={file_id}, fields={fields})"
        try:
            service = self._get_service()
            return self._execute(service.files().get(fileId=file_id, fields=fields))
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            payload = getattr(e, "content", b"")
            detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
            self.logger.error(f"{api_ctx} failed: HTTP {status}: {detail}")
            return {'error': f"HTTP {status}: {detail}"}
        except (OSError, IOError) as e:
            self.logger.error(f"{api_ctx} I/O error: {e}")
            return {'error': f"I/O error: {e}"}
        except Exception as e:
            self.logger.error(f"{api_ctx} unexpected error: {e}")
            return {'error': f"Unexpected error: {e}"}
    
    def _check_untrash_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {'status': 'unknown', 'error': None}
        file_info = self._get_file_info(file_id, 'id,trashed,capabilities')
        if 'error' in file_info:
            result['status'] = 'fail'
            result['error'] = file_info['error']
            return result
        if not file_info.get('trashed', False):
            result['status'] = 'skip'
            result['error'] = "Test file is not trashed - cannot validate untrash permission"
            return result
        capabilities = file_info.get('capabilities', {})
        if 'canUntrash' in capabilities:
            result['status'] = 'pass' if capabilities['canUntrash'] else 'fail'
            if not capabilities['canUntrash']:
                result['error'] = "File capabilities indicate untrash not allowed"
        else:
            result['status'] = 'pass'  # Fallback
        return result
    
    def _check_download_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {'status': 'unknown', 'error': None}
        file_info = self._get_file_info(file_id, 'id,size,mimeType,capabilities')
        if 'error' in file_info:
            result['status'] = 'fail'
            result['error'] = file_info['error']
            return result
        if 'size' not in file_info:
            result['status'] = 'fail'
            result['error'] = "File is not downloadable (Google Docs format or no size)"
            return result
        capabilities = file_info.get('capabilities', {})
        if 'canDownload' in capabilities:
            result['status'] = 'pass' if capabilities['canDownload'] else 'fail'
            if not capabilities['canDownload']:
                result['error'] = "File capabilities indicate download not allowed"
        else:
            result['status'] = 'pass'  # Fallback
        return result
    
    def _check_trash_delete_privileges(self, file_id: str, untrash_status: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        trash_result = {'status': untrash_status, 'error': INFERRED_MODIFY_ERROR if untrash_status == 'fail' else None}
        delete_result = {'status': untrash_status, 'error': INFERRED_MODIFY_ERROR if untrash_status == 'fail' else None}
        file_info = self._get_file_info(file_id, 'id,capabilities')
        if 'error' in file_info:
            trash_result['status'] = 'fail'
            trash_result['error'] = file_info['error']
            delete_result['status'] = 'fail'
            delete_result['error'] = file_info['error']
            return trash_result, delete_result
        capabilities = file_info.get('capabilities', {})
        if 'canTrash' in capabilities:
            trash_result['status'] = 'pass' if capabilities['canTrash'] else 'fail'
            trash_result['error'] = None if capabilities['canTrash'] else "File capabilities indicate trash not allowed"
        if 'canDelete' in capabilities:
            delete_result['status'] = 'pass' if capabilities['canDelete'] else 'fail'
            delete_result['error'] = None if capabilities['canDelete'] else "File capabilities indicate delete not allowed"
        elif trash_result['status'] == 'pass':
            delete_result['status'] = 'pass'
            delete_result['error'] = None
        return trash_result, delete_result
    
    def _test_operation_privileges(self, test_items: List[RecoveryItem]) -> Dict[str, Any]:
        privileges = {
            'untrash': {'status': 'unknown', 'error': None},
            'download': {'status': 'unknown', 'error': None},
            'trash': {'status': 'unknown', 'error': None},
            'delete': {'status': 'unknown', 'error': None}
        }
        if not test_items:
            return privileges
        test_item = test_items[0]
        privileges['untrash'] = self._check_untrash_privilege(test_item.id)
        privileges['download'] = self._check_download_privilege(test_item.id)
        privileges['trash'], privileges['delete'] = self._check_trash_delete_privileges(test_item.id, privileges['untrash']['status'])
        return privileges
    
    def _check_privileges(self) -> Dict[str, Any]:
        checks = {
            'drive_access': False,
            'drive_error': None,
            'operation_privileges': {},
            'local_writable': False,
            'local_error': None,
            'disk_space': 0,
            'estimated_needed': 0
        }
        try:
            service = self._get_service()
            service.files().list(pageSize=1).execute()
            checks['drive_access'] = True
            sample_items = self.items[:3] if self.items else []
            checks['operation_privileges'] = self._test_operation_privileges(sample_items)
        except Exception as e:
            checks['drive_error'] = str(e)
        if self.args.download_dir:
            try:
                download_path = Path(self.args.download_dir)
                download_path.mkdir(parents=True, exist_ok=True)
                test_file = download_path / '.write_test'
                test_file.write_text('test')
                test_file.unlink()
                checks['local_writable'] = True
                if hasattr(shutil, 'disk_usage'):
                    _, _, free_bytes = shutil.disk_usage(download_path)
                    checks['disk_space'] = free_bytes
                    total_size = sum(item.size for item in self.items if item.will_download)
                    checks['estimated_needed'] = total_size
            except Exception as e:
                checks['local_error'] = str(e)
        return checks
    
    def _print_drive_access_status(self, checks: Dict[str, Any]):
        drive_status = "✓ PASS" if checks['drive_access'] else "❌ FAIL"
        print(f"Drive API Access: {drive_status}")
        if checks['drive_error']:
            print(f"  Error: {checks['drive_error']}")
    
    def _print_operation_privileges(self, checks: Dict[str, Any]):
        if not checks.get('operation_privileges'):
            return
        print("\nOperation Privileges:")
        for operation, result in checks['operation_privileges'].items():
            self._print_single_operation_privilege(operation, result)
    
    def _print_single_operation_privilege(self, operation: str, result: Dict[str, Any]):
        status_symbol = {'pass': '✓', 'fail': '❌'}.get(result['status'], '?')
        print(f"  {operation.title()}: {status_symbol} {result['status'].upper()}")
        if result['error']:
            print(f"    Error: {result['error']}")
    
    def _print_local_directory_status(self, checks: Dict[str, Any]):
        if not self.args.download_dir:
            return
        local_status = "✓ PASS" if checks['local_writable'] else "❌ FAIL"
        print(f"Local Directory Writable: {local_status}")
        if checks['local_error']:
            print(f"  Error: {checks['local_error']}")
        self._print_disk_space_info(checks)
    
    def _print_privilege_checks(self, checks: Dict[str, Any]):
        print("\n📋 PRIVILEGE AND ENVIRONMENT CHECKS")
        print("-" * 50)
        self._print_drive_access_status(checks)
        self._print_operation_privileges(checks)
        self._print_local_directory_status(checks)
    
    def _print_disk_space_info(self, checks: Dict[str, Any]):
        if checks['disk_space'] > 0:
            free_gb = checks['disk_space'] / (1024**3)
            needed_gb = checks['estimated_needed'] / (1024**3)
            space_status = "✓ SUFFICIENT" if checks['disk_space'] > checks['estimated_needed'] else "⚠️  INSUFFICIENT"
            print(f"Disk Space: {space_status}")
            print(f"  Available: {free_gb:.2f} GB")
            print(f"  Estimated needed: {needed_gb:.2f} GB")
    
    def _print_scope_summary(self):
        print("\n📊 SCOPE SUMMARY")
        print("-" * 50)
        print(f"Total trashed files found: {len(self.items)}")
        if self.args.extensions:
            print(f"Extension filter: {', '.join(self.args.extensions)}")
        recover_count = sum(1 for item in self.items if item.will_recover)
        download_count = sum(1 for item in self.items if item.will_download)
        total_size_mb = sum(item.size for item in self.items) / (1024**2)
        print(f"Files to recover: {recover_count}")
        print(f"Files to download: {download_count}")
        print(f"Total size: {total_size_mb:.2f} MB")
        print(f"Post-restore policy: {PostRestorePolicy.normalize(self.args.post_restore_policy)}")
    
    def _print_item_details(self, item: RecoveryItem, index: int):
        print(f"{index:4d}. {item.name[:50]}")
        print(f"      ID: {item.id}")
        print(f"      Size: {item.size / 1024:.1f} KB")
        print(f"      Recover: {'Yes' if item.will_recover else 'No'}")
        if item.will_download:
            print(f"      Download: Yes → {item.target_path}")
        else:
            print("      Download: No")
        print(f"      Post-restore: {item.post_restore_action}")
        print()
    
    def _show_detailed_plan(self) -> bool:
        print("\n📋 DETAILED EXECUTION PLAN")
        print("-" * 50)
        page_size = 20
        total_pages = (len(self.items) + page_size - 1) // page_size
        for page in range(total_pages):
            start_idx = page * page_size
            end_idx = min(start_idx + page_size, len(self.items))
            print(f"\nPage {page + 1}/{total_pages} (items {start_idx + 1}-{end_idx}):")
            print("-" * 80)
            for i, item in enumerate(self.items[start_idx:end_idx], start_idx + 1):
                self._print_item_details(item, i)
            if page < total_pages - 1:
                response = input("Press Enter for next page, 'q' to stop viewing, or 's' to skip to summary: ").strip().lower()
                if response == 'q':
                    return False
                elif response == 's':
                    break
        return True
    
    def _generate_execution_command(self):
        print("\n🚀 EXECUTION COMMAND")
        print("-" * 50)
        cmd_parts = [sys.argv[0]]
        self._add_mode_arguments(cmd_parts)
        self._add_filter_arguments(cmd_parts)
        self._add_config_arguments(cmd_parts)
        self._add_file_arguments(cmd_parts)
        self._add_verbosity_arguments(cmd_parts)
        print("To execute this plan, run:")
        print(f"  {' '.join(cmd_parts)}")
    
    def _add_file_arguments(self, cmd_parts: List[str]):
        if self.args.after_date:
            cmd_parts.extend(['--after-date', self.args.after_date])
        if self.args.file_ids:
            cmd_parts.extend(['--file-ids'] + self.args.file_ids)
        if self.args.log_file != DEFAULT_LOG_FILE:
            cmd_parts.extend(['--log-file', self.args.log_file])
        if self.args.state_file != DEFAULT_STATE_FILE:
            cmd_parts.extend(['--state-file', self.args.state_file])
    
    def _add_verbosity_arguments(self, cmd_parts: List[str]):
        if self.args.verbose > 0:
            cmd_parts.append('-' + 'v' * self.args.verbose)
    
    def _add_mode_arguments(self, cmd_parts: List[str]):
        if self.args.mode == 'recover_and_download':
            cmd_parts.append('recover-and-download')
            cmd_parts.extend(['--download-dir', str(self.args.download_dir)])
        elif self.args.mode == 'recover_only':
            cmd_parts.append('recover-only')
        else:
            cmd_parts.append('dry-run')
    
    def _add_filter_arguments(self, cmd_parts: List[str]):
        if self.args.extensions:
            cmd_parts.extend(['--extensions'] + self.args.extensions)
    
    def _add_config_arguments(self, cmd_parts: List[str]):
        normalized = PostRestorePolicy.normalize(self.args.post_restore_policy)
        if normalized != PostRestorePolicy.TRASH:
            cmd_parts.extend(['--post-restore-policy', normalized])
        cmd_parts.extend(['--concurrency', str(self.args.concurrency)])
        if self.args.max_rps != DEFAULT_MAX_RPS:
            cmd_parts.extend(['--max-rps', str(self.args.max_rps)])
        if self.args.burst != DEFAULT_BURST:
            cmd_parts.extend(['--burst', str(self.args.burst)])
        if self.args.limit and self.args.limit > 0:
            cmd_parts.extend(['--limit', str(self.args.limit)])
        if self.args.yes:
            cmd_parts.append('--yes')
    
    def dry_run(self) -> bool:
        print("\n" + "="*80)
        print("🔍 DRY RUN MODE - No changes will be made")
        print("="*80)
        self.items = self.discover_trashed_files()
        if not self.items:
            print("No files found matching criteria.")
            return True
        checks = self._check_privileges()
        self._print_privilege_checks(checks)
        self._print_scope_summary()
        if not self._show_detailed_plan():
            return False
        self._generate_execution_command()
        return True
    
    def _load_state(self) -> bool:
        if not os.path.exists(self.args.state_file):
            return False
        try:
            with open(self.args.state_file, 'r') as f:
                data = json.load(f)
                self.state = RecoveryState(**data)
            print(f"📂 Loaded previous state: {len(self.state.processed_items)} items already processed")
            return True
        except HttpError as e:
            self.logger.error(
                f"API error while loading state file '{self.args.state_file}' "
                f"(HTTP {getattr(e.resp, 'status', 'unknown')}): {e}",
                exc_info=True
            )
            with self.stats_lock:
                self.stats['errors'] += 1
        except Exception:
            self.logger.exception(
                f"Unexpected error while loading state file '{self.args.state_file}'"
            )
            with self.stats_lock:
                self.stats['errors'] += 1
 
    # ---------- State file locking & atomic writes ----------
    def _acquire_state_lock(self) -> bool:
        """
        Cross-platform advisory lock on <state>.lock.
        Returns True on success; False if already locked by another process.
        """
        self._state_lock_path = f"{self.args.state_file}.lock"
        self._state_lock_fh = open(self._state_lock_path, 'a+')
        try:
            if os.name == "nt":
                import msvcrt
                try:
                    msvcrt.locking(self._state_lock_fh.fileno(), msvcrt.LK_NBLCK, 1)
                except OSError:
                    return False
            else:
                import fcntl
                try:
                    fcntl.flock(self._state_lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                except OSError:
                    return False
            # write owner pid for diagnostics
            try:
                self._state_lock_fh.seek(0)
                self._state_lock_fh.truncate(0)
                self._state_lock_fh.write(str(os.getpid()))
                self._state_lock_fh.flush()
            except Exception:
                pass
            return True
        except Exception as e:
            self.logger.warning(f"State lock warning: {e}")
            return True  # best-effort
 
    def _release_state_lock(self) -> None:
        try:
            if not hasattr(self, "_state_lock_fh"):
                return
            if os.name == "nt":
                import msvcrt
                try:
                    msvcrt.locking(self._state_lock_fh.fileno(), msvcrt.LK_UNLCK, 1)
                except Exception:
                    pass
            else:
                import fcntl
                try:
                    fcntl.flock(self._state_lock_fh.fileno(), fcntl.LOCK_UN)
                except Exception:
                    pass
            self._state_lock_fh.close()
        except Exception:
            pass
    
    def _save_state(self):
        try:
             tmp_path = f"{self.args.state_file}.tmp"
             with open(tmp_path, 'w') as f:
                 json.dump(asdict(self.state), f, indent=2)
                 f.flush()
                 os.fsync(f.fileno())
             os.replace(tmp_path, self.args.state_file)
        except Exception as e:
            self.logger.error(f"Failed to save state: {e}")
    
    def _is_processed(self, item_id: str) -> bool:
        return item_id in self.state.processed_items
    
    def _mark_processed(self, item_id: str):
        if item_id not in self.state.processed_items:
            self.state.processed_items.append(item_id)
            self.state.last_checkpoint = datetime.now(timezone.utc).isoformat()
    
    def _recover_file(self, item: RecoveryItem) -> bool:
        if self._is_processed(item.id):
            with self.stats_lock:
                self.stats['skipped'] += 1
            return True
        service = self._get_service()
        api_ctx = f"files.update(fileId={item.id}, trashed=False)"
        for attempt in range(MAX_RETRIES):
            try:
                self._execute(service.files().update(
                    fileId=item.id,
                    body={'trashed': False}
                ))
                item.status = 'recovered'
                with self.stats_lock:
                    self.stats['recovered'] += 1
                self.logger.info(f"Recovered: {item.name}")
                return True
            except HttpError as e:
                status = getattr(e.resp, "status", None)
                payload = getattr(e, "content", b"")
                detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
                if status in (403, 404):
                    item.status = 'failed'
                    item.error_message = f"{api_ctx} failed: HTTP {status}: {detail}"
                    with self.stats_lock:
                        self.stats['errors'] += 1
                    self.logger.error(f"Failed to recover {item.name}: {item.error_message}")
                    return False
                else:
                    self.logger.warning(f"Retrying recovery of {item.name} (attempt {attempt + 1})")
                    delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)
                    time.sleep(delay)
            except Exception as e:
                self.logger.warning(f"Retrying recovery of {item.name} (attempt {attempt + 1}): {e}")
                delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)
                time.sleep(delay)
        item.status = 'failed'
        item.error_message = "Max retries exceeded"
        with self.stats_lock:
            self.stats['errors'] += 1
        return False

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
            self._execute(service.files().update(fileId=item.id, body={'trashed': True}))
        elif action == "deleted":
            self._execute(service.files().delete(fileId=item.id))
        # "retain" does nothing

    def _log_post_restore_success(self, item: RecoveryItem, action: str):
        if action == "retain":
            with self.stats_lock:
                self.stats['post_restore_retained'] += 1
        elif action == "trashed":
            self.logger.info(f"Moved to trash: {item.name}")
            with self.stats_lock:
                self.stats['post_restore_trashed'] += 1
        elif action == "deleted":
            self.logger.info(f"Permanently deleted: {item.name}")
            with self.stats_lock:
                self.stats['post_restore_deleted'] += 1

    def _is_terminal_post_restore_error(self, e):
        status = getattr(e.resp, "status", None)
        return status in (403, 404)

    def _handle_post_restore_retry(self, item, e, attempt):
        status = getattr(e.resp, "status", None)
        self._log_fetch_metadata_retry(item.id, e, status, attempt)

    def _apply_post_restore_policy(self, item: RecoveryItem) -> bool:
        service = self._get_service()
        action, api_ctx = self._get_post_restore_action_and_ctx(item)
        for attempt in range(MAX_RETRIES):
            try:
                if action != "retain":
                    self._do_post_restore_action(service, item, action)
                self._log_post_restore_success(item, action)
                return True
            except HttpError as e:
                if self._is_terminal_post_restore_error(e):
                    detail = getattr(e, 'content', b'')
                    detail = detail.decode(errors='ignore') if hasattr(detail, 'decode') else str(e)
                    self.logger.error(
                        f"Post-restore action failed for {item.name} via {api_ctx or 'N/A'}: "
                        f"HTTP {getattr(e.resp, 'status', None)}: {detail}"
                    )
                    return False
                if attempt < MAX_RETRIES - 1:
                    self._handle_post_restore_retry(item, e, attempt)
                    continue
                detail = getattr(e, 'content', b'')
                detail = detail.decode(errors='ignore') if hasattr(detail, 'decode') else str(e)
                self.logger.error(
                    f"Post-restore action failed after retries for {item.name} via {api_ctx or 'N/A'}: {detail}"
                )
                return False
            except Exception as e:
                self.logger.warning(
                    f"Error during post-restore for {item.name} via {api_ctx or 'N/A'} "
                    f"(attempt {attempt + 1}): {e}"
                )
                delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)
                time.sleep(delay)
        self.logger.error(f"Post-restore action failed after retries for {item.name} via {api_ctx or 'N/A'}")
        return False
    
    def _process_item(self, item: RecoveryItem) -> bool:
        if self._is_processed(item.id):
            return True
        success = True
        if item.will_recover and not self._recover_file(item):
            success = False
        if success and item.will_download and not self._download_file(item):
            success = False
        if success and item.will_download and item.status == 'downloaded':
            self._apply_post_restore_policy(item)
        self._mark_processed(item.id)
        return success
    
    def _prepare_recovery(self) -> Tuple[bool, bool]:
        if not self.authenticate():
            return False, False
        self._load_state()
        if not self.items:
            self.items = self.discover_trashed_files()
        has_files = len(self.items) > 0
        if not has_files:
            print("No files found to process.")
        return True, has_files
    
    def _get_safety_confirmation(self) -> bool:
        if self.args.yes:
            return True
        actions = self._build_action_list()
        action_text = ", ".join(actions)
        response = input(f"\nProceed to {action_text} for {len(self.items)} files? (y/N): ")
        if response.lower() != 'y':
            print("Operation cancelled.")
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
            self.state.total_found = len(self.items)
    
    def _process_all_items(self) -> bool:
        print(f"\n🚀 Processing {len(self.items)} files with {self.args.concurrency} workers...")
        start_time = time.time()
        try:
            self._run_parallel_processing(start_time)
        except KeyboardInterrupt:
            print("\n⚠️  Operation interrupted. State saved for resume.")
            self._save_state()
            return False
        self._save_state()
        self._print_summary(time.time() - start_time)
        return True
    
    def _run_parallel_processing(self, start_time: float):
        processed_count = 0
        with ThreadPoolExecutor(max_workers=self.args.concurrency) as executor:
            future_to_item = {executor.submit(self._process_item, item): item for item in self.items}
            for future in as_completed(future_to_item):
                item = future_to_item[future]
                processed_count += 1
                self._handle_item_result(future, item, processed_count, start_time)
    
    def _handle_item_result(self, future, item: RecoveryItem, processed_count: int, start_time: float):
        try:
            future.result()
            if self.args.verbose >= 1:
                interval = self._progress_interval(len(self.items))
                now = time.time()
                due_count = (processed_count % interval) == 0
                due_time = (self._last_exec_progress_ts is None) or ((now - self._last_exec_progress_ts) >= 10)
                if due_count or due_time:
                    self._print_progress_update(processed_count, start_time)
                    self._last_exec_progress_ts = now
            if processed_count % 100 == 0:
                self._save_state()
        except Exception as e:
            self.logger.error(f"Unexpected error processing {item.name}: {e}")
            with self.stats_lock:
                self.stats['errors'] += 1
    
    def _print_progress_update(self, processed_count: int, start_time: float):
        elapsed = time.time() - start_time
        rate = processed_count / elapsed if elapsed > 0 else 0
        eta = (len(self.items) - processed_count) / rate if rate > 0 else 0
        pct = (processed_count/len(self.items)*100) if self.items else 100.0
        print(f"📈 Progress: {processed_count}/{len(self.items)} "
              f"({pct:.1f}%) "
              f"Rate: {rate:.1f}/sec ETA: {eta:.0f}s")

    def _progress_interval(self, total: int) -> int:
        if total <= 0:
            return 5
        return max(5, min(500, max(1, round(total * 0.02))))

    def execute_recovery(self) -> bool:
        success, has_files = self._prepare_recovery()
        if not success:
            return False
        if not has_files:
            return True
        if not self._get_safety_confirmation():
            return False
        self._initialize_recovery_state()
        try:
            return self._process_all_items()
        finally:
            # Always release state lock
            self._release_state_lock()
    
    def _print_summary(self, elapsed_time: float):
        print("\n" + "="*80)
        print("📊 EXECUTION SUMMARY")
        print("="*80)
        print(f"Total files found: {self.stats['found']}")
        print(f"Files recovered: {self.stats['recovered']}")
        print(f"Files downloaded: {self.stats['downloaded']}")
        total_post_restore = (self.stats['post_restore_retained'] + 
                             self.stats['post_restore_trashed'] + 
                             self.stats['post_restore_deleted'])
        if total_post_restore > 0:
            print(f"Post-restore actions applied: {total_post_restore}")
            print(f"  • Retained on Drive: {self.stats['post_restore_retained']}")
            print(f"  • Moved to trash: {self.stats['post_restore_trashed']}")
            print(f"  • Permanently deleted: {self.stats['post_restore_deleted']}")
        print(f"Files skipped (already processed): {self.stats['skipped']}")
        print(f"Errors encountered: {self.stats['errors']}")
        print(f"Execution time: {elapsed_time:.1f} seconds")
        if self.stats['errors'] > 0:
            print(f"\n⚠️  Check log file for error details: {self.args.log_file}")
        if self.state.processed_items:
            print(f"\n📂 State file: {self.args.state_file}")
            print("   Use same command to resume if interrupted")
        success_rate = (self.stats['recovered'] / self.stats['found'] * 100) if self.stats['found'] > 0 else 0
        print(f"\n✅ Success rate: {success_rate:.1f}%")

    # --- Streaming download implementation (rate-limit aware) ---
    def _download_file(self, item: RecoveryItem) -> bool:
        success = False
        try:
            service = self._get_service()
            request = service.files().get_media(fileId=item.id)
            target = Path(item.target_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            partial = Path(str(target) + ".partial")
            with open(partial, "wb") as fh:
                try:
                    downloader = MediaIoBaseDownload(fh, request, chunksize=DOWNLOAD_CHUNK_BYTES)
                    done = False
                    last_print = 0.0
                    while not done:
                        self._rate_limit()
                        status, done = downloader.next_chunk()
                        now = time.time()
                        if status and (self.args.verbose > 0) and (now - last_print > 1.0 or done):
                            pct = int(status.progress() * 100)
                            print(f"  ↳ downloading {item.name[:40]} … {pct}%")
                            last_print = now
                    item.status = 'downloaded'
                    with self.stats_lock:
                        self.stats['downloaded'] += 1
                    # Atomic move into place
                    try:
                        if target.exists():
                            target.unlink()
                    except Exception:
                        pass
                    partial.replace(target)
                    success = True
                except Exception as e:
                    item.status = 'failed'
                    item.error_message = f"Download error: {e}"
                    with self.stats_lock:
                        self.stats['errors'] += 1
                    self.logger.error(item.error_message)
                    success = False
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            detail = getattr(e, 'content', b'')
            detail = detail.decode(errors='ignore') if hasattr(detail, 'decode') else str(e)
            item.status = 'failed'
            item.error_message = f"files.get_media(fileId={item.id}) failed: HTTP {status}: {detail}"
            with self.stats_lock:
                self.stats['errors'] += 1
            self.logger.error(item.error_message)
            success = False
        except Exception as e:
            item.status = 'failed'
            item.error_message = f"Download error: {e}"
            with self.stats_lock:
                self.stats['errors'] += 1
            self.logger.error(item.error_message)
            success = False
        finally:
            # Clean up partial on failure
            try:
                partial = Path(str(Path(item.target_path)) + ".partial")
                if not success and partial.exists():
                    partial.unlink()
            except Exception:
                pass
        return success

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=f"Google Drive Trash Recovery Tool v{__version__}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Dry run to see what would be recovered
  %(prog)s dry-run --extensions jpg png

  # Recover only (no download)
  %(prog)s recover-only --extensions pdf docx

  # Recover and download with custom policy
  %(prog)s recover-and-download --download-dir ./recovered --post-restore-policy RetainOnDrive

  # Resume interrupted operation
  %(prog)s recover-and-download --download-dir ./recovered

Post-restore policies:
  trash  (default) / MoveToDriveTrash / Move-To-Drive-Trash / MoveToTrash
  retain / RetainOnDrive / Keep / KeepOnDrive
  delete / RemoveFromDrive / Purge / Delete

Troubleshooting:
  * Quota Exhausted:
    Error: "Quota exceeded for quota metric 'Requests' and limit 'Requests per day'"
    Solution: Wait until the next day for quota reset or request a quota increase in Google Cloud Console.

  * Permission Errors:
    Error: "HTTP 403: Forbidden - The user does not have sufficient permissions"
    Solution: Ensure the authenticated account has edit access to the files. For shared drives, verify team drive permissions.

  * Authentication Failures:
    Error: "credentials.json not found" or "Authentication failed"
    Solution: Download credentials.json from Google Cloud Console and place it in the script directory.

  * Invalid File IDs:
    Error: "Invalid file ID format" or "File IDs not found"
    Solution: Ensure file IDs are valid (25+ alphanumeric characters, hyphens, or underscores).

  * Missing Dependency (python-dateutil):
    Error: "Missing optional dependency 'python-dateutil' required for --after-date parsing."
    Solution: pip install python-dateutil

Quotas & Monitoring:
  Drive API enforces per-minute and daily quotas. If you see HTTP 429 responses,
  reduce --concurrency and retry later. Monitor usage in Google Cloud Console.

Shared Drives:
  Access is governed by membership/roles on the shared drive and by item-level permissions.

Concurrency Tuning:
  As a starting point, use min(8, CPU*2). If you observe 429/5xx bursts, back off concurrency.

Rate Limiting:
  --max-rps caps average request rate. Enable burst absorption with --burst N (token bucket).
  Use --rl-diagnostics and -vv to log sampled limiter stats (tokens, capacity, observed RPS).
  Set --max-rps 0 to disable throttling entirely. Execution progress lines respect -v;
  summaries always print.
"""
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Operation mode')
    dry_run_parser = subparsers.add_parser('dry-run', help='Show execution plan without making changes')
    recover_parser = subparsers.add_parser('recover-only', help='Recover files from trash only')
    download_parser = subparsers.add_parser('recover-and-download', help='Recover and download files')
    download_parser.add_argument('--download-dir', required=True, help='Local directory for downloads')
    
    for subparser in [dry_run_parser, recover_parser, download_parser]:
        subparser.add_argument('--version', action='version', version=f'%(prog)s {__version__}')
        subparser.add_argument('--extensions', nargs='+', help='File extensions to filter (e.g., jpg png pdf)')
        subparser.add_argument('--after-date', help='Only process files trashed after this date (ISO format)')
        subparser.add_argument('--file-ids', nargs='+', help='Process only specific file IDs')
        subparser.add_argument('--post-restore-policy', default=PostRestorePolicy.TRASH,
                               help='Post-download handling in Drive (aliases accepted): retain|trash|delete')
        subparser.add_argument('--concurrency', type=int, default=DEFAULT_WORKERS,
                               help='Number of concurrent operations')
        subparser.add_argument('--max-rps', type=float, default=DEFAULT_MAX_RPS,
                               help='Max Drive API requests per second (0 = disable throttling)')
        subparser.add_argument('--burst', type=int, default=DEFAULT_BURST,
                               help='Token-bucket burst capacity (opt-in). 0 = disabled (fixed pacing only)')
        subparser.add_argument('--debug-parity', action='store_true',
                               help='Enable validation/discovery parity checks (diagnostic logging)')
        subparser.add_argument('--clear-id-cache', action='store_true',
                               help='Clear file-id caches after validation (avoid cache reuse across phases)')
        subparser.add_argument('--strict-policy', action='store_true',
                               help='Treat unknown post-restore policy tokens as an error')
        subparser.add_argument('--limit', type=int, default=0,
                               help='Cap the number of items to discover/process (0 = no cap)')
        subparser.add_argument('--state-file', default=DEFAULT_STATE_FILE,
                               help='State file for resume capability')
        subparser.add_argument('--log-file', default=DEFAULT_LOG_FILE,
                               help='Log file path')
        subparser.add_argument('--verbose', '-v', action='count', default=0,
                               help='Increase verbosity (-v for INFO, -vv for DEBUG)')
        subparser.add_argument('--yes', '-y', action='store_true',
                               help='Skip confirmation prompts (for automation)')
        # v1.5.4: client-per-thread (default ON) and opt-out switch
        subparser.add_argument('--client-per-thread', dest='client_per_thread',
                               action='store_true', default=True,
                               help='Build a Drive API client per worker thread (default ON)')
        subparser.add_argument('--single-client', dest='client_per_thread',
                               action='store_false',
                               help='Use a single shared Drive API client (advanced)')
        # v1.5.5: rate limiter diagnostics
        subparser.add_argument('--rl-diagnostics', action='store_true',
                               help='Emit sampled rate-limiter stats at DEBUG level')
    return parser
    
def _set_mode(args) -> None:
    mode_map = {
        'dry-run': 'dry_run',
        'recover-only': 'recover_only',
        'recover-and-download': 'recover_and_download',
    }
    args.mode = mode_map.get(args.command)

def _validate_concurrency_arg(args) -> Tuple[bool, int]:
    try:
        cpu = os.cpu_count() or 1
    except Exception:
        cpu = 1
    ceiling = min(cpu * 4, 64)
    if args.concurrency < 1:
        print("❌ Invalid --concurrency value. It must be >= 1.")
        return False, 2
    if args.concurrency > ceiling:
        print(f"⚠️  --concurrency {args.concurrency} is high; capping to {ceiling} to avoid resource exhaustion and 429s.")
        args.concurrency = ceiling
    return True, 0

def _validate_download_dir_arg(args) -> Tuple[bool, int]:
    if getattr(args, 'mode', None) != 'recover_and_download':
        return True, 0
    try:
        p = Path(args.download_dir)
        if p.exists() and not p.is_dir():
            print(f"❌ --download-dir points to a file: {p}")
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
        print(f"❌ --download-dir is not writable or cannot be created: {e}")
        return False, 2

def _validate_after_date_arg(args) -> Tuple[bool, int]:
    if not getattr(args, 'after_date', None):
        return True, 0
    try:
        parsed = date_parser.parse(args.after_date)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        args.after_date = parsed.isoformat()
        return True, 0
    except Exception as e:
        print(f"❌ Invalid --after-date value '{args.after_date}': {e}")
        return False, 2

def _normalize_extension_token(token: str) -> str:
    if not isinstance(token, str):
        return ""
    token = token.strip().lower()
    token = token.strip(".")
    token = re.sub(r"\.+", ".", token)
    return token

def _is_invalid_extension_token(token: str) -> bool:
    if not token or not isinstance(token, str):
        return True
    if any(c in token for c in " ,*/\\"):
        return True
    return False

def _is_valid_extension_segments(token: str) -> bool:
    if not token:
        return False
    segments = token.split('.')
    for seg in segments:
        if not (1 <= len(seg) <= 10):
            return False
        if not re.fullmatch(r'[a-z0-9]+', seg):
            return False
    return True

def _dedupe_preserve_order(seq):
    seen = set()
    result = []
    for item in seq:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

def _normalize_and_validate_extensions_arg(args) -> Tuple[bool, int]:
    if not getattr(args, 'extensions', None):
        return True, 0
    invalid: List[str] = []
    cleaned: List[str] = []
    for raw in args.extensions:
        tok = _normalize_extension_token(raw)
        if _is_invalid_extension_token(tok):
            invalid.append(repr(raw))
            continue
        if not tok:
            invalid.append(repr(raw))
            continue
        if not _is_valid_extension_segments(tok):
            invalid.append(raw)
            continue
        cleaned.append(".".join([s for s in tok.split('.') if s != ""]))
    if invalid:
        print("❌ Invalid --extensions value(s): " + ", ".join(map(str, invalid)))
        print("   Use space-separated extensions like: --extensions jpg png pdf tar.gz min.js")
        print("   Do not include wildcards, commas, spaces, or path characters.")
        return False, 2
    deduped = _dedupe_preserve_order(cleaned)
    args.extensions = deduped
    unknown = [e for e in deduped if e not in EXTENSION_MIME_TYPES]
    if unknown:
        print("ℹ️  Note: unknown extension(s) will not narrow server-side queries;")
        print("   client-side filename filtering will apply instead: " + ", ".join(unknown))
        if any('.' in e for e in unknown):
            print("   Multi-segment extensions (e.g., tar.gz) are matched client-side only;")
            print("   server-side MIME narrowing uses the last segment when mapped.")
    return True, 0

def _normalize_policy_arg(args) -> Tuple[bool, int]:
    raw = getattr(args, "post_restore_policy", None)
    if raw is None or raw == "":
        args.post_restore_policy = PostRestorePolicy.TRASH
        return True, 0
    key = re.sub(r'[\s_-]+', '', str(raw).strip().lower())
    if key in PostRestorePolicy.ALIASES:
        args.post_restore_policy = PostRestorePolicy.ALIASES[key]
        return True, 0
    if getattr(args, "strict_policy", False):
        print(f"❌ Unknown --post-restore-policy value '{raw}'. Use one of: retain | trash | delete (aliases allowed).")
        return False, 2
    print(f"⚠️  Unknown --post-restore-policy '{raw}'. Falling back to 'trash'. (Tip: use --strict-policy to make this an error.)")
    args.post_restore_policy = PostRestorePolicy.TRASH
    return True, 0

def _run_tool(tool: 'DriveTrashRecoveryTool', args) -> bool:
    return tool.dry_run() if args.mode == 'dry_run' else tool.execute_recovery()

def main() -> int:
    parser = create_parser()
    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 2

    _set_mode(args)

    ok, code = _normalize_policy_arg(args)
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

    ok, code = _normalize_and_validate_extensions_arg(args)
    if not ok:
        return code

    tool = DriveTrashRecoveryTool(args)
 
    # Acquire state lock early; abort on contention
    try:
        if not tool._acquire_state_lock():
            print(f"❌ Another process is using the state file: {args.state_file}")
            print("   Tip: If the other run is intentional, wait for it to finish or use a different --state-file.")
            return 2
    except Exception:
        # Best-effort: continue even if locking not supported
        pass

    if hasattr(args, "file_ids") and args.file_ids:
        ok = tool._validate_file_ids()
        if not ok:
            return 2

    ran_ok = _run_tool(tool, args)
    try:
        tool._release_state_lock()
    except Exception:
        pass
    return 0 if ran_ok else 1

if __name__ == "__main__":
    sys.exit(main())
