function Lock-DistributionStateFile {
    param (
        [string]$FilePath,
        [int]$RetryDelay,
        [int]$RetryCount,
        [int]$MaxBackoff
    )

    $attempts = 0
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($FilePath, 'OpenOrCreate', 'ReadWrite', 'None')
            Write-LogInfo "Acquired lock on $FilePath"
            return $fileStream
        }
        catch {
            $attempts++
            $lastErr = $_.Exception.Message
            if ($RetryCount -ne 0 -and $attempts -ge $RetryCount) {
                Write-LogError "Failed to acquire lock on $FilePath after $attempts attempt(s). Last error: $lastErr"
                throw "Failed to acquire lock on $FilePath after $attempts attempt(s). Last error: $lastErr"
            }
            $delay = [Math]::Min([int]([Math]::Max(1, $RetryDelay) * [Math]::Pow(2, $attempts - 1)), [Math]::Max(1, $MaxBackoff))
            $jitterMs = Get-Random -Minimum 50 -Maximum 250
            Write-LogWarning "Attempt $attempts failed to lock '$FilePath'. Error: $lastErr. Retrying in ${delay}s (+${jitterMs}ms jitter)..."
            Start-Sleep -Seconds $delay
            Start-Sleep -Milliseconds $jitterMs
        }
    }
}

function Unlock-DistributionStateFile {
    param (
        [System.IO.FileStream]$FileStream
    )

    if ($null -eq $FileStream) {
        Write-LogInfo "Unlock-DistributionStateFile called with null stream; nothing to release."
        return
    }

    $fileName = "<unknown>"
    try { $fileName = $FileStream.Name } catch {
        # Stream may not have a name if already disposed
    }

    try { $FileStream.Close() } catch {
        # Stream may already be closed
    }

    try { $FileStream.Dispose() } catch {
        # Stream may already be disposed
    }

    Write-LogInfo "Released lock on $fileName"
}
