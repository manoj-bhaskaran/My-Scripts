<#
.SYNOPSIS
    This script applies Access Control Lists (ACLs) from a source folder to a target folder and its subfolders.
    It provides detailed debugging messages using a custom verbose parameter.

.PARAMETER sourceFolder
    The full path to the source folder from which the ACL settings will be copied. This is a mandatory parameter.

.PARAMETER targetFolder
    The full path to the target folder where the ACL settings will be applied. This is a mandatory parameter.

.PARAMETER EnableVerbose
    A switch that enables verbose mode for detailed messages.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,

    [Parameter(Mandatory=$true)]
    [string]$targetFolder,

    [switch]$EnableVerbose
)

Write-Host "Script execution started."

# Enable custom verbose mode
if ($EnableVerbose) {
    $VerbosePreference = 'Continue'
    Write-Host "Verbose mode enabled."
} else {
    Write-Host "Verbose mode not enabled."
}

# Check if source folder exists
Write-Host "Checking if source folder exists..."
if (-not (Test-Path $sourceFolder)) {
    Write-Host "Source folder '$sourceFolder' does not exist."
    Write-Error "Source folder '$sourceFolder' does not exist."
    exit
}

Write-Host "Source folder exists: $sourceFolder"

# Check if target folder exists
Write-Host "Checking if target folder exists..."
if (-not (Test-Path $targetFolder)) {
    Write-Host "Target folder '$targetFolder' does not exist."
    Write-Error "Target folder '$targetFolder' does not exist."
    exit
}

Write-Host "Target folder exists: $targetFolder"

# Retrieve and display ACL
Write-Host "Retrieving ACL from source folder..."
try {
    $acl = Get-Acl $sourceFolder
    Write-Host "ACL retrieved from source folder: $sourceFolder"
}
catch {
    Write-Host "Failed to retrieve ACL from source folder: $sourceFolder"
    Write-Error "Failed to retrieve ACL from source folder: $sourceFolder"
}

# Get directories and files from target folder
Write-Host "Retrieving directories and files from target folder..."
$directories = Get-ChildItem -Path $targetFolder -Recurse -Directory
$files = Get-ChildItem -Path $targetFolder -Recurse -File
$totalItems = $directories.Count + $files.Count
Write-Host "Total items to process: $totalItems"

$currentItem = 0

# Function to apply ACL to a given path
function Set-ACL {
    param (
        [string]$path
    )

    try {
        Set-Acl -Path $path -AclObject $acl
        $global:currentItem++
        Show-Progress -current $global:currentItem -total $global:totalItems -activity "Applying ACL" -status "$global:currentItem of $($global:totalItems) processed"
        if ($EnableVerbose) {
            Write-Host "Applied ACL to: $path"
        }
    }
    catch {
        Write-Warning "Failed to apply ACL to: $path"
        if ($EnableVerbose) {
            Write-Host "Error details: $_"
        }
    }
}

# Function to update progress
function Show-Progress {
    param ($current, $total, $activity, $status)
    Write-Progress -PercentComplete (($current / $total) * 100) -Activity $activity -Status $status
}

# Apply ACL to directories
Write-Host "Applying ACL to directories..."
foreach ($directory in $directories) {
    Set-ACL -path $directory.FullName
}

# Apply ACL to files
Write-Host "Applying ACL to files..."
foreach ($file in $files) {
    Set-ACL -path $file.FullName
}

# Complete the progress bar
Write-Progress -PercentComplete 100 -Activity "Applying ACL Completed" -Status "All items processed"
Write-Host "ACL application process completed."

# Finish script
Write-Host "Script execution completed."
