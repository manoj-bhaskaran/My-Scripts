# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"

# Get list of modified files in the latest commit
$modifiedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD

# Copy only files modified in the latest commit
$modifiedFiles | ForEach-Object {
    $sourceFilePath = Join-Path -Path $repoPath -ChildPath $_
    $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $_

    # Only copy if the source file exists
    if (Test-Path $sourceFilePath) {
        Copy-Item -Path $sourceFilePath -Destination $destinationFolder -Force
    }
}
