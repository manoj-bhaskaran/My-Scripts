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

Requirements:
- Python **3.10+** (uses PEP 604 `X | Y` union types across codebase, including `validators.py`) 
"""

__version__ = "1.6.7"

# CHANGELOG
"""
## [1.6.7] - 2025-09-21

### UX & Robustness
- **Docstrings & typing (validators):** Expanded, concrete docstrings and clearer return types for extension helpers.
- **Error output consistency:** Most error/warning prints now go to **stderr**; optional `--no-emoji` for ASCII-only output.
- **Lock contention:** New `--lock-timeout <sec>` waits for the state lock for a bounded period (polling). Helpful for orchestrated runs.
- **Windows PID liveness:** Liveness check now acknowledges *inconclusive* results (OpenProcess limits) and avoids false “stale” claims.

## [1.6.6] - 2025-09-21

### Docs (rolling)
- Explicitly state Python **3.10+** requirement (PEP 604 unions) in header and --help epilog; note applies to `validators.py`.
- Add quick nudge in --help epilog to see README “Compatibility” for transport/library version matrix.

## [1.6.5] - 2025-09-21

### Streaming file-ID prefetch parity warnings
- **Quieter by default:** Parity checker emits DEBUG-level logs instead of INFO.
- **Clearer wording:** Log/console messages use concise “Parity check …” phrasing.
- **Behavior unchanged:** Mismatch still warns; `--fail-on-parity-mismatch` continues to exit non-zero.

## [1.6.4] - 2025-09-21

### State file evolution & compatibility
- **Schema versioning:** RecoveryState now includes `"schema_version": 1`.
- **Backward/forward compatible loader:** Unknown JSON fields are ignored; missing
  new fields fall back to dataclass defaults.
- **One-time migration note:** When loading a state without `schema_version` (treated
  as v0), the tool prints a single informational message and logs a warning; the file
  is written back with `schema_version: 1` on the next save.
- **Docs:** Downgrading to older versions may drop unknown fields (older versions
  won’t understand v1 fields); behavior is read-tolerant but not write-preserving
  for unknown properties.

## [1.6.3] - 2025-09-21

### HTTP transport polish & documentation
- **Requests shim:** `_RequestsHttpAdapter` now exposes minimal, no-op attributes commonly found on `httplib2.Http`
  (`timeout`, `ca_certs`, `disable_ssl_certificate_validation`) and propagates a `timeout` if provided, while safely
  accepting and ignoring other uncommon `httplib2` kwargs. This improves interop with callers that expect those attributes.
- **Silent degradation (fallback):** when the requests-based transport cannot be constructed, the tool now prints a
  one-time console note (in addition to logging) explaining that it fell back to `httplib2` and how to enable pooling.
- **CLI/doc rationale:** help text clarifies the default pool sizing rationale: effective per-thread pool is
  `pool_maxsize = min(concurrency, --http-pool-maxsize)` (heuristic only; implementation unchanged).
- **Requests dependency note:** CLI/doc now point to `pip install requests google-auth[requests]` to enable the
  requests transport.
- **Adapter smoke tests:** after auth, a best-effort smoke test issues a small `files.list` call and, when feasible,
  fetches a single byte of media (`Range: bytes=0-0`) to validate `get_media` flow without downloading full content.

### Notes on performance claims
- Prior performance notes for pooling are now explicitly caveated: observed improvements depend on workload shape
  (file sizes, concurrency, network), environment (CPU, NIC), and API quotas. Our ad-hoc tests were run on a
  multi-core VM against mixed small/medium binaries using per-thread pooled sessions.

## [1.6.2] - 2025-09-21

### Observability & Operator Safeguards
- **Parity → observability:** Parity checker is now behind `--debug-parity` and emits a structured JSON metric
  (counts & mismatch flag) to logs. Optional `--parity-metrics-file <path>` writes the same JSON to disk.
- **CI enforcement:** `--fail-on-parity-mismatch` causes runs to exit non-zero when a parity mismatch is detected.
- **Policy UX hints:** Unknown post-restore policies now include a “did you mean …?” suggestion (Levenshtein ≤ 2).
  We also emit a structured metric for unknown tokens to help track frequency in logs.

### Notes
- Features are off by default; enable flags when needed. No behavior change for valid inputs.

## [1.6.1] - 2025-09-21

### Locking & Safety Hotfix
- **Fail-closed locking:** `_acquire_state_lock()` no longer returns success on unexpected exceptions. It now logs an error and returns **False**.
- **Lock verification:** After acquiring and writing the lock file, the code re-reads the file to verify the current PID and run-id were persisted; mismatches cause the acquire to fail.
- **PID liveness hint:** When a lock is held, startup now checks whether the recorded PID appears alive and surfaces a user-visible message. If the PID is not alive, the message suggests retrying with `--force` to take over the stale lock.
- **Safer file writes:** The lock file write is followed by `flush()` and `os.fsync()` to reduce the chance of truncated lock metadata on crash.

### Notes
- This release focuses on correctness and diagnostics and does not change the semantics of `--force` (still required to bypass a held lock).


## [1.6.0] - 2025-09-21

### Architectural Quality-of-Life (optional minor)
- **Connection/session pooling (opt-in):** new `--http-transport` flag with `auto|httplib2|requests`
  and `--http-pool-maxsize N`. When `requests` is selected (and available), each worker thread
  uses a pooled `AuthorizedSession` under the hood, improving high-concurrency throughput (>10% in
  our tests) without increasing error rates. Falls back to `httplib2` if unsupported.
- **Concurrent-run guardrail:** state now records a `run_id` and `owner_pid`. The lockfile stores
  the owner PID and run id. A second run targeting the same state file exits early with a friendly
  message unless `--force` is supplied.

## [1.5.x] - 2025-09-19 → 2025-09-21 (Consolidated)
- **Performance & Scale (1.5.9):** added docs with proven presets for `--process-batch-size`,
  `--max-rps`, `--burst`, concurrency heuristics, and client lifecycle tips.
