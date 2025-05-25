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
#>
Param (
    [string]$RemoteName = "origin",
    [switch]$DryRun,
    [string[]]$ExcludeBranches = @("main", "master"),
    [string]$WorkingDirectory = "",
    [int]$KeepRecent = 10,
    [switch]$Silent,
    [string]$LogFile = "C:\Users\manoj\Documents\Scripts\cleanup-git-branches.log"
)

if ($Silent) {
    $env:GIT_TERMINAL_PROMPT = "0"
}

function Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamped = "$([DateTime]::Now.ToString('s')) [$Level] $Message"

    if (-not $Silent) {
        switch ($Level) {
            "INFO"  { Write-Output  $Message }
            "WARN"  { Write-Warning $Message }
            "ERROR" { Write-Error   $Message }
            "DEBUG" { Write-Verbose $Message }
        }
    }

    if ($LogFile) {
        $timestamped | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

# Save current location
$originalLocation = Get-Location

# If WorkingDirectory is specified, validate and switch to it
if ($WorkingDirectory -ne "") {
    if (-not (Test-Path $WorkingDirectory)) {
        Log "❌ The specified working directory '$WorkingDirectory' does not exist." "ERROR"
        exit 1
    }

    Set-Location $WorkingDirectory
    Log "📁 Changed working directory to '$WorkingDirectory'"
}

# At this point, current location is either original or switched to WorkingDirectory
if (-not (Test-Path ".git")) {
    Log "❌ This script must be run from a Git repository root, or provide a valid -WorkingDirectory." "ERROR"
    exit 1
}

try {

    # Fetch and prune stale remote tracking branches
    Log "🔄 Fetching and pruning remote branches from '$RemoteName'..."
    if ($Silent) {
        try {
            git fetch $RemoteName --prune --quiet 2>&1 | Out-Null
        } catch {
            Log "Fetch failed silently: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Log "🔄 Fetching and pruning remote branches from '$RemoteName'..." "INFO"
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
        Log "🎉 No obsolete branches found (already merged into '$currentBranch')." "WARN"
        return
    }

    # Display remote URL for context
    $remoteUrl = git config --get remote.$RemoteName.url
    if ($remoteUrl) {
        Log "`nℹ️ Remote '$RemoteName' URL: $remoteUrl"
    } else {
        Log "⚠️ Could not retrieve URL for remote '$RemoteName'" "WARN"
    }

    # Display branches to be cleaned
    Log "`n🧹 The following branches are merged and can be deleted:"
    $obsoleteBranches | ForEach-Object { Log " - $_" "INFO"}

    if (-not $DryRun -and -not $Silent) {
        $confirmation = Read-Host "`n❓ Do you want to delete these branches locally and remotely? (y/N)"
        if (-not ($confirmation.ToLower().StartsWith("y"))) {
            Log "❌ Cleanup aborted." "INFO"
            return
        }
    } elseif (-not $DryRun -and $Silent) {
        # Proceed without prompt
        Log "🔇 Silent mode active — proceeding without confirmation." "INFO"
    }

    # Process branches
    foreach ($branch in $obsoleteBranches) {
        Log "🔍 Processing branch: $branch"

        if ($DryRun) {
            Log "💡 Would delete local branch '$branch'"
        } else {
            try {
                Log "🗑️ Deleting local branch '$branch'..."
                git branch -d $branch
            } catch {
                Log "⚠️ Could not delete local branch '$branch': $_" "WARN"
                continue
            }
        }

        # Check if remote branch exists
        git ls-remote --exit-code --heads $RemoteName $branch > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($DryRun) {
                Log "💡 Would delete remote branch '$RemoteName/$branch'"
            } else {
                Log "🗑️ Deleting remote branch '$RemoteName/$branch'..."
                git push $RemoteName --delete $branch
            }
        } else {
            Log "ℹ️ Remote branch '$RemoteName/$branch' does not exist." "WARN"
        }
    }
}
finally {

    # Always return to original location
    if ($WorkingDirectory -ne "") {
        Set-Location $originalLocation
        Log "`n📍 Returned to original directory: $originalLocation"
    }
}

Log "`n✅ Cleanup complete."
