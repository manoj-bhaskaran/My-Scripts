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
                if (Invoke-ZipEntryWrite -Entry $entry -DestinationRootFull $DestinationRootFull -CollisionPolicy $CollisionPolicy) {
                    $written++
                }
            }
        } finally {
            $zip.Dispose()
        }

        return $written

    } catch { Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_ }
}
