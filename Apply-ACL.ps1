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
Write-Verbose "Checking if source folder exists: $sourceFolder"
if (-not (Test-Path $sourceFolder)) {
    Write-Error "Source folder '$sourceFolder' does not exist."
    exit 1
}
Write-Verbose "Source folder exists: $sourceFolder"

# Retrieve ACL from the source folder
Write-Verbose "Retrieving ACL from source folder..."
try {
    $acl = Get-Acl $sourceFolder
    Write-Verbose "ACL retrieved successfully from: $sourceFolder"
} catch {
    Write-Error "Failed to retrieve ACL from source folder: $sourceFolder"
    exit 1
}

# Prepare target items
Write-Verbose "Gathering target items from: $targetFolder"
try {
    if ($FoldersOnly) {
        $targetItems = Get-ChildItem -Path $targetFolder -Recurse -Directory
        Write-Verbose "Found $($targetItems.Count) directories in target folder."
    } else {
        $directories = Get-ChildItem -Path $targetFolder -Recurse -Directory
        $files = Get-ChildItem -Path $targetFolder -Recurse -File
        $targetItems = $directories + $files
        Write-Verbose "Found $($directories.Count) directories and $($files.Count) files in target folder."
    }
} catch {
    Write-Error "Failed to retrieve items from target folder: $targetFolder"
    exit 1
}

$totalItems = $targetItems.Count
$currentItem = 0

# Function to apply ACL to a path
function Set-ACL {
    param (
        [string]$path
    )
    try {
        # Get the current ACL of the target
        $currentAcl = Get-Acl -Path $path

        # Skip if the ACL has only inherited rules
        if ($currentAcl.Access | Where-Object { $_.IsInherited } | Measure-Object | Select-Object -ExpandProperty Count -eq $currentAcl.Access.Count) {
            Write-Verbose "Skipping $path as it only has inherited permissions."
            return
        }

        # Apply the source ACL
        Set-Acl -Path $path -AclObject $acl
        Write-Verbose "Applied ACL to: $path"

        # Update progress
        $global:currentItem++
        Show-Progress -current $global:currentItem -total $global:totalItems -activity "Applying ACL" -status "$global:currentItem of $($global:totalItems) processed"
    } catch {
        if (-not $SkipErrors) {
            throw $_
        }
        Write-Warning "Failed to apply ACL to: $path"
    }
}

# Function to display progress
function Show-Progress {
    param ($current, $total, $activity, $status)
    Write-Progress -PercentComplete (($current / $total) * 100) -Activity $activity -Status $status
}

# Apply ACLs to target items
Write-Verbose "Starting ACL application..."
foreach ($item in $targetItems) {
    Set-ACL -path $item.FullName
}

# Complete progress
Write-Progress -PercentComplete 100 -Activity "Applying ACL Completed" -Status "All items processed"
Write-Host "ACL application process completed."
