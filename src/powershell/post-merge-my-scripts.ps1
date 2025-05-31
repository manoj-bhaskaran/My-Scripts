<#
.SYNOPSIS
This PowerShell script automates the process of pulling the main branch from the GitHub repository, comparing files with a specified directory, and distributing newer files to a target directory.

.DESCRIPTION
The script pulls the latest changes from the GitHub repository, compares the files in the local repository with those in a specified comparison directory, and copies newer files to the target directory.

.PARAMETER localRepoPath
Path to the local Git repository.

.PARAMETER compareDirectory
Path to the directory to compare files with.

.PARAMETER targetDirectory
Path to the directory where newer files will be copied.

.EXAMPLES
To run the script manually:
.\post-merge-my-scripts.ps1

.NOTES
1. Define paths for the local repository, comparison directory, and target directory.
2. Implement functionality to pull the latest changes from the main branch.
3. Compare files in the local repository with those in the comparison directory.
4. Copy newer files to the target directory.

#>

# Define paths
$localRepoPath = "D:\My Scripts"
$compareDirectory = "C:\Users\manoj\Documents\Scripts"
$targetDirectory = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
function Log-Message {
    param (
        [string]$message,
        [string]$source = "post-merge"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$source] $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Log-Message "Script execution started."

# Pull the latest changes from the main branch
Log-Message "Pulling latest changes from the main branch..."
Set-Location -Path $localRepoPath
git pull origin main | ForEach-Object { Log-Message $_ }

# Function to compare and copy newer files
function Compare-And-Copy {
    param (
        [string]$source,
        [string]$destination,
        [string]$target
    )

    Get-ChildItem -Path $source -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($source.Length)
        $compareFilePath = Join-Path $destination $relativePath
        $targetFilePath = Join-Path $target $relativePath

        if (-not (Test-Path -Path $compareFilePath)) {
            Log-Message "New file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Log-Message "Copied new file $relativePath to $target"
        } elseif ((Get-Item -Path $_.FullName).LastWriteTime -gt (Get-Item -Path $compareFilePath).LastWriteTime) {
            Log-Message "Updated file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Log-Message "Copied updated file $relativePath to $target"
        }
    }
}

# Compare and copy newer files
Log-Message "Comparing files and copying newer ones to target directory..."
Compare-And-Copy -source $localRepoPath -destination $compareDirectory -target $targetDirectory

Log-Message "Script execution completed."
