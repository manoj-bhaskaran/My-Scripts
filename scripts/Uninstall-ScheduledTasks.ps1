<#
.SYNOPSIS
    Uninstalls My-Scripts scheduled tasks from Windows Task Scheduler.

.DESCRIPTION
    Removes all scheduled tasks that were installed by Install-ScheduledTasks.ps1.
    Tasks are identified by their name prefix (default: "MyScripts-").

    This script:
    - Finds all tasks matching the specified prefix
    - Prompts for confirmation (unless -Force is used)
    - Unregisters the tasks from Task Scheduler
    - Provides a summary of removed tasks

.PARAMETER TaskPrefix
    Prefix used for task names in Task Scheduler.
    Default: "MyScripts-"

.PARAMETER Force
    Skip confirmation prompts and remove tasks immediately.

.PARAMETER WhatIf
    Show what would be uninstalled without actually uninstalling.

.EXAMPLE
    .\Uninstall-ScheduledTasks.ps1
    Removes all My-Scripts scheduled tasks with confirmation.

.EXAMPLE
    .\Uninstall-ScheduledTasks.ps1 -Force
    Removes all tasks without confirmation.

.EXAMPLE
    .\Uninstall-ScheduledTasks.ps1 -WhatIf
    Preview tasks that would be removed.

.EXAMPLE
    .\Uninstall-ScheduledTasks.ps1 -TaskPrefix "Custom-"
    Remove tasks with a custom prefix.

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Created: 2025-11-28
    Requires: Windows, PowerShell 5.1+, Administrator privileges
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [string]$TaskPrefix = "MyScripts-",

    [Parameter()]
    [switch]$Force
)

# Determine script root for logging
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Import logging framework if available
$loggingModulePath = Join-Path $ScriptRoot "src\powershell\modules\Core\Logging\PowerShellLoggingFramework.psm1"
if (Test-Path $loggingModulePath) {
    Import-Module $loggingModulePath -Force
    $logger = Initialize-Logger -ScriptName "Uninstall-ScheduledTasks"
    Write-LogInfo $logger "Starting scheduled task uninstallation"
} else {
    Write-Verbose "Logging module not found. Proceeding without logging."
    $logger = $null
}

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "Task uninstallation may fail without Administrator privileges." -ForegroundColor Yellow
    Write-Host ""

    if ($logger) {
        Write-LogWarning $logger "Script not running with Administrator privileges"
    }
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "My-Scripts Scheduled Tasks Uninstallation" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Task prefix: $TaskPrefix" -ForegroundColor White
Write-Host ""

# Find all matching tasks
try {
    $tasks = Get-ScheduledTask -TaskName "$TaskPrefix*" -ErrorAction SilentlyContinue
}
catch {
    Write-Host "ERROR: Failed to query scheduled tasks: $_" -ForegroundColor Red
    if ($logger) {
        Write-LogError $logger "Failed to query scheduled tasks: $_"
    }
    exit 1
}

if ($null -eq $tasks -or $tasks.Count -eq 0) {
    Write-Host "No tasks found with prefix '$TaskPrefix'" -ForegroundColor Yellow
    Write-Host ""
    if ($logger) {
        Write-LogInfo $logger "No tasks found with prefix '$TaskPrefix'"
    }
    exit 0
}

# Convert to array if single task
if ($tasks -isnot [System.Array]) {
    $tasks = @($tasks)
}

Write-Host "Found $($tasks.Count) task(s) to uninstall:" -ForegroundColor Cyan
Write-Host ""
foreach ($task in $tasks) {
    $status = if ($task.State -eq 'Ready') { 'Ready' } elseif ($task.State -eq 'Running') { 'Running' } else { $task.State }
    Write-Host "  • " -NoNewline -ForegroundColor White
    Write-Host $task.TaskName -NoNewline -ForegroundColor Yellow
    Write-Host " [$status]" -ForegroundColor Gray
}
Write-Host ""

# Confirm removal unless -Force is specified
if (-not $Force -and -not $WhatIfPreference) {
    Write-Host "This will permanently remove these scheduled tasks." -ForegroundColor Yellow
    $confirmation = Read-Host "Continue? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host ""
        Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# Remove tasks
$removed = 0
$failed = 0

foreach ($task in $tasks) {
    if ($PSCmdlet.ShouldProcess($task.TaskName, "Unregister scheduled task")) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
            Write-Host "✓ Removed: " -NoNewline -ForegroundColor Green
            Write-Host $task.TaskName -ForegroundColor White
            if ($logger) {
                Write-LogInfo $logger "Removed task: $($task.TaskName)"
            }
            $removed++
        }
        catch {
            Write-Host "✗ Failed to remove: " -NoNewline -ForegroundColor Red
            Write-Host $task.TaskName -NoNewline -ForegroundColor White
            Write-Host " - $_" -ForegroundColor Red
            if ($logger) {
                Write-LogError $logger "Failed to remove $($task.TaskName): $_"
            }
            $failed++
        }
    }
}

# Display summary
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Uninstallation Summary" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "  Removed: " -NoNewline
Write-Host $removed -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed:  " -NoNewline
    Write-Host $failed -ForegroundColor Red
}
Write-Host ""

if ($logger) {
    Write-LogInfo $logger "Uninstallation complete. Removed: $removed, Failed: $failed"
}

# Verify all tasks are gone
$remainingTasks = Get-ScheduledTask -TaskName "$TaskPrefix*" -ErrorAction SilentlyContinue
if ($remainingTasks) {
    Write-Host "WARNING: Some tasks may still remain in Task Scheduler." -ForegroundColor Yellow
    Write-Host "Check Task Scheduler manually if needed." -ForegroundColor Yellow
    Write-Host ""
}

# Exit with appropriate code
if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
