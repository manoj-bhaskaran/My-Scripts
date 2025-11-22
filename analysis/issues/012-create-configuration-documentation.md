# ISSUE-012: Create Comprehensive Configuration Documentation

**Priority:** 🟠 HIGH
**Category:** Documentation / Usability
**Estimated Effort:** 5 hours
**Skills Required:** Technical Writing, Configuration Management

---

## Problem Statement

Local deployment configuration requires undocumented manual setup. Users don't know how to configure the system.

### Current Gaps
- ❌ No central configuration documentation
- ❌ `local-deployment-config.json` undocumented
- ❌ No validation examples
- ❌ No troubleshooting guide

### Impact
- 💥 Git hooks fail on fresh clones
- 😤 Frustrating setup experience
- ❓ Support burden from configuration questions

---

## Acceptance Criteria
- [ ] Create `config/CONFIG_GUIDE.md`
- [ ] Document all configuration files
- [ ] Provide examples for common scenarios
- [ ] Add troubleshooting section
- [ ] Create validation script
- [ ] Link from INSTALLATION.md

---

## Implementation Plan

### Step 1: Create CONFIG_GUIDE.md (2 hours)
```markdown
# Configuration Guide

## Quick Start

1. **Local Deployment Config**
   ```bash
   cp config/local-deployment-config.json.example config/local-deployment-config.json
   ```
   
2. **Edit configuration:**
   ```json
   {
     "enabled": true,
     "stagingMirror": "C:\\Users\\YourName\\Documents\\Scripts"
   }
   ```

3. **Validate:**
   ```powershell
   .\scripts\Verify-Configuration.ps1
   ```

## Configuration Files

### local-deployment-config.json
Controls git hook deployment behavior.

**Fields:**
- `enabled` (boolean): Enable/disable deployment
- `stagingMirror` (string): Target deployment directory
- `moduleFilter` (array, optional): Specific modules to deploy

**Examples:**

Minimal config:
```json
{
  "enabled": true,
  "stagingMirror": "C:\\Scripts"
}
```

Advanced config:
```json
{
  "enabled": true,
  "stagingMirror": "C:\\Scripts",
  "moduleFilter": ["ErrorHandling", "PostgresBackup"],
  "excludePatterns": ["*.test.ps1", "*.Tests.ps1"]
}
```

### secrets/ Directory
Stores sensitive configuration (passwords, API keys).

See [Secure Configuration](CONFIG_GUIDE.md#security)

## Platform-Specific Setup

### Windows
```powershell
# Set paths
$env:MY_SCRIPTS_ROOT = "C:\Users\$env:USERNAME\Documents\Scripts"

# Configure deployment
notepad config\local-deployment-config.json
```

### Linux
```bash
# Set paths
export MY_SCRIPTS_ROOT="$HOME/scripts"

# Configure deployment
nano config/local-deployment-config.json
```

## Troubleshooting

**Problem:** "Configuration not found"
- **Solution:** Copy `.example` file and configure

**Problem:** "Staging mirror path not found"
- **Solution:** Create directory or fix path in config

**Problem:** "Permission denied"
- **Solution:** Check file permissions, run as admin if needed
```

### Step 2: Create Validation Script (1.5 hours)
```powershell
# scripts/Verify-Configuration.ps1
# Validates all configuration files
```

### Step 3: Document Additional Config Files (1 hour)
- Task Scheduler configuration
- Environment variables
- Log retention policies

### Step 4: Create Interactive Setup (30 minutes)
```powershell
# scripts/Initialize-Configuration.ps1
# Interactive configuration wizard
```

---

## Related Issues
- ISSUE-005: Create Environment Variable System
- ISSUE-007: Create Task Scheduler Templates

---

## Success Metrics
- [ ] CONFIG_GUIDE.md created
- [ ] All config files documented
- [ ] Validation script works
- [ ] Fresh system setup succeeds
- [ ] Troubleshooting section complete

---

**Time Breakdown:** Guide creation: 2h, Validation: 1.5h, Additional docs: 1h, Setup wizard: 0.5h = **5 hours**
