# Licensed under the Apache License, Version 2.0
# See http://www.apache.org/licenses/LICENSE-2.0 for details

# Backup script for the job_scheduler PostgreSQL database
# Requires pg_backup_common.ps1 from My-Scripts repository

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CommonScript = Join-Path $ScriptDir "..\..\My-Scripts\src\powershell\pg_backup_common.ps1"
. $CommonScript

$DatabaseName = "job_scheduler"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFolder = Join-Path $ScriptDir "..\..\backups\job_scheduler"
$LogFile = Join-Path $OutputFolder "job_scheduler_backup_$Timestamp.log"

# Ensure backup directory exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# Run the backup
Backup-PostgresDatabase -Database $DatabaseName -OutputFolder $OutputFolder -LogFile $LogFile
