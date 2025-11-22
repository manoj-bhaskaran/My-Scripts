# ISSUE-002: Add Comprehensive Tests for PostgresBackup Module

**Priority:** 🔴 CRITICAL
**Category:** Testing / Quality Assurance
**Estimated Effort:** 8 hours
**Skills Required:** PowerShell, Pester, PostgreSQL, Testing

---

## Problem Statement

The PostgresBackup module (`PostgresBackup.psm1`) is a critical component that handles database backups but has **zero test coverage**. This creates significant risk for data loss or backup failures going undetected.

### Current State

- **Module:** `src/powershell/modules/Database/PostgresBackup/PostgresBackup.psm1`
- **Test File:** Does not exist
- **Coverage:** 0%
- **Risk Level:** CRITICAL (handles data backups)

### Functions Without Tests

```powershell
# Main backup functions
Invoke-PostgresBackup          # Creates database backups
Test-BackupIntegrity           # Verifies backup files
Remove-OldBackups              # Manages retention policy
Get-BackupHistory              # Retrieves backup metadata
```

### Impact

- 💾 **Data Loss Risk:** No verification that backups work correctly
- 🐛 **Silent Failures:** Backup failures may go unnoticed
- 🔄 **Restoration Risk:** No guarantee backups can be restored
- 📊 **Retention Issues:** Log purging could delete critical backups
- 🚫 **Regression Risk:** Changes could break backups without detection

---

## Acceptance Criteria

- [ ] Create `tests/powershell/unit/PostgresBackup.Tests.ps1`
- [ ] Test backup file creation with correct naming convention
- [ ] Test backup retention policy (keeps N backups, deletes oldest)
- [ ] Test backup integrity validation
- [ ] Test connection error handling
- [ ] Test disk space validation before backup
- [ ] Test backup metadata generation
- [ ] Test restore verification (at least dry-run)
- [ ] Achieve >80% code coverage for PostgresBackup module
- [ ] All tests pass in CI pipeline
- [ ] Mock PostgreSQL connections (no actual database required for tests)

---

## Implementation Plan

### Step 1: Setup Test Infrastructure (1 hour)

Create test file with proper mocking structure:

```powershell
# tests/powershell/unit/PostgresBackup.Tests.ps1
BeforeAll {
    # Import module
    $modulePath = "$PSScriptRoot/../../../src/powershell/modules/Database/PostgresBackup"
    Import-Module "$modulePath/PostgresBackup.psm1" -Force

    # Mock functions that interact with PostgreSQL
    Mock Invoke-Expression { return $true }
    Mock Test-Path { return $true }
    Mock New-Item { return @{ FullName = "TestDrive:\backup.sql" } }
}

Describe "PostgresBackup Module" {
    # Tests go here
}

AfterAll {
    Remove-Module PostgresBackup -ErrorAction SilentlyContinue
}
```

### Step 2: Test Backup Creation (2 hours)

