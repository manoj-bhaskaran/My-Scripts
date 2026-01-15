<#
.SYNOPSIS
    Syncs Macrium Reflect backup files from an external HDD to Google Drive using rclone, with dynamic tuning, validations, and configurable WiFi/network logic.

.DESCRIPTION
    This script automates the synchronization of Macrium backup files from a local path (typically an external HDD)
    to a specified Google Drive remote using rclone.

    Features:
    - Validates the source path, Google Drive remote, and internet connectivity.
    - Dynamically selects an optimal --drive-chunk-size based on available memory.
    - Supports configurable preferred and fallback WiFi SSIDs for prioritised connection.
    - Automatically attempts to switch to the preferred WiFi network if it's available but not connected.
    - Handles paths and remote names with spaces via proper quoting.
    - Avoids mixing rclone --progress output with log file content to preserve log readability.
    - Appends to a single persistent log file for auditability.
    - Provides an optional -Interactive switch to enable rclone's --progress bar when running manually.

.PARAMETER PreferredSSID
    The WiFi SSID to prioritise when connecting. The script will attempt to switch to this if not currently connected.

.PARAMETER FallbackSSID
    The secondary WiFi SSID to use if the preferred is not available.

.PARAMETER SourcePath
    The local path to the Macrium backup folder. Default: "E:\Macrium Backups".

.PARAMETER RcloneRemote
    The rclone remote (and optional path) to sync to. Can include spaces. Example: "gdrive:Macrium Backups".

.PARAMETER MaxChunkMB
    The upper limit (in MB) for dynamically calculated rclone --drive-chunk-size. Default: 2048.

.PARAMETER Interactive
    Optional switch. When enabled, rclone will display a live progress bar and more interactive feedback on the console. This is intended for manual use and disables log redirection of the progress meter.

.PARAMETER AutoResume
    Optional switch. When enabled, the script checks the previous run's status from the state file. If the last run succeeded, the script exits without running (unless -Force is used). If the last run failed or was interrupted, the script proceeds with a full sync run.

.PARAMETER Force
    Optional switch. When used with -AutoResume, forces the script to run even if the previous run succeeded. Without -AutoResume, this parameter has no effect.

.EXAMPLE
    .\Sync-MacriumBackups.ps1

    Runs the sync using default source path, remote, and logging settings in non-interactive mode. Creates a fresh state file.

.EXAMPLE
    .\Sync-MacriumBackups.ps1 -Interactive

    Runs the sync with rclone --progress output shown on the console, suitable for manual invocation.

.EXAMPLE
    .\Sync-MacriumBackups.ps1 -AutoResume

    Checks the previous run status. Only runs if the last run failed or was interrupted. Skips execution if last run succeeded.

.EXAMPLE
    .\Sync-MacriumBackups.ps1 -AutoResume -Force

    Forces a sync run regardless of the previous run's status.

