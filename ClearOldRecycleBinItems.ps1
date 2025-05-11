# Get current user SID
$userSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

# List of drives to scan for Recycle Bin contents
$drives = @("C", "D")
$cutoffDate = (Get-Date).AddDays(-7)

foreach ($drive in $drives) {
    $recyclePath = "$drive`:\$Recycle.Bin\$userSID"

    if (-not (Test-Path $recyclePath)) {
        Write-Warning "Recycle Bin path not found on $drive"
        continue
    }

    Write-Host "`nScanning: $recyclePath"

    Get-ChildItem -Path $recyclePath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            # Compare using LastWriteTime (can also try CreationTime if needed)
            if ($_.LastWriteTime -lt $cutoffDate) {
                Write-Host "Deleting: $($_.FullName)"
                Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
            }
        } catch {
            Write-Warning "Failed to delete '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}