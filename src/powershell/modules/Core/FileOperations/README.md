# FileOperations Module

## Overview

The FileOperations module provides file operation utilities with built-in retry logic for PowerShell scripts. All file operations (copy, move, remove, rename) automatically handle transient failures like file locks or network issues using exponential backoff retry logic.

## Quick Start
```powershell
Import-Module FileOperations
Copy-FileWithRetry -Source "C:\source\file.txt" -Destination "D:\dest\file.txt"
```

## Common Use Cases
1. **Resilient file copies between drives** – handle transient network or lock issues automatically.
   ```powershell
   Copy-FileWithRetry -Source \\share\data\report.csv -Destination "D:\Reports\report.csv" -MaxRetries 5
   ```
2. **Transactional moves when archiving** – ensure items land in archive folders even if storage is briefly unavailable.
   ```powershell
   Move-FileWithRetry -Source "C:\temp\logs.zip" -Destination "\\archive\logs\logs.zip" -RetryDelay 1 -MaxBackoff 30
   ```
3. **Safe cleanup jobs** – remove temp files while tolerating antivirus or indexing locks.
   ```powershell
   Remove-FileWithRetry -Path "$env:TEMP\*.tmp" -MaxRetries 6
   ```
4. **Pre-flight folder checks in deployment scripts** – ensure output folders exist and are writable.
   ```powershell
   if (-not (Test-FolderWritable "C:\deploy\output")) { throw "Output folder not writable" }
   ```
5. **Append-only logging with retry** – write telemetry without losing entries during brief I/O interruptions.
   ```powershell
   Add-ContentWithRetry -Path "C:\logs\sync.log" -Value "$(Get-Date -Format o) :: sync started" -Encoding UTF8
   ```

## Parameters
- **Copy-FileWithRetry / Move-FileWithRetry**
  - `Source` (string, required): Path to the existing file.
  - `Destination` (string, required): Target path for the copy/move operation.
  - `Force` (bool, default `$true`): Overwrite destination if it exists.
  - `MaxRetries` (int, default `3`): Number of retry attempts before failing.
  - `RetryDelay` (int, default `2`): Base delay in seconds between retries.
  - `MaxBackoff` (int, default `60`): Maximum backoff delay in seconds.
- **Remove-FileWithRetry**
  - `Path` (string, required): File path or pattern to remove.
  - `MaxRetries`, `RetryDelay`, `MaxBackoff`: Same retry settings as copy/move.
- **Rename-FileWithRetry**
  - `Path` (string, required): Existing file path.
  - `NewName` (string, required): New file name (not full path).
  - `MaxRetries`, `RetryDelay`, `MaxBackoff`: Retry settings.
- **Test-FolderWritable**
  - `Path` (string, required): Folder to validate or create.
  - `SkipCreate` (bool, default `$false`): Do not create the folder if missing.
- **Add-ContentWithRetry**
  - `Path` (string, required): File to append to.
  - `Value` (string, required): Content to add.
  - `Encoding` (string, default `"UTF8"`): File encoding for new entries.
  - `MaxRetries`, `RetryDelay`, `MaxBackoff`: Retry settings.
- **New-DirectoryIfNotExists**
  - `Path` (string, required): Directory to create when missing.
- **Get-FileSize**
  - `Path` (string, required): File to measure.

## Error Handling
```powershell
try {
    Copy-FileWithRetry -Source "C:\data\input.csv" -Destination "D:\staging\input.csv" -MaxRetries 5 -RetryDelay 1
}
catch {
    Write-Error "Failed after retries: $_"
    # Optionally log to a central handler here
}
```

## Performance Considerations
- Built-in exponential backoff prevents thrashing when files are locked; tune `RetryDelay`/`MaxBackoff` for congested shares.
- Use `Force:$false` on copy/move when overwriting large files is costly and avoidable.
- Prefer `Add-ContentWithRetry` for append-heavy logging instead of reopening files manually.
- `Test-FolderWritable` can create missing folders; disable with `-SkipCreate` to avoid extra I/O during read-only health checks.

## Installation

The module is automatically deployed when using the `Deploy-Modules.ps1` script.

Manual import:
```powershell
Import-Module "$PSScriptRoot/path/to/FileOperations.psm1"
```

## Dependencies

- **ErrorHandling** module (optional but recommended) - Provides retry logic via `Invoke-WithRetry`

## Functions

### Copy-FileWithRetry

Copies a file with automatic retry on failure.

**Parameters:**
- `Source` - Source file path (must exist)
- `Destination` - Destination file path
- `Force` - Overwrite destination if exists (default: `$true`)
- `MaxRetries` - Maximum retry attempts (default: 3)
- `RetryDelay` - Base delay between retries in seconds (default: 2)
- `MaxBackoff` - Maximum backoff delay in seconds (default: 60)

**Example:**
```powershell
Copy-FileWithRetry -Source "C:\source\file.txt" -Destination "D:\dest\file.txt"
Copy-FileWithRetry -Source $src -Destination $dst -MaxRetries 5 -RetryDelay 1
```

### Move-FileWithRetry

