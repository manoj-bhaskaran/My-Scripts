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
        default { return $hex }      # Return hex if extension is not found
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

    if ($extension -and $extension -ne $file.Name) {
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
    else {
        # Log the hex value for unknown file types
        Write-Log "Could not determine extension for $($file.Name). Hex: $extension"
        $unknownCount++
    }
}

# Write summary at the end
$summaryMessage = "Summary: Skipped $skippedCount file(s), Renamed $renamedCount file(s), Unknown extension for $unknownCount file(s)."
Write-Log $summaryMessage
Write-Host $summaryMessage
