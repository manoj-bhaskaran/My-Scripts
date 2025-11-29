# ISSUE-009: Fix Hardcoded Paths in Documentation

**Priority:** 🟠 HIGH
**Category:** Documentation / Usability
**Estimated Effort:** 4 hours
**Skills Required:** Technical Writing, Documentation

---

## Problem Statement

Documentation files contain hardcoded paths in examples that don't work for other users. This creates confusion and reduces documentation quality.

### Affected Files

- `CHANGELOG.md` (Lines 22, 28, 32)
- `docs/guides/system-health-check.md` (Line 90)
- Multiple README files
- Various documentation examples

### Current Examples

```markdown
# CHANGELOG.md
.\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts"

# docs/guides/system-health-check.md
cd "C:\Users\manoj\Documents\Scripts"
```

### Impact

- 📚 **Examples Don't Work:** Users can't copy-paste examples
- 😕 **Confusion:** Unclear what paths should be
- 📉 **Reduced Quality:** Looks unprofessional
- 🔧 **Maintenance:** Hard to keep documentation in sync

---

## Acceptance Criteria

- [ ] All hardcoded paths replaced with placeholders
- [ ] Consistent placeholder style across all docs
- [ ] Note added explaining placeholders
- [ ] Examples use realistic but generic paths
- [ ] Environment variables shown where applicable
- [ ] Platform-specific examples (Windows/Linux)
- [ ] All documentation reviewed and updated
- [ ] Placeholder guide added to CONTRIBUTING.md

---

## Implementation Plan

### Step 1: Define Placeholder Standards (30 minutes)

Create `docs/conventions/placeholders.md`:

```markdown
# Documentation Placeholders

Use these standard placeholders in all documentation:

## Path Placeholders

| Placeholder | Description | Windows Example | Linux Example |
|------------|-------------|-----------------|---------------|
| `<REPO_PATH>` | Git repository location | `C:\Projects\My-Scripts` | `~/dev/My-Scripts` |
| `<SCRIPT_ROOT>` | Working/deployment directory | `C:\Users\Name\Documents\Scripts` | `~/scripts` |
| `<CONFIG_DIR>` | Configuration directory | `C:\Users\Name\AppData\Local\MyScripts` | `~/.config/myscripts` |
| `<LOG_DIR>` | Log file directory | `C:\Logs\MyScripts` | `/var/log/myscripts` |
| `<BACKUP_DIR>` | Backup storage directory | `D:\Backups` | `~/backups` |
| `<USERNAME>` | Current user | `YourName` | `yourname` |

## Usage Examples

### PowerShell Example
```powershell
# Instead of:
cd "C:\Users\manoj\Documents\Scripts"

# Write:
cd "<SCRIPT_ROOT>"

# Or with environment variable:
cd "$env:MY_SCRIPTS_ROOT"
```

### Bash Example
```bash
# Instead of:
cd /home/manoj/scripts

# Write:
cd "<SCRIPT_ROOT>"

# Or with environment variable:
cd "$MY_SCRIPTS_ROOT"
```

## Introducing Placeholders

Add this note at the beginning of documentation with examples:

> **Note:** Examples in this guide use placeholder paths like `<REPO_PATH>`.
> Replace these with your actual paths:
> - `<REPO_PATH>` → Your repository location (e.g., `C:\Projects\My-Scripts`)
> - `<SCRIPT_ROOT>` → Your working directory (e.g., `C:\Users\YourName\Documents\Scripts`)
```

### Step 2: Fix CHANGELOG.md (30 minutes)

```markdown
# CHANGELOG.md

<!-- Add note at top -->
> **Note:** Examples use placeholders. Replace:
> - `<REPO_PATH>` with your repository path
> - `<SCRIPT_ROOT>` with your working directory

## [2.0.0] - 2024-12-15

### Added
- Automated module deployment via git hooks
  ```powershell
  # Example: Sync repository to working directory
  .\Sync-Directory.ps1 -Source "<REPO_PATH>" -Destination "<SCRIPT_ROOT>"
  ```

- Local deployment configuration
  ```json
  {
    "enabled": true,
    "stagingMirror": "<SCRIPT_ROOT>"
  }
  ```

### Changed
- Updated logging framework to support multiple log levels
  ```powershell
  # Logs saved to: <SCRIPT_ROOT>\logs\ScriptName_YYYYMMDD.log
  ```
```

### Step 3: Fix docs/guides/ Files (1.5 hours)

```markdown
# docs/guides/system-health-check.md

<!-- Add note at top -->
> **Note:** Replace `<SCRIPT_ROOT>` with your actual script directory.
> Example: `C:\Users\YourName\Documents\Scripts` (Windows) or `~/scripts` (Linux)

## Installation

1. **Navigate to script directory:**

   **Windows:**
   ```powershell
   cd "<SCRIPT_ROOT>"
   ```

   **Linux:**
   ```bash
   cd "<SCRIPT_ROOT>"
   ```

2. **Run health check:**
   ```powershell
   # Windows
   .\src\powershell\Invoke-SystemHealthCheck.ps1

   # Or using environment variable
   cd "$env:MY_SCRIPTS_ROOT"
   .\src\powershell\Invoke-SystemHealthCheck.ps1
   ```

   ```bash
   # Linux
   ./src/sh/system-health-check.sh

   # Or using environment variable
   cd "$MY_SCRIPTS_ROOT"
   ./src/sh/system-health-check.sh
   ```

## Configuration

Edit configuration file:
```powershell
# Windows
notepad "<SCRIPT_ROOT>\config\health-check-config.json"

