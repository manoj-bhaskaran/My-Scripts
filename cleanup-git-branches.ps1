<#
.SYNOPSIS
    Identifies and deletes obsolete (fully merged) local Git branches and their corresponding remote branches.

.DESCRIPTION
    This script automates the cleanup of local Git branches that have already been merged into the current branch,
    and optionally deletes the corresponding remote branches. It supports a dry-run mode, customizable remote names,
    and an exclusion list of branches that should never be deleted.

.PARAMETER RemoteName
    The name of the remote repository. Default is 'origin'.

.PARAMETER DryRun
    If specified, the script will only display what would be deleted without performing actual deletions.

.PARAMETER ExcludeBranches
    An array of branch names to exclude from deletion (e.g., 'main', 'master', 'develop').

.EXAMPLE
    .\cleanup-git-branches.ps1

.EXAMPLE
    .\cleanup-git-branches.ps1 -RemoteName upstream -DryRun -ExcludeBranches "main","develop"
#>

Param (
    [string]$RemoteName = "origin",
    [switch]$DryRun,
    [string[]]$ExcludeBranches = @("main", "master")
)

# Ensure we're inside a Git repo
if (-not (Test-Path ".git")) {
    Write-Error "This script must be run from the root of a Git repository."
    exit 1
}

# Fetch and prune stale remote tracking branches
Write-Output "🔄 Fetching and pruning remote branches from '$RemoteName'..."
git fetch $RemoteName --prune

# Get the current branch
$currentBranch = git rev-parse --abbrev-ref HEAD

# Get merged branches, excluding current and explicitly excluded branches
$obsoleteBranches = git branch --merged |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne $currentBranch -and ($ExcludeBranches -notcontains $_) }

if (-not $obsoleteBranches) {
    Write-Output "🎉 No obsolete branches found (already merged into '$currentBranch')."
    exit 0
}

# Display remote URL for context
$remoteUrl = git config --get remote.$RemoteName.url
if ($remoteUrl) {
    Write-Output "`nℹ️ Remote '$RemoteName' URL: $remoteUrl"
} else {
    Write-Warning "⚠️ Could not retrieve URL for remote '$RemoteName'"
}

# Display branches to be cleaned
Write-Output "`n🧹 The following branches are merged and can be deleted:"
$obsoleteBranches | ForEach-Object { Write-Output " - $_" }

if (-not $DryRun) {
    # Ask for confirmation only in non-dry-run mode
    $confirmation = Read-Host "`n❓ Do you want to delete these branches locally and remotely? (y/N)"
    if (-not ($confirmation.ToLower().StartsWith("y"))) {
        Write-Output "❌ Cleanup aborted."
        exit 1
    }
} else {
    Write-Output "`n💡 Dry run enabled — no changes will be made."
}

# Process branches
foreach ($branch in $obsoleteBranches) {
    Write-Verbose "🔍 Processing branch: $branch"

    if ($DryRun) {
        Write-Output "💡 Would delete local branch '$branch'"
    } else {
        try {
            Write-Output "🗑️ Deleting local branch '$branch'..."
            git branch -d $branch
        } catch {
            Write-Warning "⚠️ Could not delete local branch '$branch': $_"
            continue
        }
    }

    # Check if remote branch exists
    git ls-remote --exit-code --heads $RemoteName $branch > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($DryRun) {
            Write-Output "💡 Would delete remote branch '$RemoteName/$branch'"
        } else {
            Write-Output "🗑️ Deleting remote branch '$RemoteName/$branch'..."
            git push $RemoteName --delete $branch
        }
    } else {
        Write-Output "ℹ️ Remote branch '$RemoteName/$branch' does not exist."
    }
}

Write-Output "`n✅ Cleanup complete."
