<#
.SYNOPSIS
    Interactive configuration wizard for My-Scripts repository.

.DESCRIPTION
    This script provides an interactive wizard to configure the My-Scripts repository,
    including local deployment settings, module deployment, environment variables,
    and secrets configuration. It detects your operating system and guides you through
    the setup process.

.PARAMETER Force
    Overwrite existing configuration files without prompting.

.PARAMETER SkipValidation
    Skip configuration validation at the end.

.EXAMPLE
    .\scripts\Initialize-Configuration.ps1
    Run the interactive configuration wizard.

.EXAMPLE
    .\scripts\Initialize-Configuration.ps1 -Force
    Overwrite existing configuration without prompting.

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.0
    Last Updated: 2025-11-29
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$SkipValidation
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
$ColorCyan = "`e[36m"

# Helper function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Success", "Error", "Warning", "Info", "Header", "Prompt")]
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Success" { Write-Host "${ColorGreen}✅ ${Message}${ColorReset}" }
        "Error" { Write-Host "${ColorRed}❌ ${Message}${ColorReset}" }
        "Warning" { Write-Host "${ColorYellow}⚠️  ${Message}${ColorReset}" }
        "Info" { Write-Host "${ColorBlue}ℹ️  ${Message}${ColorReset}" }
        "Prompt" { Write-Host "${ColorCyan}${Message}${ColorReset}" -NoNewline }
        "Header" {
            Write-Host ""
            Write-Host "${ColorCyan}$Message${ColorReset}"
            Write-Host ("=" * 70)
        }
    }
}

# Helper function to prompt for user input
function Read-UserInput {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [string]$Default,

        [Parameter()]
        [switch]$Required
    )

    do {
        if ($Default) {
            Write-ColorOutput "${Prompt} [${Default}]: " -Type Prompt
        }
        else {
            Write-ColorOutput "${Prompt}: " -Type Prompt
        }

        $input = Read-Host

        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($Default) {
                return $Default
            }
            elseif ($Required) {
                Write-ColorOutput "This field is required. Please enter a value." -Type Error
            }
            else {
                return $null
            }
        }
        else {
            return $input.Trim()
        }
    } while ($Required)
}

# Helper function to prompt for yes/no
function Read-YesNo {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [bool]$Default = $true
    )

    $defaultStr = if ($Default) { "Y/n" } else { "y/N" }
    $response = Read-UserInput -Prompt "$Prompt [$defaultStr]" -Default $(if ($Default) { "Y" } else { "N" })

    return $response -match "^[Yy]"
}

# Helper function to detect OS
function Get-OSInfo {
    $os = $PSVersionTable.Platform
    $isWindows = $PSVersionTable.PSVersion.Major -ge 6 ? $IsWindows : $true

    if ($isWindows) {
        return @{
            Name     = "Windows"
            Platform = "Windows"
            PathSep  = "\"
        }
    }
    elseif ($PSVersionTable.Platform -eq "Unix") {
        if ($PSVersionTable.OS -match "Darwin") {
            return @{
                Name     = "macOS"
                Platform = "Unix"
                PathSep  = "/"
            }
        }
        else {
            return @{
                Name     = "Linux"
                Platform = "Unix"
                PathSep  = "/"
            }
        }
    }
    else {
        return @{
            Name     = "Unknown"
            Platform = "Unknown"
            PathSep  = "/"
        }
    }
}

