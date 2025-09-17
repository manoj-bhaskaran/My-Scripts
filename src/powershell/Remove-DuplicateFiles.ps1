<#
.SYNOPSIS
    Script to identify and delete duplicate files in a specified directory.

.DESCRIPTION
    This script scans a specified parent directory for duplicate files using a
    **content hash (SHA-256)** to ensure true duplicate detection. It retains
    one file from each group of duplicates and deletes the rest. Actions are
    logged to a specified log file. The script validates/creates the log
    directory, performs basic permission/access checks before deletion,
    and reports duplicate counts accurately (extras beyond the retained file).
    It also avoids loading all files into memory at once by using a streaming,
    two-pass enumeration (count sizes first, then hash only size-collisions).

    .PARAMETER ParentDirectory
    The parent directory to scan for duplicate files. If not provided, defaults to the current
    working directory (Get-Location).

.PARAMETER LogFilePath
    The path to the log file where actions will be recorded. If not provided, the script
    resolves a writable path using this order (creating folders as needed):
      1) script-root relative: .\logs\Remove-DuplicateFiles.log
      2) %LOCALAPPDATA%\DuplicateCleaner\logs\Remove-DuplicateFiles.log
      3) %TEMP%\DuplicateCleaner\logs\Remove-DuplicateFiles.log

.PARAMETER DryRun
    If specified, the script will only log the actions it would take without actually deleting any files.

.EXAMPLE
    .\Remove-DuplicateFiles.ps1 -ParentDirectory "C:\MyFiles" -LogFilePath "C:\Logs\DuplicateLog.log" -DryRun

.VERSION
1.2.1

CHANGELOG
## 1.2.1 — 2025-09-14
### Fixed
- **Docs:** `.PARAMETER LogFilePath` now documents dynamic default resolution to script-root, `%LOCALAPPDATA%`, then `%TEMP%`.
- **Warnings:** Removed duplicate `$script:Warnings++` and corrected message in `Test-CanAccessFile`.
### Improved
- **Performance:** `-PrioritizeSmallFirst` no longer re-enumerates the entire tree per size; builds a single collision index in one streaming pass, then processes sizes ascending.
- **Maintainability:** Added inline comments clarifying `$script:` globals as script-scoped counters/caches.

## 1.2.0 — 2025-09-14
### Fixed
- **Undefined variable:** deletion loop now iterates over computed duplicate buckets (previously referenced `$DuplicateGroups`, which was undefined).
### Added
- **Progress & UX:** `-ShowProgress` and `-ProgressInterval` (default 500) show progress during pass 1 (counting) and pass 2 (hashing). Optional `-PrioritizeSmallFirst` hashes smaller collision buckets first for faster perceived responsiveness.
- **Error handling:** fail-fast if the log file cannot be written; robust logging with guarded writes; end-of-run summary of critical failures and non-fatal warnings. Returns non-zero exit when critical logging cannot be established.
### Improved
- **Performance visibility:** pass-2 progress computed from the number of files in size-collision buckets; hashing counters surfaced.

## 1.1.0 — 2025-09-14
### Changed
- **Defaults (UX):** Removed hard-coded, user-specific defaults. `-ParentDirectory` now defaults to the current
  directory; `-LogFilePath` is resolved to script-root `.\logs\Remove-DuplicateFiles.log`, then `%LOCALAPPDATA%`,
  then `%TEMP%` (directories created if missing).
### Improved
- **Performance:** Replaced single-pass, in-memory grouping with a **streaming two-pass** approach:
  1) count files by size, 2) re-enumerate and hash **only** size-collision files.
  Duplicates are bucketed on-demand so only duplicate sets are retained in memory.

## 1.0.x — Rollup (through 2025-09-14)

### Added
- Initial script to locate duplicate files and delete all but one in each group.
- **Safety & operability:**
  - Log directory validation/creation for `-LogFilePath` (creates parent folders if missing).
  - Permission/access checks before deletion:
    - Attempts to open the file for read/write to detect locks/ACL issues.
    - Probes delete capability in the parent directory via a temporary file (cached per-directory).
  - Skips deletion and logs a warning if checks fail.

