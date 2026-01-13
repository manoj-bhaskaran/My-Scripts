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

.EXAMPLE
    .\Sync-MacriumBackups.ps1

    Runs the sync using default source path, remote, and logging settings in non-interactive mode.

.EXAMPLE
    .\Sync-MacriumBackups.ps1 -Interactive

    Runs the sync with rclone --progress output shown on the console, suitable for manual invocation.

.NOTES
    Version: 2.2.0

    CHANGELOG
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
    [string]$SourcePath = "E:\Macrium Backups",
    [string]$RcloneRemote = "gdrive:",
    [int]$MaxChunkMB = 2048,
    [string]$PreferredSSID = "ManojNew_5G",
    [string]$FallbackSSID = "ManojNew",
    [switch]$Interactive
)

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

# Set LogFile path for rclone output redirection
$LogFile = Join-Path $logDir "Sync-MacriumBackups_rclone.log"

Initialize-Logger -resolvedLogDir $logDir -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Set StateFile path
$StateFile = Join-Path $logDir "Sync-MacriumBackups_state.json"

# Output log paths for verification
Write-Host "Framework logs: $($Global:LogConfig.LogFilePath)" -ForegroundColor Cyan
Write-Host "Rclone logs: $LogFile" -ForegroundColor Cyan
Write-Host "State file: $StateFile" -ForegroundColor Cyan

Add-Type -Namespace SleepControl -Name PowerMgmt -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
"@ -Language CSharp

#region State Management Functions

function Read-StateFile {
    <#
    .SYNOPSIS
        Reads the state file if it exists and returns the state object.
    #>
    if (Test-Path $StateFile) {
        try {
            $stateJson = Get-Content -Path $StateFile -Raw -ErrorAction Stop
            return ($stateJson | ConvertFrom-Json)
        }
        catch {
            Write-LogWarning "Failed to read state file: $_"
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

function Initialize-StateFile {
    <#
    .SYNOPSIS
        Initializes the state file at script start and checks for interrupted runs.
    .DESCRIPTION
        Creates a new run ID and sets status to InProgress. If a previous run was
        in progress, it logs a warning about the interrupted run.
    #>
    # Check previous state
    $previousState = Read-StateFile

    if ($null -ne $previousState -and $previousState.status -eq "InProgress") {
        Write-LogWarning "Previous run (ID: $($previousState.lastRunId)) was interrupted. Last step: $($previousState.lastStep)"
        Write-LogWarning "Previous run started at: $($previousState.startTime)"
    }

    # Create new state
    $newRunId = [guid]::NewGuid().ToString()
    $newState = @{
        lastRunId = $newRunId
        status = "InProgress"
        startTime = (Get-Date).ToString("o")
        endTime = $null
        lastExitCode = $null
        lastStep = "Initialize"
    }

    Write-StateFile -State $newState
    Write-LogInfo "State tracking initialized. Run ID: $newRunId"

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
        Marks the state as completed (Succeeded or Failed) with end time and exit code.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Succeeded", "Failed")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 0
    )

    $currentState = Read-StateFile
    if ($null -ne $currentState) {
        $currentState.status = $Status
        $currentState.endTime = (Get-Date).ToString("o")
        $currentState.lastExitCode = $ExitCode
        Write-StateFile -State $currentState
        Write-LogInfo "State finalized: $Status (Exit code: $ExitCode)"
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

function Test-Network {
    Update-StateStep -StepName "Test-Network"
    # Use Google's public DNS for internet connectivity test
    $connectivityTestTarget = "8.8.8.8"

    # Step 1: Get current SSID
    $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()

    if ($currentSSID -eq $PreferredSSID) {
        Write-LogInfo "Connected to preferred network '$PreferredSSID'"
    }
    elseif ($currentSSID -eq $FallbackSSID) {
        # Try to switch to preferred if available
        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-LogInfo "Switching from '$FallbackSSID' to preferred network '$PreferredSSID'"
            netsh wlan connect name=$PreferredSSID
            Start-Sleep -Seconds 10
            $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
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
            netsh wlan connect name=$PreferredSSID
        }
        elseif ($availableNetworks -match $FallbackSSID) {
            Write-LogInfo "Connecting to fallback network '$FallbackSSID'"
            netsh wlan connect name=$FallbackSSID
        }
        else {
            Write-LogError "Neither '$PreferredSSID' nor '$FallbackSSID' WiFi networks are available."
            Complete-StateFile -Status "Failed" -ExitCode 1
            exit 1
        }

        Start-Sleep -Seconds 10
        $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
        if ($currentSSID -ne $PreferredSSID -and $currentSSID -ne $FallbackSSID) {
            Write-LogError "Failed to connect to preferred or fallback WiFi networks."
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
    $allowedSizes = @(64, 128, 256, 512, 1024, 2048)

    # Select the largest allowable chunk size that fits within both thresholds
    $chunk = $allowedSizes | Where-Object { $_ -le $halfFreeMB -and $_ -le $MaxChunkMB } | Select-Object -Last 1

    if (-not $chunk) {
        $chunk = 64  # Default fallback
    }

    Write-LogInfo "Available memory: ${freeMB}MB. Dynamic chunk size set to ${chunk}MB"
    return "$chunk" + "M"
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
        "--log-level=INFO"
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

    Write-LogInfo "Starting sync with chunk size: $chunkSize"
    & rclone @rcloneArgs

    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "Sync completed successfully"
        Complete-StateFile -Status "Succeeded" -ExitCode 0
    }
    else {
        Write-LogError "Sync failed with exit code $LASTEXITCODE"
        Complete-StateFile -Status "Failed" -ExitCode $LASTEXITCODE
        exit $LASTEXITCODE
    }
}

# Execution Flow
try {
    Write-LogInfo "Starting Macrium backup sync script"

    # Initialize state tracking
    $script:currentState = Initialize-StateFile

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
    # Restore normal sleep behavior
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000000") | Out-Null
    Write-LogInfo "System sleep and display timeout restored"
    Write-LogInfo "Script execution completed"
}
