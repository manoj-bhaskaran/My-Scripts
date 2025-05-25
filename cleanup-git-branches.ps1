<#
.SYNOPSIS
    Identifies and deletes obsolete (fully merged) local Git branches and their corresponding remote branches.
    
    Supports dry-run mode, customizable remote names, exclusion lists, retention of recently merged branches,
    and the ability to operate from a specified Git repository root without altering the user's current working location.

.DESCRIPTION
    This script automates the cleanup of local Git branches that have already been merged into the current branch,
    and optionally deletes the corresponding remote branches. It supports:
    - Dry-run mode to simulate cleanup without making changes.
    - Customizable remote names (e.g., origin, upstream).
    - An exclusion list of branches that should never be deleted.
    - A retention policy to preserve a specified number of recently merged branches.
    - Operation from a specified Git repository directory, restoring the user's original location on completion.

.PARAMETER RemoteName
    The name of the remote repository. Default is 'origin'.

.PARAMETER DryRun
    If specified, the script will only display what would be deleted without performing actual deletions.

.PARAMETER ExcludeBranches
    An array of branch names to exclude from deletion (e.g., 'main', 'master', 'develop').

.PARAMETER WorkingDirectory
    The path to the root directory of a Git repository to operate in. If specified, the script temporarily switches
    to that directory for execution and returns to the original location afterward.

.PARAMETER KeepRecent
    The number of most recently active merged branches to retain (based on latest commit time). Default is 10.

.EXAMPLE
    .\cleanup-git-branches.ps1

.EXAMPLE
    .\cleanup-git-branches.ps1 -RemoteName upstream -DryRun -ExcludeBranches "main","develop"

.EXAMPLE
    .\cleanup-git-branches.ps1 -WorkingDirectory "D:\Projects\myrepo" -DryRun

.EXAMPLE
    .\cleanup-git-branches.ps1 -KeepRecent 5
#>
Param (
    [string]$RemoteName = "origin",
    [switch]$DryRun,
    [string[]]$ExcludeBranches = @("main", "master"),
    [string]$WorkingDirectory = "",
    [int]$KeepRecent = 10
)

# Save current location
$originalLocation = Get-Location

# If WorkingDirectory is specified, validate and switch to it
if ($WorkingDirectory -ne "") {
    if (-not (Test-Path $WorkingDirectory)) {
        Write-Error "❌ The specified working directory '$WorkingDirectory' does not exist."
        exit 1
    }

    Set-Location $WorkingDirectory
    Write-Output "📁 Changed working directory to '$WorkingDirectory'"
}

# At this point, current location is either original or switched to WorkingDirectory
if (-not (Test-Path ".git")) {
    Write-Error "❌ This script must be run from a Git repository root, or provide a valid -WorkingDirectory."
    exit 1
}

try {

    # Fetch and prune stale remote tracking branches
    Write-Output "🔄 Fetching and pruning remote branches from '$RemoteName'..."
    git fetch $RemoteName --prune

    # Get the current branch
    $currentBranch = git rev-parse --abbrev-ref HEAD

    # Step 1: Get all merged branches, trim and clean
    $mergedBranches = git branch --merged |
        ForEach-Object { $_.Trim().Replace("* ", "") } |
        Where-Object { $_ -ne $currentBranch -and ($ExcludeBranches -notcontains $_) }

    # Step 2: Get last commit timestamp for each branch
    $branchInfoList = foreach ($branch in $mergedBranches) {
        $timestamp = git log -1 --format=%ct $branch 2>$null
        if ($timestamp) {
            [PSCustomObject]@{
                Name      = $branch
                Timestamp = [int64]$timestamp
            }
        }
    }

    # Step 3: Sort by timestamp descending, take top N to keep
    $branchesToKeep = $branchInfoList |
        Sort-Object Timestamp -Descending |
        Select-Object -First $KeepRecent |
        Select-Object -ExpandProperty Name

    # Step 4: Filter out branches to keep
    $obsoleteBranches = $branchInfoList |
        Where-Object { $branchesToKeep -notcontains $_.Name } |
        Select-Object -ExpandProperty Name

    if (-not $obsoleteBranches) {
        Write-Output "🎉 No obsolete branches found (already merged into '$currentBranch')."
        return
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
            return
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
}
finally {

    # Always return to original location
    if ($WorkingDirectory -ne "") {
        Set-Location $originalLocation
        Write-Output "`n📍 Returned to original directory: $originalLocation"
}
}

Write-Output "`n✅ Cleanup complete."