### Changed / Improved
- **Duplicate detection is now content-based:** uses SHA-256 hashing instead of metadata (`Name`, `Extension`, `Length`, `LastWriteTime`) to eliminate false positives/negatives.
- **Performance:** pre-groups by file size and hashes only files with size collisions, reducing unnecessary hashing work.

### Fixed
- Statistics correctness: `TotalDuplicatesFound` now counts only the *extra* files beyond the one retained in each duplicate set.
- Trailing space removed from the default `-LogFilePath` value.

#>

param (
    [string]$ParentDirectory = $null,
    [string]$LogFilePath = $null,
    [switch]$DryRun,
    [switch]$ShowProgress,
    [int]$ProgressInterval = 500,
    [switch]$PrioritizeSmallFirst
)

# ----- Dynamic defaults & path resolution -----
# Script-scoped: script root is used by path-resolution helpers and remains
# constant for the lifetime of this script invocation.
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

function New-Directory {
    param([Parameter(Mandatory=$true)][string]$DirectoryPath)
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null } catch { }
 }
    return (Test-Path -LiteralPath $DirectoryPath)
}

function Resolve-PathWithFallback {
    param(
        [string]$UserPath,
        [Parameter(Mandatory=$true)][string]$ScriptRelativePath,
        [Parameter(Mandatory=$true)][string]$WindowsDefaultPath,
        [Parameter(Mandatory=$true)][string]$TempFallbackPath
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
$defaultLog_ScriptRel = 'logs\Remove-DuplicateFiles.log'
$defaultLog_Windows   = Join-Path -Path (Join-Path $localAppData 'DuplicateCleaner\logs') -ChildPath 'Remove-DuplicateFiles.log'
$defaultLog_Temp      = Join-Path -Path (Join-Path $tempRoot     'DuplicateCleaner\logs') -ChildPath 'Remove-DuplicateFiles.log'

$LogFilePath = Resolve-PathWithFallback -UserPath $LogFilePath `
    -ScriptRelativePath $defaultLog_ScriptRel -WindowsDefaultPath $defaultLog_Windows -TempFallbackPath $defaultLog_Temp
 

# Ensure the log directory exists and log file is created
function Initialize-LogDestination {
    param([Parameter(Mandatory=$true)][string]$Path)
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
        Write-Warning "Failed to validate/create log destination '$Path'. Error: $($_.Exception.Message)"
    }
}
Initialize-LogDestination -Path $LogFilePath

# --- Logging & error counters ---
# Script-scoped counters used across functions for end-of-run summary and
# fail-fast decisions when logging is not writable.
$script:CriticalErrors = 0
$script:Warnings       = 0
$script:HashFailures   = 0

function Test-LogWritable {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $probe = "[{0}] __log_writable_probe__" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        $probe | Out-File -FilePath $Path -Append -ErrorAction Stop
        return $true
    } catch {
        Write-Error "Cannot write to log file '$Path'. Error: $($_.Exception.Message)"
        return $false
    }
}
if (-not (Test-LogWritable -Path $LogFilePath)) {
    # Fail fast: we require a writable log for auditability
    exit 2
}

# Log function (guarded)
function Log {
    param ([string]$Message)
    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$($Timestamp): $Message" | Out-File -FilePath $LogFilePath -Append -ErrorAction Stop
    } catch {
        $script:CriticalErrors++
        Write-Error "Logging failure: $($_.Exception.Message)"
    }
}

# ---- Permission / access checks prior to deletion ----
# Script-scoped cache: directory delete-permission probes are cached to avoid
# repeated temp-file creation in the same directory during batch deletions.
$script:DirDeleteProbeCache = @{}

function Test-CanAccessFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None)
        $fs.Close()
        return $true
    } catch {
        # Count once and log a file-specific warning (the DirectoryPath variable
        # is not in scope here).
        $script:Warnings++
        Log "WARN: File not accessible for read/write: '$Path'. Error: $($_.Exception.Message)"
        return $false
    }
}

function Test-CanDeleteInDirectory {
    param([Parameter(Mandatory=$true)][string]$DirectoryPath)
    if ($script:DirDeleteProbeCache.ContainsKey($DirectoryPath)) {
        return $script:DirDeleteProbeCache[$DirectoryPath]
    }
    $probeOk = $false
    try {
        $tmp = Join-Path -Path $DirectoryPath -ChildPath ('.__permtest__{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType File -Path $tmp -Force | Out-Null
        Remove-Item -LiteralPath $tmp -Force
        $probeOk = $true
    } catch {
        Log "WARN: No write/delete permission in directory '$DirectoryPath'. Error: $($_.Exception.Message)"
        $probeOk = $false
    }
    $script:DirDeleteProbeCache[$DirectoryPath] = $probeOk
    return $probeOk
}

# Compute SHA-256 for a file (returns $null on failure and logs the error)
function Get-ContentHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        $script:HashFailures++
        Log "ERROR: Failed to compute hash for: $Path. Error: $_"
        return $null
    }
}


# Validate the parent directory
if (-not (Test-Path $ParentDirectory)) {
    Log "ERROR: Parent directory '$ParentDirectory' does not exist."
    Write-Error "Parent directory '$ParentDirectory' does not exist."
    exit 1
}

Log "Starting duplicate file scan in directory: $ParentDirectory"
Log "Duplicate detection strategy: pre-group by file size, then compare SHA-256 content hashes."

# -------- Streaming two-pass enumeration to reduce memory pressure --------
# Pass 1: count files by size (store only counts)
$sizeCounts = @{}
$pass1Count = 0
Get-ChildItem -Path $ParentDirectory -Recurse -File | ForEach-Object {
    $len = $_.Length
    if ($sizeCounts.ContainsKey($len)) { $sizeCounts[$len]++ } else { $sizeCounts[$len] = 1 }
    $pass1Count++
    if ($ShowProgress -and ($pass1Count % $ProgressInterval -eq 0)) {
        Write-Progress -Activity "Pass 1/2: Scanning files" -Status "Counted $pass1Count file(s)..." -Id 1
    }
}
if ($ShowProgress) { Write-Progress -Activity "Pass 1/2: Scanning files" -Status "Complete" -Completed -Id 1 }

# Pass 2: hash only files in size-collision buckets; retain in-memory only duplicate sets
$seenByHash     = @{} # hash -> first FileInfo seen
$dupeBuckets    = @{} # hash -> [FileInfo[]] (includes first once a dup is found)

# Compute total files to hash for progress (sum of collision bucket sizes)
$collisionTotal = 0
foreach ($k in $sizeCounts.Keys) { if ($sizeCounts[$k] -gt 1) { $collisionTotal += $sizeCounts[$k] } }
$hashedSoFar = 0

if ($PrioritizeSmallFirst) {
    # Build a single collision index in one streaming pass to avoid re-enumerating
    # the entire tree for every distinct size.
    $collisionIndex = @{}  # length -> [FileInfo[]]
    Get-ChildItem -Path $ParentDirectory -Recurse -File | ForEach-Object {
        $len = $_.Length
        if ($sizeCounts[$len] -gt 1) {
            if (-not $collisionIndex.ContainsKey($len)) {
                $collisionIndex[$len] = New-Object System.Collections.Generic.List[System.IO.FileInfo]
            }
            [void]$collisionIndex[$len].Add($_)
        }
    }

    # Process from smallest collision size upward for better perceived responsiveness
    $collisionSizes = $collisionIndex.Keys | Sort-Object
    foreach ($len in $collisionSizes) {
        foreach ($file in $collisionIndex[$len]) {
            $h = Get-ContentHash -Path $file.FullName
            if ($null -ne $h) {
                if ($seenByHash.ContainsKey($h)) {
                    if (-not $dupeBuckets.ContainsKey($h)) {
                        $dupeBuckets[$h] = @($seenByHash[$h])
                    }
                    $dupeBuckets[$h] += $file
                } else {
                    $seenByHash[$h] = $file
                }
            }
            $hashedSoFar++
            if ($ShowProgress -and ($hashedSoFar % $ProgressInterval -eq 0)) {
                $pct = if ($collisionTotal -gt 0) { [int](($hashedSoFar / $collisionTotal) * 100) } else { 100 }
                Write-Progress -Activity "Pass 2/2: Hashing size-collision files" -Status "Hashed $hashedSoFar / $collisionTotal" -PercentComplete $pct -Id 2
            }
        }
    }
} else {
    # Default: single streaming enumeration, only hash files in collision buckets
    Get-ChildItem -Path $ParentDirectory -Recurse -File | ForEach-Object {
        if ($sizeCounts[$_.Length] -gt 1) {
            $h = Get-ContentHash -Path $_.FullName
            if ($null -ne $h) {
                if ($seenByHash.ContainsKey($h)) {
                    if (-not $dupeBuckets.ContainsKey($h)) {
                        # create bucket and add the first occurrence
                        $dupeBuckets[$h] = @($seenByHash[$h])
                    }
                    # add the new duplicate occurrence
                    $dupeBuckets[$h] += $_
                } else {
                    $seenByHash[$h] = $_
                }
            }
            $hashedSoFar++
            if ($ShowProgress -and ($hashedSoFar % $ProgressInterval -eq 0)) {
                $pct = if ($collisionTotal -gt 0) { [int](($hashedSoFar / $collisionTotal) * 100) } else { 100 }
                Write-Progress -Activity "Pass 2/2: Hashing size-collision files" -Status "Hashed $hashedSoFar / $collisionTotal" -PercentComplete $pct -Id 2
            }
        }
    }
}
if ($ShowProgress) { Write-Progress -Activity "Pass 2/2: Hashing size-collision files" -Status "Complete" -Completed -Id 2 }

# Initialize counters for summary statistics
$TotalDuplicatesFound = 0
$TotalDeleted = 0
$TotalRetained = 0

# Iterate over hash-equal duplicate buckets (fixed undefined variable issue)
foreach ($filesInGroup in $dupeBuckets.Values) {

    # Count only the extras beyond the one we retain
    if ($filesInGroup.Count -gt 1) {
        $TotalDuplicatesFound += ($filesInGroup.Count - 1)
    }

    # Retain the first file, delete the rest
    $FilesToDelete = $filesInGroup | Select-Object -Skip 1

    foreach ($File in $FilesToDelete) {
        if ($DryRun) {
            Log "Dry-Run: Would delete file: $($File.FullName)"
        } else {
            # Permission / access checks
            $parentDir = Split-Path -Parent -Path $File.FullName
            $canDeleteHere = Test-CanDeleteInDirectory -DirectoryPath $parentDir
            $fileAccessible = Test-CanAccessFile -Path $File.FullName

            if (-not $canDeleteHere) {
                Log "SKIP: Lacking delete rights in '$parentDir'. Skipping: $($File.FullName)"
                continue
            }
            if (-not $fileAccessible) {
                Log "SKIP: File appears locked or not writable. Skipping: $($File.FullName)"
                continue
            }

            try {
                Remove-Item -Path $File.FullName -Force
                Log "Deleted file: $($File.FullName)"
                $TotalDeleted++
            } catch {
                Log "ERROR: Failed to delete file: $($File.FullName). Error: $_"
            }
        }
    }

    # Log the retained file
    $RetainedFile = $filesInGroup | Select-Object -First 1
    Log "Retained file: $($RetainedFile.FullName)"
    $TotalRetained++
}

# Log and display summary statistics
$Summary = @"
Summary:
Duplicate files found : $TotalDuplicatesFound
Duplicate files deleted : $TotalDeleted
Duplicate files retained : $TotalRetained
Hash failures : $script:HashFailures
Warnings : $script:Warnings
Critical logging errors : $script:CriticalErrors
"@

Log $Summary
Write-Host $Summary

Log "Duplicate file scan completed."
Write-Host "Duplicate file scan completed. Actions logged to $LogFilePath."

# Exit non-zero if critical logging errors occurred
if ($script:CriticalErrors -gt 0) { exit 2 }