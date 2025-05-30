<#
.SYNOPSIS
This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It supports configurable deletion modes, progress updates, and automatic conflict resolution for file names.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed. 

File name conflicts are resolved using a custom random name generator. After ensuring successful copying, the script handles the original files based on the specified `DeleteMode`:

- `RecycleBin`: Moves the files to the Recycle Bin.
- `Immediate`: Deletes the files immediately after successful copying.
- `EndOfScript`: Deletes the files at the end of the script if no critical errors or warnings (as configured) are encountered.

All actions are logged to a specified log file. Progress updates are displayed during processing if enabled, configurable by file count.

.PARAMETER SourceFolder
Mandatory. Specifies the path to the source folder containing the files to be copied.

.PARAMETER TargetFolder
Mandatory. Specifies the path to the target folder where the files will be distributed.

.PARAMETER FilesPerFolderLimit
Optional. Specifies the maximum number of files allowed in each subfolder of the target folder. Defaults to 20,000.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file for recording script activities. Defaults to "FileDistributor-log.txt" in the current directory.

.PARAMETER Restart
Optional. If specified, the script will restart from the last checkpoint, resuming its previous state.

.PARAMETER ShowProgress
Optional. Displays progress updates during the script's execution. Use this parameter to enable progress reporting.

.PARAMETER UpdateFrequency
Optional. Specifies how often progress updates are displayed. Can be set to a specific file count (e.g., every 100 files). Defaults to 100.

.PARAMETER DeleteMode
Optional. Specifies how the original files should be handled after successful copying. Options are:
- `RecycleBin`: Moves the files to the Recycle Bin (default).
- `Immediate`: Deletes the files immediately after copying.
- `EndOfScript`: Deletes the files at the end of the script if conditions are met.

.PARAMETER EndOfScriptDeletionCondition
Optional. Specifies the conditions under which files are deleted in `EndOfScript` mode. Options are:
- `NoWarnings`: Deletes files only if there are no warnings or errors (default).
- `WarningsOnly`: Deletes files if there are no errors, even if warnings exist.

.PARAMETER RetryDelay
Optional. Specifies the delay in seconds before retrying file access if locked. Defaults to 10 seconds.

.PARAMETER RetryCount
Optional. Specifies the number of times to retry file access if locked. Defaults to 1. A value of 0 means unlimited retries.

.PARAMETER CleanupDuplicates
Optional. If specified, invokes the duplicate file removal script after distribution.

.PARAMETER CleanupEmptyFolders
Optional. If specified, invokes the empty folder cleanup script after distribution.

.PARAMETER TruncateLog
Optional. If specified, the log file will be truncated (cleared) at the start of the script. This option is ignored during a restart.

.PARAMETER TruncateIfLarger
Optional. Specifies a size threshold for truncating the log file at the start of the script. The size can be specified in formats like 1K (kilobytes), 2M (megabytes), or 3G (gigabytes). This option is ignored during a restart.

.PARAMETER RemoveEntriesBefore
Optional. Specifies a timestamp in the format "YYYY-MM-DD HH:MM:SS" or ISO 8601. All log entries before this timestamp will be removed.

.PARAMETER RemoveEntriesOlderThan
Optional. Specifies an age in days. All log entries older than the specified number of days will be removed.

.PARAMETER Help
Optional. Displays the script's synopsis/help text and exits without performing any operations.

.EXAMPLES
To copy files from "C:\Source" to "C:\Target" with a default file limit:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target"

To copy files with progress updates every 50 files:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -ShowProgress -UpdateFrequency 50

To restart the script from the last checkpoint:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Restart

To delete files immediately after copying:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -DeleteMode Immediate

To delete files at the end of the script only if no warnings occur:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -DeleteMode EndOfScript -EndOfScriptDeletionCondition NoWarnings

To enable verbose logging using PowerShell's built-in `-Verbose` switch:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Verbose

To invoke cleanup scripts for duplicates and empty folders:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -CleanupDuplicates -CleanupEmptyFolders

To truncate the log file and start afresh:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -TruncateLog

To truncate the log file if it exceeds 10 megabytes:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -TruncateIfLarger 10M

To remove log entries before a specific timestamp:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -RemoveEntriesBefore "2023-01-01 00:00:00"

To remove log entries older than 30 days:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -RemoveEntriesOlderThan 30

To display the script's help text:
.\FileDistributor.ps1 -Help

