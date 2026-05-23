function Invoke-SingleZipExtraction {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$Zip,
        [Parameter(Mandatory)][string]$DestDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$MaxLen
    )

    $stats        = Get-ZipFileStats -ZipPath $Zip.FullName
    $filesFromZip = Expand-ZipSmart -ZipPath $Zip.FullName -DestinationRoot $DestDir -ExtractMode $Mode -CollisionPolicy $Policy -SafeNameMaxLen $MaxLen -ExpectedFileCount $stats.FileCount
    $actualFiles  = if ($filesFromZip -is [int]) { $filesFromZip } else { $stats.FileCount }

    return [pscustomobject]@{
        FilesExtracted    = $actualFiles
        UncompressedBytes = $stats.UncompressedBytes
        CompressedBytes   = $stats.CompressedBytes
        Log               = "Extracted '$($Zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)"
    }
}
