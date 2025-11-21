<#
.SYNOPSIS
    Runs Windows system health checks and repairs.

.DESCRIPTION
    This script performs monthly system integrity checks and repairs on Windows systems.
    It runs the following commands sequentially:
    1. System File Checker (sfc /scannow)
    2. DISM Restore Health operation

    All output is logged to timestamped files for review.

    REQUIREMENTS: Must be run with Administrator privileges.

.PARAMETER LogFolder
    The folder where log files will be stored. Defaults to D:\SystemHealth\logs

.EXAMPLE
    .\Invoke-SystemHealthCheck.ps1
    Runs system health checks with default log folder.

.EXAMPLE
    .\Invoke-SystemHealthCheck.ps1 -LogFolder "C:\Logs\SystemHealth"
    Runs system health checks with custom log folder.

.NOTES
    Author: Manoj Bhaskaran
    Created: 2025-11-16
    Version: 1.0.0

    This script is designed to be run as a scheduled task on a monthly basis.
    Requires Administrator privileges to run successfully.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LogFolder = "D:\SystemHealth\logs"
)

# Function to write messages to both console and log file
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with color based on level
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }

    # Write to log file
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
try {
    # Check for Administrator privileges
    if (-not (Test-Administrator)) {
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    # Create log folder if it doesn't exist
    if (-not (Test-Path -Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        Write-Host "Created log folder: $LogFolder" -ForegroundColor Green
    }

    # Set up log file with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = Join-Path -Path $LogFolder -ChildPath "SystemHealthCheck_$timestamp.log"

    Write-Log "========================================" "INFO"
    Write-Log "Windows System Health Check Started" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Log file: $script:LogFile" "INFO"
    Write-Log "" "INFO"

    # Check available disk space (need at least 5GB for DISM operations)
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive.TrimEnd(':')
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

    Write-Log "System Drive: $systemDrive" "INFO"
    Write-Log "Free Space: $freeSpaceGB GB" "INFO"

    if ($freeSpaceGB -lt 5) {
        Write-Log "WARNING: Low disk space detected. At least 5GB is recommended for DISM operations." "WARNING"
    }
    Write-Log "" "INFO"

    # ===========================================
    # Step 1: Run System File Checker (sfc /scannow)
    # ===========================================
    Write-Log "========================================" "INFO"
    Write-Log "Step 1: Running System File Checker (sfc /scannow)" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "This may take 15-30 minutes depending on your system..." "INFO"
    Write-Log "" "INFO"

    $sfcStartTime = Get-Date

    # Run sfc /scannow and capture output
    $sfcOutput = & cmd.exe /c "sfc /scannow 2>&1"
    $sfcExitCode = $LASTEXITCODE

    $sfcEndTime = Get-Date
    $sfcDuration = ($sfcEndTime - $sfcStartTime).TotalMinutes

    # Log SFC output
    Write-Log "SFC Output:" "INFO"
    $sfcOutput | ForEach-Object { Write-Log $_ "INFO" }
    Write-Log "" "INFO"
    Write-Log "SFC Exit Code: $sfcExitCode" "INFO"
    Write-Log "SFC Duration: $([math]::Round($sfcDuration, 2)) minutes" "INFO"

    if ($sfcExitCode -eq 0) {
        Write-Log "System File Checker completed successfully" "SUCCESS"
    }
    else {
        Write-Log "System File Checker completed with exit code: $sfcExitCode" "WARNING"
    }
    Write-Log "" "INFO"

    # ===========================================
    # Step 2: Run DISM Restore Health
    # ===========================================
    Write-Log "========================================" "INFO"
    Write-Log "Step 2: Running DISM Restore Health" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "This may take 20-45 minutes depending on your system..." "INFO"
    Write-Log "" "INFO"

    $dismStartTime = Get-Date

    # Run DISM and capture output
    $dismOutput = & cmd.exe /c "Dism /Online /Cleanup-Image /RestoreHealth 2>&1"
    $dismExitCode = $LASTEXITCODE

    $dismEndTime = Get-Date
    $dismDuration = ($dismEndTime - $dismStartTime).TotalMinutes

    # Log DISM output
    Write-Log "DISM Output:" "INFO"
    $dismOutput | ForEach-Object { Write-Log $_ "INFO" }
    Write-Log "" "INFO"
    Write-Log "DISM Exit Code: $dismExitCode" "INFO"
    Write-Log "DISM Duration: $([math]::Round($dismDuration, 2)) minutes" "INFO"

    if ($dismExitCode -eq 0) {
        Write-Log "DISM Restore Health completed successfully" "SUCCESS"
    }
    else {
        Write-Log "DISM Restore Health completed with exit code: $dismExitCode" "WARNING"
    }
    Write-Log "" "INFO"

    # ===========================================
    # Summary
    # ===========================================
    $totalEndTime = Get-Date
    $totalDuration = ($totalEndTime - $sfcStartTime).TotalMinutes

    Write-Log "========================================" "INFO"
    Write-Log "System Health Check Summary" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Total Duration: $([math]::Round($totalDuration, 2)) minutes" "INFO"
    Write-Log "SFC Status: $(if ($sfcExitCode -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH WARNINGS' })" "INFO"
    Write-Log "DISM Status: $(if ($dismExitCode -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH WARNINGS' })" "INFO"
    Write-Log "Log File: $script:LogFile" "INFO"
    Write-Log "" "INFO"
    Write-Log "System health check completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "SUCCESS"
    Write-Log "========================================" "INFO"

    # Additional system log locations
    Write-Log "" "INFO"
    Write-Log "Additional Windows logs to review:" "INFO"
    Write-Log "  - CBS Log: $env:SystemRoot\Logs\CBS\CBS.log" "INFO"
    Write-Log "  - DISM Log: $env:SystemRoot\Logs\DISM\dism.log" "INFO"
    Write-Log "" "INFO"

    # Exit with appropriate code
    if ($sfcExitCode -eq 0 -and $dismExitCode -eq 0) {
        exit 0
    }
    else {
        exit 1
    }

}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    exit 2
}
