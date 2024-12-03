<# 
.SYNOPSIS
This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It also moves the original files to the Recycle Bin after ensuring successful copying and resolves file name conflicts.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, with a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created as needed. Files in the target folder (not in subfolders) are also redistributed. File name conflicts are resolved using a custom random name generator. The script validates file copying before moving the original files to the Recycle Bin from the source folder and logs its actions in a log file. Additional details can be viewed using PowerShell's `-Verbose` switch.

.PARAMETER SourceFolder
Mandatory. Specifies the path to the source folder containing the files to be copied.

.PARAMETER TargetFolder
Mandatory. Specifies the path to the target folder where the files will be distributed.

.PARAMETER FilesPerFolderLimit
Optional. Specifies the maximum number of files allowed in each subfolder of the target folder. Defaults to 20,000.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file for recording script activities. Defaults to "file_copy_log.txt" in the current directory.

.EXAMPLES
To copy files from "C:\Source" to "C:\Target" with a default file limit:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target"

To copy files with a custom file limit and log to a specific file:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -FilesPerFolderLimit 10000 -LogFilePath "C:\Logs\copy_log.txt"

To enable verbose logging using PowerShell's built-in `-Verbose` switch:
.\FileDistribution.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Verbose

.NOTES
Script Workflow:

Initialization:

- Validates input parameters and checks if the source and target folders exist.
- Initializes logging and ensures the random name generator script is available.

Subfolder Management:

- Counts existing subfolders in the target folder.
- Creates new subfolders only if required to maintain the file limit.

File Processing:

- Files are copied from the source folder to the target subfolders.
- Files in the target folder (not in subfolders) are redistributed regardless of the limit.
- File name conflicts are resolved using the random name generator.
- Successful copying is verified before moving the original files to the Recycle Bin.

Error Handling:

- Logs errors during file operations and skips problematic files without stopping the script.

Completion:

- Logs completion of the operation and reports any unprocessed files.
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
    [switch]$Restart
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
    $logEntry | Out-File -FilePath $LogFilePath -Append

    # Use appropriate PowerShell cmdlet for errors, warnings, or console output
    if ($IsError) {
        Write-Error $logEntry
    } elseif ($IsWarning) {
        Write-Warning $logEntry
    } elseif ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
        Write-Host $logEntry
    }
}

# Check if the random name generator script exists and load it
$randomNameScriptPath = "C:\Users\manoj\Documents\Scripts\randomname.ps1"
if (Test-Path -Path $randomNameScriptPath) {
    . $randomNameScriptPath
    if (-not (Get-Command -Name Get-RandomFileName -ErrorAction SilentlyContinue)) {
        LogMessage -Message "ERROR: Failed to load the random name generator script from '$randomNameScriptPath'." -IsError
        throw "Failed to load the random name generator script."
    }
} else {
    LogMessage -Message "ERROR: Random name generator script '$randomNameScriptPath' not found." -IsError
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
        $newFileName = Get-RandomFileName
        $newFullFileName = $newFileName + $extension
        $newFilePath = Join-Path -Path $TargetFolder -ChildPath $newFullFileName
    } while (Test-Path -Path $newFilePath)
    return $newFileName
}

# Function to rename files in the source folder to random names
function RenameFilesInSourceFolder {
    param (
        [string]$SourceFolder
    )
    $files = Get-ChildItem -Path $SourceFolder -File

    foreach ($file in $files) {
        try {
            $extension = $file.Extension
            do {
                $newFileName = Get-RandomFileName
                $newFullFileName = $newFileName + $extension
                $newFilePath = Join-Path -Path $SourceFolder -ChildPath $newFullFileName
            } while (Test-Path -Path $newFilePath)

            # Rename the file
            Rename-Item -LiteralPath $file.FullName -NewName $newFullFileName -Force
            LogMessage -Message "Renamed file $($file.FullName) to $newFullFileName"
        } catch {
            LogMessage -Message "ERROR: Failed to rename file '$($file.FullName)': $_" -IsError
        }
    }
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
        LogMessage -Message "Created folder: $folderPath"
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
                LogMessage -Message "Copied and moved to Recycle Bin: $($file.FullName) to $destinationFile"
            } catch {
                LogMessage -Message "ERROR: Failed to move $($file.FullName) to Recycle Bin. Error: $($_.Exception.Message)" -IsError
            }
        } else {
            LogMessage -Message "ERROR: Failed to copy $($file.FullName) to $destinationFile. Original file not moved." -IsError
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
    LogMessage -Message "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -Path $TargetFolder -File
    DistributeFilesToSubfolders -Files $rootFiles -Subfolders $Subfolders -Limit $FilesPerFolderLimit
    LogMessage -Message "Completed file redistribution from target folder"

    LogMessage -Message "Redistributing files from subfolders..."
    foreach ($file in $allFiles) {
        $folder = $file.DirectoryName
        $currentFileCount = $folderFilesMap[$folder]

        if ($currentFileCount -gt $FilesPerFolderLimit) {
            LogMessage -Message "Renaming and redistributing files from folder: $folder"
            DistributeFilesToSubfolders -Files @($file) -Subfolders $Subfolders -Limit $FilesPerFolderLimit
            $folderFilesMap[$folder]--
        }
    }
}

