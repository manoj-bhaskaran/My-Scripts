# ISSUE-021: Add Backup/Restore Integration Tests

**Priority:** 🟡 MEDIUM
**Category:** Testing / Quality Assurance
**Estimated Effort:** 6 hours
**Skills Required:** PowerShell, PostgreSQL, Testing

---

## Problem Statement

No integration tests verify complete backup/restore cycle works end-to-end.

---

## Acceptance Criteria
- [ ] Create test PostgreSQL database
- [ ] Test backup creation
- [ ] Test backup restoration
- [ ] Verify data integrity after restore
- [ ] Test backup retention policy
- [ ] Clean up test resources

---

## Implementation

```powershell
# tests/integration/Test-BackupRestore.Tests.ps1
Describe "Backup and Restore Integration" {
    BeforeAll {
        # Create test database with sample data
        # Run backup
        # Restore to new database
        # Compare data
    }

    It "Restores database to exact state" {
        # Verify all data matches
    }
}
```

---

**Time:** Setup: 2h, Tests: 3h, Documentation: 1h = **6 hours**