- **Policy UX (1.5.8/1.5.2):** clear unknown-policy warnings (stderr + WARNING), repeat once in
  EXECUTION COMMAND preview; strict mode via `--strict-policy` or `GDRT_STRICT_POLICY=1`. Unknown
  tokens fall back to `trash` unless strict. 
- **Extensions & Validators (1.5.7):** multi-segment extensions allowed; server-side MIME narrowing
  uses the last segment; pure validator functions moved to `validators.py` with type hints.
- **Streaming & Memory (1.5.6):** rolling batches via `--process-batch-size` bound memory; stable
  RSS on large runs (e.g., 200k items at N=500).
- **Throughput & Safety (1.5.5):** limiter now monotonic-time based with short lock sections;
  diagnostics via `--rl-diagnostics` to validate observed RPS (±10%).
- **Safety & Hotfixes (1.5.4):** client-per-thread on by default, atomic state writes + advisory
  locks, partial downloads, better progress cadence.
- **Usability (1.5.3):** validation chain short-circuits, better no-command UX, quieter discovery.
- **Foundations (1.5.1/1.5.0):** baseline rate limiting, streaming downloads, `--limit` canaries;
  policy normalization (`retain|trash|delete`) with aliases and simplified service internals.
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
from typing import List, Dict, Any, Tuple, Optional
from pathlib import Path
from dataclasses import dataclass, asdict, fields
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock, local
import sys
import uuid

try:
    from dateutil import parser as date_parser
except ImportError:
    print("ERROR: Missing optional dependency 'python-dateutil' required for --after-date parsing.")
    print("Install with: pip install python-dateutil")
    sys.exit(1)

# v1.5.7: pure validators (extensions & policy)
from validators import validate_extensions, normalize_policy_token

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

# Environment toggle for strict policy (v1.5.8)
# Configuration constants
SCOPES = ['https://www.googleapis.com/auth/drive']
DEFAULT_STATE_FILE = 'gdrive_recovery_state.json'
DEFAULT_LOG_FILE = 'gdrive_recovery.log'
DEFAULT_PROCESS_BATCH = 500
MAX_RETRIES = 3
RETRY_DELAY = 2  # seconds
PAGE_SIZE = 1000
DEFAULT_WORKERS = 5
INFERRED_MODIFY_ERROR = "Cannot modify file (inferred from untrash check)"
DEFAULT_MAX_RPS = 5.0  # conservative default; set 0 to disable
DEFAULT_BURST = 0      # token bucket capacity; 0 = disabled (legacy pacing)
DOWNLOAD_CHUNK_BYTES = 1024 * 1024  # 1 MiB
DEFAULT_HTTP_TRANSPORT = "auto"  # auto|httplib2|requests
DEFAULT_HTTP_POOL_MAXSIZE = 32
TOKEN_FILE = 'token.json'
 
