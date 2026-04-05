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
- **gdrive_discovery.py** - Discovery and trashed file resolution helpers extracted from gdrive_recover.py (issue #791)
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

## Logging

All scripts use the Python Logging Framework located in `src/python/modules/logging/`.

## Internal Module Boundaries

- `gdrive_recover.py` owns recovery/download orchestration and execution flow.
- `gdrive_cli.py` owns CLI argument parsing, validation, and command routing.
- `gdrive_constants.py` owns dependency-free constants and the shared `VERSION` string used by both `gdrive_recover.py` and `gdrive_cli.py`.
- `gdrive_auth.py` owns OAuth credential management, token caching, HTTP transport construction, and Drive service initialisation.
  - Exposes `DriveAuthManager`; used by `DriveTrashRecoveryTool` via `self.auth`.
- `gdrive_rate_limiter.py` owns request pacing mechanics (`RateLimiter.wait()`), including fixed-interval mode and token-bucket mode with diagnostics.
  - Exposes `RateLimiter`; used by `DriveTrashRecoveryTool` via `self.rate_limiter` (no back-compat shim methods on the tool class).
- `gdrive_state.py` owns persistent state and lock-file concerns.
  - Includes PID liveness checks used by lock diagnostics in `gdrive_cli.py`.
  - Reports state-load failures back to `gdrive_recover.py` so execution error totals remain accurate.
- `gdrive_discovery.py` owns query/file-ID discovery, validation, and streaming discovery helpers used by `DriveTrashRecoveryTool`.