.NOTES
Script Workflow:

Initialization:
- Validates input parameters and checks if the source and target folders exist.
- Initializes logging and ensures the random name generator script is available.

Subfolder Management:
- Counts existing subfolders in the target folder.
- Creates new subfolders as needed while providing progress updates if enabled.

File Processing:
- Files are copied from the source folder to subfolders.
- Files in the target folder (not in subfolders) are redistributed to adhere to folder limits.
- File name conflicts are resolved using the random name generator.
- Successful copying is verified before handling the original files based on the `DeleteMode`.
- Progress updates are displayed based on the specified `UpdateFrequency`.

Deletion Modes:
- Handles files according to the `DeleteMode`:
  - `RecycleBin`: Moves files to the Recycle Bin.
  - `Immediate`: Deletes files immediately.
  - `EndOfScript`: Deletes files conditionally at the end of the script.

Error Handling:
- Logs errors and warnings with detailed messages during file operations.
- Skips problematic files without stopping the script.

Completion:
- Logs the completion of the operation and reports any unprocessed files.
- Provides a final summary message, including the original number of files in the source folder, the original number of files in the target folder hierarchy, and the final number of files in the target folder hierarchy.
- Throws a warning if the sum of the original counts is not equal to the final count in the target.

Post-Processing:
- Optionally invokes cleanup scripts for duplicate files and empty folders based on parameters.

Prerequisites:
- Ensure permissions for reading and writing in both source and target directories.
- The random name generator script should be located at: `C:\Users\manoj\Documents\Scripts\src\powershell\randomname.ps1`.

Limitations:
- The script does not handle nested directories in the source folder; only top-level files are processed.
#>

param(
    [string]$SourceFolder = "C:\Users\manoj\OneDrive\Desktop\New folder",
    [string]$TargetFolder = "D:\users\manoj\Documents\FIFA 07\elib",
    [int]$FilesPerFolderLimit = 20000,
    [string]$LogFilePath = "C:\users\manoj\Documents\Scripts\FileDistributor-log.txt",
    [string]$StateFilePath = "C:\users\manoj\Documents\Scripts\temp\FileDistributor-State.json",
    [switch]$Restart,
    [switch]$ShowProgress = $false,
    [int]$UpdateFrequency = 100, # Default: 100 files
    [string]$DeleteMode = "RecycleBin", # Options: "RecycleBin", "Immediate", "EndOfScript"
    [string]$EndOfScriptDeletionCondition = "NoWarnings", # Options: "NoWarnings", "WarningsOnly"
    [int]$RetryDelay = 10, # Time to wait before retrying file access (seconds)
    [int]$RetryCount = 3, # Number of times to retry file access (0 for unlimited retries)
    [switch]$CleanupDuplicates,
    [switch]$CleanupEmptyFolders,
    [switch]$TruncateLog,
    [string]$TruncateIfLarger,
    [string]$RemoveEntriesBefore,
    [int]$RemoveEntriesOlderThan,
    [switch]$Help
)

