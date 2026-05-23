function Expand-ZipInRunspace {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$Zip,
        [Parameter(Mandatory)][string]$DestDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$MaxLen,
        [string]$FsModulePath,
        [string]$ZipModulePath,
        [Parameter(Mandatory)][System.Collections.Concurrent.ConcurrentBag[string]]$ErrorBag
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    if ($FsModulePath) { Import-Module $FsModulePath -Force }
    if ($ZipModulePath) { Import-Module $ZipModulePath -Force }

    $localLogs = [System.Collections.Generic.List[string]]::new()
    try {
        $stats = Get-ZipFileStats -ZipPath $Zip.FullName
        $filesFromZip = Expand-ZipSmart -ZipPath $Zip.FullName -DestinationRoot $DestDir -ExtractMode $Mode -CollisionPolicy $Policy -SafeNameMaxLen $MaxLen -ExpectedFileCount $stats.FileCount
        $actualFiles = if ($filesFromZip -is [int]) { $filesFromZip } else { $stats.FileCount }
        $localLogs.Add("Extracted '$($Zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)") | Out-Null

        return [pscustomobject]@{
            Success           = $true
            FilesExtracted    = $actualFiles
            UncompressedBytes = $stats.UncompressedBytes
            CompressedBytes   = $stats.CompressedBytes
            Logs              = $localLogs.ToArray()
        }
    } catch {
        $ErrorBag.Add("Extraction failed for '$($Zip.FullName)': $($_.Exception.Message)") | Out-Null
        $localLogs.Add("Extraction error for '$($Zip.Name)': $($_.Exception.Message)") | Out-Null
        return [pscustomobject]@{
            Success           = $false
            FilesExtracted    = 0
            UncompressedBytes = [int64]0
            CompressedBytes   = [int64]0
            Logs              = $localLogs.ToArray()
        }
    }
}