```powershell
Describe "Invoke-PostgresBackup" {
    Context "Successful Backup Creation" {
        It "Creates backup file with correct naming convention" {
            Mock Get-Date { return [DateTime]::Parse("2025-11-22 14:30:00") }

            $result = Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            # Verify backup file name follows pattern: testdb_20251122_143000.sql
            $result.BackupFile | Should -Match "testdb_\d{8}_\d{6}\.sql$"
        }

        It "Includes timestamp in backup filename" {
            Mock Get-Date { return [DateTime]::Parse("2025-11-22 14:30:00") }

            $result = Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            $result.BackupFile | Should -Match "20251122_143000"
        }

        It "Creates backup directory if it doesn't exist" {
            Mock Test-Path { return $false }
            Mock New-Item { return @{ FullName = "TestDrive:\backups" } } -ParameterFilter { $ItemType -eq "Directory" }

            Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\backups"

            Assert-MockCalled New-Item -Times 1 -ParameterFilter { $ItemType -eq "Directory" }
        }

        It "Validates database connection before backup" {
            Mock Test-PostgresConnection { return $true }

            { Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\" } | Should -Not -Throw

            Assert-MockCalled Test-PostgresConnection -Times 1
        }

        It "Includes all required pg_dump parameters" {
            Mock Invoke-Expression { param($Command) return $Command } -Verifiable

            Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            Assert-MockCalled Invoke-Expression -ParameterFilter {
                $Command -match "pg_dump" -and
                $Command -match "--dbname=testdb" -and
                $Command -match "--file="
            }
        }
    }

    Context "Error Handling" {
        It "Throws error when database connection fails" {
            Mock Test-PostgresConnection { return $false }

            { Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\" } |
                Should -Throw "*database connection*"
        }

        It "Throws error when backup path is invalid" {
            Mock Test-Path { return $false } -ParameterFilter { $PathType -eq "Container" }
            Mock New-Item { throw "Access denied" }

            { Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "Z:\invalid\path" } |
                Should -Throw
        }

        It "Throws error when insufficient disk space" {
            Mock Get-Volume { return @{ SizeRemaining = 100MB } }
            Mock Get-DatabaseSize { return 500MB }

            { Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "C:\" } |
                Should -Throw "*insufficient disk space*"
        }

        It "Logs error details when pg_dump fails" {
            Mock Invoke-Expression { throw "pg_dump: error: connection failed" }
            Mock Write-LogError { }

            { Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\" } |
                Should -Throw

            Assert-MockCalled Write-LogError -ParameterFilter {
                $Message -match "pg_dump.*failed"
            }
        }
    }

    Context "Backup Integrity" {
        It "Validates backup file exists after creation" {
            Mock Test-Path { return $true } -ParameterFilter { $_.EndsWith(".sql") }

            $result = Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            $result.Success | Should -Be $true
            Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $_.EndsWith(".sql") }
        }

        It "Validates backup file is not empty" {
            Mock Get-Item { return @{ Length = 1024KB } }

            $result = Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            $result.BackupSize | Should -BeGreaterThan 0
        }

        It "Calculates and stores backup checksum" {
            Mock Get-FileHash { return @{ Hash = "ABC123DEF456" } }

            $result = Invoke-PostgresBackup -DatabaseName "testdb" -BackupPath "TestDrive:\"

            $result.Checksum | Should -Be "ABC123DEF456"
        }
    }
}
```

### Step 3: Test Retention Policy (2 hours)

