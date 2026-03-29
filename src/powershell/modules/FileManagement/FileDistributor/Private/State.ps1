function ConvertTo-Hashtable {
    param([Parameter(Mandatory = $true)]$Object)

    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable]) { return $Object }
    if ($Object -is [System.Collections.IDictionary]) { return @{} + $Object }

    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        foreach ($p in $Object.PSObject.Properties) {
            $ht[$p.Name] = ConvertTo-Hashtable -Object $p.Value
        }
        return $ht
    }

    if ($Object -is [System.Collections.IEnumerable] -and -not ($Object -is [string])) {
        $list = @()
        foreach ($i in $Object) {
            $list += , (ConvertTo-Hashtable -Object $i)
        }
        return $list
    }

    return $Object
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $h = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
        return $h.Hash.ToUpperInvariant()
    }
    catch {
        LogMessage -Message "Failed to compute SHA256 for '$Path': $($_.Exception.Message)" -IsWarning
        return $null
    }
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory = $true)][hashtable]$StateObject,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $dir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tmp = "$Path.tmp"
    $bak = "$Path.bak"
    $sha = "$Path.sha256"

    if (Test-Path -LiteralPath $Path) {
        try {
            Copy-Item -LiteralPath $Path -Destination $bak -Force -ErrorAction Stop
        }
        catch {
            LogMessage -Message "Failed to update state backup '$bak': $($_.Exception.Message)" -IsWarning
        }
    }

    $json = $StateObject | ConvertTo-Json -Depth 100
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8

    $hash = Get-FileSha256Hex -Path $tmp
    try {
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }
    catch {
        LogMessage -Message "Atomic move for state file failed: $($_.Exception.Message)" -IsError
        throw
    }

    if ($hash) {
        try {
            $sidecarRetryDelay = 1
            $sidecarMaxBackoff = [Math]::Min(5, $MaxBackoff)
            $sidecarRetryCount = if ($RetryCount -eq 0) { 0 } else { [Math]::Max(1, $RetryCount) }
            Invoke-WithRetry -Operation {
                Set-Content -LiteralPath $sha -Value $hash -Encoding ASCII -ErrorAction Stop
            } -Description "Write state sidecar '$sha'" `
                -RetryDelay $sidecarRetryDelay `
                -RetryCount $sidecarRetryCount `
                -MaxBackoff $sidecarMaxBackoff
        }
        catch {
            LogMessage -Message "Failed to write state sidecar '$sha': $($_.Exception.Message)" -IsWarning
        }
    }
}

function Get-StateFromPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $sha = "$Path.sha256"
    if (Test-Path -LiteralPath $sha) {
        $expected = (Get-Content -LiteralPath $sha -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        $actual = Get-FileSha256Hex -Path $Path
        if ($expected -and $actual -and ($expected -ne $actual)) {
            LogMessage -Message "Checksum mismatch for '$Path' (expected $expected, got $actual). Treating as corrupt." -IsWarning
            return $null
        }
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $ht = ConvertTo-Hashtable -Object $obj
        return $ht
    }
    catch {
        LogMessage -Message "Failed to parse state file '$Path': $($_.Exception.Message)" -IsWarning
        return $null
    }
}

function ConvertFrom-FileQueue {
    <#
    .SYNOPSIS
        Converts a FileQueue to an array for state persistence.
    #>
    param (
        [PSCustomObject]$Queue
    )

    $queueArray = @()
    $tempQueue = [System.Collections.Generic.Queue[PSCustomObject]]::new()

    while ($Queue.Items.Count -gt 0) {
        $item = $Queue.Items.Dequeue()
        $queueArray += [pscustomobject]@{
            Path             = $item.SourcePath
            Size             = $item.Size
            LastWriteTimeUtc = $item.LastWriteTimeUtc
            QueuedAtUtc      = $item.QueuedAtUtc
            SessionId        = $item.SessionId
        }
        $tempQueue.Enqueue($item)
    }

    $Queue.Items = $tempQueue

    return $queueArray
}

function Save-DistributionState {
    param (
        [int]$Checkpoint,
        [hashtable]$AdditionalVariables = @{ },
        [ref]$FileLock,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][int]$WarningsSoFar,
        [Parameter(Mandatory = $true)][int]$ErrorsSoFar
    )

    Unlock-DistributionStateFile -FileStream $FileLock.Value

    if (-not (Test-Path -Path $StateFilePath)) {
        New-Item -Path $StateFilePath -ItemType File -Force | Out-Null
        LogMessage -Message "State file created at $StateFilePath"
    }

    $state = @{
        Checkpoint    = $Checkpoint
        SessionId     = $SessionId
        WarningsSoFar = $WarningsSoFar
        ErrorsSoFar   = $ErrorsSoFar
        Timestamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    foreach ($key in $AdditionalVariables.Keys) {
        $state[$key] = $AdditionalVariables[$key]
    }

    Write-JsonAtomically -StateObject $state -Path $StateFilePath

    LogMessage -Message "Saved state: Checkpoint $Checkpoint and additional variables: $($AdditionalVariables.Keys -join ', ')"

    $FileLock.Value = Lock-DistributionStateFile -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
}

function Restore-DistributionState {
    param (
        [ref]$FileLock
    )

    Unlock-DistributionStateFile -FileStream $FileLock.Value

    $state = $null
    $primary = $StateFilePath
    $backup = "$StateFilePath.bak"

    $state = Get-StateFromPath -Path $primary

    if (-not $state) {
        $stateBak = Get-StateFromPath -Path $backup
        if ($stateBak) {
            try {
                Copy-Item -LiteralPath $backup -Destination $primary -Force
                $bakHashPath = "$backup.sha256"
                $priHashPath = "$primary.sha256"
                if (Test-Path -LiteralPath $bakHashPath) {
                    Copy-Item -LiteralPath $bakHashPath -Destination $priHashPath -Force -ErrorAction SilentlyContinue
                }
                else {
                    $rehash = Get-FileSha256Hex -Path $primary
                    if ($rehash) { Set-Content -LiteralPath $priHashPath -Value $rehash -Encoding ASCII }
                }
                LogMessage -Message "Recovered state from backup '$backup'."
            }
            catch {
                LogMessage -Message "Failed to restore state from backup '$backup': $($_.Exception.Message)" -IsWarning
            }
            $state = $stateBak
        }
        elseif (Test-Path -LiteralPath $primary) {
            try {
                $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $corruptName = "$primary.corrupt-$stamp.json"
                Rename-Item -LiteralPath $primary -NewName (Split-Path -Leaf $corruptName) -ErrorAction Stop
                $priHashPath = "$primary.sha256"
                if (Test-Path -LiteralPath $priHashPath) {
                    Rename-Item -LiteralPath $priHashPath -NewName ((Split-Path -Leaf $corruptName) + ".sha256") -ErrorAction SilentlyContinue
                }
                LogMessage -Message "Quarantined corrupt state file to '$corruptName'." -IsWarning
            }
            catch {
                LogMessage -Message "Failed to quarantine corrupt state file '$primary': $($_.Exception.Message)" -IsWarning
            }
        }
    }

    if (-not $state) { $state = @{ Checkpoint = 0 } }

    $FileLock.Value = Lock-DistributionStateFile -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff

    return $state
}
