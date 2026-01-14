<#
.SYNOPSIS
    Registers or removes a Windows Scheduled Task for automatic Sync-MacriumBackups execution at startup.

.DESCRIPTION
    This script creates or updates a scheduled task named "Sync-MacriumBackups-Startup" that:
    - Runs at system startup (primary trigger) and user logon (fallback trigger)
    - Executes Sync-MacriumBackups.ps1 with -AutoResume flag for intelligent restart behavior
    - Waits for network availability before starting
    - Automatically retries up to 3 times (every 15 minutes) if the task fails
    - Runs with highest privileges to ensure proper system access
    - Uses PowerShell Core (pwsh) with bypass execution policy

    The task is designed to be resilient and self-healing, leveraging the AutoResume
    feature of Sync-MacriumBackups.ps1 to avoid redundant runs while ensuring
    interrupted or failed syncs are automatically retried.

.PARAMETER Remove
    When specified, removes the scheduled task instead of creating/updating it.

.PARAMETER TaskName
    The name of the scheduled task to create or remove. Default: "Sync-MacriumBackups-Startup"

.PARAMETER ScriptPath
    The full path to Sync-MacriumBackups.ps1. If not specified, defaults to the script
    located in the same directory as this registration script.

.PARAMETER RunAsUser
    The user account under which the task will run. Default: Current user ($env:USERNAME)
    Use "SYSTEM" to run as Local System account (requires admin privileges).

.PARAMETER TaskPath
    The folder path in Task Scheduler where the task will be created. Must start and end with backslash.
    Default: "\My Scheduled Tasks\"
    The folder will be created automatically if it doesn't exist.

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1

    Creates or updates the scheduled task using default settings (current user, script in same directory, in "My Scheduled Tasks" folder).

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1 -RunAsUser "SYSTEM"

    Creates or updates the scheduled task to run as Local System account.

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1 -Remove

    Removes the scheduled task.

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1 -ScriptPath "C:\Scripts\Sync-MacriumBackups.ps1"

    Creates or updates the scheduled task using a custom script path.

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1 -TaskPath "\Backup Tasks\"

    Creates or updates the scheduled task in a custom folder "Backup Tasks" in Task Scheduler.

.EXAMPLE
    .\Register-SyncMacriumBackupsTask.ps1 -TaskPath "\"

    Creates or updates the scheduled task in the root Task Scheduler Library folder.

.NOTES
    Version: 1.1.0
    Requires: PowerShell 5.1+ and Administrator privileges

    CHANGELOG
    ## 1.1.0 - 2026-01-14
    ### Added
    - TaskPath parameter to specify Task Scheduler folder location (default: "\My Scheduled Tasks\")
    - Automatic folder creation if the specified TaskPath doesn't exist
    - Folder path display in output messages

    ### Fixed
    - SYSTEM account logon type handling (now uses ServiceAccount logon type)
    - Omit logon trigger for service accounts (SYSTEM, LOCAL SERVICE, NETWORK SERVICE)

    ## 1.0.0 - 2026-01-14
    ### Added
    - Initial implementation with task creation and removal functionality
    - Dual triggers: At startup (primary) and At logon (fallback)
    - Network availability condition before task execution
    - Automatic retry mechanism (15 minutes interval, up to 3 attempts)
    - AutoResume flag integration for intelligent sync restart behavior
    - Configurable task name, script path, and user account
    - Detailed output showing task configuration and registration status
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Remove,

    [Parameter(Mandatory = $false)]
    [string]$TaskName = "Sync-MacriumBackups-Startup",

    [Parameter(Mandatory = $false)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string]$RunAsUser = $env:USERNAME,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\\.*\\$|^\\$')]
    [string]$TaskPath = "\My Scheduled Tasks\"
)

#Requires -RunAsAdministrator

# Determine script path if not provided
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    $ScriptPath = Join-Path $PSScriptRoot "Sync-MacriumBackups.ps1"
}

# Validate script path exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Sync-MacriumBackups.ps1 not found at: $ScriptPath"
    Write-Error "Please specify the correct path using -ScriptPath parameter."
    exit 1
}