```powershell
Describe "Remove-OldBackups" {
    Context "Retention Policy Enforcement" {
        It "Keeps specified number of most recent backups" {
            # Setup: Create mock backup files
            $backups = @(
                @{ Name = "testdb_20251120_100000.sql"; CreationTime = "2025-11-20 10:00:00" }
                @{ Name = "testdb_20251121_100000.sql"; CreationTime = "2025-11-21 10:00:00" }
                @{ Name = "testdb_20251122_100000.sql"; CreationTime = "2025-11-22 10:00:00" }
                @{ Name = "testdb_20251123_100000.sql"; CreationTime = "2025-11-23 10:00:00" }
            )
            Mock Get-ChildItem { return $backups }
            Mock Remove-Item { }

            Remove-OldBackups -BackupPath "TestDrive:\" -RetainCount 2

            # Should delete the 2 oldest backups
            Assert-MockCalled Remove-Item -Times 2
        }

        It "Deletes oldest backups first" {
            $backups = @(
                @{ Name = "testdb_20251120_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-20 10:00:00") }
                @{ Name = "testdb_20251121_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-21 10:00:00") }
                @{ Name = "testdb_20251122_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-22 10:00:00") }
            )
            Mock Get-ChildItem { return $backups }
            Mock Remove-Item { }

            Remove-OldBackups -BackupPath "TestDrive:\" -RetainCount 1

            # Verify oldest file deleted
            Assert-MockCalled Remove-Item -ParameterFilter {
                $Path -match "20251120"
            } -Times 1
        }

        It "Does not delete if backup count is below retention threshold" {
            $backups = @(
                @{ Name = "testdb_20251122_100000.sql"; CreationTime = "2025-11-22 10:00:00" }
            )
            Mock Get-ChildItem { return $backups }
            Mock Remove-Item { }

            Remove-OldBackups -BackupPath "TestDrive:\" -RetainCount 5

            Assert-MockCalled Remove-Item -Times 0
        }

        It "Handles mixed database backups correctly" {
            $backups = @(
                @{ Name = "db1_20251120_100000.sql"; CreationTime = "2025-11-20 10:00:00" }
                @{ Name = "db2_20251121_100000.sql"; CreationTime = "2025-11-21 10:00:00" }
                @{ Name = "db1_20251122_100000.sql"; CreationTime = "2025-11-22 10:00:00" }
            )
            Mock Get-ChildItem { return $backups } -ParameterFilter { $Filter -match "db1" }
            Mock Remove-Item { }

            Remove-OldBackups -BackupPath "TestDrive:\" -DatabaseName "db1" -RetainCount 1

            # Should only delete db1 backups, not db2
            Assert-MockCalled Remove-Item -Times 1 -ParameterFilter {
                $Path -match "db1_20251120"
            }
        }
    }

    Context "Error Handling" {
        It "Logs warning when backup file is locked" {
            Mock Get-ChildItem { return @(@{ Name = "testdb_20251120_100000.sql"; CreationTime = "2025-11-20" }) }
            Mock Remove-Item { throw "File is locked" }
            Mock Write-LogWarning { }

            Remove-OldBackups -BackupPath "TestDrive:\" -RetainCount 0

            Assert-MockCalled Write-LogWarning -ParameterFilter {
                $Message -match "locked"
            }
        }
    }
}
```

### Step 4: Test Backup Verification (1.5 hours)

```powershell
Describe "Test-BackupIntegrity" {
    Context "Backup Validation" {
        It "Validates backup file structure" {
            $mockContent = @(
                "-- PostgreSQL database dump",
                "CREATE TABLE test (id INT);",
                "-- PostgreSQL database dump complete"
            )
            Mock Get-Content { return $mockContent }

            $result = Test-BackupIntegrity -BackupFile "TestDrive:\backup.sql"

            $result.IsValid | Should -Be $true
        }

        It "Detects corrupted backup files" {
            Mock Get-Content { return @("Invalid content") }

            $result = Test-BackupIntegrity -BackupFile "TestDrive:\backup.sql"

            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "*missing header*"
        }

        It "Verifies checksum matches" {
            Mock Get-FileHash { return @{ Hash = "ABC123" } }
            Mock Get-Content { return @{ Checksum = "ABC123" } } -ParameterFilter { $Path -match "\.meta$" }

            $result = Test-BackupIntegrity -BackupFile "TestDrive:\backup.sql" -VerifyChecksum

            $result.ChecksumValid | Should -Be $true
        }

        It "Can perform dry-run restore test" {
            Mock Invoke-Expression { return @{ ExitCode = 0 } }

            $result = Test-BackupIntegrity -BackupFile "TestDrive:\backup.sql" -TestRestore

            Assert-MockCalled Invoke-Expression -ParameterFilter {
                $Command -match "pg_restore.*--list"
            }
            $result.RestoreTestPassed | Should -Be $true
        }
    }
}
```

### Step 5: Test Helper Functions (1 hour)

