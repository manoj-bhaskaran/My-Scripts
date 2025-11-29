# Configuration Guide

Complete guide for configuring My-Scripts repository for local deployment and automation.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration Files Reference](#configuration-files-reference)
  - [Local Deployment Configuration](#local-deployment-configuration)
  - [Module Deployment Configuration](#module-deployment-configuration)
  - [Secrets Configuration](#secrets-configuration)
  - [Task Scheduler Configuration](#task-scheduler-configuration)
  - [Environment Variables](#environment-variables)
- [Platform-Specific Setup](#platform-specific-setup)
  - [Windows Configuration](#windows-configuration)
  - [Linux Configuration](#linux-configuration)
  - [macOS Configuration](#macos-configuration)
- [Common Scenarios](#common-scenarios)
- [Validation and Testing](#validation-and-testing)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Quick Start

Get started with minimal configuration in three steps:

### 1. Local Deployment Configuration

Create your local deployment configuration file:

```bash
# Copy the example configuration
cp config/local-deployment-config.json.example config/local-deployment-config.json
```

Edit `config/local-deployment-config.json`:

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Users\\YourName\\Documents\\Scripts"
}
```

**Important**: Replace `YourName` with your actual username.

### 2. Install Git Hooks

Install git hooks to enable automatic deployment:

```powershell
# Windows PowerShell
.\scripts\Install-GitHooks.ps1

# Linux/macOS
./scripts/install-hooks.sh
```

### 3. Validate Configuration

Run the validation script to ensure everything is set up correctly:

```powershell
.\scripts\Verify-Configuration.ps1
```

Expected output:
```
✅ Configuration validation passed
✅ Local deployment config: Valid
✅ Staging mirror path: Exists and writable
✅ Git hooks: Installed
✅ PowerShell modules: Available
```

---

## Configuration Files Reference

### Local Deployment Configuration

**File**: `config/local-deployment-config.json`
**Purpose**: Controls git hook deployment behavior for local file mirroring
**Git Status**: Ignored (never committed)

#### Schema

```json
{
  "enabled": boolean,
  "stagingMirror": string,
  "moduleFilter": [string],      // Optional
  "excludePatterns": [string]    // Optional
}
```

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | Yes | Enable/disable automatic deployment |
| `stagingMirror` | string | Yes | Absolute path to deployment directory |
| `moduleFilter` | array | No | Specific modules to deploy (empty = all) |
| `excludePatterns` | array | No | File patterns to exclude from deployment |

#### Examples

**Minimal Configuration** (recommended for most users):

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Users\\JohnDoe\\Documents\\Scripts"
}
```

**Windows with Module Filter**:

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Scripts",
  "moduleFilter": ["ErrorHandling", "PostgresBackup"]
}
```

**Linux/macOS**:

```json
{
  "enabled": true,
  "stagingMirror": "/home/johndoe/scripts"
}
```

**Advanced with Exclusions**:

```json
{
  "enabled": true,
  "stagingMirror": "D:\\Deployment\\Scripts",
  "moduleFilter": ["ErrorHandling", "PostgresBackup", "PowerShellLoggingFramework"],
  "excludePatterns": ["*.test.ps1", "*.Tests.ps1", "*.md"]
}
```

**Temporarily Disabled**:

```json
{
  "enabled": false,
  "stagingMirror": "C:\\Users\\JohnDoe\\Documents\\Scripts"
}
```

#### Path Requirements

- **Must be absolute paths** (not relative)
- **Windows**: Use double backslashes `\\` or forward slashes `/`
  - Valid: `C:\\Users\\Name\\Scripts`
  - Valid: `C:/Users/Name/Scripts`
  - Invalid: `..\\Scripts` (relative path)
- **Unix**: Use forward slashes `/`
  - Valid: `/home/user/scripts`
  - Invalid: `~/scripts` (shell expansion not supported)

---

### Module Deployment Configuration

**File**: `config/modules/deployment.txt`
**Purpose**: Defines PowerShell modules and their deployment targets
**Git Status**: Tracked (committed to repository)

#### Format

Pipe-separated values with 5 fields:

```
ModuleName|RelativePathFromRepoRoot|Targets|Author|Description
```

#### Example Entries

```
PostgresBackup|src\powershell\modules\Database\PostgresBackup\PostgresBackup.psm1|System|Manoj Bhaskaran|PostgreSQL database backup module
PowerShellLoggingFramework|src\powershell\modules\Core\Logging\PowerShellLoggingFramework.psm1|System|Manoj Bhaskaran|Cross-platform structured logging framework
RandomName|src\powershell\modules\Utilities\RandomName|System|Manoj Bhaskaran|Generates Windows-safe random file names
```

#### Deployment Targets

| Target | Deployment Location | Platform |
|--------|---------------------|----------|
| `System` | `C:\Program Files\PowerShell\Modules\` | Windows (Admin required) |
| `System` | `/usr/local/share/powershell/Modules/` | Linux/macOS (sudo required) |
| `User` | `%USERPROFILE%\Documents\PowerShell\Modules\` | Windows (No admin) |
| `User` | `~/.local/share/powershell/Modules/` | Linux/macOS (No sudo) |
| `Alt:PATH` | Custom absolute path | All platforms |

#### Customization

To deploy to custom locations:

1. Edit `config/modules/deployment.txt`
2. Change `System` to `User` for user-level deployment
3. Or use `Alt:C:\Custom\Path` for specific locations
4. Run deployment script:

```powershell
.\scripts\Deploy-Modules.ps1 -Force
```

---

### Secrets Configuration

**Directory**: `config/secrets/`
**Purpose**: Stores sensitive configuration files (passwords, API keys)
**Git Status**: Ignored (never committed)
**Security**: Windows DPAPI encryption for password files

#### Setup PostgreSQL Backup Password

Create encrypted password file for database backups:

```powershell
# Navigate to secrets directory
cd config/secrets

# Create encrypted password file
Read-Host "Enter pgbackup user password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "pgbackup_user_pwd.txt"
```

#### Verify Password File

```powershell
# Check file exists
Get-Item config/secrets/pgbackup_user_pwd.txt

# Test with backup script
.\src\powershell\backup\Backup-GnuCashDatabase.ps1 -Verbose
```

#### Custom Password File Location

**Option 1: Environment Variable (Recommended)**

```powershell
# Set for current user (persists across sessions)
[Environment]::SetEnvironmentVariable("PGBACKUP_PASSWORD_FILE", "C:\Secure\pgbackup.txt", "User")

# Or set for current session only
$env:PGBACKUP_PASSWORD_FILE = "C:\Secure\pgbackup.txt"
```

**Option 2: Script Parameter**

```powershell
.\src\powershell\backup\Backup-GnuCashDatabase.ps1 -PasswordFile "C:\Secure\pgbackup.txt"
```

#### File Permissions

Restrict access to secrets directory (Windows):

```powershell
# Remove inherited permissions
$path = ".\config\secrets"
$acl = Get-Acl $path
$acl.SetAccessRuleProtection($true, $false)

# Add permission for current user only
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Apply the ACL
Set-Acl $path $acl
```

**See**: [config/secrets/README.md](secrets/README.md) for complete security documentation.

---

### Task Scheduler Configuration

**Directory**: `config/tasks/`
**Purpose**: Windows Task Scheduler task definitions
**Platform**: Windows only
**Files**: `*.xml.template` files

#### Available Tasks

| Task Name | Schedule | Purpose |
|-----------|----------|---------|
| Monthly System Health Check | Monthly (1st, 2:00 AM) | SFC/DISM system integrity checks |
| Postgres Log Cleanup | Weekly (Sat, 3:00 PM) | Remove old PostgreSQL log files |
| Delete Old Downloads | Monthly (15th, 11:00 AM) | Clean old files from Downloads |
| Drive Space Monitor | Daily (varied) | Monitor Google Drive space |
| Clear Old Recycle Bin Items | Weekly (Sun, 7:54 AM) | Empty old Recycle Bin items |
| PostgreSQL Gnucash Backup | Daily (10:10 AM, 9:00 PM) | Backup GnuCash database |
| PostgreSQL timeline_data Backup | Weekly (Sun, 6:00 PM) | Backup timeline database |
| PostgreSQL job_scheduler Backup | Daily (7:00 AM) | Backup job scheduler database |
| Sync Macrium Backups | Weekly (Tue, 7:30 AM) | Sync backups to Google Drive |

#### Installation

Install all scheduled tasks:

```powershell
# Install using current directory as script root
.\scripts\Install-ScheduledTasks.ps1

# Or specify custom script root
.\scripts\Install-ScheduledTasks.ps1 -ScriptRoot "C:\Users\YourName\Documents\Scripts"

# Force overwrite existing tasks
.\scripts\Install-ScheduledTasks.ps1 -Force
```

#### Customization

1. Edit template files in `config/tasks/*.xml.template`
2. Modify triggers (schedule), execution limits, or parameters
3. Reinstall tasks:

```powershell
.\scripts\Install-ScheduledTasks.ps1 -Force
```

**See**: [INSTALLATION.md](../INSTALLATION.md#scheduled-tasks-setup-windows-only) for detailed task management.

---

### Environment Variables

Environment variables configure script behavior, database connections, and external tool locations.

#### Quick Setup with .env File

**Recommended**: Use `.env` file for centralized configuration.

1. Copy the template:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your values:
   ```bash
   nano .env  # Linux/macOS
   notepad .env  # Windows
   ```

3. Load environment:
   ```powershell
   # PowerShell
   . ./scripts/Load-Environment.ps1

   # Bash
   source ./scripts/load-environment.sh
   ```

4. Validate configuration:
   ```powershell
   # PowerShell
   ./scripts/Verify-Environment.ps1

   # Bash
   ./scripts/verify-environment.sh
   ```

#### Core Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `MY_SCRIPTS_ROOT` | Script execution directory | `C:\Users\Name\Documents\Scripts` |
| `PGHOST` | PostgreSQL server host | `localhost` |
| `PGPORT` | PostgreSQL server port | `5432` |
| `PGUSER` | PostgreSQL username | `postgres` |
| `PGBACKUP_PASSWORD_FILE` | Path to encrypted password file | `C:\secure\pgbackup.txt` |
| `HANDLE_EXE_PATH` | Handle.exe utility location | `C:\Tools\handle.exe` |
| `CLOUDCONVERT_PROD` | CloudConvert API key | `your-api-key` |
| `GDRIVE_CREDENTIALS_PATH` | Google Drive credentials JSON | `~/Documents/Scripts/credentials.json` |
| `GDRIVE_TOKEN_PATH` | Google Drive token JSON | `~/Documents/Scripts/drive_token.json` |

#### Setting Environment Variables

**Windows (PowerShell):**

```powershell
# Set for current session
$env:MY_SCRIPTS_ROOT = "C:\Users\JohnDoe\Documents\Scripts"

# Set permanently (current user)
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", "C:\Users\JohnDoe\Documents\Scripts", "User")

# Set system-wide (requires admin)
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", "C:\Scripts", "Machine")
```

**Linux/macOS (Bash):**

```bash
# Set for current session
export MY_SCRIPTS_ROOT="/home/johndoe/scripts"

# Set permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export MY_SCRIPTS_ROOT="/home/johndoe/scripts"' >> ~/.bashrc
source ~/.bashrc
```

**See**: [docs/guides/environment-variables.md](../docs/guides/environment-variables.md) for complete reference.

---

## Platform-Specific Setup

### Windows Configuration

#### 1. Set Script Execution Directory

```powershell
$env:MY_SCRIPTS_ROOT = "C:\Users\$env:USERNAME\Documents\Scripts"
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", $env:MY_SCRIPTS_ROOT, "User")
```

#### 2. Configure Local Deployment

```powershell
# Create config from template
Copy-Item config\local-deployment-config.json.example config\local-deployment-config.json

# Edit configuration
notepad config\local-deployment-config.json
```

Set:
```json
{
  "enabled": true,
  "stagingMirror": "C:\\Users\\YourName\\Documents\\Scripts"
}
```

#### 3. Install Git Hooks

```powershell
.\scripts\Install-GitHooks.ps1
```

#### 4. Deploy PowerShell Modules (Optional)

```powershell
# Requires Administrator
.\scripts\Deploy-Modules.ps1 -Force
```

#### 5. Set PostgreSQL Environment (if using database backups)

```powershell
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGUSER = "postgres"

# Create encrypted password file
cd config\secrets
Read-Host "Enter PostgreSQL password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "pgbackup_user_pwd.txt"
```

---

### Linux Configuration

#### 1. Set Script Execution Directory

```bash
export MY_SCRIPTS_ROOT="$HOME/scripts"
echo 'export MY_SCRIPTS_ROOT="$HOME/scripts"' >> ~/.bashrc
```

#### 2. Configure Local Deployment

```bash
# Create config from template
cp config/local-deployment-config.json.example config/local-deployment-config.json

# Edit configuration
nano config/local-deployment-config.json
```

Set:
```json
{
  "enabled": true,
  "stagingMirror": "/home/yourusername/scripts"
}
```

#### 3. Install Git Hooks

```bash
chmod +x scripts/*.sh
./scripts/install-hooks.sh
```

#### 4. Deploy PowerShell Modules (Optional)

```bash
# System-wide (requires sudo)
sudo ./scripts/install-modules.sh --force

# Or user-level (no sudo)
# First edit config/modules/deployment.txt and change "System" to "User"
./scripts/install-modules.sh --force
```

#### 5. Set PostgreSQL Environment (if using database backups)

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'
export PGHOST="localhost"
export PGPORT="5432"
export PGUSER="postgres"
EOF

# Or use .pgpass file (more secure)
echo "localhost:5432:*:postgres:yourpassword" > ~/.pgpass
chmod 600 ~/.pgpass
```

---

### macOS Configuration

#### 1. Set Script Execution Directory

```bash
export MY_SCRIPTS_ROOT="$HOME/scripts"
echo 'export MY_SCRIPTS_ROOT="$HOME/scripts"' >> ~/.zshrc
```

#### 2. Configure Local Deployment

```bash
# Create config from template
cp config/local-deployment-config.json.example config/local-deployment-config.json

# Edit configuration
nano config/local-deployment-config.json
```

Set:
```json
{
  "enabled": true,
  "stagingMirror": "/Users/yourusername/scripts"
}
```

#### 3. Install Git Hooks

```bash
chmod +x scripts/*.sh
./scripts/install-hooks.sh
```

#### 4. Deploy PowerShell Modules (Optional)

```bash
# Install PowerShell if not already installed
brew install --cask powershell

# Deploy modules (requires sudo)
sudo ./scripts/install-modules.sh --force
```

#### 5. Set PostgreSQL Environment (if using database backups)

```bash
# Add to ~/.zshrc
cat >> ~/.zshrc << 'EOF'
export PGHOST="localhost"
export PGPORT="5432"
export PGUSER="postgres"
EOF

# Or use .pgpass file (more secure)
echo "localhost:5432:*:postgres:yourpassword" > ~/.pgpass
chmod 600 ~/.pgpass
```

---

## Common Scenarios

### Scenario 1: Fresh System Setup

**Goal**: Set up My-Scripts on a new machine from scratch.

**Steps**:

1. Clone repository:
   ```bash
   git clone https://github.com/manoj-bhaskaran/My-Scripts.git
   cd My-Scripts
   ```

2. Create local deployment config:
   ```bash
   cp config/local-deployment-config.json.example config/local-deployment-config.json
   ```

3. Edit `config/local-deployment-config.json` with your staging path

4. Install git hooks:
   ```bash
   ./scripts/install-hooks.sh  # Linux/macOS
   .\scripts\Install-GitHooks.ps1  # Windows
   ```

5. Validate configuration:
   ```powershell
   .\scripts\Verify-Configuration.ps1
   ```

6. Deploy modules (optional):
   ```bash
   ./scripts/install-modules.sh --force
   ```

**Result**: Fully configured environment ready for development.

---

### Scenario 2: Disable Deployment Temporarily

**Goal**: Temporarily disable automatic deployment without removing configuration.

**Steps**:

1. Edit `config/local-deployment-config.json`
2. Set `"enabled": false`
3. Save file

**Result**: Git hooks will skip deployment but keep configuration for later re-enabling.

---

### Scenario 3: Deploy Only Specific Modules

**Goal**: Deploy only ErrorHandling and PostgresBackup modules.

**Steps**:

1. Edit `config/local-deployment-config.json`
2. Add `moduleFilter` field:
   ```json
   {
     "enabled": true,
     "stagingMirror": "C:\\Scripts",
     "moduleFilter": ["ErrorHandling", "PostgresBackup"]
   }
   ```
3. Save and commit changes

**Result**: Only specified modules will be deployed on commit/merge.

---

### Scenario 4: Multiple Deployment Targets

**Goal**: Deploy to both system-wide and user directories.

**Steps**:

1. Edit `config/modules/deployment.txt`
2. Change target from `System` to `System,User`:
   ```
   PostgresBackup|src\powershell\modules\Database\PostgresBackup\PostgresBackup.psm1|System,User|...
   ```
3. Run deployment:
   ```powershell
   .\scripts\Deploy-Modules.ps1 -Force
   ```

**Result**: Modules deployed to both system and user locations.

---

### Scenario 5: Custom Deployment Location

**Goal**: Deploy modules to `D:\PowerShellModules`.

**Steps**:

1. Edit `config/modules/deployment.txt`
2. Change target to `Alt:D:\PowerShellModules`:
   ```
   PostgresBackup|src\powershell\modules\Database\PostgresBackup\PostgresBackup.psm1|Alt:D:\PowerShellModules|...
   ```
3. Run deployment:
   ```powershell
   .\scripts\Deploy-Modules.ps1 -Force
   ```

**Result**: Modules deployed to custom location.

---

### Scenario 6: Configure Database Backups

**Goal**: Set up automated PostgreSQL backups.

**Steps**:

1. Create encrypted password file:
   ```powershell
   cd config\secrets
   Read-Host "Enter pgbackup password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "pgbackup_user_pwd.txt"
   ```

2. Set environment variables:
   ```powershell
   $env:PGHOST = "localhost"
   $env:PGPORT = "5432"
   $env:PGUSER = "pgbackup"
   ```

3. Test backup:
   ```powershell
   .\src\powershell\backup\Backup-GnuCashDatabase.ps1 -Verbose
   ```

4. Install scheduled task (optional):
   ```powershell
   .\scripts\Install-ScheduledTasks.ps1
   ```

**Result**: Automated database backups configured and tested.

---

## Validation and Testing

### Interactive Configuration Wizard

Run the interactive setup wizard to configure all settings:

```powershell
.\scripts\Initialize-Configuration.ps1
```

The wizard will:
1. Detect your operating system and environment
2. Prompt for configuration values
3. Create/update all configuration files
4. Validate the configuration
5. Provide next steps

### Validation Script

Validate your configuration:

```powershell
.\scripts\Verify-Configuration.ps1
```

The validation script checks:
- ✅ Local deployment config exists and is valid JSON
- ✅ Staging mirror path exists and is writable
- ✅ Git hooks are installed and executable
- ✅ PowerShell modules are available
- ✅ Environment variables are set correctly
- ✅ Secrets directory has correct permissions
- ✅ PostgreSQL password file exists (if configured)

### Test Deployment

Test deployment without making changes:

```powershell
# Test git hooks deployment (dry-run)
git commit --dry-run

# Test module deployment (dry-run)
.\scripts\Deploy-Modules.ps1 -WhatIf
```

---

## Troubleshooting

### Problem: Configuration File Not Found

**Symptoms**: Error message "Configuration file not found: config/local-deployment-config.json"

**Solutions**:

1. Check file exists:
   ```bash
   ls -la config/local-deployment-config.json
   ```

2. Copy from example:
   ```bash
   cp config/local-deployment-config.json.example config/local-deployment-config.json
   ```

3. Ensure file is in correct location (inside `config/` directory)

---

### Problem: Staging Mirror Path Not Found

**Symptoms**: Error message "Staging mirror path does not exist" or "Cannot create staging mirror directory"

**Solutions**:

1. Verify path in config file:
   ```powershell
   Get-Content config\local-deployment-config.json
   ```

2. Create directory manually:
   ```powershell
   # Windows
   New-Item -ItemType Directory -Path "C:\Users\YourName\Documents\Scripts" -Force

   # Linux/macOS
   mkdir -p /home/yourusername/scripts
   ```

3. Check path format:
   - Windows: Use double backslashes `C:\\Users\\...` or forward slashes `C:/Users/...`
   - Unix: Use forward slashes `/home/user/...`
   - **Do not use** relative paths or shell expansions (`~`)

4. Verify permissions:
   ```powershell
   # Windows - check if you can write to the directory
   Test-Path "C:\Users\YourName\Documents\Scripts" -PathType Container

   # Linux/macOS - check permissions
   ls -ld /home/yourusername/scripts
   ```

---

### Problem: Permission Denied

**Symptoms**: "Access denied" or "Permission denied" when deploying modules or creating directories

**Solutions**:

1. **Windows**: Run PowerShell as Administrator:
   - Right-click PowerShell icon
   - Select "Run as Administrator"
   - Re-run deployment script

2. **Linux/macOS**: Use `sudo` for system-wide installation:
   ```bash
   sudo ./scripts/install-modules.sh --force
   ```

3. **Alternative**: Install to user directory instead:
   - Edit `config/modules/deployment.txt`
   - Change `System` to `User`
   - Re-run deployment (no admin/sudo required)

---

### Problem: Invalid JSON in Configuration File

**Symptoms**: "Invalid JSON" or "Parse error" when reading configuration

**Solutions**:

1. Validate JSON syntax:
   ```powershell
   # PowerShell
   Get-Content config\local-deployment-config.json | ConvertFrom-Json

   # Or use online validator: https://jsonlint.com/
   ```

2. Common JSON errors:
   - **Trailing commas**: Remove commas after last field
     ```json
     // ❌ Wrong
     {
       "enabled": true,
       "stagingMirror": "C:\\Scripts",  <-- remove this comma
     }

     // ✅ Correct
     {
       "enabled": true,
       "stagingMirror": "C:\\Scripts"
     }
     ```

   - **Single quotes**: Use double quotes
     ```json
     // ❌ Wrong
     { 'enabled': true }

     // ✅ Correct
     { "enabled": true }
     ```

   - **Backslashes**: Use double backslashes or forward slashes
     ```json
     // ❌ Wrong
     "stagingMirror": "C:\Users\Name\Scripts"

     // ✅ Correct
     "stagingMirror": "C:\\Users\\Name\\Scripts"
     // or
     "stagingMirror": "C:/Users/Name/Scripts"
     ```

---

### Problem: Git Hooks Not Running

**Symptoms**: No files deployed after commit/merge

**Solutions**:

1. Verify hooks are installed:
   ```bash
   ls -la .git/hooks/
   ```

2. Check hooks are executable:
   ```bash
   # Linux/macOS
   chmod +x .git/hooks/post-commit
   chmod +x .git/hooks/post-merge
   ```

3. Verify PowerShell is available:
   ```bash
   # Check for PowerShell 7+
   pwsh --version

   # Windows
   powershell.exe -Command "Get-Host"
   ```

4. Test hook manually:
   ```bash
   # Linux/macOS
   .git/hooks/post-commit

   # Windows Git Bash
   .git/hooks/post-commit
   ```

5. Check hook logs:
   ```bash
   # Logs are in staging mirror directory
   cat "C:/Users/Name/Documents/Scripts/logs/git-post-action.log"
   ```

---

### Problem: Password File Not Found

**Symptoms**: "Password file not found" error when running backup scripts

**Solutions**:

1. Create password file:
   ```powershell
   cd config\secrets
   Read-Host "Enter password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "pgbackup_user_pwd.txt"
   ```

2. Verify file exists:
   ```powershell
   Get-Item config\secrets\pgbackup_user_pwd.txt
   ```

3. Set custom location via environment variable:
   ```powershell
   $env:PGBACKUP_PASSWORD_FILE = "C:\Secure\pgbackup.txt"
   ```

4. Or pass as parameter:
   ```powershell
   .\src\powershell\backup\Backup-GnuCashDatabase.ps1 -PasswordFile "C:\Secure\pgbackup.txt"
   ```

---

### Problem: Failed to Decrypt Password File

**Symptoms**: "Failed to read or decrypt password file" error

**Causes**: Password file was created by different Windows user or on different machine (Windows DPAPI is user and machine specific)

**Solutions**:

1. Recreate password file:
   ```powershell
   Remove-Item config\secrets\pgbackup_user_pwd.txt -ErrorAction SilentlyContinue
   Read-Host "Enter password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "config\secrets\pgbackup_user_pwd.txt"
   ```

2. Verify you're running as the same user who created the file:
   ```powershell
   whoami
   ```

---

### Problem: Module Not Found After Deployment

**Symptoms**: `Get-Module -ListAvailable ModuleName` returns nothing

**Solutions**:

1. Check module path:
   ```powershell
   $env:PSModulePath -split [System.IO.Path]::PathSeparator
   ```

2. Verify deployment completed:
   ```powershell
   .\scripts\Deploy-Modules.ps1 -Verbose
   ```

3. Check module exists in expected location:
   ```powershell
   # Windows
   Get-ChildItem "C:\Program Files\PowerShell\Modules" -Directory

   # Linux/macOS
   ls -la /usr/local/share/powershell/Modules/
   ```

4. Import module by path:
   ```powershell
   Import-Module "C:\Program Files\PowerShell\Modules\PostgresBackup\2.0.0\PostgresBackup.psd1"
   ```

---

### Problem: Scheduled Task Not Running

**Symptoms**: Task appears in Task Scheduler but doesn't execute

**Solutions**:

1. Check task status:
   ```powershell
   Get-ScheduledTask -TaskName "MyScripts-*" | Format-Table TaskName, State, LastRunTime, LastTaskResult
   ```

2. View task history:
   - Open Task Scheduler (taskschd.msc)
   - Select the task
   - Click "History" tab

3. Run task manually:
   ```powershell
   Start-ScheduledTask -TaskName "MyScripts-Monthly System Health Check"
   ```

4. Check script path in task XML:
   ```powershell
   Get-ScheduledTask -TaskName "MyScripts-Monthly System Health Check" | Select-Object -ExpandProperty Actions
   ```

5. Test script directly:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File "C:\path\to\script.ps1"
   ```

---

## Advanced Configuration

### Custom Module Deployment Paths

Deploy different modules to different locations:

1. Edit `config/modules/deployment.txt`
2. Use `Alt:` prefix for custom paths:

```
# Deploy to multiple locations
PostgresBackup|src\powershell\modules\Database\PostgresBackup\PostgresBackup.psm1|System,Alt:D:\SharedModules|...

# Deploy different modules to different locations
ErrorHandling|src\powershell\modules\Core\ErrorHandling|System|...
RandomName|src\powershell\modules\Utilities\RandomName|User|...
Videoscreenshot|src\powershell\modules\Media\Videoscreenshot|Alt:C:\CustomPath|...
```

### Exclude Patterns for Deployment

Exclude certain file types from deployment:

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Scripts",
  "excludePatterns": [
    "*.test.ps1",
    "*.Tests.ps1",
    "*.md",
    ".git*",
    "docs/**"
  ]
}
```

### Module Filtering

Deploy only specific modules:

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Scripts",
  "moduleFilter": [
    "ErrorHandling",
    "FileOperations",
    "PowerShellLoggingFramework"
  ]
}
```

### Environment-Specific Configuration

Use different configurations for different environments:

**Development**:
```json
{
  "enabled": true,
  "stagingMirror": "C:\\Dev\\Scripts",
  "moduleFilter": ["ErrorHandling", "FileOperations"]
}
```

**Production**:
```json
{
  "enabled": true,
  "stagingMirror": "C:\\Production\\Scripts",
  "excludePatterns": ["*.test.ps1", "*.Tests.ps1"]
}
```

Switch between configs:
```powershell
# Use development config
Copy-Item config\local-deployment-config.dev.json config\local-deployment-config.json

# Use production config
Copy-Item config\local-deployment-config.prod.json config\local-deployment-config.json
```

---

## Related Documentation

- **[INSTALLATION.md](../INSTALLATION.md)** - Installation guide and prerequisites
- **[config/DEPLOYMENT-SETUP.md](DEPLOYMENT-SETUP.md)** - Git hooks deployment setup
- **[config/secrets/README.md](secrets/README.md)** - Secure configuration guide
- **[docs/guides/environment-variables.md](../docs/guides/environment-variables.md)** - Environment variables reference
- **[docs/guides/module-deployment.md](../docs/guides/module-deployment.md)** - Module deployment guide
- **[docs/guides/git-hooks.md](../docs/guides/git-hooks.md)** - Git hooks documentation

---

## Support

If you encounter issues with configuration:

1. Run the validation script: `.\scripts\Verify-Configuration.ps1`
2. Check the troubleshooting section above
3. Review relevant documentation linked above
4. Search existing [GitHub issues](https://github.com/manoj-bhaskaran/My-Scripts/issues)
5. Open a new issue if your problem isn't covered

---

**Last Updated**: 2025-11-29
**Version**: 2.2.0
