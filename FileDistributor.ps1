<#
.SYNOPSIS
This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It provides configurable progress updates and moves the original files to the Recycle Bin after ensuring successful copying. File name conflicts are resolved automatically.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, with a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created as needed. Files in the target folder (not in subfolders) are also redistributed. File name conflicts are resolved using a custom random name generator. The script validates file copying before moving the original files to the Recycle Bin from the source folder and logs its actions in a log file. Progress updates can be displayed during processing, configurable by file count or percentage.

.PARAMETER SourceFolder
Mandatory. Specifies the path to the source folder containing the files to be copied.

.PARAMETER TargetFolder
Mandatory. Specifies the path to the target folder where the files will be distributed.

.PARAMETER FilesPerFolderLimit
Optional. Specifies the maximum number of files allowed in each subfolder of the target folder. Defaults to 20,000.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file for recording script activities. Defaults to "file_copy_log.txt" in the current directory.

.PARAMETER Restart
Optional. If specified, the script will restart from the last checkpoint, resuming its previous state.

.PARAMETER ShowProgress
Optional. Displays progress updates during the script's execution. Use this parameter to enable progress reporting.

.PARAMETER UpdateFrequency
Optional. Specifies how often progress updates are displayed. Can be set to a specific file count (e.g., every 100 files) or percentage increments. Defaults to 100.

.EXAMPLES
To copy files from "C:\Source" to "C:\Target" with a default file limit:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target"

To copy files with progress updates every 50 files:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -ShowProgress -UpdateFrequency 50

To restart the script from the last checkpoint:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Restart

To enable verbose logging using PowerShell's built-in `-Verbose` switch:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Verbose

.NOTES
Script Workflow:

Initialization:

- Validates input parameters and checks if the source and target folders exist.
- Initializes logging and ensures the random name generator script is available.

Subfolder Management:

- Counts existing subfolders in the target folder.
- Creates new subfolders as needed while providing progress updates if enabled.

File Processing:

- Files are copied from the source folder to the target subfolders.
- Files in the target folder (not in subfolders) are redistributed regardless of the limit.
- File name conflicts are resolved using the random name generator.
- Successful copying is verified before moving the original files to the Recycle Bin.
- Progress updates are displayed based on the specified `UpdateFrequency`.

Error Handling:

- Logs errors with detailed messages during file operations and skips problematic files without stopping the script.

Completion:

- Logs the completion of the operation and reports any unprocessed files.
- Provides a final summary message with the original number of files in the source folder, the original number of files in the target folder hierarchy, and the final number of files in the target folder hierarchy.
- Throws a warning if the sum of the original counts is not equal to the final count in the target.

Prerequisites:

- Ensure permissions for reading and writing in both source and target directories.
- The random name generator script should be located at: C:\Users\manoj\Documents\Scripts\randomname.ps1.

Limitations:

- The script does not handle nested directories in the source folder; only top-level files are processed.
#>

param(
    [string]$SourceFolder = "C:\Users\manoj\OneDrive\Desktop\New folder",
    [string]$TargetFolder = "D:\users\manoj\Documents\FIFA 07\elib",
    [int]$FilesPerFolderLimit = 20000,
    [string]$LogFilePath = "C:\users\manoj\Documents\Scripts\FileDistributor-log.txt",
    [string]$StateFilePath = "C:\users\manoj\Documents\Scripts\FileDistributor-State.json",
    [switch]$Restart,
    [switch]$ShowProgress = $false,
    [int]$UpdateFrequency = 100 # Default: 100 files
)

# Function to log messages
function LogMessage {
    param (
        [string]$Message,
        [switch]$ConsoleOutput,  # Explicit control for always printing to the console
        [switch]$IsError,        # Indicates if the message is an error
        [switch]$IsWarning       # Indicates if the message is a warning
    )
    # Get the timestamp and format the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp : $Message"

    # Append the log entry to the log file
    $logEntry | Add-Content -Path $LogFilePath

    # Use appropriate PowerShell cmdlet for errors, warnings, or console output
    if ($IsError) {
        Write-Error -Message $logEntry
    } elseif ($IsWarning) {
        Write-Warning -Message $logEntry
    } elseif ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
        Write-Host -Object $logEntry
    }
}

# Check if the random name generator script exists and load it
$randomNameScriptPath = "C:\Users\manoj\Documents\Scripts\randomname.ps1"

if (Test-Path -Path $randomNameScriptPath) {
    try {
        . $randomNameScriptPath
        if (-not (Get-Command -Name Get-RandomFileName -ErrorAction SilentlyContinue)) {
            throw "Failed to load the random name generator script."
        }
    }
    catch {
        LogMessage -Message "Failed to load the random name generator script from '$randomNameScriptPath'. $_" -IsError
        throw
    }
} else {
    LogMessage -Message "Random name generator script '$randomNameScriptPath' not found." -IsError
    throw "Random name generator script not found."
}

