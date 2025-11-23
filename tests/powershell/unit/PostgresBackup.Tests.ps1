<#
.SYNOPSIS
    Unit tests for PostgresBackup module

.DESCRIPTION
    Pester tests for the PostgresBackup PowerShell module
    Tests backup creation, service management, retention policies, and error handling
#>

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

    # Mock external dependencies
    Mock Get-Service {
        return [PSCustomObject]@{
            Name = "postgresql-x64-17"
            Status = "Running"
        }
    }

    Mock Start-Service { }
    Mock Stop-Service { }
    Mock Start-Sleep { }
}

Describe "Backup-PostgresDatabase" {

    Context "Successful Backup Creation" {
        BeforeEach {
            # Clean up test directory before each test
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Creates backup file with correct naming convention" {
            Mock Invoke-Command {
                # Create a dummy backup file
                $backupFile = Get-ChildItem -Path $script:testBackupFolder -Filter "*.backup" | Select-Object -First 1
                if (-not $backupFile) {
                    $files = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
                    if ($files.Count -gt 0) {
                        $backupFile = $files[0]
                    }
                }
                if ($backupFile) {
                    "Mock backup data" | Out-File -FilePath $backupFile.FullName
                }
            }

            # Mock pg_dump execution to create the backup file
            Mock Invoke-Expression {
                param($Command)
                if ($Command -like "*pg_dump*") {
                    # Extract the backup file path from the command
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock backup data" | Out-File -FilePath $backupPath -Force
                    }
                }
            }

            # Use & to mock external command execution
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    # Extract file path and create mock backup
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

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

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

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

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $newLogFile `
                -user "test_user"

            Test-Path $newLogFolder | Should -Be $true
            Test-Path $newLogFile | Should -Be $true
        }

        It "Logs backup start with timestamp" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "\[\d{8}-\d{6}\] testdb: Backup Script started"
        }

        It "Logs successful backup completion" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "\[\d{8}-\d{6}\] testdb: Backup completed successfully"
        }
    }

    Context "Service Management" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Starts PostgreSQL service if not running" {
            Mock Get-Service {
                return [PSCustomObject]@{
                    Name = "postgresql-x64-17"
                    Status = "Stopped"
                }
            } -ParameterFilter { $Name -eq "postgresql-x64-17" }

            Mock Start-Service { }

            # Mock the service status change after start
            $script:serviceCallCount = 0
            Mock Get-Service {
                $script:serviceCallCount++
                if ($script:serviceCallCount -le 1) {
                    return [PSCustomObject]@{
                        Name = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                } else {
                    return [PSCustomObject]@{
                        Name = "postgresql-x64-17"
                        Status = "Running"
                    }
                }
            }

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
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
            $script:getServiceCallCount = 0
            Mock Get-Service {
                $script:getServiceCallCount++
                # First call returns Stopped, subsequent calls return Running, then Stopped after stop
                if ($script:getServiceCallCount -eq 1) {
                    return [PSCustomObject]@{
                        Name = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                } elseif ($script:getServiceCallCount -le 3) {
                    return [PSCustomObject]@{
                        Name = "postgresql-x64-17"
                        Status = "Running"
                    }
                } else {
                    return [PSCustomObject]@{
                        Name = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                }
            }

            Mock Start-Service { }
            Mock Stop-Service { }

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

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
                    Name = "postgresql-x64-17"
                    Status = "Running"
                }
            }

            Mock Stop-Service { }

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Should -Invoke Stop-Service -Times 0
        }
    }

    Context "Retention Policy - Old Backups" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }

            # Create mock backup files with different ages
            $now = Get-Date

            # Create old backups (older than retention period)
            $oldFile1 = Join-Path $script:testBackupFolder "testdb_backup_2024-01-15_10-00-00.backup"
            $oldFile2 = Join-Path $script:testBackupFolder "testdb_backup_2024-02-20_10-00-00.backup"

            # Create recent backups (within retention period)
            $recentFile1 = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-5).ToString('yyyy-MM-dd'))_10-00-00.backup"
            $recentFile2 = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-10).ToString('yyyy-MM-dd'))_10-00-00.backup"
            $recentFile3 = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-15).ToString('yyyy-MM-dd'))_10-00-00.backup"

            "Mock data" | Out-File -FilePath $oldFile1 -Force
            "Mock data" | Out-File -FilePath $oldFile2 -Force
            "Mock data" | Out-File -FilePath $recentFile1 -Force
            "Mock data" | Out-File -FilePath $recentFile2 -Force
            "Mock data" | Out-File -FilePath $recentFile3 -Force

            # Set LastWriteTime to match the dates in filenames
            (Get-Item $oldFile1).LastWriteTime = [DateTime]::Parse("2024-01-15 10:00:00")
            (Get-Item $oldFile2).LastWriteTime = [DateTime]::Parse("2024-02-20 10:00:00")
            (Get-Item $recentFile1).LastWriteTime = $now.AddDays(-5)
            (Get-Item $recentFile2).LastWriteTime = $now.AddDays(-10)
            (Get-Item $recentFile3).LastWriteTime = $now.AddDays(-15)
        }

        It "Deletes backups older than retention period when min_backups threshold is met" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            # Count files before
            $filesBefore = (Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup").Count

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -retention_days 30 `
                -min_backups 3

            # Old backups should be deleted
            $filesAfter = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
            $oldBackupsRemaining = $filesAfter | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

            $oldBackupsRemaining.Count | Should -Be 0
            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Deleted old backup"
        }

        It "Does not delete recent backups below min_backups threshold" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            # Remove some recent backups to go below threshold
            Get-ChildItem -Path $script:testBackupFolder | Select-Object -Last 2 | Remove-Item -Force

            $filesBefore = (Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup").Count

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user" `
                -retention_days 30 `
                -min_backups 5

            # Should not delete old backups because we don't have enough recent ones
            $oldBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

            $oldBackups.Count | Should -BeGreaterThan 0
        }
    }

    Context "Retention Policy - Zero-Byte Backups" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }

            # Create zero-byte backup files
            $zeroByteFile1 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-20_10-00-00.backup"
            $zeroByteFile2 = Join-Path $script:testBackupFolder "testdb_backup_2025-11-21_10-00-00.backup"

            # Create valid backup files
            $validFile = Join-Path $script:testBackupFolder "testdb_backup_2025-11-22_10-00-00.backup"

            New-Item -Path $zeroByteFile1 -ItemType File -Force | Out-Null
            New-Item -Path $zeroByteFile2 -ItemType File -Force | Out-Null
            "Valid backup data" | Out-File -FilePath $validFile -Force
        }

        It "Deletes zero-byte backup files" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            # Count zero-byte files before
            $zeroByteFilesBefore = (Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.Length -eq 0 }).Count

            $zeroByteFilesBefore | Should -Be 2

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            # Zero-byte files should be deleted
            $zeroByteFilesAfter = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.Length -eq 0 }

            $zeroByteFilesAfter.Count | Should -Be 0

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Deleted 0-byte backup"
        }

        It "Does not delete valid backup files" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            # Valid files should still exist
            $validFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.Length -gt 0 }

            $validFiles.Count | Should -BeGreaterThan 0
        }
    }

    Context "Error Handling" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Exits with code 1 when pg_dump fails" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump failed"
                }
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
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "Connection to database failed"
                }
            }

            try {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } catch {
                # Expected to throw
            }

            Test-Path $script:testLogFile | Should -Be $true
            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup failed"
        }

        It "Handles service start timeout" {
            Mock Get-Service {
                return [PSCustomObject]@{
                    Name = "postgresql-x64-17"
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
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

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
    }

    Context "Password Handling" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Uses .pgpass authentication when password is not provided" {
            $script:capturedCommand = ""
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $script:capturedCommand = $Command
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            # Should use empty password (relying on .pgpass)
            $script:capturedCommand | Should -Match "test_user:@localhost"
        }

        It "Uses provided password when specified" {
            $securePassword = ConvertTo-SecureString "test_password" -AsPlainText -Force
            $script:capturedCommand = ""

            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $script:capturedCommand = $Command
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

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

    Context "Custom Format Backup" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Uses custom format for pg_dump" {
            $script:capturedCommand = ""
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $script:capturedCommand = $Command
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $script:capturedCommand | Should -Match "--format=custom"
        }

        It "Backup file has .backup extension" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $backupFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "*.backup"
            $backupFiles.Count | Should -BeGreaterThan 0
            $backupFiles[0].Extension | Should -Be ".backup"
        }
    }
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:testDir) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove imported module
    Remove-Module PostgresBackup -ErrorAction SilentlyContinue
}
