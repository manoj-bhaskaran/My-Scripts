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
    Version: 2.7.2
    Author: Manoj Bhaskaran

    See CHANGELOG.md for version history.
#>
param(
    # ===========================
    # Path Parameters
    # ===========================
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath = "E:\Macrium Backups",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RcloneRemote = "gdrive:",

    # ===========================
    # Network Parameters
    # ===========================
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^"`$|;&<>\r\n\t]+$')]
    [string]$PreferredSSID = "ManojNew_5G",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^"`$|;&<>\r\n\t]+$')]
    [string]$FallbackSSID = "ManojNew",

    # ===========================
    # Rclone Configuration
    # ===========================
    [Parameter(Mandatory = $false)]
    [ValidateRange(64, 4096)]
    [int]$MaxChunkMB = 2048,

    # ===========================
    # Execution Control
    # ===========================
    [Parameter(Mandatory = $false)]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [switch]$AutoResume,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script Version (extracted from .NOTES for programmatic access)
$ScriptVersion = "2.7.2"

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Import BackupState module
Import-Module "$PSScriptRoot\..\modules\Backup\BackupState.psm1" -Force

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
    param([Parameter(Mandatory = $true)][object]$State)
    Update-StateStep -StateFile $StateFile -State $State -StepName "Test-BackupPath"
    if (-not (Test-Path $SourcePath)) {
        Write-LogError "Backup source path '$SourcePath' is not accessible."
        Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
        exit 1
    }
    Write-LogInfo "Validated source path '$SourcePath'"
}

function Test-Rclone {
    param([Parameter(Mandatory = $true)][object]$State)
    Update-StateStep -StateFile $StateFile -State $State -StepName "Test-Rclone"
    $rcloneCheck = & rclone about $RcloneRemote 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Rclone Google Drive validation failed: $rcloneCheck"
        Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
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

function Connect-WiFiNetwork {
    <#
    .SYNOPSIS
    Issues a netsh wlan connect command and returns the resulting SSID.

    .DESCRIPTION
    Connects to the specified Wi-Fi network, waits for the connection to settle,
    then returns the current SSID as reported by Get-CurrentSSID. Returns $null
    if the SSID cannot be verified after the connection attempt.

    .PARAMETER SSID
    The SSID of the Wi-Fi network to connect to.

    .PARAMETER TimeoutSeconds
    Number of seconds to wait after issuing the connect command before verifying.
    Default: 10.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SSID,
        [Parameter(Mandatory = $false)][int]$TimeoutSeconds = 10
    )
    netsh wlan connect name="$SSID"
    Start-Sleep -Seconds $TimeoutSeconds
    return Get-CurrentSSID
}

