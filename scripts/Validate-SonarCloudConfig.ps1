#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates SonarCloud configuration and connectivity.

.DESCRIPTION
    This script validates the SonarCloud project configuration and checks
    if the required environment variables and files are properly set up.

.PARAMETER CheckToken
    Attempts to validate the SONAR_TOKEN if provided via environment variable.

.PARAMETER DetailedOutput
    Enables detailed output for diagnostics.

.EXAMPLE
    .\Validate-SonarCloudConfig.ps1
    Basic validation of SonarCloud configuration.

.EXAMPLE
    .\Validate-SonarCloudConfig.ps1 -CheckToken -DetailedOutput
    Full validation including token verification with detailed output.

.NOTES
    Author: My Scripts Collection
    Version: 1.0.0
    Created: 2024-12-08
#>

[CmdletBinding()]
param(
    [switch]$CheckToken,
    [switch]$DetailedOutput
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $icons = @{
        'Info'    = 'ℹ️'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Error'   = '❌'
    }

    Write-Host "$($icons[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Test-SonarProjectProperties {
    Write-Status "Checking sonar-project.properties..." -Type Info

    $propertiesFile = 'sonar-project.properties'
    if (-not (Test-Path $propertiesFile)) {
        Write-Status "sonar-project.properties not found!" -Type Error
        return $false
    }

    $content = Get-Content $propertiesFile
    $requiredProps = @(
        'sonar.projectKey',
        'sonar.organization'
    )

    $allFound = $true
    foreach ($prop in $requiredProps) {
        $found = $content | Where-Object { $_ -match "^$prop=" }
        if ($found) {
            $value = ($found -split '=', 2)[1]
            Write-Status "Found $prop = $value" -Type Success
        } else {
            Write-Status "Missing required property: $prop" -Type Error
            $allFound = $false
        }
    }

    return $allFound
}

function Test-CoverageFiles {
    Write-Status "Checking coverage files..." -Type Info

    $coverageFiles = @{
        'Python Coverage'     = 'coverage/python/coverage.xml'
        'PowerShell Coverage' = 'coverage/powershell/coverage.xml'
    }

    $foundAny = $false
    foreach ($desc in $coverageFiles.Keys) {
        $file = $coverageFiles[$desc]
        if (Test-Path $file) {
            Write-Status "$desc found at $file" -Type Success
            $foundAny = $true
        } else {
            Write-Status "$desc not found at $file (will be generated during tests)" -Type Warning
        }
    }

    return $foundAny
}

function Test-SonarToken {
    if (-not $CheckToken) {
        Write-Status "Skipping token validation (use -CheckToken to enable)" -Type Info
        return $true
    }

    Write-Status "Checking SONAR_TOKEN..." -Type Info

    $token = $env:SONAR_TOKEN
    if (-not $token) {
        Write-Status "SONAR_TOKEN environment variable not set" -Type Warning
        Write-Status "Set SONAR_TOKEN environment variable for local testing" -Type Info
        Write-Status "For CI/CD, ensure SONAR_TOKEN is configured in GitHub Secrets" -Type Info
        return $false
    }

    if ($token.Length -lt 20) {
        Write-Status "SONAR_TOKEN appears to be too short (possible invalid token)" -Type Warning
        return $false
    }

    Write-Status "SONAR_TOKEN is set and appears valid" -Type Success

    # Try to validate token by making a simple API call
    try {
        $headers = @{
            'Authorization' = "Bearer $token"
        }

        $response = Invoke-RestMethod -Uri 'https://sonarcloud.io/api/authentication/validate' -Headers $headers -Method Get
        Write-Status "Token validation successful" -Type Success
        return $true
    } catch {
        Write-Status "Token validation failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Show-HelpInstructions {
    Write-Status "SonarCloud Setup Instructions:" -Type Info
    Write-Host ""
    Write-Host "1. SonarCloud Token Setup:"
    Write-Host "   • Go to https://sonarcloud.io"
    Write-Host "   • Sign in with GitHub"
    Write-Host "   • Navigate to My Account → Security"
    Write-Host "   • Generate a new token"
    Write-Host ""
    Write-Host "2. GitHub Repository Secret:"
    Write-Host "   • Go to https://github.com/manoj-bhaskaran/My-Scripts"
    Write-Host "   • Settings → Secrets and variables → Actions"
    Write-Host "   • New repository secret: SONAR_TOKEN"
    Write-Host ""
    Write-Host "3. Local Testing (optional):"
    Write-Host "   • Set environment variable: `$env:SONAR_TOKEN = 'your-token'"
    Write-Host "   • Run: .\Validate-SonarCloudConfig.ps1 -CheckToken"
    Write-Host ""
}

# Main execution
try {
    Write-Status "🔍 SonarCloud Configuration Validation" -Type Info
    Write-Host ""

    $propertiesOk = Test-SonarProjectProperties
    Write-Host ""

    $coverageOk = Test-CoverageFiles
    Write-Host ""

    $tokenOk = Test-SonarToken
    Write-Host ""

    # Summary
    Write-Status "Validation Summary:" -Type Info
    Write-Status "Project Properties: $(if ($propertiesOk) { 'OK' } else { 'FAILED' })" -Type $(if ($propertiesOk) { 'Success' } else { 'Error' })
    Write-Status "Coverage Files: $(if ($coverageOk) { 'FOUND' } else { 'NOT FOUND' })" -Type $(if ($coverageOk) { 'Success' } else { 'Warning' })
    Write-Status "Token Validation: $(if ($tokenOk -or -not $CheckToken) { 'OK/SKIPPED' } else { 'FAILED' })" -Type $(if ($tokenOk -or -not $CheckToken) { 'Success' } else { 'Error' })

    Write-Host ""

    if (-not $propertiesOk) {
        Write-Status "❌ Configuration validation failed!" -Type Error
        Show-HelpInstructions
        exit 1
    }

    if ($CheckToken -and -not $tokenOk) {
        Write-Status "⚠️ Token validation failed, but configuration is otherwise OK" -Type Warning
        Show-HelpInstructions
        exit 0
    }

    Write-Status "✅ SonarCloud configuration validation passed!" -Type Success

} catch {
    Write-Status "Validation failed with error: $($_.Exception.Message)" -Type Error
    exit 1
}