# Display help and exit if -Help is specified
if ($Help) {
    Write-Host "FileDistributor.ps1 - File Distribution Script" -ForegroundColor Cyan
    Write-Host "`nSYNOPSIS" -ForegroundColor Yellow
    Write-Host "This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It supports configurable deletion modes, progress updates, and automatic conflict resolution for file names." -ForegroundColor White

    Write-Host "`nDESCRIPTION" -ForegroundColor Yellow
    Write-Host "The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed." -ForegroundColor White

    Write-Host "`nPARAMETERS" -ForegroundColor Yellow
    Write-Host "- SourceFolder:" -ForegroundColor Green
    Write-Host "  Mandatory. Specifies the path to the source folder containing the files to be copied." -ForegroundColor White
    Write-Host "- TargetFolder:" -ForegroundColor Green
    Write-Host "  Mandatory. Specifies the path to the target folder where the files will be distributed." -ForegroundColor White
    Write-Host "- FilesPerFolderLimit:" -ForegroundColor Green
    Write-Host "  Optional. Maximum number of files allowed in each subfolder. Defaults to 20,000." -ForegroundColor White
    Write-Host "- LogFilePath:" -ForegroundColor Green
    Write-Host "  Optional. Path to the log file for recording script activities. Defaults to 'FileDistributor-log.txt'." -ForegroundColor White
    Write-Host "- Restart:" -ForegroundColor Green
    Write-Host "  Optional. Resumes the script from the last checkpoint." -ForegroundColor White
    Write-Host "- ShowProgress:" -ForegroundColor Green
    Write-Host "  Optional. Displays progress updates during execution." -ForegroundColor White
    Write-Host "- UpdateFrequency:" -ForegroundColor Green
    Write-Host "  Optional. Frequency of progress updates. Defaults to 100 files." -ForegroundColor White
    Write-Host "- DeleteMode:" -ForegroundColor Green
    Write-Host "  Optional. Specifies how original files are handled after copying. Options: RecycleBin (default), Immediate, EndOfScript." -ForegroundColor White
    Write-Host "- EndOfScriptDeletionCondition:" -ForegroundColor Green
    Write-Host "  Optional. Conditions for deletion in EndOfScript mode. Options: NoWarnings (default), WarningsOnly." -ForegroundColor White
    Write-Host "- RetryDelay:" -ForegroundColor Green
    Write-Host "  Optional. Delay in seconds before retrying file access. Defaults to 10 seconds." -ForegroundColor White
    Write-Host "- RetryCount:" -ForegroundColor Green
    Write-Host "  Optional. Number of retries for file access. Defaults to 1." -ForegroundColor White
    Write-Host "- CleanupDuplicates:" -ForegroundColor Green
    Write-Host "  Optional. Invokes duplicate file removal script after distribution." -ForegroundColor White
    Write-Host "- CleanupEmptyFolders:" -ForegroundColor Green
    Write-Host "  Optional. Invokes empty folder cleanup script after distribution." -ForegroundColor White
    Write-Host "- TruncateLog:" -ForegroundColor Green
    Write-Host "  Optional. Clears the log file at the start of the script." -ForegroundColor White
    Write-Host "- TruncateIfLarger:" -ForegroundColor Green
    Write-Host "  Optional. Truncates the log file if it exceeds a specified size." -ForegroundColor White
    Write-Host "- RemoveEntriesBefore:" -ForegroundColor Green
    Write-Host "  Optional. Removes log entries before a specific timestamp." -ForegroundColor White
    Write-Host "- RemoveEntriesOlderThan:" -ForegroundColor Green
    Write-Host "  Optional. Removes log entries older than a specified number of days." -ForegroundColor White
    Write-Host "- Help:" -ForegroundColor Green
    Write-Host "  Displays this help text and exits." -ForegroundColor White

    Write-Host "`nEXAMPLES" -ForegroundColor Yellow
    Write-Host "To copy files from 'C:\Source' to 'C:\Target' with a default file limit:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target'" -ForegroundColor DarkCyan
    Write-Host "`nTo display progress updates every 50 files:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target' -ShowProgress -UpdateFrequency 50" -ForegroundColor DarkCyan
    Write-Host "`nTo restart the script from the last checkpoint:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target' -Restart" -ForegroundColor DarkCyan
    Write-Host "`nTo display this help text:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -Help" -ForegroundColor DarkCyan

    Write-Host "`nNOTES" -ForegroundColor Yellow
    Write-Host "Ensure permissions for reading and writing in both source and target directories." -ForegroundColor White
    Write-Host "The random name generator script should be located at: 'C:\Users\manoj\Documents\Scripts\src\powershell\randomname.ps1'." -ForegroundColor White

    exit
}

# Define script-scoped variables for warnings and errors
$script:Warnings = 0
$script:Errors = 0

# Define the script directory
$ScriptDirectory = "C:\Users\manoj\Documents\Scripts\src\powershell"

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
    $logEntry = "$($timestamp): $($Message)"

    # Append the log entry to the log file
    $logEntry | Add-Content -Path $LogFilePath

    # Use appropriate PowerShell cmdlet for errors, warnings, or console output
    if ($IsError) {
        Write-Error -Message $logEntry
        $script:Errors++
    } elseif ($IsWarning) {
        Write-Warning -Message $logEntry
        $script:Warnings++
    } elseif ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
        Write-Host -Object $logEntry
    }
}

