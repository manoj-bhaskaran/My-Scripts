# Invoke-RestoreCheckpoint.ps1 - Restore checkpoint state (public module function)

function Invoke-RestoreCheckpoint {
    param(
        [hashtable]$RunState,
        [Parameter(Mandatory = $true)][ref]$FileLockRef,
        [Parameter(Mandatory = $true)][ref]$PriorWarnings,
        [Parameter(Mandatory = $true)][ref]$PriorErrors,
        [switch]$Restart,
        [Parameter(Mandatory = $true)][string]$StateFilePath,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount,
        [Parameter(Mandatory = $true)][int]$MaxBackoff,
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)][ref]$WarningCount
    )

    $RunState.LastCheckpoint = 0

    if ($Restart) {
        $FileLockRef.Value = Lock-DistributionStateFile -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        Write-LogInfo "Restart requested. Loading checkpoint..."

        $state = Restore-DistributionState -FileLock $FileLockRef -StateFilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        $RunState.State = $state
        $RunState.LastCheckpoint = $state.Checkpoint

        if ($RunState.LastCheckpoint -gt 0) {
            if ($state.PSObject.Properties.Name -contains 'SessionId' -and $state.SessionId) {
                $RunState.SessionId = [string]$state.SessionId
            } else {
                $RunState.SessionId = [guid]::NewGuid().ToString()
                Write-LogWarning "Legacy state without SessionId; generated new SessionId for this resume."
                $WarningCount.Value++
            }

            if ($state.PSObject.Properties.Name -contains 'WarningsSoFar') { $PriorWarnings.Value = [int]$state.WarningsSoFar }
            if ($state.PSObject.Properties.Name -contains 'ErrorsSoFar') { $PriorErrors.Value = [int]$state.ErrorsSoFar }
            Write-LogInfo "Restarting from checkpoint $($RunState.LastCheckpoint)"
        } else {
            Write-LogWarning "Checkpoint not found. Executing from top..."
            $WarningCount.Value++
        }

        if ($state.ContainsKey("SourceFolder")) {
            $savedSourceFolder = $state.SourceFolder
            if (-not [string]::IsNullOrWhiteSpace($savedSourceFolder)) {
                if ($SourceFolder -ne $savedSourceFolder) {
                    throw "SourceFolder mismatch: Restarted script must use the saved SourceFolder ('$savedSourceFolder'). Aborting."
                }
            }
        } else {
            throw "State file does not contain SourceFolder. Unable to enforce."
        }

        if ($state.ContainsKey("deleteMode")) {
            $savedDeleteMode = $state.deleteMode
            if ($DeleteMode -ne $savedDeleteMode) {
                throw "DeleteMode mismatch: Restarted script must use the saved DeleteMode ('$savedDeleteMode'). Aborting."
            }
        } else {
            throw "State file does not contain DeleteMode. Unable to enforce."
        }

        if ($RunState.LastCheckpoint -in 2..7 -and $null -ne $state) {
            if ($state.ContainsKey('totalSourceFiles'))     { $RunState.totalSourceFiles     = [int]$state['totalSourceFiles'] }
            if ($state.ContainsKey('totalTargetFilesBefore')) { $RunState.totalTargetFilesBefore = [int]$state['totalTargetFilesBefore'] }
            if ($state.ContainsKey('totalSourceFilesAll'))  { $RunState.totalSourceFilesAll  = [int]$state['totalSourceFilesAll'] }
            if ($state.ContainsKey('MaxFilesToCopy')) {
                $savedMax = [int]$state['MaxFilesToCopy']
                if ($RunState.MaxFilesToCopy -ne $savedMax) {
                    throw "MaxFilesToCopy mismatch: Restarted script must use the saved MaxFilesToCopy ($savedMax). Aborting."
                }
                $RunState.MaxFilesToCopy = $savedMax
            }
            if ($state.ContainsKey('subfolders')) { $RunState.subfolders = ConvertPathsToItems($state['subfolders']) }
            if ($RunState.LastCheckpoint -in 2, 3 -and $state.ContainsKey('sourceFiles')) { $RunState.sourceFiles = ConvertPathsToItems($state['sourceFiles']) }
        }

        if ($DeleteMode -eq "EndOfScript" -and $RunState.LastCheckpoint -in 3, 4, 5, 6, 7 -and $state.ContainsKey("FilesToDelete")) {
            foreach ($e in $state.FilesToDelete) {
                if ($e -is [string]) {
                    Add-FileToQueue -Queue $RunState.FilesToDelete -FilePath $e -ValidateFile $false | Out-Null
                } else {
                    $RunState.FilesToDelete.Items.Enqueue([pscustomobject]@{
                            SourcePath       = $e.Path
                            TargetPath       = $null
                            Size             = $e.Size
                            LastWriteTimeUtc = $e.LastWriteTimeUtc
                            QueuedAtUtc      = if ($e.PSObject.Properties.Name -contains 'QueuedAtUtc') { $e.QueuedAtUtc } else { (Get-Date).ToUniversalTime() }
                            SessionId        = if ($e.PSObject.Properties.Name -contains 'SessionId') { $e.SessionId } else { $RunState.SessionId }
                            Attempts         = 0
                            Metadata         = @{}
                        })
                }
            }
        }
    } else {
        if (Test-Path -Path $StateFilePath) {
            Write-LogWarning "Restart state file found but restart not requested. Deleting state file..."
            $WarningCount.Value++
            Remove-Item -Path $StateFilePath -Force
        }
        $FileLockRef.Value = Lock-DistributionStateFile -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }
}
