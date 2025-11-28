<#
.SYNOPSIS
    Installs scheduled tasks for My-Scripts automation.

.DESCRIPTION
    Generates Task Scheduler XML files from templates and registers them.
    Replaces {{SCRIPT_ROOT}} placeholder with actual script directory.

    This script:
    - Finds all .xml.template files in config/tasks/
    - Replaces placeholders with actual paths
    - Validates generated XML
    - Registers tasks in Windows Task Scheduler

.PARAMETER ScriptRoot
    Root directory where scripts are installed.
    Defaults to the parent directory of this script.

.PARAMETER TaskPrefix
    Prefix for task names in Task Scheduler.
    Default: "MyScripts-"

.PARAMETER Force
    Overwrite existing tasks without prompting.

.PARAMETER WhatIf
    Show what would be installed without actually installing.

.EXAMPLE
    .\Install-ScheduledTasks.ps1
    Installs all scheduled tasks using current directory as root.

.EXAMPLE
    .\Install-ScheduledTasks.ps1 -ScriptRoot "C:\Users\John\Documents\Scripts"
    Installs tasks with specified script root.

.EXAMPLE
    .\Install-ScheduledTasks.ps1 -WhatIf
    Preview task installation without making changes.

.EXAMPLE
    .\Install-ScheduledTasks.ps1 -Force
    Force overwrite existing tasks.

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Created: 2025-11-28
    Requires: Windows, PowerShell 5.1+, Administrator privileges
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateScript({
        if (Test-Path $_) { $true }
        else { throw "Path '$_' does not exist" }
    })]
    [string]$ScriptRoot,

    [Parameter()]
    [string]$TaskPrefix = "MyScripts-",

    [Parameter()]
    [switch]$Force
)

# Determine script root if not provided
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $PSScriptRoot
}

# Resolve to absolute path
$ScriptRoot = (Resolve-Path $ScriptRoot).Path

# Import logging framework
$loggingModulePath = Join-Path $ScriptRoot "src\powershell\modules\Core\Logging\PowerShellLoggingFramework.psm1"
if (Test-Path $loggingModulePath) {
    Import-Module $loggingModulePath -Force
    $logger = Initialize-Logger -ScriptName "Install-ScheduledTasks"
    Write-LogInfo $logger "Starting scheduled task installation"
    Write-LogInfo $logger "Script root: $ScriptRoot"
} else {
    Write-Warning "Logging module not found at $loggingModulePath. Proceeding without logging."
    $logger = $null
}

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "Some tasks may fail to register without Administrator privileges." -ForegroundColor Yellow
    Write-Host "Consider running this script as Administrator." -ForegroundColor Yellow
    Write-Host ""

    if ($logger) {
        Write-LogWarning $logger "Script not running with Administrator privileges"
    }

    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "My-Scripts Scheduled Tasks Installation" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Script root: $ScriptRoot" -ForegroundColor White
Write-Host "Task prefix: $TaskPrefix" -ForegroundColor White
Write-Host ""

# Find all template files
$templatePath = Join-Path $ScriptRoot "config\tasks"
if (-not (Test-Path $templatePath)) {
    $errorMsg = "Template directory not found: $templatePath"
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
    if ($logger) {
        Write-LogError $logger $errorMsg
    }
    exit 1
}

$templates = Get-ChildItem -Path $templatePath -Filter "*.xml.template"

if ($templates.Count -eq 0) {
    $errorMsg = "No template files found in $templatePath"
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
    if ($logger) {
        Write-LogError $logger $errorMsg
    }
    exit 1
}

Write-Host "Found $($templates.Count) task template(s)" -ForegroundColor Cyan
Write-Host ""

$installed = 0
$skipped = 0
$failed = 0

foreach ($template in $templates) {
    # Derive task name from template filename
    $taskName = $TaskPrefix + ($template.BaseName -replace '\.xml$', '')
    $outputFile = Join-Path $templatePath ($template.BaseName)

    Write-Host "Processing: " -NoNewline
    Write-Host $taskName -ForegroundColor Yellow

    try {
        # Read template content
        $content = Get-Content $template.FullName -Raw -Encoding UTF8

        # Replace placeholder with actual script root
        $content = $content -replace '\{\{SCRIPT_ROOT\}\}', $ScriptRoot

        # Validate XML structure
        try {
            [xml]$xmlContent = $content
            Write-Verbose "  XML validation passed"
        }
        catch {
            throw "XML validation failed: $_"
        }

        # Save generated XML
        if ($PSCmdlet.ShouldProcess($outputFile, "Generate XML file")) {
            Set-Content -Path $outputFile -Value $content -Encoding UTF8
            Write-Verbose "  Generated: $outputFile"
        }

        # Check if task already exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($existingTask -and -not $Force) {
            Write-Host "  ⚠ Already exists (use -Force to overwrite)" -ForegroundColor Yellow
            if ($logger) {
                Write-LogWarning $logger "Task '$taskName' already exists. Use -Force to overwrite."
            }
            $skipped++
            continue
        }

        # Register task
        if ($PSCmdlet.ShouldProcess($taskName, "Register scheduled task")) {
            Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $outputFile -Raw) -Force:$Force | Out-Null

            Write-Host "  ✓ Installed successfully" -ForegroundColor Green
            if ($logger) {
                Write-LogInfo $logger "Installed task: $taskName"
            }
            $installed++
        }
    }
    catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        if ($logger) {
            Write-LogError $logger "Failed to install $taskName: $_"
        }
        $failed++
    }

    Write-Host ""
}

# Display summary
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "  Installed: " -NoNewline
Write-Host $installed -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host "  Skipped:   " -NoNewline
    Write-Host $skipped -ForegroundColor Yellow
}
if ($failed -gt 0) {
    Write-Host "  Failed:    " -NoNewline
    Write-Host $failed -ForegroundColor Red
}
Write-Host ""

if ($logger) {
    Write-LogInfo $logger "Installation complete. Installed: $installed, Skipped: $skipped, Failed: $failed"
}

# Provide next steps if successful
if ($installed -gt 0) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Open Task Scheduler to review installed tasks" -ForegroundColor White
    Write-Host "  2. Adjust schedules if needed for your environment" -ForegroundColor White
    Write-Host "  3. Test tasks: " -NoNewline -ForegroundColor White
    Write-Host "Get-ScheduledTask -TaskName '$TaskPrefix*'" -ForegroundColor Gray
    Write-Host "  4. Run a task manually: " -NoNewline -ForegroundColor White
    Write-Host "Start-ScheduledTask -TaskName '<task-name>'" -ForegroundColor Gray
    Write-Host ""
}

# Exit with appropriate code
if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
