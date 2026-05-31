<#
.SYNOPSIS
  Remove consecutive duplicate snapshot frames for a single video scene prefix.
.DESCRIPTION
  Walks all PNG files matching ${ScenePrefix}*.png in SaveFolder in lexical order.
  Any frame whose content hash equals the previous *kept* frame's hash is deleted.
  Only consecutive duplicates are removed; genuinely distinct frames are preserved.

  Hash mode is controlled by HashAlgorithm (default SHA256). File-byte hashing is
  used: PNG byte-identity is a reliable proxy for VLC scene-filter output of
  identical decoded frames.

  IO errors on individual files are tolerated: a locked or still-writing file is
  skipped and left in place; the error is written to the Verbose stream so callers
  can surface it without failing the batch.

  Returns a [pscustomobject] with:
    OriginalCount  - frames found before de-dup
    KeptCount      - frames retained after de-dup
    RemovedCount   - frames deleted
.PARAMETER SaveFolder
  Folder that contains the snapshot PNG files.
.PARAMETER ScenePrefix
  Filename prefix (e.g. "myvideo_") used to scope the operation to a single video.
.PARAMETER HashAlgorithm
  Cryptographic hash name passed to [System.Security.Cryptography.HashAlgorithm]::Create.
  Defaults to 'SHA256'. 'MD5' is faster for large batches but less collision-resistant.
.OUTPUTS
  [pscustomobject] with OriginalCount, KeptCount, RemovedCount.
#>
function Invoke-SnapshotDedup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$SaveFolder,
        [Parameter(Mandatory)][string]$ScenePrefix,
        [string]$HashAlgorithm = 'SHA256'
    )

    $frames = @(
        Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue |
            Sort-Object -Property Name
    )

    $originalCount = $frames.Count
    $removedCount  = 0
    $lastHash      = $null

    $hasher = $null
    try {
        $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($HashAlgorithm)
        if ($null -eq $hasher) {
            throw "Unknown hash algorithm: $HashAlgorithm"
        }

        foreach ($frame in $frames) {
            $hash = $null
            try {
                $bytes = [System.IO.File]::ReadAllBytes($frame.FullName)
                $hashBytes = $hasher.ComputeHash($bytes)
                $hash = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
            }
            catch {
                Write-Verbose ("Snapshot.Dedup: skipping locked/unreadable file '{0}': {1}" -f $frame.Name, $_.Exception.Message)
                $lastHash = $null
                continue
            }

            if ($hash -eq $lastHash) {
                try {
                    Remove-Item -LiteralPath $frame.FullName -Force -ErrorAction Stop
                    $removedCount++
                    Write-Verbose ("Snapshot.Dedup: removed duplicate '{0}'" -f $frame.Name)
                }
                catch {
                    Write-Verbose ("Snapshot.Dedup: could not remove '{0}' (locked/IO error): {1}" -f $frame.Name, $_.Exception.Message)
                }
            }
            else {
                $lastHash = $hash
            }
        }
    }
    finally {
        if ($null -ne $hasher) { $hasher.Dispose() }
    }

    [pscustomobject]@{
        OriginalCount = $originalCount
        KeptCount     = $originalCount - $removedCount
        RemovedCount  = $removedCount
    }
}
