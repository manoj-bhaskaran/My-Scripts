<#
.SYNOPSIS
    Clean up obsolete local Git branches and their corresponding remote branches.

.DESCRIPTION
    This script identifies local branches that are already merged into the current branch,
    confirms deletion with the user, and deletes both local and remote branches if applicable.

.NOTES
    Requires Git to be installed and available in PATH.
#>

# Ensure we're inside a Git repo
if (-not (Test-Path ".git")) {
    Write-Error "This script must be run from the root of a Git repository."
    exit 1
}

# Fetch and prune stale remotes
Write-Output "🔄 Fetching and pruning remote branches..."
git fetch --prune

# Get the current branch
$currentBranch = git rev-parse --abbrev-ref HEAD

# Get merged branches, excluding current, main, and master
$obsoleteBranches = git branch --merged |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne $currentBranch -and $_ -ne "main" -and $_ -ne "master" }

if (-not $obsoleteBranches) {
    Write-Output "🎉 No obsolete branches found (already merged into '$currentBranch')."
    exit 0
}

Write-Output "`n🧹 The following branches are merged and can be deleted:"
$obsoleteBranches | ForEach-Object { Write-Output " - $_" }

$confirmation = Read-Host "`n❓ Do you want to delete these branches locally and remotely? (y/N)"
if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    Write-Output "❌ Cleanup aborted."
    exit 1
}

foreach ($branch in $obsoleteBranches) {
    try {
        Write-Output "🗑️ Deleting local branch '$branch'..."
        git branch -d $branch
    } catch {
        Write-Warning "⚠️ Could not delete local branch '$branch': $_"
        continue
    }

    $remoteExists = git ls-remote --exit-code --heads origin $branch 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Output "🗑️ Deleting remote branch 'origin/$branch'..."
        git push origin --delete $branch
    } else {
        Write-Output "ℹ️ Remote branch 'origin/$branch' does not exist."
    }
}

Write-Output "`n✅ Cleanup complete."
