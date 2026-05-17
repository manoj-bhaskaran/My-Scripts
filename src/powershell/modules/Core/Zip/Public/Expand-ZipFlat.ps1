using namespace System.IO.Compression

<#
.SYNOPSIS
    Streams one ZIP archive directly into the destination root (flat mode).
.DESCRIPTION
    Implements Flat extraction mode using ZipArchive streaming extraction:
    - Normalizes each entry path and enforces a destination-root prefix check (Zip Slip protection).
    - Applies per-file collision policy (Skip, Overwrite, Rename) before writing each entry.
    - Creates required destination subdirectories on demand.
    - Skips directory entries (entries whose Name is empty).
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder for extraction.
.PARAMETER DestinationRootFull
    Fully-qualified destination root path used for Zip Slip boundary validation.
.PARAMETER CollisionPolicy
    File collision behavior: Skip, Overwrite, or Rename (default Rename).
.OUTPUTS
    Int (number of files successfully extracted).
#>
function Expand-ZipFlat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$DestinationRootFull,
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename'
    )

    $written = 0

    try {
        $zip = [ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                if ([string]::IsNullOrEmpty($entry.Name)) { continue }
                if ($entry.FullName.Contains('..') -or $entry.FullName -match '(^|[\\/])\.\.([\\/]|$)') {
                    Write-LogDebug "Skipped traversal-segment entry: $($entry.FullName)"
                    continue
                }

                $destFull = Resolve-ZipEntryDestinationPath -DestinationRootFull $DestinationRootFull -EntryFullName $entry.FullName
                if ($null -eq $destFull) {
                    Write-LogDebug "Skipped path traversal: $($entry.FullName)"
                    continue
                }

                $destDir = Split-Path -Path $destFull -Parent
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-DirectoryIfMissing -Path $destDir -Force | Out-Null
                }

                $targetPath = $destFull
                if ([System.IO.File]::Exists($targetPath)) {
                    switch ($CollisionPolicy) {
                        'Skip'      { continue }
                        'Rename'    { $targetPath = Resolve-UniquePath -Path $targetPath }
                        'Overwrite' { }
                    }
                }

                try {
                    [ZipFileExtensions]::ExtractToFile($entry, $targetPath, ($CollisionPolicy -eq 'Overwrite'))
                    $written++
                } catch {
                    # Defensive fallback: if a race or path normalization mismatch causes
                    # a late "already exists" exception under Skip policy, honor Skip.
                    if ($CollisionPolicy -eq 'Skip' -and $_.Exception.Message -imatch 'already exists') { continue }
                    Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_
                }
            }
        } finally {
            $zip.Dispose()
        }

        return $written

    } catch { Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_ }
}
