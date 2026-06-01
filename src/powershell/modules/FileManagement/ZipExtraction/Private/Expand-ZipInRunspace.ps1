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
        $r = Invoke-SingleZipExtraction -Zip $Zip -DestDir $DestDir -Mode $Mode -Policy $Policy -MaxLen $MaxLen
        $localLogs.Add($r.Log) | Out-Null

        return [pscustomobject]@{
            Success           = $true
            ZipPath           = $Zip.FullName
            FilesExtracted    = $r.FilesExtracted
            UncompressedBytes = $r.UncompressedBytes
            CompressedBytes   = $r.CompressedBytes
            Logs              = $localLogs.ToArray()
        }
    } catch {
        $ErrorBag.Add("Extraction failed for '$($Zip.FullName)': $($_.Exception.Message)") | Out-Null
        $localLogs.Add("Extraction error for '$($Zip.Name)': $($_.Exception.Message)") | Out-Null
        return [pscustomobject]@{
            Success           = $false
            ZipPath           = $Zip.FullName
            FilesExtracted    = 0
            UncompressedBytes = [int64]0
            CompressedBytes   = [int64]0
            Logs              = $localLogs.ToArray()
        }
    }
}
