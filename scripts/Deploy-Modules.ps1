<#
.SYNOPSIS
    Deploys PowerShell modules to configured module paths.

.DESCRIPTION
    Reads config/modules/deployment.txt and deploys all configured modules
    to their specified target locations (System, User, or alternate paths).
    Validates module manifests before deployment and creates version-specific
    directories for each module.

.PARAMETER Force
    Overwrite existing modules without prompting.

.PARAMETER WhatIf
    Show what would be deployed without actually deploying.

.PARAMETER ConfigPath
    Path to the module deployment configuration file.
    Defaults to ../config/modules/deployment.txt relative to this script.

.EXAMPLE
    .\Deploy-Modules.ps1
    Deploys all modules with prompts for overwrites.

.EXAMPLE
    .\Deploy-Modules.ps1 -Force
    Deploys all modules, overwriting existing versions without prompting.

.EXAMPLE
    .\Deploy-Modules.ps1 -WhatIf
    Shows what would be deployed without making changes.

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Requires: PowerShell 5.1 or later
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force,
    [string]$ConfigPath
)

# Determine repository root and config path
$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Path $scriptRoot -Parent

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "config" "modules" "deployment.txt"
}

# Verify config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

Write-Host "Module Deployment Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository Root: $repoRoot"
Write-Host "Configuration:   $ConfigPath"
Write-Host ""

# Read and parse configuration
$configLines = Get-Content $ConfigPath -Encoding UTF8 | Where-Object {
    $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$'
}

if ($configLines.Count -eq 0) {
    Write-Warning "No active module entries found in configuration file."
    exit 0
}

Write-Host "Found $($configLines.Count) module(s) to deploy" -ForegroundColor Green
Write-Host ""

# Determine module paths based on platform
$systemPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        # Windows PowerShell
        Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
    }
    else {
        # PowerShell Core on Windows
        Join-Path $env:ProgramFiles "PowerShell\Modules"
    }
}
else {
    # PowerShell Core on Linux/Mac
    "/usr/local/share/powershell/Modules"
}

$userPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        # Windows PowerShell
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules"
    }
    else {
        # PowerShell Core on Windows
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules"
    }
}
else {
    # PowerShell Core on Linux/Mac
    Join-Path $HOME ".local/share/powershell/Modules"
}

# Track deployment statistics
$deployedCount = 0
$failedCount = 0
$skippedCount = 0

# Process each module
foreach ($line in $configLines) {
    $fields = $line -split '\|' | ForEach-Object { $_.Trim() }

    if ($fields.Count -lt 3) {
        Write-Warning "Invalid configuration line (expected at least 3 fields): $line"
        $failedCount++
        continue
    }

    $moduleName = $fields[0]
    $sourcePath = $fields[1]
    $targets = $fields[2] -split ',' | ForEach-Object { $_.Trim() }
    $author = if ($fields.Count -ge 4) { $fields[3] } else { $env:USERNAME }
    $description = if ($fields.Count -ge 5) { $fields[4] } else { "PowerShell module" }

    Write-Host "Processing module: $moduleName" -ForegroundColor Yellow
    Write-Host "  Source: $sourcePath"

    # Resolve source path relative to repository root
    $fullSourcePath = Join-Path $repoRoot $sourcePath.Replace('\', '/')

    if (-not (Test-Path $fullSourcePath)) {
        Write-Error "  Source not found: $fullSourcePath"
        $failedCount++
        continue
    }

    # Determine if source is a directory or a single .psm1 file
    $isDirectory = Test-Path $fullSourcePath -PathType Container

    # Find and validate manifest
    if ($isDirectory) {
        $manifestPath = Join-Path $fullSourcePath "$moduleName.psd1"
    }
    else {
        # Source is a .psm1 file, look for .psd1 in same directory
        $sourceDir = Split-Path -Path $fullSourcePath -Parent
        $manifestPath = Join-Path $sourceDir "$moduleName.psd1"
    }

    if (-not (Test-Path $manifestPath)) {
        Write-Error "  Manifest not found: $manifestPath"
        $failedCount++
        continue
    }

    Write-Host "  Manifest: $manifestPath"

    # Test manifest validity
    try {
        $manifestData = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $version = $manifestData.Version.ToString()
        Write-Host "  Version: $version" -ForegroundColor Green
    }
    catch {
        Write-Error "  Manifest validation failed: $_"
        $failedCount++
        continue
    }

    # Deploy to each target
    foreach ($target in $targets) {
        $targetBasePath = switch -Regex ($target) {
            '^System$' { $systemPath }
            '^User$' { $userPath }
            '^Alt:(.+)' { $Matches[1] }
            default {
                Write-Warning "  Unknown target type: $target (use System, User, or Alt:<path>)"
                continue
            }
        }

        # Create versioned module directory
        $targetModulePath = Join-Path $targetBasePath $moduleName
        $targetVersionPath = Join-Path $targetModulePath $version

        Write-Host "  Target: $targetVersionPath"

        # Check if target already exists
        if ((Test-Path $targetVersionPath) -and -not $Force) {
            if ($PSCmdlet.ShouldProcess($targetVersionPath, "Overwrite existing module")) {
                # User will be prompted by ShouldProcess
            }
            else {
                Write-Host "  Skipped (already exists, use -Force to overwrite)" -ForegroundColor Gray
                $skippedCount++
                continue
            }
        }

        # Create target directory if it doesn't exist
        if (-not (Test-Path $targetVersionPath)) {
            try {
                New-Item -Path $targetVersionPath -ItemType Directory -Force | Out-Null
                Write-Host "  Created directory: $targetVersionPath" -ForegroundColor Gray
            }
            catch {
                Write-Error "  Failed to create target directory: $_"
                $failedCount++
                continue
            }
        }

        # Copy module files
        try {
            if ($PSCmdlet.ShouldProcess($targetVersionPath, "Deploy module files")) {
                if ($isDirectory) {
                    # Copy entire directory contents
                    Copy-Item -Path "$fullSourcePath\*" -Destination $targetVersionPath -Recurse -Force
                }
                else {
                    # Copy .psm1 and .psd1 files
                    $sourceDir = Split-Path -Path $fullSourcePath -Parent
                    Copy-Item -Path $fullSourcePath -Destination $targetVersionPath -Force
                    Copy-Item -Path $manifestPath -Destination $targetVersionPath -Force

                    # Copy any additional files (README, etc.)
                    $additionalFiles = Get-ChildItem -Path $sourceDir -File | Where-Object {
                        $_.Extension -notin @('.psm1', '.psd1') -and $_.Name -like "$moduleName*"
                    }
                    foreach ($file in $additionalFiles) {
                        Copy-Item -Path $file.FullName -Destination $targetVersionPath -Force
                    }
                }

                Write-Host "  Deployed successfully" -ForegroundColor Green
                $deployedCount++
            }
        }
        catch {
            Write-Error "  Deployment failed: $_"
            $failedCount++
        }
    }

    Write-Host ""
}

# Summary
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Deployed: $deployedCount" -ForegroundColor Green
if ($skippedCount -gt 0) {
    Write-Host "Skipped:  $skippedCount" -ForegroundColor Gray
}
if ($failedCount -gt 0) {
    Write-Host "Failed:   $failedCount" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All modules deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To verify, run:" -ForegroundColor Cyan
Write-Host "  Get-Module -ListAvailable -Name PostgresBackup,PowerShellLoggingFramework,PurgeLogs,RandomName,Videoscreenshot,ErrorHandling,FileOperations,ProgressReporter"
