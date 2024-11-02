#Deletes old download files from the Downloads folder

$FolderPath = "C:\Users\manoj\Downloads"
$Days = 14
$CurrentDate = Get-Date
$LogFilePath = "C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt"  # Change to desired log file path

# Ensure the log file directory exists
$LogFileDir = Split-Path -Parent $LogFilePath
if (!(Test-Path $LogFileDir)) {
    New-Item -Path $LogFileDir -ItemType Directory -Force
}

# Append a log header with the date
Add-Content -Path $LogFilePath -Value "Log Date: $CurrentDate`r`n"

try {
    $Files = Get-ChildItem -Path $FolderPath -File | Where-Object {
        ($CurrentDate - $_.LastWriteTime).Days -gt $Days
    }

    $DeletedFilesCount = 0

    if ($Files.Count -eq 0) {
        Add-Content -Path $LogFilePath -Value "No files to delete.`r`n"
    } else {
        foreach ($File in $Files) {
            # Log the file being deleted along with its last modified date
            $LastModified = $File.LastWriteTime
            Add-Content -Path $LogFilePath -Value "Deleting: $($File.FullName), Last Modified: $LastModified"
            
            # Delete the file
            Remove-Item -Path $File.FullName -Force
            
            # Increment the deleted files count
            $DeletedFilesCount++
        }

        # Log the total number of files deleted
        Add-Content -Path $LogFilePath -Value "Total files deleted: $DeletedFilesCount"
    }

    # Add a footer to the log
    Add-Content -Path $LogFilePath -Value "Log Ended: $(Get-Date)`r`n`r`n"
} catch {
    # Log detailed error information
    $ErrorMessage = $_.Exception.Message
    $ErrorDetails = $_.Exception | Out-String
    Add-Content -Path $LogFilePath -Value "Error: $ErrorMessage`r`nDetails: $ErrorDetails`r`n"

    # Display a popup message with error details
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Failed to delete old files in Downloads. Error: $ErrorMessage", 0, "Error", 16)

    # Exit with an error code to trigger Task Scheduler's failure actions
    exit 1
}