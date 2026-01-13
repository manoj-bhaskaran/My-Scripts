<#
.SYNOPSIS
    Wrapper script for Drive Space Monitor scheduled task.

.DESCRIPTION
    This script loads environment variables from .env and executes the
    drive_space_monitor.py Python script. Designed for Task Scheduler.

.PARAMETER Threshold
    Storage usage threshold percentage (0-100). Default: 80

.PARAMETER Debug
    Enable debug logging in the Python script.

.EXAMPLE
    .\Invoke-DriveSpaceMonitor.ps1 -Threshold 80

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Created: 2026-01-13

    This wrapper ensures environment variables are loaded before Python execution,
    which is necessary for Task Scheduler since it doesn't inherit user environment.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(0, 100)]
    [int]$Threshold = 80,

    [Parameter()]
    [switch]$Debug
)

# Determine script root (repository root)
$scriptRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

# Load environment variables from .env
$envFile = Join-Path $scriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()

        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -eq '') {
            return
        }

        # Parse VAR=value
        if ($line -match '^([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove surrounding quotes if present
            $value = $value -replace '^["\'']|["\'']$', ''

            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    Write-Host "Environment loaded from $envFile" -ForegroundColor Green
}
else {
    Write-Warning ".env file not found at: $envFile"
    Write-Warning "Google Drive credentials path may not be configured."
}

# Find Python executable
$pythonExe = $null

# Check common Python locations in order of preference
$pythonPaths = @(
    # Virtual environment in repository root (most common)
    (Join-Path $scriptRoot "venv\Scripts\python.exe"),
    (Join-Path $scriptRoot ".venv\Scripts\python.exe"),
    # Fallback: hardcoded common locations
    "D:\My Scripts\venv\Scripts\python.exe",
    "$env:USERPROFILE\Documents\Scripts\venv\Scripts\python.exe",
    # System Python (last resort)
    "python.exe",
    "python3.exe",
    # Windows Store Python
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe"
)

foreach ($path in $pythonPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $pythonExe = $path
        break
    }
    elseif ($path -notlike "*\*" -and $path -notlike "*:*") {
        # For bare commands like "python.exe", check if they're in PATH
        $found = Get-Command $path -ErrorAction SilentlyContinue
        if ($found) {
            $pythonExe = $path
            break
        }
    }
}

if (-not $pythonExe) {
    Write-Error "Python executable not found. Please install Python or update the script."
    exit 1
}

Write-Host "Using Python: $pythonExe" -ForegroundColor Cyan

# Build Python script path
$pythonScript = Join-Path $scriptRoot "src\python\cloud\drive_space_monitor.py"

if (-not (Test-Path $pythonScript)) {
    Write-Error "Python script not found: $pythonScript"
    exit 1
}

# Build arguments
$arguments = @(
    $pythonScript,
    "--threshold", $Threshold
)

if ($Debug) {
    $arguments += "--debug"
}

# Execute Python script
Write-Host "Executing: $pythonExe $($arguments -join ' ')" -ForegroundColor Cyan
& $pythonExe @arguments

# Exit with Python's exit code
exit $LASTEXITCODE
