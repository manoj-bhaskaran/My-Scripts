using namespace System.IO.Compression

<#
.SYNOPSIS
    Writes a single ZIP entry to disk, applying collision policy and Zip Slip protection.
.DESCRIPTION
    Validates and writes one ZipArchiveEntry to the destination root.
    Returns $true if the entry was written, $false if it was skipped.
.PARAMETER Entry
    The ZipArchiveEntry to extract.
.PARAMETER DestinationRootFull
    Fully-qualified destination root path used for Zip Slip boundary validation.
.PARAMETER CollisionPolicy
    File collision behavior: Skip, Overwrite, or Rename (default Rename).
.OUTPUTS
    Boolean ($true = written, $false = skipped).
#>
function Invoke-ZipEntryWrite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.IO.Compression.ZipArchiveEntry]$Entry,
        [Parameter(Mandatory)][string]$DestinationRootFull,
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename'
    )

    if ([string]::IsNullOrEmpty($Entry.Name)) { return $false }
    if ($Entry.FullName -match '(^|[\\/])\.\.([\\/]|$)') {
        Write-LogDebug "Skipped traversal-segment entry: $($Entry.FullName)"
        return $false
    }

    $destFull = Resolve-ZipEntryDestinationPath -DestinationRootFull $DestinationRootFull -EntryFullName $Entry.FullName
    if ($null -eq $destFull) {
        Write-LogDebug "Skipped path traversal: $($Entry.FullName)"
        return $false
    }

    $destDir = Split-Path -Path $destFull -Parent
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-DirectoryIfMissing -Path $destDir -Force | Out-Null
    }

    $targetPath = $destFull
    if ([System.IO.File]::Exists($targetPath)) {
        switch ($CollisionPolicy) {
            'Skip'      { return $false }
            'Rename'    { $targetPath = Resolve-UniquePath -Path $targetPath }
            'Overwrite' { }
        }
    }

    try {
        [ZipFileExtensions]::ExtractToFile($Entry, $targetPath, ($CollisionPolicy -eq 'Overwrite'))
        return $true
    } catch {
        # Defensive fallback: if a race or path normalization mismatch causes
        # a late "already exists" exception under Skip policy, honor Skip.
        if ($CollisionPolicy -eq 'Skip' -and $_.Exception.Message -imatch 'already exists') { return $false }
        throw $_
    }
}
