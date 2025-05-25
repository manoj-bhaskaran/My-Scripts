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
#>
param(
    [string]$SourcePath = "E:\Macrium Backups",
    [string]$RcloneRemote = "gdrive",
    [string]$LogFile = "C:\Users\manoj\Documents\Scripts\Sync-MacriumBackups.log",
    [int]$MaxChunkMB = 2048,
    [string]$PreferredSSID = "ManojNew_5G",
    [string]$FallbackSSID  = "ManojNew"
)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
}

function Test-BackupPath {
    if (-not (Test-Path $SourcePath)) {
        Write-Log "Backup source path '$SourcePath' is not accessible." "ERROR"
        exit 1
    }
    Write-Log "Validated source path '$SourcePath'"
}

function Test-Rclone {
    $rcloneCheck = & rclone about "`"$RcloneRemote`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Rclone Google Drive validation failed: $rcloneCheck" "ERROR"
        exit 1
    }
    Write-Log "Validated Google Drive remote "`"$RcloneRemote`"""
}

function Test-Network {

    # Step 1: Get current SSID
    $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()

    if ($currentSSID -eq $PreferredSSID) {
        Write-Log "Connected to preferred network '$preferred'"
    } elseif ($currentSSID -eq $FallbackSSID) {
        # Try to switch to preferred if available
        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-Log "Switching from '$FallbackSSID' to preferred network '$PreferredSSID'"
            netsh wlan connect name=$PreferredSSID
            Start-Sleep -Seconds 10
            $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
            if ($currentSSID -eq $PreferredSSID) {
                Write-Log "Switched successfully to '$PreferredSSIDd'"
            } else {
                Write-Log "Failed to switch to '$PreferredSSID'. Continuing on '$FallbackSSID'" "WARNING"
            }
        } else {
            Write-Log "Preferred network '$PreferredSSID' not available. Staying on '$FallbackSSID'"
        }
    } else {
        Write-Log "Not connected to either '$PreferredSSID' or '$FallbackSSID'. Trying to connect..."

        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $PreferredSSID) {
            Write-Log "Connecting to preferred network '$PreferredSSID'"
            netsh wlan connect name=$PreferredSSID
        } elseif ($availableNetworks -match $FallbackSSID) {
            Write-Log "Connecting to fallback network '$FallbackSSID'"
            netsh wlan connect name=$FallbackSSID
        } else {
            Write-Log "Neither '$PreferredSSID' nor '$FallbackSSID' WiFi networks are available." "ERROR"
            exit 1
        }

        Start-Sleep -Seconds 10
        $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
        if ($currentSSID -ne $PreferredSSID -and $currentSSID -ne $FallbackSSID) {
            Write-Log "Failed to connect to preferred or fallback WiFi networks." "ERROR"
            exit 1
        }

        Write-Log "Connected to WiFi network '$currentSSID'"
    }

    # Step 2: Internet test
    if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet)) {
        Write-Log "No internet connection. Sync aborted." "ERROR"
        exit 1
    }

    Write-Log "Internet connectivity validated"
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

    Write-Log "Available memory: ${freeMB}MB. Dynamic chunk size set to ${chunk}MB"
    return "$chunk" + "M"
}

function Sync-Backups {
    $chunkSize = Get-ChunkSize
    $rcloneArgs = @(
        "sync", "`"$SourcePath`"", "`"$RcloneRemote`"",
        "--drive-chunk-size", $chunkSize,
        "--drive-use-trash=false",
        "--delete-before",
        "--verbose",
        "--retries", "5",
        "--low-level-retries", "10",
        "--timeout", "5m"
    )
    Write-Log "Starting sync with chunk size: $chunkSize"
    & rclone @rcloneArgs *>> $LogFile
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Sync completed successfully"
    } else {
        Write-Log "Sync failed with exit code $LASTEXITCODE" "ERROR"
    }
}

# Ensure log directory exists
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Execution Flow
Write-Log "========== Starting Macrium Backup Sync =========="
Test-BackupPath
Test-Rclone
Test-Network
Sync-Backups
Write-Log "========== Sync Operation Ended =========="
