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
    Version:        1.2.0
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

# Import logging framework for consistent, capturable output
Import-Module "$PSScriptRoot/../src/powershell/modules/Core/Logging/PowerShellLoggingFramework.psm1" -Force

# Initialize logger at INFO by default
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Resolve and normalise paths
$Source = (Resolve-Path -Path $Source).ProviderPath.TrimEnd('\\')
$Destination = (Resolve-Path -Path $Destination).ProviderPath.TrimEnd('\\')

Write-LogInfo "Sync starting" -Metadata @{ Source = $Source; Destination = $Destination }
if ($ExcludeFromDeletion.Count -gt 0) {
    Write-LogInfo "Exclusions configured" -Metadata @{ Patterns = ($ExcludeFromDeletion -join ', ') }
}

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
    $rel = $f.FullName.Substring($Source.Length).TrimStart('\\')
    $srcIndex[$rel] = $f
}

$dstIndex = @{}
foreach ($f in $dstFiles) {
    $rel = $f.FullName.Substring($Destination.Length).TrimStart('\\')
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

$plan = [PSCustomObject]@{
    Source               = $Source
    Destination          = $Destination
    PreviewOnly          = [bool]$PreviewOnly
    Exclusions           = $ExcludeFromDeletion
    NewFiles             = $toCopyNew.RelativePath
    UpdatedFiles         = $toCopyUpdates.RelativePath
    ToDelete             = $toDelete.RelativePath
    ExcludedFromDeletion = $excludedFiles.RelativePath
}

Write-LogInfo "Planned sync actions" -Metadata @{
    NewFiles   = $toCopyNew.Count
    Updates    = $toCopyUpdates.Count
    Deletions  = $toDelete.Count
    Exclusions = $excludedFiles.Count
}

if ($PreviewOnly) {
    Write-LogInfo "Preview only mode - no changes will be made."
    Write-Output $plan
    return
}

$actionLog = New-Object System.Collections.Generic.List[object]

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

    Write-LogInfo "Copying new file" -Metadata @{ RelativePath = $rel; Destination = $dstPath }
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
    $actionLog.Add([PSCustomObject]@{
            Action       = 'CopyNew'
            RelativePath = $rel
            Destination  = $dstPath
            Status       = 'Success'
        })
}

###############################################################################
# 2. Copy updated files
###############################################################################
foreach ($item in $toCopyUpdates) {
    $rel = $item.RelativePath
    $srcFile = $item.Source
    $dstPath = $item.Destination.FullName

    Write-LogInfo "Copying updated file" -Metadata @{ RelativePath = $rel; Destination = $dstPath }
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
    $actionLog.Add([PSCustomObject]@{
            Action       = 'CopyUpdate'
            RelativePath = $rel
            Destination  = $dstPath
            Status       = 'Success'
        })
}

###############################################################################
# 3. Delete extra files from Destination
###############################################################################
if ($toDelete.Count -gt 0) {
    $confirmation = Read-Host "Delete $($toDelete.Count) file(s) that are not in the source? [Y]es / [N]o (default: No)"

    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        foreach ($item in $toDelete) {
            $rel = $item.RelativePath
            $dstFile = $item.Destination

            Write-LogInfo "Deleting extra file" -Metadata @{ RelativePath = $rel; Destination = $dstFile.FullName }
            Remove-Item -Path $dstFile.FullName -Force
            $actionLog.Add([PSCustomObject]@{
                    Action       = 'Delete'
                    RelativePath = $rel
                    Destination  = $dstFile.FullName
                    Status       = 'Success'
                })
        }

        ###########################################################################
        # 4. Clean up empty directories from Destination
        ###########################################################################
        Write-LogInfo "Cleaning up empty directories"

        # Get all directories in destination, sorted by depth (deepest first)
        $allDirs = Get-ChildItem -Path $Destination -Recurse -Directory |
            Sort-Object { $_.FullName.Split([System.IO.Path]::DirectorySeparatorChar).Count } -Descending

        $emptyDirsRemoved = 0
        foreach ($dir in $allDirs) {
            # Skip if directory matches exclusion pattern
            $relDirPath = $dir.FullName.Substring($Destination.Length).TrimStart('\\')
            if (Test-ExcludedPath -RelativePath $relDirPath -Patterns $ExcludeFromDeletion) {
                continue
            }

            # Check if directory is empty (no files, no subdirectories)
            $contents = Get-ChildItem -Path $dir.FullName -Force
            if ($contents.Count -eq 0) {
                Write-LogInfo "Removing empty directory" -Metadata @{ RelativePath = $relDirPath }
                Remove-Item -Path $dir.FullName -Force
                $emptyDirsRemoved++
                $actionLog.Add([PSCustomObject]@{
                        Action       = 'RemoveDirectory'
                        RelativePath = $relDirPath
                        Status       = 'Success'
                    })
            }
        }

        if ($emptyDirsRemoved -gt 0) {
            Write-LogInfo "Removed empty directories" -Metadata @{ Count = $emptyDirsRemoved }
        }
        else {
            Write-LogInfo "No empty directories to remove"
        }
    }
    else {
        Write-LogWarning "Deletion cancelled by user"
    }
}

$summary = [PSCustomObject]@{
    Source                  = $Source
    Destination             = $Destination
    PreviewOnly             = $false
    Plan                    = $plan
    Actions                 = $actionLog.ToArray()
    DeletedCount            = ($actionLog | Where-Object { $_.Action -eq 'Delete' }).Count
    EmptyDirectoriesRemoved = ($actionLog | Where-Object { $_.Action -eq 'RemoveDirectory' }).Count
    Status                  = 'Complete'
}

Write-LogInfo "Sync complete" -Metadata @{ Actions = $summary.Actions.Count }
Write-Output $summary