# Function to save state
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

    Write-Host "Output 2::"
    Write-Host $state

    # Save the state to the file
    $state | ConvertTo-Json -Depth 100 | Set-Content -Path $StateFilePath

    # Log the save operation
    LogMessage -Message "Saved state: Checkpoint $Checkpoint and additional variables: $($AdditionalVariables.Keys -join ', ')"
}

# Function to load state
function LoadState {
    if (Test-Path -Path $StateFilePath) {
        return Get-Content -Path $StateFilePath | ConvertFrom-Json
    } else {
        # Default state if no file exists
        return @{ Checkpoint = 0 }
    }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput
    LogMessage -Message "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilePerFolderLimit - $FilesPerFolderLimit"
    try {
        # Ensure source and target folders exist
        if (!(Test-Path -Path $SourceFolder)) {
            LogMessage -Message "ERROR: Source folder '$SourceFolder' does not exist." -IsError
            throw "Source folder not found."
        }
        if(!($FilesPerFolderLimit -gt 0)) {
            LogMessage -Message "WARNING: Incorrect value for FilesPerFolderLimit. Resetting to default: 20000." -IsWarning
            $FilesPerFolderLimit = 20000
        }
        if (!(Test-Path -Path $TargetFolder)) {
            LogMessage -Message "WARNING: Target folder '$TargetFolder' does not exist. Creating it." -IsWarning
            New-Item -ItemType Directory -Path $TargetFolder
        }
        LogMessage -Message "Parameter validation completed"

        #Restart logic
        $lastCheckpoint = 0
        if ($Restart) {
            LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput
            $state = LoadState
            $lastCheckpoint = $state.Checkpoint
            if ($lastCheckpoint -gt 0) {
                LogMessage -Message "Restarting from checkpoint $lastCheckpoint"
            } else {
                LogMessage -Message "WARNING: Checkpoint not found. Executing from top..." -IsWarning
            }
        } else {
            # Check if a restart state file exists
            if (Test-Path -Path $StateFilePath) {
                LogMessage -Message "WARNING: Restart state file found but restart not requested. Deleting state file..." -IsWarning
                Remove-Item -Path $StateFilePath -Force
            }
        }

        If ($lastCheckpoint -lt 1) {
            # Rename files in the source folder to random names
            LogMessage -Message "Renaming files in source folder..."
            RenameFilesInSourceFolder -SourceFolder $SourceFolder
            LogMessage -Message "File rename completed"
            SaveState -Checkpoint 1
        }

        If ($lastCheckpoint -lt 2) {
            # Count files in the source and target folder before distribution
            $sourceFiles = Get-ChildItem -Path $SourceFolder -File
            $totalSourceFiles = $sourceFiles.Count
            $totalTargetFilesBefore = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
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
                $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders
            }

            $additionalVars = @{
                sourceFiles = $sourceFiles
                totalSourceFiles = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
            }

            $subfolderPaths = $subfolders.$newFullFileName
            $additionalVars["subfolders"] = $subfolderPaths
            Write-Host: "Output 1:"
            Write-Host $additionalVars

            SaveState -Checkpoint 2 -AdditionalVariables $additionalVars
        }
        exit
        If ($lastCheckpoint -lt 3) {
            # Distribute files from the source folder to subfolders
            LogMessage -Message "Distributing files to subfolders..."
            DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -Limit $FilesPerFolderLimit
            LogMessage -Message "Completed file distribution"
        
            SaveState -Checkpoint 3
        }

        if ($lastCheckpoint -lt 4) {
            # Redistribute files within the target folder and subfolders if needed
            LogMessage -Message "Redistributing files in target folders..."
            RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders -FilesPerFolderLimit $FilesPerFolderLimit

            SaveState -Checkpoint 4
        }

         # Count files in the target folder after distribution
         $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
 
         # Log summary message
         LogMessage "Original number of files in the source folder: $totalSourceFiles" -ConsoleOutput
         LogMessage "Original number of files in the target folder hierarchy: $totalTargetFilesBefore" -ConsoleOutput
         LogMessage "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput
 
         if ($totalSourceFiles + $totalTargetFilesBefore -ne $totalTargetFilesAfter) {
             LogMessage "WARNING: Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -IsWarning
         } else {
             LogMessage "File distribution and cleanup completed successfully." -ConsoleOutput
         }
 
     } catch {
         LogMessage "ERROR: $($_.Exception.Message)" -IsError
     }
 }
 
 # Run the script
 Main
 
