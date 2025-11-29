<#
.SYNOPSIS
    Validates My-Scripts repository configuration.

.DESCRIPTION
    This script validates all configuration files and settings for the My-Scripts repository,
    including local deployment config, module deployment config, environment variables,
    git hooks, and secrets configuration.

.PARAMETER Verbose
    Show detailed validation output.

.PARAMETER ConfigPath
    Path to local deployment configuration file.
    Default: config/local-deployment-config.json

.EXAMPLE
    .\scripts\Verify-Configuration.ps1
    Validates configuration with standard output.

.EXAMPLE
    .\scripts\Verify-Configuration.ps1 -Verbose
    Validates configuration with detailed output.

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.0
    Last Updated: 2025-11-29
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = "config/local-deployment-config.json"
)

#Requires -Version 5.1

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Color codes for output
$ColorReset = "`e[0m"
$ColorGreen = "`e[32m"
$ColorRed = "`e[31m"
$ColorYellow = "`e[33m"
$ColorBlue = "`e[34m"

# Symbols for output
$SymbolSuccess = "✅"
$SymbolError = "❌"
$SymbolWarning = "⚠️"
$SymbolInfo = "ℹ️"

# Track validation results
$script:ValidationErrors = @()
$script:ValidationWarnings = @()
$script:ValidationPassed = 0
$script:ValidationFailed = 0

# Helper function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Success", "Error", "Warning", "Info", "Header")]
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Success" {
            Write-Host "${ColorGreen}${SymbolSuccess} ${Message}${ColorReset}"
            $script:ValidationPassed++
        }
        "Error" {
            Write-Host "${ColorRed}${SymbolError} ${Message}${ColorReset}"
            $script:ValidationErrors += $Message
            $script:ValidationFailed++
        }
        "Warning" {
            Write-Host "${ColorYellow}${SymbolWarning} ${Message}${ColorReset}"
            $script:ValidationWarnings += $Message
        }
        "Info" {
            Write-Host "${ColorBlue}${SymbolInfo} ${Message}${ColorReset}"
        }
        "Header" {
            Write-Host ""
            Write-Host "${ColorBlue}$Message${ColorReset}"
            Write-Host ("=" * 60)
        }
    }
}

# Helper function to test JSON file
function Test-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Description
    )

    Write-Verbose "Testing JSON file: $Path"

    if (-not (Test-Path $Path)) {
        Write-ColorOutput "File not found: $Description" -Type Error
        return $null
    }

    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        Write-ColorOutput "${Description}: Valid JSON" -Type Success
        return $content
    }
    catch {
        Write-ColorOutput "${Description}: Invalid JSON - $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Helper function to test directory
function Test-DirectoryExists {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [switch]$TestWritable
    )

    Write-Verbose "Testing directory: $Path"

    if (-not (Test-Path $Path -PathType Container)) {
        Write-ColorOutput "${Description}: Directory does not exist" -Type Error
        return $false
    }

    if ($TestWritable) {
        try {
            $testFile = Join-Path $Path ".test_$(Get-Random)"
            $null = New-Item -Path $testFile -ItemType File -Force
            Remove-Item -Path $testFile -Force
            Write-ColorOutput "${Description}: Exists and writable" -Type Success
            return $true
        }
        catch {
            Write-ColorOutput "${Description}: Exists but not writable - $($_.Exception.Message)" -Type Error
            return $false
        }
    }
    else {
        Write-ColorOutput "${Description}: Exists" -Type Success
        return $true
    }
}

# Helper function to test command availability
function Test-CommandExists {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [switch]$Optional
    )

    Write-Verbose "Testing command: $Command"

    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)

    if ($exists) {
        Write-ColorOutput "${Description}: Available" -Type Success
        return $true
    }
    else {
        if ($Optional) {
            Write-ColorOutput "${Description}: Not available (optional)" -Type Warning
        }
        else {
            Write-ColorOutput "${Description}: Not available" -Type Error
        }
        return $false
    }
}

