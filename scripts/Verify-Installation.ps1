<#
.SYNOPSIS
    Verifies My-Scripts installation completeness and correctness.

.DESCRIPTION
    This script checks all prerequisites, dependencies, modules, and configuration
    to ensure the My-Scripts repository is properly installed and ready to use.

    Checks performed:
    - PowerShell version (5.1+ or 7+)
    - Python version (3.8+)
    - Git version (2.30+)
    - PowerShell modules availability
    - Python packages installation
    - Git hooks configuration
    - Optional software (VLC, PostgreSQL, ADB)

.PARAMETER Verbose
    Provides detailed output for each check.

.PARAMETER IncludeOptional
    Also checks for optional software (VLC, PostgreSQL, ADB).

.EXAMPLE
    .\Verify-Installation.ps1
    Runs basic installation verification.

.EXAMPLE
    .\Verify-Installation.ps1 -Verbose -IncludeOptional
    Runs comprehensive verification with detailed output.

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
    Created: 2025-11-19
    Requires: PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [switch]$IncludeOptional
)

# Script variables
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0

# Helper function to test prerequisite software
function Test-Prerequisite {
    param(
        [string]$Name,
        [string]$Command,
        [version]$MinVersion,
        [switch]$Optional
    )

    Write-Verbose "Testing $Name..."

    try {
        # Execute command and capture output
        $output = Invoke-Expression $Command 2>$null

        if ($LASTEXITCODE -eq 0 -or $output) {
            # Extract version from output
            $versionMatch = $output | Select-String -Pattern '(\d+\.[\d\.]+)' | Select-Object -First 1

            if ($versionMatch) {
                $currentVersion = [version]($versionMatch.Matches[0].Groups[1].Value -replace '^(\d+\.\d+\.\d+).*', '$1')

                if ($currentVersion -ge $MinVersion) {
                    Write-Host "✅ $Name $currentVersion (Minimum: $MinVersion)" -ForegroundColor Green
                    $script:PassCount++
                    return $true
                }
                else {
                    Write-Host "⚠️  $Name $currentVersion is below minimum version $MinVersion" -ForegroundColor Yellow
                    $script:WarnCount++
                    return $false
                }
            }
            else {
                Write-Host "✅ $Name installed" -ForegroundColor Green
                $script:PassCount++
                return $true
            }
        }
        else {
            if ($Optional) {
                Write-Host "⚠️  $Name not found (optional)" -ForegroundColor Yellow
                $script:WarnCount++
            }
            else {
                Write-Host "❌ $Name not found" -ForegroundColor Red
                $script:FailCount++
            }
            return $false
        }
    }
    catch {
        if ($Optional) {
            Write-Host "⚠️  $Name not found (optional)" -ForegroundColor Yellow
            $script:WarnCount++
        }
        else {
            Write-Host "❌ $Name not found or not accessible" -ForegroundColor Red
            $script:FailCount++
        }
        return $false
    }
}

# Helper function to check PowerShell modules
function Test-PowerShellModule {
    param(
        [string]$ModuleName,
        [version]$MinVersion
    )

    Write-Verbose "Checking PowerShell module: $ModuleName..."

    $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

    if ($module) {
        if ($MinVersion -and $module.Version -lt $MinVersion) {
            Write-Host "⚠️  $ModuleName ($($module.Version)) - below minimum $MinVersion" -ForegroundColor Yellow
            $script:WarnCount++
            return $false
        }
        else {
            Write-Host "✅ $ModuleName ($($module.Version))" -ForegroundColor Green
            $script:PassCount++
            return $true
        }
    }
    else {
        Write-Host "❌ $ModuleName not found" -ForegroundColor Red
        $script:FailCount++
        return $false
    }
}

# Helper function to check Python packages
function Test-PythonPackage {
    param(
        [string]$PackageName
    )

    Write-Verbose "Checking Python package: $PackageName..."

    try {
        # Try using pip show
        $output = & python -m pip show $PackageName 2>$null

        if ($LASTEXITCODE -eq 0 -and $output) {
            Write-Host "✅ $PackageName" -ForegroundColor Green
            $script:PassCount++
            return $true
        }
        else {
            Write-Host "❌ $PackageName not installed" -ForegroundColor Red
            $script:FailCount++
            return $false
        }
    }
    catch {
        Write-Host "❌ $PackageName not installed" -ForegroundColor Red
        $script:FailCount++
        return $false
    }
}

