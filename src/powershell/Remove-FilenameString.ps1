<#
.SYNOPSIS
    Renames files by removing specified strings from their filenames.

.DESCRIPTION
    This script searches for files in a specified directory that contain specific strings
    in their filenames and renames them by removing those strings. It handles filename
    conflicts by appending a numeric suffix.

.PARAMETER sourcePath
    The directory path to search for files to rename. Default: "C:\Users\manoj\Documents\FIFA 07\elib"

.PARAMETER logFilePath
    The path to the log file where renaming actions are recorded. Default: "C:\Users\manoj\Documents\Scripts\scrubname.log"

.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release with Add-Content logging
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\common\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "scrubname" -LogLevel 20

# Enforce explicit variable declarations
Set-StrictMode -Version Latest

# Define source directory path
[string]$sourcePath = "C:\Users\manoj\Documents\FIFA 07\elib"

# Define path for log file
[string]$logFilePath = "C:\Users\manoj\Documents\Scripts\scrubname.log"

# Define strings to scrub from filenames and their replacements
$scrubStrings = @{
    "manojbhaskaran76_" = $null
    "_Instagram" = $null
    "_WhatsApp" = $null
    "Screenshot_" = $null
}

# End of input parameters

Write-LogInfo "Starting filename scrubbing process for directory: $sourcePath"

# Get current timestamp
[string]$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#Program variable declarations
[string]$string = ""
[System.IO.FileInfo[]]$files = $null
[System.IO.FileInfo]$file = $null
[string]$oldName = ""
[string]$newName = ""
[int]$suffix = ""
[string]$baseName = ""
[string]$extension = ""

# Check if log file exists, if not, create it
if (-not (Test-Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType File | Out-Null
    Write-LogInfo "Created log file: $logFilePath"
}

# Iterate over each scrub string
foreach ($string in $scrubStrings.Keys) {

    # Display the string being processed
    Write-Host "Processing: $string"
    Write-LogInfo "Processing scrub string: $string"

    # Get files containing the current scrub string
    $files = Get-ChildItem -Path $sourcePath -Filter "*$string*"

    If ($files -ne $null) {

        # Display the number of files to be processed
        Write-Host "$($files.Count) files to be processed"
        Write-LogInfo "Found $($files.Count) files containing '$string'"

    } else {

        Write-Host "0 files to be processed"
        Write-LogInfo "No files found containing '$string'"

    }

    # Iterate over each file
    foreach ($file in $files) {

        # Store current filename
        $oldName = $file.Name

        # Replace the scrub string with empty string in filename
        $newName = $oldName -replace $string

        # Check if filename has changed
        if ($oldName -ne $newName) {

            # Initialize suffix for avoiding filename conflicts
            $suffix = 1

            # Append suffix to filename if it already exists
	        while (Test-Path (Join-Path -Path $sourcePath -ChildPath $newName)) {
	            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($newName)
	            $extension = [System.IO.Path]::GetExtension($newName)
                $newName = "${baseName}_${suffix}${extension}"
                $suffix++
            }

	        # Rename the file
	        Rename-Item -Path $file.FullName -NewName $newName

            # Log the renaming action
            Write-LogInfo "Renamed file: $oldName to $newName"
            Add-Content -Path $logFilePath -Value "$timeStamp - Renamed file: $oldName to $newName"
        }
    }
}

Write-LogInfo "Filename scrubbing process completed"
