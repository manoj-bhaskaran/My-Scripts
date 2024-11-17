<#
.SYNOPSIS
    This script applies Access Control Lists (ACLs) from a source folder to a target folder and its subfolders.

.DESCRIPTION
    The script retrieves the ACL from the source folder and applies it to the target folder and its subdirectories.
    You can choose to apply the ACL only to folders or to both folders and files. Errors can be skipped, and a progress bar is provided to track progress.

.PARAMETER sourceFolder
    The full path to the source folder from which the ACL settings will be copied.

.PARAMETER targetFolder
    The full path to the target folder where the ACL settings will be applied.

.PARAMETER SkipErrors
    A switch to skip errors and continue processing other items.

.PARAMETER FoldersOnly
    A switch to apply the ACL only to folders, excluding files.

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Source" -targetFolder "D:\Target"

.EXAMPLE
    .\Set-ACL.ps1 -sourceFolder "C:\Source" -targetFolder "D:\Target" -SkipErrors -FoldersOnly -Verbose
    Applies the ACL from the source folder to folders only, skipping errors, with verbose messages enabled.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$sourceFolder,

    [Parameter(Mandatory = $true)]
    [string]$targetFolder,

    [switch]$SkipErrors,

    [switch]$FoldersOnly
)

# Check if the source folder exists
Write-Verbose "Starting the script execution..."
Write-Verbose "Checking if the source folder exists at path: '$sourceFolder'"
if (-not (Test-Path $sourceFolder)) {
    Write-Error "The source folder '$sourceFolder' does not exist. Please provide a valid path and try again."
    exit 1
}
Write-Verbose "Source folder verification complete. Source folder exists: '$sourceFolder'"

# Retrieve ACL from the source folder
Write-Verbose "Attempting to retrieve ACL from the source folder: '$sourceFolder'"
try {
    $acl = Get-Acl $sourceFolder
    Write-Verbose "Successfully retrieved ACL from the source folder. ACL details: $($acl.Access | Format-Table | Out-String)"
} catch {
    Write-Error "Failed to retrieve ACL from the source folder: '$sourceFolder'. Exception: $_"
    exit 1
}

# Prepare target items
Write-Verbose "Gathering target items from: $targetFolder"
try {
    # Always include the target folder itself
    $targetItems = @($targetFolder)

    if ($FoldersOnly) {
        # If only folders, add directories from the target folder recursively
        $targetItems += Get-ChildItem -Path $targetFolder -Recurse -Directory
        Write-Verbose "Found $($targetItems.Count) directories in target folder, including the target folder."
    } else {
        # If both files and folders, add directories and files
        $directories = Get-ChildItem -Path $targetFolder -Recurse -Directory
        $files = Get-ChildItem -Path $targetFolder -Recurse -File
        $targetItems += $directories + $files
        Write-Verbose "Found $($directories.Count) directories and $($files.Count) files in target folder, including the target folder."
    }
} catch {
    Write-Error "Failed to retrieve items from target folder: $targetFolder"
    exit 1
}

$totalItems = $targetItems.Count
$currentItem = 0
Write-Verbose "Preparation complete. Total items to process: $totalItems"

# Function to apply ACL to a path
function Set-ACL {
    param (
        [string]$path
    )
    Write-Verbose "Processing item: '$path'"
    try {
        # Retrieve current ACL
        $currentAcl = Get-Acl -Path $path
        Write-Verbose "Retrieved current ACL for '$path'. Verifying inherited permissions."
    
        # Count the inherited rules
        $inheritedCount = ($currentAcl.Access | Where-Object { $_.IsInherited }).Count
    
        # Skip if all permissions are inherited
        if ($inheritedCount -eq $currentAcl.Access.Count) {
            Write-Verbose "Item '$path' contains only inherited permissions. Skipping ACL update."
            return
        }
    
        # Apply the source ACL
        Write-Verbose "Applying ACL to '$path' using source folder ACL."
        Set-Acl -Path $path -AclObject $acl
        Write-Verbose "Successfully applied ACL to '$path'."
    
        # Update progress
        $global:currentItem++
        Show-Progress -current $global:currentItem -total $global:totalItems -activity "Applying ACL" -status "Processed $global:currentItem of $($global:totalItems)"
    } catch {
        if (-not $SkipErrors) {
            throw $_
        }
        Write-Warning "Failed to apply ACL to '$path'. Skipping. Error: $_"
    }
}    

# Function to display progress
function Show-Progress {
    param ($current, $total, $activity, $status)
    Write-Progress -PercentComplete (($current / $total) * 100) -Activity $activity -Status $status
}

# Apply ACLs to target items
Write-Verbose "Starting the ACL application process."
foreach ($item in $targetItems) {
    Set-ACL -path $item.FullName
}

# Complete progress
Write-Progress -PercentComplete 100 -Activity "Applying ACL Completed" -Status "All items processed"
Write-Host "ACL application process completed successfully for $($targetItems.Count) items."
