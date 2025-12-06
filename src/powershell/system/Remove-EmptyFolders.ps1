<#
.SYNOPSIS
    Identifies and deletes all empty folders under a specified parent directory.

.DESCRIPTION
    This script recursively searches for empty folders under a given parent directory.
    It supports a dry-run mode to simulate deletions and logs all actions to a specified log file.
    For safety and portability, it **does not traverse reparse points** (symlinks/junctions) and never walks outside the specified root.

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

.EXAMPLE
    # UNC / network path (dry-run first for safety)
    .\Remove-EmptyFolders.ps1 -ParentDirectory "\\server\share\Data" -DryRun

.EXAMPLE
    # Invalid path handling (fails fast with an error)
    .\Remove-EmptyFolders.ps1 -ParentDirectory "Z:\DefinitelyNotHere"

.EXAMPLE
    # Read-only or permission-restricted directory (use Dry-Run to see what would happen)
    .\Remove-EmptyFolders.ps1 -ParentDirectory "C:\SomeReadOnlyShare" -DryRun

.EXAMPLE
    # Large-scale tree: start with Dry-Run to estimate scope before actual deletion
    .\Remove-EmptyFolders.ps1 -ParentDirectory "E:\MassiveArchive" -DryRun

.VERSION
2.0.0

CHANGELOG
## 2.0.0 - 2025-11-16
### Changed
- Migrated to PowerShellLoggingFramework.psm1 for standardized logging
- Removed custom Log function
- Replaced Log calls with Write-LogInfo, Write-LogError
- Replaced Write-Host with Write-LogInfo
- Replaced Write-Error with Write-LogError

## 1.3.1 — 2025-09-25
### Fixed
- **Empty-folder cleanup helper crash:** `Remove-EmptyFolders.ps1` referenced `WouldDeleteCount` without `$`, causing "The term 'WouldDeleteCount' is not recognized…" at runtime. Initialised and correctly referenced as `$WouldDeleteCount` (typed `[int]`).

## 1.3.0 — 2025-09-14
### Changed
- **Traversal safety:** Do not traverse reparse points (symlinks/junctions); enumeration is restricted to real directories under the specified root.
### Improved
- **Logging setup:** Simplified log initialization to a single call per artifact (directory/file) using .NET APIs.
- **Performance:** Combined the emptiness probe into a single, minimal `Get-ChildItem -Name` call.
### Added
- **Examples:** Added read-only/permission-restricted and large-scale tree scenarios.

## 1.2.0 — 2025-09-14
### Added
- **Examples:** Added UNC/network share usage and invalid-path example for clearer guidance.
### Improved
- **Dry-run clarity:** Track and report how many folders *would* be deleted (`$WouldDeleteCount`) instead of leaving the count at 0.
- **Path resolution readability:** Simplified `Resolve-PathWithFallback` to reduce repetition while keeping behavior.
- **Performance (emptiness probe):** Use `-File`/`-Directory` targeted checks to minimize enumeration work when probing directory contents.

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

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\FileSystem\FileSystem.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# ----- Dynamic defaults & path resolution -----
# Determine script root (works when executed as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

function New-Directory {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)
    if ([string]::IsNullOrWhiteSpace($DirectoryPath)) { return $false }
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-DirectoryIfMissing -Path $DirectoryPath -Force | Out-Null } catch { return $false }
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
    # Prefer user-specified path if its parent can be created.
    if ($UserPath) {
        $parent = Split-Path -Path $UserPath -Parent
        if (New-Directory -DirectoryPath $parent) { return $UserPath.Trim() }
    }
    # Otherwise, iterate ordered candidates and return the first whose parent can be created.
    $candidates = @(
        (Join-Path -Path $script:ScriptRoot -ChildPath $ScriptRelativePath),
        $WindowsDefaultPath,
        $TempFallbackPath
    )
    foreach ($cand in $candidates) {
        $p = Split-Path -Path $cand -Parent
        if (New-Directory -DirectoryPath $p) { return $cand }
    }
    return $TempFallbackPath
}

# Compute effective defaults
if (-not $ParentDirectory) { $ParentDirectory = (Get-Location).Path }

$localAppData = $env:LOCALAPPDATA
$tempRoot = $env:TEMP
$defaultLog_ScriptRel = 'logs\Remove-EmptyFolders.log'
$defaultLog_Windows = Join-Path -Path (Join-Path $localAppData 'DuplicateCleaner\logs') -ChildPath 'Remove-EmptyFolders.log'
$defaultLog_Temp = Join-Path -Path (Join-Path $tempRoot     'DuplicateCleaner\logs') -ChildPath 'Remove-EmptyFolders.log'

$LogFilePath = Resolve-PathWithFallback -UserPath $LogFilePath `
    -ScriptRelativePath $defaultLog_ScriptRel -WindowsDefaultPath $defaultLog_Windows -TempFallbackPath $defaultLog_Temp

# ----- Input validation -----
if (-not (Test-Path -LiteralPath $ParentDirectory -PathType Container)) {
    $msg = "Parent directory '$ParentDirectory' does not exist or is not a directory."
    Write-LogError "ERROR: $msg"
    exit 1
}

# Start logging
Write-LogInfo "Starting empty folder cleanup. Dry-run: $DryRun"

# Initialize counters
[int]$DeletedFolderCount = 0
[int]$WouldDeleteCount = 0

# Enumerate subdirectories without traversing reparse points (symlinks/junctions)
function Get-SubdirsNoReparse {
    param([Parameter(Mandatory = $true)][string]$Root)
    $list = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
    # seed with immediate children of root (skip reparse points)
    Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
        -not (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint))
    } | ForEach-Object { $stack.Push($_) }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $list.Add($d) | Out-Null
        # push children of $d that are real directories (no reparse points)
        Get-ChildItem -LiteralPath $d.FullName -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
            -not (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint))
        } | ForEach-Object { $stack.Push($_) }
    }
    return $list
}

# -------- Performance: bottom-up traversal, immediate-contents check only --------
# Collect subdirectories without reparse points, then sort deepest-first
$allDirs = Get-SubdirsNoReparse -Root $ParentDirectory `
| Sort-Object { ($_.FullName -split '[\\/]').Count } -Descending

foreach ($dir in $allDirs) {
    # Single-call emptiness probe: any immediate child (file/dir/link) means NOT empty
    $hasEntries = $null -ne (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue -Name | Select-Object -First 1)
    if (-not $hasEntries) {
        if ($DryRun) {
            Write-LogInfo "[Dry-Run] Empty folder found: $($dir.FullName)"
            $WouldDeleteCount++
        }
        else {
            try {
                Remove-Item -LiteralPath $dir.FullName -Force
                Write-LogInfo "Deleted empty folder: $($dir.FullName)"
                $DeletedFolderCount++
            }
            catch {
                Write-LogError "Failed to delete folder $($dir.FullName): $($_.Exception.Message)"
            }
        }
    }
}

# End logging
if ($DryRun) {
    $completionMessage = "Empty folder cleanup completed (dry-run). $WouldDeleteCount folder(s) would be deleted."
}
else {
    $completionMessage = "Empty folder cleanup completed. $DeletedFolderCount folder(s) were deleted."
}

Write-LogInfo $completionMessage
