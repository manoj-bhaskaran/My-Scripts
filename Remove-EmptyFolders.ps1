<#
.SYNOPSIS
    Identifies and deletes all empty folders under a specified parent directory.

.DESCRIPTION
    This script recursively searches for empty folders under a given parent directory.
    It supports a dry-run mode to simulate deletions and logs all actions to a specified log file.

.PARAMETER ParentDirectory
    The parent directory to search for empty folders. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib".

.PARAMETER LogFilePath
    The path to the log file. Defaults to "C:\Users\manoj\Documents\Scripts\Remove-EmptyFolders.log".

.PARAMETER DryRun
    If specified, simulate deletions without actually deleting folders.

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -ParentDirectory "D:\MyFolder" -LogFilePath "D:\Logs\cleanup.log"

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -ParentDirectory "D:\MyFolder" -LogFilePath "D:\Logs\cleanup.log" -DryRun

.EXAMPLE
    .\Remove-EmptyFolders.ps1
#>

param (
    [string]$ParentDirectory = "D:\users\Manoj\Documents\FIFA 07\elib",
    [string]$LogFilePath = "C:\Users\manoj\Documents\Scripts\Remove-EmptyFolders.log",
    [switch]$DryRun
)

# Initialize logging
function Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp: $Message" | Out-File -FilePath $LogFilePath -Append
}

# Start logging
Log "Starting empty folder cleanup. Dry-run: $DryRun"

# Recursively search for empty folders
Get-ChildItem -Path $ParentDirectory -Directory -Recurse | ForEach-Object {
    if (-not (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { $_.PSIsContainer -or $_.PSIsContainer -eq $false })) {
        if ($DryRun) {
            Log "[Dry-Run] Empty folder found: $($_.FullName)"
        } else {
            try {
                Remove-Item -Path $_.FullName -Recurse -Force
                Log "Deleted empty folder: $($_.FullName)"
            } catch {
                Log "Failed to delete folder $($_.FullName): $($_.Exception.Message)"
            }
        }
    }
}

# End logging
Log "Empty folder cleanup completed."
