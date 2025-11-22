# ISSUE-018: Replace Write-Host in Shared PowerShell Modules

**Priority:** 🟡 MEDIUM
**Category:** Code Quality / Best Practices
**Estimated Effort:** 5 hours
**Skills Required:** PowerShell, Best Practices

---

## Problem Statement

186 instances of `Write-Host` across scripts. This anti-pattern breaks pipelines and makes testing difficult.

---

## Acceptance Criteria
- [ ] Replace Write-Host in all shared modules
- [ ] Use Write-Verbose, Write-Output, or logging functions
- [ ] Keep colored Write-Host only for user-facing scripts
- [ ] Add [CmdletBinding()] where missing
- [ ] Tests verify output is pipe-able

---

## Implementation

```powershell
# Before
function Process-Files {
    Write-Host "Processing: $file"
}

# After
function Process-Files {
    [CmdletBinding()]
    param([string[]]$Files)
    
    foreach ($file in $Files) {
        Write-Verbose "Processing: $file"
        # Process and output object
        [PSCustomObject]@{
            File = $file
            Status = "Completed"
        }
    }
}
```

**Priority modules:**
1. ErrorHandling
2. FileOperations
3. PostgresBackup
4. PurgeLogs

---

**Time:** Module updates: 3h, Testing: 1h, Documentation: 1h = **5 hours**
