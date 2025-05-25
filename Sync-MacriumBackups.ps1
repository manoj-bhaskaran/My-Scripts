<#
.SYNOPSIS
    Syncs Macrium Reflect backup files from an external HDD to Google Drive using rclone with validations and dynamic tuning.

.DESCRIPTION
    This script automates the synchronization of Macrium backup files stored on an external HDD (e.g., "E:\Macrium Backups") to a specified Google Drive remote using rclone.
    
    Key features:
    - Validates presence of the backup source path.
    - Verifies internet connectivity and ensures connection to a preferred WiFi network (e.g., "ManojNew_5G").
    - Attempts to switch to the preferred WiFi if not currently connected.
    - Validates rclone remote connectivity.
    - Dynamically calculates optimal --drive-chunk-size based on available system memory.
    - Appends logs to a single persistent log file.
    - Uses rclone's recommended options for performance and reliability.
    - Logs key events, errors, and decisions throughout execution.

.PARAMETER SourcePath
    The local path to the Macrium backup folder. Default: "E:\Macrium Backups".

.PARAMETER RcloneRemote
    The rclone remote name to sync to. Default: "gdrive".

.PARAMETER LogFile
    Full path to the log file where execution details will be appended. Default: "C:\Users\<User>\Documents\Scripts\Sync-MacriumBackups.log".

.PARAMETER MaxChunkMB
    Maximum chunk size (in MB) to be used for rclone uploads. Actual chunk size is dynamically selected based on available memory. Default: 2048.

.NOTES
    Requires rclone to be installed and the specified remote to be configured.
    Requires WiFi profiles for both ManojNew_5G and ManojNew to be pre-saved on the system.
    For best results, run this script after Macrium Reflect has completed its backup job.

.EXAMPLE
    .\Sync-MacriumBackups.ps1

    Runs the sync using default source path, rclone remote, and log file location.

.EXAMPLE
    .\Sync-MacriumBackups.ps1 -SourcePath "F:\Backups" -RcloneRemote "gdrive:Macrium" -LogFile "D:\Logs\macrium-sync.log" -MaxChunkMB 1024
#>
param(
    [string]$SourcePath = "E:\Macrium Backups",
    [string]$RcloneRemote = "gdrive",
    [string]$LogFile = "C:\Users\manoj\Documents\Scripts\Sync-MacriumBackups.log",
    [int]$MaxChunkMB = 2048
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
    $rcloneCheck = & rclone about $RcloneRemote 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Rclone Google Drive validation failed: $rcloneCheck" "ERROR"
        exit 1
    }
    Write-Log "Validated Google Drive remote '$RcloneRemote'"
}

function Test-Network {
    $preferred = "ManojNew_5G"
    $fallback = "ManojNew"

    # Step 1: Get current SSID
    $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()

    if ($currentSSID -eq $preferred) {
        Write-Log "Connected to preferred network '$preferred'"
    } elseif ($currentSSID -eq $fallback) {
        # Try to switch to preferred if available
        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $preferred) {
            Write-Log "Switching from '$fallback' to preferred network '$preferred'"
            netsh wlan connect name=$preferred
            Start-Sleep -Seconds 5
            $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
            if ($currentSSID -eq $preferred) {
                Write-Log "Switched successfully to '$preferred'"
            } else {
                Write-Log "Failed to switch to '$preferred'. Continuing on '$fallback'" "WARNING"
            }
        } else {
            Write-Log "Preferred network '$preferred' not available. Staying on '$fallback'"
        }
    } else {
        Write-Log "Not connected to either '$preferred' or '$fallback'. Trying to connect..."

        $availableNetworks = (netsh wlan show networks mode=bssid) -join "`n"
        if ($availableNetworks -match $preferred) {
            Write-Log "Connecting to preferred network '$preferred'"
            netsh wlan connect name=$preferred
        } elseif ($availableNetworks -match $fallback) {
            Write-Log "Connecting to fallback network '$fallback'"
            netsh wlan connect name=$fallback
        } else {
            Write-Log "Neither '$preferred' nor '$fallback' WiFi networks are available." "ERROR"
            exit 1
        }

        Start-Sleep -Seconds 10
        $currentSSID = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(':')[1].Trim()
        if ($currentSSID -ne $preferred -and $currentSSID -ne $fallback) {
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
        "sync", "`"$SourcePath`"", "$RcloneRemote",
        "--drive-chunk-size", $chunkSize,
        "--drive-use-trash=false",
        "--delete-before",
        "--progress",
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
