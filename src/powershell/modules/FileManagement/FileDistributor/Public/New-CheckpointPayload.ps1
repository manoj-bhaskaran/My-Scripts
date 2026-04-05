# New-CheckpointPayload.ps1 - Build checkpoint payload for state persistence (public module function)

function New-CheckpointPayload {
    param(
        [hashtable]$RunState,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [string]$SourceFolder,
        [int]$MaxFilesToCopy,
        [object]$Subfolders,
        [object]$SourceFiles,
        [switch]$IncludeSourceFiles,
        [switch]$IncludeFilesToDelete
    )

    $payload = @{
        totalSourceFiles       = $RunState.totalSourceFiles
        totalSourceFilesAll    = $RunState.totalSourceFilesAll
        totalTargetFilesBefore = $RunState.totalTargetFilesBefore
        deleteMode             = $DeleteMode
        SourceFolder           = $SourceFolder
        MaxFilesToCopy         = $MaxFilesToCopy
    }

    if ($null -ne $Subfolders) {
        $payload.subfolders = ConvertItemsToPaths($Subfolders)
    }

    if ($IncludeSourceFiles -and $null -ne $SourceFiles) {
        $payload.sourceFiles = ConvertItemsToPaths($SourceFiles)
    }

    if ($IncludeFilesToDelete -and $DeleteMode -eq "EndOfScript") {
        $payload.FilesToDelete = ConvertFrom-FileQueue -Queue $RunState.FilesToDelete
    }

    return $payload
}
