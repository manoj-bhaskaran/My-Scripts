param (
    [switch]$Verbose
)

# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
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

# Read .gitignore file
$gitignorePath = Join-Path -Path $repoPath -ChildPath ".gitignore"
$ignoredPatterns = @()

# Check if .gitignore exists and read its contents
if (Test-Path $gitignorePath) {
    $ignoredPatterns = Get-Content -Path $gitignorePath

    if ($Verbose) {
        Write-Host "Ignored Patterns:" -ForegroundColor Yellow
        $ignoredPatterns | ForEach-Object { Write-Host $_ }
    }
} else {
    if ($Verbose) {
        Write-Host ".gitignore file not found"
    }
}

# Function to check if a file matches any ignored patterns
function Test-Ignored {
    param (
        [string]$relativePath
    )

    $ignoreCheck = git -C $repoPath check-ignore "$relativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($ignoreCheck)
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
            Write-Message ("Failed to copy {0}: {1}" -f $sourceFilePath, $_)

            # Optional rollback logic here
        }
    } else {
        Write-Message "File $sourceFilePath is ignored or does not exist"
    }
}

# Move deleted files to the Recycle Bin
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
                
        }
    } else {
        Write-Message "File $destinationFilePath is ignored or does not exist in the destination folder"
    }
}

Write-Message "Script execution completed."
