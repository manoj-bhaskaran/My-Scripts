# Invoke-ParameterValidation.ps1 - Script parameter validation (public module function)

function Invoke-ParameterValidation {
    param(
        [hashtable]$RunState,
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [int]$FilesPerFolderLimit,
        [int]$MaxFilesToCopy,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [switch]$ConsolidateToMinimum,
        [switch]$RebalanceToAverage,
        [switch]$RandomizeDistribution,
        [Parameter(Mandatory = $true)][string]$EndOfScriptDeletionCondition,
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

    if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
        Write-LogError "TargetFolder not specified. Provide -TargetFolder with a valid path."
        $ErrorCount.Value++
        throw "Missing required parameter: -TargetFolder"
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFolder) -and !(Test-Path -Path $SourceFolder)) {
        Write-LogError "Source folder '$SourceFolder' does not exist."
        $ErrorCount.Value++
        throw "Source folder not found."
    }

    if (!($FilesPerFolderLimit -gt 0)) {
        Write-LogWarning "Incorrect value for FilesPerFolderLimit. Resetting to default: 20000."
        $WarningCount.Value++
        $RunState.FilesPerFolderLimit = 20000
    } else {
        $RunState.FilesPerFolderLimit = $FilesPerFolderLimit
    }

    if (!(Test-Path -Path $TargetFolder)) {
        Write-LogWarning "Target folder '$TargetFolder' does not exist. Creating it."
        $WarningCount.Value++
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    }

    if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $DeleteMode)) {
        Write-LogError "Invalid value for DeleteMode: $DeleteMode. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'."
        $ErrorCount.Value++
        throw "Invalid DeleteMode."
    }

    $exclusiveOptions = @($ConsolidateToMinimum, $RebalanceToAverage, $RandomizeDistribution)
    $enabledCount = ($exclusiveOptions | Where-Object { $_ }).Count
    if ($enabledCount -gt 1) {
        Write-LogError "Parameters -ConsolidateToMinimum, -RebalanceToAverage, and -RandomizeDistribution are mutually exclusive. Choose only one."
        $ErrorCount.Value++
        throw "Mutually exclusive options: only one of -ConsolidateToMinimum, -RebalanceToAverage, or -RandomizeDistribution can be specified"
    }

    if (-not ("NoWarnings", "WarningsOnly" -contains $EndOfScriptDeletionCondition)) {
        Write-LogError "Invalid value for EndOfScriptDeletionCondition: $EndOfScriptDeletionCondition. Valid options are 'NoWarnings', 'WarningsOnly'."
        $ErrorCount.Value++
        throw "Invalid EndOfScriptDeletionCondition."
    }

    if ($RunState.MaxFilesToCopy -lt -1) {
        Write-LogWarning "Invalid MaxFilesToCopy '$($RunState.MaxFilesToCopy)'. Using -1 (no limit)."
        $WarningCount.Value++
        $RunState.MaxFilesToCopy = -1
    }

    $RunState.FilesToDelete    = New-FileQueue -Name "FilesToDelete" -SessionId $RunState.SessionId -MaxSize -1
    $RunState.GlobalFileCounter = New-Ref 0
    Write-LogInfo "Parameter validation completed"
}
