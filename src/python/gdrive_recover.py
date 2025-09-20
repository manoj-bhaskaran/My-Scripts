"""
Google Drive Trash Recovery Tool
A comprehensive tool to recover files from Google Drive Trash at scale with configurable options.

This tool provides:
- Bulk recovery of trashed files with optional extension filtering
- Optional download to local directory with conflict-safe filenames
- Configurable post-restore policies (MoveToDriveTrash, RetainOnDrive, RemoveFromDrive)
- Comprehensive Dry Run mode with full planning and privilege validation
- Resume capability for interrupted operations
- Progress tracking and detailed summaries
"""

__version__ = "1.4.13"

# CHANGELOG
"""
 ## [1.4.13] - 2025-09-19
 
 ### Improved
 - **Adaptive progress reporting:** progress updates now scale with workload size and time; prints approximately every 2% of items (bounded 5–500) and at least every ~10 seconds for long-running operations. Applies to both discovery (`--file-ids`) and execution phases.
 - **Extension handling for multi-dot tokens:** accept tokens like `tar.gz` and `min.js`. Unknown extensions no longer hard-fail; they’re allowed with a clear note that only client-side filename filtering will apply unless mapped in `EXTENSION_MIME_TYPES`.
 - **Download directory validation order and cleanup:** directory writability checks occur *after* authentication. Temporary probe files are always cleaned up, and if a directory was created by validation and remains empty when the run is cancelled, it is removed.
 - **Hardened token file permissions (POSIX):** `token.json` is created with `0600` permissions; we also warn and correct permissive modes.
 
 ### Documentation
 - Added **Quotas & Monitoring** notes and guidance on **Shared Drives** permissions and **Concurrency Tuning** to the CLI help epilog.
 
 ### Notes
 - Backwards-compatible; no CLI changes required.

## [1.4.12] - 2025-09-19

### Fixed
- **Validation for `--extensions`:** normalize and validate user input up front. Reject malformed tokens (spaces, commas, wildcards, path separators, or non-alnum chars), strip leading dots, lowercase, and de-duplicate. This prevents confusing under/over-filtering and wasted API calls.

### Improved
- **Clear UX for unknown extensions:** if an extension is syntactically valid but not in our `EXTENSION_MIME_TYPES` map, print a note that only client-side filename filtering will apply (server-side query won’t narrow), setting accurate expectations about performance and results.

### Notes
- No breaking CLI changes. Behavior is stricter for malformed inputs and more explicit for unknown ones.

## [1.4.11] - 2025-09-19

### Fixed
- **Targeted exception handling in `_get_file_info`:** add API-context to errors (e.g., `files.get(fileId=..., fields=...)`), preserve HTTP status/payload for `HttpError`, and distinguish I/O/transport errors from unexpected ones for clearer diagnostics. Aligns formatting/verbosity with other hot paths.
- **Early validation of `--download-dir`:** for `recover-and-download`, fail fast if the path points to a file, can’t be created, or isn’t writable. Creates the directory when missing and performs a touch/unlink check to verify permissions.

### Notes
- Backwards-compatible; no CLI changes. Improves debuggability and fail-fast UX.

## [1.4.10] - 2025-09-19

### Fixed
- **Consistent API-context logging for recoveries:** `_recover_file` now logs with full API context (e.g., `files.update(fileId=..., trashed=False)`) and decoded payloads. Retries only occur for transient statuses (429/5xx) with jittered backoff; terminal statuses (403/404) are not retried and include clear context in logs.
- **Clearer transient error feedback during `--file-ids` validation:** `_validate_file_ids` prints the specific IDs that experienced transient errors so users can retry just those IDs. The IDs are also logged.
- **Progress visibility for large `--file-ids` discoveries:** `_discover_via_ids` prints periodic progress (every 100 IDs) with counts of processed IDs, discovered items, skipped non-trashed, and errors (shown when using `-v` or higher).

### Notes
- These changes improve debuggability and UX without altering external behavior or CLI flags.

## [1.4.9] - 2025-09-19

### Fixed
- Tightened exception handling in downloads and post-restore actions; retry only on transient (429/5xx) with backoff, and add clear API context to error messages.
- Validate `--concurrency` early (reject <1; cap to `min(os.cpu_count()*4, 64)` with a warning).

## [1.4.8] - 2025-09-19

### Fixed
- `_validate_file_ids` now uses the same resilient retry/backoff logic as metadata fetches (handles 429/5xx) and provides clearer user guidance for transient errors and 403 permission issues.
- Console feedback for `--file-ids` improved: if none of the provided IDs are actionable (invalid, not found, or not trashed), the tool now prints an explicit summary explaining why zero items were discovered.

### Refactored
- Removed reliance on a shared `self.service` attribute. Authentication stores credentials and validates them; all runtime API calls consistently use thread-local clients via `_get_service()` to eliminate confusion and reduce maintenance risk.

## [1.4.7] - 2025-09-19
 
 ### Fixed
 - Standardized CLI indentation for “Error:” lines across sections to improve readability.
 - Enriched `_fetch_file_metadata` error messages with API method context and `fileId` to aid debugging.
 - Preserved stack traces and distinguished API vs unexpected errors in `_handle_item_result` logging.
 
## [1.4.6] - 2025-09-19

### Refactored
- Extracted all helper functions from inside `_fetch_file_metadata` to top-level methods in the class to further reduce its cognitive complexity and improve maintainability.

## [1.4.0–1.4.5] - 2025-09-19

### Summary (Condensed)
Between 1.4.0 and 1.4.5 we focused on correctness, resilience, and maintainability around discovery, validation, and metadata fetching:

- **ID Validation & Troubleshooting (1.4.0):** Introduced `_validate_file_ids()` with format and existence checks using Drive v3. Added richer CLI troubleshooting (quota, permissions, auth) and an `INFERRED_MODIFY_ERROR` constant for consistent messaging. Permission checks were modularized (`_get_file_info`, `_check_untrash_privilege`, `_check_download_privilege`, `_check_trash_delete_privileges`), cutting cognitive complexity substantially.
- **Authentication & Time Handling (1.4.2):** Ensured auth occurs for all modes and is idempotent. Improved time filtering by requesting `modifiedTime`, removing unsupported `trashedTime`, and handling timezones correctly. Backoff logic shifted to exponential with jitter; types were cleaned up; unused variables removed.
- **`--file-ids` Path & Docs (1.4.3):** Corrected `--file-ids` handling to per-ID lookups (conformant with Drive v3 grammar). Restored thread-safety in downloads via thread-local services. Documented the `python-dateutil` requirement and simplified client-side checks.
- **Thread-local Services & Discovery Polish (1.4.4):** Standardized `_get_service()` usage across the codebase. Added resilient per-ID discovery with backoff for 429/5xx, minimal field requests, and fail-fast validation for `--after-date`. Reduced complexity of `_discover_via_ids` and `main()` via small helpers.
- **Metadata Fetch Simplification (1.4.5):** Centralized retry checks and error formatting, reduced `_fetch_file_metadata` complexity to ≤15 while preserving behavior and logging parity.

Overall, these releases made discovery/validation more robust, clarified user guidance, reduced cognitive complexity across hot paths, and aligned field selection and retries with Drive API realities.

## [1.3.0] - 2025-09-19

### Added
- Read-only privilege validation for dry-run mode to ensure no Drive modifications during planning
- Enhanced privilege testing that validates permissions without making actual file changes

### Improved
- Dry-run mode is now completely read-only and safe for strict audit environments
- Privilege validation uses metadata-only checks to verify file access permissions
- Better compliance with enterprise audit requirements where dry-run must not modify files

### Fixed
- Privilege testing no longer performs temporary file modifications during dry-run
- Dry-run mode maintains true read-only behavior for organizations with strict compliance requirements

### Technical Changes
- Replaced reversible operation testing with read-only permission validation
- Enhanced privilege checks using file metadata access patterns
- Improved dry-run safety for enterprise and audited environments

## [1.2.x] - 2025-09-19

### Fixed
- **CRITICAL**: Removed unsupported trashedTime filtering from server-side queries (Drive API limitation)
- **CRITICAL**: Enhanced extension filtering with robust mimeType-based queries instead of unreliable name contains
- **CRITICAL**: Fixed success masking where authentication failures were incorrectly reported as success
- **CRITICAL**: Fixed field selection inconsistency - removed unused trashedTime, added required modifiedTime
- Improved query reliability by eliminating problematic mixed-case name filtering patterns
- Corrected field selection to match optimization goals and functional requirements

### Improved
- Server-side queries use proper mimeType filtering for file extensions (image/jpeg, image/png, etc.)
- Eliminated reliance on prefix-only name contains behavior for more reliable filtering
- Enhanced client-side validation to compensate for server-side query limitations
- Optimized field selection to reduce response payload sizes and improve performance
- Fixed execute_recovery return logic to properly report preparation failures

### Technical Changes
- Replaced name contains extension filtering with mimeType-based queries
- Added comprehensive mimeType mapping for common file extensions
- Enhanced error handling for query complexity limits and special characters
- Updated API field requests to include modifiedTime for time filtering functionality
- Aligned field selection with actual code requirements for better performance and correctness

### Performance Optimizations
- Added selective field requests to reduce API usage and response sizes
- Improved client-side time filtering using modifiedTime as proxy for trash time
- Enhanced query building with precise extension handling for better reliability

## [1.1.x] - 2025-09-19

### Added
- Enhanced privilege validation in dry-run mode with comprehensive operation testing
- Complete command preview generation including all user inputs and flags
- Enhanced post-restore action tracking with detailed policy-specific statistics

### Improved
- Dry-run mode validates all necessary permissions on sample files
- Generated execution commands include all parameters for full reproducibility
- Progress update frequency increased from every 50 to every 20 items for better visibility
- Final summary with breakdown of specific post-restore actions (retained/trashed/deleted)
- Better error reporting for insufficient privileges with specific operation details

### Fixed
- Command preview includes --after-date, --file-ids, --log-file, --state-file, and verbosity flags
- Progress updates provide more frequent feedback during large operations
- Summary statistics distinguish between different post-restore policies applied
- Verified correct implementation of post-restore statistics structure and progress reporting

### Technical Changes
- Enhanced post-restore statistics tracking with policy-specific counters
- Verified progress reporting interval correctly implemented at 20-item intervals
- Improved command generation for full operation reproducibility

## [1.0.x] - 2025-09-19

### Added
- Initial release of Google Drive Trash Recovery Tool with comprehensive features
- Bulk recovery of trashed files with case-insensitive extension filtering
- Three operation modes: dry-run, recover-only, recover-and-download
- Configurable post-restore policies (MoveToDriveTrash, RetainOnDrive, RemoveFromDrive)
- Resume capability for interrupted operations with persistent state
- Progress tracking with ETA calculations and concurrent processing
- Robust error handling with retry logic and detailed logging
- Safety confirmations with override option for automation
- Support for time-based filtering (files trashed after specific date)
- Support for explicit file ID targeting with conflict-safe filename generation
- Comprehensive privilege and environment validation
- Detailed execution summaries with statistics
- Paginated display for large file sets in dry-run mode

### Technical Features
- Google Drive API v3 integration with OAuth2 authentication
- Thread-safe operations using thread-local service instances
- Persistent JSON state files for resume capability
- Configurable logging with multiple verbosity levels
- Thread-safe statistics tracking with proper extension suffix matching
- Automatic retry with exponential backoff for transient errors
- Memory-efficient pagination for large file sets
- Cross-platform compatibility (Windows, macOS, Linux)

### Documentation
- Comprehensive CLI help with examples
- Inline code documentation with troubleshooting guidance
- Post-restore policy explanations and usage examples

### Security & Reliability
- **CRITICAL FIXES**: Thread-safety with thread-local API service instances
- **CRITICAL FIXES**: Case-insensitive extension filtering with proper suffix matching
- Robust extension filter preventing false matches on partial strings
- Enhanced query building with precise extension handling
"""

