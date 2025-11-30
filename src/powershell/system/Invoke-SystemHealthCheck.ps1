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
    Version: 1.1.0

    This script is designed to be run as a scheduled task on a monthly basis.
    Requires Administrator privileges to run successfully.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LogFolder = "D:\SystemHealth\logs"
)

# Structured logging
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Initialize-Logger -resolvedLogDir $LogFolder -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
try {
    $runStartTime = Get-Date

    Write-LogInfo "========================================"
    Write-LogInfo "Windows System Health Check Started"
    Write-LogInfo "========================================"
    Write-LogInfo "Log file: $($Global:LogConfig.LogFilePath)"
    Write-LogInfo ""

    # Check for Administrator privileges
    if (-not (Test-Administrator)) {
        Write-LogError "This script must be run as Administrator!"
        Write-LogWarning "Please right-click and select 'Run as Administrator'"
        $adminResult = [PSCustomObject]@{
            Status         = 'RequiresAdministrator'
            LogFile        = $Global:LogConfig.LogFilePath
            SystemDrive    = $env:SystemDrive
            FreeSpaceGB    = $null
            SfcExitCode    = $null
            DismExitCode   = $null
            StartedAt      = $runStartTime
            CompletedAt    = Get-Date
        }
        Write-Output $adminResult
        exit 1
    }

    # Check available disk space (need at least 5GB for DISM operations)
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive.TrimEnd(':')
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

    Write-LogInfo "System Drive: $systemDrive"
    Write-LogInfo "Free Space: $freeSpaceGB GB"

    if ($freeSpaceGB -lt 5) {
        Write-LogWarning "Low disk space detected. At least 5GB is recommended for DISM operations."
    }
    Write-LogInfo ""

    # ===========================================
    # Step 1: Run System File Checker (sfc /scannow)
    # ===========================================
    Write-LogInfo "========================================"
    Write-LogInfo "Step 1: Running System File Checker (sfc /scannow)"
    Write-LogInfo "========================================"
    Write-LogInfo "This may take 15-30 minutes depending on your system..."
    Write-LogInfo ""

    $sfcStartTime = Get-Date

    # Run sfc /scannow and capture output
    $sfcOutput = & cmd.exe /c "sfc /scannow 2>&1"
    $sfcExitCode = $LASTEXITCODE

    $sfcEndTime = Get-Date
    $sfcDuration = ($sfcEndTime - $sfcStartTime).TotalMinutes

    # Log SFC output
    Write-LogInfo "SFC Output:"
    $sfcOutput | ForEach-Object { Write-LogInfo $_ }
    Write-LogInfo ""
    Write-LogInfo "SFC Exit Code: $sfcExitCode"
    Write-LogInfo "SFC Duration: $([math]::Round($sfcDuration, 2)) minutes"

    if ($sfcExitCode -eq 0) {
        Write-LogInfo "System File Checker completed successfully"
    }
    else {
        Write-LogWarning "System File Checker completed with exit code: $sfcExitCode"
    }
    Write-LogInfo ""

    # ===========================================
    # Step 2: Run DISM Restore Health
    # ===========================================
    Write-LogInfo "========================================"
    Write-LogInfo "Step 2: Running DISM Restore Health"
    Write-LogInfo "========================================"
    Write-LogInfo "This may take 20-45 minutes depending on your system..."
    Write-LogInfo ""

    $dismStartTime = Get-Date

    # Run DISM and capture output
    $dismOutput = & cmd.exe /c "Dism /Online /Cleanup-Image /RestoreHealth 2>&1"
    $dismExitCode = $LASTEXITCODE

    $dismEndTime = Get-Date
    $dismDuration = ($dismEndTime - $dismStartTime).TotalMinutes

    # Log DISM output
    Write-LogInfo "DISM Output:"
    $dismOutput | ForEach-Object { Write-LogInfo $_ }
    Write-LogInfo ""
    Write-LogInfo "DISM Exit Code: $dismExitCode"
    Write-LogInfo "DISM Duration: $([math]::Round($dismDuration, 2)) minutes"

    if ($dismExitCode -eq 0) {
        Write-LogInfo "DISM Restore Health completed successfully"
    }
    else {
        Write-LogWarning "DISM Restore Health completed with exit code: $dismExitCode"
    }
    Write-LogInfo ""

    # ===========================================
    # Summary
    # ===========================================
    $totalEndTime = Get-Date
    $totalDuration = ($totalEndTime - $sfcStartTime).TotalMinutes

    Write-LogInfo "========================================"
    Write-LogInfo "System Health Check Summary"
    Write-LogInfo "========================================"
    Write-LogInfo "Total Duration: $([math]::Round($totalDuration, 2)) minutes"
    Write-LogInfo "SFC Status: $(if ($sfcExitCode -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH WARNINGS' })"
    Write-LogInfo "DISM Status: $(if ($dismExitCode -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH WARNINGS' })"
    Write-LogInfo "Log File: $($Global:LogConfig.LogFilePath)"
    Write-LogInfo ""
    Write-LogInfo "System health check completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-LogInfo "========================================"

    # Additional system log locations
    Write-LogInfo ""
    Write-LogInfo "Additional Windows logs to review:"
    Write-LogInfo "  - CBS Log: $env:SystemRoot\Logs\CBS\CBS.log"
    Write-LogInfo "  - DISM Log: $env:SystemRoot\Logs\DISM\dism.log"
    Write-LogInfo ""

    $result = [PSCustomObject]@{
        Status          = if ($sfcExitCode -eq 0 -and $dismExitCode -eq 0) { 'Success' } else { 'CompletedWithWarnings' }
        LogFile         = $Global:LogConfig.LogFilePath
        SystemDrive     = $systemDrive
        FreeSpaceGB     = $freeSpaceGB
        SfcExitCode     = $sfcExitCode
        SfcDurationMins = [math]::Round($sfcDuration, 2)
        DismExitCode    = $dismExitCode
        DismDurationMins= [math]::Round($dismDuration, 2)
        StartedAt       = $runStartTime
        CompletedAt     = $totalEndTime
    }

    Write-Output $result

    # Exit with appropriate code for task scheduling compatibility
    if ($sfcExitCode -eq 0 -and $dismExitCode -eq 0) { exit 0 } else { exit 1 }

}
catch {
    Write-LogCritical "CRITICAL ERROR: $($_.Exception.Message)"
    Write-LogCritical "Stack Trace: $($_.ScriptStackTrace)"
    exit 2
}
