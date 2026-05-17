<#
.SYNOPSIS
    Extracts one ZIP archive into a safe, unique subfolder under the destination root.
.DESCRIPTION
    Implements PerArchiveSubfolder extraction mode using Expand-Archive.
    The target subfolder is derived from SafeSubfolderName; if a folder with that name
    already exists, Resolve-UniqueDirectoryPath generates a timestamped alternative.
    Returns ExpectedFileCount directly so callers avoid a redundant post-extraction walk.
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder under which the subfolder is created.
.PARAMETER SafeSubfolderName
    Safe destination subfolder name derived from the zip file name.
.PARAMETER ExpectedFileCount
    Pre-computed file count from Get-ZipFileStats. Returned without re-opening the archive.
.OUTPUTS
    Int ($ExpectedFileCount as supplied by the caller).
#>
function Expand-ZipToSubfolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$SafeSubfolderName,
        [Parameter(Mandatory)][int]$ExpectedFileCount
    )

    try {
        $target = Join-Path $DestinationRoot $SafeSubfolderName
        $target = Resolve-UniqueDirectoryPath -Path $target
        if (-not (Test-Path -LiteralPath $target)) {
            New-DirectoryIfMissing -Path $target -Force | Out-Null
        }

        Expand-Archive -LiteralPath $ZipPath -DestinationPath $target -Force
        Write-LogDebug "Expand-ZipToSubfolder: '$($ZipPath | Split-Path -Leaf)' -> '$target' ($ExpectedFileCount file(s) per archive manifest)"
        return $ExpectedFileCount

    } catch { Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_ }
}
