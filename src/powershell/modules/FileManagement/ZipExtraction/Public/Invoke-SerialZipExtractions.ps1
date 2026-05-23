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

    foreach ($zip in $Zips) {
        $index++
        try {
            Show-ProgressPhase -Activity "Extracting archives" -Status $zip.Name -Current ($index - 1) -Total $ZipCount -QuietMode $QuietMode
            if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                $stats = Get-ZipFileStats -ZipPath $zip.FullName
                $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName -DestinationRoot $DestinationDir -ExtractMode $Mode -CollisionPolicy $Policy -SafeNameMaxLen $SafeNameMaxLen -ExpectedFileCount $stats.FileCount
                if ($filesFromZip -is [int]) { $totalFilesExtracted += $filesFromZip } else { $totalFilesExtracted += $stats.FileCount }
                $totalUncompressedBytes += $stats.UncompressedBytes; $totalCompressedZipBytes += $stats.CompressedBytes; $processedZips++
                Write-LogDebug "Extracted '$($zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)"
            }
        } catch { $msg = $_.Exception.Message; $ErrorList.Add("Extraction failed for '$($zip.FullName)': $msg") | Out-Null; Write-LogDebug $msg }
    }

    Show-ProgressPhase -Activity "Extracting archives" -Status "Done" -Current $ZipCount -Total $ZipCount -QuietMode $QuietMode -Completed
    return New-ExtractionSummary -ZipCount $ZipCount -ProcessedZips $processedZips -FilesExtracted $totalFilesExtracted -UncompressedBytes $totalUncompressedBytes -CompressedBytes $totalCompressedZipBytes
}
