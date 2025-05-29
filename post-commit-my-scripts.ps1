<#
.SYNOPSIS
    Post-commit Git hook PowerShell script to copy committed files to a staging directory while preserving directory structure.

.DESCRIPTION
    This script is invoked by a Git post-commit hook. It processes the list of modified and deleted files from the latest commit and performs the following:
    - Copies modified files from the repository to a destination folder, preserving their relative directory structure.
    - Deletes files from the destination folder if they were deleted in the commit.
    - Honors .gitignore rules using Git's check-ignore command.
    - Logs actions and errors to a specified log file.

.PARAMETER Verbose
    Switch to enable verbose output to the console for debugging and tracing operations.

.NOTES
    Author: Your Name
    Version: 1.0
    Last Updated: YYYY-MM-DD
#>

param (
    [switch]$Verbose
)

# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
<#
.SYNOPSIS
    Logs a message to a file with a timestamp and optional console output.

.DESCRIPTION
    This function formats a message with a timestamp and optional source label, writes it to the configured log file, and optionally prints it to the console when verbose mode is enabled.

.PARAMETER message
    The message string to be logged.

.PARAMETER source
    The source label to tag the message origin in the log. Defaults to "post-commit".
#>

function Write-Message {
    param (
        [string]$message,
        [string]$source = "post-commit"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$source] $message"
    Add-Content -Path $logFile -Value $logEntry
    if ($Verbose) {
        Write-Host $logEntry
    }
}

Write-Message "Script execution started."

if ($Verbose) {
    Write-Host "Verbose mode enabled"
    Write-Host "Repository Path: $repoPath"
    Write-Host "Destination Folder: $destinationFolder"
}

# Get list of modified files in the latest commit (excluding deletions)
$modifiedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=ACMRT

if ($Verbose) {
    Write-Host "Modified Files:" -ForegroundColor Green
    $modifiedFiles | ForEach-Object { Write-Host $_ }
}

# Get list of deleted files in the latest commit
$deletedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=D

if ($Verbose) {
    Write-Host "Deleted Files:" -ForegroundColor Red
    $deletedFiles | ForEach-Object { Write-Host $_ }
}

# Function to check if a file matches any ignored patterns
<#
.SYNOPSIS
    Checks if a file is ignored by Git based on .gitignore rules.

.DESCRIPTION
    This function uses Git's check-ignore command to determine whether a file should be excluded from processing based on .gitignore rules in the repository.

.PARAMETER relativePath
    The path to the file relative to the repository root.
#>
function Test-Ignored {
    param (
        [string]$relativePath
    )
    $result = git -C $repoPath check-ignore "$relativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($result)
}

# Copy only files modified in the latest commit, preserving directory structure
$modifiedFiles | ForEach-Object {
    $relativePath = $_
    $sourceFilePath = Join-Path -Path $repoPath -ChildPath $relativePath

    # Only copy if the source file exists and is not in .gitignore
    if ((Test-Path $sourceFilePath) -and !(Test-Ignored $relativePath)) {

        Write-Message "Processing modified file: $sourceFilePath"

        $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $relativePath
        $destinationDir = Split-Path -Path $destinationFilePath -Parent

        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        try {
            Copy-Item -Path $sourceFilePath -Destination $destinationFilePath -Force
            Write-Message "Copied file $sourceFilePath to $destinationFilePath"
        } catch {
            Write-Message ("Failed to copy {0}: {1}" -f $sourceFilePath, $_.Exception.Message)
        }
    } else {
        Write-Message "File $sourceFilePath is ignored or does not exist"
    }
}

# Permanently delete files in the destination folder that were deleted in the commit
$deletedFiles | ForEach-Object {
    $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $_

    Write-Message "Processing deleted file: $destinationFilePath"

    # Only move to Recycle Bin if the file exists in the destination and is not ignored
    if ((Test-Path $destinationFilePath) -and -not (Test-Ignored $_)) {
        Write-Message "Removing file $destinationFilePath"
        try {
            Remove-Item -Path $destinationFilePath -Recurse -Confirm:$false -Force
            Write-Message "Deleted file $destinationFilePath"
        } catch {
            Write-Message ("Failed to delete {0}: {1}" -f $destinationFilePath, $_.Exception.Message)
        }
    } else {
        Write-Message "File $destinationFilePath is ignored or does not exist in the destination folder"
    }
}

Write-Message "Script execution completed."