# Check if the random name generator script exists and load it
$randomNameScriptPath = Join-Path -Path $ScriptDirectory -ChildPath "randomname.ps1"

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

    try {
        # Create a new Shell.Application COM object
        $shell = New-Object -ComObject Shell.Application

        # 10 is the folder type for Recycle Bin
        $recycleBin = $shell.NameSpace(10)

        # Get the file to be moved to the Recycle Bin
        $file = Get-Item $FilePath

        # Move the file to the Recycle Bin, suppressing the confirmation dialog (0x100)
        $recycleBin.MoveHere($file.FullName, 0x100)

        # Log success
        LogMessage -Message "Moved $FilePath to Recycle Bin."
    } catch {
        # Log failure
        LogMessage -Message "Failed to move $FilePath to Recycle Bin. Error: $($_.Exception.Message)" -IsWarning
    }
}

# Function to delete files
function Remove-File {
    param (
        [string]$FilePath
    )

    try {
        # Check if the file exists before attempting deletion
        if (Test-Path -Path $FilePath) {
            Remove-Item -Path $FilePath -Force
            LogMessage -Message "Deleted file: $FilePath."
        } else {
            LogMessage -Message "File $FilePath not found. Skipping deletion." -IsWarning
        }
    } catch {
        # Log failure
        LogMessage -Message "Failed to delete file $FilePath. Error: $($_.Exception.Message)" -IsWarning
    }
}

function DistributeFilesToSubfolders {
    param (
        [string[]]$Files,
        [string[]]$Subfolders,
        [int]$Limit,
        [switch]$ShowProgress,        # Enable/disable progress updates
        [int]$UpdateFrequency,       # Frequency for progress updates
        [string]$DeleteMode,         # Specifies the deletion mode
        [ref]$FilesToDelete,         # Reference to the files pending deletion
        [ref]$GlobalFileCounter,     # Reference to a global file counter
        [int]$TotalFiles             # Total number of files to process
    )

    # Create an enumerator for subfolders to cycle through them
    $subfolderQueue = $Subfolders.GetEnumerator()

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
                # Handle file deletion based on DeleteMode
                if ($DeleteMode -eq "RecycleBin") {
                    Move-ToRecycleBin -FilePath $file
                    LogMessage -Message "Copied from $file to $destinationFile and moved original to Recycle Bin."
                } elseif ($DeleteMode -eq "Immediate") {
                    Remove-File -FilePath $file
                    LogMessage -Message "Copied from $file to $destinationFile and immediately deleted original."
                } elseif ($DeleteMode -eq "EndOfScript") {
                    # Ensure FilesToDelete.Value is initialized as an array
                    if (-not $FilesToDelete.Value) {
                        $FilesToDelete.Value = @()
                    }
                    $FilesToDelete.Value += $file  # Correctly update the ref variable
                    LogMessage -Message "Copied from $file to $destinationFile. Original pending deletion at end of script."
                }
            } catch {
                LogMessage -Message "Failed to process file $file after copying to $destinationFile. Error: $($_.Exception.Message)" -IsWarning
            }
        } else {
            LogMessage -Message "Failed to copy $file to $destinationFile. Original file not moved." -IsError
        }

        # Increment the global file counter
        $GlobalFileCounter.Value++

        # Show progress if enabled and only after every $UpdateFrequency files
        if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($GlobalFileCounter.Value / $TotalFiles) * 100)
            Write-Progress -Activity "Distributing Files" `
                           -Status "Processed $($GlobalFileCounter.Value) of $TotalFiles files" `
                           -PercentComplete $percentComplete
            LogMessage -Message "Processed $($GlobalFileCounter.Value) of $TotalFiles files." -ConsoleOutput
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Distributing Files" -Status "Complete" -Completed
    }
    LogMessage -Message "File distribution completed: Processed $($GlobalFileCounter.Value) of $TotalFiles files." -ConsoleOutput
}

