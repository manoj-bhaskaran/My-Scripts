function Remove-OldBackups {
    param (
        [string]$BackupFolder,
        [string]$DatabaseName,
        [string]$LogFile,
        [int]$RetentionDays,
        [int]$MinBackups
    )

    $backup_files = Get-ChildItem -Path $BackupFolder -Filter "${DatabaseName}_backup_*.backup"
    $cutoff_date = (Get-Date).AddDays(-$RetentionDays)
    $files_deleted = $false
    $recent_backup_count = ($backup_files | Where-Object { $_.LastWriteTime -ge $cutoff_date }).Count
    if ($recent_backup_count -ge $MinBackups) {
        $files_to_delete = $backup_files | Where-Object { $_.LastWriteTime -lt $cutoff_date }
        foreach ($file in $files_to_delete) {
            Remove-Item -Path $file.FullName -Force
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $LogFile -Value "[$timestamp] ${DatabaseName}: Deleted old backup: $($file.FullName)" -Encoding utf8
            $files_deleted = $true
        }
    }
    return $files_deleted
}

function Remove-ZeroByteBackups {
    param (
        [string]$BackupFolder,
        [string]$DatabaseName,
        [string]$LogFile
    )

    $backup_files = Get-ChildItem -Path $BackupFolder -Filter "${DatabaseName}_backup_*.backup"
    $files_deleted = $false
    foreach ($file in $backup_files) {
        if ($file.Length -eq 0) {
            Remove-Item -Path $file.FullName -Force
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $LogFile -Value "[$timestamp] ${DatabaseName}: Deleted 0-byte backup: $($file.FullName)" -Encoding utf8
            $files_deleted = $true
        }
    }
    return $files_deleted
}