# Linux
nano "<SCRIPT_ROOT>/config/health-check-config.json"
```
```

### Step 4: Fix README Files (1 hour)

```markdown
# README.md

<!-- Add setup section -->
## Quick Start

### 1. Clone Repository

```bash
# Clone to your preferred location
git clone https://github.com/yourusername/My-Scripts.git <REPO_PATH>
cd <REPO_PATH>
```

### 2. Set Environment Variables

**Windows (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", "<SCRIPT_ROOT>", "User")
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_REPO", "<REPO_PATH>", "User")
```

**Linux (Bash):**
```bash
echo 'export MY_SCRIPTS_ROOT="<SCRIPT_ROOT>"' >> ~/.bashrc
echo 'export MY_SCRIPTS_REPO="<REPO_PATH>"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Run Scripts

```powershell
# Navigate to your deployment directory
cd "$env:MY_SCRIPTS_ROOT"  # Windows
cd "$MY_SCRIPTS_ROOT"       # Linux

# Run any script
.\src\powershell\backup\Backup-GnuCashDatabase.ps1  # Windows
./src/sh/backup.sh                                   # Linux
```

## Directory Structure

```
<REPO_PATH>/                 # Repository (development)
├── src/
├── config/
└── docs/

<SCRIPT_ROOT>/              # Working directory (deployment)
├── src/
├── config/
└── logs/
```
```

### Step 5: Create Automated Checker (30 minutes)

```powershell
# scripts/Check-DocumentationPaths.ps1

<#
.SYNOPSIS
    Checks documentation for hardcoded paths
#>

$docFiles = Get-ChildItem -Path @(".", "docs") -Include *.md -Recurse

$patterns = @{
    'C:\\Users\\[^<]' = 'Windows user path'
    'D:\\' = 'D: drive path'
    '/home/[^<]' = 'Linux home path'
    'manoj' = 'Specific username'
}

$found = $false

foreach ($file in $docFiles) {
    $content = Get-Content $file.FullName -Raw
    $lineNum = 0

    foreach ($line in (Get-Content $file.FullName)) {
        $lineNum++

        foreach ($pattern in $patterns.Keys) {
            if ($line -match $pattern) {
                Write-Warning "$($file.Name):$lineNum - Found $($patterns[$pattern]): $line"
                $found = $true
            }
        }
    }
}

if (-not $found) {
    Write-Host "✓ No hardcoded paths found in documentation" -ForegroundColor Green
}
else {
    Write-Host "✗ Hardcoded paths found - please fix" -ForegroundColor Red
    exit 1
}
```

### Step 6: Add to CI Pipeline (30 minutes)

```yaml
# .github/workflows/documentation-check.yml (new file or add to existing)
- name: Check Documentation Paths
  run: |
    pwsh scripts/Check-DocumentationPaths.ps1
```

### Step 7: Update CONTRIBUTING.md (30 minutes)

```markdown
# CONTRIBUTING.md

## Documentation Guidelines

### Path Placeholders

Always use placeholders instead of actual paths in examples:

✅ **Good:**
```powershell
cd "<SCRIPT_ROOT>"
```

❌ **Bad:**
```powershell
cd "C:\Users\manoj\Documents\Scripts"
```

### Standard Placeholders

| Placeholder | Use For |
|------------|---------|
| `<REPO_PATH>` | Git repository location |
| `<SCRIPT_ROOT>` | Working/deployment directory |
| `<CONFIG_DIR>` | Configuration files |
| `<USERNAME>` | User-specific paths |

See [Placeholder Guide](docs/conventions/placeholders.md) for complete list.

### Platform-Specific Examples

Provide both Windows and Linux examples when applicable:

```markdown
**Windows:**
```powershell
cd "<SCRIPT_ROOT>"
```

**Linux:**
```bash
cd "<SCRIPT_ROOT>"
```
```
```

---

## Testing Strategy

### Automated Checks
- Run Check-DocumentationPaths.ps1 script
- CI pipeline validates on every PR
- Fail build if hardcoded paths found

### Manual Review
- Review all documentation files
- Test examples on fresh system
- Verify placeholders are clear

### User Testing
- Ask new user to follow documentation
- Identify confusing sections
- Update based on feedback

---

## Related Issues

- ISSUE-008: Fix Hardcoded Paths in Scripts
- ISSUE-001: Fix Hardcoded Credentials Paths

---

## References

- Technical Writing Best Practices: https://developers.google.com/tech-writing
- Microsoft Documentation Style Guide: https://learn.microsoft.com/en-us/style-guide/

---

## Success Metrics

- [ ] Zero hardcoded paths in documentation
- [ ] Consistent placeholder usage
- [ ] Platform-specific examples where needed
- [ ] Automated checking in CI
- [ ] Placeholder guide available
- [ ] CONTRIBUTING.md updated
- [ ] Fresh system test successful

---

**Estimated Time Breakdown:**
- Define placeholder standards: 0.5 hours
- Fix CHANGELOG.md: 0.5 hours
- Fix docs/guides/ files: 1.5 hours
- Fix README files: 1 hour
- Create automated checker: 0.5 hours
- Add to CI pipeline: 0.5 hours
- Update CONTRIBUTING.md: 0.5 hours
- **Total: 4 hours**