function RedistributeFilesInTarget {
    param (
        [string]$TargetFolder,
        [string[]]$Subfolders,
        [int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency,
        [string]$DeleteMode,
        [ref]$FilesToDelete,
        [ref]$GlobalFileCounter,
        [int]$TotalFiles
    )

    # Step 1: Build initial folder file count map
    $folderFilesMap = @{}
    foreach ($subfolder in $Subfolders) {
        $folderFilesMap[$subfolder] = (Get-ChildItem -Path $subfolder -File).Count
    }

    # Step 2: Redistribute files from root of target folder (not subfolders)
    LogMessage -Message "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -Path $TargetFolder -File

    if ($rootFiles.Count -gt 0) {
        $eligibleTargets = $folderFilesMap.GetEnumerator() |
            Where-Object { $_.Value -lt $FilesPerFolderLimit } |
            ForEach-Object { $_.Key }

        if ($eligibleTargets.Count -eq 0) {
            # Create a new subfolder using Get-RandomFileName
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            LogMessage -Message "Created new target subfolder: $newFolder for redistribution from root folder."

            # Update maps
            $eligibleTargets = @($newFolder)
            $Subfolders += $newFolder
            $folderFilesMap[$newFolder] = 0
        }

        DistributeFilesToSubfolders -Files $rootFiles `
            -Subfolders $eligibleTargets `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $TotalFiles
    }

    # Step 3: Identify overloaded folders and select random files for redistribution
    $filesToRedistributeMap = @{}

    foreach ($folder in $folderFilesMap.Keys) {
        $fileCount = $folderFilesMap[$folder]
        if ($fileCount -gt $FilesPerFolderLimit) {
            $excess = $fileCount - $FilesPerFolderLimit
            $overloadedFiles = Get-ChildItem -Path $folder -File | Get-Random -Count $excess
            $filesToRedistributeMap[$folder] = $overloadedFiles
            LogMessage -Message "Folder $folder is overloaded by $excess file(s), queuing for redistribution."
        }
    }

    # Step 4: Redistribute files from overloaded folders, excluding the source folder from targets
    foreach ($sourceFolder in $filesToRedistributeMap.Keys) {
        $sourceFiles = $filesToRedistributeMap[$sourceFolder]

        $eligibleTargets = $folderFilesMap.GetEnumerator() |
            Where-Object {
                $_.Key -ne $sourceFolder -and $_.Value -lt $FilesPerFolderLimit
            } |
            ForEach-Object { $_.Key }

        if ($eligibleTargets.Count -eq 0) {
            # Create a new subfolder using Get-RandomFileName
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            LogMessage -Message "Created new target subfolder: $newFolder for redistribution from overloaded folder $sourceFolder."

            # Update maps
            $eligibleTargets = @($newFolder)
            $Subfolders += $newFolder
            $folderFilesMap[$newFolder] = 0
        }

        DistributeFilesToSubfolders -Files $sourceFiles `
            -Subfolders $eligibleTargets `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $TotalFiles
    }

    LogMessage -Message "File redistribution completed: Processed $($GlobalFileCounter.Value) of $TotalFiles files in the target folder."
}

function SaveState {
    param (
        [int]$Checkpoint,
        [hashtable]$AdditionalVariables = @{ },
        [ref]$fileLock
    )

    # Release the file lock before saving state
    ReleaseFileLock -FileStream $fileLock.Value

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

    # Reacquire the file lock after saving state
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
}

# Function to load state
function LoadState {
    param (
        [ref]$fileLock
    )

    # Release the file lock before loading state
    ReleaseFileLock -FileStream $fileLock.Value

    if (Test-Path -Path $StateFilePath) {
        # Load and convert the state file from JSON format
        $state = Get-Content -Path $StateFilePath | ConvertFrom-Json
    } else {
        # Return a default state if the state file does not exist
        $state = @{ Checkpoint = 0 }
    }

    # Reacquire the file lock after loading state
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount

    return $state
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

# Function to acquire a lock on the state file
function AcquireFileLock {
    param (
        [string]$FilePath,
        [int]$RetryDelay,
        [int]$RetryCount
    )

    $attempts = 0
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($FilePath, 'OpenOrCreate', 'ReadWrite', 'None')
            LogMessage -Message "Acquired lock on $FilePath"
            return $fileStream
        } catch {
            $attempts++
            if ($RetryCount -ne 0 -and $attempts -ge $RetryCount) {
                LogMessage -Message "Failed to acquire lock on $FilePath after $attempts attempts. Aborting." -IsError
                throw "Failed to acquire lock on $FilePath after $attempts attempts."
            }
            LogMessage -Message "Failed to acquire lock on $FilePath. Retrying in $RetryDelay seconds... (Attempt $attempts)" -IsWarning
            Start-Sleep -Seconds $RetryDelay
        }
    }
}

# Function to release the file lock
function ReleaseFileLock {
    param (
        [System.IO.FileStream]$FileStream
    )

    $fileName = $FileStream.Name
    $FileStream.Close()
    $FileStream.Dispose()
    LogMessage -Message "Released lock on $fileName"
}

