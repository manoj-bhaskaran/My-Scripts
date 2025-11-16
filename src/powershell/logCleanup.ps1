<#
.SYNOPSIS
    Cleans up old PostgreSQL log files from the data/log directory.

.DESCRIPTION
    This script removes log files older than 90 days from the PostgreSQL log directory
    and logs the cleanup operations using the PowerShellLoggingFramework.

.NOTES
    Version: 2.0.0

    CHANGELOG
    ## 2.0.0 - 2025-11-16
    ### Changed
    - Migrated to PowerShellLoggingFramework.psm1 for standardized logging
    - Replaced Add-Content manual logging with Write-LogInfo
    - Added proper script documentation and version tracking
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\common\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Define the path to the directory
$logDirectory = "D:\Program Files\PostgreSQL\17\data\log"

# Get the current date
$currentDate = Get-Date

# Start the log entry
Write-LogInfo "Log Cleanup Script - $(Get-Date)"
Write-LogInfo "-----------------------------------"

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
        Write-LogInfo $logMessage
    }
}

# End the log entry
Write-LogInfo "Log Cleanup Completed - $(Get-Date)"
Write-LogInfo "-----------------------------------"
