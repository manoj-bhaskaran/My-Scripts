# Contributing to My Scripts Collection

Thank you for your interest in this repository. While this is primarily a personal project and external contributions are not currently being accepted, this document serves as a guide for maintaining code quality and consistency across the project.

---

## Table of Contents

- [Code Standards](#code-standards)
- [Logging Framework](#logging-framework)
  - [Overview](#overview)
  - [Console Output Streams](#console-output-streams)
  - [Python Logging](#python-logging)
  - [PowerShell Logging](#powershell-logging)
  - [Batch Script Logging](#batch-script-logging)
  - [Log Purge Mechanism](#log-purge-mechanism)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Standards](#documentation-standards)
- [Version Control Practices](#version-control-practices)
  - [Git LFS Requirements](#git-lfs-requirements)

---

## Code Standards

All scripts in this repository should follow these general principles:

- **Clarity**: Code should be self-documenting with meaningful variable and function names
- **Consistency**: Follow language-specific conventions and existing patterns in the codebase
- **Error Handling**: Implement robust error handling with appropriate logging
- **Security**: Never log sensitive data (credentials, tokens, PII); use restricted file permissions for logs
- **Modularity**: Prefer reusable functions and modules over duplicate code

---

## HTTP Request Guidelines

### Always Specify Timeouts

Never make HTTP requests without a timeout parameter:

```python
# ❌ BAD - Can hang indefinitely
response = requests.get(url)

# ✅ GOOD - Will timeout after 30 seconds
response = requests.get(url, timeout=(5, 30))  # (connect, read)
```

### Recommended Timeout Values

- **Quick API calls**: `(3, 10)` - Status checks, metadata
- **Standard API calls**: `(5, 30)` - Most operations
- **File uploads**: `(10, 120)` - Small to medium files
- **Large operations**: `(10, 600)` - Large file uploads/downloads

### Handle Timeout Exceptions

```python
from requests.exceptions import Timeout

try:
    response = requests.get(url, timeout=(5, 30))
except Timeout:
    logger.error(f"Request to {url} timed out")
    # Handle timeout appropriately
```

---

## Logging Framework

### Overview

This repository uses a **standardized, cross-platform logging framework** that provides consistent log formatting across Python, PowerShell, and Batch scripts. All new scripts **MUST** use this framework, and existing scripts **SHOULD** be refactored to use it during maintenance cycles.

**Key Features:**

- Unified log format across all languages
- Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Automatic timestamp generation with timezone support
- Optional structured metadata for enhanced context
- Centralized log storage with automatic directory management
- Built-in log purge mechanisms for retention management

**Core Specification:**

- Full specification: [`docs/logging_specification.md`](docs/logging_specification.md)
- Log format: `[YYYY-MM-DD HH:MM:SS.mmm TIMEZONE] [LEVEL] [SCRIPT_NAME] [HOST] [PROCESS_ID] [MESSAGE] [key1=value1 ...]`
- Log directory: `<script_root_dir>/logs/`
- Filename pattern: `<script_name>_<language>_YYYY-MM-DD.log`
- Default timezone: IST (Asia/Kolkata)
- Default retention: 30 days

---

### Console Output Streams

- **Default**: Production-ready PowerShell scripts must initialize `PowerShellLoggingFramework` and emit messages through `Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, etc.
- **Lightweight utilities**: When the logging module is intentionally not imported, prefer `Write-Information` for user-facing messages (`-InformationAction Continue` keeps output visible while remaining redirectable). Continue to use `Write-Warning`/`Write-Error` for warnings and failures.
- **Write-Host usage**: Reserved for interactive, color-coded diagnostics only. Add an inline justification and a `PSAvoidUsingWriteHost` suppression when you intentionally choose `Write-Host` (for example, in reporting tools such as `scripts/Check-DocumentationPaths.ps1`).
- **Automation compatibility**: When a script's output might be piped or captured by CI, avoid `Write-Host` and prefer structured logs or `Write-Information`/`Write-Output` instead.
- **Code review checklist**: Verify that new or modified scripts follow the above routing rules and that any `Write-Host` usage is documented and justified.

---

### Python Logging

#### Setup

**Module Location:** `src/common/python_logging_framework.py`

Import the logging framework at the top of your script:

```python
import sys
import os

# Add common directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'common'))
import python_logging_framework as plog
```

#### Initialization

Initialize the logger early in your script (typically after imports and before main logic):

```python
# Option 1: Automatic log file path (recommended)
plog.initialise_logger(log_file_path="auto", level="INFO")

# Option 2: Custom log directory
plog.initialise_logger(
    script_name="my_script",
    log_dir="/custom/path/to/logs",
    log_level="DEBUG",
    json_format=False
)
```

**Parameters:**

- `log_file_path`: Use `"auto"` for automatic path resolution, or provide a custom directory
- `level`: Log level string ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
- `json_format`: Set to `True` for structured JSON logging (default: `False`)

#### Basic Logging

Use level-specific functions for logging:

```python
# Debug - detailed diagnostic information
plog.log_debug("Starting authentication process")

# Info - general informational messages
plog.log_info("Successfully connected to database")

# Warning - warning messages for potentially harmful situations
plog.log_warning("API rate limit approaching threshold")

# Error - error events that might still allow the application to continue
plog.log_error(f"Failed to process file: {filename}")

# Critical - severe error events that might cause the application to abort
plog.log_critical("Database connection lost, aborting operation")
```

#### Logging with Metadata

Add contextual information using the `metadata` parameter:

```python
# Example 1: API operation with correlation ID
plog.log_info(
    "CloudConvert job submitted successfully",
    metadata={"CorrelationId": "job-12345", "Duration": "2.5s"}
)

# Example 2: File processing with details
plog.log_error(
    f"Failed to process image: {error}",
    metadata={
        "FileName": image_path,
        "FileSize": "2.3MB",
        "Attempt": attempt_number
    }
)

# Example 3: User action tracking
plog.log_info(
    "Backup completed",
    metadata={
        "User": os.getenv("USER"),
        "TaskId": task_id,
        "FilesProcessed": file_count
    }
)
```

**Recommended Metadata Keys:**

- `CorrelationId`: Unique identifier for tracking related operations
- `User`: Username or user identifier
- `TaskId`: Task or job identifier
- `FileName`: File being processed
- `Duration`: Operation duration (e.g., "2.5s", "150ms")
- `Attempt`: Retry attempt number
- `FileSize`: File size (human-readable format)

#### Complete Example

```python
#!/usr/bin/env python3
"""
Script: backup_to_drive.py
Description: Backs up local files to Google Drive
"""

import sys
import os
from pathlib import Path

# Add common directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'common'))
import python_logging_framework as plog

def main():
    # Initialize logger
    plog.initialise_logger(log_file_path="auto", level="INFO")

    plog.log_info("=== Backup script started ===")

    try:
        source_dir = Path("/path/to/source")
        plog.log_debug(f"Source directory: {source_dir}")

        if not source_dir.exists():
            plog.log_error(
                "Source directory not found",
                metadata={"FileName": str(source_dir)}
            )
            return 1

        # Process files
        files = list(source_dir.glob("*.txt"))
        plog.log_info(f"Found {len(files)} files to backup")

        for file in files:
            plog.log_debug(f"Processing: {file.name}")
            # ... backup logic here ...

        plog.log_info(
            "Backup completed successfully",
            metadata={"FilesProcessed": len(files), "Duration": "45s"}
        )
        return 0

    except Exception as e:
        plog.log_critical(f"Unexpected error: {e}", metadata={"Error": str(e)})
        return 1
    finally:
        plog.log_info("=== Backup script ended ===")

if __name__ == "__main__":
    sys.exit(main())
```

---

### PowerShell Logging

#### Setup

**Module Location:** `src/common/PowerShellLoggingFramework.psm1`

Import the logging framework at the beginning of your script:

```powershell
# Import logging framework
$commonPath = Join-Path $PSScriptRoot ".." "common"
Import-Module (Join-Path $commonPath "PowerShellLoggingFramework.psm1") -Force
```

#### Initialization

Initialize the logger after imports:

```powershell
# Option 1: Automatic configuration (recommended)
Initialize-Logger -LogLevel 20  # INFO level

# Option 2: Custom configuration
Initialize-Logger `
    -LogDirectory "C:\CustomLogs" `
    -ScriptName "MyScript" `
    -LogLevel 10 `
    -JsonFormat $false
```

**Log Levels (Numeric):**

- `10`: DEBUG
- `20`: INFO (default)
- `30`: WARNING
- `40`: ERROR
- `50`: CRITICAL

**Parameters:**

- `LogDirectory`: Custom log directory (default: auto-resolved from script location)
- `ScriptName`: Custom script name (default: auto-detected from caller)
- `LogLevel`: Minimum log level to record (default: 20/INFO)
- `JsonFormat`: Enable JSON structured logging (default: `$false`)

#### Basic Logging

Use level-specific cmdlets:

```powershell
# Debug - detailed diagnostic information
Write-LogDebug "Connecting to remote server"

# Info - general informational messages
Write-LogInfo "Service started successfully"

# Warning - warning messages
Write-LogWarning "Disk space running low: 15% remaining"

# Error - error events
Write-LogError "Failed to copy file: Access denied"

# Critical - severe errors
Write-LogCritical "System configuration corrupted, aborting"
```

#### Logging with Metadata

Add contextual information using hashtables:

```powershell
# Example 1: Task tracking with metadata
Write-LogInfo "File transfer completed" @{
    TaskId = "transfer-001"
    Duration = "12.5s"
    FilesProcessed = 150
}

# Example 2: Error with context
Write-LogError "Database connection failed" @{
    CorrelationId = $correlationId
    Attempt = 3
    Server = "db-server-01"
}

# Example 3: Performance monitoring
Write-LogWarning "Operation slow" @{
    Duration = "45s"
    Threshold = "30s"
    Operation = "DataSync"
}
```

#### Complete Example

```powershell
<#
.SYNOPSIS
    Synchronizes files between two directories
.DESCRIPTION
    Copies new or modified files from source to destination with logging
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [Parameter(Mandatory=$true)]
    [string]$DestinationPath
)

# Import logging framework
$commonPath = Join-Path $PSScriptRoot ".." "common"
Import-Module (Join-Path $commonPath "PowerShellLoggingFramework.psm1") -Force

# Initialize logger
Initialize-Logger -LogLevel 20

Write-LogInfo "=== File sync started ==="
Write-LogDebug "Source: $SourcePath"
Write-LogDebug "Destination: $DestinationPath"

try {
    # Validate paths
    if (-not (Test-Path $SourcePath)) {
        Write-LogError "Source path not found" @{ FileName = $SourcePath }
        exit 1
    }

    # Get files to sync
    $files = Get-ChildItem -Path $SourcePath -File
    Write-LogInfo "Found $($files.Count) files to process"

    $syncCount = 0
    foreach ($file in $files) {
        Write-LogDebug "Processing: $($file.Name)"

        try {
            Copy-Item -Path $file.FullName -Destination $DestinationPath -ErrorAction Stop
            $syncCount++
        }
        catch {
            Write-LogError "Failed to copy file" @{
                FileName = $file.Name
                Error = $_.Exception.Message
            }
        }
    }

    Write-LogInfo "Sync completed successfully" @{
        FilesProcessed = $syncCount
        Duration = "$(((Get-Date) - $startTime).TotalSeconds)s"
    }
}
catch {
    Write-LogCritical "Unexpected error: $_" @{ Error = $_.Exception.Message }
    exit 1
}
finally {
    Write-LogInfo "=== File sync ended ==="
}
```

---

### Batch Script Logging

Batch scripts should invoke PowerShell scripts that use the PowerShell logging framework for structured logging. This approach ensures consistency and leverages the full capability of the logging framework.

#### Pattern

```batch
@echo off
REM Script: run_backup.bat
REM Description: Wrapper to invoke PowerShell backup script with logging

PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup_script.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Backup script failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Backup completed successfully
exit /b 0
```

The corresponding PowerShell script (`backup_script.ps1`) would use the PowerShell logging framework as documented above.

---

### Log Purge Mechanism

The repository includes automated log retention management to prevent unbounded log growth.

#### PowerShell Purge Module

**Module Location:** `src/common/PurgeLogs.psm1`

The `Clear-LogFile` cmdlet supports **four mutually exclusive purge strategies**:

##### Strategy 1: Retention-Based Purge (Recommended)

Removes log entries older than a specified number of days:

```powershell
Import-Module "src/common/PurgeLogs.psm1"

# Remove entries older than 30 days
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -RetentionDays 30

# With dry run (preview only)
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -RetentionDays 15 -DryRun
```

##### Strategy 2: Size-Based Purge

Trims the log file to fit within a maximum size by removing oldest entries:

```powershell
# Keep only the most recent 20MB of logs
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -MaxSizeMB 20

# Alternative: size with units
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -MaxSizeMB "500KB"
```

##### Strategy 3: Threshold-Based Truncation

Clears the entire log file if it exceeds a size threshold:

```powershell
# Clear file completely if larger than 100MB
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -TruncateIfLarger "100MB"
```

##### Strategy 4: Unconditional Truncation

Clears the log file completely:

```powershell
# Clear log file immediately
Clear-LogFile -LogFilePath "C:\logs\myapp_powershell_2025-01-15.log" -TruncateLog
```

#### Purge Script

**Script Location:** `src/powershell/purge_logs.ps1`

A standalone script wrapper for the purge module:

```powershell
# Purge logs older than 15 days with verbose output
.\src\powershell\purge_logs.ps1 -LogFilePath "C:\logs\app.log" -RetentionDays 15 -Verbose

# Limit log size to 50MB
.\src\powershell\purge_logs.ps1 -LogFilePath "C:\logs\app.log" -MaxSizeMB 50
```

#### Scheduling Log Purge

**Recommended Schedule:** Weekly purge with 30-day retention

##### Windows Task Scheduler

1. **Create a scheduled task:**

```powershell
# Create task to run weekly on Sundays at 2 AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument `
    "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\My-Scripts\src\powershell\purge_logs.ps1 -LogFilePath C:\Scripts\My-Scripts\logs\*.log -RetentionDays 30"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "PurgeLogs-MyScripts" -Action $action -Trigger $trigger -Principal $principal
```

2. **Or import from XML:**

Example XML files are available in `Windows Task Scheduler/` directory.

##### Linux/macOS Cron

For cross-platform environments using PowerShell Core:

```bash
# Add to crontab (crontab -e)
# Run every Sunday at 2:00 AM
0 2 * * 0 /usr/bin/pwsh -NoProfile -ExecutionPolicy Bypass -File /home/user/My-Scripts/src/powershell/purge_logs.ps1 -LogFilePath "/home/user/My-Scripts/logs/*.log" -RetentionDays 30
```

#### Bulk Purge Pattern

To purge all logs in the repository's log directory:

```powershell
# Get all log files
$logDir = "C:\Scripts\My-Scripts\logs"
$logFiles = Get-ChildItem -Path $logDir -Filter "*.log"

# Purge each with 30-day retention
foreach ($logFile in $logFiles) {
    Write-Host "Purging: $($logFile.Name)"
    Clear-LogFile -LogFilePath $logFile.FullName -RetentionDays 30 -Verbose
}
```

---

## Testing Guidelines

When adding or modifying scripts:

1. **Manual Testing**: Test scripts in isolated environments before committing
2. **Edge Cases**: Verify behavior with empty inputs, missing files, permission errors, etc.
3. **Logging Verification**: Ensure all error paths produce appropriate log entries
4. **Cross-Platform**: For PowerShell scripts, test on both Windows PowerShell 5.1 and PowerShell 7+ if applicable

---

## Documentation Standards

### Path Placeholders

Always use placeholders instead of actual paths in examples to ensure documentation works for all users.

#### Standard Placeholders

| Placeholder     | Description                  | Windows Example                             | Linux Example         |
| --------------- | ---------------------------- | ------------------------------------------- | --------------------- |
| `<REPO_PATH>`   | Git repository location      | `C:\Projects\My-Scripts`                    | `~/dev/My-Scripts`    |
| `<SCRIPT_ROOT>` | Working/deployment directory | `C:\Users\YourName\Documents\Scripts`       | `~/scripts`           |
| `<CONFIG_DIR>`  | Configuration directory      | `C:\Users\YourName\AppData\Local\MyScripts` | `~/.config/myscripts` |
| `<LOG_DIR>`     | Log file directory           | `C:\Logs\MyScripts`                         | `/var/log/myscripts`  |
| `<BACKUP_DIR>`  | Backup storage directory     | `D:\Backups`                                | `~/backups`           |
| `<USERNAME>`    | Current user                 | `YourName`                                  | `yourname`            |

See [Documentation Placeholders](docs/conventions/placeholders.md) for complete guide.

#### Good Example ✅

```powershell
# Using placeholders
cd "<SCRIPT_ROOT>"
.\src\powershell\Invoke-SystemHealthCheck.ps1

# Using environment variables (preferred)
cd "$env:MY_SCRIPTS_ROOT"
.\src\powershell\Invoke-SystemHealthCheck.ps1
```

#### Bad Example ❌

```powershell
# DO NOT use actual paths
cd "C:\Users\manoj\Documents\Scripts"
.\src\powershell\Invoke-SystemHealthCheck.ps1
```

#### Platform-Specific Examples

Provide both Windows and Linux examples when applicable:

**Windows:**

```powershell
cd "<SCRIPT_ROOT>"
.\script.ps1
```

**Linux:**

```bash
cd "<SCRIPT_ROOT>"
./script.sh
```

### Script Headers

All scripts should include a descriptive header:

**Python:**

```python
#!/usr/bin/env python3
"""
Script: script_name.py
Description: Brief description of what this script does
Author: Manoj Bhaskaran
Version: 1.0.0
"""
```

**PowerShell:**

```powershell
<#
.SYNOPSIS
    Brief one-line description

.DESCRIPTION
    Detailed description of what the script does

.PARAMETER ParameterName
    Description of parameter

.EXAMPLE
    Example usage

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.0
#>
```

### Inline Comments

- Use comments to explain **why**, not **what** (code should be self-explanatory)
- Document complex algorithms or non-obvious logic
- Keep comments up-to-date when code changes

---

## Version Control Practices

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(python): add Google Drive backup script with logging
fix(powershell): resolve parameter validation in DeleteOldDownloads
docs(logging): update CONTRIBUTING.md with logging examples
refactor(common): migrate legacy scripts to use logging framework
```

### Branching

- Use descriptive branch names: `feature/description`, `fix/issue-number`, `docs/topic`
- Keep branches focused on a single concern
- Merge or rebase from main regularly to avoid conflicts

### Git LFS Requirements

Large binary assets slow down clones and inflate repository size. To keep history lean, Git LFS is configured for database dumps, archives, and media files.

1. Install the LFS hooks (once per machine):

   ```bash
   git lfs install
   ```

2. Automatic tracking is configured in [`.gitattributes`](.gitattributes) for `*.sql`, `*.dump`, `*.mp4`, and `*.zip`.

3. When adding new large binaries (or new extensions that should use LFS), ensure they are covered by LFS patterns before committing. Run `git add` again after updating `.gitattributes` so tracked files are rewritten as LFS pointers.

4. After cloning, run `git lfs pull` if you need the actual binary contents for development or testing.

5. Do not commit large binaries outside of LFS. If you accidentally do, rewrite the commit before merging.

---

## Security Best Practices

### Logging Security

1. **Never log sensitive data:**

   - Passwords, API keys, tokens
   - Personally Identifiable Information (PII)
   - Financial or health information
   - Full file paths that reveal user directory structures

2. **Log file permissions:**

   - Linux/macOS: `chmod 600` (owner read/write only)
   - Windows: Configure NTFS ACLs to restrict access

3. **Sanitize user input:**

   ```python
   # Good: Sanitized logging
   plog.log_info(f"User login attempt", metadata={"User": username})

   # Bad: Logging password
   plog.log_info(f"Login with password: {password}")  # NEVER DO THIS
   ```

### Script Security

- Validate and sanitize all user inputs
- Avoid `Invoke-Expression`; prefer the call operator (`&`) or `Start-Process` with explicit arguments
- Use parameterized queries for database operations
- Avoid executing external commands with unsanitized input
- Keep dependencies up-to-date

---

## Questions or Issues?

For questions or to report issues, please open a GitHub issue in this repository.

---

**Last Updated:** 2025-11-16
**Version:** 1.0.0
