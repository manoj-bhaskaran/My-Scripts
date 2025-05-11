# Get current user's SID
$userSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$cutoffDate = (Get-Date).AddDays(-7)

# Get all drives that have $Recycle.Bin
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path "$($_.Root)`$Recycle.Bin"
}

foreach ($drive in $drives) {
    $recyclePath = Join-Path -Path $drive.Root -ChildPath "\$Recycle.Bin\$userSID"

    if (-not (Test-Path $recyclePath)) {
        Write-Host "No recycle bin found for user on drive $($drive.Name)"
        continue
    }

    Write-Host "`nScanning $recyclePath..."

    Get-ChildItem -Path $recyclePath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.LastWriteTime -lt $cutoffDate) {
                Write-Host "Deleting: $($_.FullName)"
                Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
            }
        } catch {
            Write-Warning "Failed to delete '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}