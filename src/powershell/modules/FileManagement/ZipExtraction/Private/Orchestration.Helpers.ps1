function Merge-ParallelZipResults {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList,
        [Parameter(Mandatory)][System.Collections.Concurrent.ConcurrentBag[string]]$ConcurrentErrors
    )
    $processedZips           = 0
    $totalFilesExtracted     = 0
    $totalUncompressedBytes  = [int64]0
    $totalCompressedZipBytes = [int64]0
    $processedZipPaths       = [System.Collections.Generic.List[string]]::new()

    foreach ($r in $Results) {
        foreach ($log in $r.Logs) { Write-LogDebug $log }
        if ($r.Success) {
            $processedZips++
            $totalFilesExtracted     += $r.FilesExtracted
            $totalUncompressedBytes  += $r.UncompressedBytes
            $totalCompressedZipBytes += $r.CompressedBytes
            if ($r.ZipPath) { $processedZipPaths.Add($r.ZipPath) | Out-Null }
        }
    }
    foreach ($e in $ConcurrentErrors) { $ErrorList.Add($e) | Out-Null }
    Write-LogInfo "Parallel extraction complete: $processedZips / $ZipCount archive(s) processed."
    return New-ExtractionSummary -ZipCount $ZipCount -ProcessedZips $processedZips -FilesExtracted $totalFilesExtracted -UncompressedBytes $totalUncompressedBytes -CompressedBytes $totalCompressedZipBytes -ProcessedZipPaths $processedZipPaths.ToArray()
}
