"""
Static configuration constants for the Google Drive recovery tool.

This module is a dependency-free constants store shared by gdrive_recover.py
and future sibling modules (validators, reporters, etc.).  It has no runtime
logic: every name is either a literal or a simple os.getenv() call evaluated
at import time.
"""

import os

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
VERSION = "1.18.1"

# ---------------------------------------------------------------------------
# API / OAuth
# ---------------------------------------------------------------------------
SCOPES = ["https://www.googleapis.com/auth/drive"]

# ---------------------------------------------------------------------------
# File-operation defaults
# ---------------------------------------------------------------------------
DEFAULT_STATE_FILE = "gdrive_recovery_state.json"
DEFAULT_LOG_FILE = "gdrive_recovery.log"
DEFAULT_PROCESS_BATCH = 500
MAX_RETRIES = 3
RETRY_DELAY = 2  # seconds
PAGE_SIZE = 1000
DEFAULT_WORKERS = min(8, (os.cpu_count() or 1) * 2)
INFERRED_MODIFY_ERROR = "Cannot modify file (inferred from untrash check)"
FOLDER_MIME_TYPE = "application/vnd.google-apps.folder"

# ---------------------------------------------------------------------------
# Rate-limiting / HTTP transport
# ---------------------------------------------------------------------------
DEFAULT_MAX_RPS = 5.0  # conservative default; set 0 to disable
DEFAULT_BURST = 0  # token bucket capacity; 0 = disabled (legacy pacing)
DOWNLOAD_CHUNK_BYTES = 1024 * 1024  # 1 MiB
DEFAULT_HTTP_TRANSPORT = "auto"  # auto|httplib2|requests
DEFAULT_HTTP_POOL_MAXSIZE = 32

# ---------------------------------------------------------------------------
# Credential / token path resolution (env-overridable)
#  - GDRIVE_CREDENTIALS_PATH: shared Google client secret JSON for auth modules
#  - GDRIVE_TOKEN_PATH:        shared OAuth token cache path
#  - GDRT_CREDENTIALS_FILE:   override for the recovery tool only
#  - GDRT_TOKEN_FILE:         override token cache for the recovery tool only
# ---------------------------------------------------------------------------
DEFAULT_CREDENTIALS_FILE = os.getenv("GDRIVE_CREDENTIALS_PATH", "credentials.json")
DEFAULT_TOKEN_FILE = os.getenv("GDRIVE_TOKEN_PATH", "token.json")
CREDENTIALS_FILE = os.getenv("GDRT_CREDENTIALS_FILE", DEFAULT_CREDENTIALS_FILE)
TOKEN_FILE = os.getenv("GDRT_TOKEN_FILE", DEFAULT_TOKEN_FILE)

# ---------------------------------------------------------------------------
# Extension → MIME-type mapping for robust server-side filtering
# ---------------------------------------------------------------------------
EXTENSION_MIME_TYPES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "bmp": "image/bmp",
    "tiff": "image/tiff",
    "tif": "image/tiff",
    "webp": "image/webp",
    "svg": "image/svg+xml",
    "pdf": "application/pdf",
    "doc": "application/msword",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xls": "application/vnd.ms-excel",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "ppt": "application/vnd.ms-powerpoint",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "txt": "text/plain",
    "csv": "text/csv",
    "mp4": "video/mp4",
    "avi": "video/x-msvideo",
    "mov": "video/quicktime",
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "zip": "application/zip",
    "rar": "application/vnd.rar",
    "7z": "application/x-7z-compressed",
}
