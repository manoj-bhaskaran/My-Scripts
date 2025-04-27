<#
.SYNOPSIS
This PowerShell script recovers file extensions for files that have lost their extensions. It scans a specified folder, determines the file type based on the file's signature (first few bytes), and appends the appropriate extension to the file name. The script logs all actions for future reference.

.DESCRIPTION
The script iterates through each file in the specified folder and checks if the file already has an extension. If the file does not have an extension, it reads the first few bytes to determine the file type and appends the appropriate extension. The script supports common file signatures for PNG and JPEG files. It logs each action taken, including files skipped, renamed, and those with unknown extensions.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file where actions are recorded. Defaults to "C:\users\manoj\Documents\Scripts\recover-extensions.log".

.PARAMETER FolderPath
Optional. Specifies the path to the folder containing the files to be processed. Defaults to "C:\Users\manoj\OneDrive\Desktop\New folder".

.PARAMETER UnknownsFolder
Optional. Specifies the path to the folder where files with unrecognized extensions are moved. Defaults to "C:\Users\manoj\OneDrive\Desktop\UnidentifiedFiles".

.PARAMETER DryRun
Optional. If specified, no changes are made to the files or folders. Actions are logged but not executed.

.PARAMETER MoveUnknowns
Optional. If specified, files with unrecognized extensions are moved to the UnknownsFolder. If not specified, these files are not moved.

.PARAMETER Debug
Optional. If specified, debug messages are logged and displayed in the console.

.EXAMPLES
To recover file extensions in the default folder and log the actions:
.\recover-extensions.ps1

To recover file extensions in a custom folder and log the actions:
.\recover-extensions.ps1 -FolderPath "C:\Custom\Path"

To perform a dry run without renaming files:
.\recover-extensions.ps1 -DryRun

To move files with unrecognized extensions to a specific folder:
.\recover-extensions.ps1 -MoveUnknowns

To enable debug logging:
.\recover-extensions.ps1 -Debug

.NOTES
Script Workflow:
1. **Initialization**:
   - Defines the log file path, target folder path, and unknowns folder path using the provided parameters or defaults to the specified paths.

2. **File Extension Detection**:
   - Reads the first few bytes of each file to determine its type based on common file signatures (e.g., PNG, JPEG).

3. **File Processing**:
   - Iterates through each file in the target folder.
   - Skips files that already have an extension.
   - Appends the correct extension to files without an extension based on their detected file type.
   - Moves files with unrecognized extensions to the unknowns folder if specified.
   - Logs each action (skipped, renamed, moved, unknown extension).

4. **Summary Logging**:
   - Logs a summary of all actions taken (files skipped, renamed, moved, and unknown extensions).
   - In dry run mode, logs actions without renaming or moving files and provides a detailed summary.

Limitations:
- The script currently supports common file signatures for PNG and JPEG files.
- Additional file signatures can be added to the `Get-FileExtension` function as needed.
- Ensure you have the necessary permissions to read, write, and rename files in the target directory.
#>

# Add Debug parameter to the script
param(
    [string]$FolderPath = "C:\Users\manoj\OneDrive\Desktop\New folder",
    [string]$LogFilePath = "C:\users\manoj\Documents\Scripts\recover-extensions-log.txt",
    [string]$UnknownsFolder = "C:\Users\manoj\OneDrive\Desktop\UnidentifiedFiles",
    [switch]$DryRun,
    [switch]$MoveUnknowns,
    [switch]$Debug
)

# Update Write-Log to handle debug messages without using Write-Host
function Write-Log {
    param(
        [string]$message,
        [switch]$isDebug
    )

    if ($isDebug -and -not $Debug) {
        return
    }

    # Check if log file exists, and create it if it doesn't
    if (-not (Test-Path -Path $LogFilePath)) {
        New-Item -ItemType File -Path $LogFilePath -Force | Out-Null
    }

    # Get current timestamp
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # Prepare log entry
    $logEntry = if ($isDebug) { "$timestamp - DEBUG: $message" } else { "$timestamp - $message" }

    # Write log entry to the log file
    Add-Content -Path $LogFilePath -Value $logEntry
}

