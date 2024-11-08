# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"

# Get list of modified files in the latest commit
$modifiedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD

# Read .gitignore file
$gitignorePath = Join-Path -Path $repoPath -ChildPath ".gitignore"
$ignoredPatterns = @()

# Check if .gitignore exists and read its contents
if (Test-Path $gitignorePath) {
    $ignoredPatterns = Get-Content -Path $gitignorePath
}

# Function to check if a file matches any ignored patterns
function Is-Ignored {
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
    $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $_

    # Only copy if the source file exists and is not in .gitignore
    if (Test-Path $sourceFilePath -and -not (Is-Ignored $_)) {
        Copy-Item -Path $sourceFilePath -Destination $destinationFolder -Force
    }
}