function Test-Network {
    param([Parameter(Mandatory = $true)][object]$State)
    Update-StateStep -StateFile $StateFile -State $State -StepName "Test-Network"
    # Use Google's public DNS for internet connectivity test
    $connectivityTestTarget = "8.8.8.8"

    # Step 0: Pre-check Wi-Fi adapter presence
    if (-not (Test-WifiAdapter)) {
        Write-LogError "Wi-Fi adapter validation failed. Cannot proceed with network connectivity test."
        Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
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
            $currentSSID = Connect-WiFiNetwork -SSID $PreferredSSID -TimeoutSeconds 10
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
            $targetSSID = $PreferredSSID
        }
        elseif ($availableNetworks -match $FallbackSSID) {
            Write-LogInfo "Connecting to fallback network '$FallbackSSID'"
            $targetSSID = $FallbackSSID
        }
        else {
            Write-LogError "Neither '$PreferredSSID' nor '$FallbackSSID' WiFi networks are available."
            Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
            exit 1
        }
        $currentSSID = Connect-WiFiNetwork -SSID $targetSSID -TimeoutSeconds 10
        if ($null -eq $currentSSID) {
            Write-LogError "Unable to verify SSID after connection attempt. Connection likely failed."
            Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
            exit 1
        }
        if ($currentSSID -ne $PreferredSSID -and $currentSSID -ne $FallbackSSID) {
            Write-LogError "Failed to connect to preferred or fallback WiFi networks. Connected to: '$currentSSID'"
            Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
            exit 1
        }
        Write-LogInfo "Connected to WiFi network '$currentSSID'"
    }

    # Step 2: Internet test
    if (-not (Test-Connection -ComputerName $connectivityTestTarget -Count 2 -Quiet)) {
        Write-LogError "No internet connection. Sync aborted."
        Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode 1
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
    param([string[]]$Arguments)

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

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]
        $splitArg = $arg -split "=", 2

        if ($splitArg.Count -eq 2 -and $sensitiveFlags -contains $splitArg[0]) {
            $sanitized.Add("$($splitArg[0])=******")
            continue
        }

        if ($sensitiveFlags -contains $arg) {
            $sanitized.Add($arg)
            if ($i + 1 -lt $Arguments.Count) {
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
    param([string[]]$Arguments)

    $formattedArgs = $Arguments | ForEach-Object {
        if ($_ -match "\s") { '"' + $_ + '"' } else { $_ }
    }

    return "rclone " + ($formattedArgs -join " ")
}

function Sync-Backups {
    param([Parameter(Mandatory = $true)][object]$State)
    Update-StateStep -StateFile $StateFile -State $State -StepName "Sync-Backups"
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
        "--log-format", "date,time,microseconds"
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

    $sanitizedArgs = Get-SanitizedRcloneArgs -Arguments $rcloneArgs
    $sanitizedCommandLine = Format-RcloneCommandLine -Arguments $sanitizedArgs

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
    $State.syncStartTime = $syncStartTime.ToString("o")
    Write-StateFile -StateFile $StateFile -State $State

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
        Complete-StateFile -StateFile $StateFile -State $State -Status "Succeeded" -ExitCode $rcloneExitCode -SyncDurationSeconds $syncDuration
    }
    else {
        Write-LogError "Sync failed with exit code $rcloneExitCode"
        Complete-StateFile -StateFile $StateFile -State $State -Status "Failed" -ExitCode $rcloneExitCode -SyncDurationSeconds $syncDuration
        exit $rcloneExitCode
    }
}

# Execution Flow
try {
    Write-LogInfo "Starting Macrium backup sync script (version $ScriptVersion)"

    # Read previous state once; pass through to avoid redundant disk reads
    $previousState = Read-StateFile -StateFile $StateFile

    # Check auto-resume logic to determine if sync should run
    $shouldProceed = Invoke-AutoResumeLogic -PreviousState $previousState -AutoResume ([bool]$AutoResume) -Force ([bool]$Force)

    if (-not $shouldProceed) {
        # Previous run succeeded and Force not set - exit gracefully
        Write-LogInfo "Exiting without running sync. Previous run already succeeded."
        exit 0
    }

    # Initialize state tracking
    # Use CleanStart when AutoResume is NOT set (default behavior)
    $cleanStart = -not $AutoResume
    $script:currentState = Initialize-StateFile -StateFile $StateFile -ScriptVersion $ScriptVersion -CleanStart $cleanStart -PreviousState $previousState

    # Acquire instance lock to prevent concurrent runs
    $script:instanceMutex = New-ScriptMutex -TimeoutSeconds 120
    if ($null -eq $script:instanceMutex) {
        Write-LogWarning "Skipping sync run - another instance is already running"
        Complete-StateFile -StateFile $StateFile -State $script:currentState -Status "Failed" -ExitCode 2
        exit 2
    }

    # Prevent sleep & display timeout
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000003") | Out-Null
    Write-LogInfo "System sleep and display timeout temporarily disabled"

    # Main execution
    Test-BackupPath -State $script:currentState
    Test-Rclone -State $script:currentState
    Test-Network -State $script:currentState
    Sync-Backups -State $script:currentState
}
catch {
    Write-LogError "Unhandled exception: $_"
    if ($null -ne $script:currentState) {
        Complete-StateFile -StateFile $StateFile -State $script:currentState -Status "Failed" -ExitCode 1
    }
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