# Helper function to check file existence
function Test-FileExists {
    param(
        [string]$Path,
        [string]$Description
    )

    Write-Verbose "Checking file: $Path..."

    if (Test-Path $Path) {
        Write-Host "✅ $Description" -ForegroundColor Green
        $script:PassCount++
        return $true
    }
    else {
        Write-Host "❌ $Description not found" -ForegroundColor Red
        $script:FailCount++
        return $false
    }
}

# Main verification script
Write-Host ""
Write-Host "Installation Verification for My-Scripts Repository" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
Write-Verbose "Checking PowerShell version..."
$psVersion = $PSVersionTable.PSVersion
$minPSVersion = [version]"5.1.0"

if ($psVersion -ge $minPSVersion) {
    Write-Host "✅ PowerShell $psVersion (Minimum: $minPSVersion)" -ForegroundColor Green
    $script:PassCount++
}
else {
    Write-Host "❌ PowerShell $psVersion is below minimum $minPSVersion" -ForegroundColor Red
    $script:FailCount++
}

# Check Python
Test-Prerequisite -Name "Python" -Command "python --version" -MinVersion ([version]"3.8.0") | Out-Null

# Check Git
Test-Prerequisite -Name "Git" -Command "git --version" -MinVersion ([version]"2.30.0") | Out-Null

Write-Host ""
Write-Host "PowerShell Modules:" -ForegroundColor Cyan

# Check PowerShell modules
$modules = @(
    @{Name = "PostgresBackup"; MinVersion = $null },
    @{Name = "PowerShellLoggingFramework"; MinVersion = $null },
    @{Name = "PurgeLogs"; MinVersion = $null },
    @{Name = "RandomName"; MinVersion = $null },
    @{Name = "Videoscreenshot"; MinVersion = $null }
)

foreach ($module in $modules) {
    Test-PowerShellModule -ModuleName $module.Name -MinVersion $module.MinVersion | Out-Null
}

Write-Host ""
Write-Host "Python Packages:" -ForegroundColor Cyan

# Check critical Python packages
$packages = @(
    "requests",
    "numpy",
    "pandas",
    "opencv-python",
    "psycopg2",
    "google-api-python-client"
)

foreach ($package in $packages) {
    Test-PythonPackage -PackageName $package | Out-Null
}

Write-Host ""
Write-Host "Git Hooks:" -ForegroundColor Cyan

# Check Git hooks
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$hookPath = Join-Path $repoRoot ".git" "hooks"

Test-FileExists -Path (Join-Path $hookPath "pre-commit") -Description "pre-commit hook configured" | Out-Null
Test-FileExists -Path (Join-Path $hookPath "commit-msg") -Description "commit-msg hook configured" | Out-Null
Test-FileExists -Path (Join-Path $hookPath "post-commit") -Description "post-commit hook configured" | Out-Null

# Check optional software if requested
if ($IncludeOptional) {
    Write-Host ""
    Write-Host "Optional Software:" -ForegroundColor Cyan

    # Check VLC
    Test-Prerequisite -Name "VLC" -Command "vlc --version" -MinVersion ([version]"3.0.0") -Optional | Out-Null

    # Check PostgreSQL
    Test-Prerequisite -Name "PostgreSQL" -Command "psql --version" -MinVersion ([version]"12.0.0") -Optional | Out-Null

    # Check ADB
    Test-Prerequisite -Name "ADB" -Command "adb --version" -MinVersion ([version]"1.0.0") -Optional | Out-Null
}

# Summary
Write-Host ""
Write-Host "Verification Summary:" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Passed: $script:PassCount" -ForegroundColor Green

if ($script:WarnCount -gt 0) {
    Write-Host "Warnings: $script:WarnCount" -ForegroundColor Yellow
}

if ($script:FailCount -gt 0) {
    Write-Host "Failed: $script:FailCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  Installation is incomplete or has issues." -ForegroundColor Yellow
    Write-Host "   See INSTALLATION.md for troubleshooting guidance." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
else {
    Write-Host ""
    Write-Host "Installation verification complete! ✅" -ForegroundColor Green

    if ($script:WarnCount -gt 0) {
        Write-Host ""
        Write-Host "Note: Some optional components are missing. This is OK for basic usage." -ForegroundColor Yellow
        Write-Host "      See INSTALLATION.md for optional software installation." -ForegroundColor Yellow
    }

    Write-Host ""
    exit 0
}
