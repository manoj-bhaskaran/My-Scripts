<#
.SYNOPSIS
    Dispatches zip extraction to the configured extraction mode helper.
.DESCRIPTION
    Routes extraction to either Expand-ZipToSubfolder (PerArchiveSubfolder mode) or
    Expand-ZipFlat (Flat mode). Computes a safe subfolder name and the fully-qualified
    destination root before delegating to the selected helper.
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder for extraction.
.PARAMETER ExtractMode
    PerArchiveSubfolder (default) or Flat.
.PARAMETER CollisionPolicy
    Skip | Overwrite | Rename (default Rename). Applied in Flat mode per-file.
.PARAMETER SafeNameMaxLen
    Maximum safe-name length for per-archive subfolder names (0 = no limit).
.PARAMETER ExpectedFileCount
    Pre-computed file count from Get-ZipFileStats. Pass when available to avoid
    a second archive open in PerArchiveSubfolder mode (default 0 = compute internally).
.OUTPUTS
    Int (number of files written by the selected mode helper).
#>
function Expand-ZipSmart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [ValidateSet('PerArchiveSubfolder', 'Flat')][string]$ExtractMode = 'PerArchiveSubfolder',
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename',
        [int]$SafeNameMaxLen = 0,
        [int]$ExpectedFileCount = 0
    )

    if (-not (Test-Path -LiteralPath $DestinationRoot)) {
        New-DirectoryIfMissing -Path $DestinationRoot -Force | Out-Null
    }

    $destRootFull = Get-FullPath -Path $DestinationRoot
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
    $safeSub = Get-SafeName -Name $baseName -MaxLength $SafeNameMaxLen

    if ($ExtractMode -eq 'PerArchiveSubfolder') {
        # Callers that pre-compute stats pass ExpectedFileCount > 0 to avoid a
        # second zip open; fall back to Get-ZipFileStats when omitted (default 0).
        if ($ExpectedFileCount -le 0) {
            $ExpectedFileCount = (Get-ZipFileStats -ZipPath $ZipPath).FileCount
        }
        return Expand-ZipToSubfolder -ZipPath $ZipPath -DestinationRoot $DestinationRoot -SafeSubfolderName $safeSub -ExpectedFileCount $ExpectedFileCount
    }

    return Expand-ZipFlat -ZipPath $ZipPath -DestinationRoot $DestinationRoot -DestinationRootFull $destRootFull -CollisionPolicy $CollisionPolicy
}
