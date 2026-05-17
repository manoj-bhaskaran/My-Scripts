<#
.SYNOPSIS
    Resolves a ZipArchive entry to a destination path and blocks path traversal (Zip Slip).
.DESCRIPTION
    Validates every archive entry before extraction:
    - Rejects null/whitespace names.
    - Rejects rooted/archive-absolute inputs (Unix /, Windows \, drive letters, UNC prefixes).
    - Normalizes separators and rejects any '..' traversal segment.
    - Computes the canonical destination path and confirms it is strictly inside DestinationRootFull.
    Returns $null for any entry that fails validation; returns the full destination path otherwise.
.PARAMETER DestinationRootFull
    Fully-qualified destination root path (used as the containment boundary).
.PARAMETER EntryFullName
    The archive entry's FullName property (relative path inside the archive).
.OUTPUTS
    [string] Absolute destination path, or $null if the entry is unsafe.
#>
function Resolve-ZipEntryDestinationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DestinationRootFull,
        [Parameter(Mandatory)][string]$EntryFullName
    )

    if ([string]::IsNullOrWhiteSpace($EntryFullName)) { return $null }

    # Reject rooted/archive-absolute inputs before normalization/trimming.
    if (
        $EntryFullName.StartsWith('/') -or
        $EntryFullName.StartsWith('\') -or
        $EntryFullName -match '^[A-Za-z]:[\\/]' -or
        $EntryFullName.StartsWith('//') -or
        $EntryFullName.StartsWith('\\')
    ) {
        return $null
    }

    # Normalize separators and explicitly reject traversal segments.
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
    $normalizedEntry = ($EntryFullName -replace '\\', '/')
    $segments = @($normalizedEntry -split '/+' | Where-Object { $_ -ne '' -and $_ -ne '.' })
    if ($segments.Count -eq 0) { return $null }
    if (@($segments | Where-Object { $_ -eq '..' }).Count -gt 0) { return $null }

    $relativePath = ($segments -join [string]$directorySeparator)
    if ([System.IO.Path]::IsPathRooted($relativePath)) { return $null }

    # Compute canonical paths from fully-qualified roots to compare like-for-like.
    $rootFull = [System.IO.Path]::GetFullPath($DestinationRootFull)
    $candidate = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($rootFull, $relativePath))
    $rootWithSep = if ($rootFull.EndsWith($directorySeparator)) { $rootFull } else { $rootFull + $directorySeparator }
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }

    if ($candidate.StartsWith($rootWithSep, $comparison)) {
        return $candidate
    }

    return $null
}
