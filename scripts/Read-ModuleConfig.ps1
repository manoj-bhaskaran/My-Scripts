<#
.SYNOPSIS
    Reads and parses TOML-based module configuration files.

.DESCRIPTION
    Parses psmodule.toml and optionally merges user-specific overrides from
    psmodule.local.toml. Returns a structured configuration object for module
    deployment.

.PARAMETER ConfigPath
    Path to the main TOML configuration file.
    Defaults to psmodule.toml in the repository root.

.PARAMETER LocalConfigPath
    Path to the user-specific TOML configuration file.
    Defaults to psmodule.local.toml in the repository root.

.PARAMETER SkipLocalConfig
    Skip loading the local configuration file even if it exists.

.EXAMPLE
    $config = Read-ModuleConfig
    # Reads psmodule.toml and psmodule.local.toml (if exists)

.EXAMPLE
    $config = Read-ModuleConfig -ConfigPath "/path/to/custom.toml" -SkipLocalConfig
    # Reads only the specified config file

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Requires: PowerShell 5.1 or later

    TOML Parser:
    - Uses Tomlyn.Signed module from PowerShell Gallery
    - Automatically installs if not present
    - Falls back to basic TOML parser if module unavailable
#>

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$LocalConfigPath,
    [switch]$SkipLocalConfig
)

function Install-TomlParser {
    <#
    .SYNOPSIS
        Ensures a TOML parser is available.
    #>
    [CmdletBinding()]
    param()

    # Check if Tomlyn.Signed is available
    if (Get-Module -ListAvailable -Name Tomlyn.Signed) {
        Write-Verbose "TOML parser (Tomlyn.Signed) already installed"
        return $true
    }

    # Try to install Tomlyn.Signed
    try {
        Write-Host "Installing TOML parser (Tomlyn.Signed)..." -ForegroundColor Yellow
        Install-Module -Name Tomlyn.Signed -Force -Scope CurrentUser -ErrorAction Stop
        Write-Verbose "TOML parser installed successfully"
        return $true
    }
    catch {
        Write-Warning "Failed to install Tomlyn.Signed: $_"
        Write-Warning "Falling back to basic TOML parser"
        return $false
    }
}

function ConvertFrom-TomlBasic {
    <#
    .SYNOPSIS
        Basic TOML parser for simple configurations (fallback).
    .DESCRIPTION
        Provides basic TOML parsing when Tomlyn.Signed is not available.
        Supports simple key-value pairs, tables, and arrays of tables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TomlContent
    )

    $result = @{
        deployment = @{}
        modules = @()
    }

    $currentTable = $null
    $currentModule = $null

    foreach ($line in $TomlContent -split "`n") {
        $line = $line.Trim()

        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        # Array of tables [[modules]]
        if ($line -match '^\[\[(.+)\]\]$') {
            $tableName = $Matches[1]
            if ($tableName -eq 'modules') {
                $currentModule = @{}
                $result.modules += $currentModule
                $currentTable = $currentModule
            }
            continue
        }

        # Tables [deployment]
        if ($line -match '^\[(.+)\]$') {
            $tableName = $Matches[1]
            $currentTable = $result[$tableName]
            $currentModule = $null
            continue
        }

        # Key-value pairs
        if ($line -match '^([a-zA-Z0-9_-]+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()

            # Parse value type
            $parsedValue = switch -Regex ($value) {
                '^"(.+)"$' { $Matches[1] }  # String
                "^'(.+)'$" { $Matches[1] }  # String
                '^true$' { $true }           # Boolean
                '^false$' { $false }         # Boolean
                '^\d+$' { [int]$value }      # Integer
                '^\[(.+)\]$' {              # Array
                    $arrayContent = $Matches[1]
                    $arrayContent -split ',' | ForEach-Object {
                        $_.Trim().Trim('"').Trim("'")
                    }
                }
                default { $value }           # Default string
            }

            if ($currentTable) {
                $currentTable[$key] = $parsedValue
            }
        }
    }

    return $result
}

function Merge-Configuration {
    <#
    .SYNOPSIS
        Merges local configuration overrides into base configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BaseConfig,

        [Parameter(Mandatory)]
        [hashtable]$LocalConfig
    )

    # Merge deployment settings
    if ($LocalConfig.deployment) {
        foreach ($key in $LocalConfig.deployment.Keys) {
            $BaseConfig.deployment[$key] = $LocalConfig.deployment[$key]
            Write-Verbose "Merged deployment.$key from local config"
        }
    }

    # Merge module settings
    if ($LocalConfig.modules) {
        foreach ($localModule in $LocalConfig.modules) {
            $moduleName = $localModule.name
            $baseModule = $BaseConfig.modules | Where-Object { $_.name -eq $moduleName }

            if ($baseModule) {
                # Merge module properties
                foreach ($key in $localModule.Keys) {
                    if ($key -ne 'name') {
                        $baseModule[$key] = $localModule[$key]
                        Write-Verbose "Merged module $moduleName.$key from local config"
                    }
                }
            }
            else {
                Write-Warning "Local config references unknown module: $moduleName"
            }
        }
    }

    return $BaseConfig
}

# Main execution
try {
    # Determine script root and repository root
    $scriptRoot = $PSScriptRoot
    $repoRoot = if ($scriptRoot) {
        Split-Path -Path $scriptRoot -Parent
    } else {
        Get-Location
    }

    # Set default paths
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $repoRoot "psmodule.toml"
    }

    if (-not $LocalConfigPath) {
        $LocalConfigPath = Join-Path $repoRoot "psmodule.local.toml"
    }

    Write-Verbose "Repository root: $repoRoot"
    Write-Verbose "Config path: $ConfigPath"
    Write-Verbose "Local config path: $LocalConfigPath"

    # Verify main config exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Read main configuration
    $configContent = Get-Content $ConfigPath -Raw -Encoding UTF8

    # Try to parse with Tomlyn.Signed, fallback to basic parser
    $useTomlyn = Install-TomlParser

    if ($useTomlyn) {
        try {
            Import-Module Tomlyn.Signed -ErrorAction Stop
            $config = ConvertFrom-Toml $configContent
            Write-Verbose "Parsed config using Tomlyn.Signed"
        }
        catch {
            Write-Warning "Tomlyn.Signed failed, using basic parser: $_"
            $config = ConvertFrom-TomlBasic -TomlContent $configContent
        }
    }
    else {
        $config = ConvertFrom-TomlBasic -TomlContent $configContent
        Write-Verbose "Parsed config using basic parser"
    }

    # Load and merge local config if exists and not skipped
    if (-not $SkipLocalConfig -and (Test-Path $LocalConfigPath)) {
        Write-Verbose "Loading local configuration: $LocalConfigPath"

        $localContent = Get-Content $LocalConfigPath -Raw -Encoding UTF8

        if ($useTomlyn) {
            try {
                $localConfig = ConvertFrom-Toml $localContent
            }
            catch {
                Write-Warning "Failed to parse local config, using basic parser: $_"
                $localConfig = ConvertFrom-TomlBasic -TomlContent $localContent
            }
        }
        else {
            $localConfig = ConvertFrom-TomlBasic -TomlContent $localContent
        }

        # Merge configurations
        $config = Merge-Configuration -BaseConfig $config -LocalConfig $localConfig
        Write-Host "Merged local configuration overrides" -ForegroundColor Green
    }

    # Add repository root to config for convenience
    $config.repoRoot = $repoRoot

    Write-Verbose "Configuration loaded successfully"
    Write-Verbose "Modules configured: $($config.modules.Count)"

    return $config
}
catch {
    Write-Error "Failed to read module configuration: $_"
    throw
}
