<#
.SYNOPSIS
    Unit tests for PostgresBackup module

.DESCRIPTION
    Pester tests for the PostgresBackup PowerShell module
    Tests backup creation, service management, retention policies, and error handling

.NOTES
    These tests are Windows-specific as the PostgresBackup module uses Windows services.
    Tests will be skipped on non-Windows platforms.
#>

# Suppress PSScriptAnalyzer warning for test credential creation
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test file requires plaintext conversion for credential mocking')]
param()

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Database\PostgresBackup\PostgresBackup.psm1"
    Import-Module $modulePath -Force

    # Create temp directory for test backups and logs
    $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "PostgresBackupTests_$([guid]::NewGuid())"
    $script:testBackupFolder = Join-Path $script:testDir "backups"
    $script:testLogFile = Join-Path $script:testDir "test.log"
    New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testBackupFolder -ItemType Directory -Force | Out-Null
}

Describe "Backup-PostgresDatabase" -Skip:($env:OS -ne 'Windows_NT') {

    BeforeAll {
        # Mock external dependencies
        Mock Get-Service {
            return [PSCustomObject]@{
                Name   = "postgresql-x64-17"
                Status = "Running"
            }
        }

        Mock Start-Service { }
        Mock Stop-Service { }
        Mock Start-Sleep { }
    }

    BeforeEach {
        # Clean up test directory before each test
        if (Test-Path $script:testBackupFolder) {
            Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
        }
        if (Test-Path $script:testLogFile) {
            Remove-Item -Path $script:testLogFile -Force
        }
        $script:capturedCommand = ""
        Mock -CommandName 'Invoke-PgDump' -ModuleName 'PostgresBackup' -MockWith {
            param($ArgumentList, $LogFilePath)
            $script:capturedCommand = $ArgumentList -join ' '
            $fileArg = $ArgumentList | Where-Object { $_ -like '--file=*' }
            if ($fileArg) {
                $backupPath = $fileArg -replace '^--file=', ''
                "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
            }
            $global:LASTEXITCODE = 0
        }
    }

    Context "Successful Backup Creation" {

        It "Creates backup file with correct naming convention" {
            # Execute backup
            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -retention_days 90 `
                -min_backups 3

            # Verify backup file naming convention: testdb_backup_YYYY-MM-DD_HH-mm-ss.backup
            $backupFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
            $backupFiles.Count | Should -BeGreaterThan 0
            $backupFiles[0].Name | Should -Match "^testdb_backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.backup$"
        }

        It "Creates backup directory if it doesn't exist" {
            $newBackupFolder = Join-Path $script:testDir "new_backups"

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $newBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Test-Path $newBackupFolder | Should -Be $true
        }

        It "Creates log file directory if it doesn't exist" {
            $newLogFolder = Join-Path $script:testDir "logs"
            $newLogFile = Join-Path $newLogFolder "test.log"

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $newLogFile `
                -user "test_user"

            Test-Path $newLogFolder | Should -Be $true
            Test-Path $newLogFile | Should -Be $true
        }

        It "Logs backup start with timestamp" {

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "\[\d{8}-\d{6}\] testdb: Backup Script started"
        }

        It "Logs successful backup completion" {

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "\[\d{8}-\d{6}\] testdb: Backup completed successfully"
        }

        It "Uses custom format for pg_dump" {

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $script:capturedCommand | Should -Match "--format=custom"
        }
    }

    Context "Service Management" {
        BeforeEach {
            $script:serviceCallCount = 0
            $script:getServiceCallCount = 0
        }

        It "Starts PostgreSQL service if not running" {
            # Mock the service status change after start
            Mock Get-Service {
                $script:serviceCallCount++
                if ($script:serviceCallCount -le 1) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                } else {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Running"
                    }
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Should -Invoke Start-Service -Times 1
        }

        It "Stops PostgreSQL service after backup if it was stopped initially" {
            Mock Get-Service {
                $script:getServiceCallCount++
                # First call returns Stopped, subsequent calls return Running, then Stopped after stop
                if ($script:getServiceCallCount -eq 1) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                } elseif ($script:getServiceCallCount -le 3) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Running"
                    }
                } else {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                }
            }

            Mock Start-Service { }
            Mock Stop-Service { }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Should -Invoke Stop-Service -Times 1
        }

        It "Leaves PostgreSQL service running if it was running initially" {
            Mock Get-Service {
                return [PSCustomObject]@{
                    Name   = "postgresql-x64-17"
                    Status = "Running"
                }
            }

            Mock Stop-Service { }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Should -Invoke Stop-Service -Times 0
        }
    }

    Context "Retention Policy" {

        BeforeAll {
            function New-TestBackupFile {
                param (
                    [string]$Path,
                    [int]$AgeDays = 0,
                    [string]$Content = "Mock backup data",
                    [switch]$Empty
                )
                if ($Empty) {
                    New-Item -Path $Path -ItemType File -Force | Out-Null
                } else {
                    $Content | Out-File -FilePath $Path -Force
                }
                if ($AgeDays -gt 0) {
                    (Get-Item $Path).LastWriteTime = (Get-Date).AddDays(-$AgeDays)
                }
            }
        }

        Context "Remove-ZeroByteBackups" {

            It "Deletes zero-byte backup files" {
                $zeroByteFile1 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-20_10-00-00.backup"
                $zeroByteFile2 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-21_10-00-00.backup"
                $validFile = Join-Path $script:testBackupFolder "testdb_backup_2025-11-22_10-00-00.backup"
                New-TestBackupFile -Path $zeroByteFile1 -Empty
                New-TestBackupFile -Path $zeroByteFile2 -Empty
                New-TestBackupFile -Path $validFile

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-ZeroByteBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log
                }

                $remaining = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.Length -eq 0 }
                $remaining.Count | Should -Be 0
                (Get-Content -Path $script:testLogFile -Raw) | Should -Match "Deleted 0-byte backup"
            }

            It "Does not delete valid backup files" {
                $zeroByteFile1 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-20_10-00-00.backup"
                $zeroByteFile2 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-21_10-00-00.backup"
                $validFile = Join-Path $script:testBackupFolder "testdb_backup_2025-11-22_10-00-00.backup"
                New-TestBackupFile -Path $zeroByteFile1 -Empty
                New-TestBackupFile -Path $zeroByteFile2 -Empty
                New-TestBackupFile -Path $validFile

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-ZeroByteBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log
                }

                $validFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.Length -gt 0 }
                $validFiles.Count | Should -BeGreaterThan 0
            }
        }

        Context "Remove-OldBackups" {

            It "Deletes backups older than retention period when min_backups threshold is met" {
                $now = Get-Date
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_2024-01-15_10-00-00.backup") -AgeDays 365
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_2024-02-20_10-00-00.backup") -AgeDays 340
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-5).ToString('yyyy-MM-dd'))_10-00-00.backup") -AgeDays 5
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-10).ToString('yyyy-MM-dd'))_10-00-00.backup") -AgeDays 10
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-15).ToString('yyyy-MM-dd'))_10-00-00.backup") -AgeDays 15

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 30 -MinBackups 3
                }

                $oldBackupsRemaining = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                $oldBackupsRemaining.Count | Should -Be 0
                (Get-Content -Path $script:testLogFile -Raw) | Should -Match "Deleted old backup"
            }

            It "Does not delete old backups when recent backup count is below min_backups" {
                $now = Get-Date
                # 2 old + 2 recent = 4 total; min_backups=5 means threshold not met, old files kept
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_2024-01-15_10-00-00.backup") -AgeDays 365
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_2024-02-20_10-00-00.backup") -AgeDays 340
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-5).ToString('yyyy-MM-dd'))_10-00-00.backup") -AgeDays 5
                New-TestBackupFile -Path (Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-10).ToString('yyyy-MM-dd'))_10-00-00.backup") -AgeDays 10

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 30 -MinBackups 5
                }

                $oldBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                $oldBackups.Count | Should -BeGreaterThan 0
            }

            It "Handles retention with exactly min_backups count" {
                $now = Get-Date
                # 3 backups aged 1, 2, 3 days; retention_days=1 means files aged 2+ are old;
                # with min_backups=3 and at most 1 recent file, threshold not met — no deletion occurs
                1..3 | ForEach-Object {
                    $path = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-$_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                    New-TestBackupFile -Path $path -AgeDays $_
                }

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 1 -MinBackups 3
                }

                $backupFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
                $backupFiles.Count | Should -BeGreaterOrEqual 3
            }

            It "Handles retention_days set to 0" {
                $now = Get-Date
                $oldFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-10).ToString('yyyy-MM-dd'))_10-00-00.backup"
                # Anchor one file 1 day in the future so it is always newer than Remove-OldBackups'
                # internal (Get-Date) cutoff, regardless of how long execution takes
                $recentFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.ToString('yyyy-MM-dd'))_23-59-59.backup"
                New-TestBackupFile -Path $oldFile -AgeDays 10
                New-TestBackupFile -Path $recentFile
                (Get-Item $recentFile).LastWriteTime = $now.AddDays(1)

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 0 -MinBackups 1
                }

                # retention_days=0 means cutoff is now; the 10-day-old file should be deleted
                $remainingOld = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.LastWriteTime -lt $now.AddDays(-1) }
                $remainingOld.Count | Should -Be 0
            }

            It "Deletes old backups when min_backups is 0" {
                $now = Get-Date
                $oldFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-45).ToString('yyyy-MM-dd'))_10-00-00.backup"
                New-TestBackupFile -Path $oldFile -AgeDays 45

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 30 -MinBackups 0
                }

                Test-Path $oldFile | Should -Be $false
            }

            It "Only deletes backups for specified database" {
                $now = Get-Date
                $db1File = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-100).ToString('yyyy-MM-dd'))_10-00-00.backup"
                $db2File = Join-Path $script:testBackupFolder "otherdb_backup_$($now.AddDays(-100).ToString('yyyy-MM-dd'))_10-00-00.backup"
                # One recent testdb backup is required so recent_count(1) >= MinBackups(1) and deletion is eligible
                $recentFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-1).ToString('yyyy-MM-dd'))_10-00-00.backup"
                New-TestBackupFile -Path $db1File -AgeDays 100
                New-TestBackupFile -Path $db2File -AgeDays 100
                New-TestBackupFile -Path $recentFile -AgeDays 1

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 30 -MinBackups 1
                }

                Test-Path $db1File | Should -Be $false
                Test-Path $db2File | Should -Be $true
            }

            It "Deletes all old backups when old backup count greatly exceeds min_backups" {
                $now = Get-Date

                # Create 5 old backups (100+ days old)
                1..5 | ForEach-Object {
                    $path = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-100 - $_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                    New-TestBackupFile -Path $path -AgeDays (100 + $_)
                }

                # Create 5 recent backups
                1..5 | ForEach-Object {
                    $path = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-$_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                    New-TestBackupFile -Path $path -AgeDays $_
                }

                InModuleScope 'PostgresBackup' -Parameters @{ Folder = $script:testBackupFolder; Log = $script:testLogFile } {
                    param($Folder, $Log)
                    Remove-OldBackups -BackupFolder $Folder -DatabaseName 'testdb' -LogFile $Log -RetentionDays 30 -MinBackups 3
                }

                $oldBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                    Where-Object { $_.LastWriteTime -lt $now.AddDays(-30) }
                $oldBackups.Count | Should -Be 0

                $allBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
                $allBackups.Count | Should -BeGreaterOrEqual 5
            }
        }
    }

    Context "Error Scenarios" {
        BeforeEach {
            $script:getServiceCallCount = 0
        }

        # --- pg_dump failures ---

        It "Exits with code 1 when pg_dump fails" {
            Mock -CommandName 'Invoke-PgDump' -ModuleName 'PostgresBackup' -MockWith {
                $global:LASTEXITCODE = 1
                throw "pg_dump failed"
            }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw
        }

        It "Logs error when backup fails" {
            Mock -CommandName 'Invoke-PgDump' -ModuleName 'PostgresBackup' -MockWith {
                $global:LASTEXITCODE = 1
                throw "Connection to database failed"
            }

            try {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } catch {
                $null = $_
            }

            Test-Path $script:testLogFile | Should -Be $true
            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup failed"
        }

        It "Handles service start timeout" {
            Mock Get-Service {
                return [PSCustomObject]@{
                    Name   = "postgresql-x64-17"
                    Status = "Stopped"
                }
            }

            Mock Start-Service { }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw "*did not reach Running status*"
        }

        It "Logs cleanup failures" {
            # Create a backup file first

            # Create an old backup file
            $oldFile = Join-Path $script:testBackupFolder "testdb_backup_2024-01-15_10-00-00.backup"
            "Mock data" | Out-File -FilePath $oldFile -Force
            (Get-Item $oldFile).LastWriteTime = [DateTime]::Parse("2024-01-15 10:00:00")

            # Mock Remove-Item to fail
            Mock Remove-Item {
                throw "Access denied"
            } -ParameterFilter { $Path -like "*testdb_backup_*.backup" }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user" `
                    -retention_days 30 `
                    -min_backups 1
            } | Should -Throw

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup file cleanup failed"
        }

        It "Handles permission denied on backup folder" {
            $restrictedFolder = Join-Path $script:testDir "restricted"
            if (Test-Path $restrictedFolder) {
                Remove-Item -Path $restrictedFolder -Recurse -Force
            }

            # Mock New-Item to fail
            Mock New-Item {
                throw "Access to the path is denied"
            } -ModuleName 'PostgresBackup' -ParameterFilter { $Path -eq $restrictedFolder -and $ItemType -eq "Directory" }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $restrictedFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw
        }

        It "Logs pg_dump warning output" {
            Mock -CommandName 'Invoke-PgDump' -ModuleName 'PostgresBackup' -MockWith {
                param($ArgumentList, $LogFilePath)
                $fileArg = $ArgumentList | Where-Object { $_ -like '--file=*' }
                if ($fileArg) {
                    $backupPath = $fileArg -replace '^--file=', ''
                    "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                }
                # Simulate pg_dump warning output being captured to log
                Add-Content -Path $LogFilePath -Value "pg_dump: warning: some deprecated features used" -Encoding utf8
                $global:LASTEXITCODE = 0
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Test-Path $script:testLogFile | Should -Be $true
            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "pg_dump: warning: some deprecated features used"
            $logContent | Should -Match "Backup completed successfully"
        }

        # --- Service management errors ---

        It "Handles service stop failure after successful backup" {
            Mock Get-Service {
                $script:getServiceCallCount++
                if ($script:getServiceCallCount -eq 1) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                } else {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Running"
                    }
                }
            }

            Mock Start-Service { }
            Mock Stop-Service {
                throw "Failed to stop service"
            }

            # Service stop failure should cause the function to throw
            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw
        }

        # --- Zero-byte cleanup failures ---

        It "Throws when zero-byte cleanup fails after backup creation" {
            # Create a zero-byte file that can't be deleted
            $zeroByteFile = Join-Path $script:testBackupFolder "testdb_backup_2024-01-01_10-00-00.backup"
            New-Item -Path $zeroByteFile -ItemType File -Force | Out-Null

            Mock Remove-Item {
                throw "Access denied"
            } -ParameterFilter { $Path -like "*testdb_backup_*.backup" }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup file cleanup failed"
        }
    }

    Context "Password Handling" {

        It "Uses .pgpass authentication when password is not provided" {

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            # Should use standard options (not connection string) to allow .pgpass lookup
            $script:capturedCommand | Should -Match "-U test_user"
            $script:capturedCommand | Should -Match "-d testdb"
            $script:capturedCommand | Should -Match "-h localhost"
            $script:capturedCommand | Should -Not -Match "postgresql://"
        }

        It "Uses provided password when specified" {
            $securePassword = ConvertTo-SecureString "test_password" -AsPlainText -Force

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -password $securePassword

            # Password should be URL-encoded in the connection string
            $script:capturedCommand | Should -Match "test_user:test_password@localhost"
        }
    }

    Context "Invalid Database Scenarios" {

        It "Handles non-existent database gracefully" {
            Mock -CommandName 'Invoke-PgDump' -ModuleName 'PostgresBackup' -MockWith {
                $global:LASTEXITCODE = 1
                throw "pg_dump: error: connection to server at localhost, port 5432 failed: FATAL: database 'nonexistent_db' does not exist"
            }

            {
                Backup-PostgresDatabase `
                    -dbname "nonexistent_db" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup failed"
        }
    }

    Context "Special Characters and URL Encoding" {

        It "Properly encodes password with special characters" {
            $securePassword = ConvertTo-SecureString "p@ssw0rd!#$%&*" -AsPlainText -Force

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -password $securePassword

            # Password should be URL-encoded
            $script:capturedCommand | Should -Match "p%40ssw0rd"
        }

        It "Handles password with spaces" {
            $securePassword = ConvertTo-SecureString "my password 123" -AsPlainText -Force

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -password $securePassword

            # Spaces should be URL-encoded as %20
            $script:capturedCommand | Should -Match "my%20password%20123"
        }

        It "Passes username through in no-password mode" {

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test.user@domain"

            # No-password mode uses separate CLI args, so username should be passed as-is
            $script:capturedCommand | Should -Match "test\.user@domain"
        }
    }

}

AfterAll {
    # Clean up test directory (only if tests ran on Windows)
    if ($env:OS -eq 'Windows_NT' -and $script:testDir -and (Test-Path $script:testDir)) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove imported module
    if ($env:OS -eq 'Windows_NT') {
        Remove-Module PostgresBackup -ErrorAction SilentlyContinue
    }
}
