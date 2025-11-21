<#
.SYNOPSIS
    Formats all PowerShell scripts using PSScriptAnalyzer

.DESCRIPTION
    This script formats all PowerShell scripts in the repository according to
    consistent coding standards using Invoke-Formatter from PSScriptAnalyzer.

.PARAMETER Check
    When specified, only checks formatting without modifying files.
    Returns exit code 1 if any files need formatting.

.PARAMETER Path
    The path to format. Defaults to src/powershell and tests/powershell directories.

.EXAMPLE
    .\scripts\Format-PowerShellCode.ps1
    Formats all PowerShell files in the repository

.EXAMPLE
    .\scripts\Format-PowerShellCode.ps1 -Check
    Checks if any files need formatting without modifying them

.EXAMPLE
    .\scripts\Format-PowerShellCode.ps1 -Path src/powershell/system
    Formats only files in the specified directory
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Check only, don't modify files")]
    [switch]$Check,

    [Parameter(HelpMessage = "Path to format (defaults to src/powershell and tests/powershell)")]
    [string]$Path
)

# Ensure PSScriptAnalyzer is installed
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Error "PSScriptAnalyzer module is not installed. Install it with: Install-Module -Name PSScriptAnalyzer -Force"
    exit 1
}

Import-Module PSScriptAnalyzer

# Define formatting settings
$settings = @{
    IncludeRules = @(
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSAlignAssignmentStatement',
        'PSUseCorrectCasing'
    )
    Rules        = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace  = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing         = @{
            Enable = $true
        }
    }
}

# Determine which files to process
$searchPaths = if ($Path) {
    @($Path)
}
else {
    @(
        'src/powershell',
        'tests/powershell',
        'scripts'
    )
}

$files = @()
foreach ($searchPath in $searchPaths) {
    if (Test-Path $searchPath) {
        $files += Get-ChildItem -Path $searchPath -Recurse -Include *.ps1, *.psm1 -ErrorAction SilentlyContinue
    }
}

if ($files.Count -eq 0) {
    Write-Warning "No PowerShell files found to format"
    exit 0
}

Write-Host "Found $($files.Count) PowerShell files to process" -ForegroundColor Cyan

$needsFormatting = @()
$formattedCount = 0
$errorCount = 0

foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Verbose "Skipping empty file: $($file.FullName)"
            continue
        }

        # Format the content
        $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $settings -ErrorAction Stop

        # Compare original and formatted content
        if ($content -ne $formatted) {
            $needsFormatting += $file

            if ($Check) {
                Write-Host "  [NEEDS FORMATTING] $($file.FullName)" -ForegroundColor Yellow
            }
            else {
                # Write formatted content back to file
                Set-Content -Path $file.FullName -Value $formatted -NoNewline -ErrorAction Stop
                Write-Host "  [FORMATTED] $($file.FullName)" -ForegroundColor Green
                $formattedCount++
            }
        }
        else {
            Write-Verbose "File already formatted: $($file.FullName)"
        }
    }
    catch {
        Write-Error "Error processing file $($file.FullName): $_"
        $errorCount++
    }
}

# Summary
Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "Total files processed: $($files.Count)"

if ($Check) {
    Write-Host "Files needing formatting: $($needsFormatting.Count)" -ForegroundColor $(if ($needsFormatting.Count -gt 0) { 'Yellow' } else { 'Green' })

    if ($needsFormatting.Count -gt 0) {
        Write-Host "`nRun without -Check to format these files" -ForegroundColor Yellow
        exit 1
    }
    else {
        Write-Host "All files are properly formatted!" -ForegroundColor Green
        exit 0
    }
}
else {
    Write-Host "Files formatted: $formattedCount" -ForegroundColor Green
    Write-Host "Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })

    if ($errorCount -gt 0) {
        exit 1
    }
    exit 0
}