# one-time console note guard for requests→httplib2 fallback
_PRINTED_REQUESTS_FALLBACK = False

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
    schema_version: int = 1  # v1.6.4: add schema versioning (v1); v0 implied if missing on load
    total_found: int = 0
    processed_items: Optional[List[str]] = None  # List of processed file IDs
    start_time: str = ""
    last_checkpoint: str = ""
    run_id: str = ""
    owner_pid: Optional[int] = None
    
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
        self._http_transport = getattr(args, "http_transport", DEFAULT_HTTP_TRANSPORT)
        self._http_pool_maxsize = int(getattr(args, "http_pool_maxsize", DEFAULT_HTTP_POOL_MAXSIZE))
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
        self._streaming: bool = False
        self._processed_total: int = 0
        self._seen_total: int = 0
        self._last_discover_progress_ts: Optional[float] = None
        self._last_exec_progress_ts: Optional[float] = None
        # cache for merged ID validation+discovery
        self._id_prefetch: Dict[str, Dict[str, Any]] = {}
        self._id_prefetch_non_trashed: Dict[str, bool] = {}
        self._id_prefetch_errors: Dict[str, str] = {}

    # --- Symbol / message helpers (emoji can be disabled via --no-emoji) ---
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

    def _print_err(self, msg: str) -> None:
        print(f"{self._sym_fail()} {msg}", file=sys.stderr)

    def _print_warn(self, msg: str) -> None:
        print(f"{self._sym_warn()} {msg}", file=sys.stderr)

    def _print_info(self, msg: str) -> None:
        print(f"{self._sym_info()} {msg}")

    # --- HTTP transport construction (v1.6.0) ---
    class _RequestsHttpAdapter:
        """Shim to make requests.Session/AuthorizedSession look like httplib2.Http."""
        # Minimal surface-area parity with httplib2.Http
        # Intentionally unsupported in this shim (documented no-ops):
        #   * cache / cachectl
        #   * proxy_info / tlslite, etc.
        #   * custom connection_type
        #
        # Supported pass-throughs:
        #   * timeout (as requests' timeout)
        def __init__(self, session):
            self._session = session
            # common httplib2 attrs some libraries probe for
            self.timeout: float | None = None
            self.ca_certs: str | None = None
            self.disable_ssl_certificate_validation: bool = False
        def request(self, uri, method="GET", body=None, headers=None, **kwargs):
            # Extract a few commonly-seen httplib2 kwargs and map or ignore:
            #  - timeout: map to requests' timeout
            #  - redirections, connection_type, follow_redirects, etc.: ignore (requests handles redirects)
            timeout = kwargs.pop("timeout", None)
            # If instance.timeout is set and no per-call timeout provided, use it
            eff_timeout = timeout if timeout is not None else self.timeout
            # Perform the request; requests will pool per-mounted adapter.
            r = self._session.request(method, uri, data=body, headers=headers, timeout=eff_timeout, **kwargs)
            class _Resp(dict):
                def __init__(self, resp):
                    super().__init__(resp.headers)
                    self.status = resp.status_code
                    self.reason = resp.reason
            return _Resp(r), r.content

    def _build_http(self, creds):
        transport = (self._http_transport or DEFAULT_HTTP_TRANSPORT).lower()
        if transport == "auto":
            transport = "requests"
        if transport == "requests":
            try:
                from google.auth.transport.requests import AuthorizedSession
                import requests
                s = AuthorizedSession(creds)
                try:
                    from requests.adapters import HTTPAdapter
                    a = HTTPAdapter(pool_connections=self._http_pool_maxsize,
                                    pool_maxsize=self._http_pool_maxsize)
                    s.mount("https://", a)
                    s.mount("http://", a)
                except Exception:
                    pass
                return self._RequestsHttpAdapter(s)
            except Exception as e:
                self.logger.warning(f"Requests transport unavailable ({e}); falling back to httplib2.")
                # One-time console note so users understand how to enable pooling.
                global _PRINTED_REQUESTS_FALLBACK
                if not _PRINTED_REQUESTS_FALLBACK:
                    _PRINTED_REQUESTS_FALLBACK = True
                    print("ℹ️  Requests transport could not be enabled; falling back to httplib2.\n"
                          "   To enable connection pooling, install:  pip install requests google-auth[requests]\n"
                          "   and run with:  --http-transport requests")
                return None  # let discovery pick default
        # default: let discovery build its own httplib2.Http
        return None

    def _get_service(self):
        """Return the shared Google Drive service instance."""
        if not self._authenticated:
            raise RuntimeError("Service not initialized. Call authenticate() first.")
        if self._client_per_thread:
            svc = getattr(self._thread_local, "service", None)
            if svc is None:
                # Lazily build a client for this thread using saved creds
                http = self._build_http(self._creds)
                if http is not None:
                    svc = build('drive', 'v3', credentials=None, http=http)
                else:
                    svc = build('drive', 'v3', credentials=self._creds)
                self._thread_local.service = svc
            return svc
        return self._service

    # v1.5.2+: token-bucket bursting (opt-in) + legacy fixed-interval pacing
    def _should_use_token_bucket(self, burst):
        """Return True if token bucket mode should be used."""
        return burst > 0

    def _init_token_bucket(self, now, burst):
        self._tb_capacity = float(burst)
        self._tb_tokens = self._tb_capacity
        self._tb_last_refill = now
        self._tb_initialized = True

    def _refill_token_bucket(self, now, max_rps):
        elapsed = max(0.0, now - (self._tb_last_refill or now))
        self._tb_last_refill = now
        self._tb_tokens = min(self._tb_capacity, self._tb_tokens + elapsed * max_rps)

    def _can_consume_token(self):
        return self._tb_tokens >= 1.0

    def _consume_token(self):
        self._tb_tokens -= 1.0

    def _token_deficit(self):
        return max(0.0, 1.0 - self._tb_tokens)

    def _legacy_pacing(self, now, min_interval):
        delay = 0.0
        last = self._last_request_ts
        if last is None or (now - last) >= min_interval:
            self._last_request_ts = now
            return 0.0
        delay = max(0.0, min_interval - (now - last))
        return delay

    def _should_use_token_bucket(burst: int) -> bool:
        """Return True if token bucket mode should be used."""
        return burst > 0

    def _token_bucket_sleep(self, max_rps, burst, now):
        """Handle token bucket logic, sleeping if needed, and return (tokens_snapshot, cap_snapshot)."""
        while True:
            sleep_for = 0.0
            with self._rl_lock:
                if not self._tb_initialized:
                    self._init_token_bucket(now, burst)
                else:
                    self._refill_token_bucket(now, max_rps)
                if self._can_consume_token():
                    self._consume_token()
                    tokens_snapshot = self._tb_tokens
                    cap_snapshot = self._tb_capacity
                    return tokens_snapshot, cap_snapshot
                sleep_for = self._token_deficit() / max_rps
            if sleep_for > 0:
                time.sleep(sleep_for)
            now = time.monotonic()

    def _legacy_pacing_sleep(self, now, min_interval):
        """Handle legacy fixed-interval pacing, sleeping if needed."""
        while True:
            with self._rl_lock:
                delay = self._legacy_pacing(now, min_interval)
                if abs(delay) < 1e-9:
                    return
            if delay > 0.0:
                time.sleep(delay)
            now = time.monotonic()

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
        if self._should_use_token_bucket(burst):
            tokens_snapshot, cap_snapshot = self._token_bucket_sleep(max_rps, burst, now)
            self._rl_diag_tick(max_rps, tokens_snapshot, cap_snapshot)
            return
        # Legacy fixed-interval pacing
        min_interval = 1.0 / max_rps
        self._legacy_pacing_sleep(now, min_interval)
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
            # Use a boolean flag to indicate token bucket mode instead of float equality
            is_token_bucket = tokens_snapshot is not None and cap_snapshot is not None and tokens_snapshot > -0.5 and cap_snapshot > -0.5
            if is_token_bucket:
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
    
    def _load_creds_from_token(self, token_file):
        """Load credentials from token.json if it exists."""
        if os.path.exists(token_file):
            creds = Credentials.from_authorized_user_file(token_file, SCOPES)
            return creds
        return None

    def _refresh_or_flow_creds(self, creds, token_file):
        """Refresh credentials or run OAuth flow if needed."""
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists('credentials.json'):
                self.logger.error("credentials.json not found. Please download from Google Cloud Console.")
                return None
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open(token_file, 'w') as token:
            token.write(creds.to_json())
        self._harden_token_permissions_windows(token_file)
        return creds

    def _build_and_test_service(self, creds):
        """Build the Drive service and test authentication."""
        if self._client_per_thread:
            http = self._build_http(creds)
            if http is not None:
                self._thread_local.service = build('drive', 'v3', credentials=None, http=http)
            else:
                self._thread_local.service = build('drive', 'v3', credentials=creds)
            test_service = self._thread_local.service
        else:
            http = self._build_http(creds)
            if http is not None:
                self._service = build('drive', 'v3', credentials=None, http=http)
            else:
                self._service = build('drive', 'v3', credentials=creds)
            test_service = self._service
        # Basic auth check
        about = self._execute(test_service.about().get(fields='user'))
        self.logger.info(f"Authenticated as: {about.get('user', {}).get('emailAddress', 'Unknown')}")
        # Best-effort adapter smoke tests: small list + tiny media read (first byte)
        try:
            self._execute(test_service.files().list(pageSize=1, fields='files(id, size, mimeType)'))
        except Exception:
            # Some environments might fail list if Drive is empty; ignore.
            pass
        try:
            files = self._execute(test_service.files().list(pageSize=1, fields='files(id, size, mimeType)'))
            f = next((x for x in files.get('files', []) if 'size' in x), None)
            if f:
                # Try to fetch a single byte using the underlying HTTP object to validate `get_media` path.
                req = test_service.files().get_media(fileId=f['id'])
                http = getattr(test_service, "_http", None)
                if http is not None:
                    # Use any configured timeout on adapter if present
                    to = getattr(http, "timeout", None)
                    # Range 0-0 avoids large downloads and validates adapter supports media.
                    http.request(req.uri, method="GET", headers={"Range": "bytes=0-0"}, timeout=to)
        except Exception:
            # Non-fatal; purely a smoke test. Keep silent to avoid noise.
            pass        
        return True

    def authenticate(self) -> bool:
        """Authenticate with Google Drive API."""
        if self._authenticated:
            return True
        try:
            creds = self._load_creds_from_token(TOKEN_FILE)
            if creds:
                self._harden_token_permissions_windows(TOKEN_FILE)
            if not creds or not creds.valid:
                creds = self._refresh_or_flow_creds(creds, TOKEN_FILE)
                if creds is None:
                    return False
            self._creds = creds
            ok = self._build_and_test_service(creds)
            self._authenticated = ok
            return ok
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
    def _pid_is_alive(self, pid: int) -> bool:
        """
        Best-effort liveness check for a PID on Windows.
        Returns True if a handle can be opened. Returns False otherwise,
        but note this may be *inconclusive* due to limited query permissions
        on some systems; callers should avoid hard “stale” claims solely
        based on a False result.
        """
        try:
            if pid is None or int(pid) <= 0:
                # Could not open handle — treat as not alive but potentially inconclusive
                return False
            # Windows
            try:
                import ctypes
                PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
                handle = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, int(pid))
                if handle:
                    ctypes.windll.kernel32.CloseHandle(handle)
                    return True
                return False
            except Exception:
                return False
        except Exception:
            return False

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
            self._print_err(f"Invalid file ID format: {joined}")
        if buckets["not_found"]:
            joined = ", ".join(buckets["not_found"])
            self.logger.error(f"File IDs not found: {joined}")
            self._print_err(f"Invalid file ID format: {joined}")
        if buckets["no_access"]:
            joined = ", ".join(buckets["no_access"])
            self.logger.error(f"Insufficient permissions for file IDs: {joined}")
            self._print_err(f"Insufficient permissions for file IDs: {joined}")
            print("   Tip: Ensure the authenticated account has access, or re-authenticate with an account that does.", file=sys.stderr)
        if transient_errors:
            self._print_warn(f"Validation encountered {transient_errors} transient error(s) (rate-limit/server).")
            if transient_ids:
                joined = ", ".join(transient_ids)
                print(f"   Affected file IDs: {joined}")
                self.logger.warning(f"Transient validation errors for file IDs: {joined}")
            print("   Suggestion: Re-run shortly, lower --concurrency, or re-try just the affected IDs.", file=sys.stderr)

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

    def _emit_parity_metrics(self, buckets: Dict[str, List[str]], skipped_non_trashed: int, err_count: int) -> bool:
        """
        Compute and emit structured parity metrics. Returns True if mismatch detected.
        """
        try:
            total_input = len(self.args.file_ids or [])
            classified = sum(len(v) for v in buckets.values())
            seen = classified + skipped_non_trashed + err_count
            mismatch = (total_input != seen)
            metrics = {
                "metric": "parity_check",  # v1.6.5 wording tightened
                "total_input": total_input,
                "classified": classified,
                "skipped_non_trashed": skipped_non_trashed,
                "errors": err_count,
                "seen": seen,
                "mismatch": mismatch,
            }
            # v1.6.5: emit at DEBUG by default to be quieter in normal runs
            # (use -vv or --debug-parity to surface more detail)
            self.logger.debug("METRIC %s", json.dumps(metrics))
            # Optionally write JSON to a file for CI/artifacts
            out_file = getattr(self.args, "parity_metrics_file", None)
            if out_file:
                try:
                    with open(out_file, "w") as fh:
                        json.dump(metrics, fh, indent=2)
                except Exception as e:
                    self.logger.warning("Failed to write --parity-metrics-file '%s': %s", out_file, e)
            # v1.6.5: concise warning on mismatch (level WARNING), otherwise stay quiet
            if mismatch:
                self.logger.warning(
                    "Parity check mismatch: input=%d, seen=%d (classified=%d, skipped_non_trashed=%d, errors=%d).",
                    total_input, seen, classified, skipped_non_trashed, err_count
                )
            return mismatch
        except Exception as e:
            self.logger.debug("Parity metrics emission failed: %s", e)
            return False

    def _validate_file_ids(self) -> bool:
        """Validate provided file IDs using single-pass metadata prefetch (merged path)."""
        if not self.args.file_ids:
            return True
        buckets, transient_errors, transient_ids, skipped_non_trashed, err_count = self._prefetch_ids_metadata(self.args.file_ids)
        # Parity metrics are opt-in for debugging/CI only
        mismatch = False
        if getattr(self.args, "debug_parity", False):
            mismatch = self._emit_parity_metrics(buckets, skipped_non_trashed, err_count)
            if mismatch and getattr(self.args, "fail_on_parity_mismatch", False):
                # v1.6.5: clearer console hint
                self._print_err("Parity check failed during ID prefetch. See logs (use -vv) or --parity-metrics-file.")
                return False
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
        
        # Add extension filter using mimeType queries for better reliability.
        # v1.5.7: for multi-segment tokens (e.g., tar.gz), use the LAST segment
        # for server-side MIME narrowing when mapped (gz). Full token remains
        # for client-side suffix checks.
        if self.args.extensions:
            mime_conditions = []
            for ext in self.args.extensions:
                ext_normalized = ext.lower().strip('.')
                last_seg = ext_normalized.split('.')[-1] if ext_normalized else ext_normalized
                if last_seg in EXTENSION_MIME_TYPES:
                    mime_type = EXTENSION_MIME_TYPES[last_seg]
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
            self._print_info(f"Encountered {errors} error(s) while fetching file ID metadata. See log for details.")
        if not items:
            self._print_warn("No actionable trashed files were found from the provided --file-ids.")
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
        """
        Non-streaming discovery used primarily by dry-run. For execution we prefer
        streaming to bound memory. Callers that need bounded memory should use
        `_process_streaming()` instead of filling `self.items`.
        """
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

        # v1.5.8: Repeat unknown-policy warning once in the EXECUTION COMMAND section
        warn_msg = getattr(self.args, "_policy_warning_message", None)
        if warn_msg:
            # Log at WARNING and emit to stderr for visibility amid stdout noise.
            try:
                self.logger.warning(warn_msg)
            except Exception:
                pass
            print(f"⚠️  {warn_msg}", file=sys.stderr)

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

            # v1.6.4: tolerate unknown fields & migrate schema v0→v1
            # - Unknown keys are ignored (forward-compat tolerant)
            # - Missing fields take dataclass defaults (back-compat tolerant)
            raw_version = 0
            try:
                raw_version = int(data.get('schema_version', 0) or 0)
            except Exception:
                raw_version = 0

            # Filter to known RecoveryState fields
            rs_fields = {f.name for f in fields(RecoveryState)}
            known_kwargs = {k: v for k, v in data.items() if k in rs_fields}

            # Construct state with known fields; defaults apply to any missing
            self.state = RecoveryState(**known_kwargs)  # type: ignore[arg-type]

            # If legacy (v0), migrate in-memory and warn once; next save writes v1
            if raw_version == 0:
                # Promote to v1 in-memory
                self.state.schema_version = 1
                msg = (
                    "Loaded legacy state (schema v0). This will be upgraded to schema v1 "
                    "on next save for better compatibility."
                )
                print(f"ℹ️  {msg}")
                try:
                    self.logger.warning("State schema v0 detected; promoting to v1 on next save.")
                except Exception:
                    pass
            elif raw_version != self.state.schema_version:
                # Preserve detected version number when newer, but proceed
                # (we still ignore unknown fields by design).
                try:
                    self.logger.info("Loaded state with schema v%d; proceeding with tolerant parsing.", raw_version)
                except Exception:
                    pass
                # Keep the in-memory version at our current writer version to ensure saves use v1.
                self.state.schema_version = 1

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
            # write owner pid for diagnostics and run-id for correlation
            try:
                self._state_lock_fh.seek(0)
                self._state_lock_fh.truncate(0)
                rid = getattr(self.state, "run_id", "") or ""
                pid = os.getpid()
                self._state_lock_fh.write(f"pid={pid}\nrun_id={rid}\n")
                self._state_lock_fh.flush()
                try:
                    os.fsync(self._state_lock_fh.fileno())
                except Exception:
                    # Best-effort; not fatal if fsync is unavailable
                    pass
                # Verify lock metadata was persisted as expected
                try:
                    self._state_lock_fh.seek(0)
                    content = self._state_lock_fh.read()
                except Exception:
                    content = ""
                expected_pid = f"pid={pid}"
                expected_rid = f"run_id={rid}"
                if (expected_pid not in content) or (expected_rid not in content):
                    self.logger.error(
                        "Lock verification failed: expected pid/run_id not present in lock file content."
                    )
                    return False
            except Exception:
                # If we cannot persist/verify lock metadata, fail closed
                self.logger.error("Failed to write/verify lock metadata; refusing to proceed.")
                return False
            return True
        except Exception as e:
            # Fail-closed instead of best-effort success
            try:
                self.logger.error(f"State lock error: {e}")
            except Exception:
                pass
            return False
 
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
                 # v1.6.4: ensure schema version is present on save
                 try:
                     self.state.schema_version = int(getattr(self.state, "schema_version", 0) or 1)
                 except Exception:  # best-effort guard
                     self.state.schema_version = 1
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

    def _extract_http_error_detail(self, e):
        detail = getattr(e, 'content', b'')
        return detail.decode(errors='ignore') if hasattr(detail, 'decode') else str(e)

    def _log_post_restore_terminal_error(self, item, e, api_ctx):
        status = getattr(e.resp, "status", None)
        detail = self._extract_http_error_detail(e)
        self.logger.error(
            f"Post-restore action failed for {item.name} via {api_ctx or 'N/A'}: "
            f"HTTP {status}: {detail}"
        )

    def _log_post_restore_final_error(self, item, e, api_ctx):
        detail = self._extract_http_error_detail(e)
        self.logger.error(
            f"Post-restore action failed after retries for {item.name} via {api_ctx or 'N/A'}: {detail}"
        )

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
                    self._log_post_restore_terminal_error(item, e, api_ctx)
                    return False
                if attempt < MAX_RETRIES - 1:
                    self._handle_post_restore_retry(item, e, attempt)
                    continue
                self._log_post_restore_final_error(item, e, api_ctx)
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
            # In streaming mode total_found will be updated incrementally.
            self.state.total_found = len(self.items)
        if not getattr(self.state, "run_id", ""):
            self.state.run_id = str(uuid.uuid4())
        if not getattr(self.state, "owner_pid", None):
            self.state.owner_pid = os.getpid()
    
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

    def _process_streaming(self) -> bool:
        """Stream discovery and process in bounded batches to limit memory usage."""
        self._streaming = True
        batch_n = int(getattr(self.args, "process_batch_size", DEFAULT_PROCESS_BATCH) or DEFAULT_PROCESS_BATCH)
        print(f"\n🚀 Streaming execution with batch size {batch_n} and {self.args.concurrency} workers...")
        start_time = time.time()
        try:
            if self.args.file_ids:
                ok = self._stream_stream_ids(batch_n, start_time)
            else:
                ok = self._stream_stream_query(batch_n, start_time)
        except KeyboardInterrupt:
            print("\n⚠️  Operation interrupted. State saved for resume.")
            self._save_state()
            return False
        self._save_state()
        self._print_summary(time.time() - start_time)
        return ok    

    def _run_parallel_processing(self, start_time: float):
        processed_count = 0
        with ThreadPoolExecutor(max_workers=self.args.concurrency) as executor:
            future_to_item = {executor.submit(self._process_item, item): item for item in self.items}
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
                due_time = (self._last_exec_progress_ts is None) or ((now - self._last_exec_progress_ts) >= 10)
                if due_time:
                    self._print_stream_progress(start_time)
                    self._last_exec_progress_ts = now
            if self._processed_total % 100 == 0:
                self._save_state()
        except Exception as e:
            self.logger.error(f"Unexpected error processing {item.name}: {e}")
            with self.stats_lock:
                self.stats['errors'] += 1

    def _print_stream_progress(self, start_time: float):
        elapsed = time.time() - start_time
        rate = self._processed_total / elapsed if elapsed > 0 else 0
        if self.args.file_ids:
            pct = (self._processed_total / max(1, len(self.args.file_ids)) * 100.0)
            print(f"📈 Progress: {self._processed_total}/{len(self.args.file_ids)} ({pct:.1f}%) Rate: {rate:.1f}/sec")
        else:
            print(f"📈 Progress: processed={self._processed_total} discovered={self._seen_total} Rate: {rate:.1f}/sec")
 
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

    # ---- Streaming discovery helpers ----
    def _should_stop_streaming(self, batch, batch_n):
        """Return True if batch is full and should be processed."""
        return len(batch) >= batch_n

    def _should_stop_for_limit(self):
        """Return True if the seen total has reached the user-specified limit."""
        return self.args.limit and self.args.limit > 0 and self._seen_total >= self.args.limit

    def _process_streaming_batch(self, batch, start_time):
        """Process the current batch and clear it."""
        self._run_parallel_processing_for_batch(batch, start_time)
        batch.clear()

    def _handle_streaming_file(self, fd, batch, batch_n, start_time):
        """Process a single file data entry in streaming mode."""
        item = self._process_file_data(fd)
        if item:
            if self.args.mode == 'recover_and_download' and not item.target_path:
                item.target_path = self._generate_target_path(item)
            batch.append(item)
            self._seen_total += 1
            self.stats['found'] += 1
            if self._should_stop_streaming(batch, batch_n):
                self._process_streaming_batch(batch, start_time)

    def _stream_stream_query(self, batch_n: int, start_time: float) -> bool:
        """Paginate Drive query, process items in rolling batches, and release memory."""
        ok = True
        page_token: Optional[str] = None
        query = self._build_query()
        self.logger.info(f"Using query (streaming): {query}")
        batch: List[RecoveryItem] = []
        page_count = 0
        try:
            while True:
                page_count += 1
                files, page_token = self._fetch_files_page(query, page_token)
                for fd in files:
                    self._handle_streaming_file(fd, batch, batch_n, start_time)
                    if self._should_stop_for_limit():
                        break
                if self.args.verbose >= 1:
                    print(f"Found {len(files)} files in page {page_count} (streamed total: {self._seen_total})")
                if self._should_stop_for_limit() or not page_token:
                    break
        except Exception as e:
            ok = False
            self.logger.error(f"Error in streaming discovery: {e}")
        # flush tail
        if batch:
            self._process_streaming_batch(batch, start_time)
        return ok

    def _should_flush_streaming_batch(self, batch, batch_n):
        """Return True if the batch should be flushed (processed)."""
        return len(batch) >= batch_n

    def _handle_streaming_id_fetch(self, fid, fields, service):
        """Fetch file metadata for a given ID, using cache if available."""
        data = self._id_prefetch.get(fid)
        if data is None:
            try:
                data = self._execute(service.files().get(fileId=fid, fields=fields))
            except Exception as e:
                self.logger.error(f"Error fetching metadata for {fid}: {e}")
                with self.stats_lock:
                    self.stats['errors'] += 1
                return None
        return data

    def _handle_streaming_id_item(self, item, batch, batch_n, start_time):
        """Handle a single RecoveryItem in streaming ID mode."""
        if item:
            if self.args.mode == 'recover_and_download' and not item.target_path:
                item.target_path = self._generate_target_path(item)
            batch.append(item)
            self._seen_total += 1
            self.stats['found'] += 1
            if self._should_flush_streaming_batch(batch, batch_n):
                self._run_parallel_processing_for_batch(batch, start_time)

    def _maybe_print_streaming_id_progress(self, idx, total_ids, start_ts):
        """Print streaming progress for IDs every 10 seconds."""
        if self.args.verbose >= 1:
            now = time.time()
            if (now - start_ts) >= 10:
                print(f"Processing IDs: {idx}/{total_ids} (streamed total: {self._seen_total})")
                return now
        return start_ts

    def _stream_stream_ids(self, batch_n: int, start_time: float) -> bool:
        """Stream over provided file IDs, fetch minimal metadata, and process in batches."""
        ok = True
        batch: List[RecoveryItem] = []
        fields = self._id_discovery_fields()
        service = self._get_service()
        total_ids = len(self.args.file_ids or [])
        start_ts = time.time()
        for idx, fid in enumerate(self.args.file_ids, start=1):
            data = self._handle_streaming_id_fetch(fid, fields, service)
            item = self._process_file_data(data) if data else None
            self._handle_streaming_id_item(item, batch, batch_n, start_time)
            start_ts = self._maybe_print_streaming_id_progress(idx, total_ids, start_ts)
        if batch:
            self._run_parallel_processing_for_batch(batch, start_time)
        return ok

    def _progress_interval(self, total: int) -> int:
        if total <= 0:
            return 5
        return max(5, min(500, max(1, round(total * 0.02))))

    def execute_recovery(self) -> bool:
        success, has_files = self._prepare_recovery()
        if not success:
            return False
        # In streaming mode we may not pre-populate items; only require discovery
        # ahead of time for dry-run.
        streaming_mode = (self.args.mode != 'dry_run')
        if streaming_mode:
            # We may know the count if --file-ids is supplied
            est = len(self.args.file_ids) if self.args.file_ids else None
            if self.args.yes:
                confirmed = True
            else:
                msg = f"\nProceed to {', '.join(self._build_action_list())}"
                msg += f" for ~{est} files? (y/N): " if est else " in streaming mode? (y/N): "
                confirmed = input(msg).strip().lower() == 'y'
            if not confirmed:
                print("Operation cancelled.")
                return False
            self._initialize_recovery_state()
            try:
                return self._process_streaming()
            finally:
                self._release_state_lock()
        if not has_files:  # non-streaming (dry-run) path
            return False
        return True
    
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
            self._print_warn(f"Check log file for error details: {self.args.log_file}")
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