.NOTES
    Version: 2.6.3

    CHANGELOG
    ## 2.6.3 - 2026-01-15
    ### Fixed
    - Added single-line and multi-line sanitized rclone command output for easier reconstruction and debugging
    - Avoided logging a dangling rclone backslash line without arguments

    ## 2.6.2 - 2026-01-15
    ### Fixed
    - Enhanced rclone command logging to display each argument on a separate line for better debugging
    - Ensures full command can be reconstructed even when rclone fails with syntax errors

    ## 2.6.1 - 2026-01-15
    ### Fixed
    - Allowed 4096 MB rclone chunk size when MaxChunkMB is set to the documented maximum

    ## 2.6.0 - 2026-01-15
    ### Changed
    - Refactored Initialize-StateFile to eliminate duplicated interrupted state handling logic
    - Added Mark-InterruptedState helper function to consolidate state marking logic
    - Extracted script version from .NOTES into dedicated $ScriptVersion variable for programmatic access
    - Enhanced state file to include scriptVersion field for version tracking
    - Improved logging to include script version at startup and state initialization

    ## 2.5.1 - 2026-01-15
    ### Added
    - Sanitized rclone command line logging for auditability
    - Framework log entries for framework, rclone, and state file paths
    - Consistent rclone log timestamp formatting aligned with framework logs

    ## 2.5.0 - 2026-01-14
    ### Added
    - Post-run verification summary showing exit code and sync duration after rclone completes
    - Sync duration tracking: captures syncStartTime and syncDurationSeconds in state file
    - Format-Duration helper function for human-readable duration formatting (e.g., "5h 23m 15s")
    - Startup sanity check: corrupt/unreadable state files are renamed with timestamp instead of deleted
    - Corrupt state files preserved for debugging with .corrupt_TIMESTAMP suffix

    ### Changed
    - Complete-StateFile now accepts and persists SyncDurationSeconds parameter
    - State structure includes syncStartTime and syncDurationSeconds fields
    - Read-StateFile handles corrupt files gracefully by renaming them before continuing
    - Enhanced state finalization logging includes formatted sync duration when available

    ### Fixed
    - Improved state consistency: all error paths guaranteed to update state to Failed before exit
    - State file corruption no longer blocks script execution

    ## 2.4.0 - 2026-01-13
    ### Added
    - Auto-resume behavior with -AutoResume flag to intelligently restart sync based on previous run status
    - -Force flag to override auto-resume logic and run sync regardless of previous success
    - Invoke-AutoResumeLogic function to evaluate previous run state and determine if sync should proceed
    - Clean start behavior (default) that removes existing state file when AutoResume is not set
    - Enhanced logging for resume/retry scenarios showing previous run context
    - Exit code 0 when previous run succeeded and -Force not set (with AutoResume)
    - Decision path logging clearly showing why sync is running or being skipped

    ### Changed
    - Initialize-StateFile now accepts CleanStart parameter for explicit state cleanup
    - Modified state initialization to log different messages for resume vs retry scenarios
    - Updated parameter documentation with AutoResume and Force usage examples

    ## 2.3.0 - 2026-01-13
    ### Added
    - Single-instance locking using named mutex to prevent concurrent runs
    - Mutex-based lock with 120-second timeout when another instance is running
    - Graceful exit with exit code 2 when lock cannot be acquired
    - Automatic lock release in finally block to ensure cleanup
    - Detailed logging for lock acquisition, waiting, and release

    ### Fixed
    - Handle AbandonedMutexException from crashed previous instances as successful lock acquisition
    - Prevent false-positive concurrent instance detection when previous run crashed unexpectedly

    ## 2.2.0 - 2026-01-13
    ### Added
    - Persistent state tracking with JSON state file (Sync-MacriumBackups_state.json)
    - State file records: lastRunId (GUID), status, startTime, endTime, lastExitCode, lastStep
    - Atomic state file writes using temporary file and rename
    - Detection and warning for interrupted runs (status=InProgress from previous run)
    - State updates at each major step: Initialize, Test-BackupPath, Test-Rclone, Test-Network, Sync-Backups
    - State finalization on success (Succeeded) and failure (Failed) with exit codes
    - Exception handling to mark state as Failed on unhandled errors

    ## 2.1.0 - 2026-01-13
    ### Changed
    - Configure logging to centralized Scripts\logs directory
    - Removed LogFile parameter (now automatically set to logs directory)
    - Framework logs: Sync-MacriumBackups.ps1_powershell_YYYY-MM-DD.log
    - Rclone logs: Sync-MacriumBackups_rclone.log
    - Added log path output on script start for verification

    ### Fixed
    - Use rclone's --log-file parameter instead of PowerShell redirection
    - Eliminates PowerShell stderr errors when rclone writes INFO messages
    - Cleaner log output without RemoteException errors

    ## 2.0.0 - 2025-11-16
    ### Changed
    - Migrated to PowerShellLoggingFramework.psm1 for standardized logging
    - Removed custom Write-Log function
    - Replaced Write-Log calls with Write-LogInfo, Write-LogError, Write-LogWarning
