<#
.SYNOPSIS
    Migrates from legacy module deployment configuration to TOML format.

.DESCRIPTION
    Reads the legacy deployment.txt and local-deployment-config.json files
    and generates the new psmodule.toml and psmodule.local.toml files.

    This script is idempotent and can be run multiple times safely.

.PARAMETER Force
    Overwrite existing psmodule.toml file without prompting.

.PARAMETER OutputPath
    Directory where psmodule.toml will be written.
    Defaults to repository root.

.PARAMETER WhatIf
    Show what would be generated without actually creating files.

.EXAMPLE
    .\Migrate-ModuleConfig.ps1
    # Migrates configuration with prompts for overwrites

.EXAMPLE
    .\Migrate-ModuleConfig.ps1 -Force
    # Migrates configuration, overwriting existing files

.EXAMPLE
    .\Migrate-ModuleConfig.ps1 -WhatIf
    # Shows what would be generated without making changes

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Requires: PowerShell 5.1 or later

    Source files:
    - config/modules/deployment.txt
    - config/local-deployment-config.json (optional)

    Generated files:
    - psmodule.toml
    - psmodule.local.toml (only if local config exists)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force,
    [string]$OutputPath
)

# Determine repository root
$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Path $scriptRoot -Parent

if (-not $OutputPath) {
    $OutputPath = $repoRoot
}

Write-Host "Module Configuration Migration" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository Root: $repoRoot"
Write-Host "Output Path:     $OutputPath"
Write-Host ""

# Define source and target paths
$deploymentTxtPath = Join-Path $repoRoot "config" "modules" "deployment.txt"
$localConfigJsonPath = Join-Path $repoRoot "config" "local-deployment-config.json"
$psmoduleTomlPath = Join-Path $OutputPath "psmodule.toml"
$psmoduleLocalTomlPath = Join-Path $OutputPath "psmodule.local.toml"

# Check if source files exist
if (-not (Test-Path $deploymentTxtPath)) {
    Write-Error "Source configuration not found: $deploymentTxtPath"
    exit 1
}

Write-Host "Source files:" -ForegroundColor Yellow
Write-Host "  deployment.txt:              $(if (Test-Path $deploymentTxtPath) { 'Found' } else { 'Not found' })"
Write-Host "  local-deployment-config.json: $(if (Test-Path $localConfigJsonPath) { 'Found' } else { 'Not found' })"
Write-Host ""

# Parse deployment.txt
Write-Host "Parsing deployment.txt..." -ForegroundColor Yellow

$modules = @()
$configLines = Get-Content $deploymentTxtPath -Encoding UTF8 | Where-Object {
    $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$'
}

foreach ($line in $configLines) {
    $fields = $line -split '\|' | ForEach-Object { $_.Trim() }

    if ($fields.Count -lt 3) {
        Write-Warning "Skipping invalid line (expected at least 3 fields): $line"
        continue
    }

    $module = [PSCustomObject]@{
        Name = $fields[0]
        Source = $fields[1] -replace '\\', '/'
        Targets = $fields[2] -split ',' | ForEach-Object { $_.Trim() }
        Author = if ($fields.Count -ge 4) { $fields[3] } else { $env:USERNAME }
        Description = if ($fields.Count -ge 5) { $fields[4] } else { "PowerShell module" }
    }

    $modules += $module
}

Write-Host "  Found $($modules.Count) modules" -ForegroundColor Green
Write-Host ""

# Parse local-deployment-config.json if exists
$localConfig = $null
if (Test-Path $localConfigJsonPath) {
    Write-Host "Parsing local-deployment-config.json..." -ForegroundColor Yellow
    try {
        $localConfig = Get-Content $localConfigJsonPath -Raw | ConvertFrom-Json
        Write-Host "  Staging mirror: $($localConfig.stagingMirror)" -ForegroundColor Green
        Write-Host "  Enabled: $($localConfig.enabled)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to parse local-deployment-config.json: $_"
    }
    Write-Host ""
}

# Generate psmodule.toml
Write-Host "Generating psmodule.toml..." -ForegroundColor Yellow

$tomlContent = @"
# psmodule.toml - Single source of truth for PowerShell module deployment
#
# This configuration file replaces the legacy deployment.txt and
# local-deployment-config.json files with a modern TOML-based approach.
#
# Version: 1.0.0
# Created: $(Get-Date -Format "yyyy-MM-dd")
# Migrated from: deployment.txt

[deployment]
# Auto-detect PowerShell module path or use custom
# "auto" uses the first path in `$env:PSModulePath
# Can be overridden with an absolute path
default-path = "auto"

# Testing and validation options
test-on-deploy = true           # Run Pester tests after deployment if available
validate-manifest = true        # Validate module manifests before deployment
import-after-deploy = false     # Import modules after deployment to verify

