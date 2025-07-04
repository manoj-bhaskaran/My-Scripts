# Delete old download files from the Downloads folder
$FolderPath = "C:\Users\manoj\Downloads"
$Days = 14
$CurrentDate = Get-Date
$LogFilePath = "C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt"

try {
    # Ensure the log file directory exists
    $LogFileDir = Split-Path -Parent $LogFilePath
    if (!(Test-Path $LogFileDir)) {
        New-Item -Path $LogFileDir -ItemType Directory -Force
    }

    # Append a log header with the date
    Add-Content -Path $LogFilePath -Value "Log Date: $CurrentDate`r`n"

    # Process files
    $Files = Get-ChildItem -Path $FolderPath -File | Where-Object {
        ($CurrentDate - $_.LastWriteTime).Days -gt $Days
    }

    $DeletedFilesCount = 0

    if ($Files.Count -eq 0) {
        Add-Content -Path $LogFilePath -Value "No files to delete.`r`n"
    } else {
        foreach ($File in $Files) {
            $LastModified = $File.LastWriteTime
            Add-Content -Path $LogFilePath -Value "Deleting: $($File.FullName), Last Modified: $LastModified"
            Remove-Item -Path $File.FullName -Force
            $DeletedFilesCount++
        }
        Add-Content -Path $LogFilePath -Value "Total files deleted: $DeletedFilesCount"
    }

    # Add a footer to the log
    Add-Content -Path $LogFilePath -Value "Log Ended: $(Get-Date)`r`n`r`n"
    exit 0
} catch {
    $ErrorMessage = $_.Exception.Message
    $ErrorDetails = $_.Exception | Out-String
    $ErrorOutput = "Error: $ErrorMessage`r`nDetails: $ErrorDetails`r`n"
    if (Test-Path $LogFilePath) {
        Add-Content -Path $LogFilePath -Value $ErrorOutput
    }
    exit 1
}