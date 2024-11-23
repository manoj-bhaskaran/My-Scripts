# Define the path to the log file
$logFilePath = "C:\users\manoj\Documents\Scripts\recover-extensions.log"

# Function to log messages with timestamp
function Write-Log {
    param([string]$message)

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
    if ($extension -and $extension -ne $file.Name) {
        # Rename the file with the correct extension
        $newFileName = $file.FullName + $extension
        Rename-Item -Path $file.FullName -NewName $newFileName
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
