# Invoke-EndOfScriptDeletion.ps1 - End-of-script deletion phase (public module function)

function Invoke-EndOfScriptDeletion {
    param(
        [hashtable]$RunState,
        [int]$PriorWarnings,
        [int]$PriorErrors,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)][string]$EndOfScriptDeletionCondition,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount
    )

    if ($DeleteMode -ne "EndOfScript") { return }

    $effectiveWarnings = [Math]::Max($WarningCount.Value, $PriorWarnings)
    $effectiveErrors   = [Math]::Max($ErrorCount.Value,   $PriorErrors)

    if (-not (Test-EndOfScriptCondition -Condition $EndOfScriptDeletionCondition -Warnings $effectiveWarnings -Errors $effectiveErrors)) {
        Write-LogInfo "End-of-script deletion skipped due to warnings or errors."
        return
    }

    while ($RunState.FilesToDelete.Items.Count -gt 0) {
        $entry = Get-NextQueueItem -Queue $RunState.FilesToDelete -IncrementAttempts $false
        if ($null -eq $entry) { break }
        if ($entry.SessionId -ne $RunState.SessionId) { continue }
        if (-not (Test-Path -Path $entry.SourcePath)) { continue }

        $okToDelete = $true
        try {
            $fi = Get-Item -LiteralPath $entry.SourcePath -ErrorAction Stop
            if ($null -ne $entry.Size -and $fi.Length -ne $entry.Size) { $okToDelete = $false }
            if ($null -ne $entry.LastWriteTimeUtc -and $fi.LastWriteTimeUtc -ne $entry.LastWriteTimeUtc) { $okToDelete = $false }
        } catch { Write-LogDebug "Could not stat queued file before deletion: $($_.Exception.Message)" }

        if ($okToDelete) {
            try { Remove-DistributionFile -FilePath $entry.SourcePath -RetryDelay $RetryDelay -RetryCount $RetryCount }
            catch {
                Write-LogWarning "Failed to delete file $($entry.SourcePath). Error: $($_.Exception.Message)"
                $WarningCount.Value++
            }
        }
    }
}
