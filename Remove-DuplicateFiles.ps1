<#
.SYNOPSIS
    Script to identify and delete duplicate files in a specified directory.

.DESCRIPTION
    This script scans a specified parent directory for duplicate files based on file name, extension, size, and last modified date.
    It retains one file from each group of duplicates and deletes the rest. Actions are logged to a specified log file.

.PARAMETER ParentDirectory
    The parent directory to scan for duplicate files. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib" if not provided.

.PARAMETER LogFilePath
    The path to the log file where actions will be recorded. Defaults to "C:\Users\manoj\Documents\Scripts\Remove-DuplicateFiles.log" if not provided.

.PARAMETER DryRun
    If specified, the script will only log the actions it would take without actually deleting any files.

.EXAMPLE
    .\Remove-DuplicateFiles.ps1 -ParentDirectory "C:\MyFiles" -LogFilePath "C:\Logs\DuplicateLog.log" -DryRun

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

# Validate the parent directory
if (-not (Test-Path $ParentDirectory)) {
    Log "ERROR: Parent directory '$ParentDirectory' does not exist."
    Write-Error "Parent directory '$ParentDirectory' does not exist."
    exit 1
}

Log "Starting duplicate file scan in directory: $ParentDirectory"

# Get all files in the directory and subdirectories
$Files = Get-ChildItem -Path $ParentDirectory -Recurse -File

# Group files by name, extension, size, and last write time
$DuplicateGroups = $Files | Group-Object -Property Name, Extension, Length, LastWriteTime | Where-Object { $_.Count -gt 1 }

# Initialize counters for summary statistics
$TotalDuplicatesFound = 0
$TotalDeleted = 0
$TotalRetained = 0

foreach ($Group in $DuplicateGroups) {
    $TotalDuplicatesFound += $Group.Count
    $FilesToDelete = $Group.Group | Select-Object -Skip 1 # Retain the first file, delete the rest

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
    $RetainedFile = $Group.Group | Select-Object -First 1
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