<#
.SYNOPSIS
    This script applies Access Control Lists (ACLs) from a source folder to a target folder and its subfolders.

.DESCRIPTION
    The script retrieves the ACL from the source folder and applies it to the target folder and its subdirectories.
    You can choose to apply the ACL only to folders or to both folders and files. Additionally, errors can be skipped,
    and a progress bar is provided to track the application of ACLs.

.PARAMETER sourceFolder
    The full path to the source folder from which the ACL settings will be copied. This is a mandatory parameter.
    Example: "C:\Path\To\Source\Folder"

.PARAMETER targetFolder
    The full path to the target folder where the ACL settings will be applied. This is a mandatory parameter.
    Example: "D:\Path\To\Target\Folder"

.PARAMETER SkipErrors
    A switch that, if provided, will allow the script to skip errors and continue processing other items.
    If not specified, the script will stop and throw an error if it encounters a missing item or failure.
    Example: `-SkipErrors`

.PARAMETER FoldersOnly
    A switch that, if provided, will apply the ACL only to folders, excluding files.
    If not specified, ACLs will be applied to both folders and files.
    Example: `-FoldersOnly`

.PARAMETER EnableVerbose
    A switch that, if provided, will enable verbose mode for detailed messages.
    Example: `-EnableVerbose`

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Path\To\Source\Folder" -targetFolder "D:\Path\To\Target\Folder"
    This will apply the ACL from the source folder to both the folders and files in the target folder.

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Path\To\Source\Folder" -targetFolder "D:\Path\To\Target\Folder" -SkipErrors
    This will apply the ACL from the source folder to both folders and files in the target folder, skipping errors.

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Path\To\Source\Folder" -targetFolder "D:\Path\To\Target\Folder" -FoldersOnly
    This will apply the ACL only to the folders in the target folder, skipping files.

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Path\To\Source\Folder" -targetFolder "D:\Path\To\Target\Folder" -EnableVerbose
    This will apply the ACL from the source folder to both folders and files in the target folder, with verbose messages enabled.

.NOTES
    The script uses the `Get-Acl` cmdlet to retrieve the ACL from the source folder and the `Set-Acl` cmdlet to apply it to the target folder.
    The script processes both directories and files in the target folder, applying the ACL recursively.
    A progress bar is displayed to show the status of ACL application. If `$SkipErrors` is provided, missing files or folders will not halt the execution.
    If `$SkipErrors` is not provided, errors will throw and the script will stop. If `$FoldersOnly` is provided, ACLs will be applied only to directories.
#>

# Define the source and target folders
param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,

    [Parameter(Mandatory=$true)]
    [string]$targetFolder,

    [switch]$SkipErrors,

    [switch]$FoldersOnly,

    [switch]$EnableVerbose
)

# Enable verbose mode
if ($EnableVerbose) {
    $VerbosePreference = 'Continue'
    Write-Host "Verbose mode enabled."
} else {
    Write-Host "Verbose mode not enabled."
}

# Check if source folder exists
Write-Host "Checking if source folder exists..."
if (-not (Test-Path $sourceFolder)) {
    Write-Error "Source folder '$sourceFolder' does not exist."
    exit
}
Write-Host "Source folder exists: $sourceFolder"

# Get the ACL from the source folder
Write-Host "Retrieving ACL from source folder..."
try {
    $acl = Get-Acl $sourceFolder
    Write-Host "ACL retrieved from source folder: $sourceFolder"
}
catch {
    Write-Error "Failed to retrieve ACL from source folder: $sourceFolder"
    exit
}

# Initialize progress bar variables
if ($FoldersOnly) {
    # Only get directories if FoldersOnly is specified
    Write-Host "Retrieving directories from target folder..."
    $directories = Get-ChildItem -Path $targetFolder -Recurse -Directory
    $totalItems = $directories.Count
} else {
    # Get both directories and files if FoldersOnly is not specified
    Write-Host "Retrieving directories and files from target folder..."
    $directories = Get-ChildItem -Path $targetFolder -Recurse -Directory
    $files = Get-ChildItem -Path $targetFolder -Recurse -File
    $totalItems = $directories.Count + $files.Count
}
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
        if (-not $SkipErrors) {
            throw $_
        }
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
    if ($EnableVerbose) {
        Write-Host "Processing directory: $($directory.FullName)"
    }
    Set-ACL -path $directory.FullName
}

# If FoldersOnly is not specified, apply ACL to files
if (-not $FoldersOnly) {
    Write-Host "Applying ACL to files..."
    foreach ($file in $files) {
        if ($EnableVerbose) {
            Write-Host "Processing file: $($file.FullName)"
        }
        Set-ACL -path $file.FullName
    }
}

# Complete the progress bar
Write-Progress -PercentComplete 100 -Activity "Applying ACL Completed" -Status "All items processed"
Write-Host "ACL application process completed."

# Finish script
Write-Host "Script execution completed."
