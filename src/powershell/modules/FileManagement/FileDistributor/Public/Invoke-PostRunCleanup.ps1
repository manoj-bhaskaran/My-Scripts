# Invoke-PostRunCleanup.ps1 - Post-run cleanup and summary (public module function)

function Invoke-PostRunCleanup {
    param(
        [hashtable]$RunState,
        [Parameter(Mandatory = $true)][ref]$FileLockRef,
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][string]$StateFilePath,
        [switch]$CleanupDuplicates,
        [switch]$CleanupEmptyFolders,
        [string]$LogFilePath,
        [string]$ScriptRoot,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount
    )

    $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
    $totalTargetFilesAfter = if ($null -eq $totalTargetFilesAfter) { 0 } else { $totalTargetFilesAfter }

    if ([string]::IsNullOrWhiteSpace($RunState['SourceFolder'])) {
        Write-LogInfo "===== File Rebalancing Summary ====="
        Write-LogInfo "Original number of files in the target folder hierarchy: $($RunState.totalTargetFilesBefore)"
        Write-LogInfo "Final number of files in the target folder hierarchy: $totalTargetFilesAfter"
        if ($RunState.totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            Write-LogWarning "File count changed during rebalancing. Possible discrepancy detected."
            $WarningCount.Value++
        } else {
            Write-LogInfo "File rebalancing completed successfully."
        }
    } else {
        Write-LogInfo "===== File Distribution Summary ====="
        Write-LogInfo "Original number of files in the source folder (enumerated): $($RunState.totalSourceFilesAll)"
        Write-LogInfo "Files selected for copying this run: $($RunState.totalSourceFiles)"
        Write-LogInfo "Original number of files in the target folder hierarchy: $($RunState.totalTargetFilesBefore)"
        Write-LogInfo "Final number of files in the target folder hierarchy: $totalTargetFilesAfter"
        if ($RunState.totalSourceFiles + $RunState.totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            Write-LogWarning "Sum of original counts does not equal the final count in the target. Possible discrepancy detected."
            $WarningCount.Value++
        } else {
            Write-LogInfo "File distribution and cleanup completed successfully."
        }
    }
    Write-LogInfo "Total warnings: $($WarningCount.Value)"
    Write-LogInfo "Total errors: $($ErrorCount.Value)"

    if ($FileLockRef.Value) { Unlock-DistributionStateFile -FileStream $FileLockRef.Value; $FileLockRef.Value = $null }
    Remove-Item -Path $StateFilePath -Force

    if ($CleanupDuplicates -and $ScriptRoot) {
        $dupScript = Join-Path -Path $ScriptRoot -ChildPath "Remove-DuplicateFiles.ps1"
        if (Test-Path -LiteralPath $dupScript) { & $dupScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false }
    }

    if ($CleanupEmptyFolders -and $ScriptRoot) {
        $emptyScript = Join-Path -Path $ScriptRoot -ChildPath "Remove-EmptyFolders.ps1"
        if (Test-Path -LiteralPath $emptyScript) { & $emptyScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false }
    }
}
