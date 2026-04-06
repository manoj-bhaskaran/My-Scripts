<#
.SYNOPSIS
    BackupState module — state management for Sync-MacriumBackups.ps1.

.DESCRIPTION
    Provides all state-tracking functions used by Sync-MacriumBackups.ps1:
    reading/writing the JSON state file, initialising a new run, recording
    step progress, finalising run status, and evaluating auto-resume logic.

    All functions accept explicit parameters (StateFile, State, etc.) so that
    the state object is initialised once in the caller and passed through the
    call chain, eliminating redundant disk reads within a single execution.

.NOTES
    Version: 1.0.0

    CHANGELOG
    ## 1.0.0 - 2026-04-06
    ### Added
    - Initial release: extracted from Sync-MacriumBackups.ps1 (v2.7.0).
    - Format-Duration: formats a duration in seconds to a human-readable string.
    - Read-StateFile: reads the state file; renames corrupt files for debugging.
    - Write-StateFile: atomically writes the state object to the state file.
    - Mark-InterruptedState: marks an in-progress state as Interrupted and persists it.
    - Initialize-StateFile: creates a new run state; accepts PreviousState to
      avoid a second disk read after Invoke-AutoResumeLogic.
    - Update-StateStep: updates the lastStep field; accepts State parameter to
      eliminate the internal Read-StateFile call.
    - Complete-StateFile: finalises state as Succeeded or Failed; accepts State
      parameter to eliminate the internal Read-StateFile call.
    - Invoke-AutoResumeLogic: evaluates AutoResume/Force flags; accepts
      PreviousState to eliminate an internal Read-StateFile call.
    - Export-ModuleMember lists all eight public functions explicitly.
#>

function Format-Duration {
    <#
    .SYNOPSIS
        Formats a duration in seconds to a human-readable string.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$Seconds
    )

    $timeSpan = [TimeSpan]::FromSeconds($Seconds)

    if ($timeSpan.TotalHours -ge 1) {
        return "{0:N0}h {1:N0}m {2:N0}s" -f $timeSpan.Hours, $timeSpan.Minutes, $timeSpan.Seconds
    }
    elseif ($timeSpan.TotalMinutes -ge 1) {
        return "{0:N0}m {1:N0}s" -f $timeSpan.Minutes, $timeSpan.Seconds
    }
    else {
        return "{0:N2}s" -f $timeSpan.TotalSeconds
    }
}

function Read-StateFile {
    <#
    .SYNOPSIS
        Reads the state file if it exists and returns the state object.
    .DESCRIPTION
        If the state file is corrupt or unreadable, it will be renamed with a
        timestamp to preserve it for debugging, and the function will return
        $null to allow the script to continue with a fresh state.
    .PARAMETER StateFile
        Full path to the state JSON file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile
    )

    if (Test-Path $StateFile) {
        try {
            $stateJson = Get-Content -Path $StateFile -Raw -ErrorAction Stop
            return ($stateJson | ConvertFrom-Json)
        }
        catch {
            # State file is corrupt - rename it with timestamp and continue safely
            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            $corruptFile = "$StateFile.corrupt_$timestamp"

            Write-LogWarning "State file is corrupt or unreadable: $_"
            Write-LogInfo "Renaming corrupt state file to: $corruptFile"

            try {
                Move-Item -Path $StateFile -Destination $corruptFile -Force -ErrorAction Stop
                Write-LogInfo "Corrupt state file preserved for debugging. Continuing with fresh state."
            }
            catch {
                Write-LogWarning "Failed to rename corrupt state file: $_. Attempting to delete it."
                Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue
            }

            return $null
        }
    }
    return $null
}

