<#
.SYNOPSIS
    Installs the Monthly System Health Check scheduled task.

.DESCRIPTION
    This script sets up a Windows scheduled task that runs monthly system health checks.
    The task will execute on the 1st day of each month at 2:00 AM.

    The task runs:
    - System File Checker (sfc /scannow)
    - DISM Restore Health

    REQUIREMENTS: Must be run with Administrator privileges.

.PARAMETER ScriptPath
    The full path to the Invoke-SystemHealthCheck.ps1 script.
    If not provided, the script will attempt to auto-detect it.

.PARAMETER LogFolder
    The folder where log files will be stored. Defaults to D:\SystemHealth\logs

.PARAMETER TaskName
    The name of the scheduled task. Defaults to "Monthly System Health Check"

.PARAMETER RunDay
    The day of the month to run the task (1-31). Defaults to 1 (first day of month)

.PARAMETER RunTime
    The time to run the task in 24-hour format (HH:mm). Defaults to "02:00"

.EXAMPLE
    .\Install-SystemHealthCheckTask.ps1
    Installs the task with default settings.

.EXAMPLE
    .\Install-SystemHealthCheckTask.ps1 -LogFolder "C:\Logs\SystemHealth" -RunDay 15 -RunTime "03:00"
    Installs the task to run on the 15th of each month at 3:00 AM with custom log folder.

.NOTES
    Author: Manoj Bhaskaran
    Created: 2025-11-16
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string]$LogFolder = "D:\SystemHealth\logs",

    [Parameter(Mandatory = $false)]
    [string]$TaskName = "Monthly System Health Check",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 31)]
    [int]$RunDay = 1,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$RunTime = "02:00"
)

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Monthly System Health Check - Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Check for Administrator privileges
    if (-not (Test-Administrator)) {
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    # Auto-detect script path if not provided
    if (-not $ScriptPath) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $ScriptPath = Join-Path -Path $scriptDir -ChildPath "Invoke-SystemHealthCheck.ps1"
        Write-Host "Auto-detected script path: $ScriptPath" -ForegroundColor Yellow
    }

    # Verify the script exists
    if (-not (Test-Path -Path $ScriptPath)) {
        Write-Host "ERROR: Script not found at: $ScriptPath" -ForegroundColor Red
        Write-Host "Please provide the correct path using -ScriptPath parameter." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    Write-Host "Script Location: $ScriptPath" -ForegroundColor Green
    Write-Host "Log Folder: $LogFolder" -ForegroundColor Green
    Write-Host "Task Name: $TaskName" -ForegroundColor Green
    Write-Host "Schedule: Day $RunDay of each month at $RunTime" -ForegroundColor Green
    Write-Host ""

    # Create log folder if it doesn't exist
    if (-not (Test-Path -Path $LogFolder)) {
        Write-Host "Creating log folder: $LogFolder" -ForegroundColor Yellow
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        Write-Host "Log folder created successfully." -ForegroundColor Green
    } else {
        Write-Host "Log folder already exists: $LogFolder" -ForegroundColor Green
    }
    Write-Host ""

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "WARNING: A task named '$TaskName' already exists." -ForegroundColor Yellow
        $response = Read-Host "Do you want to replace it? (Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Existing task removed." -ForegroundColor Green
        Write-Host ""
    }

    # Create the scheduled task action
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -LogFolder `"$LogFolder`""

    # Create the scheduled task trigger (monthly on specified day)
    $trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth $RunDay -At $RunTime

    # Create the scheduled task principal (run with highest privileges)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Password -RunLevel Highest

    # Create the scheduled task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -WakeToRun `
        -ExecutionTimeLimit (New-TimeSpan -Hours 3) `
        -Priority 4

    # Register the scheduled task
    Write-Host "Creating scheduled task: $TaskName" -ForegroundColor Yellow

    $task = Register-ScheduledTask -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Runs monthly Windows system health checks (SFC and DISM) to verify and repair system integrity. Logs are saved to $LogFolder for review."

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installation Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $TaskName" -ForegroundColor White
    Write-Host "  Schedule: Day $RunDay of each month at $RunTime" -ForegroundColor White
    Write-Host "  Next Run: $($task.Triggers[0].StartBoundary)" -ForegroundColor White
    Write-Host "  Script: $ScriptPath" -ForegroundColor White
    Write-Host "  Logs: $LogFolder" -ForegroundColor White
    Write-Host ""
    Write-Host "What happens each month:" -ForegroundColor Cyan
    Write-Host "  1. System File Checker (sfc /scannow) runs" -ForegroundColor White
    Write-Host "  2. DISM Restore Health runs" -ForegroundColor White
    Write-Host "  3. Results are logged to timestamped files" -ForegroundColor White
    Write-Host ""
    Write-Host "To view the task:" -ForegroundColor Cyan
    Write-Host "  Open Task Scheduler (taskschd.msc)" -ForegroundColor White
    Write-Host "  Navigate to: Task Scheduler Library" -ForegroundColor White
    Write-Host "  Find: '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "To run the task manually (for testing):" -ForegroundColor Cyan
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To remove the task:" -ForegroundColor Cyan
    Write-Host "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "NOTE: You may be prompted for your password when the task runs" -ForegroundColor Yellow
    Write-Host "      to confirm Administrator privileges." -ForegroundColor Yellow
    Write-Host ""

    exit 0

} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host ""
    exit 2
}
