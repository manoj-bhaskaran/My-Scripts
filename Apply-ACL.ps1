<#
.SYNOPSIS
    This script applies Access Control Lists (ACLs) from a source folder to a target folder and its subfolders and files.
    It can handle errors by skipping problematic items based on user input.

.DESCRIPTION
    The script retrieves the ACL from the source folder and applies it to the target folder and all its subdirectories and files.
    It also provides an option to skip errors if certain files or folders are missing in the target folder.
    A progress bar is displayed to track the application of ACLs to directories and files.

.PARAMETER sourceFolder
    The full path to the source folder from which the ACL settings will be copied.
    Example: "C:\Users\manoj\Documents\FIFA 07\elib"

.PARAMETER targetFolder
    The full path to the target folder where the ACL settings will be applied.
    Example: "D:\Users\manoj\Documents\FIFA 07\elib"

.PARAMETER SkipErrors
    A switch that, if provided, will allow the script to skip errors and continue processing other items.
    If not specified, the script will stop and throw an error if it encounters a missing item or failure.
    Example: `-SkipErrors`

.EXAMPLE
    .\Apply-ACL.ps1 -sourceFolder "C:\Users\manoj\Documents\FIFA 07\elib" -targetFolder "D:\Users\manoj\Documents\FIFA 07\elib"
    This will apply the ACL from the source folder to the target folder and its contents, stopping on errors.

.EXAMPLE
    .\Apply-ACL.ps1 -sourceFolder "C:\Users\manoj\Documents\FIFA 07\elib" -targetFolder "D:\Users\manoj\Documents\FIFA 07\elib" -SkipErrors
    This will apply the ACL from the source folder to the target folder and its contents, skipping over any errors.

.NOTES
    The script uses the `Get-Acl` cmdlet to retrieve the ACL from the source folder and the `Set-Acl` cmdlet to apply it to the target folder.
    The script processes both directories and files in the target folder, applying the ACL recursively.
    A progress bar is displayed to show the status of ACL application.
    If `$SkipErrors` is provided, missing files or folders will not halt the execution.
    If `$SkipErrors` is not provided, errors will throw and the script will stop.

#>

param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,

    [Parameter(Mandatory=$true)]
    [string]$targetFolder,

    [Switch]$SkipErrors
)

# Function to show progress
function Show-Progress {
    param (
        [int]$current,
        [int]$total,
        [string]$activity,
        [string]$status
    )
    Write-Progress -PercentComplete (($current / $total) * 100) -Activity $activity -Status $status
}

# Check if source folder exists
if (-not (Test-Path -Path $sourceFolder)) {
    Write-Host "Source folder does not exist: $sourceFolder"
    exit
}

# Get the ACL from the source folder
$acl = Get-Acl $sourceFolder

# Get all files and directories in the target folder (recursively)
$allItems = Get-ChildItem -Path $targetFolder -Recurse
$totalItems = $allItems.Count
$counter = 0

# Apply the ACL to the target folder itself
try {
    Set-Acl -Path $targetFolder -AclObject $acl
} catch {
    if (-not $SkipErrors) { throw $_ }
    Write-Warning "Failed to apply ACL to target folder: $targetFolder"
}

# Apply ACL to directories
$directories = $allItems | Where-Object { $_.PSIsContainer }
$directories | ForEach-Object {
    try {
        Set-Acl -Path $_.FullName -AclObject $acl
        $counter++
        # Update progress bar
        Show-Progress -current $counter -total $totalItems -activity "Applying ACL to Directories" -status "$counter of $totalItems directories processed"
    } catch {
        if (-not $SkipErrors) { throw $_ }
        Write-Warning "Failed to apply ACL to directory: $_"
    }
}

# Apply ACL to files
$files = $allItems | Where-Object { -not $_.PSIsContainer }
$files | ForEach-Object {
    try {
        Set-Acl -Path $_.FullName -AclObject $acl
        $counter++
        # Update progress bar
        Show-Progress -current $counter -total $totalItems -activity "Applying ACL to Files" -status "$counter of $totalItems files processed"
    } catch {
        if (-not $SkipErrors) { throw $_ }
        Write-Warning "Failed to apply ACL to file: $_"
    }
}

# Final completion
Write-Progress -PercentComplete 100 -Activity "Applying ACL" -Status "Process complete"
Write-Host "ACL application completed."
