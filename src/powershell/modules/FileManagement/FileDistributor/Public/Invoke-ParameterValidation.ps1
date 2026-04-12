# Invoke-ParameterValidation.ps1 - Script parameter validation (public module function)

function Invoke-ParameterValidation {
    param(
        [Parameter(Mandatory = $true)][hashtable]$RunState,
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetFolder,
        [ValidateRange(1, [int]::MaxValue)][int]$FilesPerFolderLimit,
        [ValidateRange(-1, [int]::MaxValue)][int]$MaxFilesToCopy,
        [Parameter(Mandatory = $true)][ValidateSet("RecycleBin", "Immediate", "EndOfScript")][string]$DeleteMode,
        [switch]$ConsolidateToMinimum,
        [switch]$RebalanceToAverage,
        [switch]$RandomizeDistribution,
        [Parameter(Mandatory = $true)][ValidateSet("NoWarnings", "WarningsOnly")][string]$EndOfScriptDeletionCondition,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount
    )

    Write-LogInfo "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilesPerFolderLimit - $FilesPerFolderLimit, MaxFilesToCopy - $MaxFilesToCopy"

    $RunState.SessionId = [guid]::NewGuid().ToString()

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        $RunState.MaxFilesToCopy = 0
        Write-LogInfo "SourceFolder not specified. Running in rebalance-only mode (no files will be copied)."
    } else {
        $RunState.MaxFilesToCopy = $MaxFilesToCopy
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFolder) -and -not (Test-Path -Path $SourceFolder)) {
        Write-LogError "Source folder '$SourceFolder' does not exist."
        $ErrorCount.Value++
        throw "Source folder not found."
    }

    $RunState.FilesPerFolderLimit = $FilesPerFolderLimit

    if (-not (Test-Path -Path $TargetFolder)) {
        Write-LogWarning "Target folder '$TargetFolder' does not exist. Creating it."
        $WarningCount.Value++
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    }

    $exclusiveOptions = @($ConsolidateToMinimum, $RebalanceToAverage, $RandomizeDistribution)
    $enabledCount = ($exclusiveOptions | Where-Object { $_ }).Count
    if ($enabledCount -gt 1) {
        Write-LogError "Parameters -ConsolidateToMinimum, -RebalanceToAverage, and -RandomizeDistribution are mutually exclusive. Choose only one."
        $ErrorCount.Value++
        throw "Mutually exclusive options: only one of -ConsolidateToMinimum, -RebalanceToAverage, or -RandomizeDistribution can be specified"
    }

    $RunState.FilesToDelete = New-FileQueue -Name "FilesToDelete" -SessionId $RunState.SessionId -MaxSize -1
    $RunState.GlobalFileCounter = New-Ref 0
    Write-LogInfo "Parameter validation completed"
}
