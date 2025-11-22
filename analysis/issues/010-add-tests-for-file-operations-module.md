# ISSUE-010: Add Tests for FileOperations Module

**Priority:** 🟠 HIGH
**Category:** Testing / Quality Assurance
**Estimated Effort:** 4 hours
**Skills Required:** PowerShell, Pester, Testing

---

## Problem Statement

The FileOperations module handles critical file manipulation but lacks comprehensive test coverage.

### Functions Without Tests
- `Copy-FileWithRetry` - Retry logic untested
- `Remove-FileWithBackup` - Backup creation untested
- `Test-FileInUse` - Lock detection untested
- `Move-FileAtomic` - Atomicity not verified

### Impact
- 🗑️ Risk of data loss during file operations
- 💥 Untested retry logic may fail
- 🐛 Edge cases not covered

---

## Acceptance Criteria
- [ ] Test retry logic with configurable attempts
- [ ] Test backup creation before deletion
- [ ] Test file lock detection
- [ ] Test atomic move operations
- [ ] Test error handling for all functions
- [ ] Achieve >80% code coverage
- [ ] All tests pass in CI

---

## Implementation Plan

### Step 1: Test Copy-FileWithRetry (1 hour)
```powershell
Describe "Copy-FileWithRetry" {
    It "Retries on failure" {
        $attempts = 0
        Mock Copy-Item { $script:attempts++; if ($attempts -lt 3) { throw "Locked" } }
        
        Copy-FileWithRetry -Source "test.txt" -Destination "dest.txt" -MaxRetries 5
        
        $attempts | Should -Be 3
    }
    
    It "Throws after max retries" {
        Mock Copy-Item { throw "Locked" }
        
        { Copy-FileWithRetry -Source "test.txt" -Destination "dest.txt" -MaxRetries 2 } |
            Should -Throw
    }
}
```

### Step 2: Test Remove-FileWithBackup (1 hour)
```powershell
Describe "Remove-FileWithBackup" {
    It "Creates backup before deletion" {
        Mock Test-Path { $true }
        Mock Copy-Item { }
        Mock Remove-Item { }
        
        Remove-FileWithBackup -Path "test.txt" -BackupDir "backup"
        
        Assert-MockCalled Copy-Item -ParameterFilter { $Destination -match "backup" }
        Assert-MockCalled Remove-Item
    }
}
```

### Step 3: Test File Lock Detection (1 hour)
### Step 4: Integration & Documentation (1 hour)

---

## Related Issues
- ISSUE-002: Add Tests for PostgresBackup Module
- ISSUE-011: Add Tests for ErrorHandling Module

---

## Success Metrics
- [ ] >80% code coverage
- [ ] All edge cases tested
- [ ] Retry logic verified
- [ ] Backup safety verified

---

**Time Breakdown:** Test development: 3h, Documentation: 1h = **4 hours**
