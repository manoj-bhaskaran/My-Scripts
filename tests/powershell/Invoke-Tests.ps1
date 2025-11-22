<#
.SYNOPSIS
    PowerShell test runner with code coverage reporting.

.DESCRIPTION
    This script executes all PowerShell tests using Pester and generates
    code coverage reports in JaCoCo format (compatible with SonarCloud and Codecov).

.PARAMETER Path
    Path to the tests directory. Defaults to current script's parent directory.

.PARAMETER CodeCoverageEnabled
    Enable code coverage reporting. Defaults to $true.

.PARAMETER OutputPath
    Path where coverage report will be saved. Defaults to 'coverage/powershell/coverage.xml'.

.PARAMETER MinimumCoverage
    Minimum coverage percentage required. Defaults to 30%.

.PARAMETER Verbosity
    Output verbosity level. Options: None, Normal, Detailed, Diagnostic. Defaults to Detailed.

.EXAMPLE
    .\Invoke-Tests.ps1
    Runs all tests with default settings (coverage enabled, 30% threshold)

.EXAMPLE
    .\Invoke-Tests.ps1 -CodeCoverageEnabled $false
    Runs tests without generating coverage reports

.EXAMPLE
    .\Invoke-Tests.ps1 -MinimumCoverage 50 -Verbosity Diagnostic
    Runs tests with 50% coverage threshold and detailed diagnostic output

.NOTES
    Version: 1.0.0
    Author: My-Scripts Repository
    Requires: Pester 5.0.0+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [bool]$CodeCoverageEnabled = $true,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'coverage/powershell/coverage.xml',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]$MinimumCoverage = 30,

    [Parameter(Mandatory = $false)]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Verbosity = 'Detailed'
)

# Ensure we're using Pester 5.x
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule -or $pesterModule.Version.Major -lt 5) {
    Write-Error "Pester 5.0.0 or higher is required. Please install: Install-Module -Name Pester -Force -Scope CurrentUser"
    exit 1
}

Write-Host "Using Pester version: $($pesterModule.Version)" -ForegroundColor Cyan
Import-Module Pester -MinimumVersion 5.0.0

# Resolve paths
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$testPath = Resolve-Path $Path
$outputFile = Join-Path $repoRoot $OutputPath

# Create output directory if it doesn't exist
$outputDir = Split-Path $outputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $outputDir" -ForegroundColor Green
}

# Find all PowerShell source files to include in coverage
$coveragePaths = @()
$srcPaths = @(
    (Join-Path $repoRoot 'src' 'powershell'),
    (Join-Path $repoRoot 'src' 'common')
)

foreach ($srcPath in $srcPaths) {
    if (Test-Path $srcPath) {
        $psFiles = Get-ChildItem -Path $srcPath -Include '*.ps1', '*.psm1' -Recurse -File |
            Where-Object { $_.Name -notlike '*.Tests.ps1' } |
            Select-Object -ExpandProperty FullName
        $coveragePaths += $psFiles
    }
}

if ($coveragePaths.Count -eq 0) {
    Write-Warning "No PowerShell source files found for coverage analysis"
    $CodeCoverageEnabled = $false
}

Write-Host "`nTest Configuration:" -ForegroundColor Cyan
Write-Host "  Test Path:       $testPath"
Write-Host "  Coverage:        $($CodeCoverageEnabled -eq $true ? 'Enabled' : 'Disabled')"
if ($CodeCoverageEnabled) {
    Write-Host "  Coverage Files:  $($coveragePaths.Count) files"
    Write-Host "  Output Path:     $outputFile"
    Write-Host "  Min Coverage:    $MinimumCoverage%"
}
Write-Host "  Verbosity:       $Verbosity"
Write-Host ""

# Create Pester configuration
$config = New-PesterConfiguration

# Test discovery and execution
$config.Run.Path = $testPath
$config.Run.Exit = $true  # Exit with non-zero code on failure
$config.Run.PassThru = $true  # Return result object

# Test results output
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $repoRoot 'powershell-testresults.xml'
$config.TestResult.OutputFormat = 'NUnitXml'

# Code coverage configuration
if ($CodeCoverageEnabled) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = $coveragePaths
    $config.CodeCoverage.OutputPath = $outputFile
    $config.CodeCoverage.OutputFormat = 'JaCoCo'  # SonarCloud and Codecov compatible
}

# Output verbosity
$config.Output.Verbosity = $Verbosity

# Run tests
Write-Host "Running PowerShell tests..." -ForegroundColor Yellow
$result = Invoke-Pester -Configuration $config

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests:   $($result.TotalCount)"
Write-Host "Passed:        $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:        $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:       $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:      $($result.Duration.TotalSeconds.ToString('F2')) seconds"

if ($CodeCoverageEnabled -and $result.CodeCoverage) {
    $coverage = $result.CodeCoverage
    $coveredCommands = $coverage.CommandsExecutedCount
    $totalCommands = $coverage.CommandsAnalyzedCount
    $coveragePercent = if ($totalCommands -gt 0) {
        [math]::Round(($coveredCommands / $totalCommands) * 100, 2)
    }
    else {
        0
    }

    Write-Host "`nCode Coverage:" -ForegroundColor Cyan
    Write-Host "  Commands Covered: $coveredCommands / $totalCommands"
    Write-Host "  Coverage:         $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge $MinimumCoverage) { 'Green' } else { 'Red' })
    Write-Host "  Report:           $outputFile"

    # Check coverage threshold
    if ($coveragePercent -lt $MinimumCoverage) {
        Write-Warning "Coverage ($coveragePercent%) is below minimum threshold ($MinimumCoverage%)"
        exit 1
    }
}

Write-Host "========================================`n" -ForegroundColor Cyan

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Error "Tests failed. See output above for details."
    exit 1
}

Write-Host "All tests passed successfully!" -ForegroundColor Green
exit 0