#>
param(
    # ===========================
    # Path Parameters
    # ===========================
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath = "E:\Macrium Backups",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RcloneRemote = "gdrive:",

    # ===========================
    # Network Parameters
    # ===========================
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^"`$|;&<>\r\n\t]+$')]
    [string]$PreferredSSID = "ManojNew_5G",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^"`$|;&<>\r\n\t]+$')]
    [string]$FallbackSSID = "ManojNew",

    # ===========================
    # Rclone Configuration
    # ===========================
    [Parameter(Mandatory=$false)]
    [ValidateRange(64, 4096)]
    [int]$MaxChunkMB = 2048,

    # ===========================
    # Execution Control
    # ===========================
    [Parameter(Mandatory=$false)]
    [switch]$Interactive,

    [Parameter(Mandatory=$false)]
    [switch]$AutoResume,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Script Version (extracted from .NOTES for programmatic access)
$ScriptVersion = "2.6.3"

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger with custom log directory at script root
# PSScriptRoot is at: Scripts\src\powershell\backup
# We need to go up 3 levels to reach Scripts root
$scriptRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$logDir = Join-Path $scriptRoot "logs"

# Create logs directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Set LogFile path for rclone output redirection (include date for traceability)
$dateStamp = (Get-Date).ToString("yyyy-MM-dd")
$LogFile = Join-Path $logDir "Sync-MacriumBackups_rclone_$dateStamp.log"

Initialize-Logger -resolvedLogDir $logDir -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Set StateFile path
$StateFile = Join-Path $logDir "Sync-MacriumBackups_state.json"

# Output log paths for verification
Write-Host "Framework logs: $($Global:LogConfig.LogFilePath)" -ForegroundColor Cyan
Write-Host "Rclone logs: $LogFile" -ForegroundColor Cyan
Write-Host "State file: $StateFile" -ForegroundColor Cyan
Write-LogInfo "Framework logs: $($Global:LogConfig.LogFilePath)"
Write-LogInfo "Rclone logs: $LogFile"
Write-LogInfo "State file: $StateFile"

Add-Type -Namespace SleepControl -Name PowerMgmt -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
"@ -Language CSharp

#region State Management Functions

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
        If the state file is corrupt or unreadable, it will be renamed with a timestamp
        to preserve it for debugging, and the function will return null to allow the script
        to continue with a fresh state.
    #>
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
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    try {
        # Convert hashtable to JSON
        $stateJson = $State | ConvertTo-Json -Depth 10

        # Write to temporary file
        $tempFile = "$StateFile.tmp"
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
        Helper function to mark a previous state as interrupted and persist it.
    .DESCRIPTION
        Centralizes the logic for marking an interrupted run, logging the details,
        and writing the updated state to the state file.
    .PARAMETER State
        The state object to mark as interrupted.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    Write-LogWarning "Previous run was interrupted (possible reboot/crash)"
    Write-LogInfo "Previous run details - Run ID: $($State.lastRunId), Started: $($State.startTime), Last step: $($State.lastStep)"

    # Mark the state as Interrupted
    $State.status = "Interrupted"
    $State.endTime = (Get-Date).ToString("o")
    $State.reason = "Previous run ended without completion (possible reboot/crash)"
    Write-StateFile -State $State
    Write-LogInfo "Previous state marked as Interrupted"
}

function Initialize-StateFile {
    <#
    .SYNOPSIS
        Initializes the state file at script start and checks for interrupted runs.
    .DESCRIPTION
        Creates a new run ID and sets status to InProgress.

        Behavior depends on AutoResume flag:
        - Without AutoResume: Performs clean start, removes any existing state
        - With AutoResume: Previous state has already been evaluated by Invoke-AutoResumeLogic
    .PARAMETER CleanStart
        When true, explicitly removes existing state file before creating new one (default behavior without AutoResume).
    #>
    param(
        [bool]$CleanStart = $false
    )

    # Check previous state
    $previousState = Read-StateFile

    # Handle interrupted state first (applies to both clean start and resume scenarios)
    if ($null -ne $previousState -and $previousState.status -eq "InProgress") {
        Mark-InterruptedState -State $previousState
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
        lastRunId = $newRunId
        scriptVersion = $ScriptVersion
        status = "InProgress"
        startTime = (Get-Date).ToString("o")
        endTime = $null
        lastExitCode = $null
        lastStep = "Initialize"
        syncStartTime = $null
        syncDurationSeconds = $null
    }

    Write-StateFile -State $newState
    Write-LogInfo "State tracking initialized. Run ID: $newRunId, Script version: $ScriptVersion"

    return $newState
}

function Update-StateStep {
    <#
    .SYNOPSIS
        Updates the lastStep field in the state file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    $currentState = Read-StateFile
    if ($null -ne $currentState) {
        $currentState.lastStep = $StepName
        Write-StateFile -State $currentState
    }
}

function Complete-StateFile {
    <#
    .SYNOPSIS
        Marks the state as completed (Succeeded or Failed) with end time, exit code, and sync duration.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Succeeded", "Failed")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 0,

        [Parameter(Mandatory = $false)]
        [double]$SyncDurationSeconds = $null
    )

    $currentState = Read-StateFile
    if ($null -ne $currentState) {
        $currentState.status = $Status
        $currentState.endTime = (Get-Date).ToString("o")
        $currentState.lastExitCode = $ExitCode

        if ($null -ne $SyncDurationSeconds) {
            $currentState.syncDurationSeconds = [math]::Round($SyncDurationSeconds, 2)
        }

        Write-StateFile -State $currentState

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
        When AutoResume is enabled, this function checks the previous run state and determines
        if the sync should run. Returns $true if sync should proceed, $false if it should skip.

        Decision logic:
        - If AutoResume not set: Always return $true (fresh run, handled by caller)
        - If AutoResume set:
          - No state file: Return $true (first run)
          - Last status "Succeeded" + Force not set: Return $false (skip)
          - Last status "Succeeded" + Force set: Return $true (forced run)
          - Last status "Failed" or "InProgress": Return $true (resume/retry)
    #>

    # If AutoResume is not set, the caller will handle fresh run initialization
    if (-not $AutoResume) {
        Write-LogInfo "AutoResume not enabled. Proceeding with fresh run."
        return $true
    }

    Write-LogInfo "AutoResume enabled. Checking previous run status..."

    # Read previous state
    $previousState = Read-StateFile

    # No state file exists - treat as first run
    if ($null -eq $previousState) {
        Write-LogInfo "No previous state file found. Treating as first run."
        return $true
    }

    $lastStatus = $previousState.status
    $lastRunId = $previousState.lastRunId
    $lastStartTime = $previousState.startTime

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
                # Exit gracefully without running sync
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

#endregion

#region Instance Locking Functions

function New-ScriptMutex {
    <#
    .SYNOPSIS
        Acquires a named mutex to prevent concurrent script execution.
    .DESCRIPTION
        Attempts to acquire a script-wide mutex. If another instance is running,
        waits for up to the specified timeout. Returns the mutex object if acquired,
        or $null if unable to acquire within timeout.

        Handles abandoned mutexes (from crashed instances) by treating them as
        successfully acquired and continuing execution.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 120
    )

    $mutexName = "Global\Sync-MacriumBackups-SingleInstance"

    try {
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)

        Write-LogInfo "Attempting to acquire instance lock (timeout: ${TimeoutSeconds}s)..."

        try {
            $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))
        }
        catch [System.Threading.AbandonedMutexException] {
            # Mutex is acquired, but previous owner didn't release it cleanly (crashed)
            Write-LogWarning "Previous instance crashed or exited unexpectedly (abandoned mutex). Lock acquired successfully."
            return $mutex
        }

        if ($acquired) {
            Write-LogInfo "Instance lock acquired successfully"
            return $mutex
        }
        else {
            Write-LogWarning "Could not acquire instance lock within ${TimeoutSeconds} seconds. Another instance may be running."
            $mutex.Dispose()
            return $null
        }
    }
    catch {
        Write-LogError "Failed to create or acquire mutex: $_"
        return $null
    }
}

