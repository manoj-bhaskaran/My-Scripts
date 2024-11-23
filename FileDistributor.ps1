param(
    [string]$SourceFolder,
    [string]$TargetFolder,
    [int]$FilesPerFolderLimit = 20000,
    [string]$LogFilePath = "file_copy_log.txt",
    [switch]$Verbose # Enable verbose logging if specified
)

# Function to log messages
function LogMessage {
    param (
        [string]$Message,
        [switch]$VerboseMode
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp : $Message"
    $logEntry | Out-File -FilePath $LogFilePath -Append

    # Print to console only in verbose mode
    if ($VerboseMode) {
        Write-Host $logEntry
    }
}

# Load function to generate random names
. "C:\Users\manoj\Documents\Scripts\randomname.ps1"

# Function to resolve file name conflicts
function ResolveFileNameConflict {
    param (
        [string]$TargetFolder,
        [string]$OriginalFileName
    )
    $extension = [System.IO.Path]::GetExtension($OriginalFileName)
    do {
        $newFileName = Get-RandomFileName + $extension
        $newFilePath = Join-Path -Path $TargetFolder -ChildPath $newFileName
    } while (Test-Path -Path $newFilePath)
    return $newFileName
}

# Function to create random subfolders
function CreateRandomSubfolders {
    param (
        [string]$TargetPath,
        [int]$NumberOfFolders
    )
    $createdFolders = @()
    for ($i = 1; $i -le $NumberOfFolders; $i++) {
        do {
            $randomFolderName = Get-RandomFileName
            $folderPath = Join-Path -Path $TargetPath -ChildPath $randomFolderName
        } while (Test-Path -Path $folderPath)

        New-Item -ItemType Directory -Path $folderPath | Out-Null
        $createdFolders += $folderPath
        LogMessage "Created folder: $folderPath" -VerboseMode:$Verbose
    }
    return $createdFolders
}

# Function to distribute files to subfolders
function DistributeFilesToSubfolders {
    param (
        [string[]]$Files,
        [string[]]$Subfolders,
        [int]$Limit
    )
    $subfolderQueue = $Subfolders.GetEnumerator()
    foreach ($file in $Files) {
        if (!$subfolderQueue.MoveNext()) {
            $subfolderQueue.Reset()
            $subfolderQueue.MoveNext() | Out-Null
        }

        $destinationFolder = $subfolderQueue.Current
        $destinationFile = Join-Path -Path $destinationFolder -ChildPath $file.Name

        if (Test-Path -Path $destinationFile) {
            $newFileName = ResolveFileNameConflict -TargetFolder $destinationFolder -OriginalFileName $file.Name
            $destinationFile = Join-Path -Path $destinationFolder -ChildPath $newFileName
        }

        Copy-Item -Path $file.FullName -Destination $destinationFile

        # Verify the file was copied successfully
        if (Test-Path -Path $destinationFile) {
            Remove-Item -Path $file.FullName -Force
            LogMessage "Copied and deleted $($file.FullName) to $destinationFile" -VerboseMode:$Verbose
        } else {
            LogMessage "ERROR: Failed to copy $($file.FullName) to $destinationFile. Original file not deleted." -VerboseMode:$Verbose
        }        
    }
}

# Function to redistribute files within the target folder and subfolders
function RedistributeFilesInTarget {
    param (
        [string]$TargetFolder,
        [string[]]$Subfolders,
        [int]$FilesPerFolderLimit
    )
    $allFiles = Get-ChildItem -Path $TargetFolder -Recurse -File
    $folderFilesMap = @{}

    foreach ($subfolder in $Subfolders) {
        $folderFilesMap[$subfolder] = (Get-ChildItem -Path $subfolder -File).Count
    }

    # Redistribute files in the target folder (not in subfolders) regardless of limit
    $rootFiles = Get-ChildItem -Path $TargetFolder -File
    DistributeFilesToSubfolders -Files $rootFiles -Subfolders $Subfolders -Limit $FilesPerFolderLimit

    foreach ($file in $allFiles) {
        $folder = $file.DirectoryName
        $currentFileCount = $folderFilesMap[$folder]

        if ($currentFileCount -gt $FilesPerFolderLimit) {
            DistributeFilesToSubfolders -Files @($file) -Subfolders $Subfolders -Limit $FilesPerFolderLimit
            $folderFilesMap[$folder]--
        }
    }
}

# Main script logic
function Main {
    try {
        # Ensure source and target folders exist
        if (!(Test-Path -Path $SourceFolder)) {
            LogMessage "ERROR: Source folder '$SourceFolder' does not exist." -VerboseMode:$Verbose
            throw "Source folder not found."
        }
        if (!(Test-Path -Path $TargetFolder)) {
            LogMessage "Target folder '$TargetFolder' does not exist. Creating it." -VerboseMode:$Verbose
            New-Item -ItemType Directory -Path $TargetFolder
        }

        # Count files in the source and target folder
        $sourceFiles = Get-ChildItem -Path $SourceFolder -File
        $totalSourceFiles = $sourceFiles.Count
        $subfolders = Get-ChildItem -Path $TargetFolder -Directory

        # Determine if subfolders need to be created
        $totalTargetFiles = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
        $totalFiles = $totalTargetFiles + $totalSourceFiles
        $currentFolderCount = $subfolders.Count

        if ($totalFiles / $FilesPerFolderLimit -gt $currentFolderCount) {
            $additionalFolders = [math]::Ceiling($totalFiles / $FilesPerFolderLimit) - $currentFolderCount
            $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders
        }

        # Distribute files from the source folder to subfolders
        DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -Limit $FilesPerFolderLimit

        # Redistribute files within the target folder and subfolders if needed
        RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders -FilesPerFolderLimit $FilesPerFolderLimit

        LogMessage "File distribution and cleanup completed successfully." -VerboseMode:$Verbose
    } catch {
        LogMessage "ERROR: $($_.Exception.Message)" -VerboseMode:$Verbose
    }
}

# Run the script
Main