# Define a function to get file type based on the first few bytes
function Get-FileExtension {
    param([string]$filePath)

    # Open the file and read the first 12 bytes
    $fileStream = [System.IO.File]::OpenRead($filePath)
    $buffer = New-Object byte[] 12
    $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
    $fileStream.Close()

    # Convert bytes to hex string
    $hex = [BitConverter]::ToString($buffer[0..($bytesRead - 1)]) -replace '-'

    # Match common file signatures and return the extension
    switch -regex ($hex) {
        '^89504E47' { return ".png" }  # PNG signature (4 bytes)
        '^FFD8FF(DB|E0|E1|E2|EE)' { return ".jpg" }  # JPEG signatures (4 bytes)
        '^49492A00' { return ".tiff" } # TIFF signature (4 bytes)
        '^4D4D002(A|B)' { return ".tiff" } # TIFF signatures (4 bytes)
        '^49492800' { return ".tiff" } # TIFF signature (4 bytes)
        '^492049'   { return ".tiff" } # TIFF 3-byte signature
        '^6674797068656963' { return ".heic" } # HEIC signature (8 bytes)
        '^6674797061766966' { return ".avif" } # AVIF signature (8 bytes)
        '^474946383761' { return ".gif" }  # GIF87a signature (6 bytes)
        '^474946383961' { return ".gif" }  # GIF89a signature (6 bytes)
        '^424D' { return ".bmp" }  # BMP signature (2 bytes)
        '^52494646.{8}57454250' { return ".webp" } # WEBP signature (RIFF + WEBP in bytes 9-12)
        default { return $null }       # Return null if extension is not found
    }
}

# Check if the input folder exists
if (-not (Test-Path -Path $FolderPath)) {
    $errorMessage = "ERROR: The specified folder '$FolderPath' does not exist."
    Write-Error $errorMessage
    Write-Log $errorMessage
    exit 1
}

# Ensure the unknowns folder exists if not in dry run mode and moving unknowns is enabled
if ($MoveUnknowns -and -not $DryRun -and -not (Test-Path -Path $UnknownsFolder)) {
    New-Item -ItemType Directory -Path $UnknownsFolder -Force | Out-Null
    Write-Log "Created unknowns folder at $UnknownsFolder"
}

# Initialize counters
$skippedCount = 0
$renamedCount = 0
$unknownCount = 0
$extensionCounts = @{ }
$unknownSignatures = @{ }

# Initialize a dictionary to count files by extension
$extensionSummary = @{}

# Debug log for script start
if ($Debug) { Write-Host "Script started. Processing folder: $FolderPath" }
Write-Log "Script started. Processing folder: $FolderPath" -isDebug

# Debug log for folder path
Write-Log "Starting script with FolderPath: $FolderPath" -isDebug
Write-Log "LogFilePath: $LogFilePath" -isDebug
Write-Log "UnknownsFolder: $UnknownsFolder" -isDebug
Write-Log "DryRun: $DryRun" -isDebug
Write-Log "MoveUnknowns: $MoveUnknowns" -isDebug

# Recursive file scanning
Write-Log "Discovering files in folder: $FolderPath" -isDebug
$files = Get-ChildItem -Path $FolderPath -File -Recurse
$totalFiles = $files.Count
if ($Debug) { Write-Host "Found $totalFiles file(s) in folder." }
Write-Log "Found $totalFiles file(s) in folder." -isDebug

# Iterate through each file and check its type
$processedFiles = 0
foreach ($file in $files) {
    # Update progress bar
    $processedFiles++
    $percentComplete = [math]::Round(($processedFiles / $totalFiles) * 100, 2)
    Write-Progress -Activity "Processing Files" -Status "Processing file $processedFiles of $totalFiles" -PercentComplete $percentComplete

    if ($Debug) { Write-Host "Processing file: $($file.FullName)" }  # Debug message for the first file
    Write-Log "Processing file: $($file.FullName)" -isDebug

    # Skip files that already have an extension
    if ($file.Extension) {
        Write-Log "File already has an extension: $($file.Extension)" -isDebug
        Write-Log "Skipping $($file.Name), already has extension."
        $skippedCount++

        # Increment the count for the extension
        if (-not $extensionSummary.ContainsKey($file.Extension)) {
            $extensionSummary[$file.Extension] = 0
        }
        $extensionSummary[$file.Extension]++

        continue
    }

    # If no extension, try to recover it
    $extension = Get-FileExtension -filePath $file.FullName
    Write-Log "Detected extension $extension for file $($file.Name)"  # Added log for detected extension

    if ($extension -and $extension.StartsWith(".")) {
        Write-Log "Detected valid extension: $extension for file: $($file.Name)" -isDebug

        # Update extension count
        if (-not $extensionCounts.ContainsKey($extension)) {
            $extensionCounts[$extension] = 0
        }
        $extensionCounts[$extension]++

        if (-not $DryRun) {
            # Extract the file name without extension
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.FullName)

            # Construct the new file name
            $newFileName = $fileNameWithoutExtension + $extension

            # Get the new full file path
            $newFullFilePath = [System.IO.Path]::Combine($file.DirectoryName, $newFileName)

            # Rename the file with the correct extension
            Rename-Item -Path $file.FullName -NewName $newFullFilePath
            Write-Log "Renamed $($file.Name) to $($newFileName)"
            $renamedCount++
        }
    } else {
        Write-Log "Unknown extension detected for file: $($file.Name)" -isDebug

        # Log the hex value for unknown file types
        if (-not $unknownSignatures.ContainsKey($extension)) {
            $unknownSignatures[$extension] = 0
        }
        $unknownSignatures[$extension]++
        Write-Log "Could not determine extension for $($file.Name). Hex: $extension"
        $unknownCount++

        # Move unknown files to the unknowns folder if MoveUnknowns is enabled and not in dry run mode
        if ($MoveUnknowns -and -not $DryRun) {
            $destinationPath = Join-Path -Path $UnknownsFolder -ChildPath $file.Name
            Move-Item -Path $file.FullName -Destination $destinationPath
            Write-Log "Moved $($file.Name) to $UnknownsFolder"
        }
    }
}

