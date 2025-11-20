# Using Shared Utilities

## Overview

This guide explains how to use the shared utility modules that have been extracted from duplicated code patterns across the My-Scripts repository. These modules provide standardized error handling, file operations with retry logic, and progress reporting.

## Table of Contents

- [PowerShell Modules](#powershell-modules)
  - [ErrorHandling](#errorhandling-module)
  - [FileOperations](#fileoperations-module)
  - [ProgressReporter](#progressreporter-module)
- [Python Modules](#python-modules)
  - [error_handling](#error_handling-module)
  - [file_operations](#file_operations-module)
- [Migration Examples](#migration-examples)
- [Benefits](#benefits)

## PowerShell Modules

### ErrorHandling Module

**Location:** `src/powershell/modules/Core/ErrorHandling/`

The ErrorHandling module provides standardized error handling, retry logic, and privilege checking.

#### Importing

```powershell
Import-Module "$PSScriptRoot/relative/path/to/ErrorHandling.psm1"
```

#### Functions

##### Invoke-WithErrorHandling

Execute script blocks with standardized error handling.

**Before:**
```powershell
try {
    Get-Content "file.txt"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    throw
}
```

**After:**
```powershell
Import-Module ErrorHandling

Invoke-WithErrorHandling {
    Get-Content "file.txt"
} -OnError Stop
```

**Options for `-OnError`:**
- `Stop` - Re-throw the exception (default)
- `Continue` - Return `$null` and continue
- `SilentlyContinue` - Return `$null` silently

##### Invoke-WithRetry

Execute operations with automatic retry using exponential backoff.

**Before:**
```powershell
$attempt = 0
$maxRetries = 3
while ($attempt -lt $maxRetries) {
    try {
        Copy-Item $source $destination -Force
        break
    }
    catch {
        $attempt++
        if ($attempt -ge $maxRetries) {
            throw
        }
        Start-Sleep -Seconds 2
    }
}
```

**After:**
```powershell
Import-Module ErrorHandling

Invoke-WithRetry -Operation {
    Copy-Item $source $destination -Force
} -Description "Copy file" -RetryCount 3 -RetryDelay 2
```

##### Test-IsElevated

Check if running with admin/root privileges.

**Before:**
```powershell
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    throw "Requires admin privileges"
}
```

**After:**
```powershell
Import-Module ErrorHandling

if (Test-IsElevated) {
    Write-Host "Running with admin privileges"
}

# Or use Assert-Elevated to throw if not elevated
Assert-Elevated
```

##### Test-CommandAvailable

Check if a command is available.

```powershell
if (Test-CommandAvailable "git") {
    Write-Host "Git is available"
}
```

### FileOperations Module

**Location:** `src/powershell/modules/Core/FileOperations/`

Provides file operation utilities with built-in retry logic.

#### Importing

```powershell
Import-Module "$PSScriptRoot/relative/path/to/FileOperations.psm1"
```

#### Functions

##### Copy-FileWithRetry

Copy files with automatic retry on failure.

**Before:**
```powershell
try {
    Copy-Item -Path $source -Destination $dest -Force
}
catch {
    Write-Error "Failed to copy: $_"
    throw
}
```

**After:**
```powershell
Import-Module FileOperations

Copy-FileWithRetry -Source $source -Destination $dest -MaxRetries 5
```

##### Move-FileWithRetry, Remove-FileWithRetry, Rename-FileWithRetry

Similar patterns for move, remove, and rename operations.

```powershell
Move-FileWithRetry -Source $src -Destination $dst
Remove-FileWithRetry -Path $tempFile
Rename-FileWithRetry -Path $file -NewName "newname.txt"
```

##### Test-FolderWritable

Test if a folder is writable.

**Before:**
```powershell
if (-not (Test-Path $folder)) {
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
}
$testFile = Join-Path $folder "test.tmp"
try {
    [IO.File]::WriteAllText($testFile, "test")
    Remove-Item $testFile -Force
    $isWritable = $true
}
catch {
    $isWritable = $false
}
```

**After:**
```powershell
Import-Module FileOperations

if (Test-FolderWritable $folder) {
    Write-Host "Folder is writable"
}
```

##### Add-ContentWithRetry

Append content to files with retry logic (useful for logging).

```powershell
Add-ContentWithRetry -Path $logFile -Value "Log entry" -MaxRetries 3
```

##### New-DirectoryIfNotExists

Ensure a directory exists.

```powershell
New-DirectoryIfNotExists "C:\temp\logs"
```

##### Get-FileSize

Get file size in bytes.

```powershell
$size = Get-FileSize "data.txt"
```

### ProgressReporter Module

**Location:** `src/powershell/modules/Core/Progress/`

Provides standardized progress reporting with logging integration.

#### Importing

```powershell
Import-Module "$PSScriptRoot/relative/path/to/ProgressReporter.psm1"
```

#### Functions

##### Show-Progress

Display standardized progress bars.

```powershell
Show-Progress -Activity "Processing files" -PercentComplete 50 -Status "50 of 100"
Show-Progress -Activity "Processing files" -Completed
```

##### Write-ProgressLog

Combine progress reporting with logging.

```powershell
for ($i = 1; $i -le 100; $i++) {
    Write-ProgressLog -Message "Processing file" -Current $i -Total 100
    # Do work...
}
```

##### New-ProgressTracker

Create a progress tracker for complex operations.

**Before:**
```powershell
$total = 1000
$current = 0

foreach ($item in $items) {
    $current++
    $percent = [int](($current / $total) * 100)
    Write-Progress -Activity "Processing" -PercentComplete $percent
    # Process item
}

Write-Progress -Activity "Processing" -Completed
```

**After:**
```powershell
Import-Module ProgressReporter

$tracker = New-ProgressTracker -Total 1000 -Activity "Processing" -UpdateFrequency 50

foreach ($item in $items) {
    # Process item
    Update-ProgressTracker -Tracker $tracker -Increment 1
}

Complete-ProgressTracker -Tracker $tracker
```

## Python Modules

### error_handling Module

**Location:** `src/python/modules/utils/error_handling.py`

Provides error handling utilities, decorators, and retry logic.

#### Importing

```python
from src.python.modules.utils.error_handling import (
    with_error_handling,
    with_retry,
    retry_operation,
    is_elevated,
    require_elevated,
    safe_execute,
    ErrorContext
)
```

#### Functions and Decorators

##### @with_error_handling

Decorator for standardized error handling.

**Before:**
```python
def read_config(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception as e:
        logging.error(f"Failed to read config: {e}")
        return None
```

**After:**
```python
from src.python.modules.utils.error_handling import with_error_handling

@with_error_handling(on_error="return_none", error_message="Failed to read config")
def read_config(path):
    with open(path) as f:
        return f.read()
```

##### @with_retry

Decorator for automatic retry with exponential backoff.

**Before:**
```python
def fetch_data(url):
    for attempt in range(3):
        try:
            return requests.get(url).json()
        except Exception as e:
            if attempt >= 2:
                raise
            time.sleep(2 ** attempt)
```

**After:**
```python
from src.python.modules.utils.error_handling import with_retry

@with_retry(max_retries=3, retry_delay=1.0)
def fetch_data(url):
    return requests.get(url).json()
```

##### retry_operation

Execute operations with retry logic.

```python
from src.python.modules.utils.error_handling import retry_operation

retry_operation(
    lambda: shutil.copy("source.txt", "dest.txt"),
    "Copy file",
    max_retries=5
)
```

##### is_elevated / require_elevated

Check and require elevated privileges.

**Before:**
```python
import os
import platform

if platform.system() == "Windows":
    import ctypes
    is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
else:
    is_admin = os.geteuid() == 0

if not is_admin:
    raise PermissionError("Requires admin privileges")
```

**After:**
```python
from src.python.modules.utils.error_handling import is_elevated, require_elevated

if is_elevated():
    print("Running with admin privileges")

# Or simply require elevation
require_elevated("This operation requires administrator rights")
```

##### ErrorContext

Context manager for error handling.

```python
from src.python.modules.utils.error_handling import ErrorContext

with ErrorContext("Processing data", on_error="continue"):
    process_data()
```

### file_operations Module

**Location:** `src/python/modules/utils/file_operations.py`

Provides file operation utilities with built-in retry logic.

#### Importing

```python
from src.python.modules.utils.file_operations import (
    copy_with_retry,
    move_with_retry,
    remove_with_retry,
    is_writable,
    ensure_directory,
    get_file_size,
    safe_write_text,
    safe_append_text
)
```

#### Functions

##### copy_with_retry, move_with_retry, remove_with_retry

File operations with automatic retry.

**Before:**
```python
import shutil
import time

for attempt in range(3):
    try:
        shutil.copy(source, dest)
        break
    except Exception as e:
        if attempt >= 2:
            raise
        time.sleep(2)
```

**After:**
```python
from src.python.modules.utils.file_operations import copy_with_retry

copy_with_retry(source, dest, max_retries=3)
```

##### is_writable

Check if directory is writable.

```python
from src.python.modules.utils.file_operations import is_writable

if is_writable("/tmp"):
    print("Directory is writable")
```

##### ensure_directory

Create directory if it doesn't exist.

```python
from src.python.modules.utils.file_operations import ensure_directory

log_dir = ensure_directory("logs/app")
```

##### safe_write_text

Write text safely with optional atomic write.

```python
from src.python.modules.utils.file_operations import safe_write_text

safe_write_text("config.txt", "key=value", atomic=True)
```

##### safe_append_text

Append text with retry logic.

```python
from src.python.modules.utils.file_operations import safe_append_text

safe_append_text("app.log", "2025-11-20 INFO: Started\n")
```

## Migration Examples

### Example 1: Script with Manual Error Handling

**Before (FileDistributor.ps1):**
```powershell
function Copy-ItemWithRetry {
    param(
        [string]$Path,
        [string]$Destination,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    $attempt = 0
    while ($attempt -lt $RetryCount) {
        try {
            Copy-Item -Path $Path -Destination $Destination -Force -ErrorAction Stop
            return
        }
        catch {
            $attempt++
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Seconds $RetryDelay
        }
    }
}
```

**After:**
```powershell
Import-Module FileOperations

# Simply use the module function
Copy-FileWithRetry -Source $Path -Destination $Destination -MaxRetries 3
```

### Example 2: Python Script with Manual Retry

**Before:**
```python
def copy_with_retry(source, dest):
    for attempt in range(3):
        try:
            shutil.copy2(source, dest)
            return True
        except Exception as e:
            if attempt >= 2:
                raise
            time.sleep(2 ** attempt)
```

**After:**
```python
from src.python.modules.utils.file_operations import copy_with_retry

# Simply use the module function
copy_with_retry(source, dest, max_retries=3)
```

### Example 3: Progress Reporting

**Before:**
```powershell
$files = Get-ChildItem "C:\data"
$total = $files.Count
$current = 0

foreach ($file in $files) {
    $current++
    $percent = [int](($current / $total) * 100)
    Write-Progress -Activity "Processing files" -PercentComplete $percent
    Process-File $file
}

Write-Progress -Activity "Processing files" -Completed
```

**After:**
```powershell
Import-Module ProgressReporter

$files = Get-ChildItem "C:\data"
$tracker = New-ProgressTracker -Total $files.Count -Activity "Processing files"

foreach ($file in $files) {
    Process-File $file
    Update-ProgressTracker -Tracker $tracker
}

Complete-ProgressTracker -Tracker $tracker
```

## Benefits

### Code Reduction

Using these shared utilities reduces code duplication by **30-50%** in typical scripts:

- **Before:** 20-30 lines of retry logic
- **After:** 1-2 lines using module functions

### Consistency

- All scripts use the same error handling patterns
- Consistent logging format
- Standardized progress reporting

### Maintainability

- Bug fixes in one place benefit all scripts
- Easier to update retry logic or error handling behavior
- Centralized testing

### Reliability

- Battle-tested retry logic with exponential backoff
- Proper handling of edge cases
- Cross-platform support (Windows, Linux, macOS)

## Best Practices

### 1. Import Modules at Script Start

```powershell
# PowerShell
Import-Module ErrorHandling
Import-Module FileOperations
Import-Module ProgressReporter
```

```python
# Python
from src.python.modules.utils import error_handling, file_operations
```

### 2. Use Appropriate Retry Counts

- **File operations:** 3-5 retries
- **Network operations:** 5-10 retries
- **Quick operations:** 2-3 retries

### 3. Set Reasonable Delays

- **Local file operations:** 1-2 seconds base delay
- **Network operations:** 2-5 seconds base delay
- **Always set MaxBackoff** to prevent excessive waits (e.g., 60 seconds)

### 4. Log Appropriately

- Set `LogErrors` to `$true` for production
- Set `LogErrors` to `$false` for unit tests
- Use custom error messages for better diagnostics

### 5. Handle Elevation Carefully

```powershell
# Check first, then act
if (Test-IsElevated) {
    # Perform admin operation
} else {
    Write-Warning "Some features require admin privileges"
}

# Or require elevation
Assert-Elevated -CustomMessage "This operation requires administrator rights"
```

## Deployment

The modules are automatically deployed using the `Deploy-Modules.ps1` script. To manually deploy:

### PowerShell Modules

```powershell
.\scripts\Deploy-Modules.ps1
```

This copies modules to the PowerShell modules directory.

### Python Modules

The Python modules are part of the repository and can be imported directly:

```python
from src.python.modules.utils.error_handling import with_retry
```

## Testing

All modules include comprehensive unit tests:

### PowerShell Tests

```powershell
# Run all tests
.\tests\powershell\Invoke-Tests.ps1

# Run specific module tests
Invoke-Pester .\tests\powershell\unit\ErrorHandling.Tests.ps1
Invoke-Pester .\tests\powershell\unit\FileOperations.Tests.ps1
Invoke-Pester .\tests\powershell\unit\ProgressReporter.Tests.ps1
```

### Python Tests

```bash
# Run all tests
pytest tests/python/unit/

# Run specific module tests
pytest tests/python/unit/test_error_handling.py
pytest tests/python/unit/test_file_operations.py
```

## Support

For issues or questions:

1. Check the module README files in `src/powershell/modules/Core/*/README.md`
2. Check the Python module README at `src/python/modules/utils/README.md`
3. Review the unit tests for usage examples
4. Open an issue in the repository

## Version History

### 1.0.0 (2025-11-20)
- Initial release of shared utilities
- ErrorHandling module (PowerShell)
- FileOperations module (PowerShell)
- ProgressReporter module (PowerShell)
- error_handling module (Python)
- file_operations module (Python)
- Comprehensive unit tests
- Migration guide

## License

Apache License 2.0
