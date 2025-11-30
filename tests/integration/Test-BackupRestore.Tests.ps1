[CmdletBinding()]
param()

Describe "Backup and Restore Integration" {
    BeforeAll {
        $script:skipReason = $null

        $requiredCommands = @('initdb', 'pg_ctl', 'psql', 'pg_dump', 'pg_restore')
        $missingCommands = @()
        foreach ($command in $requiredCommands) {
            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
                $missingCommands += $command
            }
        }

        if ($missingCommands.Count -gt 0) {
            $script:skipReason = "Missing required PostgreSQL utilities: $($missingCommands -join ', ')"
            return
        }

        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "postgres_backup_integration_$([guid]::NewGuid())"
        $script:dataDirectory = Join-Path $script:testRoot "pgdata"
        $script:backupDirectory = Join-Path $script:testRoot "backups"
        $script:logFile = Join-Path $script:testRoot "backup.log"
        $script:postgresPort = 5432
        $script:restoreDatabase = "backup_restore_validation"
        $script:sourceDatabase = "backup_restore_source"
        $script:oldBackupFile = Join-Path $script:backupDirectory "${script:sourceDatabase}_backup_old.backup"

        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $script:backupDirectory -ItemType Directory -Force | Out-Null

        & initdb -D $script:dataDirectory -A trust --username=postgres --no-locale | Out-Null

        $postgresConfig = Join-Path $script:dataDirectory "postgresql.conf"
        Add-Content -Path $postgresConfig -Value "port = $($script:postgresPort)" -Encoding utf8
        Add-Content -Path $postgresConfig -Value "listen_addresses = 'localhost'" -Encoding utf8

        $script:postgresLog = Join-Path $script:testRoot "postgres.log"
        & pg_ctl -D $script:dataDirectory -l $script:postgresLog -o "-F" start | Out-Null

        $maxAttempts = 10
        $attempt = 0
        do {
            $attempt++
            Start-Sleep -Seconds 1
            try {
                & psql -h localhost -p $script:postgresPort -U postgres -d postgres -c "SELECT 1;" | Out-Null
                $script:serverReady = $true
            }
            catch {
                $script:serverReady = $false
            }
        } while (-not $script:serverReady -and $attempt -lt $maxAttempts)

        if (-not $script:serverReady) {
            $script:skipReason = "PostgreSQL server did not start successfully for integration test"
            return
        }

        & psql -h localhost -p $script:postgresPort -U postgres -d postgres -c "DROP DATABASE IF EXISTS $($script:sourceDatabase);" | Out-Null
        & psql -h localhost -p $script:postgresPort -U postgres -d postgres -c "CREATE DATABASE $($script:sourceDatabase);" | Out-Null

        $seedDataSql = @'
CREATE TABLE IF NOT EXISTS widgets (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);
INSERT INTO widgets (name, quantity, updated_at) VALUES
    ('alpha', 10, NOW() - INTERVAL '2 days'),
    ('bravo', 20, NOW() - INTERVAL '1 day'),
    ('charlie', 30, NOW());
'@
        $seedDataSql | & psql -h localhost -p $script:postgresPort -U postgres -d $script:sourceDatabase | Out-Null

        Import-Module "$PSScriptRoot/../src/powershell/modules/Database/PostgresBackup/PostgresBackup.psm1" -Force

        InModuleScope PostgresBackup {
            $script:pg_dump_path = "pg_dump"
            $script:service_name = "postgresql-integration"
            $script:service_start_wait = 1
            $script:max_wait_time = 10
        }

        Mock -ModuleName PostgresBackup -CommandName Get-Service -MockWith {
            [PSCustomObject]@{ Name = 'postgresql-integration'; Status = 'Running' }
        }

        Mock -ModuleName PostgresBackup -CommandName Start-Service -MockWith {}
        Mock -ModuleName PostgresBackup -CommandName Stop-Service -MockWith {}
        Mock -ModuleName PostgresBackup -CommandName Wait-ServiceStatus -MockWith {}

        "stale backup" | Out-File -FilePath $script:oldBackupFile -Encoding utf8
        (Get-Item $script:oldBackupFile).LastWriteTime = (Get-Date).AddDays(-14)

        Backup-PostgresDatabase `
            -dbname $script:sourceDatabase `
            -backup_folder $script:backupDirectory `
            -log_file $script:logFile `
            -user "postgres" `
            -retention_days 1 `
            -min_backups 1

        $script:latestBackup = Get-ChildItem -Path $script:backupDirectory -Filter "${script:sourceDatabase}_backup_*.backup" |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1

        & psql -h localhost -p $script:postgresPort -U postgres -d postgres -c "DROP DATABASE IF EXISTS $($script:restoreDatabase);" | Out-Null
        & psql -h localhost -p $script:postgresPort -U postgres -d postgres -c "CREATE DATABASE $($script:restoreDatabase);" | Out-Null

        & pg_restore -h localhost -p $script:postgresPort -U postgres -d $script:restoreDatabase -c $script:latestBackup.FullName | Out-Null

        $script:sourceRows = & psql -h localhost -p $script:postgresPort -U postgres -d $script:sourceDatabase -At -F '|' -c "SELECT id, name, quantity FROM widgets ORDER BY id;"
        $script:restoredRows = & psql -h localhost -p $script:postgresPort -U postgres -d $script:restoreDatabase -At -F '|' -c "SELECT id, name, quantity FROM widgets ORDER BY id;"
    }

    It "Restores database to exact state" -Skip:([bool]$script:skipReason) {
        $script:sourceRows | Should -Not -BeNullOrEmpty
        $script:restoredRows | Should -Be $script:sourceRows
    }

    It "Applies retention policy to prune expired backups" -Skip:([bool]$script:skipReason) {
        Test-Path -Path $script:oldBackupFile | Should -BeFalse
        $script:latestBackup | Should -Not -BeNullOrEmpty
    }

    AfterAll {
        if ($script:serverReady) {
            & pg_ctl -D $script:dataDirectory stop -s -m fast | Out-Null
        }

        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Get-Module -Name PostgresBackup -ErrorAction SilentlyContinue) {
            Remove-Module -Name PostgresBackup -Force -ErrorAction SilentlyContinue
        }
    }
}
