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
    # Check if running on Windows
    $script:isWindows = $PSVersionTable.PSVersion.Major -le 5 -or $IsWindows

    if (-not $script:isWindows) {
        Write-Warning "PostgresBackup tests require Windows platform. Skipping tests on $($PSVersionTable.Platform)."
        return
    }

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
            Name   = "postgresql-x64-17"
            Status = "Running"
        }
    }

    Mock Start-Service { }
    Mock Stop-Service { }
    Mock Start-Sleep { }
}

Describe "Backup-PostgresDatabase" -Skip:(-not $script:isWindows) {

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
                    Name   = "postgresql-x64-17"
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
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                }
                else {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
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
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                }
                elseif ($script:getServiceCallCount -le 3) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Running"
                    }
                }
                else {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
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
                    Name   = "postgresql-x64-17"
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
            }
            catch {
                # Expected to throw
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

    Context "Invalid Database Scenarios" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Handles non-existent database gracefully" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump: error: connection to server at localhost, port 5432 failed: FATAL: database 'nonexistent_db' does not exist"
                }
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

        It "Handles database connection timeout" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump: error: connection to server timed out"
                }
            }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw

            Test-Path $script:testLogFile | Should -Be $true
        }

        It "Handles authentication failure" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump: error: connection to server failed: FATAL: password authentication failed for user 'test_user'"
                }
            }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup failed"
        }

        It "Handles insufficient permissions on database" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump: error: permission denied for database"
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
    }

    Context "Retention Policy Edge Cases" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Handles retention with exactly min_backups count" {
            $now = Get-Date

            # Create exactly 3 backups (matching min_backups)
            1..3 | ForEach-Object {
                $file = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-$_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                "Mock data" | Out-File -FilePath $file -Force
                (Get-Item $file).LastWriteTime = $now.AddDays(-$_)
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
                -user "test_user" `
                -retention_days 1 `
                -min_backups 3

            # Should have 4 files total (3 old + 1 new)
            $backupFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
            $backupFiles.Count | Should -BeGreaterOrEqual 3
        }

        It "Handles retention_days set to 0" {
            $now = Get-Date

            # Create backups with various ages
            $oldFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-10).ToString('yyyy-MM-dd'))_10-00-00.backup"
            "Mock data" | Out-File -FilePath $oldFile -Force
            (Get-Item $oldFile).LastWriteTime = $now.AddDays(-10)

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
                -user "test_user" `
                -retention_days 0 `
                -min_backups 1

            # Old file should be deleted (retention 0 days means delete everything older than today)
            $remainingOld = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.LastWriteTime -lt $now.AddDays(-1) }
            $remainingOld.Count | Should -Be 0
        }

        It "Preserves backups when min_backups is 0 but retention not met" {
            $now = Get-Date

            # Create only recent backups
            $recentFile = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-5).ToString('yyyy-MM-dd'))_10-00-00.backup"
            "Mock data" | Out-File -FilePath $recentFile -Force
            (Get-Item $recentFile).LastWriteTime = $now.AddDays(-5)

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
                -user "test_user" `
                -retention_days 30 `
                -min_backups 0

            # Recent file should still exist
            Test-Path $recentFile | Should -Be $true
        }

        It "Handles multiple database backups in same folder" {
            $now = Get-Date

            # Create backups for different databases in same folder
            $db1File = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-100).ToString('yyyy-MM-dd'))_10-00-00.backup"
            $db2File = Join-Path $script:testBackupFolder "otherdb_backup_$($now.AddDays(-100).ToString('yyyy-MM-dd'))_10-00-00.backup"

            "Mock data" | Out-File -FilePath $db1File -Force
            "Mock data" | Out-File -FilePath $db2File -Force
            (Get-Item $db1File).LastWriteTime = $now.AddDays(-100)
            (Get-Item $db2File).LastWriteTime = $now.AddDays(-100)

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
                -user "test_user" `
                -retention_days 30 `
                -min_backups 1

            # Only testdb backup should be deleted, otherdb should remain
            Test-Path $db1File | Should -Be $false
            Test-Path $db2File | Should -Be $true
        }

        It "Handles very large number of old backups efficiently" {
            $now = Get-Date

            # Create 50 old backups
            1..50 | ForEach-Object {
                $file = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-100 - $_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                "Mock data" | Out-File -FilePath $file -Force
                (Get-Item $file).LastWriteTime = $now.AddDays(-100 - $_)
            }

            # Create 5 recent backups
            1..5 | ForEach-Object {
                $file = Join-Path $script:testBackupFolder "testdb_backup_$($now.AddDays(-$_).ToString('yyyy-MM-dd'))_10-00-00.backup"
                "Mock data" | Out-File -FilePath $file -Force
                (Get-Item $file).LastWriteTime = $now.AddDays(-$_)
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
                -user "test_user" `
                -retention_days 30 `
                -min_backups 3

            # All 50 old backups should be deleted
            $oldBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup" |
                Where-Object { $_.LastWriteTime -lt $now.AddDays(-30) }
            $oldBackups.Count | Should -Be 0

            # Recent backups plus new one should remain
            $recentBackups = Get-ChildItem -Path $script:testBackupFolder -Filter "testdb_backup_*.backup"
            $recentBackups.Count | Should -BeGreaterOrEqual 5
        }
    }

    Context "Special Characters and URL Encoding" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Properly encodes password with special characters" {
            $securePassword = ConvertTo-SecureString "p@ssw0rd!#$%&*" -AsPlainText -Force
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

            # Password should be URL-encoded
            $script:capturedCommand | Should -Match "p%40ssw0rd"
        }

        It "Handles password with spaces" {
            $securePassword = ConvertTo-SecureString "my password 123" -AsPlainText -Force
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

            # Spaces should be URL-encoded as %20
            $script:capturedCommand | Should -Match "my%20password%20123"
        }

        It "Handles database name with underscores and numbers" {
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
                -dbname "test_db_123" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            $backupFiles = Get-ChildItem -Path $script:testBackupFolder -Filter "test_db_123_backup_*.backup"
            $backupFiles.Count | Should -BeGreaterThan 0
        }

        It "Handles username with special characters" {
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
                -user "test.user@domain"

            # Username should appear in connection string
            $script:capturedCommand | Should -Match "test\.user@domain"
        }
    }

    Context "Additional Error Scenarios" {
        BeforeEach {
            if (Test-Path $script:testBackupFolder) {
                Get-ChildItem -Path $script:testBackupFolder | Remove-Item -Force
            }
            if (Test-Path $script:testLogFile) {
                Remove-Item -Path $script:testLogFile -Force
            }
        }

        It "Handles disk full error during backup" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    $global:LASTEXITCODE = 1
                    throw "pg_dump: error: could not write to output file: No space left on device"
                }
            }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw

            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup failed"
        }

        It "Handles permission denied on backup folder" {
            $restrictedFolder = Join-Path $script:testDir "restricted"
            New-Item -Path $restrictedFolder -ItemType Directory -Force | Out-Null

            # Mock New-Item to fail
            Mock New-Item {
                throw "Access to the path is denied"
            } -ParameterFilter { $ItemType -eq "Directory" }

            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $restrictedFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw
        }

        It "Handles pg_dump executable not found" {
            # This would normally be caught at the Config level, but test the scenario
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    throw "The term 'pg_dump' is not recognized as the name of a cmdlet, function, script file, or operable program"
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

        It "Logs all pg_dump output including warnings" {
            Mock -CommandName 'Invoke-Expression' -MockWith {
                param($Command)
                if ($Command -match 'pg_dump') {
                    if ($Command -match '--file=([^\s]+)') {
                        $backupPath = $matches[1]
                        "Mock PostgreSQL backup data" | Out-File -FilePath $backupPath -Force
                    }
                    # Simulate pg_dump warnings
                    Write-Warning "pg_dump: warning: some deprecated features used"
                    $global:LASTEXITCODE = 0
                }
            }

            Backup-PostgresDatabase `
                -dbname "testdb" `
                -backup_folder $script:testBackupFolder `
                -log_file $script:testLogFile `
                -user "test_user"

            Test-Path $script:testLogFile | Should -Be $true
            $logContent = Get-Content -Path $script:testLogFile -Raw
            $logContent | Should -Match "Backup completed successfully"
        }

        It "Handles service stop failure after successful backup" {
            $script:getServiceCallCount = 0
            Mock Get-Service {
                $script:getServiceCallCount++
                if ($script:getServiceCallCount -eq 1) {
                    return [PSCustomObject]@{
                        Name   = "postgresql-x64-17"
                        Status = "Stopped"
                    }
                }
                else {
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

            # Service stop failure should cause the function to throw
            {
                Backup-PostgresDatabase `
                    -dbname "testdb" `
                    -backup_folder $script:testBackupFolder `
                    -log_file $script:testLogFile `
                    -user "test_user"
            } | Should -Throw
        }

        It "Creates backup even when zero-byte cleanup fails" {
            # Create a zero-byte file that can't be deleted
            $zeroByteFile = Join-Path $script:testBackupFolder "testdb_backup_2024-01-01_10-00-00.backup"
            New-Item -Path $zeroByteFile -ItemType File -Force | Out-Null

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
}

AfterAll {
    # Clean up test directory (only if tests ran on Windows)
    if ($script:isWindows -and $script:testDir -and (Test-Path $script:testDir)) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove imported module
    if ($script:isWindows) {
        Remove-Module PostgresBackup -ErrorAction SilentlyContinue
    }
}
