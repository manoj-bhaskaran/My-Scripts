# ErrorHandling Module

## Overview

The ErrorHandling module provides standardized error handling, retry logic, and privilege checking utilities for PowerShell scripts. This module helps reduce code duplication and ensures consistent error handling across all scripts in the My-Scripts repository.

## Installation

The module is automatically deployed when using the `Deploy-Modules.ps1` script.

Manual import:
```powershell
Import-Module "$PSScriptRoot/path/to/ErrorHandling.psm1"
```

## Functions

### Invoke-WithErrorHandling

Executes a script block with standardized error handling.

**Parameters:**
- `ScriptBlock` - Code to execute
- `OnError` - Action to take on error: `Stop` (default), `Continue`, or `SilentlyContinue`
- `LogError` - Whether to log errors (default: `$true`)
- `ErrorMessage` - Custom error message prefix

**Example:**
```powershell
Invoke-WithErrorHandling {
    Get-Content "file.txt"
} -OnError Stop

$result = Invoke-WithErrorHandling {
    Get-Content "optional-file.txt"
} -OnError Continue -ErrorMessage "Failed to read optional file"
```

### Invoke-WithRetry

Executes a script block with automatic retry on failure using exponential backoff.

**Parameters:**
- `Operation` - Script block to execute
- `Description` - Description for logging
- `RetryDelay` - Base delay in seconds (default: 2)
- `RetryCount` - Maximum retry attempts (default: 3, 0 = unlimited)
- `MaxBackoff` - Maximum backoff delay in seconds (default: 60)
- `LogErrors` - Whether to log retry attempts (default: `$true`)

**Example:**
```powershell
Invoke-WithRetry -Operation {
    Copy-Item $source $dest -Force
} -Description "Copy file to destination" -RetryCount 5

Invoke-WithRetry -Operation {
    Remove-Item $path -Force
} -Description "Delete temporary file" -RetryDelay 1 -RetryCount 3
```

### Test-IsElevated

Checks if the script is running with elevated privileges (Administrator on Windows, root on Linux/macOS).

**Example:**
```powershell
if (Test-IsElevated) {
    Write-Host "Running with admin privileges"
} else {
    Write-Warning "Not running with admin privileges"
}
```

### Assert-Elevated

Throws an exception if the script is not running with elevated privileges.

**Parameters:**
- `CustomMessage` - Optional custom error message

**Example:**
```powershell
Assert-Elevated
# Script continues only if running as admin/root

Assert-Elevated -CustomMessage "This operation requires administrator rights"
```

### Test-CommandAvailable

Checks if a command, cmdlet, or executable is available in the current session.

**Parameters:**
- `CommandName` - Name of the command to test

**Example:**
```powershell
if (Test-CommandAvailable "git") {
    Write-Host "Git is available"
} else {
    Write-Warning "Git is not installed"
}
```

## Integration with Logging

The module automatically integrates with the `PowerShellLoggingFramework` module if available. If the logging framework is loaded, errors and warnings will be logged using `Write-LogError`, `Write-LogWarning`, and `Write-LogInfo`. Otherwise, it falls back to standard PowerShell cmdlets like `Write-Error` and `Write-Warning`.

## Migration Guide

### Before (Duplicated Error Handling)
```powershell
try {
    Copy-Item $source $destination -Force
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    throw
}
```

### After (Using ErrorHandling Module)
```powershell
Import-Module ErrorHandling

Invoke-WithErrorHandling {
    Copy-Item $source $destination -Force
} -OnError Stop
```

### Before (Manual Retry Logic)
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

### After (Using Invoke-WithRetry)
```powershell
Import-Module ErrorHandling

Invoke-WithRetry -Operation {
    Copy-Item $source $destination -Force
} -Description "Copy file" -RetryCount 3
```

### Before (Manual Elevation Check)
```powershell
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    throw "This script requires elevated privileges"
}
```

### After (Using ErrorHandling Module)
```powershell
Import-Module ErrorHandling

Assert-Elevated
```

## Version History

### 1.0.0 (2025-11-20)
- Initial release
- `Invoke-WithErrorHandling` function
- `Invoke-WithRetry` function with exponential backoff
- `Test-IsElevated` function
- `Assert-Elevated` function
- `Test-CommandAvailable` function
- Cross-platform support (Windows, Linux, macOS)
- Optional integration with PowerShellLoggingFramework

## License

Apache License 2.0