# Main validation logic
try {
    # Print header
    Write-Host ""
    Write-ColorOutput "My-Scripts Configuration Validation" -Type Header

    # 1. Validate local deployment configuration
    Write-ColorOutput "`n1. Local Deployment Configuration" -Type Header

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $fullConfigPath = Join-Path $repoRoot $ConfigPath

    if (Test-Path $fullConfigPath) {
        $config = Test-JsonFile -Path $fullConfigPath -Description "Local deployment config"

        if ($config) {
            # Check required fields
            if ($null -eq $config.enabled) {
                Write-ColorOutput "Missing required field: 'enabled'" -Type Error
            }
            elseif ($config.enabled -is [bool]) {
                Write-ColorOutput "Field 'enabled': Valid boolean ($($config.enabled))" -Type Success
            }
            else {
                Write-ColorOutput "Field 'enabled': Invalid type (expected boolean)" -Type Error
            }

            if ($null -eq $config.stagingMirror) {
                Write-ColorOutput "Missing required field: 'stagingMirror'" -Type Error
            }
            elseif ([string]::IsNullOrWhiteSpace($config.stagingMirror)) {
                Write-ColorOutput "Field 'stagingMirror': Empty or whitespace" -Type Error
            }
            else {
                # Test if staging mirror path exists and is writable
                $stagingMirror = $config.stagingMirror
                if ($config.enabled) {
                    Test-DirectoryExists -Path $stagingMirror -Description "Staging mirror path" -TestWritable
                }
                else {
                    Write-ColorOutput "Deployment disabled, skipping staging mirror validation" -Type Info
                }
            }

            # Check optional fields
            if ($config.moduleFilter) {
                if ($config.moduleFilter -is [array]) {
                    Write-ColorOutput "Module filter: Configured with $($config.moduleFilter.Count) module(s)" -Type Success
                }
                else {
                    Write-ColorOutput "Module filter: Invalid type (expected array)" -Type Error
                }
            }

            if ($config.excludePatterns) {
                if ($config.excludePatterns -is [array]) {
                    Write-ColorOutput "Exclude patterns: Configured with $($config.excludePatterns.Count) pattern(s)" -Type Success
                }
                else {
                    Write-ColorOutput "Exclude patterns: Invalid type (expected array)" -Type Error
                }
            }
        }
    }
    else {
        Write-ColorOutput "Local deployment config file not found (optional for non-deployment setups)" -Type Warning
    }

    # 2. Validate module deployment configuration
    Write-ColorOutput "`n2. Module Deployment Configuration" -Type Header

    $moduleConfigPath = Join-Path $repoRoot "config/modules/deployment.txt"
    if (Test-Path $moduleConfigPath) {
        Write-ColorOutput "Module deployment config: Found" -Type Success

        $moduleLines = Get-Content $moduleConfigPath | Where-Object {
            $_ -match '\S' -and $_ -notmatch '^\s*#'
        }

        if ($moduleLines.Count -gt 0) {
            Write-ColorOutput "Module deployment config: $($moduleLines.Count) module(s) configured" -Type Success
        }
        else {
            Write-ColorOutput "Module deployment config: No modules configured" -Type Warning
        }
    }
    else {
        Write-ColorOutput "Module deployment config: Not found" -Type Error
    }

    # 3. Validate git hooks
    Write-ColorOutput "`n3. Git Hooks" -Type Header

    $gitHooksDir = Join-Path $repoRoot ".git/hooks"
    if (Test-Path $gitHooksDir) {
        $hooks = @("post-commit", "post-merge", "pre-commit", "commit-msg")

        foreach ($hook in $hooks) {
            $hookPath = Join-Path $gitHooksDir $hook
            if (Test-Path $hookPath) {
                Write-ColorOutput "Git hook '$hook': Installed" -Type Success
            }
            else {
                Write-ColorOutput "Git hook '$hook': Not installed" -Type Warning
            }
        }
    }
    else {
        Write-ColorOutput "Git hooks directory: Not found (not a git repository?)" -Type Error
    }

    # 4. Validate PowerShell modules
    Write-ColorOutput "`n4. PowerShell Modules" -Type Header

    $expectedModules = @(
        "PostgresBackup",
        "PowerShellLoggingFramework",
        "PurgeLogs",
        "RandomName",
        "Videoscreenshot",
        "ErrorHandling",
        "FileOperations",
        "ProgressReporter"
    )

    foreach ($module in $expectedModules) {
        $moduleAvailable = $null -ne (Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue)
        if ($moduleAvailable) {
            $moduleInfo = Get-Module -ListAvailable -Name $module | Select-Object -First 1
            Write-ColorOutput "Module '$module': Available (v$($moduleInfo.Version))" -Type Success
        }
        else {
            Write-ColorOutput "Module '$module': Not installed" -Type Warning
        }
    }

    # 5. Validate environment variables
    Write-ColorOutput "`n5. Environment Variables" -Type Header

    $envVars = @{
        "MY_SCRIPTS_ROOT" = $true
        "PGHOST"          = $false
        "PGPORT"          = $false
        "PGUSER"          = $false
    }

    foreach ($varName in $envVars.Keys) {
        $varValue = [Environment]::GetEnvironmentVariable($varName)
        $required = $envVars[$varName]

        if ([string]::IsNullOrWhiteSpace($varValue)) {
            if ($required) {
                Write-ColorOutput "Environment variable '$varName': Not set" -Type Error
            }
            else {
                Write-ColorOutput "Environment variable '$varName': Not set (optional)" -Type Warning
            }
        }
        else {
            Write-ColorOutput "Environment variable '$varName': Set to '$varValue'" -Type Success
        }
    }

    # 6. Validate secrets directory
    Write-ColorOutput "`n6. Secrets Configuration" -Type Header

    $secretsDir = Join-Path $repoRoot "config/secrets"
    if (Test-DirectoryExists -Path $secretsDir -Description "Secrets directory") {
        # Check for password file
        $passwordFile = Join-Path $secretsDir "pgbackup_user_pwd.txt"
        if (Test-Path $passwordFile) {
            Write-ColorOutput "PostgreSQL password file: Found" -Type Success
        }
        else {
            Write-ColorOutput "PostgreSQL password file: Not found (optional if not using DB backups)" -Type Warning
        }
    }

    # 7. Validate required commands
    Write-ColorOutput "`n7. Required Commands" -Type Header

    Test-CommandExists -Command "git" -Description "Git"
    Test-CommandExists -Command "pwsh" -Description "PowerShell 7+" -Optional
    Test-CommandExists -Command "python3" -Description "Python 3" -Optional
    Test-CommandExists -Command "pip3" -Description "pip3" -Optional

    # 8. Summary
    Write-ColorOutput "`n8. Validation Summary" -Type Header

    Write-Host ""
    Write-Host "Validation Results:"
    Write-Host "  ${ColorGreen}Passed: $script:ValidationPassed${ColorReset}"
    Write-Host "  ${ColorRed}Failed: $script:ValidationFailed${ColorReset}"
    Write-Host "  ${ColorYellow}Warnings: $($script:ValidationWarnings.Count)${ColorReset}"
    Write-Host ""

    if ($script:ValidationFailed -eq 0) {
        Write-ColorOutput "✅ Configuration validation PASSED" -Type Success
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  1. Deploy PowerShell modules: .\scripts\Deploy-Modules.ps1 -Force"
        Write-Host "  2. Install git hooks: .\scripts\Install-GitHooks.ps1"
        Write-Host "  3. Test deployment: git commit --dry-run"
        Write-Host ""
        exit 0
    }
    else {
        Write-ColorOutput "❌ Configuration validation FAILED with $script:ValidationFailed error(s)" -Type Error
        Write-Host ""
        Write-Host "Errors found:"
        foreach ($error in $script:ValidationErrors) {
            Write-Host "  - $error"
        }
        Write-Host ""
        Write-Host "Please fix the errors above and re-run validation."
        Write-Host "See config/CONFIG_GUIDE.md for configuration help."
        Write-Host ""
        exit 1
    }
}
catch {
    Write-ColorOutput "Unexpected error during validation: $($_.Exception.Message)" -Type Error
    Write-Verbose "Error details: $($_ | Out-String)"
    exit 1
}
