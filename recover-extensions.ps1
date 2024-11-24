<#
.SYNOPSIS
This PowerShell script recovers file extensions for files that have lost their extensions. It scans a specified folder, determines the file type based on the file's signature (first few bytes), and appends the appropriate extension to the file name. The script logs all actions for future reference.

.DESCRIPTION
The script iterates through each file in the specified folder and checks if the file already has an extension. If the file does not have an extension, it reads the first few bytes to determine the file type and appends the appropriate extension. The script supports common file signatures for PNG and JPEG files. It logs each action taken, including files skipped, renamed, and those with unknown extensions.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file where actions are recorded. Defaults to "C:\users\manoj\Documents\Scripts\recover-extensions.log".

.PARAMETER FolderPath
Optional. Specifies the path to the folder containing the files to be processed. Defaults to "C:\Users\manoj\OneDrive\Desktop\New folder".

.EXAMPLES
To recover file extensions in the default folder and log the actions:
.\recover-extensions.ps1

To recover file extensions in a custom folder and log the actions:
.\recover-extensions.ps1 -FolderPath "C:\Custom\Path"

.NOTES
Script Workflow:
1. **Initialization**:
   - Defines the log file path and the target folder path using the provided parameters or defaults to the specified paths.

2. **File Extension Detection**:
   - Reads the first few bytes of each file to determine its type based on common file signatures (e.g., PNG, JPEG).

3. **File Processing**:
   - Iterates through each file in the target folder.
   - Skips files that already have an extension.
   - Appends the correct extension to files without an extension based on their detected file type.
   - Logs each action (skipped, renamed, unknown extension).

4. **Summary Logging**:
   - Logs a summary of all actions taken (files skipped, renamed, and unknown extensions).

Limitations:
- The script currently supports common file signatures for PNG and JPEG files.
- Additional file signatures can be added to the `Get-FileExtension` function as needed.
- Ensure you have the necessary permissions to read, write, and rename files in the target directory.
#>

# Define the path to the log file
$logFilePath = "C:\users\manoj\Documents\Scripts\recover-extensions-log.txt"

# Function to log messages with timestamp
function Write-Log {
    param([string]$message)

    # Check if log file exists, and create it if it doesn't
    if (-not (Test-Path -Path $logFilePath)) {
        New-Item -ItemType File -Path $logFilePath -Force
    }

    # Get current timestamp
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    # Prepare log entry
    $logEntry = "$timestamp - $message"

    # Write log entry to the log file
    Add-Content -Path $logFilePath -Value "$logEntry"
}

# Define a function to get file type based on the first few bytes
function Get-FileExtension {
    param([string]$filePath)

    # Read the first 4 bytes of the file
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)[0..3]

    # Convert bytes to hex string
    $hex = [BitConverter]::ToString($fileBytes) -replace '-'

    # Match common file signatures and return the extension
    switch ($hex) {
        '89504E47' { return ".png" }  # PNG signature
        'FFD8FFDB' { return ".jpg" }  # JPEG signature
        'FFD8FFE0' { return ".jpg" }  # Another common JPEG signature
        'FFD8FFE1' { return ".jpg" }  # Another common JPEG signature
        'FFD8FFE2' { return ".jpg" }  # Another common JPEG signature
        default { return $hex }       # Return hex if extension is not found
    }
}

# Path to the folder with renamed files
$folderPath = "C:\Users\manoj\OneDrive\Desktop\New folder"

# Get all files in the folder
$files = Get-ChildItem -Path $folderPath -File

# Initialize counters
$skippedCount = 0
$renamedCount = 0
$unknownCount = 0

# Iterate through each file and check its type
foreach ($file in $files) {
    # Skip files that already have an extension
    if ($file.Extension) {
        Write-Log "Skipping $($file.Name), already has extension."
        $skippedCount++
        continue
    }

    # If no extension, try to recover it
    $extension = Get-FileExtension -filePath $file.FullName
    Write-Log "Detected extension $extension for file $($file.Name)"  # Added log for detected extension

    if ($extension -and $extension.StartsWith(".")) {
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
    } else {
        # Log the hex value for unknown file types
        Write-Log "Could not determine extension for $($file.Name). Hex: $extension"
        $unknownCount++
    }
}

# Write summary at the end
$summaryMessage = "Summary: Skipped $skippedCount file(s), Renamed $renamedCount file(s), Unknown extension for $unknownCount file(s)."
Write-Log $summaryMessage
Write-Host $summaryMessage