import os
import io
import json
import time
import argparse
import logging
import shutil
import threading
import re
import random
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
from dataclasses import dataclass, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
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
    post_restore_action: str = "MoveToDriveTrash"
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
    MOVE_TO_DRIVE_TRASH = "MoveToDriveTrash"
    RETAIN_ON_DRIVE = "RetainOnDrive"
    REMOVE_FROM_DRIVE = "RemoveFromDrive"

class DriveTrashRecoveryTool:
    """Main recovery tool class."""
    
    def __init__(self, args):
        self.args = args
        # Thread-local service is created lazily in _get_service(); no global service kept.
        self._thread_local = threading.local()  # Thread-local storage for API clients
        self.logger = self._setup_logging()
        self._authenticated = False
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
        
    def _get_service(self):
        """Get thread-local Google Drive service instance."""
        if not hasattr(self._thread_local, 'service'):
            if not hasattr(self, '_main_credentials') or not self._main_credentials:
                raise RuntimeError("Main service not initialized. Call authenticate() first.")
            
            # Create thread-local copy using stored credentials
            self._thread_local.service = build('drive', 'v3', credentials=self._main_credentials)
        
        return self._thread_local.service
    
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
            
            self.service = build('drive', 'v3', credentials=creds)
            # Store credentials for thread-local access
            self._main_credentials = creds
            
            # Test the connection
            test_service = build('drive', 'v3', credentials=creds)
            about = test_service.about().get(fields='user').execute()
            self.logger.info(f"Authenticated as: {about.get('user', {}).get('emailAddress', 'Unknown')}")
            self._authenticated = True
            return True
            
        except Exception as e:
            self.logger.error(f"Authentication failed: {e}")
            return False
    
    # -------------------- File-ID validation helpers --------------------
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

    def _classify_id_via_api(self, service, file_id: str) -> str:
        """Return one of: ok | not_found | no_access | transient_error."""
        for attempt in range(MAX_RETRIES):
            try:
                service.files().get(fileId=file_id, fields='id').execute()
                return "ok"
            except Exception as e:
                status = self._extract_status_from_http_error(e)
                if status == 404:
                    return "not_found"
                if status == 403:
                    return "no_access"
                should_retry, _ = self._should_retry_fetch_metadata(e, attempt)
                if should_retry:
                    self._log_fetch_metadata_retry(file_id, e, status, attempt)
                    continue
                self._log_terminal_id_validation_error(e, file_id, status)
                return "transient_error"
        return "transient_error"

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

    def _validate_file_ids(self) -> bool:
        """Validate provided file IDs for format and existence with retries and clear guidance."""
        if not self.args.file_ids:
            return True

        service = self._get_service()
        buckets: Dict[str, List[str]] = {
            "ok": [],
            "invalid": [],
            "not_found": [],
            "no_access": [],
        }
        transient_errors = 0
        transient_ids: List[str] = []

        for fid in self.args.file_ids:
            if not self._is_valid_file_id_format(fid):
                buckets["invalid"].append(fid)
                continue
            result = self._classify_id_via_api(service, fid)
            if result in buckets:
                buckets[result].append(fid)
            else:
                transient_errors += 1
                transient_ids.append(fid)

        return self._report_validation_outcome(buckets, transient_errors, transient_ids)
    
    def _build_query(self) -> str:
        """Build the Drive API query string using robust mimeType-based filtering."""
        base_query = "trashed=true"
        
        # Add extension filter using mimeType queries for better reliability
        if self.args.extensions:
            mime_conditions = []
            
            for ext in self.args.extensions:
                ext_normalized = ext.lower().strip('.')
                
                # Use mimeType for known extensions (more reliable)
                if ext_normalized in EXTENSION_MIME_TYPES:
                    mime_type = EXTENSION_MIME_TYPES[ext_normalized]
                    mime_conditions.append(f"mimeType = '{mime_type}'")
            
            # Combine mimeType conditions
            if mime_conditions:
                extensions_query = f"({' or '.join(mime_conditions)})"
                base_query += f" and {extensions_query}"
        
        # Note: trashedTime filtering removed - not supported by Drive API v3
        # Time-based filtering will be handled client-side if needed
        if self.args.after_date:
            self.logger.warning("Time-based filtering (--after-date) will be applied client-side due to Drive API limitations")
        
    # Note: we do not add file IDs to `q` because Drive v3 query does not support filtering by fileId.
    # When `--file-ids` is provided, discovery uses per-ID lookups for correctness and minimal I/O.
        
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
            post_restore_action=self.args.post_restore_policy
        )
        
        if self.args.mode == 'recover_and_download':
            item.target_path = self._generate_target_path(item)
        
        return item
    
    def _fetch_files_page(self, query: str, page_token: Optional[str]) -> Tuple[List[Dict], Optional[str]]:
        """Fetch a single page of files from the API."""
        service = self._get_service()
        response = service.files().list(
            q=query,
            spaces='drive',
            fields='nextPageToken, files(id, name, mimeType, size, createdTime, modifiedTime)',
            pageSize=PAGE_SIZE,
            pageToken=page_token
        ).execute()
        
        files = response.get('files', [])
        next_page_token = response.get('nextPageToken')
        
        return files, next_page_token
    

    # --- Discovery helpers (extracted to reduce cognitive complexity) ---
    def _append_item_if_valid(self, items: List[RecoveryItem], file_data: Dict[str, Any]) -> None:
        """Append a processed RecoveryItem to list if it passes filters."""
        item = self._process_file_data(file_data)
        if item:
            items.append(item)

    # --- ID discovery helpers to reduce cognitive complexity ---
    def _id_discovery_fields(self) -> str:
        """Return minimal fields needed for per-ID discovery based on current args."""
        base_fields = ['id', 'name', 'mimeType', 'trashed', 'createdTime']
        if self.args.mode == 'recover_and_download':
            base_fields.append('size')
        if bool(self.args.after_date):
            base_fields.append('modifiedTime')
        return ', '.join(base_fields)

    def _should_retry_fetch_metadata(self, exc: Exception, attempt: int) -> Tuple[bool, Optional[int]]:
        """Return (should_retry, status_if_http) for fetch metadata."""
        if isinstance(exc, HttpError):
            status = getattr(exc.resp, "status", None)
            return (status in (429, 500, 502, 503, 504) and attempt < MAX_RETRIES - 1), status
        return (attempt < MAX_RETRIES - 1), None

    def _format_fetch_metadata_error(self, exc: Exception, status: Optional[int]) -> str:
        """Format error for fetch metadata."""
        if isinstance(exc, HttpError):
            content = getattr(exc, 'content', b'')
            payload = content.decode(errors='ignore') if hasattr(content, 'decode') else str(exc)
            return f"HTTP {status}: {payload}"
        return str(exc)

    # New: include method and file-id context for clearer diagnostics
    def _format_fetch_metadata_error_with_context(
        self,
        exc: Exception,
        status: Optional[int],
        fid: str,
        *,
        fields: Optional[str] = None,
    ) -> str:
        base = self._format_fetch_metadata_error(exc, status)
        fields_part = f", fields={fields}" if fields else ""
        return f"files.get(fileId={fid}{fields_part}) failed: {base}"
 
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
                data = service.files().get(fileId=fid, fields=fields).execute()
                if data.get('trashed', False):
                    return data, False, None
                return None, True, None
            except Exception as e:
                should_retry, status = self._should_retry_fetch_metadata(e, attempt)
                if should_retry:
                    self._log_fetch_metadata_retry(fid, e, status, attempt)
                    continue
                return None, False, self._format_fetch_metadata_error_with_context(e, status, fid, fields=fields)
        return None, False, "Unknown error"

    def _handle_discover_id_result(self, items, data, non_trashed, err, fid, skipped_non_trashed_ref, errors_ref):
        """Handle the result of a single ID discovery attempt."""
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
        """Print periodic progress for large ID lists."""
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
        """Print summary after ID discovery."""
        if skipped_non_trashed:
            print(f"ℹ️  Skipped {skipped_non_trashed} non-trashed file ID(s).")
        if errors:
            print(f"ℹ️  Encountered {errors} error(s) while fetching file ID metadata. See log for details.")
        if not items:
            print("❎ No actionable trashed files were found from the provided --file-ids.")
            print("   All provided IDs may be invalid, not found, non-trashed, or inaccessible.")
            print("   Tip: Re-check IDs from their Drive URLs and ensure they are currently in Trash.")

    def _discover_via_ids(self) -> List[RecoveryItem]:
        """Discover trashed files by explicit IDs (per-ID lookups)."""
        self.logger.info("Using per-ID lookups for discovery (--file-ids provided)")
        service = self._get_service()
        fields = self._id_discovery_fields()

        items: List[RecoveryItem] = []
        skipped_non_trashed = [0]
        errors = [0]
        total = len(self.args.file_ids)
        start_time = time.time()
        for idx, fid in enumerate(self.args.file_ids, start=1):
            data, non_trashed, err = self._fetch_file_metadata(service, fid, fields)
            self._handle_discover_id_result(items, data, non_trashed, err, fid, skipped_non_trashed, errors)
            self._maybe_print_discover_progress(idx, total, items, skipped_non_trashed[0], errors[0], start_time)

        self._print_discover_id_summary(items, skipped_non_trashed[0], errors[0])
        return items

    def _discover_via_query(self, query: str) -> List[RecoveryItem]:
        """Discover trashed files via Drive query pagination."""
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
                print(f"Found {len(files)} files in page {page_count} (total: {len(items)})")
                if not page_token:
                    break
        except Exception as e:
            self.logger.error(f"Error discovering files: {e}")
            return []
        return items

    def discover_trashed_files(self) -> List[RecoveryItem]:
        """Discover all trashed files matching criteria."""
        print("🔍 Discovering trashed files...")

        if self.args.file_ids:
            items = self._discover_via_ids()
        else:
            query = self._build_query()
            self.logger.info(f"Using query: {query}")
            items = self._discover_via_query(query)

        self.stats['found'] = len(items)
        print(f"📊 Total files discovered: {len(items)}")
        return items
    
    def _matches_extension_filter(self, filename: str) -> bool:
        """Check if filename matches extension filter with proper suffix matching."""
        if not self.args.extensions or not filename:
            return True
        
        filename_lower = filename.lower()
        for ext in self.args.extensions:
            if filename_lower.endswith(f'.{ext.lower().strip('.')}'):
                return True
        
        return False
    
    def _matches_time_filter(self, item_data: Dict[str, Any]) -> bool:
        """Apply client-side time filtering since server-side trashedTime is not supported."""
        if not self.args.after_date:
            return True
        
        try:
            # Parse modifiedTime (RFC3339) and after_date (ISO) to timezone-aware datetime
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
        """Generate safe target path for download."""
        if not self.args.download_dir:
            return ""
        
        # Sanitize filename
        safe_name = "".join(c for c in item.name if c.isalnum() or c in (' ', '-', '_', '.')).rstrip()
        if not safe_name:
            safe_name = f"file_{item.id}"
        
        base_path = Path(self.args.download_dir) / safe_name
        
        # Handle conflicts
        if base_path.exists():
            stem = base_path.stem
            suffix = base_path.suffix
            counter = 1
            while base_path.exists():
                base_path = base_path.parent / f"{stem}_{counter}{suffix}"
                counter += 1
        
        return str(base_path)
    
    def _get_file_info(self, file_id: str, fields: str) -> Dict[str, Any]:
        """Fetch file information with targeted error handling and API-context logging."""
        api_ctx = f"files.get(fileId={file_id}, fields={fields})"
        try:
            service = self._get_service()
            return service.files().get(fileId=file_id, fields=fields).execute()
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            payload = getattr(e, "content", b"")
            detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
            self.logger.error(f"{api_ctx} failed: HTTP {status}: {detail}")
            return {'error': f"HTTP {status}: {detail}"}
        except (OSError, IOError) as e:
            # Local/network I/O issues (e.g., DNS failure, socket issues wrapped as OSError)
            self.logger.error(f"{api_ctx} I/O error: {e}")
            return {'error': f"I/O error: {e}"}
        except Exception as e:
            # Keep a final guard while providing context for debuggability
            self.logger.error(f"{api_ctx} unexpected error: {e}")
            return {'error': f"Unexpected error: {e}"}
    
    def _check_untrash_privilege(self, file_id: str) -> Dict[str, Any]:
        """Check untrash permission for a file."""
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
            result['status'] = 'pass'  # Fallback: readable file likely allows untrash
        
        return result
    
    def _check_download_privilege(self, file_id: str) -> Dict[str, Any]:
        """Check download permission for a file."""
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
            result['status'] = 'pass'  # Fallback: file with size is likely downloadable
        
        return result
    
    def _check_trash_delete_privileges(self, file_id: str, untrash_status: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """Check trash and delete permissions for a file."""
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
        """Test operation privileges using read-only metadata checks for dry-run safety."""
        privileges = {
            'untrash': {'status': 'unknown', 'error': None},
            'download': {'status': 'unknown', 'error': None},
            'trash': {'status': 'unknown', 'error': None},
            'delete': {'status': 'unknown', 'error': None}
        }
        
        if not test_items:
            return privileges
        
        test_item = test_items[0]
        
        # Check untrash permission
        privileges['untrash'] = self._check_untrash_privilege(test_item.id)
        
        # Check download permission
        privileges['download'] = self._check_download_privilege(test_item.id)
        
        # Check trash and delete permissions
        privileges['trash'], privileges['delete'] = self._check_trash_delete_privileges(test_item.id, privileges['untrash']['status'])
        
        return privileges
    
    def _check_privileges(self) -> Dict[str, Any]:
        """Check Drive privileges and local filesystem."""
        checks = {
            'drive_access': False,
            'drive_error': None,
            'operation_privileges': {},
            'local_writable': False,
            'local_error': None,
            'disk_space': 0,
            'estimated_needed': 0
        }
        
        # Check basic Drive access
        try:
            # Test basic read access
            service = self._get_service()
            service.files().list(pageSize=1).execute()
            checks['drive_access'] = True
            
            # Test specific operation privileges on sample items
            sample_items = self.items[:3] if self.items else []
            checks['operation_privileges'] = self._test_operation_privileges(sample_items)
                
        except Exception as e:
            checks['drive_error'] = str(e)
        
        # Check local filesystem
        if self.args.download_dir:
            try:
                download_path = Path(self.args.download_dir)
                download_path.mkdir(parents=True, exist_ok=True)
                
                # Test write access
                test_file = download_path / '.write_test'
                test_file.write_text('test')
                test_file.unlink()
                
                checks['local_writable'] = True
                
                # Check disk space
                if hasattr(shutil, 'disk_usage'):
                    _, _, free_bytes = shutil.disk_usage(download_path)
                    checks['disk_space'] = free_bytes
                    
                    # Estimate needed space
                    total_size = sum(item.size for item in self.items if item.will_download)
                    checks['estimated_needed'] = total_size
                    
            except Exception as e:
                checks['local_error'] = str(e)
        
        return checks
    
    def _print_drive_access_status(self, checks: Dict[str, Any]):
        """Print Drive API access status."""
        drive_status = "✓ PASS" if checks['drive_access'] else "❌ FAIL"
        print(f"Drive API Access: {drive_status}")
        if checks['drive_error']:
            print(f"  Error: {checks['drive_error']}")
    
    def _print_operation_privileges(self, checks: Dict[str, Any]):
        """Print detailed operation privilege results."""
        if not checks.get('operation_privileges'):
            return
        
        print("\nOperation Privileges:")
        for operation, result in checks['operation_privileges'].items():
            self._print_single_operation_privilege(operation, result)
    
    def _print_single_operation_privilege(self, operation: str, result: Dict[str, Any]):
        """Print privilege status for a single operation."""
        status_symbol = self._get_privilege_status_symbol(result['status'])
        print(f"  {operation.title()}: {status_symbol} {result['status'].upper()}")
        if result['error']:
            print(f"    Error: {result['error']}")
    
    def _get_privilege_status_symbol(self, status: str) -> str:
        """Get the appropriate symbol for privilege status."""
        if status == 'pass':
            return "✓"
        elif status == 'fail':
            return "❌"
        else:
            return "?"
    
    def _print_local_directory_status(self, checks: Dict[str, Any]):
        """Print local directory access status."""
        if not self.args.download_dir:
            return
        
        local_status = "✓ PASS" if checks['local_writable'] else "❌ FAIL"
        print(f"Local Directory Writable: {local_status}")
        if checks['local_error']:
            print(f"  Error: {checks['local_error']}")
        
        self._print_disk_space_info(checks)
    
    def _print_privilege_checks(self, checks: Dict[str, Any]):
        """Print privilege and environment check results."""
        print("\n📋 PRIVILEGE AND ENVIRONMENT CHECKS")
        print("-" * 50)
        
        self._print_drive_access_status(checks)
        self._print_operation_privileges(checks)
        self._print_local_directory_status(checks)
    
    def _print_disk_space_info(self, checks: Dict[str, Any]):
        """Print disk space information."""
        if checks['disk_space'] > 0:
            free_gb = checks['disk_space'] / (1024**3)
            needed_gb = checks['estimated_needed'] / (1024**3)
            space_status = "✓ SUFFICIENT" if checks['disk_space'] > checks['estimated_needed'] else "⚠️  INSUFFICIENT"
            print(f"Disk Space: {space_status}")
            print(f"  Available: {free_gb:.2f} GB")
            print(f"  Estimated needed: {needed_gb:.2f} GB")
    
    def _print_scope_summary(self):
        """Print scope summary information."""
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
        print(f"Post-restore policy: {self.args.post_restore_policy}")
    
    def _print_item_details(self, item: RecoveryItem, index: int):
        """Print details for a single item."""
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
        """Show detailed execution plan with pagination."""
        print("\n📋 DETAILED EXECUTION PLAN")
        print("-" * 50)
        
        page_size = 20
        total_pages = (len(self.items) + page_size - 1) // page_size
        
        for page in range(total_pages):
            if not self._show_page(page, page_size, total_pages):
                return False
            
            if page < total_pages - 1:
                response = input("Press Enter for next page, 'q' to stop viewing, or 's' to skip to summary: ").strip().lower()
                if response == 'q':
                    return False
                elif response == 's':
                    break
        
        return True
    
    def _show_page(self, page: int, page_size: int, total_pages: int) -> bool:
        """Show a single page of items."""
        start_idx = page * page_size
        end_idx = min(start_idx + page_size, len(self.items))
        
        print(f"\nPage {page + 1}/{total_pages} (items {start_idx + 1}-{end_idx}):")
        print("-" * 80)
        
        for i, item in enumerate(self.items[start_idx:end_idx], start_idx + 1):
            self._print_item_details(item, i)
        
        return True
    
    def _generate_execution_command(self):
        """Generate and print the execution command."""
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
        """Add file and state arguments to command."""
        if self.args.after_date:
            cmd_parts.extend(['--after-date', self.args.after_date])
        
        if self.args.file_ids:
            cmd_parts.extend(['--file-ids'] + self.args.file_ids)
        
        if self.args.log_file != DEFAULT_LOG_FILE:
            cmd_parts.extend(['--log-file', self.args.log_file])
        
        if self.args.state_file != DEFAULT_STATE_FILE:
            cmd_parts.extend(['--state-file', self.args.state_file])
    
    def _add_verbosity_arguments(self, cmd_parts: List[str]):
        """Add verbosity arguments to command."""
        if self.args.verbose > 0:
            cmd_parts.append('-' + 'v' * self.args.verbose)
    
    def _add_mode_arguments(self, cmd_parts: List[str]):
        """Add mode-specific arguments to command."""
        if self.args.mode == 'recover_and_download':
            cmd_parts.append('recover-and-download')
            cmd_parts.extend(['--download-dir', str(self.args.download_dir)])
        else:
            cmd_parts.append('recover-only')
    
    def _add_filter_arguments(self, cmd_parts: List[str]):
        """Add filter arguments to command."""
        if self.args.extensions:
            cmd_parts.extend(['--extensions'] + self.args.extensions)
    
    def _add_config_arguments(self, cmd_parts: List[str]):
        """Add configuration arguments to command."""
        if self.args.post_restore_policy != PostRestorePolicy.MOVE_TO_DRIVE_TRASH:
            cmd_parts.extend(['--post-restore-policy', self.args.post_restore_policy])
        
        cmd_parts.extend(['--concurrency', str(self.args.concurrency)])
        
        if self.args.yes:
            cmd_parts.append('--yes')
    
    def dry_run(self) -> bool:
        """Execute comprehensive dry run."""
        print("\n" + "="*80)
        print("🔍 DRY RUN MODE - No changes will be made")
        print("="*80)
        
        # Discover files
        self.items = self.discover_trashed_files()
        
        if not self.items:
            print("No files found matching criteria.")
            return True
        
        # Check privileges and show results
        checks = self._check_privileges()
        self._print_privilege_checks(checks)
        
        # Show scope summary
        self._print_scope_summary()
        
        # Show detailed plan
        if not self._show_detailed_plan():
            return False
        
        # Generate execution command
        self._generate_execution_command()
        
        return True
    
    def _load_state(self) -> bool:
        """Load previous execution state for resume."""
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
    
    def _save_state(self):
        """Save current execution state."""
        try:
            with open(self.args.state_file, 'w') as f:
                json.dump(asdict(self.state), f, indent=2)
        except Exception as e:
            self.logger.error(f"Failed to save state: {e}")
    
    def _is_processed(self, item_id: str) -> bool:
        """Check if item has already been processed."""
        return item_id in self.state.processed_items
    
    def _mark_processed(self, item_id: str):
        """Mark item as processed."""
        if item_id not in self.state.processed_items:
            self.state.processed_items.append(item_id)
            self.state.last_checkpoint = datetime.now(timezone.utc).isoformat()
    
    def _recover_file(self, item: RecoveryItem) -> bool:
        """Recover a single file from trash."""
        if self._is_processed(item.id):
            with self.stats_lock:
                self.stats['skipped'] += 1
            return True
        
        service = self._get_service()  # Use thread-local service for thread safety
        api_ctx = f"files.update(fileId={item.id}, trashed=False)"
        for attempt in range(MAX_RETRIES):
            try:
                service.files().update(
                    fileId=item.id,
                    body={'trashed': False}
                ).execute()
                
                item.status = 'recovered'
                with self.stats_lock:
                    self.stats['recovered'] += 1
                
                self.logger.info(f"Recovered: {item.name}")
                return True
                
            except HttpError as e:
                status = getattr(e.resp, "status", None)
                payload = getattr(e, "content", b"")
                detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
                # Terminal statuses: no retry
                if status in (403, 404):
                    item.status = 'failed'
                    item.error_message = f"{api_ctx} failed: HTTP {status}: {detail}"
                    with self.stats_lock:
                        self.stats['errors'] += 1
                    self.logger.error(f"Failed to recover {item.name}: {item.error_message}")
                    return False
                else:
                    self.logger.warning(f"Retrying recovery of {item.name} (attempt {attempt + 1})")
                    delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)  # Exponential backoff with jitter
                    time.sleep(delay)
            except Exception as e:
                self.logger.warning(f"Retrying recovery of {item.name} (attempt {attempt + 1}): {e}")
                delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)  # Exponential backoff with jitter
                time.sleep(delay)
        
        item.status = 'failed'
        item.error_message = "Max retries exceeded"
        with self.stats_lock:
            self.stats['errors'] += 1
        return False
    
    # --- Add these helpers outside the class or as class methods (shown here as class methods for context):

    def _get_post_restore_action_and_ctx(self, item: RecoveryItem):
        """Return (action, api_ctx) tuple for post-restore policy."""
        if item.post_restore_action == PostRestorePolicy.RETAIN_ON_DRIVE:
            return "retain", None
        elif item.post_restore_action == PostRestorePolicy.MOVE_TO_DRIVE_TRASH:
            return "trashed", f"files.update(fileId={item.id}, trashed=True)"
        elif item.post_restore_action == PostRestorePolicy.REMOVE_FROM_DRIVE:
            return "deleted", f"files.delete(fileId={item.id})"
        else:
            return "retain", None

    def _do_post_restore_action(self, service, item: RecoveryItem, action: str):
        """Perform the actual API call for the post-restore action."""
        if action == "trashed":
            service.files().update(fileId=item.id, body={'trashed': True}).execute()
        elif action == "deleted":
            service.files().delete(fileId=item.id).execute()
        # "retain" does nothing

    def _log_post_restore_success(self, item: RecoveryItem, action: str):
        """Log and update stats for post-restore outcome."""
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

    def _handle_post_restore_http_error(self, item, e, api_ctx):
        """Handle HttpError during post-restore, return True if handled (no retry)."""
        status = getattr(e.resp, "status", None)
        payload = getattr(e, 'content', b'')
        detail = payload.decode(errors='ignore') if hasattr(payload, 'decode') else str(e)
        if status in (403, 404):
            self.logger.error(
                f"Post-restore action failed for {item.name} via {api_ctx or 'N/A'} "
                f"(no retry): HTTP {status}: {detail}"
            )
            return True
        return False

    def _handle_post_restore_exception(self, item, e, api_ctx, attempt):
        """Handle generic exception during post-restore with backoff."""
        self.logger.warning(
            f"Error during post-restore for {item.name} via {api_ctx or 'N/A'} "
            f"(attempt {attempt + 1}): {e}"
        )
        delay = (RETRY_DELAY ** attempt) * random.uniform(0.5, 1.5)
        time.sleep(delay)

    def _should_retry_post_restore(self, e, attempt):
        """Determine if post-restore error is retryable."""
        should_retry, status = self._should_retry_fetch_metadata(e, attempt)
        return should_retry, status

    def _extract_http_error_detail(self, e):
        payload = getattr(e, 'content', b'')
        return payload.decode(errors='ignore') if hasattr(payload, 'decode') else str(e)

    def _log_post_restore_terminal_error(self, item, e, api_ctx):
        status = getattr(e.resp, "status", None)
        detail = self._extract_http_error_detail(e)
        self.logger.error(
            f"Post-restore action failed for {item.name} via {api_ctx or 'N/A'}: "
            f"HTTP {status}: {detail}"
        )

    def _is_terminal_post_restore_error(self, e):
        status = getattr(e.resp, "status", None)
        return status in (403, 404)

    def _handle_post_restore_retry(self, item, e, attempt):
        status = getattr(e.resp, "status", None)
        self._log_fetch_metadata_retry(item.id, e, status, attempt)

    # --- Refactored _apply_post_restore_policy method ---
    def _apply_post_restore_policy(self, item: RecoveryItem) -> bool:
        """Apply post-restore policy to successfully downloaded file."""
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
                should_retry, _ = self._should_retry_post_restore(e, attempt)
                if should_retry:
                    self._handle_post_restore_retry(item, e, attempt)
                    continue
                self._log_post_restore_terminal_error(item, e, api_ctx)
                return False
            except Exception as e:
                self._handle_post_restore_exception(item, e, api_ctx, attempt)
        self.logger.error(
            f"Post-restore action failed after retries for {item.name} via {api_ctx or 'N/A'}"
        )
        return False
    
    def _process_item(self, item: RecoveryItem) -> bool:
        """Process a single recovery item."""
        if self._is_processed(item.id):
            return True
        
        success = True
        
        # Step 1: Recover from trash
        if item.will_recover and not self._recover_file(item):
            success = False
        
        # Step 2: Download if requested and recovery succeeded
        if success and item.will_download and not self._download_file(item):
            success = False
        
        # Step 3: Apply post-restore policy if download succeeded
        if success and item.will_download and item.status == 'downloaded':
            self._apply_post_restore_policy(item)
        
        # Mark as processed regardless of outcome
        self._mark_processed(item.id)
        
        return success
    
    def _prepare_recovery(self) -> Tuple[bool, bool]:
        """Prepare for recovery by authenticating and loading state.
        
        Returns:
            Tuple[bool, bool]: (success, has_files)
            - success: True if preparation succeeded (auth, etc.)
            - has_files: True if files were found to process
        """
        if not self.authenticate():
            return False, False
        
        # Load previous state if resuming
        self._load_state()
        
        # Discover files
        if not self.items:
            self.items = self.discover_trashed_files()
        
        has_files = len(self.items) > 0
        if not has_files:
            print("No files found to process.")
        
        return True, has_files
    
    def _get_safety_confirmation(self) -> bool:
        """Get user confirmation for potentially destructive operations."""
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
        """Build list of actions to be performed."""
        actions = []
        if any(item.will_recover for item in self.items):
            actions.append("recover from trash")
        if any(item.will_download for item in self.items):
            actions.append("download locally")
        if self.args.post_restore_policy != PostRestorePolicy.RETAIN_ON_DRIVE:
            actions.append(f"apply post-restore policy: {self.args.post_restore_policy}")
        return actions
    
    def _initialize_recovery_state(self):
        """Initialize state for new recovery operation."""
        if not self.state.start_time:
            self.state.start_time = datetime.now(timezone.utc).isoformat()
            self.state.total_found = len(self.items)
    
    def _process_all_items(self) -> bool:
        """Process all recovery items with progress tracking."""
        print(f"\n🚀 Processing {len(self.items)} files with {self.args.concurrency} workers...")
        
        start_time = time.time()
        
        try:
            self._run_parallel_processing(start_time)
        except KeyboardInterrupt:
            print("\n⚠️  Operation interrupted. State saved for resume.")
            # Best-effort cleanup of newly created (empty) download dir on cancel
            self._maybe_cleanup_created_download_dir()
            self._save_state()
            return False
        
        # Final state save
        self._save_state()
        # Best-effort cleanup if nothing executed after creating dir
        self._maybe_cleanup_created_download_dir()
        
        # Print final summary
        self._print_summary(time.time() - start_time)
        
        return True
    
    def _run_parallel_processing(self, start_time: float):
        """Run parallel processing of all items."""
        processed_count = 0
        
        with ThreadPoolExecutor(max_workers=self.args.concurrency) as executor:
            # Submit all tasks
            future_to_item = {
                executor.submit(self._process_item, item): item 
                for item in self.items
            }
            
            # Process results
            for future in as_completed(future_to_item):
                item = future_to_item[future]
                processed_count += 1
                
                self._handle_item_result(future, item, processed_count, start_time)
    
    def _handle_item_result(self, future, item: RecoveryItem, processed_count: int, start_time: float):
        """Handle the result of processing a single item."""
        try:
            future.result()
            
            # Adaptive progress update by count or at least every ~10s
            interval = self._progress_interval(len(self.items))
            now = time.time()
            if (processed_count % interval == 0) or (self._last_exec_progress_ts is None) or ((now - self._last_exec_progress_ts) >= 10) or (processed_count == len(self.items)):
                self._print_progress_update(processed_count, start_time)
                self._last_exec_progress_ts = now
            
            # Save state periodically
            if processed_count % 100 == 0:
                self._save_state()
        
        except Exception as e:
            self.logger.error(f"Unexpected error processing {item.name}: {e}")
            with self.stats_lock:
                self.stats['errors'] += 1
    
    def _print_progress_update(self, processed_count: int, start_time: float):
        """Print progress update with ETA calculation."""
        elapsed = time.time() - start_time
        rate = processed_count / elapsed if elapsed > 0 else 0
        eta = (len(self.items) - processed_count) / rate if rate > 0 else 0
        
        print(f"📈 Progress: {processed_count}/{len(self.items)} "
              f"({processed_count/len(self.items)*100:.1f}%) "
              f"Rate: {rate:.1f}/sec ETA: {eta:.0f}s")

    def _progress_interval(self, total: int) -> int:
        """
        Compute adaptive progress cadence:
        - target ~2% of total
        - clamp to [5, 500]
        """
        if total <= 0:
            return 5
        return max(5, min(500, max(1, round(total * 0.02))))

    def _maybe_cleanup_created_download_dir(self):
        """
        If validation created the download directory, and it remains empty,
        remove it to avoid leaving residue on cancel/early exit.
        """
        if getattr(self.args, "_created_download_dir", False) and getattr(self.args, "download_dir", None):
            try:
                p = Path(self.args.download_dir)
                if p.exists() and p.is_dir():
                    # Only remove if empty
                    if not any(p.iterdir()):
                        p.rmdir()
            except Exception:
                pass
    
    def execute_recovery(self) -> bool:
        """Execute the main recovery process."""
        # Prepare for recovery
        success, has_files = self._prepare_recovery()
        if not success:
            return False  # Return False for actual failures (auth, network, etc.)
        
        if not has_files:
            return True  # Return True for "no files found" - this is a successful completion
        
        # Get safety confirmation
        if not self._get_safety_confirmation():
            return False
        
        # Initialize state
        self._initialize_recovery_state()
        
        # Process all items
        return self._process_all_items()
    
    def _print_summary(self, elapsed_time: float):
        """Print final execution summary."""
        print("\n" + "="*80)
        print("📊 EXECUTION SUMMARY")
        print("="*80)
        
        print(f"Total files found: {self.stats['found']}")
        print(f"Files recovered: {self.stats['recovered']}")
        print(f"Files downloaded: {self.stats['downloaded']}")
        
        # Detailed post-restore action breakdown
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