function Release-ScriptMutex {
    <#
    .SYNOPSIS
        Releases the script instance mutex.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [System.Threading.Mutex]$Mutex
    )

    if ($null -ne $Mutex) {
        try {
            $Mutex.ReleaseMutex()
            $Mutex.Dispose()
            Write-LogInfo "Instance lock released"
        }
        catch {
            Write-LogWarning "Failed to release mutex: $_"
        }
    }
}

#endregion

function Test-BackupPath {
    Update-StateStep -StepName "Test-BackupPath"
    if (-not (Test-Path $SourcePath)) {
        Write-LogError "Backup source path '$SourcePath' is not accessible."
        Complete-StateFile -Status "Failed" -ExitCode 1
        exit 1
    }
    Write-LogInfo "Validated source path '$SourcePath'"
}

function Test-Rclone {
    Update-StateStep -StepName "Test-Rclone"
    $rcloneCheck = & rclone about $RcloneRemote 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Rclone Google Drive validation failed: $rcloneCheck"
        Complete-StateFile -Status "Failed" -ExitCode 1
        exit 1
    }
    Write-LogInfo "Validated Google Drive remote `"$RcloneRemote`""
}

function Test-WifiAdapter {
    <#
    .SYNOPSIS
    Validates that a Wi-Fi adapter/interface is present and enabled.

    .DESCRIPTION
    Checks for the presence of a Wi-Fi adapter by querying network interfaces.
    Returns $true if a valid Wi-Fi adapter is found, $false otherwise.
    #>

    try {
        $wlanInterfaces = netsh wlan show interfaces 2>&1

        # Check if the command succeeded and returned interface data
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Wi-Fi adapter query failed. WLAN AutoConfig service may not be running."
            return $false
        }

        # Check if output contains interface information
        $interfaceOutput = $wlanInterfaces -join "`n"
        if ([string]::IsNullOrWhiteSpace($interfaceOutput) -or $interfaceOutput -match "There is no wireless interface") {
            Write-LogError "No Wi-Fi adapter detected. Please ensure Wi-Fi hardware is enabled."
            return $false
        }

        return $true
    }
    catch {
        Write-LogError "Failed to check Wi-Fi adapter: $_"
        return $false
    }
}

