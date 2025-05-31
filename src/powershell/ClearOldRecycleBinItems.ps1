# Get all local drives that contain $Recycle.Bin
$recycleDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path "$($_.Root)\`$Recycle.Bin"
}

# Get current user SID
$userSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$cutoffDate = (Get-Date).AddDays(-7)

foreach ($drive in $recycleDrives) {
    $basePath = Join-Path $drive.Root '$Recycle.Bin'
    $userRecycleBin = Join-Path $basePath $userSID

    if (-not (Test-Path $userRecycleBin)) {
        Write-Warning "Recycle Bin path not found for user on $($drive.Name)"
        continue
    }

    Get-ChildItem -Path $userRecycleBin -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.LastWriteTime -lt $cutoffDate) {
                Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
            }
        } catch {
            Write-Warning "Failed to delete '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}