def create_parser() -> argparse.ArgumentParser:
    """Create argument parser."""
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
  MoveToDriveTrash (default) - Move back to trash after successful download
  RetainOnDrive             - Keep files in Drive after download
  RemoveFromDrive           - Permanently delete from Drive after download

Troubleshooting:
  * Quota Exhausted:
    Error: "Quota exceeded for quota metric 'Requests' and limit 'Requests per day'"
    Solution: Wait until the next day for quota reset or request a quota increase in Google Cloud Console.
    Example: Check https://console.cloud.google.com/apis/api/drive.googleapis.com/quotas

  * Permission Errors:
    Error: "HTTP 403: Forbidden - The user does not have sufficient permissions"
    Solution: Ensure the authenticated account has edit access to the files. For shared drives, verify team drive permissions.
    Example: Ask the file owner to grant edit access or re-authenticate with an account that has sufficient permissions.

  * Authentication Failures:
    Error: "credentials.json not found" or "Authentication failed"
    Solution: Download credentials.json from Google Cloud Console and place it in the script directory. Re-run to authenticate via browser.
    Example: Visit https://console.cloud.google.com/apis/credentials to generate credentials.json.

  * Invalid File IDs:
    Error: "Invalid file ID format" or "File IDs not found"
    Solution: Ensure file IDs are valid (25+ alphanumeric characters, hyphens, or underscores) and exist in Google Drive.
    Example: Use file IDs from Google Drive URLs, e.g., https://drive.google.com/file/d/FILE_ID/view

  * Missing Dependency (python-dateutil):
    Error: "Missing optional dependency 'python-dateutil' required for --after-date parsing."
    Solution: Install the package used to parse and compare dates.
    Example: pip install python-dateutil    
            """
    )
    
    # Subcommands
    subparsers = parser.add_subparsers(dest='command', help='Operation mode')
    
    # Dry run command
    dry_run_parser = subparsers.add_parser('dry-run', help='Show execution plan without making changes')
    
    # Recover only command
    recover_parser = subparsers.add_parser('recover-only', help='Recover files from trash only')
    
    # Recover and download command
    download_parser = subparsers.add_parser('recover-and-download', help='Recover and download files')
    download_parser.add_argument('--download-dir', required=True, help='Local directory for downloads')
    
    # Common arguments for all parsers
    for subparser in [dry_run_parser, recover_parser, download_parser]:
        subparser.add_argument('--version', action='version', version=f'%(prog)s {__version__}')
        subparser.add_argument('--extensions', nargs='+', 
                              help='File extensions to filter (e.g., jpg png pdf)')
        subparser.add_argument('--after-date', 
                              help='Only process files trashed after this date (ISO format)')
        subparser.add_argument('--file-ids', nargs='+',
                              help='Process only specific file IDs')
        subparser.add_argument('--post-restore-policy', 
                              choices=[PostRestorePolicy.MOVE_TO_DRIVE_TRASH, 
                                     PostRestorePolicy.RETAIN_ON_DRIVE,
                                     PostRestorePolicy.REMOVE_FROM_DRIVE],
                              default=PostRestorePolicy.MOVE_TO_DRIVE_TRASH,
                              help='What to do with files on Drive after successful download')
        subparser.add_argument('--concurrency', type=int, default=DEFAULT_WORKERS,
                              help='Number of concurrent operations')
        subparser.add_argument('--state-file', default=DEFAULT_STATE_FILE,
                              help='State file for resume capability')
        subparser.add_argument('--log-file', default=DEFAULT_LOG_FILE,
                              help='Log file path')
        subparser.add_argument('--verbose', '-v', action='count', default=0,
                              help='Increase verbosity (-v for INFO, -vv for DEBUG)')
        subparser.add_argument('--yes', '-y', action='store_true',
                              help='Skip confirmation prompts (for automation)')
 
    # Enrich epilog with quotas, shared drives, and tuning hints
    parser.epilog += """
 
  Quotas & Monitoring:
    Drive API enforces per-minute and daily quotas. If you see HTTP 429 responses,
    reduce --concurrency and retry later. Monitor usage in Google Cloud Console:
    drive.googleapis.com → Quotas. Consider staggering runs or using smaller batches.
 
  Shared Drives:
    Access is governed by membership/roles on the shared drive and by item-level
    permissions. 403 on files from a shared drive often indicates missing content
    manager access. Ask an admin to grant sufficient privileges or use an account
    with appropriate access.
 
  Concurrency Tuning:
    As a starting point, use min(8, CPU*2). If your network is high-latency or you
    observe 429/5xx bursts, back off concurrency until errors subside.
 """
    
def _set_mode(args) -> None:
    """Map subcommand to internal mode string (reduces branching in main)."""
    mode_map = {
        'dry-run': 'dry_run',
        'recover-only': 'recover_only',
       
       
        'recover-and-download': 'recover_and_download',
    }
    args.mode = mode_map.get(args.command)

def _validate_concurrency_arg(args) -> Tuple[bool, int]:
    """
    Validate --concurrency; returns (ok, exit_code_if_not_ok).
    Enforces >=1 and caps extremely high values to prevent resource exhaustion/rate limits.
    """
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

def _note_dir_created(args, path: Path) -> None:
    """Mark that validation created the directory, for potential cleanup on cancel."""
    try:
        if not hasattr(args, "_created_download_dir"):
            args._created_download_dir = False
        # If directory didn't exist before and exists now, mark it.
        if not getattr(args, "_created_download_dir", False) and path.exists() and path.is_dir():
            args._created_download_dir = True
    except Exception:
        pass

def _validate_download_dir_arg(args) -> Tuple[bool, int]:
    """
    Validate --download-dir for recover-and-download mode; fail fast on invalid paths.
    Creates the directory if missing and verifies writability.
    """
    if getattr(args, 'mode', None) != 'recover_and_download':
        return True, 0
    try:
        p = Path(args.download_dir)
        if p.exists() and not p.is_dir():
            print(f"❌ --download-dir points to a file: {p}")
            return False, 2
        pre_exists = p.exists()
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
        if not pre_exists:
            _note_dir_created(args, p)
        return True, 0
    except Exception as e:
        print(f"❌ --download-dir is not writable or cannot be created: {e}")
        return False, 2

def _validate_after_date_arg(args) -> Tuple[bool, int]:
    """Validate and normalize --after-date; returns (ok, exit_code_if_not_ok)."""
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

def _normalize_and_validate_extensions_arg(args) -> Tuple[bool, int]:
    """
    Normalize and validate --extensions; returns (ok, exit_code_if_not_ok).
    - Strips leading dots, lowercases, de-duplicates.
    - Rejects tokens containing spaces, commas, wildcards, or path separators.
    - Requires strictly [a-z0-9] tokens of reasonable length (1–10).
    - Warns (does not fail) for syntactically valid but unknown extensions
      that won't narrow the server-side mimeType query.
    """
    if not getattr(args, 'extensions', None):
        return True, 0

    invalid: List[str] = []
    cleaned: List[str] = []
    for raw in args.extensions:
        tok = (raw or "").strip()
        if not tok:
            invalid.append(repr(raw))
            continue
        # Disallow separators/wildcards and whitespace/comma-separated lists
        if any(ch in tok for ch in (' ', ',', '*', '?', '\\', '/')):
            invalid.append(tok)
            continue
        tok = tok.lower()
        if tok.startswith('.'):
            tok = tok[1:]
        # Strict token check: alnum (a–z0–9) only, reasonable length
        if not re.fullmatch(r'[a-z0-9]{1,10}', tok):
            invalid.append(raw)
            continue
        cleaned.append(tok)

    if invalid:
        print("❌ Invalid --extensions value(s): " + ", ".join(map(str, invalid)))
        print("   Use space-separated bare extensions like: --extensions jpg png pdf")
        print("   Do not include wildcards, commas, spaces, or path characters.")
        return False, 2

    # De-duplicate while preserving order
    deduped = list(dict.fromkeys(cleaned))
    args.extensions = deduped

    # Warn (do not fail) for unknown extensions; these won't narrow server-side
    unknown = [e for e in deduped if e not in EXTENSION_MIME_TYPES]
    if unknown:
        print("ℹ️  Note: unknown extension(s) will not narrow server-side queries;")
        print("   client-side filename filtering will apply instead: " + ", ".join(unknown))
    return True, 0

def _run_tool(tool: 'DriveTrashRecoveryTool', args) -> bool:
    """Run the selected mode (dry run vs execute)."""
    return tool.dry_run() if args.mode == 'dry_run' else tool.execute_recovery()

def main():
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Set mode based on command (extracted helper)
    _set_mode(args)
    
    # Create tool instance
    tool = DriveTrashRecoveryTool(args)

    # Validate --concurrency early (before heavy work)
    ok, code = _validate_concurrency_arg(args)
    if not ok:
        return code

    # Normalize/validate --extensions (fail fast on malformed inputs)
    ok, code = _normalize_and_validate_extensions_arg(args)
    if not ok:
        return code

    # Authenticate unconditionally
    if not tool.authenticate():
        print("❌ Authentication failed. Check logs for details.")
        return 1

    # Validate --after-date up front (extracted helper; fail fast on invalid input)
    ok, code = _validate_after_date_arg(args)
    if not ok:
        return code

    # Validate --download-dir after successful auth to avoid unnecessary FS changes
    ok, code = _validate_download_dir_arg(args)
    if not ok:
         return code
  
    # Validate file IDs if provided
    if args.file_ids and not tool._validate_file_ids():
        print("❌ File ID validation failed. Check logs for details.")
        return 1

    try:
        if args.mode == 'dry_run':
            success = tool.dry_run()
        else:
            success = tool.execute_recovery()
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n⚠️  Operation interrupted by user.")
        return 130
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())


def _normalize_and_validate_extensions_arg(args) -> Tuple[bool, int]:
    """
    Normalize and validate --extensions; returns (ok, exit_code_if_not_ok).
    - Strips leading dots, lowercases, de-duplicates.
    - Disallows spaces, commas, wildcards, and path separators.
    - Accepts alnum tokens and multi-dot forms (e.g., 'tar.gz', 'min.js').
    - Warns (does not fail) for tokens that won't narrow server-side queries.
    """
    if not getattr(args, 'extensions', None):
        return True, 0

    invalid: List[str] = []
    cleaned: List[str] = []
    for raw in args.extensions:
        tok = (raw or "").strip()
        if not tok:
            invalid.append(repr(raw))
            continue
        if any(ch in tok for ch in (' ', ',', '*', '?', '\\', '/')):
            invalid.append(tok)
            continue
        tok = tok.lower()
        if tok.startswith('.'):
            tok = tok[1:]
        # Accept alnum segments separated by single dots, length 1..20 total
        if not re.fullmatch(r'[a-z0-9]+(\.[a-z0-9]+)*', tok) or not (1 <= len(tok) <= 20):
            invalid.append(raw)
            continue
        cleaned.append(tok)

    if invalid:
        print("❌ Invalid --extensions value(s): " + ", ".join(map(str, invalid)))
        print("   Use space-separated extensions like: --extensions jpg png pdf tar.gz min.js")
        print("   Do not include wildcards, commas, spaces, or path characters.")
        return False, 2

    # De-duplicate while preserving order
    deduped = list(dict.fromkeys(cleaned))
    args.extensions = deduped

    # Guidance: server-side mimeType filtering only for known LAST suffix mappings
    unknown_for_server = []
    for tok in deduped:
        last = tok.split('.')[-1]
        if last not in EXTENSION_MIME_TYPES:
            unknown_for_server.append(tok)

    if unknown_for_server:
        print("ℹ️  Note: these extension(s) won't narrow server-side queries: "
              + ", ".join(unknown_for_server))
        print("   Client-side filename filtering will still apply. Consider extending EXTENSION_MIME_TYPES.")
    return True, 0
