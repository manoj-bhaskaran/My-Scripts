<#
.SYNOPSIS
    Identifies and deletes all empty folders under a specified parent directory.

.DESCRIPTION
    This script recursively searches for empty folders under a given parent directory.
    It supports a dry-run mode to simulate deletions and logs all actions to a specified log file.

.PARAMETER ParentDirectory
    The parent directory to search for empty folders. If not provided, defaults to the current
    working directory (Get-Location).

.PARAMETER LogFilePath
    The path to the log file. If not provided, the script resolves a writable path using this order
    (creating folders as needed):
      1) script-root relative: .\logs\Remove-EmptyFolders.log
      2) %LOCALAPPDATA%\DuplicateCleaner\logs\Remove-EmptyFolders.log
      3) %TEMP%\DuplicateCleaner\logs\Remove-EmptyFolders.log

.PARAMETER DryRun
    If specified, simulate deletions without actually deleting folders.

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -ParentDirectory "D:\MyFolder" -LogFilePath "D:\Logs\cleanup.log"

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -ParentDirectory "D:\MyFolder" -LogFilePath "D:\Logs\cleanup.log" -DryRun

.EXAMPLE
    .\Remove-EmptyFolders.ps1

.VERSION
1.1.0

CHANGELOG
## 1.1.0 — 2025-09-14
### Changed
- **Defaults (portability):** Removed hard-coded user-specific defaults. `-ParentDirectory` now defaults to the current
  directory; `-LogFilePath` is resolved to script-root `.\logs\Remove-EmptyFolders.log`, then `%LOCALAPPDATA%`, then `%TEMP%`
  (directories auto-created).
### Added
- **Input validation:** Fail early if `-ParentDirectory` does not exist or isn’t a directory; ensure log destination can be created.
### Improved
- **Performance:** Use a bottom-up traversal and check **immediate** contents only, eliminating redundant per-folder recursive scans.

## 1.0.0 — 2025-09-14
### Added
- Initial version to identify and delete empty folders with optional dry-run.
#>

param (
    [string]$ParentDirectory = $null,
    [string]$LogFilePath = $null,
    [switch]$DryRun
)

# ----- Dynamic defaults & path resolution -----
# Determine script root (works when executed as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

function New-Directory {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)
    if ([string]::IsNullOrWhiteSpace($DirectoryPath)) { return $false }
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null } catch { return $false }
    }
    return (Test-Path -LiteralPath $DirectoryPath)
}

function Resolve-PathWithFallback {
    param(
        [string]$UserPath,
        [Parameter(Mandatory = $true)][string]$ScriptRelativePath,
        [Parameter(Mandatory = $true)][string]$WindowsDefaultPath,
        [Parameter(Mandatory = $true)][string]$TempFallbackPath
    )
    # 1) User-provided
    if ($UserPath) {
        $parent = Split-Path -Path $UserPath -Parent
        if (New-Directory -DirectoryPath $parent) { return $UserPath.Trim() }
    }
    # 2) Script-root relative
    $scriptCandidate = Join-Path -Path $script:ScriptRoot -ChildPath $ScriptRelativePath
    $parent = Split-Path -Path $scriptCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $scriptCandidate }
    # 3) Windows default (LOCALAPPDATA)
    $winCandidate = $WindowsDefaultPath
    $parent = Split-Path -Path $winCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $winCandidate }
    # 4) TEMP fallback
    $tempCandidate = $TempFallbackPath
    $parent = Split-Path -Path $tempCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $tempCandidate }
    return $TempFallbackPath
}

# Compute effective defaults
if (-not $ParentDirectory) { $ParentDirectory = (Get-Location).Path }

$localAppData = $env:LOCALAPPDATA
$tempRoot     = $env:TEMP
$defaultLog_ScriptRel = 'logs\Remove-EmptyFolders.log'
$defaultLog_Windows   = Join-Path -Path (Join-Path $localAppData 'DuplicateCleaner\logs') -ChildPath 'Remove-EmptyFolders.log'
$defaultLog_Temp      = Join-Path -Path (Join-Path $tempRoot     'DuplicateCleaner\logs') -ChildPath 'Remove-EmptyFolders.log'

$LogFilePath = Resolve-PathWithFallback -UserPath $LogFilePath `
    -ScriptRelativePath $defaultLog_ScriptRel -WindowsDefaultPath $defaultLog_Windows -TempFallbackPath $defaultLog_Temp
 
# Initialize logging
function Initialize-LogDestination {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $dir = Split-Path -Parent -Path $Path
        if ([string]::IsNullOrWhiteSpace($dir)) { return }
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType File -Path $Path -Force | Out-Null
        }
    } catch {
        Write-Error "Failed to validate/create log destination '$Path'. Error: $($_.Exception.Message)"
        exit 2
    }
}
Initialize-LogDestination -Path $LogFilePath

function Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$($timestamp): $Message" | Out-File -FilePath $LogFilePath -Append
}

# ----- Input validation -----
if (-not (Test-Path -LiteralPath $ParentDirectory -PathType Container)) {
    $msg = "Parent directory '$ParentDirectory' does not exist or is not a directory."
    Log "ERROR: $msg"
    Write-Error $msg
    exit 1
}

# Start logging
Log "Starting empty folder cleanup. Dry-run: $DryRun"

# Initialize a counter for deleted folders
$DeletedFolderCount = 0

# -------- Performance: bottom-up traversal, immediate-contents check only --------
# Sort directories deepest-first so that parents are reconsidered after children go away.
$allDirs = Get-ChildItem -LiteralPath $ParentDirectory -Directory -Recurse -Force `
          | Sort-Object { ($_.FullName -split '[\\/]').Count } -Descending

foreach ($dir in $allDirs) {
    # Check if directory is empty by probing for any immediate children
    $hasEntries = Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hasEntries) {
        if ($DryRun) {
            Log "[Dry-Run] Empty folder found: $($dir.FullName)"
        } else {
            try {
                Remove-Item -LiteralPath $dir.FullName -Force
                Log "Deleted empty folder: $($dir.FullName)"
                $DeletedFolderCount++
            } catch {
                Log "Failed to delete folder $($dir.FullName): $($_.Exception.Message)"
            }
        }
    }
}

# End logging
if ($DryRun) {
    $completionMessage = "Empty folder cleanup completed. Dry-run mode: No folders were deleted. $DeletedFolderCount folders will be deleted if executed in normal mode."
} else {
    $completionMessage = "Empty folder cleanup completed. $DeletedFolderCount folders were deleted."
}

Log $completionMessage
Write-Host $completionMessage
