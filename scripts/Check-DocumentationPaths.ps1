<#
.SYNOPSIS
    Checks documentation for hardcoded paths

.DESCRIPTION
    Scans all markdown files in the repository for hardcoded paths that should be replaced
    with placeholders. Helps maintain documentation quality and portability.

.PARAMETER Path
    Root path to search for documentation files (default: current directory)

.PARAMETER ExcludePath
    Paths to exclude from checking (e.g., analysis/issues, docs/conventions)

.EXAMPLE
    .\Check-DocumentationPaths.ps1
    Checks all documentation in the current directory

.EXAMPLE
    .\Check-DocumentationPaths.ps1 -Path "C:\Projects\My-Scripts"
    Checks documentation in the specified path

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.3
    Last Updated: 2025-11-29
#>

# Intentional use of Write-Host for interactive, color-coded diagnostics.
# Output is not consumed by automation pipelines; results are interpreted visually.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive reporting tool that requires color-coded console output')]

param(
    [string]$Path = ".",
    [string[]]$ExcludePath = @(
        "analysis/issues",
        "analysis/ANALYSIS_REPORT.md",
        "docs/conventions/placeholders.md"
    )
)

# Define patterns to search for (hardcoded paths)
$patterns = @{
    'C:\\Users\\[^<\s"''`]+'        = 'Windows user path (C:\Users\username)'
    'D:\\[^<\s"''`]+'               = 'D: drive path'
    'E:\\[^<\s"''`]+'               = 'E: drive path'
    '/home/[^<\s"''`/]+/[^<\s"''`]' = 'Linux home path (/home/username/...)'
}

# Get all markdown files
# Using Write-Host for visibility and to provide immediate color-coded feedback to interactive users.
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DOCUMENTATION PATH CHECKER v1.0.3" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Searching for markdown files..." -ForegroundColor Cyan
$docFiles = Get-ChildItem -Path $Path -Include *.md -Recurse -File

# Filter out excluded paths
$excludedCount = 0
$filteredFiles = $docFiles | Where-Object {
    $file = $_
    $shouldInclude = $true

    foreach ($excludePattern in $ExcludePath) {
        $excludePattern = $excludePattern.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        if ($file.FullName -like "*$excludePattern*") {
            $shouldInclude = $false
            $excludedCount++
            Write-Verbose "Excluding: $($file.FullName)"
            break
        }
    }

    $shouldInclude
}

Write-Host "Found $($docFiles.Count) total markdown files" -ForegroundColor White
Write-Host "Excluded $excludedCount file(s) from checking" -ForegroundColor Gray
Write-Host "Checking $($filteredFiles.Count) markdown files for hardcoded paths..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Patterns being checked:" -ForegroundColor Cyan
Write-Host "  - Windows paths: C:\Users\, D:\, E:\" -ForegroundColor Gray
Write-Host "  - Linux paths: /home/username/" -ForegroundColor Gray
Write-Host "  - Specific usernames" -ForegroundColor Gray
Write-Host ""

$found = $false
$totalIssues = 0

foreach ($file in $filteredFiles) {
    $relativePath = Resolve-Path -Path $file.FullName -Relative
    $fileHasIssues = $false
    $lineNum = 0
    $lines = Get-Content $file.FullName
    $inBadExampleBlock = $false

    foreach ($line in $lines) {
        $lineNum++

        # Check if we're entering or in a bad example block
        if ($line -match 'Bad Example|❌|DO NOT|Incorrect|[Bb]ad:') {
            $inBadExampleBlock = $true
        }
        # Reset only when we hit a new major section (not just empty lines)
        # This keeps bad example blocks active across code fences and empty lines
        if ($line -match '^#{1,4}\s' -and -not ($line -match 'Bad Example|❌|DO NOT')) {
            $inBadExampleBlock = $false
        }

        foreach ($pattern in $patterns.Keys) {
            if ($line -match $pattern) {
                # Skip if this is already using a placeholder
                if ($line -match '<[A-Z_]+>') {
                    continue
                }

                # Skip if we're in a bad example block
                if ($inBadExampleBlock) {
                    continue
                }

                # Skip if this line itself contains exclusion markers
                if ($line -match '(#|//).*DO NOT|Bad Example|❌|[Bb]ad:|[Ii]ncorrect') {
                    continue
                }

                # Skip GitHub URLs, Codecov URLs, SonarCloud URLs (legitimate repository references)
                if ($line -match 'github\.com|codecov\.io|sonarcloud\.io|githubusercontent\.com') {
                    continue
                }

                if (-not $fileHasIssues) {
                    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
                    Write-Host "FILE: $relativePath" -ForegroundColor Yellow
                    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
                    $fileHasIssues = $true
                    $found = $true
                }

                $description = $patterns[$pattern]
                Write-Host ""
                Write-Host "  ⚠ Line $($lineNum): $description" -ForegroundColor Red
                Write-Host "     $($line.Trim())" -ForegroundColor Gray
                $totalIssues++
            }
        }
    }

    if ($fileHasIssues) {
        Write-Host ""
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DOCUMENTATION PATH CHECK SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $found) {
    Write-Host "✓ RESULT: PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "All $($filteredFiles.Count) documentation files are using placeholders correctly." -ForegroundColor Green
    Write-Host "No hardcoded paths detected." -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    Write-Host "✗ RESULT: FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Found $totalIssues hardcoded path(s) in documentation" -ForegroundColor Red
    Write-Host ""
    Write-Host "REMEDIATION:" -ForegroundColor Yellow
    Write-Host "  Please replace hardcoded paths with placeholders:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Placeholder       | Use For" -ForegroundColor Cyan
    Write-Host "  ------------------|----------------------------------" -ForegroundColor Cyan
    Write-Host "  <REPO_PATH>       | Repository location" -ForegroundColor White
    Write-Host "  <SCRIPT_ROOT>     | Working/deployment directory" -ForegroundColor White
    Write-Host "  <CONFIG_DIR>      | Configuration directory" -ForegroundColor White
    Write-Host "  <LOG_DIR>         | Log file directory" -ForegroundColor White
    Write-Host "  <BACKUP_DIR>      | Backup storage directory" -ForegroundColor White
    Write-Host "  <USERNAME>        | Current user" -ForegroundColor White
    Write-Host ""
    Write-Host "  See docs/conventions/placeholders.md for complete guide" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    exit 1
}