# Clear the progress bar after processing is complete
Write-Progress -Activity "Processing Files" -Status "Completed" -Completed

# Debug log for summary
Write-Log "Script completed. Generating summary." -isDebug

# Update dry run summary to include identified extensions and total files processed
if ($DryRun) {
    $identifiedExtensions = $extensionCounts.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }
    $unknownExtensions = $unknownSignatures.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }

    $identifiedExtensionsMessage = if ($identifiedExtensions) { $identifiedExtensions -join ", " } else { "None" }
    $unknownExtensionsMessage = if ($unknownExtensions) { $unknownExtensions -join ", " } else { "None" }

    $totalFilesProcessed = $skippedCount + $renamedCount + $unknownCount
    $summaryMessage = "Dry Run Summary: Processed $totalFilesProcessed file(s). Skipped $skippedCount file(s), Identified extensions: $identifiedExtensionsMessage, Unknown extensions: $unknownExtensionsMessage."
    Write-Log $summaryMessage
    Write-Host $summaryMessage
} else {
    # Update non-dry run summary to include identified extensions and unknown hex signatures
    $totalFilesProcessed = $skippedCount + $renamedCount + $unknownCount
    $summaryMessage = "Summary: Processed $totalFilesProcessed file(s). Skipped $skippedCount file(s), Renamed $renamedCount file(s), Unknown extension for $unknownCount file(s)."
    Write-Log $summaryMessage
    Write-Host $summaryMessage

    # Include identified extensions and their counts
    if ($extensionCounts.Count -gt 0) {
        $identifiedExtensionsMessage = $extensionCounts.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } | Out-String
        $formattedIdentifiedExtensionsMessage = $identifiedExtensionsMessage -replace "\n", "`n"
        Write-Log "Identified extensions and counts:`n$formattedIdentifiedExtensionsMessage"
        Write-Host "Identified extensions and counts:`n$formattedIdentifiedExtensionsMessage"
    } else {
        Write-Log "No identified extensions."
        Write-Host "No identified extensions."
    }

    # Include unknown hex signatures and their counts
    if ($unknownSignatures.Count -gt 0) {
        $unknownSignaturesMessage = $unknownSignatures.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } | Out-String
        $formattedUnknownSignaturesMessage = $unknownSignaturesMessage -replace "\n", "`n"
        Write-Log "Unknown hex signatures and counts:`n$formattedUnknownSignaturesMessage"
        Write-Host "Unknown hex signatures and counts:`n$formattedUnknownSignaturesMessage"
    } else {
        Write-Log "No unknown hex signatures."
        Write-Host "No unknown hex signatures."
    }

    # Summary of files grouped by extension
    if ($extensionSummary.Count -gt 0) {
        $extensionSummaryMessage = $extensionSummary.GetEnumerator() | ForEach-Object { "Extension $($_.Key): $($_.Value) file(s)" } | Out-String
        $formattedSummaryMessage = $extensionSummaryMessage -replace "\n", "`n"
        Write-Log "Summary of files with extensions:`n$formattedSummaryMessage"
        Write-Host "Summary of files with extensions:`n$formattedSummaryMessage"
    } else {
        Write-Log "No files with extensions to summarize."
        Write-Host "No files with extensions to summarize."
    }
}
