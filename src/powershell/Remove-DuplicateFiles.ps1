<#
.SYNOPSIS
    Script to identify and delete duplicate files in a specified directory.

.DESCRIPTION
    This script scans a specified parent directory for duplicate files using a
    **content hash (SHA-256)** to ensure true duplicate detection. It retains
    one file from each group of duplicates and deletes the rest. Actions are
    logged to a specified log file

    .PARAMETER ParentDirectory
    The parent directory to scan for duplicate files. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib" if not provided.

.PARAMETER LogFilePath
    The path to the log file where actions will be recorded. Defaults to "C:\Users\manoj\Documents\Scripts\Remove-DuplicateFiles.log" if not provided.

.PARAMETER DryRun
    If specified, the script will only log the actions it would take without actually deleting any files.

.EXAMPLE
    .\Remove-DuplicateFiles.ps1 -ParentDirectory "C:\MyFiles" -LogFilePath "C:\Logs\DuplicateLog.log" -DryRun

.VERSION
1.0.1

CHANGELOG
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
    [string]$LogFilePath = "C:\Users\manoj\Documents\Scripts\Remove-DuplicateFiles.log ",
    [switch]$DryRun
)

# Ensure the log file exists
if (-not (Test-Path $LogFilePath)) {
    New-Item -ItemType File -Path $LogFilePath -Force | Out-Null
}

# Log function
function Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$($Timestamp): $Message" | Out-File -FilePath $LogFilePath -Append
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

    $TotalDuplicatesFound += $filesInGroup.Count

    # Retain the first file, delete the rest
    $FilesToDelete = $filesInGroup | Select-Object -Skip 1

    foreach ($File in $FilesToDelete) {
        if ($DryRun) {
            Log "Dry-Run: Would delete file: $($File.FullName)"
        } else {
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