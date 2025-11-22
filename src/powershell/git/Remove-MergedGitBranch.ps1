<#
.SYNOPSIS
    Identifies and deletes obsolete (fully merged) local Git branches and their corresponding remote branches.

    Supports dry-run mode, customizable remote names and exclusion lists, retention of recently merged branches,
    silent execution with optional logging, and the ability to operate from a specified Git repository root
    without altering the user's current working location.

.DESCRIPTION
    This script automates the cleanup of local Git branches that have already been merged into the current branch,
    and optionally deletes the corresponding remote branches. It supports:

    - Dry-run mode to simulate cleanup without making changes.
    - Customizable remote names (e.g., origin, upstream).
    - An exclusion list of branches that should never be deleted.
    - A retention policy to preserve a specified number of recently merged branches.
    - Operation from a specified Git repository directory, restoring the user's original location on completion.
    - Silent mode to suppress all console output and skip confirmation prompts.
    - Logging to a file with timestamped entries for audit or review.

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

.PARAMETER Silent
    If specified, suppresses all output to the console and skips the confirmation prompt. Logging to file will still occur if -LogFile is set.

.PARAMETER LogFile
    The path to a file where all actions, warnings, and errors will be logged with timestamps. If omitted, no file logging occurs.

.EXAMPLE
    .\cleanup-git-branches.ps1

.EXAMPLE
    .\cleanup-git-branches.ps1 -RemoteName upstream -DryRun -ExcludeBranches "main","develop"

.EXAMPLE
    .\cleanup-git-branches.ps1 -WorkingDirectory "D:\Projects\myrepo" -DryRun

.EXAMPLE
    .\cleanup-git-branches.ps1 -KeepRecent 5 -LogFile "D:\Logs\branch-cleanup.log"

.EXAMPLE
    .\cleanup-git-branches.ps1 -Silent -LogFile "C:\logs\cleanup.log"

.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release with custom Log function
#>
param (
    [string]$RemoteName = "origin",
    [switch]$DryRun,
    [string[]]$ExcludeBranches = @("main", "master"),
    [string]$WorkingDirectory = "",
    [int]$KeepRecent = 10,
    [switch]$Silent,
    [string]$LogFile = "C:\Users\manoj\Documents\Scripts\cleanup-git-branches.log"
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "cleanup-git-branches" -LogLevel 20

if ($Silent) {
    $env:GIT_TERMINAL_PROMPT = "0"
}

# Save current location
$originalLocation = Get-Location

# If WorkingDirectory is specified, validate and switch to it
if ($WorkingDirectory -ne "") {
    if (-not (Test-Path $WorkingDirectory)) {
        Write-LogError "The specified working directory '$WorkingDirectory' does not exist."
        exit 1
    }

    Set-Location $WorkingDirectory
    Write-LogInfo "Changed working directory to '$WorkingDirectory'"
}

# At this point, current location is either original or switched to WorkingDirectory
if (-not (Test-Path ".git")) {
    Write-LogError "This script must be run from a Git repository root, or provide a valid -WorkingDirectory."
    exit 1
}

try {

    # Fetch and prune stale remote tracking branches
    Write-LogInfo "Fetching and pruning remote branches from '$RemoteName'..."
    if ($Silent) {
        try {
            git fetch $RemoteName --prune --quiet 2>&1 | Out-Null
        }
        catch {
            Write-LogError "Fetch failed silently: $($_.Exception.Message)"
        }
    }
    else {
        git fetch $RemoteName --prune
    }

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
        Write-LogWarning "No obsolete branches found (already merged into '$currentBranch')."
        return
    }

    # Display remote URL for context
    $remoteUrl = git config --get remote.$RemoteName.url
    if ($remoteUrl) {
        Write-LogInfo "Remote '$RemoteName' URL: $remoteUrl"
    }
    else {
        Write-LogWarning "Could not retrieve URL for remote '$RemoteName'"
    }

    # Display branches to be cleaned
    Write-LogInfo "The following branches are merged and can be deleted:"
    $obsoleteBranches | ForEach-Object { Write-LogInfo " - $_" }

    if (-not $DryRun -and -not $Silent) {
        $confirmation = Read-Host "`nDo you want to delete these branches locally and remotely? (y/N)"
        if (-not ($confirmation.ToLower().StartsWith("y"))) {
            Write-LogInfo "Cleanup aborted."
            return
        }
    }
    elseif (-not $DryRun -and $Silent) {
        # Proceed without prompt
        Write-LogInfo "Silent mode active — proceeding without confirmation."
    }

    # Process branches
    foreach ($branch in $obsoleteBranches) {
        Write-LogInfo "Processing branch: $branch"

        if ($DryRun) {
            Write-LogInfo "Would delete local branch '$branch'"
        }
        else {
            try {
                Write-LogInfo "Deleting local branch '$branch'..."
                git branch -d $branch
            }
            catch {
                Write-LogWarning "Could not delete local branch '$branch': $_"
                continue
            }
        }

        # Check if remote branch exists
        git ls-remote --exit-code --heads $RemoteName $branch > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($DryRun) {
                Write-LogInfo "Would delete remote branch '$RemoteName/$branch'"
            }
            else {
                Write-LogInfo "Deleting remote branch '$RemoteName/$branch'..."
                git push $RemoteName --delete $branch
            }
        }
        else {
            Write-LogWarning "Remote branch '$RemoteName/$branch' does not exist."
        }
    }
}
finally {

    # Always return to original location
    if ($WorkingDirectory -ne "") {
        Set-Location $originalLocation
        Write-LogInfo "Returned to original directory: $originalLocation"
    }
}

Write-LogInfo "Cleanup complete."
