# Issue #003b: Test Database Backup Scripts

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Phase 1 - Critical Paths
**Effort**: 8 hours

## Description
Add comprehensive tests for PostgreSQL backup scripts. These handle financial data (GnuCash) and must be thoroughly tested to prevent data loss.

## Scope
- `src/powershell/modules/Database/PostgresBackup/`
- Backup creation logic
- Retention policy enforcement
- Restore functionality

## Implementation

### Test Cases
```powershell
# tests/powershell/unit/PostgresBackup.Tests.ps1 (expand existing)

Describe "Backup Creation" {
    Context "When database is accessible" {
        It "Creates backup file successfully" {
            Mock Invoke-Command { return 0 }
            Mock Test-Path { return $true }

            $result = Invoke-DatabaseBackup -Database "gnucash"

            $result.Success | Should -Be $true
            $result.BackupPath | Should -Not -BeNullOrEmpty
        }

        It "Includes timestamp in filename" {
            $result = Invoke-DatabaseBackup -Database "test"
            $result.BackupPath | Should -Match '\d{4}-\d{2}-\d{2}'
        }
    }

    Context "When database is unavailable" {
        It "Returns error status" {
            Mock Invoke-Command { throw "Connection failed" }

            $result = Invoke-DatabaseBackup -Database "gnucash"

            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Retention Policy" {
    It "Keeps configured number of backups" {
        # Create mock old backups
        $oldBackups = 1..10 | ForEach-Object {
            [PSCustomObject]@{
                Name = "backup-$(Get-Date).AddDays(-$_).ToString('yyyy-MM-dd')).sql"
                CreationTime = (Get-Date).AddDays(-$_)
            }
        }

        Mock Get-ChildItem { return $oldBackups }

        Invoke-RetentionPolicy -Path "TestDrive:\backups" -Keep 7

        # Verify only 7 newest remain
        Should -Invoke Remove-Item -Times 3
    }
}
```

## Acceptance Criteria
- [ ] Backup creation tested with valid/invalid databases
- [ ] Retention policy tested with various scenarios
- [ ] Error handling tested
- [ ] Restore functionality tested
- [ ] Coverage for PostgresBackup module > 30%

## Benefits
- Validates financial data backup reliability
- Prevents data loss
- Documents expected behavior
- Enables confident refactoring

## Related
- Issue #003c (data processing tests)
- GnuCash backup automation
