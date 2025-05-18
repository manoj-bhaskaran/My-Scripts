# Parameters for timeline_data backup
$dbname = "timeline_data"
$backup_folder = "D:\pgbackup\timeline_data"
$log_folder = "D:\pgbackup\logs"
$user = "backup_user"
$password = Get-Content "C:\Users\manoj\Documents\Scripts\pgbackup_user\pgbackup_user_pwd.txt" | ConvertTo-SecureString
$retention_days = 90
$min_backups = 3

# Call the common backup script
& "$PSScriptRoot\pg_backup_common.ps1" `
    -dbname $dbname `
    -backup_folder $backup_folder `
    -log_folder $log_folder `
    -user $user `
    -password $password `
    -retention_days $retention_days `
    -min_backups $min_backups