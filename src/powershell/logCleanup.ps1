# Define the path to the directory and the log file
$logDirectory = "D:\Program Files\PostgreSQL\17\data\log"
$logFile = "D:\Program Files\PostgreSQL\17\data\log_cleanup.log"

# Get the current date
$currentDate = Get-Date

# Start the log entry
Add-Content -Path $logFile -Value "Log Cleanup Script - $(Get-Date)"
Add-Content -Path $logFile -Value "-----------------------------------"

# Get all files in the directory
$files = Get-ChildItem -Path $logDirectory -File

# Iterate over each file
foreach ($file in $files) {
    # Calculate the age of the file
    $fileAge = $currentDate - $file.LastWriteTime

    # Check if the file is older than 90 days
    if ($fileAge.Days -gt 90) {
        # Delete the file
        Remove-Item -Path $file.FullName -Force
        $logMessage = "Deleted: $($file.FullName) - Last Modified: $($file.LastWriteTime)"
        Add-Content -Path $logFile -Value $logMessage
    }
}

# End the log entry
Add-Content -Path $logFile -Value "Log Cleanup Completed - $(Get-Date)"
Add-Content -Path $logFile -Value "-----------------------------------`n"
