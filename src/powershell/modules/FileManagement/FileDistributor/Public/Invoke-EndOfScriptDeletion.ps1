# Invoke-EndOfScriptDeletion.ps1 - End-of-script deletion phase (public module function)

function Invoke-EndOfScriptDeletion {
    [CmdletBinding(SupportsShouldProcess = $true)]
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

    $frameworkWarnings = if (Get-Command -Name Get-LogWarningCount -ErrorAction SilentlyContinue) { Get-LogWarningCount } else { $WarningCount.Value }
    $frameworkErrors = if (Get-Command -Name Get-LogErrorCount -ErrorAction SilentlyContinue) { Get-LogErrorCount } else { $ErrorCount.Value }
    $effectiveWarnings = [Math]::Max($frameworkWarnings, $PriorWarnings)
    $effectiveErrors   = [Math]::Max($frameworkErrors,   $PriorErrors)

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
            if ($PSCmdlet.ShouldProcess($entry.SourcePath, "Delete source file at end-of-script")) {
                try { Remove-DistributionFile -FilePath $entry.SourcePath -RetryDelay $RetryDelay -RetryCount $RetryCount }
                catch {
                    Write-LogWarning "Failed to delete file $($entry.SourcePath). Error: $($_.Exception.Message)"
                    $WarningCount.Value++
                }
            } else {
                Write-LogInfo "End-of-script deletion skipped due to ShouldProcess: '$($entry.SourcePath)'."
            }
        } else {
            Write-LogDebug "End-of-script deletion: skipped '$($entry.SourcePath)' due to file metadata drift."
        }
    }
}