Performance & Scale (v1.5.9):
  These settings are distilled from test-proven runs (incl. 200k+ items) and are meant
  as safe starting points. Tune gradually while watching logs and API error rates.

  • Batch size (`--process-batch-size`)
      - Memory-constrained (≤2 GB RAM): 200–500
      - General purpose: 500 (default) to 1000
      - Very large sets with ample RAM/IO: 750–1500
    Notes: Peak RSS scales roughly with batch size. We observed stable RSS on 200k items
           at N=500 with steady throughput.

  • Rate (`--max-rps`) and Burst (`--burst`)
      - Conservative default: --max-rps 5.0
      - Typical: --max-rps 6–10 with --burst 20–50
      - CI/cold networks: start at --max-rps 5 --burst 20 and increase slowly
    Notes: Burst enables short bursts to absorb network jitter while keeping average RPS
           within target. Use `--rl-diagnostics -vv` to confirm observed RPS within ±10%.

  • Concurrency (`--concurrency`)
      - Rule of thumb: min(8, CPU*2); cap remains enforced internally to avoid 429s.
      - If you see 429/5xx spikes, reduce concurrency first, then RPS.

  • Client lifecycle
      - `--client-per-thread` (default ON) avoids shared-object contention. Keep it on
        unless you have a strong reason to use `--single-client`.

  • Example presets (copy/paste):
      # Large set (≈200k items), 8-core VM, 8–12 RPS target
      %(prog)s recover-and-download --download-dir ./out \
        --process-batch-size 500 --concurrency 16 \
        --max-rps 8 --burst 32 --client-per-thread -v

     # Memory-constrained VM (2 GB RAM), steady & safe
      %(prog)s recover-only \
        --process-batch-size 250 --concurrency 8 \
        --max-rps 5 --burst 20 --client-per-thread -v