```powershell
Describe "Get-BackupHistory" {
    It "Returns list of all backups sorted by date" {
        $backups = @(
            @{ Name = "testdb_20251120_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-20") }
            @{ Name = "testdb_20251122_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-22") }
            @{ Name = "testdb_20251121_100000.sql"; CreationTime = [DateTime]::Parse("2025-11-21") }
        )
        Mock Get-ChildItem { return $backups }

        $result = Get-BackupHistory -BackupPath "TestDrive:\"

        $result[0].Name | Should -Match "20251122"  # Most recent first
        $result.Count | Should -Be 3
    }

    It "Filters by database name" {
        $backups = @(
            @{ Name = "db1_20251122_100000.sql"; CreationTime = "2025-11-22" }
            @{ Name = "db2_20251122_100000.sql"; CreationTime = "2025-11-22" }
        )
        Mock Get-ChildItem { return $backups } -ParameterFilter { $Filter -match "db1" }

        $result = Get-BackupHistory -BackupPath "TestDrive:\" -DatabaseName "db1"

        $result.Count | Should -Be 1
        $result[0].Name | Should -Match "db1"
    }
}

Describe "Test-PostgresConnection" {
    It "Returns true when connection succeeds" {
        Mock Invoke-Expression { return "PostgreSQL 14.0" }

        $result = Test-PostgresConnection -DatabaseName "testdb"

        $result | Should -Be $true
    }

    It "Returns false when connection fails" {
        Mock Invoke-Expression { throw "connection failed" }

        $result = Test-PostgresConnection -DatabaseName "testdb"

        $result | Should -Be $false
    }
}
```

### Step 6: Integration with CI Pipeline (30 minutes)

Update `.github/workflows/validate-modules.yml`:

```yaml
- name: Run PostgresBackup Module Tests
  shell: pwsh
  run: |
    # Install Pester
    Install-Module -Name Pester -Force -SkipPublisherCheck

    # Run tests
    $config = New-PesterConfiguration
    $config.Run.Path = 'tests/powershell/unit/PostgresBackup.Tests.ps1'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = 'src/powershell/modules/Database/PostgresBackup/*.psm1'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = 'test-results/PostgresBackup.xml'

    $result = Invoke-Pester -Configuration $config

    if ($result.FailedCount -gt 0) {
        throw "PostgresBackup tests failed"
    }

    # Check coverage threshold
    if ($result.CodeCoverage.CoveragePercent -lt 80) {
        Write-Warning "Coverage is $($result.CodeCoverage.CoveragePercent)%, below 80% threshold"
    }
```

---

## Testing Strategy

### Unit Tests (Primary Focus)
- **Backup Creation:** Mock pg_dump, test file creation logic
- **Retention:** Test backup deletion with mock files
- **Validation:** Test backup integrity checks
- **Error Handling:** Test all failure scenarios
- **Connection Testing:** Mock database connections

### Integration Tests (Future)
- Create test PostgreSQL database
- Perform actual backup/restore cycle
- Validate backup can restore successfully
- Test with different PostgreSQL versions

### Manual Testing Checklist
1. Run tests on Windows and Linux
2. Verify coverage report shows >80%
3. Test with actual PostgreSQL instance (manual)
4. Verify backup files created correctly
5. Verify retention policy works

---

## Related Issues

- ISSUE-003: Add Tests for Git Hooks
- ISSUE-004: Add Tests for PurgeLogs Module
- ISSUE-021: Add Backup/Restore Integration Tests

---

## References

- Pester Documentation: https://pester.dev/docs/quick-start
- PowerShell Testing Best Practices: https://pester.dev/docs/usage/mocking
- PostgreSQL pg_dump Documentation: https://www.postgresql.org/docs/current/app-pgdump.html
- Code Coverage with Pester: https://pester.dev/docs/usage/code-coverage

---

## Success Metrics

- [ ] All PostgresBackup tests passing in CI
- [ ] >80% code coverage for PostgresBackup module
- [ ] Zero failures in test runs across Windows/Linux
- [ ] All backup creation scenarios tested
- [ ] All retention policy scenarios tested
- [ ] All error handling paths tested
- [ ] Mock strategy documented for other modules to follow

---

**Estimated Time Breakdown:**
- Test infrastructure setup: 1 hour
- Backup creation tests: 2 hours
- Retention policy tests: 2 hours
- Backup verification tests: 1.5 hours
- Helper function tests: 1 hour
- CI integration: 0.5 hours
- **Total: 8 hours**
