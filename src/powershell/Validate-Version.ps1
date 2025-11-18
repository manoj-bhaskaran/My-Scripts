<#
.SYNOPSIS
    Validates VERSION file matches CHANGELOG.md and follows semantic versioning

.DESCRIPTION
    This script ensures:
    1. VERSION file exists and contains valid semantic version
    2. CHANGELOG.md exists and is properly formatted
    3. Latest version in CHANGELOG matches VERSION file
    4. Version links at bottom of CHANGELOG are correct

.EXAMPLE
    .\Validate-Version.ps1

    Runs validation checks on VERSION and CHANGELOG.md files

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.0
    Exit Codes:
        0 - Validation passed
        1 - Validation failed
#>

[CmdletBinding()]
param()

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ ERROR: $Message" -ForegroundColor Red
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "⚠ WARNING: $Message" -ForegroundColor Yellow
}

function Write-InfoMsg {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Test-SemanticVersion {
    <#
    .SYNOPSIS
        Validates semantic versioning format (MAJOR.MINOR.PATCH)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    $Version = $Version.Trim()
    return $Version -match '^\d+\.\d+\.\d+$'
}

function Get-VersionFromFile {
    <#
    .SYNOPSIS
        Reads and validates VERSION file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VersionFilePath
    )

    if (-not (Test-Path $VersionFilePath)) {
        Write-ErrorMsg "VERSION file not found: $VersionFilePath"
        return $null
    }

    try {
        $version = (Get-Content $VersionFilePath -Raw).Trim()
    }
    catch {
        Write-ErrorMsg "Failed to read VERSION file: $_"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        Write-ErrorMsg "VERSION file is empty"
        return $null
    }

    if (-not (Test-SemanticVersion -Version $version)) {
        Write-ErrorMsg "VERSION file contains invalid semantic version: '$version'"
        Write-InfoMsg "Expected format: MAJOR.MINOR.PATCH (e.g., 1.0.0)"
        return $null
    }

    Write-Success "VERSION file is valid: $version"
    return $version
}

function Get-LatestVersionFromChangelog {
    <#
    .SYNOPSIS
        Extracts the latest version from CHANGELOG.md
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ChangelogFilePath
    )

    if (-not (Test-Path $ChangelogFilePath)) {
        Write-ErrorMsg "CHANGELOG.md not found: $ChangelogFilePath"
        return $null
    }

    try {
        $content = Get-Content $ChangelogFilePath -Raw
    }
    catch {
        Write-ErrorMsg "Failed to read CHANGELOG.md: $_"
        return $null
    }

    # Pattern to match version headers like ## [2.0.0] - 2025-11-16
    # Excludes [Unreleased] section
    $versionPattern = '##\s+\[(\d+\.\d+\.\d+)\]\s+-\s+(\d{4}-\d{2}-\d{2})'

    $matches = [regex]::Matches($content, $versionPattern)

    if ($matches.Count -eq 0) {
        Write-ErrorMsg "No versioned releases found in CHANGELOG.md"
        Write-InfoMsg "Expected format: ## [X.Y.Z] - YYYY-MM-DD"
        return $null
    }

    # First match is the latest version (CHANGELOG is in reverse chronological order)
    $latestVersion = $matches[0].Groups[1].Value
    $latestDate = $matches[0].Groups[2].Value

    Write-Success "Latest CHANGELOG version: $latestVersion ($latestDate)"

    return @{
        Version = $latestVersion
        Date = $latestDate
    }
}

function Test-ChangelogLinks {
    <#
    .SYNOPSIS
        Validates that version links at bottom of CHANGELOG are correct
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ChangelogFilePath,

        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    try {
        $content = Get-Content $ChangelogFilePath -Raw
    }
    catch {
        Write-ErrorMsg "Failed to read CHANGELOG.md: $_"
        return $false
    }

    # Check for version link
    $versionLinkPattern = "\[$([regex]::Escape($Version))\]:\s+https://github\.com/"

    if ($content -match $versionLinkPattern) {
        Write-Success "Version link found for v$Version"
        return $true
    }
    else {
        Write-WarningMsg "Version link not found for v$Version at bottom of CHANGELOG.md"
        Write-InfoMsg "Expected format: [X.Y.Z]: https://github.com/..."
        return $true  # Warning, not error
    }
}

function Test-UnreleasedSection {
    <#
    .SYNOPSIS
        Validates that CHANGELOG has an [Unreleased] section
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ChangelogFilePath
    )

    try {
        $content = Get-Content $ChangelogFilePath -Raw
    }
    catch {
        Write-ErrorMsg "Failed to read CHANGELOG.md: $_"
        return $false
    }

    $unreleasedPattern = '##\s+\[Unreleased\]'

    if ($content -match $unreleasedPattern) {
        Write-Success "CHANGELOG contains [Unreleased] section"
        return $true
    }
    else {
        Write-WarningMsg "CHANGELOG missing [Unreleased] section"
        return $true  # Warning, not error
    }
}

# Main execution
Write-Host ""
Write-Host "=== Version Validation ===" -ForegroundColor White
Write-Host ""

# Get repository root (script is in src/powershell/, so repo root is two levels up)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$versionFile = Join-Path $repoRoot "VERSION"
$changelogFile = Join-Path $repoRoot "CHANGELOG.md"

Write-InfoMsg "Repository root: $repoRoot"
Write-InfoMsg "VERSION file: $versionFile"
Write-InfoMsg "CHANGELOG file: $changelogFile"
Write-Host ""

# Step 1: Read and validate VERSION file
$version = Get-VersionFromFile -VersionFilePath $versionFile
if ($null -eq $version) {
    exit 1
}

# Step 2: Extract latest version from CHANGELOG
$changelogResult = Get-LatestVersionFromChangelog -ChangelogFilePath $changelogFile
if ($null -eq $changelogResult) {
    exit 1
}

$changelogVersion = $changelogResult.Version
$changelogDate = $changelogResult.Date

# Step 3: Compare versions
Write-Host ""
if ($version -eq $changelogVersion) {
    Write-Success "VERSION file matches CHANGELOG.md: $version"
}
else {
    Write-ErrorMsg "VERSION file ($version) does not match CHANGELOG.md ($changelogVersion)"
    Write-InfoMsg "Please update VERSION file or CHANGELOG.md to match"
    exit 1
}

# Step 4: Validate CHANGELOG structure
Write-Host ""
Test-UnreleasedSection -ChangelogFilePath $changelogFile | Out-Null
Test-ChangelogLinks -ChangelogFilePath $changelogFile -Version $version | Out-Null

# Success
Write-Host ""
Write-Host "✓ All validation checks passed!" -ForegroundColor Green
Write-Host ""

exit 0
