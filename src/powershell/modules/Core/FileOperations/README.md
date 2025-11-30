# FileOperations Module

## Overview

The FileOperations module provides file operation utilities with built-in retry logic for PowerShell scripts. All file operations (copy, move, remove, rename) automatically handle transient failures like file locks or network issues using exponential backoff retry logic.

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
