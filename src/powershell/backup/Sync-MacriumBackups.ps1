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

.PARAMETER LogFile
    Full path to the log file where execution details are appended. Default: "$env:USERPROFILE\Documents\Scripts\Sync-MacriumBackups.log".

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
    Version: 2.0.0

    CHANGELOG
    ## 2.0.0 - 2025-11-16
    ### Changed
    - Migrated to PowerShellLoggingFramework.psm1 for standardized logging
    - Removed custom Write-Log function
    - Replaced Write-Log calls with Write-LogInfo, Write-LogError, Write-LogWarning
#>
param(
    [string]$SourcePath = "E:\Macrium Backups",
    [string]$RcloneRemote = "gdrive:",
    [string]$LogFile = "C:\Users\manoj\Documents\Scripts\Sync-MacriumBackups.log",
    [int]$MaxChunkMB = 2048,
    [string]$PreferredSSID = "ManojNew_5G",
    [string]$FallbackSSID  = "ManojNew",
    [switch]$Interactive
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

Add-Type -Namespace SleepControl -Name PowerMgmt -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
"@ -Language CSharp

function Test-BackupPath {
    if (-not (Test-Path $SourcePath)) {
        Write-LogError "Backup source path '$SourcePath' is not accessible."
        exit 1
    }
    Write-LogInfo "Validated source path '$SourcePath'"
}

function Test-Rclone {
    $rcloneCheck = & rclone about $RcloneRemote 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Rclone Google Drive validation failed: $rcloneCheck"
        exit 1
    }
    Write-LogInfo "Validated Google Drive remote `"$RcloneRemote`""
}

function Test-Network {

    # Step 1: Get current SSID
    $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()

    if ($currentSSID -eq $PreferredSSID) {
        Write-LogInfo "Connected to preferred network '$PreferredSSID'"
    } elseif ($currentSSID -eq $FallbackSSID) {
        # Try to switch to preferred if available
        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-LogInfo "Switching from '$FallbackSSID' to preferred network '$PreferredSSID'"
            netsh wlan connect name=$PreferredSSID
            Start-Sleep -Seconds 10
            $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
            if ($currentSSID -eq $PreferredSSID) {
                Write-LogInfo "Switched successfully to '$PreferredSSID'"
            } else {
                Write-LogWarning "Failed to switch to '$PreferredSSID'. Continuing on '$FallbackSSID'"
            }
        } else {
            Write-LogInfo "Preferred network '$PreferredSSID' not available. Staying on '$FallbackSSID'"
        }
    } else {
        Write-LogInfo "Not connected to either '$PreferredSSID' or '$FallbackSSID'. Trying to connect..."

        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-LogInfo "Connecting to preferred network '$PreferredSSID'"
            netsh wlan connect name=$PreferredSSID
        } elseif ($availableNetworks -match $FallbackSSID) {
            Write-LogInfo "Connecting to fallback network '$FallbackSSID'"
            netsh wlan connect name=$FallbackSSID
        } else {
            Write-LogError "Neither '$PreferredSSID' nor '$FallbackSSID' WiFi networks are available."
            exit 1
        }

        Start-Sleep -Seconds 10
        $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
        if ($currentSSID -ne $PreferredSSID -and $currentSSID -ne $FallbackSSID) {
            Write-LogError "Failed to connect to preferred or fallback WiFi networks."
            exit 1
        }

        Write-LogInfo "Connected to WiFi network '$currentSSID'"
    }

    # Step 2: Internet test
    if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet)) {
        Write-LogError "No internet connection. Sync aborted."
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
    $chunkSize = Get-ChunkSize
    $rcloneArgs = @(
        "sync", $SourcePath, $RcloneRemote,
        "--drive-chunk-size", $chunkSize,
        "--drive-use-trash=false",
        "--delete-before",
        "--retries", "5",
        "--low-level-retries", "10",
        "--timeout", "5m"
    )

    # Adjust logging based on mode
    if ($Interactive) {
        $rcloneArgs += "--progress"
        $rcloneArgs += "--log-level=INFO"  # keep log messages for clarity
    } else {
        $rcloneArgs += "--log-level=INFO"
    }
    Write-LogInfo "Starting sync with chunk size: $chunkSize"
    if ($Interactive) {
        Write-LogInfo "Running rclone in interactive mode (output goes to console)"
        & rclone @rcloneArgs
    } else {
        Write-LogInfo "Running rclone in non-interactive mode (output redirected to log)"
        & rclone @rcloneArgs *>> $LogFile
    }
    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "Sync completed successfully"
    } else {
        Write-LogError "Sync failed with exit code $LASTEXITCODE"
    }
}

# Ensure log directory exists
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Execution Flow
try {
    Write-LogInfo "Starting Macrium backup sync script"
    # Prevent sleep & display timeout
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000003") | Out-Null
    Write-LogInfo "System sleep and display timeout temporarily disabled"

    # Main execution
    Test-BackupPath
    Test-Rclone
    Test-Network
    Sync-Backups
}
finally {
    # Restore normal sleep behavior
    [SleepControl.PowerMgmt]::SetThreadExecutionState([uint32]"0x80000000") | Out-Null
    Write-LogInfo "System sleep and display timeout restored"
    Write-LogInfo "Script execution completed"
}