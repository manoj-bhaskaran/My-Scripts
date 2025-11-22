# ISSUE-026: Repository Cleanup and Maintenance Tasks

**Priority:** 🟢 LOW
**Category:** Repository Hygiene / Maintenance
**Estimated Effort:** 4 hours
**Skills Required:** Git, Shell, PowerShell

---

## Problem Statement

Several minor cleanup tasks need attention:
- Shell script missing execute permission
- Egg-info directory in version control
- Potential logging performance optimization

---

## Acceptance Criteria
- [ ] Fix shell script permissions
- [ ] Remove egg-info from git
- [ ] Update .gitignore
- [ ] Optimize logging path resolution
- [ ] Clean up temporary files

---

## Tasks

### Task 1: Fix Shell Script Permissions (5 min)
```bash
chmod +x src/sh/create_github_issues.sh
git add src/sh/create_github_issues.sh
git commit -m "fix: add execute permission to shell script"
```

### Task 2: Remove Egg-info (10 min)
```bash
git rm -r src/python/modules/logging/python_logging_framework.egg-info/
echo "*.egg-info/" >> .gitignore
git add .gitignore
git commit -m "chore: remove egg-info from version control"
```

### Task 3: Optimize Logging Performance (2h)
```powershell
# PowerShellLoggingFramework.psm1
# Calculate default log dir once at module load
$script:DefaultLogDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs"

function Initialize-Logger {
    param([string]$resolvedLogDir = $script:DefaultLogDir)
    # Function body
}
```

### Task 4: General Cleanup (1.5h)
- Remove temporary test files
- Clean up old logs
- Remove unused scripts
- Update .gitignore as needed

---

## Testing
- Verify shell script is executable
- Confirm egg-info not tracked
- Test logging performance improvement
- Verify repository cleanliness

---

**Time:** Permissions: 0.1h, Egg-info: 0.2h, Logging: 2h, Cleanup: 1.5h, Testing: 0.2h = **4 hours**