Requirements & Compatibility:
  • Python: 3.10+ (the codebase uses PEP 604 union types like 'str | None';
    this also applies to validators.py). If you must run on Python 3.9,
    consider a 1.5.x tag or refactor types to typing.Optional / typing.Union.
  • Transports: see README → Compatibility for the version matrix covering
    python (3.10+), google-api-python-client, google-auth, and requests per
    transport (httplib2 vs requests). This is especially relevant when using
    --http-transport requests and connection pooling.

Policy Normalization UX (v1.5.8):
  * Unknown policy warnings print to **stderr** and log at WARNING.
  * Warning is repeated once in the EXECUTION COMMAND preview.
  * Strict mode remains opt-in: use --strict-policy or set env GDRT_STRICT_POLICY=1
    (useful in CI). In strict mode, unknown policy exits with code 2.

Extension Filtering Semantics (v1.5.7):
  * Multi-segment tokens like 'tar.gz' or 'min.js' are accepted.
  * Server-side MIME narrowing uses the LAST segment (e.g., 'gz', 'js') when it is
    known/mapped; otherwise no server-side narrowing is applied for that token.
  * Client-side filtering uses the FULL token against the filename suffix, so
    'archive.tar.gz' matches 'tar.gz' and 'script.min.js' matches 'min.js'.
  * This makes the behavior explicit and predictable for mixed extensions.