function Get-CurrentSSID {
    <#
    .SYNOPSIS
    Safely retrieves the current Wi-Fi SSID with proper validation.

    .DESCRIPTION
    Parses netsh output to extract the SSID, using anchored regex to avoid
    matching BSSID or other fields. Returns the SSID string or $null if not found.
    #>

    try {
        $wlanOutput = netsh wlan show interfaces 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Failed to query Wi-Fi interfaces."
            return $null
        }

        # Use anchored regex to match only the SSID line, not BSSID
        # Pattern: start of line (^), optional whitespace (\s*), literal "SSID", optional whitespace, colon
        # This ensures we don't match "BSSID" which contains "SSID"
        $ssidLine = $wlanOutput | Where-Object { $_ -match '^\s*SSID\s*:' } | Select-Object -First 1

        if (-not $ssidLine) {
            Write-LogError "Could not find SSID in netsh output. Wi-Fi may not be connected."
            return $null
        }

        # Extract the SSID value after the colon
        $ssid = ($ssidLine -split ':', 2)[1].Trim()

        if ([string]::IsNullOrWhiteSpace($ssid)) {
            Write-LogError "Parsed SSID is empty. Wi-Fi may not be connected to a network."
            return $null
        }

        return $ssid
    }
    catch {
        Write-LogError "Failed to parse SSID: $_"
        return $null
    }
}