function ResolveFileNameConflict {
    param (
        [string]$TargetFolder,
        [string]$OriginalFileName
    )

    # Get the extension of the original file
    $extension = [System.IO.Path]::GetExtension($OriginalFileName)

    # Loop to generate a unique file name
    do {
        $newFileName = (Get-RandomFileName) + $extension
        $newFilePath = Join-Path -Path $TargetFolder -ChildPath $newFileName
    } while (Test-Path -Path $newFilePath)

    return $newFileName
}

function RenameFilesInSourceFolder {
    param (
        [string]$SourceFolder,
        [switch]$ShowProgress,
        [int]$UpdateFrequency
    )

    # Get all files in the source folder
    $files = Get-ChildItem -Path $SourceFolder -File
    $totalFiles = $files.Count
    $fileCount = 0

    foreach ($file in $files) {
        try {
            # Increment file counter
            $fileCount++

            # Show progress if enabled
            if ($ShowProgress -and ($fileCount % $UpdateFrequency -eq 0)) {
                $percentComplete = [math]::Floor(($fileCount / $totalFiles) * 100)
                Write-Progress -Activity "Renaming Files" `
                               -Status "Processing file $fileCount of $totalFiles" `
                               -PercentComplete $percentComplete
            }

            # Get the file extension
            $extension = $file.Extension
            do {
                # Generate a new random file name
                $newFileName = (Get-RandomFileName) + $extension
                $newFilePath = Join-Path -Path $SourceFolder -ChildPath $newFileName
            } while (Test-Path -Path $newFilePath)

            # Rename the file
            Rename-Item -LiteralPath $file.FullName -NewName $newFileName -Force
            LogMessage -Message "Renamed file $($file.FullName) to $newFileName"
        } catch {
            # Log error if renaming fails
            LogMessage -Message "Failed to rename file '$($file.FullName)': $_" -IsError
        }
    }
    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Renaming Files" -Status "Complete" -Completed
    }
    LogMessage -Message "Renaming completed: Processed $fileCount of $totalFiles files." -ConsoleOutput
}