Moves a file with automatic retry on failure.

**Parameters:**
Same as `Copy-FileWithRetry`

**Example:**
```powershell
Move-FileWithRetry -Source "C:\temp\file.txt" -Destination "D:\archive\file.txt"
```

### Remove-FileWithRetry

Removes a file with automatic retry on failure.

**Parameters:**
- `Path` - Path to the file to remove
- `MaxRetries` - Maximum retry attempts (default: 3)
- `RetryDelay` - Base delay between retries in seconds (default: 2)
- `MaxBackoff` - Maximum backoff delay in seconds (default: 60)

**Example:**
```powershell
Remove-FileWithRetry -Path "C:\temp\file.txt"
Remove-FileWithRetry -Path $tempFile -MaxRetries 5
```

### Rename-FileWithRetry

Renames a file with automatic retry on failure.

**Parameters:**
- `Path` - Path to the file to rename
- `NewName` - New name for the file (not full path, just the name)
- `MaxRetries` - Maximum retry attempts (default: 3)
- `RetryDelay` - Base delay between retries in seconds (default: 2)
- `MaxBackoff` - Maximum backoff delay in seconds (default: 60)

**Example:**
```powershell
Rename-FileWithRetry -Path "C:\temp\oldname.txt" -NewName "newname.txt"
```

### Test-FolderWritable

Tests if a folder exists and is writable.

**Parameters:**
- `Path` - Path to the folder to test
- `SkipCreate` - Don't create the folder if it doesn't exist (default: `$false`)

**Example:**
```powershell
if (Test-FolderWritable "C:\temp") {
    Write-Output "Folder is writable"
}

if (Test-FolderWritable "C:\logs" -SkipCreate) {
    Write-Output "Folder exists and is writable"
}
```

### Add-ContentWithRetry

Appends content to a file with retry logic.

**Parameters:**
- `Path` - Path to the file
- `Value` - Content to append
- `MaxRetries` - Maximum retry attempts (default: 3)
- `RetryDelay` - Base delay between retries in seconds (default: 1)
- `MaxBackoff` - Maximum backoff delay in seconds (default: 30)
- `Encoding` - File encoding (default: "UTF8")

**Example:**
```powershell
Add-ContentWithRetry -Path "C:\logs\app.log" -Value "Log entry"
Add-ContentWithRetry -Path $logFile -Value $message -MaxRetries 5
```

### New-DirectoryIfNotExists

Creates a directory if it doesn't exist.

**Parameters:**
- `Path` - Path to the directory

**Example:**
```powershell
New-DirectoryIfNotExists "C:\temp\logs"

if (New-DirectoryIfNotExists $path) {
    Write-Output "Directory was created"
} else {
    Write-Output "Directory already existed"
}
```

### Get-FileSize

Gets the size of a file in bytes.

**Parameters:**
- `Path` - Path to the file

**Example:**
```powershell
$size = Get-FileSize "C:\temp\file.txt"
Write-Output "File size: $size bytes"
```

## Migration Guide

### Before (Manual Copy)
```powershell
try {
    Copy-Item -Path $source -Destination $dest -Force
}
catch {
    Write-Error "Failed to copy: $_"
    throw
}
```

### After (Using FileOperations)
```powershell
Import-Module FileOperations

Copy-FileWithRetry -Source $source -Destination $dest
```

### Before (Manual Retry Logic)
```powershell
$attempt = 0
while ($attempt -lt 3) {
    try {
        Copy-Item $src $dst -Force
        break
    }
    catch {
        $attempt++
        if ($attempt -ge 3) { throw }
        Start-Sleep -Seconds 2
    }
}
```

### After (Using FileOperations)
```powershell
Import-Module FileOperations

Copy-FileWithRetry -Source $src -Destination $dst -MaxRetries 3
```

### Before (Manual Writable Check)
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

### After (Using FileOperations)
```powershell
Import-Module FileOperations

$isWritable = Test-FolderWritable $folder
```

## Retry Behavior

All retry functions use **exponential backoff** with the following formula:

```
delay = min(RetryDelay * 2^(attempt-1), MaxBackoff)
```

Example with `RetryDelay=2` and `MaxBackoff=60`:
- Attempt 1: 2 seconds
- Attempt 2: 4 seconds
- Attempt 3: 8 seconds
- Attempt 4: 16 seconds
- Attempt 5: 32 seconds
- Attempt 6+: 60 seconds (capped at MaxBackoff)

## Error Handling

- All functions throw on final failure after exhausting retries
- Transient failures are logged as warnings (if logging framework is available)
- Final success after retries is logged as informational
- File not found errors throw immediately without retry

## Version History

### 1.0.0 (2025-11-20)
- Initial release
- `Copy-FileWithRetry` function
- `Move-FileWithRetry` function
- `Remove-FileWithRetry` function
- `Rename-FileWithRetry` function
- `Test-FolderWritable` function
- `Add-ContentWithRetry` function
- `New-DirectoryIfNotExists` function
- `Get-FileSize` function
- Integration with ErrorHandling module
- Exponential backoff retry logic

## License

Apache License 2.0