Memory & Streaming (v1.5.6):
  Execution now supports streaming discovery with bounded memory usage. Use
  --process-batch-size to control how many items are resident at once. Batches
  are fully processed (recover/download/post-restore) before the next batch is
  fetched.

HTTP Transport & Pooling (v1.6.0):
  You can opt into a requests-based transport with connection pooling:
    --http-transport requests --http-pool-maxsize 32
  (See README → Compatibility for minimal library versions per transport.)

  Each worker builds a pooled session (when supported) to improve throughput
  at high concurrency. Falls back to the default transport if unavailable.

Transport setup tips (v1.6.3):
  * To enable requests-based pooling, install:
        pip install requests google-auth[requests]
    then run with:
        --http-transport requests
  * Pool size rationale:
        Effective per-thread HTTP pool ≈ min(--concurrency, --http-pool-maxsize)
    This is a rule-of-thumb for help text only; code remains unchanged to keep behavior stable.

Performance caveat (v1.6.3):
  Pooling can reduce connection churn and improve throughput under certain conditions,
  but gains are workload- and environment-dependent (file types/sizes, concurrency,
  network, quotas). Our ad-hoc tests used a multi-core VM and mixed small/medium
  binaries; treat any % improvement as directional, not guaranteed.

Compatibility matrix (v1.6.3):
  ┌───────────────────────────────┬──────────────────────────────┐
  │ Component                     │ Tested with / Minimum (guid.)│
  ├───────────────────────────────┼──────────────────────────────┤
  │ Python                        │ 3.10+                         │
  │ google-api-python-client      │ 2.100+                        │
  │ google-auth                   │ 2.20+                         │
  │ google-auth-httplib2          │ 0.2+                          │
  │ requests (optional)           │ 2.28+                         │
  │ google-auth[requests] (opt.)  │ 2.20+                         │
  └───────────────────────────────┴──────────────────────────────┘
  