function Write-StateFile {
    <#
    .SYNOPSIS
        Atomically writes the state object to the state file.
    .DESCRIPTION
        Writes to a temporary file first, then renames it to ensure atomic writes.
    .PARAMETER StateFile
        Full path to the state JSON file.
    .PARAMETER State
        The state object to serialise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $tempFile = "$StateFile.tmp"
    try {
        # Convert hashtable/object to JSON
        $stateJson = $State | ConvertTo-Json -Depth 10

        # Write to temporary file
        $stateJson | Set-Content -Path $tempFile -Force -ErrorAction Stop

        # Atomic rename
        Move-Item -Path $tempFile -Destination $StateFile -Force -ErrorAction Stop
    }
    catch {
        Write-LogError "Failed to write state file: $_"
        # Clean up temp file if it exists
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Mark-InterruptedState {
    <#
    .SYNOPSIS
        Marks a previous in-progress state as Interrupted and persists it.
    .DESCRIPTION
        Centralises the logic for marking an interrupted run, logging the
        details, and writing the updated state to the state file.
    .PARAMETER StateFile
        Full path to the state JSON file.
    .PARAMETER State
        The state object to mark as interrupted.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [object]$State
    )

    Write-LogWarning "Previous run was interrupted (possible reboot/crash)"
    Write-LogInfo "Previous run details - Run ID: $($State.lastRunId), Started: $($State.startTime), Last step: $($State.lastStep)"

    $State.status = "Interrupted"
    $State.endTime = (Get-Date).ToString("o")
    $State.reason = "Previous run ended without completion (possible reboot/crash)"
    Write-StateFile -StateFile $StateFile -State $State
    Write-LogInfo "Previous state marked as Interrupted"
}

function Initialize-StateFile {
    <#
    .SYNOPSIS
        Initialises the state file at script start and checks for interrupted runs.
    .DESCRIPTION
        Creates a new run ID and sets status to InProgress.  Returns the new
        state hashtable so the caller can pass it through the execution chain
        without re-reading the file.

        Behavior depends on CleanStart:
        - CleanStart = $true  : removes any existing state file (default without AutoResume).
        - CleanStart = $false : with AutoResume; logs retry context if previous run failed.

        Accepts an optional PreviousState object (already loaded by the caller)
        to avoid a second disk read.
    .PARAMETER StateFile
        Full path to the state JSON file.
    .PARAMETER ScriptVersion
        Version string of the calling script, stored in the new state.
    .PARAMETER CleanStart
        When $true, removes the existing state file before creating a new one.
    .PARAMETER PreviousState
        Previously-read state object.  When supplied, Read-StateFile is not called.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [string]$ScriptVersion,

        [bool]$CleanStart = $false,

        [object]$PreviousState = $null
    )

    # Use the supplied previous state; read from disk only when none was provided.
    $previousState = if ($null -ne $PreviousState) { $PreviousState } else { Read-StateFile -StateFile $StateFile }

    # Handle interrupted state first (applies to both clean start and resume scenarios)
    if ($null -ne $previousState -and $previousState.status -eq "InProgress") {
        Mark-InterruptedState -StateFile $StateFile -State $previousState
    }

    # Handle clean start (default behavior without AutoResume)
    if ($CleanStart) {
        if ($null -ne $previousState) {
            Write-LogInfo "Clean start requested. Removing previous state file."
            if (Test-Path $StateFile) {
                Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        # With AutoResume, log context if retrying after failure
        if ($null -ne $previousState -and $previousState.status -eq "Failed") {
            Write-LogInfo "Retrying after failed run (ID: $($previousState.lastRunId))."
        }
    }

    # Create new state
    $newRunId = [guid]::NewGuid().ToString()
    $newState = @{
        lastRunId           = $newRunId
        scriptVersion       = $ScriptVersion
        status              = "InProgress"
        startTime           = (Get-Date).ToString("o")
        endTime             = $null
        lastExitCode        = $null
        lastStep            = "Initialize"
        syncStartTime       = $null
        syncDurationSeconds = $null
        reason              = $null
    }

    Write-StateFile -StateFile $StateFile -State $newState
    Write-LogInfo "State tracking initialized. Run ID: $newRunId, Script version: $ScriptVersion"

    return $newState
}

function Update-StateStep {
    <#
    .SYNOPSIS
        Updates the lastStep field in the state object and persists it.
    .DESCRIPTION
        Accepts the in-memory State object to avoid a redundant Read-StateFile
        disk read.
    .PARAMETER StateFile
        Full path to the state JSON file.
    .PARAMETER State
        The current in-memory state object returned by Initialize-StateFile.
    .PARAMETER StepName
        Name of the step to record.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [object]$State,

        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    if ($null -ne $State) {
        $State.lastStep = $StepName
        Write-StateFile -StateFile $StateFile -State $State
    }
}

function Complete-StateFile {
    <#
    .SYNOPSIS
        Marks the state as completed (Succeeded or Failed) with end time,
        exit code, and optional sync duration.
    .DESCRIPTION
        Accepts the in-memory State object to avoid a redundant Read-StateFile
        disk read.
    .PARAMETER StateFile
        Full path to the state JSON file.
    .PARAMETER State
        The current in-memory state object returned by Initialize-StateFile.
    .PARAMETER Status
        Final status: "Succeeded" or "Failed".
    .PARAMETER ExitCode
        The exit code to record.
    .PARAMETER SyncDurationSeconds
        Optional total sync duration in seconds.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [object]$State,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Succeeded", "Failed")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 0,

        [Parameter(Mandatory = $false)]
        [double]$SyncDurationSeconds = $null
    )

    if ($null -ne $State) {
        $State.status = $Status
        $State.endTime = (Get-Date).ToString("o")
        $State.lastExitCode = $ExitCode

        if ($null -ne $SyncDurationSeconds) {
            $State.syncDurationSeconds = [math]::Round($SyncDurationSeconds, 2)
        }

        Write-StateFile -StateFile $StateFile -State $State

        # Log finalization with duration if available
        if ($null -ne $SyncDurationSeconds) {
            $durationFormatted = Format-Duration -Seconds $SyncDurationSeconds
            Write-LogInfo "State finalized: $Status (Exit code: $ExitCode, Sync duration: $durationFormatted)"
        }
        else {
            Write-LogInfo "State finalized: $Status (Exit code: $ExitCode)"
        }
    }
}

function Invoke-AutoResumeLogic {
    <#
    .SYNOPSIS
        Evaluates whether the script should proceed based on AutoResume and Force flags.
    .DESCRIPTION
        When AutoResume is enabled, checks the previous run state and determines
        if the sync should run.  Returns $true if sync should proceed, $false if
        it should be skipped.

        Accepts the PreviousState object (already loaded by the caller) to avoid
        an internal Read-StateFile call.

        Decision logic:
        - AutoResume = $false : Always return $true (fresh run handled by caller).
        - AutoResume = $true  :
          - No state / $null  : Return $true (first run).
          - Succeeded + no Force : Return $false (skip).
          - Succeeded + Force    : Return $true (forced run).
          - Failed or InProgress : Return $true (resume/retry).
    .PARAMETER PreviousState
        Previously-read state object, or $null if no state file existed.
    .PARAMETER AutoResume
        Whether the -AutoResume flag was set by the caller.
    .PARAMETER Force
        Whether the -Force flag was set by the caller.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$PreviousState = $null,

        [Parameter(Mandatory = $true)]
        [bool]$AutoResume,

        [Parameter(Mandatory = $true)]
        [bool]$Force
    )

    # If AutoResume is not set, the caller will handle fresh run initialization
    if (-not $AutoResume) {
        Write-LogInfo "AutoResume not enabled. Proceeding with fresh run."
        return $true
    }

    Write-LogInfo "AutoResume enabled. Checking previous run status..."

    # No state file exists - treat as first run
    if ($null -eq $PreviousState) {
        Write-LogInfo "No previous state file found. Treating as first run."
        return $true
    }

    $lastStatus = $PreviousState.status
    $lastRunId = $PreviousState.lastRunId
    $lastStartTime = $PreviousState.startTime

    Write-LogInfo "Previous run status: $lastStatus (Run ID: $lastRunId, Started: $lastStartTime)"

    # Decision tree based on last status
    switch ($lastStatus) {
        "Succeeded" {
            if ($Force) {
                Write-LogInfo "Previous run succeeded, but -Force flag is set. Proceeding with sync."
                return $true
            }
            else {
                Write-LogInfo "Previous run succeeded. No action required. Use -Force to override."
                return $false
            }
        }

        "Failed" {
            Write-LogInfo "Previous run failed. Proceeding with sync to retry."
            return $true
        }

        "InProgress" {
            Write-LogWarning "Previous run was interrupted (status: InProgress). Proceeding with sync to complete."
            return $true
        }

        default {
            Write-LogWarning "Unknown previous status '$lastStatus'. Proceeding with sync."
            return $true
        }
    }
}

Export-ModuleMember -Function @(
    'Format-Duration',
    'Read-StateFile',
    'Write-StateFile',
    'Mark-InterruptedState',
    'Initialize-StateFile',
    'Update-StateStep',
    'Complete-StateFile',
    'Invoke-AutoResumeLogic'
)
