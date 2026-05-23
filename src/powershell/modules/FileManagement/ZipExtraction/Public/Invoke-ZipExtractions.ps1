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

    $zips = @(Get-ChildItem -LiteralPath $SourceDir -Filter '*.zip' -File -ErrorAction Stop)
    $zipCount = $zips.Count

    Write-LogInfo ("Found {0} zip file(s) in: {1}" -f $zipCount, $SourceDir)
    Write-LogInfo ("Extracting to: {0} (Mode: {1}, Policy: {2})" -f $DestinationDir, $Mode, $Policy)

    if ($zipCount -lt 1) {
        return New-ExtractionSummary -ZipCount 0 -ProcessedZips 0 -FilesExtracted 0 -UncompressedBytes 0L -CompressedBytes 0L
    }

    $dispatch = @{
        Zips           = $zips
        ZipCount       = $zipCount
        DestinationDir = $DestinationDir
        Mode           = $Mode
        Policy         = $Policy
        SafeNameMaxLen = $SafeNameMaxLen
        QuietMode      = $QuietMode
        ThrottleLimit  = $ThrottleLimit
        ErrorList      = $ErrorList
    }

    $canParallel = ($ThrottleLimit -gt 1) -and (-not $WhatIfPreference)
    $runner = if ($canParallel) { 'Invoke-ParallelZipExtractions' } else { 'Invoke-SerialZipExtractions' }
    return & $runner @dispatch
}