function CreateRandomSubfolders {
    param (
        [string]$TargetPath,
        [int]$NumberOfFolders,
        [switch]$ShowProgress,
        [int]$UpdateFrequency
    )

    # Initialize an array to store created folder paths
    $createdFolders = @()

    for ($i = 1; $i -le $NumberOfFolders; $i++) {
        do {
            # Generate a random folder name
            $randomFolderName = Get-RandomFileName
            $folderPath = Join-Path -Path $TargetPath -ChildPath $randomFolderName
        } while (Test-Path -Path $folderPath)

        # Create the new directory
        New-Item -ItemType Directory -Path $folderPath | Out-Null
        $createdFolders += $folderPath

        # Log the creation of the folder
        LogMessage -Message "Created folder: $folderPath"

        # Show progress if enabled
        if ($ShowProgress -and ($i % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($i / $NumberOfFolders) * 100)
            Write-Progress -Activity "Creating Subfolders" `
                           -Status "Created $i of $NumberOfFolders folders" `
                           -PercentComplete $percentComplete
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Creating Subfolders" -Status "Complete" -Completed
    }

    return $createdFolders
}

function Move-ToRecycleBin {
    param (
        [string]$FilePath
    )

    # Create a new Shell.Application COM object
    $shell = New-Object -ComObject Shell.Application

    # 10 is the folder type for Recycle Bin
    $recycleBin = $shell.NameSpace(10)

    # Get the file to be moved to the Recycle Bin
    $file = Get-Item $FilePath

    # Move the file to the Recycle Bin, suppressing the confirmation dialog (0x100)
    $recycleBin.MoveHere($file.FullName, 0x100)
}

function DistributeFilesToSubfolders {
    param (
        [string[]]$Files,
        [string[]]$Subfolders,
        [int]$Limit,
        [switch]$ShowProgress,        # Enable/disable progress updates
        [int]$UpdateFrequency         # Frequency for progress updates
    )

    # Create an enumerator for subfolders to cycle through them
    $subfolderQueue = $Subfolders.GetEnumerator()
    $totalFiles = $Files.Count
    $fileCount = 0

    foreach ($file in $Files) {
        if (!$subfolderQueue.MoveNext()) {
            $subfolderQueue.Reset()
            $subfolderQueue.MoveNext() | Out-Null
        }

        $destinationFolder = $subfolderQueue.Current
        $fileName = [System.IO.Path]::GetFileName($file)
        $destinationFile = Join-Path -Path $destinationFolder -ChildPath $fileName

        if (Test-Path -Path $destinationFile) {
            $newFileName = ResolveFileNameConflict -TargetFolder $destinationFolder -OriginalFileName $file.Name
            $destinationFile = Join-Path -Path $destinationFolder -ChildPath $newFileName
        }

        Copy-Item -Path $file -Destination $destinationFile

        # Verify the file was copied successfully
        if (Test-Path -Path $destinationFile) {
            try {
                Move-ToRecycleBin -FilePath $file
                LogMessage -Message "Copied and moved to Recycle Bin: $file to $destinationFile"
            } catch {
                LogMessage -Message "Failed to move $($file.FullName) to Recycle Bin. Error: $($_.Exception.Message)" -IsWarning
            }
        } else {
            LogMessage -Message "Failed to copy $($file.FullName) to $destinationFile. Original file not moved." -IsError
        }

        # Increment file counter
        $fileCount++

        # Show progress if enabled
        if ($ShowProgress -and ($fileCount % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($fileCount / $totalFiles) * 100)
            Write-Progress -Activity "Distributing Files" `
                           -Status "Processing file $fileCount of $totalFiles" `
                           -PercentComplete $percentComplete
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Distributing Files" -Status "Complete" -Completed
    }

    LogMessage -Message "File distribution completed: Processed $fileCount of $totalFiles files." -ConsoleOutput
}

function RedistributeFilesInTarget {
    param (
        [string]$TargetFolder,
        [string[]]$Subfolders,
        [int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency 
    )

    # Get all files in the target folder and its subfolders
    $allFiles = Get-ChildItem -Path $TargetFolder -Recurse -File
    $folderFilesMap = @{}

    foreach ($subfolder in $Subfolders) {
        $folderFilesMap[$subfolder] = (Get-ChildItem -Path $subfolder -File).Count
    }

    # Redistribute files in the target folder (not in subfolders) regardless of limit
    LogMessage -Message "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -Path $TargetFolder -File
    DistributeFilesToSubfolders -Files $rootFiles -Subfolders $Subfolders -Limit $FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency

    LogMessage -Message "Redistributing files from subfolders..."
    foreach ($file in $allFiles) {
        $folder = $file.DirectoryName
        $currentFileCount = $folderFilesMap[$folder]

        if ($currentFileCount -gt $FilesPerFolderLimit) {
            LogMessage -Message "Renaming and redistributing files from folder: $folder"
            DistributeFilesToSubfolders -Files @($file) -Subfolders $Subfolders -Limit $FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
            $folderFilesMap[$folder]--
        }
    }
}

function SaveState {
    param (
        [int]$Checkpoint,
        [hashtable]$AdditionalVariables = @{}
    )

    # Ensure the state file exists
    if (-not (Test-Path -Path $StateFilePath)) {
        New-Item -Path $StateFilePath -ItemType File -Force | Out-Null
        LogMessage -Message "State file created at $StateFilePath"
    }

    # Combine state information
    $state = @{
        Checkpoint = $Checkpoint
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    # Merge additional variables into the state
    foreach ($key in $AdditionalVariables.Keys) {
        $state[$key] = $AdditionalVariables[$key]
    }

    # Save the state to the file in JSON format with appropriate depth
    $state | ConvertTo-Json -Depth 100 | Set-Content -Path $StateFilePath

    # Log the save operation
    LogMessage -Message "Saved state: Checkpoint $Checkpoint and additional variables: $($AdditionalVariables.Keys -join ', ')"
}

# Function to load state
function LoadState {
    if (Test-Path -Path $StateFilePath) {
        # Load and convert the state file from JSON format
        return Get-Content -Path $StateFilePath | ConvertFrom-Json
    } else {
        # Return a default state if the state file does not exist
        return @{ Checkpoint = 0 }
    }
}

# Function to extract paths from items
function ConvertItemsToPaths {
    param (
        [array]$Items
    )

    # Return the array of item full paths
    return $Items.FullName
}

# Function to convert paths to items
function ConvertPathsToItems {
    param (
        [array]$Paths
    )

    # Use pipeline to retrieve items for all paths and return them as an array
    return $Paths | ForEach-Object { Get-Item -Path $_ }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput
    LogMessage -Message "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilePerFolderLimit - $FilesPerFolderLimit"

    try {
        # Ensure source and target folders exist
        if (!(Test-Path -Path $SourceFolder)) {
            LogMessage -Message "Source folder '$SourceFolder' does not exist." -IsError
            throw "Source folder not found."
        }

        if (!($FilesPerFolderLimit -gt 0)) {
            LogMessage -Message "Incorrect value for FilesPerFolderLimit. Resetting to default: 20000." -IsWarning
            $FilesPerFolderLimit = 20000
        }

        if (!(Test-Path -Path $TargetFolder)) {
            LogMessage -Message "Target folder '$TargetFolder' does not exist. Creating it." -IsWarning
            New-Item -ItemType Directory -Path $TargetFolder -Force
        }

        LogMessage -Message "Parameter validation completed"

        # Restart logic
        $lastCheckpoint = 0
        if ($Restart) {
            LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput
            $state = LoadState
            $lastCheckpoint = $state.Checkpoint
            if ($lastCheckpoint -gt 0) {
                LogMessage -Message "Restarting from checkpoint $lastCheckpoint" -ConsoleOutput
            } else {
                LogMessage -Message "Checkpoint not found. Executing from top..." -IsWarning
            }

            # Load checkpoint-specific additional variables
            if ($lastCheckpoint -in 2, 3, 4) {
                $totalSourceFiles = $state.totalSourceFiles
                $totalTargetFilesBefore = $state.totalTargetFilesBefore
            }

            if ($lastCheckpoint -in 2, 3) {
                $subfolders = ConvertPathsToItems($state.subfolders)
            }

            if ($lastCheckpoint -eq 2) {
                $sourceFiles = ConvertPathsToItems($state.sourceFiles)
            }
        } else {
            # Check if a restart state file exists
            if (Test-Path -Path $StateFilePath) {
                LogMessage -Message "Restart state file found but restart not requested. Deleting state file..." -IsWarning
                Remove-Item -Path $StateFilePath -Force
            }
        }

        if ($lastCheckpoint -lt 1) {
            # Rename files in the source folder to random names
            LogMessage -Message "Renaming files in source folder..."
            RenameFilesInSourceFolder -SourceFolder $SourceFolder -ShowProgress:$ShowProgress -UpdateFrequency $UpdateFrequency
            SaveState -Checkpoint 1
        }

        if ($lastCheckpoint -lt 2) {
            # Count files in the source and target folder before distribution
            $sourceFiles = Get-ChildItem -Path $SourceFolder -File
            $totalSourceFiles = $sourceFiles.Count
            $totalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
            $totalTargetFilesBefore = if ($null -eq $totalTargetFilesBefore) { 0 } else { $totalTargetFilesBefore }
            LogMessage -Message "Source File Count: $totalSourceFiles. Target File Count Before: $totalTargetFilesBefore."

            # Get subfolders in the target folder
            $subfolders = Get-ChildItem -Path $TargetFolder -Directory

            # Determine if subfolders need to be created
            $totalFiles = $totalTargetFilesBefore + $totalSourceFiles
            LogMessage -Message "Total Files Before: $totalFiles."
            $currentFolderCount = $subfolders.Count
            LogMessage -Message "Sub-folder Count Before: $currentFolderCount."

            if ($totalFiles / $FilesPerFolderLimit -gt $currentFolderCount) {
                $additionalFolders = [math]::Ceiling($totalFiles / $FilesPerFolderLimit) - $currentFolderCount
                LogMessage -Message "Need to create $additionalFolders subfolders"
                $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
            }

            $additionalVars = @{
                sourceFiles = ConvertItemsToPaths($sourceFiles)
                totalSourceFiles = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders = ConvertItemsToPaths($subfolders)
            }

            SaveState -Checkpoint 2 -AdditionalVariables $additionalVars
        }

        if ($lastCheckpoint -lt 3) {
            # Distribute files from the source folder to subfolders
            LogMessage -Message "Distributing files to subfolders..."
            DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -Limit $FilesPerFolderLimit
            LogMessage -Message "Completed file distribution"

            $additionalVars = @{
                totalSourceFiles = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders = ConvertItemsToPaths($subfolders)
            }
        
            SaveState -Checkpoint 3 -AdditionalVariables $additionalVars
        }

        if ($lastCheckpoint -lt 4) {
            # Redistribute files within the target folder and subfolders if needed
            LogMessage -Message "Redistributing files in target folders..."
            RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency

            $additionalVars = @{
                totalSourceFiles = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
            }
            SaveState -Checkpoint 4 -AdditionalVariables $additionalVars
        }

        # Count files in the target folder after distribution
        $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
        $totalTargetFilesAfter = if ($null -eq $totalTargetFilesAfter) { 0 } else { $totalTargetFilesAfter }

        # Log summary message
        LogMessage -Message "Original number of files in the source folder: $totalSourceFiles" -ConsoleOutput
        LogMessage -Message "Original number of files in the target folder hierarchy: $totalTargetFilesBefore" -ConsoleOutput
        LogMessage -Message "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput

        if ($totalSourceFiles + $totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage -Message "Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -IsWarning
        } else {
            LogMessage -Message "File distribution and cleanup completed successfully." -ConsoleOutput
        }

        Remove-Item -Path $StateFilePath -Force

    } catch {
        LogMessage -Message "$($_.Exception.Message)" -IsError
    }
}
 
 # Run the script
 Main
 