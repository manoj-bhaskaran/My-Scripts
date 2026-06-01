function Invoke-SerialZipExtractions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.IO.FileInfo[]]$Zips, [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][string]$DestinationDir, [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy, [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode, [Parameter(Mandatory)][int]$ThrottleLimit,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    if ($ThrottleLimit -gt 1 -and $WhatIfPreference) { Write-Verbose "WhatIf is active — falling back to serial extraction so -WhatIf/-Confirm are honoured." }
    $processedZips = 0; $totalFilesExtracted = 0; $totalUncompressedBytes = [int64]0; $totalCompressedZipBytes = [int64]0; $index = 0
    $processedZipPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($zip in $Zips) {
        $index++
        try {
            Show-ProgressPhase -Activity "Extracting archives" -Status $zip.Name -Current ($index - 1) -Total $ZipCount -QuietMode $QuietMode
            if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                $r = Invoke-SingleZipExtraction -Zip $zip -DestDir $DestinationDir -Mode $Mode -Policy $Policy -MaxLen $SafeNameMaxLen
                $totalFilesExtracted += $r.FilesExtracted
                $totalUncompressedBytes += $r.UncompressedBytes; $totalCompressedZipBytes += $r.CompressedBytes; $processedZips++
                $processedZipPaths.Add($zip.FullName) | Out-Null
                Write-LogDebug $r.Log
            }
        } catch { $msg = $_.Exception.Message; $ErrorList.Add("Extraction failed for '$($zip.FullName)': $msg") | Out-Null; Write-LogDebug $msg }
    }

    Show-ProgressPhase -Activity "Extracting archives" -Status "Done" -Current $ZipCount -Total $ZipCount -QuietMode $QuietMode -Completed
    return New-ExtractionSummary -ZipCount $ZipCount -ProcessedZips $processedZips -FilesExtracted $totalFilesExtracted -UncompressedBytes $totalUncompressedBytes -CompressedBytes $totalCompressedZipBytes -ProcessedZipPaths $processedZipPaths.ToArray()
}