# Function to convert size string to bytes
function ConvertToBytes {
    param (
        [string]$Size
    )
    if ($Size -match '^(\d+)([KMG])$') {
        $value = [int]$matches[1]
        switch ($matches[2]) {
            'K' { return $value * 1KB }
            'M' { return $value * 1MB }
            'G' { return $value * 1GB }
        }
    } else {
        throw "Invalid size format: $Size. Use formats like 1K, 2M, or 3G."
    }
}

# Function to remove log entries based on timestamp or age
function RemoveLogEntries {
    param (
        [string]$LogFilePath,
        [datetime]$BeforeTimestamp,
        [int]$OlderThanDays
    )

    try {
        if (-not (Test-Path -Path $LogFilePath)) {
            LogMessage -Message "Log file not found: $LogFilePath. Skipping log entry removal." -IsWarning
            return
        }

        $logEntries = Get-Content -Path $LogFilePath
        $filteredEntries = @()

        foreach ($entry in $logEntries) {
            if ($entry -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                $entryTimestamp = [datetime]::ParseExact($matches[0], "yyyy-MM-dd HH:mm:ss", $null)

                if ($BeforeTimestamp -and $entryTimestamp -ge $BeforeTimestamp) {
                    $filteredEntries += $entry
                } elseif ($OlderThanDays -and $entryTimestamp -ge (Get-Date).AddDays(-$OlderThanDays)) {
                    $filteredEntries += $entry
                }
            } else {
                # Preserve entries without a valid timestamp
                $filteredEntries += $entry
            }
        }

        # Overwrite the log file with filtered entries
        $filteredEntries | Set-Content -Path $LogFilePath
        LogMessage -Message "Log entries filtered successfully. Updated log file: $LogFilePath"
    } catch {
        LogMessage -Message "Failed to filter log entries: $($_.Exception.Message)" -IsError
    }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput

    # Handle log entry removal
    if (-not $Restart) {
        $beforeTimestamp = $null
        if ($RemoveEntriesBefore) {
            try {
                $beforeTimestamp = [datetime]::Parse($RemoveEntriesBefore)
            } catch {
                LogMessage -Message "Invalid timestamp format for RemoveEntriesBefore: $RemoveEntriesBefore" -IsError
                throw "Invalid timestamp format. Use 'YYYY-MM-DD HH:MM:SS' or ISO 8601."
            }
        }

        if ($RemoveEntriesOlderThan -lt 0) {
            LogMessage -Message "Invalid value for RemoveEntriesOlderThan: $RemoveEntriesOlderThan. Must be a non-negative integer." -IsError
            throw "Invalid value for RemoveEntriesOlderThan. Must be a non-negative integer."
        }

        if ($beforeTimestamp -or $RemoveEntriesOlderThan) {
            RemoveLogEntries -LogFilePath $LogFilePath -BeforeTimestamp $beforeTimestamp -OlderThanDays $RemoveEntriesOlderThan
        }
    }

    # Handle log truncation for fresh runs
    if (-not $Restart) {
        if ($TruncateIfLarger) {
            try {
                $thresholdBytes = ConvertToBytes -Size $TruncateIfLarger
                if ((Test-Path -Path $LogFilePath) -and ((Get-Item -Path $LogFilePath).Length -gt $thresholdBytes)) {
                    Clear-Content -Path $LogFilePath -Force
                    LogMessage -Message "Log file truncated due to size exceeding ${TruncateIfLarger}: $LogFilePath"
                }
            } catch {
                LogMessage -Message "Failed to evaluate or truncate log file based on size: $($_.Exception.Message)" -IsError
            }
        } elseif ($TruncateLog) {
            try {
                Clear-Content -Path $LogFilePath -Force
                LogMessage -Message "Log file truncated: $LogFilePath"
            } catch {
                LogMessage -Message "Failed to truncate log file: $($_.Exception.Message)" -IsError
            }
        }
    }

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

        # Validate input parameters
        if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $DeleteMode)) {
            Write-Error "Invalid value for DeleteMode: $DeleteMode. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'."
            exit 1
        }

        if (-not ("NoWarnings", "WarningsOnly" -contains $EndOfScriptDeletionCondition)) {
            Write-Error "Invalid value for EndOfScriptDeletionCondition: $EndOfScriptDeletionCondition. Valid options are 'NoWarnings', 'WarningsOnly'."
            exit 1
        }

        LogMessage -Message "Parameter validation completed"

        $FilesToDelete = [ref]@()  # Initialize FilesToDelete as a [ref] object with an empty array
        $GlobalFileCounter = [ref]0  # Initialize GlobalFileCounter as a [ref] object with a value of 0

        $fileLockRef = [ref]$null

        try {
            # Restart logic
            $lastCheckpoint = 0
            if ($Restart) {
                # Acquire a lock on the state file
                $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount

                LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput
                $state = LoadState -fileLock $fileLockRef
                $lastCheckpoint = $state.Checkpoint
                if ($lastCheckpoint -gt 0) {
                    LogMessage -Message "Restarting from checkpoint $lastCheckpoint" -ConsoleOutput
                } else {
                    LogMessage -Message "Checkpoint not found. Executing from top..." -IsWarning
                }

                # Restore SourceFolder
                if ($state.ContainsKey("SourceFolder")) {
                    $savedSourceFolder = $state.SourceFolder

                    # Validate the loaded SourceFolder
                    if ($SourceFolder -ne $savedSourceFolder) {
                        throw "SourceFolder mismatch: Restarted script must use the saved SourceFolder ('$savedSourceFolder'). Aborting."
                    }
                    $SourceFolder = $savedSourceFolder
                    LogMessage -Message "SourceFolder restored from state file: $SourceFolder"
                } else {
                    throw "State file does not contain SourceFolder. Unable to enforce."
                }

                # Restore DeleteMode
                if ($state.ContainsKey("deleteMode")) {
                    $savedDeleteMode = $state.deleteMode

                    # Validate the loaded DeleteMode
                    if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $savedDeleteMode)) {
                        throw "Invalid value for DeleteMode in state file: '$savedDeleteMode'. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'."
                    }
                    
                    if ($DeleteMode -ne $savedDeleteMode) {
                        throw "DeleteMode mismatch: Restarted script must use the saved DeleteMode ('$savedDeleteMode'). Aborting."
                    }
                    $DeleteMode = $savedDeleteMode
                    Write-Output "DeleteMode restored from state file: $DeleteMode"
                } else {
                    throw "State file does not contain DeleteMode. Unable to enforce."
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

                # Load FilesToDelete only for EndOfScript mode and lastCheckpoint 3 or 4
                if ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4 -and $state.ContainsKey("FilesToDelete")) {
                    $FilesToDelete = $state.FilesToDelete

                    # Handle empty FilesToDelete array
                    if (-not $FilesToDelete -or $FilesToDelete.Count -eq 0) {
                        Write-Output "No files to delete from the previous session."
                    } else {
                        Write-Output "Loaded $($FilesToDelete.Count) files to delete from the previous session."
                    }
                } elseif ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4) {
                    # If DeleteMode is EndOfScript but no FilesToDelete key exists
                    Write-Warning "State file does not contain FilesToDelete key for EndOfScript mode."
                    $FilesToDelete = @() # Initialise to an empty array
                } else {
                    # Default initialisation when EndOfScript mode does not apply
                    $FilesToDelete = @() # Ensure FilesToDelete is always defined
                }
            } else {

                # Check if a restart state file exists
                if (Test-Path -Path $StateFilePath) {
                  
                    LogMessage -Message "Restart state file found but restart not requested. Deleting state file..." -IsWarning

                    try {
                        Remove-Item -Path $StateFilePath -Force
                        LogMessage -Message "State file $StateFilePath deleted."
                    } catch {
                        LogMessage -Message "Failed to delete state file $StateFilePath. Error: $_" -IsError
                        throw "An error occurred while deleting the state file: $($_.Exception.Message)"
                    }  
                }
                # Acquire the file lock after deleting the file
                $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay
            }
        } catch {
            LogMessage -Message "An unexpected error occurred: $($_.Exception.Message)" -IsError
            throw
        }

        if ($lastCheckpoint -lt 1) {
            # Rename files in the source folder to random names
            LogMessage -Message "Renaming files in source folder..."
            RenameFilesInSourceFolder -SourceFolder $SourceFolder -ShowProgress:$ShowProgress -UpdateFrequency $UpdateFrequency
            $additionalVars = @{
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }
            SaveState -Checkpoint 1 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 2) {
            # Count files in the source and target folder before distribution
            $sourceFiles = Get-ChildItem -Path $SourceFolder -File
            $totalSourceFiles = $sourceFiles.Count
            $totalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
            $totalTargetFilesBefore = if ($null -eq $totalTargetFilesBefore) { 0 } else { $totalTargetFilesBefore }
            $totalFiles = $totalSourceFiles + $totalTargetFilesBefore # Correctly calculate total files
            LogMessage -Message "Source File Count: $totalSourceFiles. Target File Count Before: $totalTargetFilesBefore."

            # Get subfolders in the target folder
            $subfolders = Get-ChildItem -Path $TargetFolder -Directory

            # Determine if subfolders need to be created
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
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }

            SaveState -Checkpoint 2 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 3) {
            # Distribute files from the source folder to subfolders
            LogMessage -Message "Distributing files to subfolders..."
            DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -Limit $FilesPerFolderLimit `
                                        -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency `
                                        -DeleteMode $DeleteMode -FilesToDelete $FilesToDelete `
                                        -GlobalFileCounter $GlobalFileCounter -TotalFiles $totalFiles # Pass correct total
            LogMessage -Message "Completed file distribution"

            # Common base for additional variables
            $additionalVars = @{
                totalSourceFiles      = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders            = ConvertItemsToPaths($subfolders)
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }

            # Conditionally add FilesToDelete for EndOfScript mode
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = $FilesToDelete
            }

            # Save the state with the consolidated additional variables
            SaveState -Checkpoint 3 -AdditionalVariables $additionalVars -fileLock $fileLockRef

        }

        if ($lastCheckpoint -lt 4) {
            # Redistribute files within the target folder and subfolders if needed
            LogMessage -Message "Redistributing files in target folders..."
            RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders `
                                      -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress `
                                      -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode `
                                      -FilesToDelete $FilesToDelete -GlobalFileCounter $GlobalFileCounter `
                                      -TotalFiles $totalFiles # Pass correct total
        
            # Base additional variables
            $additionalVars = @{
                totalSourceFiles      = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }
        
            # Conditionally add FilesToDelete if DeleteMode is EndOfScript
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = $FilesToDelete
            }
        
            # Save state with checkpoint 4 and additional variables
            SaveState -Checkpoint 4 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }        

        if ($DeleteMode -eq "EndOfScript") {
            # Check if conditions for deletion are satisfied
            if (($EndOfScriptDeletionCondition -eq "NoWarnings" -and $Warnings -eq 0 -and $Errors -eq 0) -or
                ($EndOfScriptDeletionCondition -eq "WarningsOnly" -and $Errors -eq 0)) {
                
                # Attempt to delete each file in $FilesToDelete.Value
                foreach ($file in $FilesToDelete.Value) {
                    try {
                        if (Test-Path -Path $file) {
                            Remove-File -FilePath $file
                            LogMessage -Message "Deleted file: $file during EndOfScript cleanup."
                        } else {
                            LogMessage -Message "File $file not found during EndOfScript deletion." -IsWarning
                        }
                    } catch {
                        # Log a warning for failure to delete
                        LogMessage -Message "Failed to delete file $file. Error: $($_.Exception.Message)" -IsWarning
                    }
                }
            } else {
                # Log a message if conditions are not met
                LogMessage -Message "End-of-script deletion skipped due to warnings or errors."
            }
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

        # Release the file lock before deleting state file
        if ($fileLockRef.Value) {
            ReleaseFileLock -FileStream $fileLockRef.Value
        }

        Remove-Item -Path $StateFilePath -Force
        LogMessage -Message "Deleted state file: $StateFilePath"

        # Post-processing: Cleanup duplicates
        if ($CleanupDuplicates) {
            LogMessage -Message "Invoking duplicate file cleanup script..."
            & (Join-Path -Path $ScriptDirectory -ChildPath "Remove-DuplicateFiles.ps1") -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false
            LogMessage -Message "Duplicate file cleanup completed."
        } else {
            LogMessage -Message "Skipping duplicate file cleanup."
        }

        # Post-processing: Cleanup empty folders
        if ($CleanupEmptyFolders) {
            LogMessage -Message "Invoking empty folder cleanup script..."
            & (Join-Path -Path $ScriptDirectory -ChildPath "Remove-EmptyFolders.ps1") -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false
            LogMessage -Message "Empty folder cleanup completed."
        } else {
            LogMessage -Message "Skipping empty folder cleanup."
        }

        LogMessage -Message "File distribution and optional cleanup completed."

    } catch {
        LogMessage -Message "$($_.Exception.Message)" -IsError
    } finally {
        if ($fileLockRef.Value) {
            ReleaseFileLock -FileStream $fileLockRef.Value
        }
    }
}

# Run the script
Main