# Module discovery settings
auto-discover = true            # Auto-discover modules in source-paths
source-paths = ["src/powershell/modules"]

# Deployment target (System, User, or custom path)
# System: C:\Program Files\PowerShell\Modules (Windows) or /usr/local/share/powershell/Modules (Linux/Mac)
# User: %USERPROFILE%\Documents\PowerShell\Modules (Windows) or ~/.local/share/powershell/Modules (Linux/Mac)
default-target = "System"

# ============================================================================
# MODULE DEFINITIONS
# ============================================================================
# Each [[modules]] entry defines a PowerShell module to be deployed.
# All modules are deployed in dependency order.

"@

# Add module definitions
foreach ($module in $modules) {
    # Convert source path from .psm1 file to directory if needed
    $sourcePath = $module.Source
    if ($sourcePath -match '\.psm1$') {
        # Extract directory path
        $sourcePath = Split-Path -Path $sourcePath -Parent
    }

    # Determine dependencies based on module analysis
    $dependencies = @()
    if ($module.Name -in @('PostgresBackup', 'PurgeLogs', 'ProgressReporter')) {
        $dependencies = @('PowerShellLoggingFramework')
    }

    $dependencyList = if ($dependencies.Count -gt 0) {
        '["' + ($dependencies -join '", "') + '"]'
    } else {
        '[]'
    }

    $tomlContent += @"

[[modules]]
name = "$($module.Name)"
source = "$sourcePath"
auto-deploy = true
test-on-deploy = true
description = "$($module.Description)"
author = "$($module.Author)"
dependencies = $dependencyList
"@
}

# Write psmodule.toml
if ($PSCmdlet.ShouldProcess($psmoduleTomlPath, "Create psmodule.toml")) {
    if ((Test-Path $psmoduleTomlPath) -and -not $Force) {
        $response = Read-Host "psmodule.toml already exists. Overwrite? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Skipped psmodule.toml" -ForegroundColor Gray
        }
        else {
            $tomlContent | Out-File $psmoduleTomlPath -Encoding UTF8
            Write-Host "✓ Created $psmoduleTomlPath" -ForegroundColor Green
        }
    }
    else {
        $tomlContent | Out-File $psmoduleTomlPath -Encoding UTF8
        Write-Host "✓ Created $psmoduleTomlPath" -ForegroundColor Green
    }
}

# Generate psmodule.local.toml if local config exists
if ($localConfig -and $localConfig.stagingMirror) {
    Write-Host ""
    Write-Host "Generating psmodule.local.toml from local config..." -ForegroundColor Yellow

    $localTomlContent = @"
# psmodule.local.toml - User-specific overrides (NOT committed to git)
#
# Created: $(Get-Date -Format "yyyy-MM-dd")
# Migrated from: local-deployment-config.json

[deployment]
# Override the default deployment path (from legacy stagingMirror)
default-path = "$($localConfig.stagingMirror -replace '\\', '/')"

# Override deployment target
# default-target = "User"

# Override testing settings
# test-on-deploy = false
# validate-manifest = false
# import-after-deploy = true
"@

    if ($PSCmdlet.ShouldProcess($psmoduleLocalTomlPath, "Create psmodule.local.toml")) {
        $localTomlContent | Out-File $psmoduleLocalTomlPath -Encoding UTF8
        Write-Host "✓ Created $psmoduleLocalTomlPath" -ForegroundColor Green
        Write-Host "⚠ WARNING: psmodule.local.toml contains user-specific settings" -ForegroundColor Yellow
        Write-Host "  Make sure it's added to .gitignore!" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "Migration Summary" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Migrated $($modules.Count) modules from deployment.txt" -ForegroundColor Green
Write-Host "✓ Generated psmodule.toml" -ForegroundColor Green

if ($localConfig) {
    Write-Host "✓ Generated psmodule.local.toml from local config" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review psmodule.toml and adjust as needed" -ForegroundColor White
Write-Host "  2. Update .gitignore to exclude psmodule.local.toml" -ForegroundColor White
Write-Host "  3. Update Deploy-Modules.ps1 to use Read-ModuleConfig" -ForegroundColor White
Write-Host "  4. Test deployment with new configuration:" -ForegroundColor White
Write-Host "     .\scripts\Deploy-Modules.ps1 -WhatIf" -ForegroundColor Gray
Write-Host "  5. Commit psmodule.toml to git" -ForegroundColor White
Write-Host ""
Write-Host "⚠ NOTE: Legacy config files (deployment.txt, local-deployment-config.json)" -ForegroundColor Yellow
Write-Host "  are not removed by this script. You can deprecate them manually after" -ForegroundColor Yellow
Write-Host "  verifying the new configuration works correctly." -ForegroundColor Yellow
Write-Host ""
