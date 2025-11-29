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
    Version: 1.0.0
    Last Updated: 2025-11-29
#>

param(
    [string]$Path = ".",
    [string[]]$ExcludePath = @("analysis/issues", "docs/conventions/placeholders.md")
)

# Define patterns to search for (hardcoded paths)
$patterns = @{
    'C:\\Users\\[^<\s"''`]+'       = 'Windows user path (C:\Users\username)'
    'D:\\[^<\s"''`]+'               = 'D: drive path'
    'E:\\[^<\s"''`]+'               = 'E: drive path'
    '/home/[^<\s"''`/]+/[^<\s"''`]' = 'Linux home path (/home/username/...)'
    '\bmanoj\b'                     = 'Specific username (manoj)'
}

# Get all markdown files
Write-Host "Searching for markdown files..." -ForegroundColor Cyan
$docFiles = Get-ChildItem -Path $Path -Include *.md -Recurse -File

# Filter out excluded paths
$filteredFiles = $docFiles | Where-Object {
    $file = $_
    $shouldInclude = $true

    foreach ($excludePattern in $ExcludePath) {
        $excludePattern = $excludePattern.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        if ($file.FullName -like "*$excludePattern*") {
            $shouldInclude = $false
            Write-Verbose "Excluding: $($file.FullName)"
            break
        }
    }

    $shouldInclude
}

Write-Host "Checking $($filteredFiles.Count) markdown files for hardcoded paths..." -ForegroundColor Cyan
Write-Host ""

$found = $false
$totalIssues = 0

foreach ($file in $filteredFiles) {
    $relativePath = Resolve-Path -Path $file.FullName -Relative
    $fileHasIssues = $false
    $lineNum = 0

    foreach ($line in (Get-Content $file.FullName)) {
        $lineNum++

        foreach ($pattern in $patterns.Keys) {
            if ($line -match $pattern) {
                # Skip if this is already using a placeholder
                if ($line -match '<[A-Z_]+>') {
                    continue
                }

                # Skip if this is in a code block showing bad examples
                if ($line -match '(#|//).*DO NOT|Bad Example|❌|[Bb]ad:|[Ii]ncorrect') {
                    continue
                }

                if (-not $fileHasIssues) {
                    Write-Host "$relativePath" -ForegroundColor Yellow
                    $fileHasIssues = $true
                    $found = $true
                }

                $description = $patterns[$pattern]
                Write-Host "  Line $lineNum - $description" -ForegroundColor Red
                Write-Host "    $line" -ForegroundColor Gray
                $totalIssues++
            }
        }
    }

    if ($fileHasIssues) {
        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
if (-not $found) {
    Write-Host "✓ No hardcoded paths found in documentation" -ForegroundColor Green
    Write-Host ""
    Write-Host "All documentation files are using placeholders correctly." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Found $totalIssues hardcoded path(s) in documentation" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please replace hardcoded paths with placeholders:" -ForegroundColor Yellow
    Write-Host "  - Use <REPO_PATH> for repository location" -ForegroundColor Yellow
    Write-Host "  - Use <SCRIPT_ROOT> for working/deployment directory" -ForegroundColor Yellow
    Write-Host "  - Use <USERNAME> for usernames" -ForegroundColor Yellow
    Write-Host "  - See docs/conventions/placeholders.md for complete guide" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