function Test-Network {
    Update-StateStep -StepName "Test-Network"
    # Use Google's public DNS for internet connectivity test
    $connectivityTestTarget = "8.8.8.8"

    # Step 0: Pre-check Wi-Fi adapter presence
    if (-not (Test-WifiAdapter)) {
        Write-LogError "Wi-Fi adapter validation failed. Cannot proceed with network connectivity test."
        Complete-StateFile -Status "Failed" -ExitCode 1
        exit 1
    }

    # Step 1: Get current SSID with proper validation
    $currentSSID = Get-CurrentSSID

    # Treat null SSID as disconnected state - allow reconnection attempt
    if ($null -eq $currentSSID) {
        Write-LogInfo "Wi-Fi adapter is present but not connected. Will attempt to connect..."
        # Set to empty string to trigger the "not connected" branch below
        $currentSSID = ""
    }

    if ($currentSSID -eq $PreferredSSID) {
        Write-LogInfo "Connected to preferred network '$PreferredSSID'"
    }
    elseif ($currentSSID -eq $FallbackSSID) {
        # Try to switch to preferred if available
        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-LogInfo "Switching from '$FallbackSSID' to preferred network '$PreferredSSID'"
            netsh wlan connect name="$PreferredSSID"
            Start-Sleep -Seconds 10

            $currentSSID = Get-CurrentSSID
            if ($null -eq $currentSSID) {
                Write-LogWarning "Unable to verify SSID after connection attempt. Assuming connection failed."
                $currentSSID = $FallbackSSID
            }

            if ($currentSSID -eq $PreferredSSID) {
                Write-LogInfo "Switched successfully to '$PreferredSSID'"
            }
            else {
                Write-LogWarning "Failed to switch to '$PreferredSSID'. Continuing on '$FallbackSSID'"
            }
        }
        else {
            Write-LogInfo "Preferred network '$PreferredSSID' not available. Staying on '$FallbackSSID'"
        }
    }
    else {
        Write-LogInfo "Not connected to either '$PreferredSSID' or '$FallbackSSID'. Trying to connect..."

        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-LogInfo "Connecting to preferred network '$PreferredSSID'"
            netsh wlan connect name="$PreferredSSID"
        }
        elseif ($availableNetworks -match $FallbackSSID) {
            Write-LogInfo "Connecting to fallback network '$FallbackSSID'"
            netsh wlan connect name="$FallbackSSID"
        }
        else {
            Write-LogError "Neither '$PreferredSSID' nor '$FallbackSSID' WiFi networks are available."
            Complete-StateFile -Status "Failed" -ExitCode 1
            exit 1
        }

        Start-Sleep -Seconds 10

        $currentSSID = Get-CurrentSSID
        if ($null -eq $currentSSID) {
            Write-LogError "Unable to verify SSID after connection attempt. Connection likely failed."
            Complete-StateFile -Status "Failed" -ExitCode 1
            exit 1
        }

        if ($currentSSID -ne $PreferredSSID -and $currentSSID -ne $FallbackSSID) {
            Write-LogError "Failed to connect to preferred or fallback WiFi networks. Connected to: '$currentSSID'"
            Complete-StateFile -Status "Failed" -ExitCode 1
            exit 1
        }

        Write-LogInfo "Connected to WiFi network '$currentSSID'"
    }

    # Step 2: Internet test
    if (-not (Test-Connection -ComputerName $connectivityTestTarget -Count 2 -Quiet)) {
        Write-LogError "No internet connection. Sync aborted."
        Complete-StateFile -Status "Failed" -ExitCode 1
        exit 1
    }

    Write-LogInfo "Internet connectivity validated"
}

function Get-ChunkSize {
    # Get available physical memory in MB
    $freeMB = [math]::Floor((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1024)

    # Use half of available memory as upper limit
    $halfFreeMB = [math]::Floor($freeMB / 2)

    # Allowed rclone chunk sizes (in MB)
    $allowedSizes = @(64, 128, 256, 512, 1024, 2048, 4096)

    # Select the largest allowable chunk size that fits within both thresholds
    $chunk = $allowedSizes | Where-Object { $_ -le $halfFreeMB -and $_ -le $MaxChunkMB } | Select-Object -Last 1

    if (-not $chunk) {
        $chunk = 64  # Default fallback
    }

    Write-LogInfo "Available memory: ${freeMB}MB. Dynamic chunk size set to ${chunk}MB"
    return "$chunk" + "M"
}

function Get-SanitizedRcloneArgs {
    param([string[]]$Args)

    $sensitiveFlags = @(
        "--password",
        "--password-command",
        "--pass",
        "--token",
        "--client-id",
        "--client-secret",
        "--account",
        "--config",
        "--crypt-password",
        "--crypt-remote",
        "--drive-client-secret",
        "--drive-client-id"
    )

    $sanitized = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Args.Count; $i++) {
        $arg = $Args[$i]
        $splitArg = $arg -split "=", 2

        if ($splitArg.Count -eq 2 -and $sensitiveFlags -contains $splitArg[0]) {
            $sanitized.Add("$($splitArg[0])=******")
            continue
        }

        if ($sensitiveFlags -contains $arg) {
            $sanitized.Add($arg)
            if ($i + 1 -lt $Args.Count) {
                $sanitized.Add("******")
                $i++
            }
            continue
        }

        $sanitized.Add($arg)
    }

    return $sanitized.ToArray()
}

function Format-RcloneCommandLine {
    param([string[]]$Args)

    $formattedArgs = $Args | ForEach-Object {
        if ($_ -match "\s") { '"' + $_ + '"' } else { $_ }
    }

    return "rclone " + ($formattedArgs -join " ")
}

