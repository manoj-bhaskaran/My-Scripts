function Invoke-ZipExtractions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList,
        [int]$ThrottleLimit = 1
    )
    $zips = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File -ErrorAction Stop)
    $zipCount = $zips.Count
    Write-LogInfo "Found $zipCount zip file(s) in: $SourceDir"
    Write-LogInfo "Extracting to: $DestinationDir (Mode: $Mode, Policy: $Policy)"
    if ($zipCount -eq 0) { return New-ExtractionSummary -ZipCount 0 -ProcessedZips 0 -FilesExtracted 0 -UncompressedBytes ([int64]0) -CompressedBytes ([int64]0) }

    $sharedParams = @{ Zips=$zips; ZipCount=$zipCount; DestinationDir=$DestinationDir; Mode=$Mode; Policy=$Policy; SafeNameMaxLen=$SafeNameMaxLen; QuietMode=$QuietMode; ThrottleLimit=$ThrottleLimit; ErrorList=$ErrorList }
    if ($ThrottleLimit -gt 1 -and -not $WhatIfPreference) { return Invoke-ParallelZipExtractions @sharedParams }
    return Invoke-SerialZipExtractions @sharedParams
}
