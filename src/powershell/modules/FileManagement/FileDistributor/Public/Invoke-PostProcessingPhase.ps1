# Invoke-PostProcessingPhase.ps1 - Post-processing phase orchestration (public module function)

function Invoke-PostProcessingPhase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [FileDistributorRunState]$RunState,
        [Parameter(Mandatory = $true)][ref]$FileLockRef,
        [switch]$ConsolidateToMinimum,
        [switch]$RebalanceToAverage,
        [switch]$RandomizeDistribution,
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [int]$RebalanceTolerance = 10,
        [Parameter(Mandatory = $true)][string]$StateFilePath,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount,
        [Parameter(Mandatory = $true)][int]$MaxBackoff,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount
    )

    if ($ConsolidateToMinimum -and $RunState.LastCheckpoint -lt 6) {
        Invoke-FolderConsolidation -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -WarningCount $WarningCount -ErrorCount $ErrorCount -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        $cp6 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 6 -AdditionalVariables $cp6 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RebalanceToAverage -and $RunState.LastCheckpoint -lt 7) {
        Invoke-FolderRebalance -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -Tolerance $RebalanceTolerance -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -WarningCount $WarningCount -ErrorCount $ErrorCount -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        $cp7 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 7 -AdditionalVariables $cp7 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RandomizeDistribution -and $RunState.LastCheckpoint -lt 8) {
        Invoke-DistributionRandomize -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency $UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -WarningCount $WarningCount -ErrorCount $ErrorCount -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        $cp8 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 8 -AdditionalVariables $cp8 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }
}