# Get absolute path
$ScriptPath = (Resolve-Path $ScriptPath).Path

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Sync-MacriumBackups Task Registration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Handle removal
if ($Remove) {
    Write-Host "[INFO] Attempting to remove task: $TaskPath$TaskName" -ForegroundColor Yellow

    try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue

        if ($null -ne $existingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction Stop
            Write-Host "[SUCCESS] Scheduled task '$TaskPath$TaskName' has been removed." -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] Task '$TaskPath$TaskName' does not exist. Nothing to remove." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to remove scheduled task: $_"
        exit 1
    }

    exit 0
}

# Task registration logic
Write-Host "[INFO] Task Name: $TaskName" -ForegroundColor Cyan
Write-Host "[INFO] Task Path: $TaskPath" -ForegroundColor Cyan
Write-Host "[INFO] Full Task Path: $TaskPath$TaskName" -ForegroundColor Cyan
Write-Host "[INFO] Script Path: $ScriptPath" -ForegroundColor Cyan
Write-Host "[INFO] Run As User: $RunAsUser`n" -ForegroundColor Cyan

try {
    # Ensure the task folder exists (create if it doesn't)
    if ($TaskPath -ne "\") {
        $folderName = $TaskPath.Trim('\')
        try {
            $folder = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $folder) {
                Write-Host "[INFO] Creating Task Scheduler folder: $TaskPath" -ForegroundColor Yellow
                $scheduleService = New-Object -ComObject Schedule.Service
                $scheduleService.Connect()
                $rootFolder = $scheduleService.GetFolder("\")
                $rootFolder.CreateFolder($folderName) | Out-Null
                Write-Host "[SUCCESS] Folder created successfully." -ForegroundColor Green
            }
            else {
                Write-Host "[INFO] Task Scheduler folder already exists: $TaskPath" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "[WARNING] Could not verify/create folder (may already exist): $_" -ForegroundColor Yellow
        }
    }

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    $isUpdate = $null -ne $existingTask

    if ($isUpdate) {
        Write-Host "[INFO] Existing task found. Will update configuration." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] Creating new scheduled task." -ForegroundColor Yellow
    }

    # Define the action
    $actionArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$ScriptPath`"",
        "-AutoResume"
    )
    $actionArgString = $actionArgs -join " "

    $action = New-ScheduledTaskAction `
        -Execute "pwsh.exe" `
        -Argument $actionArgString

    Write-Host "`n[ACTION] Command to execute:" -ForegroundColor Cyan
    Write-Host "  pwsh.exe $actionArgString" -ForegroundColor Gray

    # Determine if RunAsUser is a service account
    $serviceAccounts = @("SYSTEM", "LOCAL SERVICE", "NETWORK SERVICE", "NT AUTHORITY\SYSTEM", "NT AUTHORITY\LOCAL SERVICE", "NT AUTHORITY\NETWORK SERVICE")
    $isServiceAccount = $serviceAccounts -contains $RunAsUser

    # Define triggers
    # Trigger 1: At startup (primary - always included)
    $triggerStartup = New-ScheduledTaskTrigger -AtStartup

    # Trigger 2: At logon (fallback - only for regular user accounts)
    # Service accounts like SYSTEM don't have logon events, so we skip this trigger for them
    $triggers = @($triggerStartup)

    Write-Host "`n[TRIGGERS]" -ForegroundColor Cyan
    Write-Host "  1. At system startup" -ForegroundColor Gray

    if (-not $isServiceAccount) {
        $triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $RunAsUser
        $triggers += $triggerLogon
        Write-Host "  2. At user logon ($RunAsUser)" -ForegroundColor Gray
    }
    else {
        Write-Host "  (Logon trigger omitted - service accounts don't have logon events)" -ForegroundColor Gray
    }

    # Define settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -RestartInterval (New-TimeSpan -Minutes 15) `
        -RestartCount 3 `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4)

    Write-Host "`n[SETTINGS]" -ForegroundColor Cyan
    Write-Host "  - Network Required: Yes (waits for network before starting)" -ForegroundColor Gray
    Write-Host "  - Allow on Battery: Yes" -ForegroundColor Gray
    Write-Host "  - Retry on Failure: Yes (every 15 minutes, up to 3 times)" -ForegroundColor Gray
    Write-Host "  - Execution Time Limit: 4 hours" -ForegroundColor Gray
    Write-Host "  - Start When Available: Yes (runs if missed during offline)" -ForegroundColor Gray

    # Define principal (user and privilege level)
    # Service accounts require -LogonType ServiceAccount, regular users use Interactive
    if ($isServiceAccount) {
        $principal = New-ScheduledTaskPrincipal `
            -UserId $RunAsUser `
            -LogonType ServiceAccount `
            -RunLevel Highest
        $logonTypeDisplay = "ServiceAccount"
    }
    else {
        $principal = New-ScheduledTaskPrincipal `
            -UserId $RunAsUser `
            -LogonType Interactive `
            -RunLevel Highest
        $logonTypeDisplay = "Interactive"
    }

    Write-Host "`n[PRINCIPAL]" -ForegroundColor Cyan
    Write-Host "  - User: $RunAsUser" -ForegroundColor Gray
    Write-Host "  - Run Level: Highest (Administrator privileges)" -ForegroundColor Gray
    Write-Host "  - Logon Type: $logonTypeDisplay" -ForegroundColor Gray

    # Register or update the task
    Write-Host "`n[REGISTRATION]" -ForegroundColor Cyan

    $registerParams = @{
        TaskName    = $TaskName
        TaskPath    = $TaskPath
        Action      = $action
        Trigger     = $triggers
        Settings    = $settings
        Principal   = $principal
        Description = "Automatically runs Sync-MacriumBackups.ps1 at startup with AutoResume flag to sync Macrium Reflect backups to Google Drive. Includes network availability check and automatic retry on failure."
        Force       = $true
    }

    $task = Register-ScheduledTask @registerParams -ErrorAction Stop

    if ($isUpdate) {
        Write-Host "[SUCCESS] Scheduled task '$TaskPath$TaskName' has been updated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "[SUCCESS] Scheduled task '$TaskPath$TaskName' has been created successfully." -ForegroundColor Green
    }

    # Display task summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Task Registration Summary" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Task Name      : $TaskName" -ForegroundColor White
    Write-Host "Task Path      : $TaskPath" -ForegroundColor White
    Write-Host "Full Path      : $TaskPath$TaskName" -ForegroundColor White
    Write-Host "Status         : $($task.State)" -ForegroundColor White
    Write-Host "Next Run Time  : $((Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $TaskPath).NextRunTime)" -ForegroundColor White
    Write-Host "Script         : $ScriptPath" -ForegroundColor White
    Write-Host "Run As         : $RunAsUser" -ForegroundColor White

    Write-Host "`n[NEXT STEPS]" -ForegroundColor Cyan
    if ($isServiceAccount) {
        Write-Host "  - The task will run automatically at next system startup" -ForegroundColor Gray
    }
    else {
        Write-Host "  - The task will run automatically at next startup/logon" -ForegroundColor Gray
    }
    Write-Host "  - You can manually test it by running: Start-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath'" -ForegroundColor Gray

    $taskLocationDisplay = if ($TaskPath -eq "\") { "Task Scheduler Library (root)" } else { "Task Scheduler Library$TaskPath" }
    Write-Host "  - View task details in Task Scheduler (taskschd.msc) under $taskLocationDisplay" -ForegroundColor Gray

    if ($TaskPath -eq "\My Scheduled Tasks\") {
        Write-Host "  - To remove this task, run: .\Register-SyncMacriumBackupsTask.ps1 -Remove" -ForegroundColor Gray
    }
    else {
        Write-Host "  - To remove this task, run: .\Register-SyncMacriumBackupsTask.ps1 -Remove -TaskPath '$TaskPath'" -ForegroundColor Gray
    }
    Write-Host "" -ForegroundColor Gray

    Write-Host "[SUCCESS] Task registration completed successfully.`n" -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Failed to register scheduled task:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host "`nPlease ensure you are running this script as Administrator.`n" -ForegroundColor Yellow
    exit 1
}
