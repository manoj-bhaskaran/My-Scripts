<#
.SYNOPSIS
    Clears Recycle Bin items older than 7 days for the current user.
.DESCRIPTION
    Scans all local drives for $Recycle.Bin folders and removes items
    older than 7 days for the current user's SID.
.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\common\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "ClearOldRecycleBinItems" -LogLevel 20

Write-LogInfo "Starting Recycle Bin cleanup for items older than 7 days"

# Get all local drives that contain $Recycle.Bin
$recycleDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path "$($_.Root)\`$Recycle.Bin"
}

Write-LogInfo "Found $($recycleDrives.Count) drive(s) with Recycle Bin"

# Get current user SID
$userSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$cutoffDate = (Get-Date).AddDays(-7)

Write-LogDebug "User SID: $userSID, Cutoff date: $cutoffDate"

$totalDeleted = 0
$totalErrors = 0

foreach ($drive in $recycleDrives) {
    $basePath = Join-Path $drive.Root '$Recycle.Bin'
    $userRecycleBin = Join-Path $basePath $userSID

    if (-not (Test-Path $userRecycleBin)) {
        Write-LogWarning "Recycle Bin path not found for user on $($drive.Name)"
        continue
    }

    Write-LogInfo "Processing Recycle Bin on drive $($drive.Name)"

    Get-ChildItem -Path $userRecycleBin -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.LastWriteTime -lt $cutoffDate) {
                Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
                $totalDeleted++
                Write-LogDebug "Deleted: $($_.FullName)"
            }
        } catch {
            $totalErrors++
            Write-LogWarning "Failed to delete '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}

Write-LogInfo "Recycle Bin cleanup completed. Deleted: $totalDeleted, Errors: $totalErrors"
