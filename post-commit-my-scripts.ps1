# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"

# Get list of modified files in the latest commit (excluding deletions)
$modifiedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=ACMRT

# Get list of deleted files in the latest commit
$deletedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=D

# Read .gitignore file
$gitignorePath = Join-Path -Path $repoPath -ChildPath ".gitignore"
$ignoredPatterns = @()

# Check if .gitignore exists and read its contents
if (Test-Path $gitignorePath) {
    $ignoredPatterns = Get-Content -Path $gitignorePath
}

# Function to check if a file matches any ignored patterns
function Test-Ignored {
    param (
        [string]$fileName
    )

    # Check if the file is .gitignore itself
    if ($fileName -eq ".gitignore") {
        return $true
    }

    # Check against patterns in .gitignore
    foreach ($pattern in $ignoredPatterns) {
        # Use -like for wildcard matching, if applicable
        if ($fileName -like $pattern) {
            return $true
        }
    }
    return $false
}

# Copy only files modified in the latest commit, excluding .gitignore and ignored files
$modifiedFiles | ForEach-Object {
    $sourceFilePath = Join-Path -Path $repoPath -ChildPath $_

    # Only copy if the source file exists and is not in .gitignore
    if (Test-Path $sourceFilePath -and !(Test-Ignored $_)) {
        Copy-Item -Path $sourceFilePath -Destination $destinationFolder -Force
    }
}

# Move deleted files to the Recycle Bin
$deletedFiles | ForEach-Object {
    $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $_

    # Only move to Recycle Bin if the file exists in the destination and is not ignored
    if (Test-Path $destinationFilePath -and -not (Test-Ignored $_)) {
        # Move file to the Recycle Bin
        Remove-Item -Path $destinationFilePath -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    }
}