function Sync-Backups {
    Update-StateStep -StepName "Sync-Backups"
    $chunkSize = Get-ChunkSize
    $rcloneArgs = @(
        "sync", $SourcePath, $RcloneRemote,
        "--drive-chunk-size", $chunkSize,
        "--drive-use-trash=false",
        "--delete-before",
        "--retries", "5",
        "--low-level-retries", "10",
        "--timeout", "5m",
        "--log-level=INFO",
        "--log-format", "date,time",
        "--log-date-format", "2006-01-02 15:04:05.000"
    )

    # Adjust logging based on mode
    if ($Interactive) {
        $rcloneArgs += "--progress"
        Write-LogInfo "Running rclone in interactive mode (output goes to console)"
    }
    else {
        # Use rclone's --log-file to write directly to log (avoids PowerShell stderr issues)
        $rcloneArgs += "--log-file=$LogFile"
        Write-LogInfo "Running rclone in non-interactive mode (output logged to $LogFile)"
    }

    $sanitizedArgs = Get-SanitizedRcloneArgs -Args $rcloneArgs
    $sanitizedCommandLine = Format-RcloneCommandLine -Args $sanitizedArgs

    # Log the full command line for debugging (especially important when rclone fails)
    Write-LogInfo "Rclone command line (sanitized, single-line):"
    Write-LogInfo "  $sanitizedCommandLine"
    Write-LogInfo "Rclone command line (sanitized, multi-line):"
    Write-LogInfo "  rclone"
    foreach ($arg in $sanitizedArgs) {
        $formattedArg = if ($arg -match "\s") { "`"$arg`"" } else { $arg }
        Write-LogInfo "    $formattedArg"
    }
    Write-LogInfo "Starting sync with chunk size: $chunkSize"

    # Capture sync start time and persist to state
    $syncStartTime = Get-Date
    $currentState = Read-StateFile
    if ($null -ne $currentState) {
        $currentState.syncStartTime = $syncStartTime.ToString("o")
        Write-StateFile -State $currentState
    }

    # Run rclone and capture duration
    & rclone @rcloneArgs
    $rcloneExitCode = $LASTEXITCODE
    $syncEndTime = Get-Date
    $syncDuration = ($syncEndTime - $syncStartTime).TotalSeconds

    # Post-run verification summary
    Write-LogInfo "=== Post-Run Verification Summary ==="
    Write-LogInfo "Rclone exit code: $rcloneExitCode"
    Write-LogInfo "Sync duration: $(Format-Duration -Seconds $syncDuration)"
    Write-LogInfo "===================================="

    if ($rcloneExitCode -eq 0) {
        Write-LogInfo "Sync completed successfully"
        Complete-StateFile -Status "Succeeded" -ExitCode $rcloneExitCode -SyncDurationSeconds $syncDuration
    }
    else {
        Write-LogError "Sync failed with exit code $rcloneExitCode"
        Complete-StateFile -Status "Failed" -ExitCode $rcloneExitCode -SyncDurationSeconds $syncDuration
        exit $rcloneExitCode
    }
}

# Execution Flow
try {
    Write-LogInfo "Starting Macrium backup sync script (version $ScriptVersion)"

    # Check auto-resume logic to determine if sync should run
    $shouldProceed = Invoke-AutoResumeLogic

    if (-not $shouldProceed) {
        # Previous run succeeded and Force not set - exit gracefully
        Write-LogInfo "Exiting without running sync. Previous run already succeeded."
        exit 0
    }

    # Initialize state tracking
    # Use CleanStart when AutoResume is NOT set (default behavior)
    $cleanStart = -not $AutoResume
    $script:currentState = Initialize-StateFile -CleanStart $cleanStart

    # Acquire instance lock to prevent concurrent runs
    $script:instanceMutex = New-ScriptMutex -TimeoutSeconds 120
    if ($null -eq $script:instanceMutex) {
        Write-LogWarning "Skipping sync run - another instance is already running"
        Complete-StateFile -Status "Failed" -ExitCode 2
        exit 2
    }

    # Prevent sleep & display timeout
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000003") | Out-Null
    Write-LogInfo "System sleep and display timeout temporarily disabled"

    # Main execution
    Test-BackupPath
    Test-Rclone
    Test-Network
    Sync-Backups
}
catch {
    Write-LogError "Unhandled exception: $_"
    Complete-StateFile -Status "Failed" -ExitCode 1
    throw
}
finally {
    # Release instance lock
    Release-ScriptMutex -Mutex $script:instanceMutex

    # Restore normal sleep behavior
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000000") | Out-Null
    Write-LogInfo "System sleep and display timeout restored"
    Write-LogInfo "Script execution completed"
}
