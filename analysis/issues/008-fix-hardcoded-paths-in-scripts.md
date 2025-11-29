# ISSUE-008: Fix Hardcoded Paths in PowerShell Scripts and Batch Files

**Priority:** 🟠 HIGH
**Category:** Portability / Security
**Estimated Effort:** 6 hours
**Skills Required:** PowerShell, Batch Scripting, Path Handling

---

## Problem Statement

Multiple PowerShell scripts and batch files contain hardcoded paths that expose usernames and prevent portability. These paths must be replaced with relative paths or environment variables.

### Affected Files

**PowerShell Scripts:**
- `src/powershell/backup/Backup-GnuCashDatabase.ps1` (Line 6) - **SECURITY RISK**
- `src/powershell/cloud/Invoke-CloudConvert.ps1` (Line 34)

**Batch Files:**
- `src/batch/RunDeleteOldDownloads.bat` (Line 23)

### Current Code Examples

```powershell
# Backup-GnuCashDatabase.ps1 - SECURITY RISK
$password = Get-Content "C:\Users\manoj\Documents\Scripts\pgbackup_user\pgbackup_user_pwd.txt" | ConvertTo-SecureString

# Invoke-CloudConvert.ps1
$scriptPath = "C:\Users\manoj\Documents\Scripts\src\python\cloudconvert_utils.py"

# RunDeleteOldDownloads.bat
SET SCRIPT_PATH=C:\Users\manoj\Documents\Scripts\src\powershell\cleanup\Remove-OldDownloads.ps1
```

### Impact

- ⚠️ **Security Risk:** Password file location exposed in version control
- 🚫 **Not Portable:** Scripts fail on other systems
- 💥 **Runtime Errors:** File not found errors on other machines
- 🔧 **Maintenance:** Path changes require editing multiple files

---

## Acceptance Criteria

- [ ] All hardcoded paths removed from PowerShell scripts
- [ ] All hardcoded paths removed from batch files
- [ ] Password files moved to secure config directory
- [ ] Scripts use $PSScriptRoot for relative paths
- [ ] Scripts use environment variables where appropriate
- [ ] Path validation added (clear error if file missing)
- [ ] All scripts tested on different systems
- [ ] No security issues (no exposed credentials)
- [ ] Documentation updated

---

## Implementation Plan

### Step 1: Fix Backup-GnuCashDatabase.ps1 (1.5 hours) - PRIORITY

```powershell
# src/powershell/backup/Backup-GnuCashDatabase.ps1

[CmdletBinding()]
param(
    [string]$PasswordFile
)

# Import logging
Import-Module "$PSScriptRoot/../modules/Core/Logging/PowerShellLoggingFramework.psm1"
$logger = Initialize-Logger -ScriptName "Backup-GnuCashDatabase"

# Determine password file location
if (-not $PasswordFile) {
    # Try environment variable first
    if ($env:PGBACKUP_PASSWORD_FILE) {
        $PasswordFile = $env:PGBACKUP_PASSWORD_FILE
    }
    # Fall back to config directory (relative to script)
    else {
        $scriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $PasswordFile = Join-Path $scriptRoot "config" "secrets" "pgbackup_user_pwd.txt"
    }
}

# Validate password file exists
if (-not (Test-Path $PasswordFile)) {
    Write-LogError $logger "Password file not found: $PasswordFile"
    Write-LogError $logger "Set PGBACKUP_PASSWORD_FILE environment variable or place file at: $PasswordFile"
    throw "Password file not found: $PasswordFile"
}

Write-LogInfo $logger "Using password file: $PasswordFile"

# Read password securely
try {
    $password = Get-Content $PasswordFile | ConvertTo-SecureString -ErrorAction Stop
    Write-LogInfo $logger "Password loaded successfully"
}
catch {
    Write-LogError $logger "Failed to read password file: $_"
    throw "Failed to read password: $_"
}

# Rest of backup logic...
```

**Security Improvement:**
```bash
# Create secure config directory structure
mkdir -p config/secrets
echo "config/secrets/*.txt" >> .gitignore
echo "config/secrets/*.pwd" >> .gitignore

# Move password file to config
# (User must do this manually - don't commit passwords!)
```

### Step 2: Fix Invoke-CloudConvert.ps1 (1 hour)

```powershell
# src/powershell/cloud/Invoke-CloudConvert.ps1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputFile,

    [Parameter(Mandatory)]
    [string]$OutputFormat,

    [string]$PythonScript
)

# Determine Python script path
if (-not $PythonScript) {
    # Use relative path from this script
    $scriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $PythonScript = Join-Path $scriptRoot "src" "python" "cloudconvert_utils.py"
}

# Validate Python script exists
if (-not (Test-Path $PythonScript)) {
    throw "Python script not found: $PythonScript"
}

Write-Verbose "Using Python script: $PythonScript"

# Validate input file
if (-not (Test-Path $InputFile)) {
    throw "Input file not found: $InputFile"
}

# Execute Python script
$arguments = @(
    $PythonScript,
    "--input", "`"$InputFile`"",
    "--output-format", $OutputFormat
)

Write-Verbose "Executing: python $($arguments -join ' ')"

