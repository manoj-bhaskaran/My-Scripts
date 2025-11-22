<#
.SYNOPSIS
    Synchronizes files from a source directory to a destination directory with exclusion support.

.DESCRIPTION
    This script performs a one-way sync from source to destination, with support for
    excluding specific patterns from deletion. It's designed for syncing a Git repository
    to a working directory while preserving non-repository files (logs, configs, venvs, etc.).

.PARAMETER Source
    The source directory path (e.g., Git repository directory).

.PARAMETER Destination
    The destination directory path (e.g., working copy directory).

.PARAMETER ExcludeFromDeletion
    Array of glob patterns for files/directories to exclude from deletion.
    These patterns are matched against the relative path from the destination root.
    Examples: ".venv", "*.log", "logs/*", "temp", "venv", "backups/*"

.PARAMETER PreviewOnly
    If set, shows what would happen without making any changes.

.EXAMPLE
    .\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts" -PreviewOnly
    Preview changes without making modifications.

.EXAMPLE
    .\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts" -ExcludeFromDeletion @(".venv", "venv", "logs", "temp", "*.log", "backups")
    Sync directories while preserving specified patterns from deletion.

.NOTES
    Version:        1.1.0
    Author:         Manoj Bhaskaran
    Creation Date:  2025-11-22
    Purpose:        One-way directory synchronization with exclusion support

.LINK
    https://github.com/manoj-bhaskaran/My-Scripts
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFromDeletion = @(),

    # If set, only show what *would* happen, don't change anything
    [switch]$PreviewOnly
)

