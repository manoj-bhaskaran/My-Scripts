# ISSUE-019: Replace Write-Host in Backup-Related Scripts

**Priority:** 🟡 MEDIUM
**Category:** Code Quality / Best Practices
**Estimated Effort:** 5 hours
**Skills Required:** PowerShell, Best Practices

---

## Problem Statement

Backup scripts use Write-Host extensively, preventing automation and output capture.

---

## Acceptance Criteria
- [ ] Replace Write-Host in all backup scripts
- [ ] Use logging framework for important messages
- [ ] Use Write-Output for pipeline data
- [ ] Scripts return structured objects
- [ ] Can capture output in automation

---

## Target Scripts
- Backup-GnuCashDatabase.ps1
- PostgreSQL backup scripts
- File backup utilities

---

**Time:** Script updates: 3.5h, Testing: 1h, Documentation: 0.5h = **5 hours**
