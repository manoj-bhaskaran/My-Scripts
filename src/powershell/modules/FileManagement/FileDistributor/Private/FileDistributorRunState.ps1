class FileDistributorRunState {
    [int]$TotalSourceFilesAll = 0
    [int]$TotalSourceFiles = 0
    [int]$TotalTargetFilesBefore = 0
    [object[]]$Subfolders = @()
    [object[]]$SourceFiles = @()
    [hashtable]$SkippedFilesByExtension = @{}
    [int]$TotalSkippedFiles = 0
    [string]$SessionId
    [int]$MaxFilesToCopy = -1
    [int]$FilesPerFolderLimit = 0
    [object]$FilesToDelete
    [object]$GlobalFileCounter
    [int]$LastCheckpoint = 0
    [hashtable]$State = @{}
    [string]$SourceFolder

    FileDistributorRunState() {
    }

    [hashtable] ToSerializableHashtable() {
        return @{
            totalSourceFiles        = $this.TotalSourceFiles
            totalSourceFilesAll     = $this.TotalSourceFilesAll
            totalTargetFilesBefore  = $this.TotalTargetFilesBefore
            MaxFilesToCopy          = $this.MaxFilesToCopy
            SourceFolder            = $this.SourceFolder
            totalSkippedFiles       = $this.TotalSkippedFiles
            skippedFilesByExtension = @{} + $this.SkippedFilesByExtension
        }
    }

    static [FileDistributorRunState] FromHashtable([hashtable]$State) {
        $runState = [FileDistributorRunState]::new()

        if ($null -eq $State) {
            return $runState
        }

        if ($State.ContainsKey('totalSourceFiles')) {
            $runState.TotalSourceFiles = [int]$State['totalSourceFiles']
        }
        if ($State.ContainsKey('totalSourceFilesAll')) {
            $runState.TotalSourceFilesAll = [int]$State['totalSourceFilesAll']
        }
        if ($State.ContainsKey('totalTargetFilesBefore')) {
            $runState.TotalTargetFilesBefore = [int]$State['totalTargetFilesBefore']
        }
        if ($State.ContainsKey('MaxFilesToCopy')) {
            $runState.MaxFilesToCopy = [int]$State['MaxFilesToCopy']
        }
        if ($State.ContainsKey('SourceFolder')) {
            $runState.SourceFolder = [string]$State['SourceFolder']
        }
        if ($State.ContainsKey('SessionId')) {
            $runState.SessionId = [string]$State['SessionId']
        }
        if ($State.ContainsKey('Checkpoint')) {
            $runState.LastCheckpoint = [int]$State['Checkpoint']
        }
        if ($State.ContainsKey('totalSkippedFiles')) {
            $runState.TotalSkippedFiles = [int]$State['totalSkippedFiles']
        }
        if ($State.ContainsKey('skippedFilesByExtension')) {
            $dict = $State['skippedFilesByExtension']
            if ($dict -is [System.Collections.IDictionary]) {
                $copy = @{}
                foreach ($key in $dict.Keys) {
                    $copy[[string]$key] = [int]$dict[$key]
                }
                $runState.SkippedFilesByExtension = $copy
            }
        }

        return $runState
    }
}
