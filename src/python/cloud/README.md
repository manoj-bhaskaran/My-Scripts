# Cloud Services Scripts

Python scripts for cloud service integration, primarily Google Drive operations.

## Scripts

- **gdrive_recover.py** - Google Drive file recovery and restoration utilities
- **gdrive_cli.py** - CLI entry layer for gdrive_recover (argument parsing, validation, and main entry point)
- **gdrive_constants.py** - Static configuration constants (including authoritative `VERSION`) shared by gdrive_recover.py and sibling modules
- **gdrive_models.py** - Data model types (TypedDicts, dataclasses, PostRestorePolicy) shared by gdrive_recover.py and future sibling modules
- **gdrive_auth.py** - OAuth credential management, token caching, HTTP transport construction, and Drive service initialisation for gdrive_recover.py
- **gdrive_rate_limiter.py** - Thread-safe request pacing primitives (fixed-interval and token-bucket) used by gdrive_recover.py
- **gdrive_state.py** - Recovery state persistence, schema handling, and lock file management for gdrive_recover.py
- **gdrive_discovery.py** - Discovery helpers: trashed-file query/ID resolution and folder-scoped BFS traversal with subfolder hierarchy reconstruction (issue #791)
- **gdrive_download.py** - File download subsystem (chunked streaming, atomic placement, Windows/OneDrive retry, partial cleanup) extracted from gdrive_recover.py (issue #853)
- **gdrive_operations.py** - Recovery and post-restore execution helpers extracted from gdrive_recover.py (issue #854)
- **gdrive_privileges.py** - Dry-run privilege-check subsystem (Drive capability checks and local-writability checks) extracted from gdrive_recover.py (issue #856)
- **gdrive_report.py** - Recovery reporting/presentation layer (dry-run plan output, progress, and summaries) extracted from gdrive_recover.py (issue #855)
- **gdrive_retry.py** - Shared retry/backoff utility used across recovery/discovery operations
- **google_drive_root_files_delete.py** - Cleans up files in Google Drive root directory
- **drive_space_monitor.py** - Monitors Google Drive storage usage and sends alerts
- **cloudconvert_utils.py** - CloudConvert API utilities for file conversion

## Dependencies

### Python Modules

- **python_logging_framework** (`src/python/modules/logging/`) - Standardized logging
- **google_drive_auth** (`src/python/modules/auth/`) - Google Drive authentication

### External Packages

```bash
pip install google-auth google-auth-oauthlib google-auth-httplib2
pip install google-api-python-client
pip install requests
```

## Configuration

### Google Drive Authentication

Scripts using Google Drive require OAuth2 credentials:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Drive API
3. Create OAuth2 credentials
4. Download credentials file
5. Configure the credential and token file paths via environment variables:
   - `GDRIVE_CREDENTIALS_PATH` (defaults to `~/Documents/Scripts/credentials.json`)
   - `GDRIVE_TOKEN_PATH` (defaults to `~/Documents/Scripts/drive_token.json`)
6. Optionally override recovery tool paths with `GDRT_CREDENTIALS_FILE` and `GDRT_TOKEN_FILE`
7. Load `.env` with `source scripts/load-environment.sh` (Bash) or `. ./scripts/Load-Environment.ps1` (PowerShell)

### CloudConvert API

CloudConvert scripts require an API key:

- Set environment variable `CLOUDCONVERT_PROD`
- Or configure in script parameters
- Use `.env.example` and the validation scripts to confirm your configuration

## Scheduling

The Drive Space Monitor script can be scheduled via Windows Task Scheduler:

- Task definition: `config/tasks/Drive Space Monitor.xml`

## Use Cases

### Drive Space Management

Monitor storage usage and receive alerts before reaching quota limits.

### File Organization

Move files out of Drive root into organized folders.

### File Recovery

Recover deleted or lost files from Google Drive trash.

## Examples

All commands below are run from the `src/python/cloud/` directory using `python gdrive_recover.py`.

### Dry-run (preview only — no changes made)

```bash
# Preview all recoverable trashed files
python gdrive_recover.py dry-run

# Preview only image files trashed after 2024-01-01
python gdrive_recover.py dry-run --extensions jpg jpeg png --after-date 2024-01-01

# Preview specific files by their Drive IDs
python gdrive_recover.py dry-run --file-ids FILE_ID_1 FILE_ID_2

# Preview what a folder download would look like (full subfolder tree with target paths)
python gdrive_recover.py dry-run \
  --folder-id DRIVE_FOLDER_ID \
  --download-dir ./backup \
  --post-restore-policy retain

# Dry-run with ASCII output (no emoji) — useful for CI logs
python gdrive_recover.py dry-run --no-emoji
```

### Recover-only (restore trashed files to Drive — no local download)

```bash
# Restore all trashed files to Drive
python gdrive_recover.py recover-only

# Restore only PDF and DOCX files trashed after a date
python gdrive_recover.py recover-only --extensions pdf docx --after-date 2024-06-01

# Restore specific files without a confirmation prompt (automation)
python gdrive_recover.py recover-only --file-ids FILE_ID_1 FILE_ID_2 --yes

# Resume an interrupted recover-only run
python gdrive_recover.py recover-only --state-file ./my_state.json --yes
```

> **Note:** `--folder-id` cannot be used with `recover-only`. Folder-scoped files are not in trash,
> so there is nothing to untrash. Use `recover-and-download --post-restore-policy retain` instead.

### Recover-and-download (restore trashed files and save locally)

```bash
# Download all trashed files; move them to Drive Trash after download (default policy)
python gdrive_recover.py recover-and-download --download-dir ./recovered

# Download and keep files in Drive (recommended)
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --post-restore-policy retain

# Download only image files, keep on Drive, skip confirmation
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --extensions jpg jpeg png gif \
  --post-restore-policy retain \
  --yes

# Download and permanently delete from Drive after downloading
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --post-restore-policy delete \
  --yes

# Download specific files by Drive ID, retaining them in Drive
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --file-ids FILE_ID_1 FILE_ID_2 FILE_ID_3 \
  --post-restore-policy retain

# Resume an interrupted download using a named state file
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --state-file ./recovery_state.json \
  --yes

# Direct download: stream directly to final filename (avoids AV/thumbnailer lock races on Windows)
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --direct-download \
  --post-restore-policy retain

# Overwrite existing local files instead of creating conflict-safe copies
python gdrive_recover.py recover-and-download \
  --download-dir ./recovered \
  --overwrite \
  --post-restore-policy retain
```

### Folder-scoped download (download a live Drive folder)

Downloads a non-trashed Google Drive folder and all its subfolders to a local directory, preserving the full subfolder hierarchy.

```bash
# Step 1: Preview the folder tree before downloading
python gdrive_recover.py dry-run \
  --folder-id DRIVE_FOLDER_ID \
  --post-restore-policy retain

# Step 2: Download the entire folder
python gdrive_recover.py recover-and-download \
  --folder-id DRIVE_FOLDER_ID \
  --download-dir ./my_backup \
  --post-restore-policy retain

# Download only PDF files from a folder
python gdrive_recover.py recover-and-download \
  --folder-id DRIVE_FOLDER_ID \
  --download-dir ./my_backup \
  --extensions pdf \
  --post-restore-policy retain \
  --yes

# Large folder: increase concurrency and batch size for throughput
python gdrive_recover.py recover-and-download \
  --folder-id DRIVE_FOLDER_ID \
  --download-dir ./my_backup \
  --post-restore-policy retain \
  --concurrency 16 \
  --process-batch-size 500 \
  --max-rps 8 \
  --burst 32 \
  --yes

# Re-download a folder and overwrite any files already present locally
python gdrive_recover.py recover-and-download \
  --folder-id DRIVE_FOLDER_ID \
  --download-dir ./my_backup \
  --overwrite \
  --post-restore-policy retain \
  --yes
```

The folder ID is the alphanumeric string at the end of a Google Drive folder URL:
`https://drive.google.com/drive/folders/<FOLDER_ID>`

> **Note:** `--post-restore-policy retain` is strongly recommended when using `--folder-id` to avoid
> moving your live Drive files to Trash after download. The tool warns you if the default `trash`
> policy is active.

**Post-restore policies:**

| Policy  | Effect after download             | With `--folder-id`                  |
| ------- | --------------------------------- | ----------------------------------- |
| `trash` | Move file to Drive Trash          | **Avoid** — moves live files to Trash |
| `retain`| Leave the file in its Drive location | **Recommended**                  |
| `delete`| Permanently delete from Drive     | Use with caution                    |

### Performance presets

```bash
# High-throughput preset (large sets, e.g. ~200k files on an 8-core VM)
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --process-batch-size 500 \
  --concurrency 16 \
  --max-rps 8 \
  --burst 32 \
  --client-per-thread \
  --post-restore-policy retain \
  -v

# Memory-constrained preset (~2 GB RAM)
python gdrive_recover.py recover-only \
  --process-batch-size 250 \
  --concurrency 8 \
  --max-rps 5 \
  --burst 20 \
  --client-per-thread \
  -v

# Validate observed RPS with rate-limiter diagnostics
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --rl-diagnostics \
  --max-rps 5 \
  -vv

# Use pooled requests transport for high-concurrency workloads
# Requires: pip install requests "google-auth[requests]"
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --http-transport requests \
  --http-pool-maxsize 16 \
  --concurrency 16 \
  --post-restore-policy retain
```

### Locking and automation

```bash
# Wait up to 60 s for a held state lock before giving up
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --state-file ./shared_state.json \
  --lock-timeout 60

# Force takeover of a stale lock from a crashed previous run
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --state-file ./shared_state.json \
  --force

# Fully automated run (no prompts)
python gdrive_recover.py recover-and-download \
  --download-dir ./out \
  --post-restore-policy retain \
  --yes \
  --no-emoji
```

## Logging

All scripts use the Python Logging Framework located in `src/python/modules/logging/`.

## Compatibility and Performance

### Compatibility Matrix

| Component                        | Tested with / Minimum (guidance) |
| -------------------------------- | -------------------------------- |
| Python                           | 3.10+                            |
| google-api-python-client         | 2.100+                           |
| google-auth                      | 2.20+                            |
| google-auth-httplib2             | 0.2+                             |
| requests (optional)              | 2.28+                            |
| google-auth[requests] (optional) | 2.20+                            |

### Performance Presets

- Large sets (for example ~200k items, 8-core VM):
  - `recover-and-download --download-dir ./out --process-batch-size 500 --concurrency 16 --max-rps 8 --burst 32 --client-per-thread -v`
- Memory-constrained environments (around 2 GB RAM):
  - `recover-only --process-batch-size 250 --concurrency 8 --max-rps 5 --burst 20 --client-per-thread -v`
- Tuning guidance:
  - Start with `--concurrency min(8, CPU*2)` and reduce first when 429/5xx spikes appear.
  - Use `--max-rps` and `--burst` together to smooth short network jitter while controlling average rate.
  - Enable `--rl-diagnostics -vv` when validating throughput behavior.

## Internal Module Boundaries

- `gdrive_recover.py` owns recovery orchestration and execution flow; download calls are delegated to `self.downloader`.
- `gdrive_cli.py` owns CLI argument parsing, validation, and command routing.
- `gdrive_constants.py` owns dependency-free constants and the shared `VERSION` string used by both `gdrive_recover.py` and `gdrive_cli.py`.
- `gdrive_auth.py` owns OAuth credential management, token caching, HTTP transport construction, and Drive service initialisation.
  - Exposes `DriveAuthManager`; used by `DriveTrashRecoveryTool` via `self.auth`.
- `gdrive_rate_limiter.py` owns request pacing mechanics (`RateLimiter.wait()`), including fixed-interval mode and token-bucket mode with diagnostics.
  - Exposes `RateLimiter`; used by `DriveTrashRecoveryTool` via `self.rate_limiter` (no back-compat shim methods on the tool class).
- `gdrive_state.py` owns persistent state and lock-file concerns.
  - Includes PID liveness checks used by lock diagnostics in `gdrive_cli.py`.
  - Reports state-load failures back to `gdrive_recover.py` so execution error totals remain accurate.
- `gdrive_discovery.py` owns query/file-ID discovery, validation, streaming helpers, and folder-scoped BFS traversal used by `DriveTrashRecoveryTool`.
  - `DriveTrashDiscovery` holds no reference to `DriveTrashRecoveryTool`; all dependencies (`stats`, `stats_lock`, `seen_total_ref`, `generate_target_path`, `run_parallel_processing_for_batch`) are injected at construction time.
  - Neither `DriveTrashRecoveryTool` nor `DriveTrashDiscovery` defines `__getattr__`; all inter-class wiring is explicit.
  - Streaming helper methods required by discovery paths are implemented in this module (not delegated back to `gdrive_recover.py`).
  - Folder-scoped discovery (`--folder-id`) uses BFS traversal: `_discover_folder_recursively` for dry-run/non-streaming paths and `_stream_stream_folder` for streaming execution. Both reconstruct subfolder hierarchy via `relative_path` on each `RecoveryItem`.
- `gdrive_download.py` owns the file download subsystem: chunked streaming via `MediaIoBaseDownload`, atomic placement, Windows/OneDrive retry, and partial-file cleanup.
  - Exposes `DriveDownloader`; used by `DriveTrashRecoveryTool` via `self.downloader`.
  - `DriveDownloader` holds no reference to `DriveTrashRecoveryTool`; all dependencies (`args`, `logger`, `rate_limiter`, `auth`, `stats`, `stats_lock`) are injected at construction time.
  - `MediaIoBaseDownload` and `DOWNLOAD_CHUNK_BYTES` are imported only in this module.
- `gdrive_operations.py` owns per-item recovery execution (`_recover_file`, `_apply_post_restore_policy`, and `_process_item`) plus post-restore helper logic.
  - Exposes `DriveOperations`; used by `DriveTrashRecoveryTool` via `self.ops`.
  - `DriveOperations` holds no reference to `DriveTrashRecoveryTool`; all dependencies (`args`, `logger`, `auth`, `downloader`, `state_manager`, `stats`, `stats_lock`) are injected at construction time.
- `gdrive_privileges.py` owns dry-run privilege checking concerns (`_check_privileges`, `_check_untrash_privilege`, `_check_download_privilege`, `_check_trash_delete_privileges`, `_test_operation_privileges`, `_get_file_info`).
  - Exposes `DrivePrivilegeChecker`; used by `DriveTrashRecoveryTool` via `self.privileges`.
  - `DrivePrivilegeChecker` receives auth, execute function, logger, and item list via dependency injection; it has no back-reference to `DriveTrashRecoveryTool`.
- `gdrive_report.py` owns user-facing presentation for recovery and dry-run paths.
  - Exposes `RecoveryReporter`; used by `DriveTrashRecoveryTool` via `self.reporter`.
  - `RecoveryReporter` formats symbols/messages, plan rendering, progress lines, and execution summary output while honoring `--no-emoji`.
- `gdrive_retry.py` owns shared `with_retries(...)` backoff logic used by both recovery and discovery modules to avoid copy-pasted retry loops.
  - `with_retries(...)` returns `(result, error_message, http_status)` so callers can branch on status code without parsing formatted message text.
  - Internal planning/logging helpers keep retry flow explicit while reducing function complexity for static analysis.
