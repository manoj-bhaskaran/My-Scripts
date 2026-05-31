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
VERSION = "1.29.0"

# ---------------------------------------------------------------------------
# CLI help text
# ---------------------------------------------------------------------------
HELP_EPILOG = r"""
Examples:
  Dry-run (preview — no changes made):
    %(prog)s dry-run
    %(prog)s dry-run --extensions jpg png --no-emoji
    %(prog)s dry-run --after-date 2024-01-01
    %(prog)s dry-run --file-ids FILE_ID_1 FILE_ID_2
    %(prog)s dry-run --folder-id FOLDER_ID --download-dir ./backup --post-restore-policy retain
    %(prog)s dry-run --download-dir ./recovered --extensions jpg png

  Recover-only (restore trashed files to Drive — no local download):
    %(prog)s recover-only --extensions pdf docx
    %(prog)s recover-only --after-date 2024-06-01 --yes
    %(prog)s recover-only --file-ids FILE_ID_1 FILE_ID_2 --yes
    %(prog)s recover-only --state-file ./state.json --yes

  Recover-and-download (restore trashed files and save locally):
    %(prog)s recover-and-download --download-dir ./recovered --post-restore-policy retain
    %(prog)s recover-and-download --download-dir ./recovered --extensions jpg png --post-restore-policy retain --yes
    %(prog)s recover-and-download --download-dir ./recovered --file-ids FILE_ID_1 --post-restore-policy retain
    %(prog)s recover-and-download --download-dir ./recovered --state-file ./state.json --yes
    %(prog)s recover-and-download --download-dir ./recovered --direct-download --post-restore-policy retain
    %(prog)s recover-and-download --download-dir ./recovered --overwrite --post-restore-policy retain
    %(prog)s recover-and-download --download-dir ./recovered --skip-existing --post-restore-policy retain

  Folder-scoped download (download a live Drive folder and all subfolders):
    %(prog)s dry-run --folder-id FOLDER_ID --download-dir ./backup --post-restore-policy retain
    %(prog)s recover-and-download --folder-id FOLDER_ID --download-dir ./backup --post-restore-policy retain
    %(prog)s recover-and-download --folder-id FOLDER_ID --download-dir ./backup --extensions pdf --post-restore-policy retain --yes
    %(prog)s recover-and-download --folder-id FOLDER_ID --download-dir ./backup --overwrite --post-restore-policy retain --yes

  Performance presets:
    %(prog)s recover-and-download --download-dir ./out --concurrency 16 --process-batch-size 500 --max-rps 8 --burst 32 --post-restore-policy retain -v
    %(prog)s recover-and-download --download-dir ./out --http-transport requests --http-pool-maxsize 16 --concurrency 16 --post-restore-policy retain

  Logging and failure tracking:
    %(prog)s recover-and-download --download-dir ./out --log-file ./run.log
    %(prog)s recover-and-download --download-dir ./out --failed-file ./failed.csv
    %(prog)s recover-and-download --download-dir ./out --log-file ./logs/run.log --failed-file ./logs/failed.csv
    %(prog)s recover-and-download --download-dir ./out --fresh-run --failed-file ./failed.csv  # clears state + failed.csv first

  Fresh run (ignore prior progress, regenerate run identity, truncate failed-file):
    %(prog)s recover-only --fresh-run --state-file ./state.json --yes
    %(prog)s recover-and-download --download-dir ./out --fresh-run --failed-file ./failed.csv --yes

  Retry failed downloads from a previous run:
    %(prog)s recover-and-download --download-dir ./out --retry-failed-file ./failed.csv
    %(prog)s recover-and-download --download-dir ./out --retry-failed-file ./failed.csv --post-restore-policy retain --yes

  Locking and automation:
    %(prog)s recover-and-download --download-dir ./out --lock-timeout 60 --state-file ./state.json
    %(prog)s recover-and-download --download-dir ./out --force --state-file ./state.json
    %(prog)s recover-and-download --download-dir ./out --yes --no-emoji

Policies: trash (default), retain, delete
  trash  — move file to Drive Trash after download (WARNING: avoid with --folder-id)
  retain — leave the file in its current Drive location (recommended with --folder-id)
  delete — permanently delete from Drive after download (irreversible)

Notes:
  --folder-id targets non-trashed live files; it cannot be combined with --file-ids or recover-only.
  Use --post-restore-policy retain with --folder-id to avoid moving live files to Trash.
  The folder ID is the alphanumeric string at the end of a Drive folder URL:
    https://drive.google.com/drive/folders/<FOLDER_ID>

For the compatibility matrix, transport notes, and performance presets: see README.md and CHANGELOG-gdrive-recover.md.
"""

# ---------------------------------------------------------------------------
# API / OAuth
# ---------------------------------------------------------------------------
SCOPES = ["https://www.googleapis.com/auth/drive"]

# ---------------------------------------------------------------------------
# File-operation defaults
# ---------------------------------------------------------------------------
DEFAULT_STATE_FILE = "gdrive_recovery_state.json"
DEFAULT_LOG_FILE = ""  # empty = no log file; supply --log-file <path> to enable
DEFAULT_FAILED_FILE = ""  # empty = disabled; supply --failed-file <path> to record failed paths
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