# Resolve and normalise paths
$Source = (Resolve-Path -Path $Source).ProviderPath.TrimEnd('\')
$Destination = (Resolve-Path -Path $Destination).ProviderPath.TrimEnd('\')

Write-Host "Source     : $Source"
Write-Host "Destination: $Destination"
if ($ExcludeFromDeletion.Count -gt 0) {
    Write-Host "Exclusions : $($ExcludeFromDeletion -join ', ')"
}
Write-Host ""

# Helper function to check if a path matches any exclusion pattern
function Test-ExcludedPath {
    param(
        [string]$RelativePath,
        [string[]]$Patterns
    )

    if ($Patterns.Count -eq 0) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        # Normalize pattern separators to match current OS
        $normalizedPattern = $pattern -replace '[/\\]', [System.IO.Path]::DirectorySeparatorChar

        # Check for exact match
        if ($RelativePath -eq $normalizedPattern) {
            return $true
        }

        # Check if path starts with pattern (for directory matches)
        $patternWithSep = $normalizedPattern.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if ($RelativePath.StartsWith($patternWithSep, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        # Check for wildcard match
        if ($normalizedPattern -like '*[*?]*') {
            if ($RelativePath -like $normalizedPattern) {
                return $true
            }
        }
    }

    return $false
}

# Get all files from both trees
$srcFiles = Get-ChildItem -Path $Source      -Recurse -File
$dstFiles = Get-ChildItem -Path $Destination -Recurse -File

# Index by relative path (same key for source & destination)
$srcIndex = @{}
foreach ($f in $srcFiles) {
    $rel = $f.FullName.Substring($Source.Length).TrimStart('\')
    $srcIndex[$rel] = $f
}

$dstIndex = @{}
foreach ($f in $dstFiles) {
    $rel = $f.FullName.Substring($Destination.Length).TrimStart('\')
    $dstIndex[$rel] = $f
}

$toCopyNew = New-Object System.Collections.Generic.List[object]
$toCopyUpdates = New-Object System.Collections.Generic.List[object]
$toDelete = New-Object System.Collections.Generic.List[object]

# Determine new and updated files (Source → Destination)
foreach ($relPath in $srcIndex.Keys) {
    $srcFile = $srcIndex[$relPath]
    if (-not $dstIndex.ContainsKey($relPath)) {
        # Exists only in source → new file to copy
        $toCopyNew.Add([PSCustomObject]@{
                RelativePath = $relPath
                Source       = $srcFile
            })
    }
    else {
        $dstFile = $dstIndex[$relPath]
        # Compare by LastWriteTimeUtc and length (simple heuristic)
        if ($srcFile.LastWriteTimeUtc -ne $dstFile.LastWriteTimeUtc -or
            $srcFile.Length -ne $dstFile.Length) {

            $toCopyUpdates.Add([PSCustomObject]@{
                    RelativePath = $relPath
                    Source       = $srcFile
                    Destination  = $dstFile
                })
        }
    }
}

# Determine files present only in Destination → candidates for deletion
$excludedFiles = New-Object System.Collections.Generic.List[object]
foreach ($relPath in $dstIndex.Keys) {
    if (-not $srcIndex.ContainsKey($relPath)) {
        # Check if this path matches any exclusion pattern
        if (Test-ExcludedPath -RelativePath $relPath -Patterns $ExcludeFromDeletion) {
            $excludedFiles.Add([PSCustomObject]@{
                    RelativePath = $relPath
                    Destination  = $dstIndex[$relPath]
                })
        }
        else {
            $toDelete.Add([PSCustomObject]@{
                    RelativePath = $relPath
                    Destination  = $dstIndex[$relPath]
                })
        }
    }
}

Write-Host "Planned actions:"
Write-Host "  New files     to copy   : $($toCopyNew.Count)"
Write-Host "  Updated files to copy   : $($toCopyUpdates.Count)"
Write-Host "  Extra files   to delete : $($toDelete.Count)"
if ($excludedFiles.Count -gt 0) {
    Write-Host "  Files excluded from del.: $($excludedFiles.Count)" -ForegroundColor Yellow
}
Write-Host ""

if ($PreviewOnly) {
    Write-Host "Preview only mode - no changes will be made."
    Write-Host ""

    if ($toCopyNew.Count -gt 0) {
        Write-Host "=== New files to be copied ==="
        $toCopyNew | ForEach-Object {
            Write-Host "[NEW]     $($_.RelativePath)"
        }
        Write-Host ""
    }

    if ($toCopyUpdates.Count -gt 0) {
        Write-Host "=== Files to be updated ==="
        $toCopyUpdates | ForEach-Object {
            Write-Host "[UPDATE]  $($_.RelativePath)"
        }
        Write-Host ""
    }

    if ($toDelete.Count -gt 0) {
        Write-Host "=== Files that would be deleted from Destination ==="
        $toDelete | ForEach-Object {
            Write-Host "[DELETE]  $($_.RelativePath)"
        }
        Write-Host ""
    }

    if ($excludedFiles.Count -gt 0) {
        Write-Host "=== Files excluded from deletion (preserved in Destination) ===" -ForegroundColor Yellow
        Write-Host "Total: $($excludedFiles.Count) files will be preserved (matching exclusion patterns)" -ForegroundColor Yellow
        Write-Host ""
    }

    return
}

###############################################################################
# 1. Copy new files
###############################################################################
foreach ($item in $toCopyNew) {
    $rel = $item.RelativePath
    $srcFile = $item.Source
    $dstPath = Join-Path -Path $Destination -ChildPath $rel

    $dstDir = Split-Path -Path $dstPath -Parent
    if (-not (Test-Path -Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "[COPY NEW] $rel"
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
}

###############################################################################
# 2. Copy updated files
###############################################################################
foreach ($item in $toCopyUpdates) {
    $rel = $item.RelativePath
    $srcFile = $item.Source
    $dstPath = $item.Destination.FullName

    Write-Host "[COPY UPDATE] $rel"
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
}

###############################################################################
# 3. Delete extra files from Destination
###############################################################################
if ($toDelete.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Deletion Confirmation ===" -ForegroundColor Yellow
    Write-Host "The following $($toDelete.Count) file(s) will be deleted:" -ForegroundColor Yellow
    $toDelete | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $($_.RelativePath)" -ForegroundColor Yellow
    }
    if ($toDelete.Count -gt 10) {
        Write-Host "  ... and $($toDelete.Count - 10) more files" -ForegroundColor Yellow
    }
    Write-Host ""

    $confirmation = Read-Host "Delete these files? [Y]es / [N]o (default: No)"

    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        foreach ($item in $toDelete) {
            $rel = $item.RelativePath
            $dstFile = $item.Destination

            Write-Host "[DELETE] $rel"
            Remove-Item -Path $dstFile.FullName -Force
        }
        Write-Host "Deleted $($toDelete.Count) file(s)." -ForegroundColor Green
    }
    else {
        Write-Host "Deletion cancelled. No files were deleted." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Sync complete."
