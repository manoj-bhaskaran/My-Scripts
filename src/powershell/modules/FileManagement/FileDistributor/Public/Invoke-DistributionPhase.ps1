# Invoke-DistributionPhase.ps1 - Main distribution phase orchestration (public module function)

function Invoke-DistributionPhase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [FileDistributorRunState]$RunState,
        [Parameter(Mandatory = $true)][ref]$FileLockRef,
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)][string]$StateFilePath,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount,
        [Parameter(Mandatory = $true)][int]$MaxBackoff,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount
    )

    if ($RunState.LastCheckpoint -lt 1) {
        if (-not [string]::IsNullOrWhiteSpace($SourceFolder)) {
            Write-LogInfo "Preparing for distribution (no upfront renaming; rename occurs at copy time)."
        }
        Save-DistributionState -Checkpoint 1 -AdditionalVariables @{ deleteMode = $DeleteMode; SourceFolder = $SourceFolder } -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RunState.LastCheckpoint -lt 2) {
        if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
            Write-LogInfo "Enumerating target files..."
            $RunState.SourceFiles = @(); $RunState.TotalSourceFiles = 0; $RunState.TotalSourceFilesAll = 0
        } else {
            Write-LogInfo "Enumerating source and target files..."
            $allSourceFiles = Get-ChildItem -Path $SourceFolder -Recurse -File
            $allowedExtensions = @('.jpg', '.png', '.mp4')
            $sourceFilesAll = @()
            foreach ($file in $allSourceFiles) {
                $ext = $file.Extension.ToLower()
                if ($ext -in $allowedExtensions) { $sourceFilesAll += $file }
                else {
                    if (-not $RunState.SkippedFilesByExtension.ContainsKey($ext)) { $RunState.SkippedFilesByExtension[$ext] = 0 }
                    $RunState.SkippedFilesByExtension[$ext]++
                    $RunState.TotalSkippedFiles++
                }
            }
            $RunState.TotalSourceFilesAll = $sourceFilesAll.Count
            if ($RunState.MaxFilesToCopy -eq 0) { $RunState.SourceFiles = @() }
            elseif ($RunState.MaxFilesToCopy -gt 0) { $RunState.SourceFiles = $sourceFilesAll | Select-Object -First $RunState.MaxFilesToCopy }
            else { $RunState.SourceFiles = $sourceFilesAll }
            $RunState.TotalSourceFiles = $RunState.SourceFiles.Count
        }

        $RunState.TotalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
        $RunState.TotalTargetFilesBefore = if ($null -eq $RunState.TotalTargetFilesBefore) { 0 } else { $RunState.TotalTargetFilesBefore }
        $totalFiles = $RunState.TotalSourceFiles + $RunState.TotalTargetFilesBefore

        $RunState.Subfolders = @(Get-ChildItem -LiteralPath $TargetFolder -Force | Where-Object { $_.PSIsContainer })
        if ($totalFiles / $RunState.FilesPerFolderLimit -gt $RunState.Subfolders.Count) {
            $additionalFolders = [math]::Ceiling($totalFiles / $RunState.FilesPerFolderLimit) - $RunState.Subfolders.Count
            $RunState.Subfolders += New-DistributionSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
        }

        Save-DistributionState -Checkpoint 2 -AdditionalVariables (New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.Subfolders -SourceFiles $RunState.SourceFiles -IncludeSourceFiles) -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RunState.LastCheckpoint -lt 3) {
        $cp3 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.Subfolders -SourceFiles $RunState.SourceFiles -IncludeSourceFiles -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 3 -AdditionalVariables $cp3 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RunState.LastCheckpoint -lt 4) {
        if ($RunState.TotalSourceFiles -gt 0 -and $RunState.SourceFiles.Count -gt 0) {
            Invoke-FileDistribution -Files $RunState.SourceFiles -Subfolders $RunState.Subfolders -TargetRoot $TargetFolder -Limit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -TotalFiles $RunState.TotalSourceFiles -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff -WarningCount $WarningCount -ErrorCount $ErrorCount
        }
        $cp4 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.Subfolders -SourceFiles $RunState.SourceFiles -IncludeSourceFiles -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 4 -AdditionalVariables $cp4 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }

    if ($RunState.LastCheckpoint -lt 5) {
        Invoke-TargetRedistribution -TargetFolder $TargetFolder -Subfolders $RunState.Subfolders -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff -WarningCount $WarningCount -ErrorCount $ErrorCount
        $cp5 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -IncludeFilesToDelete
        Save-DistributionState -Checkpoint 5 -AdditionalVariables $cp5 -FileLock $FileLockRef -SessionId $RunState.SessionId -WarningsSoFar $WarningCount.Value -ErrorsSoFar $ErrorCount.Value -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }
}