# Main wizard logic
try {
    # Print welcome banner
    Clear-Host
    Write-Host ""
    Write-Host "${ColorCyan}╔═══════════════════════════════════════════════════════════════════╗${ColorReset}"
    Write-Host "${ColorCyan}║                                                                   ║${ColorReset}"
    Write-Host "${ColorCyan}║         My-Scripts Configuration Wizard                          ║${ColorReset}"
    Write-Host "${ColorCyan}║                                                                   ║${ColorReset}"
    Write-Host "${ColorCyan}╚═══════════════════════════════════════════════════════════════════╝${ColorReset}"
    Write-Host ""

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $osInfo = Get-OSInfo

    Write-ColorOutput "Detected OS: $($osInfo.Name)" -Type Info
    Write-ColorOutput "Repository: $repoRoot" -Type Info
    Write-Host ""

    # Ask user what they want to configure
    Write-ColorOutput "What would you like to configure?" -Type Header
    Write-Host ""
    Write-Host "  1. Local Deployment Configuration (git hooks deployment)"
    Write-Host "  2. Environment Variables"
    Write-Host "  3. PostgreSQL Backup Secrets"
    Write-Host "  4. Full Setup (all of the above)"
    Write-Host ""

    $choice = Read-UserInput -Prompt "Enter your choice [1-4]" -Default "4" -Required

    $configureDeployment = $choice -in @("1", "4")
    $configureEnv = $choice -in @("2", "4")
    $configureSecrets = $choice -in @("3", "4")

    # 1. Configure Local Deployment
    if ($configureDeployment) {
        Write-ColorOutput "`nStep 1: Local Deployment Configuration" -Type Header

        $configPath = Join-Path $repoRoot "config/local-deployment-config.json"
        $examplePath = Join-Path $repoRoot "config/local-deployment-config.json.example"

        if ((Test-Path $configPath) -and -not $Force) {
            $overwrite = Read-YesNo -Prompt "Configuration file already exists. Overwrite?" -Default $false
            if (-not $overwrite) {
                Write-ColorOutput "Skipping local deployment configuration" -Type Warning
                $configureDeployment = $false
            }
        }

        if ($configureDeployment) {
            Write-Host ""
            Write-ColorOutput "This configuration controls automatic deployment via git hooks." -Type Info
            Write-ColorOutput "Files will be automatically mirrored to your staging directory on commit/merge." -Type Info
            Write-Host ""

            # Prompt for enabled
            $enabled = Read-YesNo -Prompt "Enable automatic deployment?" -Default $true

            # Prompt for staging mirror
            if ($osInfo.Name -eq "Windows") {
                $defaultStaging = "C:\Users\$env:USERNAME\Documents\Scripts"
            }
            else {
                $defaultStaging = "$HOME/scripts"
            }

            $stagingMirror = Read-UserInput -Prompt "Staging mirror directory" -Default $defaultStaging -Required

            # Normalize path for JSON
            if ($osInfo.Name -eq "Windows") {
                $stagingMirror = $stagingMirror -replace "\\", "\\"
            }

            # Ask about optional settings
            $configureAdvanced = Read-YesNo -Prompt "Configure advanced settings (module filter, exclude patterns)?" -Default $false

            $config = @{
                enabled       = $enabled
                stagingMirror = $stagingMirror
            }

            if ($configureAdvanced) {
                Write-Host ""

                # Module filter
                $useModuleFilter = Read-YesNo -Prompt "Filter specific modules only?" -Default $false
                if ($useModuleFilter) {
                    Write-ColorOutput "Enter module names (comma-separated, e.g., ErrorHandling,PostgresBackup)" -Type Info
                    $moduleFilterInput = Read-UserInput -Prompt "Module filter"
                    if ($moduleFilterInput) {
                        $config.moduleFilter = $moduleFilterInput -split "," | ForEach-Object { $_.Trim() }
                    }
                }

                # Exclude patterns
                $useExcludePatterns = Read-YesNo -Prompt "Exclude certain file patterns?" -Default $false
                if ($useExcludePatterns) {
                    Write-ColorOutput "Enter patterns (comma-separated, e.g., *.test.ps1,*.md)" -Type Info
                    $excludePatternsInput = Read-UserInput -Prompt "Exclude patterns"
                    if ($excludePatternsInput) {
                        $config.excludePatterns = $excludePatternsInput -split "," | ForEach-Object { $_.Trim() }
                    }
                }
            }

            # Write configuration file
            try {
                $configJson = $config | ConvertTo-Json -Depth 10
                $configJson | Out-File -FilePath $configPath -Encoding utf8 -Force
                Write-ColorOutput "Local deployment configuration saved: $configPath" -Type Success
            }
            catch {
                Write-ColorOutput "Failed to save configuration: $($_.Exception.Message)" -Type Error
            }
        }
    }

    # 2. Configure Environment Variables
    if ($configureEnv) {
        Write-ColorOutput "`nStep 2: Environment Variables" -Type Header

        Write-Host ""
        Write-ColorOutput "Environment variables configure database connections and script behavior." -Type Info
        Write-Host ""

        # MY_SCRIPTS_ROOT
        $currentScriptsRoot = [Environment]::GetEnvironmentVariable("MY_SCRIPTS_ROOT", "User")
        if ($osInfo.Name -eq "Windows") {
            $defaultScriptsRoot = if ($currentScriptsRoot) { $currentScriptsRoot } else { "C:\Users\$env:USERNAME\Documents\Scripts" }
        }
        else {
            $defaultScriptsRoot = if ($currentScriptsRoot) { $currentScriptsRoot } else { "$HOME/scripts" }
        }

        $scriptsRoot = Read-UserInput -Prompt "MY_SCRIPTS_ROOT (script execution directory)" -Default $defaultScriptsRoot
        if ($scriptsRoot) {
            [Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", $scriptsRoot, "User")
            Write-ColorOutput "Set MY_SCRIPTS_ROOT=$scriptsRoot" -Type Success
        }

        # PostgreSQL settings
        $configurePostgres = Read-YesNo -Prompt "Configure PostgreSQL connection settings?" -Default $false

        if ($configurePostgres) {
            Write-Host ""

            $pghost = Read-UserInput -Prompt "PGHOST (PostgreSQL server)" -Default "localhost"
            if ($pghost) {
                [Environment]::SetEnvironmentVariable("PGHOST", $pghost, "User")
                Write-ColorOutput "Set PGHOST=$pghost" -Type Success
            }

            $pgport = Read-UserInput -Prompt "PGPORT (PostgreSQL port)" -Default "5432"
            if ($pgport) {
                [Environment]::SetEnvironmentVariable("PGPORT", $pgport, "User")
                Write-ColorOutput "Set PGPORT=$pgport" -Type Success
            }

            $pguser = Read-UserInput -Prompt "PGUSER (PostgreSQL username)" -Default "postgres"
            if ($pguser) {
                [Environment]::SetEnvironmentVariable("PGUSER", $pguser, "User")
                Write-ColorOutput "Set PGUSER=$pguser" -Type Success
            }
        }

        Write-Host ""
        Write-ColorOutput "Environment variables set for current user (permanent)" -Type Info
        Write-ColorOutput "Restart your terminal/PowerShell session to apply changes" -Type Warning
    }

    # 3. Configure PostgreSQL Backup Secrets
    if ($configureSecrets) {
        Write-ColorOutput "`nStep 3: PostgreSQL Backup Secrets" -Type Header

        Write-Host ""
        Write-ColorOutput "Create encrypted password file for PostgreSQL backups." -Type Info
        Write-ColorOutput "Password is encrypted using Windows DPAPI (user and machine specific)." -Type Info
        Write-Host ""

        $configurePassword = Read-YesNo -Prompt "Create encrypted password file?" -Default $true

        if ($configurePassword) {
            $secretsDir = Join-Path $repoRoot "config/secrets"

            # Ensure secrets directory exists
            if (-not (Test-Path $secretsDir)) {
                New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
            }

            $passwordFile = Join-Path $secretsDir "pgbackup_user_pwd.txt"

            if ((Test-Path $passwordFile) -and -not $Force) {
                $overwrite = Read-YesNo -Prompt "Password file already exists. Overwrite?" -Default $false
                if (-not $overwrite) {
                    Write-ColorOutput "Skipping password file creation" -Type Warning
                    $configurePassword = $false
                }
            }

            if ($configurePassword) {
                Write-Host ""
                $password = Read-Host "Enter PostgreSQL backup password" -AsSecureString

                try {
                    $password | ConvertFrom-SecureString | Out-File -FilePath $passwordFile -Force
                    Write-ColorOutput "Encrypted password saved: $passwordFile" -Type Success
                }
                catch {
                    Write-ColorOutput "Failed to save password file: $($_.Exception.Message)" -Type Error
                }
            }
        }
    }

    # Summary and Next Steps
    Write-ColorOutput "`nConfiguration Complete!" -Type Header
    Write-Host ""
    Write-ColorOutput "Configuration wizard completed successfully!" -Type Success
    Write-Host ""

    Write-Host "What was configured:"
    if ($configureDeployment) {
        Write-Host "  ✅ Local deployment configuration"
    }
    if ($configureEnv) {
        Write-Host "  ✅ Environment variables"
    }
    if ($configureSecrets) {
        Write-Host "  ✅ PostgreSQL backup secrets"
    }
    Write-Host ""

    Write-Host "Next steps:"
    Write-Host ""
    Write-Host "  1. Install git hooks:"
    if ($osInfo.Name -eq "Windows") {
        Write-Host "     ${ColorCyan}.\scripts\Install-GitHooks.ps1${ColorReset}"
    }
    else {
        Write-Host "     ${ColorCyan}./scripts/install-hooks.sh${ColorReset}"
    }
    Write-Host ""

    Write-Host "  2. Deploy PowerShell modules (optional):"
    if ($osInfo.Name -eq "Windows") {
        Write-Host "     ${ColorCyan}.\scripts\Deploy-Modules.ps1 -Force${ColorReset}"
    }
    else {
        Write-Host "     ${ColorCyan}./scripts/install-modules.sh --force${ColorReset}"
    }
    Write-Host ""

    Write-Host "  3. Validate configuration:"
    Write-Host "     ${ColorCyan}.\scripts\Verify-Configuration.ps1${ColorReset}"
    Write-Host ""

    Write-Host "  4. Read the configuration guide:"
    Write-Host "     ${ColorCyan}config/CONFIG_GUIDE.md${ColorReset}"
    Write-Host ""

    # Run validation if requested
    if (-not $SkipValidation) {
        $runValidation = Read-YesNo -Prompt "Run configuration validation now?" -Default $true

        if ($runValidation) {
            Write-Host ""
            $validationScript = Join-Path $PSScriptRoot "Verify-Configuration.ps1"
            if (Test-Path $validationScript) {
                & $validationScript
            }
            else {
                Write-ColorOutput "Validation script not found: $validationScript" -Type Warning
            }
        }
    }

    Write-Host ""
    Write-ColorOutput "Thank you for using My-Scripts!" -Type Success
    Write-Host ""

    exit 0
}
catch {
    Write-ColorOutput "Unexpected error during configuration: $($_.Exception.Message)" -Type Error
    Write-Host ""
    Write-Host "Error details:"
    Write-Host $_.Exception.Message
    Write-Host ""
    Write-Host "Stack trace:"
    Write-Host $_.ScriptStackTrace
    Write-Host ""
    exit 1
}
