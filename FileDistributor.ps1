<# .SYNOPSIS This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It also moves the original files to the Recycle Bin after ensuring successful copying and resolves file name conflicts.

.DESCRIPTION The script ensures that files are evenly distributed across subfolders in the target directory, with a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created as needed. Files in the target folder (not in subfolders) are also redistributed. File name conflicts are resolved using a custom random name generator. The script validates file copying before moving the original files to the Recycle Bin from the source folder and logs its actions in both summary and verbose modes.

.PARAMETER SourceFolder Mandatory. Specifies the path to the source folder containing the files to be copied.

.PARAMETER TargetFolder Mandatory. Specifies the path to the target folder where the files will be distributed.

.PARAMETER FilesPerFolderLimit Optional. Specifies the maximum number of files allowed in each subfolder of the target folder. Defaults to 20,000.

.PARAMETER LogFilePath Optional. Specifies the path to the log file for recording script activities. Defaults to "file_copy_log.txt" in the current directory.

.PARAMETER Verbose Optional. Enables detailed logging and output to the console.

.EXAMPLES To copy files from "C:\Source" to "C:\Target" with a default file limit: .\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target"

To copy files with a custom file limit and log to a specific file: .\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -FilesPerFolderLimit 10000 -LogFilePath "C:\Logs\copy_log.txt"

To enable verbose logging: .\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Verbose

.NOTES Script Workflow:

Initialization:

Validates input parameters and checks if the source and target folders exist.

Initializes logging and ensures the random name generator script is available.

Subfolder Management:

Counts existing subfolders in the target folder.

Creates new subfolders only if required to maintain the file limit.

File Processing:

Files are copied from the source folder to the target subfolders.

Files in the target folder (not in subfolders) are redistributed regardless of the limit.

File name conflicts are resolved using the random name generator.

Successful copying is verified before moving the original files to the Recycle Bin.

Error Handling:

Logs errors during file operations and skips problematic files without stopping the script.

Completion:

Logs completion of the operation and reports any unprocessed files.

Provides a final summary message with the original number of files in the source folder, the original number of files in the target folder hierarchy, and the final number of files in the target folder hierarchy. Throws a warning if the sum of the original counts is not equal to the final count in the target.

Prerequisites:

Ensure permissions for reading and writing in both source and target directories.

The random name generator script should be located at: C:\Users\manoj\Documents\Scripts\randomname.ps1.

Limitations:

The script does not handle nested directories in the source folder; only top-level files are processed. #>

param(
    [string]$SourceFolder,
    [string]$TargetFolder,
    [int]$FilesPerFolderLimit = 20000,
    [string]$LogFilePath = "C:\users\manoj\Documents\Scripts\FileDistributor.log",
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

# Check if the random name generator script exists and load it
$randomNameScriptPath = "C:\Users\manoj\Documents\Scripts\randomname.ps1"
if (Test-Path -Path $randomNameScriptPath) {
    . $randomNameScriptPath
    if (-not (Get-Command -Name Get-RandomFileName -ErrorAction SilentlyContinue)) {
        LogMessage "ERROR: Failed to load the random name generator script from '$randomNameScriptPath'." -VerboseMode:$Verbose
        throw "Failed to load the random name generator script."
    }
} else {
    LogMessage "ERROR: Random name generator script '$randomNameScriptPath' not found." -VerboseMode:$Verbose
    throw "Random name generator script not found."
}

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

# Function to move files to Recycle Bin
function Move-ToRecycleBin {
    param (
        [string]$FilePath
    )
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.NameSpace(10) # 10 is the folder type for Recycle Bin
    $file = Get-Item $FilePath
    $recycleBin.MoveHere($file.FullName, 0x100) # 0x100 suppresses the confirmation dialog
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
            try {
                Move-ToRecycleBin -FilePath $file.FullName
                LogMessage "Copied and moved to Recycle Bin: $($file.FullName) to $destinationFile" -VerboseMode:$Verbose
            } catch {
                LogMessage "ERROR: Failed to move $($file.FullName) to Recycle Bin. Error: $($_.Exception.Message)" -VerboseMode:$Verbose
            }
        } else {
            LogMessage "ERROR: Failed to copy $($file.FullName) to $destinationFile. Original file not moved." -VerboseMode:$Verbose
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

        # Count files in the source and target folder before distribution
        $sourceFiles = Get-ChildItem -Path $SourceFolder -File
        $totalSourceFiles = $sourceFiles.Count
        $totalTargetFilesBefore = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count

        # Get subfolders in the target folder
        $subfolders = Get-ChildItem -Path $TargetFolder -Directory

        # Determine if subfolders need to be created
        $totalFiles = $totalTargetFilesBefore + $totalSourceFiles
        $currentFolderCount = $subfolders.Count

        if ($totalFiles / $FilesPerFolderLimit -gt $currentFolderCount) {
            $additionalFolders = [math]::Ceiling($totalFiles / $FilesPerFolderLimit) - $currentFolderCount
            $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders
        }

        # Distribute files from the source folder to subfolders
        DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -Limit $FilesPerFolderLimit

        # Redistribute files within the target folder and subfolders if needed
        RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders -FilesPerFolderLimit $FilesPerFolderLimit

        # Count files in the target folder after distribution
        $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count

        # Log summary message
        LogMessage "Original number of files in the source folder: $totalSourceFiles" -VerboseMode:$Verbose
        LogMessage "Original number of files in the target folder hierarchy: $totalTargetFilesBefore" -VerboseMode:$Verbose
        LogMessage "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -VerboseMode:$Verbose

        if ($totalSourceFiles + $totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage "WARNING: Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -VerboseMode:$Verbose
        } else {
            LogMessage "File distribution and cleanup completed successfully." -VerboseMode:$Verbose
        }

    } catch {
        LogMessage "ERROR: $($_.Exception.Message)" -VerboseMode:$Verbose
    }
}

# Run the script
Main