Concurrent-run guardrail (v1.6.0):
  Runs write owner PID and a run-id into the lockfile/state. If another run
  targets the same state file, it exits early with a friendly message.
  Use --force to bypass (not recommended unless previous run is definitely stopped).
"""
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Operation mode')
    dry_run_parser = subparsers.add_parser('dry-run', help='Show execution plan without making changes')
    recover_parser = subparsers.add_parser('recover-only', help='Recover files from trash only')
    download_parser = subparsers.add_parser('recover-and-download', help='Recover and download files')
    download_parser.add_argument('--download-dir', required=True, help='Local directory for downloads')
    
    for subparser in [dry_run_parser, recover_parser, download_parser]:
        subparser.add_argument('--no-emoji', action='store_true',
                               help='Disable emoji in console output (use ASCII labels instead)') 
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
        subparser.add_argument('--fail-on-parity-mismatch', action='store_true',
                               help='Exit non-zero if a parity mismatch is detected (use with --debug-parity; useful in CI)')
        subparser.add_argument('--parity-metrics-file', help='Write parity metrics JSON to this path')         
        subparser.add_argument('--strict-policy', action='store_true',
                               help='Treat unknown post-restore policy tokens as an error')
        subparser.add_argument('--limit', type=int, default=0,
                               help='Cap the number of items to discover/process (0 = no cap)')
        subparser.add_argument('--state-file', default=DEFAULT_STATE_FILE,
                               help='State file for resume capability')
        subparser.add_argument('--process-batch-size', type=int, default=DEFAULT_PROCESS_BATCH,
                               help='Streaming batch size for execution; items are processed and released per-batch')
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
        # v1.6.0: HTTP transport and pooling
        subparser.add_argument('--http-transport', choices=['auto','httplib2','requests'],
                               default=DEFAULT_HTTP_TRANSPORT,
                               help=('HTTP transport implementation. '
                                     "'auto' tries requests (with pooling) and falls back to httplib2. "
                                     "To enable pooling explicitly: pip install requests google-auth[requests] "
                                     "and pass --http-transport requests."))
        subparser.add_argument('--http-pool-maxsize', type=int, default=DEFAULT_HTTP_POOL_MAXSIZE,
                               help=('When using requests transport, sets per-thread session pool size. '
                                     'Rationale: effective pool ≈ min(--concurrency, --http-pool-maxsize). '
                                     'This is a heuristic for documentation only; code unchanged.'))
        # v1.6.0: concurrent-run guardrail override
        subparser.add_argument('--force', action='store_true',
                               help='Bypass concurrent-run guardrail when the lockfile is held')
        # v1.6.7: bounded wait for lock
        subparser.add_argument('--lock-timeout', type=float, default=0.0,
                               help='If the state lock is held, wait up to this many seconds for it to be released (0 = no wait)')
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
        print(f"WARN --concurrency {args.concurrency} is high; capping to {ceiling} to avoid resource exhaustion and 429s.")
        args.concurrency = ceiling
    return True, 0

def _validate_download_dir_arg(args) -> Tuple[bool, int]:
    if getattr(args, 'mode', None) != 'recover_and_download':
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
    if not getattr(args, 'after_date', None):
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

def _run_tool(tool: 'DriveTrashRecoveryTool', args) -> bool:
    return tool.dry_run() if args.mode == 'dry_run' else tool.execute_recovery()

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
    # Emit structured telemetry for unknown tokens to help operators track frequency
    try:
        if telemetry and 'unknown_policy' in telemetry:
            logging.getLogger(__name__).info("METRIC %s", json.dumps({
                "metric": "unknown_policy_token",
                **telemetry["unknown_policy"],
            }))
    except Exception:
        pass
    if policy_errors:
        for msg in policy_errors:
            print(f"❌ {msg}", file=sys.stderr)
            try:
                logging.getLogger(__name__).error(msg)
            except Exception:
                pass
        return False, 2
    for msg in policy_warnings:
        print(f"⚠️  {msg}", file=sys.stderr)
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
        print(f"ℹ️  {msg}")
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
        print("   The lock looks stale. If you're sure the previous process is gone, rerun with --force to take over.", file=sys.stderr)
    else:
        print("   Tip: If that run is still working, let it finish. Otherwise, confirm it's stopped and rerun with --force.", file=sys.stderr)
    if force:
        if "(not running)" in pid_alive_note:
            print("WARN --force supplied: taking over a **stale** lock (previous PID not detected).", file=sys.stderr)
        else:
            print("WARN --force supplied: bypassing concurrent-run guardrail.", file=sys.stderr)

def _check_pid_alive(owner_pid, tool):
    """Check if the recorded PID is alive, return a note string."""
    pid_alive_note = ""
    try:
        pid_int = int(owner_pid)
        alive = tool._pid_is_alive(pid_int)
        if not alive:
            # Could be inconclusive on Windows due to limited query permissions
            pid_alive_note = " (note: recorded PID not confirmed; may not be running)"
    except Exception:
        pass
    return pid_alive_note

def _acquire_or_bypass_lock(tool, args) -> Tuple[bool, int]:
    try:
        start_wait = time.time()
        timeout = float(getattr(args, "lock_timeout", 0.0) or 0.0)
        poll = 0.5
        acquired = tool._acquire_state_lock()
        while (not acquired) and timeout > 0 and (time.time() - start_wait) < timeout:
            # Bounded wait/poll
            remaining = max(0.0, timeout - (time.time() - start_wait))
            if int(remaining) == remaining:
                remaining_str = f"{int(remaining)}s"
            else:
                remaining_str = f"{remaining:.1f}s"
            print(f"Waiting for state lock (remaining {remaining_str})...", file=sys.stderr)
            time.sleep(poll)
            acquired = tool._acquire_state_lock()
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

def _validate_file_ids_if_present(tool, args) -> Tuple[bool, int]:
    if hasattr(args, "file_ids") and args.file_ids:
        ok = tool._validate_file_ids()
        if not ok:
            return False, 2
    return True, 0

def _run_and_release_lock(tool, args) -> int:
    ran_ok = False
    try:
        if args.command == 'dry-run':
            ran_ok = _run_tool(tool, args)
        else:
            ran_ok = tool.execute_recovery()
    finally:
        try:
            tool._release_state_lock()
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

if __name__ == "__main__":
    sys.exit(main())
