<#
.SYNOPSIS
    Script to identify and delete duplicate files in a specified directory.

.DESCRIPTION
    This script scans a specified parent directory for duplicate files using a
    **content hash (SHA-256)** to ensure true duplicate detection. It retains
    one file from each group of duplicates and deletes the rest. Actions are
    logged to a specified log file. The script validates/creates the log
    directory, performs basic permission/access checks before deletion,
    and reports duplicate counts accurately (extras beyond the retained file)

    .PARAMETER ParentDirectory
    The parent directory to scan for duplicate files. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib" if not provided.

.PARAMETER LogFilePath
    The path to the log file where actions will be recorded. Defaults to "C:\Users\manoj\Documents\Scripts\Remove-DuplicateFiles.log" if not provided.

.PARAMETER DryRun
    If specified, the script will only log the actions it would take without actually deleting any files.

.EXAMPLE
    .\Remove-DuplicateFiles.ps1 -ParentDirectory "C:\MyFiles" -LogFilePath "C:\Logs\DuplicateLog.log" -DryRun

.VERSION
1.0.2

CHANGELOG
## 1.0.2 — 2025-09-14
### Fixed
- **Log path default**: removed trailing space from default `-LogFilePath`.
- **Accurate statistics**: `TotalDuplicatesFound` now counts only the *extra* files
  beyond the one retained in each duplicate set.
### Added
- **Log directory validation/creation**: ensure the directory for `-LogFilePath`
  exists (create if missing).
- **Permission/access checks before delete**:
  - Verify the file can be opened for read/write (helps detect locks/ACL issues).
  - Verify delete capability in the parent directory via a temp file probe
    (cached per-directory).
  If a check fails, deletion is skipped and a warning is logged.

## 1.0.1 — 2025-09-14
### Fixed
- **Duplicate detection now uses content hashing (SHA-256)** instead of metadata
  (`Name`, `Extension`, `Length`, `LastWriteTime`). This prevents both false positives
  (different files sharing metadata) and false negatives (same-content files with
  different names/timestamps).
- Performance optimized by **pre-grouping on file size** and hashing only files in
  size-collision groups.

## 1.0.0 — 2025-09-14
### Added
- Initial script to locate duplicate files and delete all but one in each group; metadata-based grouping.

#>

param (
    [string]$ParentDirectory = "D:\users\Manoj\Documents\FIFA 07\elib",
    # (fixed: removed trailing space)
    [string]$LogFilePath = "C:\Users\manoj\Documents\Scripts\Remove-DuplicateFiles.log",
    [switch]$DryRun
)

# Trim accidental whitespace on the provided path
$LogFilePath = $LogFilePath.Trim()

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

# Log function
function Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$($Timestamp): $Message" | Out-File -FilePath $LogFilePath -Append
}

# ---- Permission / access checks prior to deletion ----
# Cache dir probes to avoid repeated temp file work
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
        Log "WARN: File not accessible for read/write (locked or permission issue): $Path. Error: $($_.Exception.Message)"
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

# Get all files in the directory and subdirectories
$Files = Get-ChildItem -Path $ParentDirectory -Recurse -File

# Step 1: pre-group by file size (cheap) and only hash files within size-collision groups
$SizeGroups = $Files | Group-Object -Property Length | Where-Object { $_.Count -gt 1 }

# Step 2: within each size group, compute SHA-256 and find true duplicate sets
$DuplicateGroups = @()
foreach ($sg in $SizeGroups) {
    # Build [FileInfo, Hash] objects; skip files we failed to hash
    $hashed = foreach ($f in $sg.Group) {
        $h = Get-ContentHash -Path $f.FullName
        if ($null -ne $h) {
            [PSCustomObject]@{ File = $f; Hash = $h }
        }
    }

    if ($hashed) {
        $hashGroups = $hashed | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 }
        if ($hashGroups.Count -gt 0) {
            $DuplicateGroups += $hashGroups
        }
    }
}

# Initialize counters for summary statistics
$TotalDuplicatesFound = 0
$TotalDeleted = 0
$TotalRetained = 0

# Iterate over hash-equal duplicate groups
foreach ($Group in $DuplicateGroups) {
    # $Group.Group is an array of PSCustomObjects with .File and .Hash
    $filesInGroup = $Group.Group | ForEach-Object { $_.File }

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
"@

Log $Summary
Write-Host $Summary

Log "Duplicate file scan completed."
Write-Host "Duplicate file scan completed. Actions logged to $LogFilePath."