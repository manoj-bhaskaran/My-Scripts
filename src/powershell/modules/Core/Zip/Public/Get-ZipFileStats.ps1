using namespace System.IO.Compression

<#
.SYNOPSIS
    Returns quick stats for a ZIP file: file count, total uncompressed bytes, and compressed bytes.
.DESCRIPTION
    Opens the archive once with ZipFile.OpenRead and accumulates entry counts and sizes.
    The compressed byte count is taken from the FileInfo.Length to avoid re-reading the archive.
    Directory entries (entries whose Name is empty) are excluded from the count.
.PARAMETER ZipPath
    Full path to the .zip file.
.OUTPUTS
    [pscustomobject] with FileCount [int], UncompressedBytes [int64], and CompressedBytes [int64].
#>
function Get-ZipFileStats {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ZipPath)

    $zipItem = Get-Item -LiteralPath $ZipPath
    $compressedLen = [int64]$zipItem.Length

    $result = [pscustomobject]@{
        FileCount         = 0
        UncompressedBytes = [int64]0
        CompressedBytes   = $compressedLen
    }

    try {
        $zip = [ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                if ($entry.Name) {
                    $result.FileCount++
                    $result.UncompressedBytes += [int64]$entry.Length
                }
            }
        } finally {
            $zip.Dispose()
        }
    } catch {
        Write-LogDebug "Failed to read zip stats for: $ZipPath. $_"
    }
    return $result
}