try {
    $result = & python $arguments
    if ($LASTEXITCODE -ne 0) {
        throw "CloudConvert failed with exit code: $LASTEXITCODE"
    }
    Write-Output $result
}
catch {
    Write-Error "CloudConvert execution failed: $_"
    throw
}
```

### Step 3: Fix RunDeleteOldDownloads.bat (1 hour)

```batch
@echo off
REM src/batch/RunDeleteOldDownloads.bat

REM Get script directory
SET SCRIPT_DIR=%~dp0

REM Navigate up to repository root
SET REPO_ROOT=%SCRIPT_DIR%..\..

REM Build path to PowerShell script
SET PS_SCRIPT=%REPO_ROOT%\src\powershell\cleanup\Remove-OldDownloads.ps1

REM Validate script exists
IF NOT EXIST "%PS_SCRIPT%" (
    echo Error: Script not found: %PS_SCRIPT%
    echo Please check the repository structure.
    exit /b 1
)

REM Execute PowerShell script
echo Running: %PS_SCRIPT%
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%" %*

REM Check exit code
IF %ERRORLEVEL% NEQ 0 (
    echo Script failed with error code: %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Script completed successfully
exit /b 0
```

### Step 4: Create Secure Config Guide (1 hour)

Create `config/secrets/README.md`:

```markdown
# Secure Configuration Files

This directory stores sensitive configuration files that should NEVER be committed to version control.

## Setup

### PostgreSQL Backup Password

1. Create password file:
   ```powershell
   # Create file with encrypted password
   Read-Host "Enter pgbackup user password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath ".\pgbackup_user_pwd.txt"
   ```

2. Set environment variable (optional):
   ```powershell
   [Environment]::SetEnvironmentVariable("PGBACKUP_PASSWORD_FILE", "C:\path\to\config\secrets\pgbackup_user_pwd.txt", "User")
   ```

3. Verify:
   ```powershell
   # This should work without errors
   .\src\powershell\backup\Backup-GnuCashDatabase.ps1
   ```

## Security Notes

- ✅ Files in this directory are ignored by git
- ✅ Use Windows file permissions to restrict access
- ✅ Passwords stored as SecureString (encrypted)
- ❌ Never commit this directory's contents
- ❌ Never share password files
```

### Step 5: Find and Fix All Other Hardcoded Paths (1.5 hours)

```bash
# Search for remaining hardcoded paths
grep -r "C:\\\\Users\\\\manoj" src/ --include="*.ps1" --include="*.bat"
grep -r "C:/Users/manoj" src/ --include="*.ps1" --include="*.bat"

# Search for other common patterns
grep -r 'Documents\\Scripts' src/ --include="*.ps1"
grep -r 'Documents/Scripts' src/ --include="*.ps1"
```

Fix pattern:
1. Replace with `$PSScriptRoot` relative paths
2. Add path validation
3. Support environment variable override
4. Add clear error messages

### Step 6: Testing and Documentation (1 hour)

```powershell
# Test script
function Test-ScriptPaths {
    param([string]$ScriptPath)

    Write-Host "Testing: $ScriptPath"

    # Parse script for hardcoded paths
    $content = Get-Content $ScriptPath -Raw

    $patterns = @(
        'C:\\Users\\',
        'C:/Users/',
        'D:\\',
        'E:\\'
    )

    $found = $false
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            Write-Warning "Found hardcoded path pattern '$pattern' in $ScriptPath"
            $found = $true
        }
    }

    if (-not $found) {
        Write-Host "✓ No hardcoded paths found" -ForegroundColor Green
    }
}

# Test all scripts
Get-ChildItem src/ -Recurse -Include *.ps1,*.bat | ForEach-Object {
    Test-ScriptPaths $_.FullName
}
```

---

## Testing Strategy

### Automated Tests
- Scan all scripts for hardcoded path patterns
- Validate scripts run with relative paths
- Test on different drive letters

### Manual Tests
1. Copy repository to different location
2. Run each affected script
3. Verify scripts find files correctly
4. Test with environment variables set
5. Test without environment variables

### Security Validation
- Verify password files not in git
- Check .gitignore includes secrets directory
- Confirm no credentials in version control

---

## Related Issues

- ISSUE-001: Fix Hardcoded Credentials Paths
- ISSUE-005: Create Environment Variable System
- ISSUE-007: Create Task Scheduler Templates
- ISSUE-009: Fix Hardcoded Paths in Documentation

---

## References

- PowerShell Automatic Variables: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables
- Batch File Path Variables: https://ss64.com/nt/syntax-args.html

---

## Success Metrics

- [ ] Zero hardcoded absolute paths in scripts
- [ ] All scripts use $PSScriptRoot or %~dp0
- [ ] Password files in secure config directory
- [ ] Path validation with clear error messages
- [ ] Scripts work on different systems/drives
- [ ] No security issues
- [ ] Documentation updated

---

**Estimated Time Breakdown:**
- Fix Backup-GnuCashDatabase.ps1: 1.5 hours
- Fix Invoke-CloudConvert.ps1: 1 hour
- Fix batch files: 1 hour
- Create secure config guide: 1 hour
- Find and fix other paths: 1.5 hours
- Testing and documentation: 1 hour
- **Total: 6 hours**
