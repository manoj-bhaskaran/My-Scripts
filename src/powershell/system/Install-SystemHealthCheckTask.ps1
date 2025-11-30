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
    Version: 1.1.0
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
    Write-LogInfo "Monthly System Health Check - Setup"
    Write-LogInfo "========================================"
    Write-LogInfo "Using log file: $($Global:LogConfig.LogFilePath)"

    # Check for Administrator privileges
    if (-not (Test-Administrator)) {
        Write-LogError "This script must be run as Administrator!"
        Write-LogWarning "Please right-click PowerShell and select 'Run as Administrator', then run this script again."
        $adminResult = [PSCustomObject]@{
            Status      = 'RequiresAdministrator'
            TaskName    = $TaskName
            ScriptPath  = $ScriptPath
            LogFolder   = $LogFolder
            RunDay      = $RunDay
            RunTime     = $RunTime
            LogFile     = $Global:LogConfig.LogFilePath
            StartedAt   = $runStartTime
            CompletedAt = Get-Date
        }
        Write-Output $adminResult
        exit 1
    }

    # Auto-detect script path if not provided
    if (-not $ScriptPath) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $ScriptPath = Join-Path -Path $scriptDir -ChildPath "Invoke-SystemHealthCheck.ps1"
        Write-LogInfo "Auto-detected script path: $ScriptPath"
    }

    # Verify the script exists
    if (-not (Test-Path -Path $ScriptPath)) {
        Write-LogError "Script not found at: $ScriptPath"
        Write-LogWarning "Please provide the correct path using -ScriptPath parameter."
        $missingResult = [PSCustomObject]@{
            Status      = 'ScriptNotFound'
            TaskName    = $TaskName
            ScriptPath  = $ScriptPath
            LogFolder   = $LogFolder
            RunDay      = $RunDay
            RunTime     = $RunTime
            LogFile     = $Global:LogConfig.LogFilePath
            StartedAt   = $runStartTime
            CompletedAt = Get-Date
        }
        Write-Output $missingResult
        exit 1
    }

    Write-LogInfo "Script Location: $ScriptPath"
    Write-LogInfo "Log Folder: $LogFolder"
    Write-LogInfo "Task Name: $TaskName"
    Write-LogInfo "Schedule: Day $RunDay of each month at $RunTime"

    # Create log folder if it doesn't exist
    if (-not (Test-Path -Path $LogFolder)) {
        Write-LogInfo "Creating log folder: $LogFolder"
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
        Write-LogInfo "Log folder created successfully."
    }
    else {
        Write-LogInfo "Log folder already exists: $LogFolder"
    }

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-LogWarning "A task named '$TaskName' already exists."
        $response = Read-Host "Do you want to replace it? (Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-LogInfo "Installation cancelled by user."
            $cancelResult = [PSCustomObject]@{
                Status      = 'Cancelled'
                TaskName    = $TaskName
                ScriptPath  = $ScriptPath
                LogFolder   = $LogFolder
                RunDay      = $RunDay
                RunTime     = $RunTime
                LogFile     = $Global:LogConfig.LogFilePath
                StartedAt   = $runStartTime
                CompletedAt = Get-Date
            }
            Write-Output $cancelResult
            exit 0
        }
        Write-LogWarning "Removing existing task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-LogInfo "Existing task removed."
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
    Write-LogInfo "Creating scheduled task: $TaskName"

    $task = Register-ScheduledTask -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Runs monthly Windows system health checks (SFC and DISM) to verify and repair system integrity. Logs are saved to $LogFolder for review."

    $result = [PSCustomObject]@{
        Status      = 'Installed'
        TaskName    = $TaskName
        ScriptPath  = $ScriptPath
        LogFolder   = $LogFolder
        RunDay      = $RunDay
        RunTime     = $RunTime
        NextRun     = $task.Triggers[0].StartBoundary
        LogFile     = $Global:LogConfig.LogFilePath
        StartedAt   = $runStartTime
        CompletedAt = Get-Date
    }

    Write-LogInfo "========================================"
    Write-LogInfo "Installation Completed Successfully!"
    Write-LogInfo "========================================"
    Write-LogInfo "Task Details:"
    Write-LogInfo "  Name: $TaskName"
    Write-LogInfo "  Schedule: Day $RunDay of each month at $RunTime"
    Write-LogInfo "  Next Run: $($task.Triggers[0].StartBoundary)"
    Write-LogInfo "  Script: $ScriptPath"
    Write-LogInfo "  Logs: $LogFolder"
    Write-LogInfo "What happens each month:"
    Write-LogInfo "  1. System File Checker (sfc /scannow) runs"
    Write-LogInfo "  2. DISM Restore Health runs"
    Write-LogInfo "  3. Results are logged to timestamped files"
    Write-LogInfo "To view the task:"
    Write-LogInfo "  Open Task Scheduler (taskschd.msc)"
    Write-LogInfo "  Navigate to: Task Scheduler Library"
    Write-LogInfo "  Find: '$TaskName'"
    Write-LogInfo "To run the task manually (for testing):"
    Write-LogInfo "  Start-ScheduledTask -TaskName '$TaskName'"
    Write-LogInfo "To remove the task:"
    Write-LogInfo "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
    Write-LogInfo "NOTE: You may be prompted for your password when the task runs to confirm Administrator privileges."

    Write-Output $result

    exit 0

}
catch {
    Write-LogCritical "ERROR: $($_.Exception.Message)"
    Write-LogCritical "Stack Trace: $($_.ScriptStackTrace)"

    $errorResult = [PSCustomObject]@{
        Status       = 'Failed'
        TaskName     = $TaskName
        ScriptPath   = $ScriptPath
        LogFolder    = $LogFolder
        RunDay       = $RunDay
        RunTime      = $RunTime
        LogFile      = $Global:LogConfig.LogFilePath
        ErrorMessage = $_.Exception.Message
        StartedAt    = $runStartTime
        CompletedAt  = Get-Date
    }
    Write-Output $errorResult
    exit 2
}
