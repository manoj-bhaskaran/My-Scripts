# Installation Guide

This guide provides comprehensive instructions for setting up and installing the My-Scripts repository and its modules.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Repository Setup](#repository-setup)
- [Module Installation](#module-installation)
- [Platform-Specific Instructions](#platform-specific-instructions)
- [Scheduled Tasks Setup (Windows Only)](#scheduled-tasks-setup-windows-only)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

## Quick Start

For experienced users who want to get started quickly:

```bash
# Clone the repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# Install git hooks (optional but recommended)
./scripts/install-hooks.sh

# Install all modules
./scripts/install-modules.sh

# Verify installation
pwsh -c 'Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework,PurgeLogs,RandomName,Videoscreenshot'
python3 -c 'import python_logging_framework; print("OK")'
```

## Prerequisites

### Required Software

Before installing, ensure you have the following installed:

#### Essential
- **Git** - Version control system
  - Windows: [Git for Windows](https://git-scm.com/download/win)
  - Linux: `sudo apt install git` (Debian/Ubuntu) or `sudo yum install git` (RHEL/CentOS)
  - macOS: `brew install git`

- **PowerShell** - Shell and scripting language
  - Windows: PowerShell 5.1+ (built-in) or PowerShell 7+ (recommended)
  - Linux/macOS: [PowerShell 7+](https://github.com/PowerShell/PowerShell#get-powershell)

  ```bash
  # Install PowerShell on Linux
  wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb
  sudo dpkg -i powershell_7.4.0-1.deb_amd64.deb

  # Install PowerShell on macOS
  brew install --cask powershell
  ```

- **Python 3.7+** - Programming language
  - Windows: [Python.org](https://www.python.org/downloads/)
  - Linux: `sudo apt install python3 python3-pip` (Debian/Ubuntu)
  - macOS: `brew install python3`

#### Optional (for specific scripts)
- **PostgreSQL Client** - Required for database backup scripts
- **VLC Media Player** - Required for Videoscreenshot module
- **ADB (Android Debug Bridge)** - Required for Copy-AndroidFiles.ps1
- **CloudConvert API Key** - Required for cloudconvert_utils.py
- **Google Cloud Project** - Required for Google Drive scripts
- **Image processing libraries** - Required for certain Python scripts (PIL, OpenCV)

### Permissions

- **Windows**: Administrator privileges for system-wide module installation
- **Linux/macOS**: `sudo` access for system-wide installation (or use user-level installation)

### Python Dependencies

This repository requires the following Python packages (installed via `requirements.txt`):

```
requests, numpy, pandas, opencv-python, cloudconvert
google-auth, google-auth-oauthlib, google-api-python-client
tqdm, networkx, openpyxl, psycopg2, pytz
pytest, pytest-cov, pytest-mock (for testing)
```

## Repository Setup

### 1. Clone the Repository

```bash
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts
```

### 2. Install Git Hooks (Optional but Recommended)

Git hooks enforce code quality and consistent commit messages using the **pre-commit framework**:

```bash
# Linux/macOS/Git Bash
./scripts/install-hooks.sh
```

This installs:
- **Pre-commit framework**: Multi-language hook manager
- **Python hooks**: Black (formatter), Pylint (linter), Bandit (security)
- **PowerShell hooks**: PSScriptAnalyzer (linter)
- **SQL hooks**: SQLFluff (linter/formatter)
- **General hooks**: Trailing whitespace, YAML/JSON validation, large files check
- **Commit message validation**: Conventional Commits format enforcement
- **Post-commit**: Automatic module deployment to staging
- **Post-merge**: Post-merge automation

**What the script does:**
1. Installs pre-commit framework via pip
2. Configures hooks from `.pre-commit-config.yaml`
3. Runs validation on all files

See [docs/guides/git-hooks.md](docs/guides/git-hooks.md) for comprehensive documentation.

### 3. Review Configuration

Check the module deployment configuration:

```bash
cat config/module-deployment-config.txt
```

This file controls which modules are deployed and where they go.

### 4. Install Python Dependencies

```bash
# Install all required Python packages
pip install -r requirements.txt

# Or with Python 3 explicitly
pip3 install -r requirements.txt
```

## Optional Software Installation

These software packages are optional and only required for specific scripts.

### VLC Media Player (for Videoscreenshot module)

**Windows:**
1. Download from [https://www.videolan.org/vlc/](https://www.videolan.org/vlc/)
2. Install using the installer
3. Add to PATH (if not automatically added):
   ```powershell
   # Add to current session
   $env:Path += ";C:\Program Files\VideoLAN\VLC"

   # Add permanently (as Administrator)
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\VideoLAN\VLC", "Machine")
   ```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install vlc

# Fedora/RHEL/CentOS
sudo yum install vlc

# Verify installation
which vlc
```

**macOS:**
```bash
brew install --cask vlc

# Verify installation
which vlc
```

### ADB (Android Debug Bridge)

**Windows:**
1. Download [Android SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools)
2. Extract to a directory (e.g., `C:\adb`)
3. Add to PATH:
   ```powershell
   # Add to current session
   $env:Path += ";C:\adb"

   # Add permanently (as Administrator)
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\adb", "Machine")
   ```
4. Verify: `adb --version`

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install android-tools-adb

# Fedora/RHEL/CentOS
sudo yum install android-tools

# Verify
adb --version
```

**macOS:**
```bash
brew install android-platform-tools

# Verify
adb --version
```

### PostgreSQL Client

**Windows:**
1. Download from [PostgreSQL Downloads](https://www.postgresql.org/download/windows/)
2. Run installer and select "Command Line Tools" component
3. Verify installation: `psql --version`

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# Fedora/RHEL/CentOS
sudo yum install postgresql

# Verify
psql --version
```

**macOS:**
```bash
brew install postgresql

# Verify
psql --version
```

### API Keys and Cloud Services

**CloudConvert:**
1. Sign up at [https://cloudconvert.com/](https://cloudconvert.com/)
2. Generate an API key from the dashboard
3. Set as environment variable (see Environment Configuration section)

**Google Cloud:**
1. Create a project at [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Drive API
3. Create OAuth 2.0 credentials
4. Download credentials JSON
5. Set environment variables (see Environment Configuration section)

## Configuration

For detailed configuration instructions, see **[config/CONFIG_GUIDE.md](config/CONFIG_GUIDE.md)**.

### Quick Configuration Setup

1. **Run the interactive configuration wizard:**
   ```powershell
   .\scripts\Initialize-Configuration.ps1
   ```

2. **Or manually configure:**
   ```bash
   # Copy local deployment config template
   cp config/local-deployment-config.json.example config/local-deployment-config.json

   # Edit configuration
   nano config/local-deployment-config.json  # Linux/macOS
   notepad config\local-deployment-config.json  # Windows
   ```

3. **Validate your configuration:**
   ```powershell
   .\scripts\Verify-Configuration.ps1
   ```

The [Configuration Guide](config/CONFIG_GUIDE.md) includes:
- Local deployment configuration (git hooks)
- Module deployment settings
- Environment variables setup
- Secrets configuration (database passwords)
- Platform-specific instructions
- Troubleshooting guide

## Environment Configuration

# Create and load a `.env` file to manage all configuration in one place.

### Quick Setup

1. **Copy the template:**
   ```bash
   cp .env.example .env
   ```
2. **Edit your values:**
   - Required: `MY_SCRIPTS_ROOT` (script execution directory)
   - Feature flags: set the variables for the services you plan to use (Google Drive, CloudConvert, database backups, etc.)
3. **Load the environment:**
   - PowerShell: `. ./scripts/Load-Environment.ps1`
   - Bash: `source scripts/load-environment.sh`
4. **Validate configuration:**
   - PowerShell: `./scripts/Verify-Environment.ps1`
   - Bash: `./scripts/verify-environment.sh`
5. **Review the full reference:** see `docs/guides/environment-variables.md` for every variable, default, and description.

### Google Drive Integration

Google Drive scripts require OAuth 2.0 credentials for API access. Follow these steps to set up:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Drive API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Drive API" and enable it
4. Create **OAuth 2.0 credentials**:
   - Navigate to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth 2.0 Client ID"
   - Select "Desktop app" as application type
   - Download the credentials JSON file
5. Configure credential file paths:
   - `GDRIVE_CREDENTIALS_PATH` (defaults to `~/Documents/Scripts/credentials.json`)
   - `GDRIVE_TOKEN_PATH` (defaults to `~/Documents/Scripts/drive_token.json`)
   - Recovery tool overrides: `GDRT_CREDENTIALS_FILE` and `GDRT_TOKEN_FILE`
6. Load `.env` and run the validation script to confirm configuration.

The token file (`drive_token.json`) is created automatically during the first OAuth authentication flow.

### CloudConvert Scripts

CloudConvert requires an API key:

- Set `CLOUDCONVERT_PROD` in `.env`
- Load the environment and run the validation script

### PostgreSQL Database Backups

Configure database connection parameters as needed (defaults are provided in `.env.example`):

**Windows (PowerShell):**
```powershell
# Set database connection parameters
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGUSER = "your-username"
$env:PGPASSWORD = "your-password"  # Note: Consider using .pgpass file instead

# Set permanently (current user)
[Environment]::SetEnvironmentVariable("PGHOST", "localhost", "User")
[Environment]::SetEnvironmentVariable("PGPORT", "5432", "User")
[Environment]::SetEnvironmentVariable("PGUSER", "your-username", "User")
```

**Linux/macOS (Bash):**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PGHOST="localhost"
export PGPORT="5432"
export PGUSER="your-username"
export PGPASSWORD="your-password"  # Note: Consider using .pgpass file instead

# Or use .pgpass file (more secure)
# Create ~/.pgpass with format: hostname:port:database:username:password
echo "localhost:5432:*:your-username:your-password" > ~/.pgpass
chmod 600 ~/.pgpass
```

### Configuration Files

The repository includes several configuration files:

- **[config/CONFIG_GUIDE.md](config/CONFIG_GUIDE.md)** – Comprehensive configuration guide
- **config/local-deployment-config.json** – Local deployment settings (git hooks)
- **config/modules/deployment.txt** – Module deployment targets
- **config/tasks/*.xml** – Windows Task Scheduler definitions
- **config/secrets/** – Encrypted password files (git-ignored)
- **.vscode/settings.json** – Editor configuration (optional)

See [config/CONFIG_GUIDE.md](config/CONFIG_GUIDE.md) for detailed configuration instructions.

## Module Installation

Modules are optional but recommended for the best experience. They allow you to use shared functionality across scripts without manual path management.

### Automated Installation (Recommended)

The easiest way to install all modules:

```bash
./scripts/install-modules.sh
```

**Options:**
```bash
# Force overwrite existing modules
./scripts/install-modules.sh --force

# Install only PowerShell modules
./scripts/install-modules.sh --powershell-only

# Install only Python modules
./scripts/install-modules.sh --python-only

# Show help
./scripts/install-modules.sh --help
```

### Manual Installation

#### PowerShell Modules Only

```powershell
# Windows PowerShell or PowerShell Core
./scripts/Deploy-Modules.ps1 -Force

# See what would be deployed without making changes
./scripts/Deploy-Modules.ps1 -WhatIf

# Deploy with verbose output
./scripts/Deploy-Modules.ps1 -Verbose
```

**Where modules are installed:**

- **Windows (PowerShell 5.1)**: `C:\Program Files\WindowsPowerShell\Modules\`
- **Windows (PowerShell Core)**: `C:\Program Files\PowerShell\Modules\`
- **Linux**: `/usr/local/share/powershell/Modules/`
- **macOS**: `/usr/local/share/powershell/Modules/`

#### Python Modules Only

```bash
# Development installation (editable mode - recommended)
pip install -e .

# Or standard installation
pip install .

# For Python 3 specifically
pip3 install -e .
```

**What gets installed:**
- Package name: `my-scripts-logging`
- Module name: `python_logging_framework`

## Platform-Specific Instructions

### Windows

#### Using PowerShell (Recommended)

```powershell
# Clone repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# Install git hooks
.\scripts\install-hooks.ps1

# Install all modules (requires Administrator)
.\scripts\Deploy-Modules.ps1 -Force
pip install -e .

# Verify
Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework
python -c "import python_logging_framework; print('OK')"
```

#### Using Git Bash

```bash
# Clone repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# Install git hooks
./scripts/install-hooks.sh

# Install all modules
./scripts/install-modules.sh --force

# Verify
pwsh -c 'Get-Module -ListAvailable PostgresBackup'
python -c 'import python_logging_framework; print("OK")'
```

### Linux

```bash
# Clone repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# Install git hooks
chmod +x scripts/*.sh
./scripts/install-hooks.sh

# Install PowerShell (if not installed)
# See Prerequisites section above

# Install all modules
sudo ./scripts/install-modules.sh --force

# Or install to user directory (no sudo needed)
# Edit config/module-deployment-config.txt and change "System" to "User"
./scripts/install-modules.sh --force

# Verify
pwsh -c 'Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework'
python3 -c 'import python_logging_framework; print("OK")'
```

### macOS

```bash
# Clone repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# Install git hooks
chmod +x scripts/*.sh
./scripts/install-hooks.sh

# Install PowerShell (if not installed)
brew install --cask powershell

# Install all modules
sudo ./scripts/install-modules.sh --force

# Verify
pwsh -c 'Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework'
python3 -c 'import python_logging_framework; print("OK")'
```

## Scheduled Tasks Setup (Windows Only)

My-Scripts includes automated scheduled tasks for maintenance, backups, and monitoring on Windows systems.

### Installation

**Prerequisites:**
- Windows operating system with Task Scheduler
- Administrator privileges (recommended)
- Scripts properly installed in a permanent location

**Install all scheduled tasks:**

```powershell
# Install tasks using current directory as script root
.\scripts\Install-ScheduledTasks.ps1

# Or specify custom script root
.\scripts\Install-ScheduledTasks.ps1 -ScriptRoot "C:\Users\YourName\Documents\Scripts"

# Preview installation (dry-run)
.\scripts\Install-ScheduledTasks.ps1 -WhatIf

# Force overwrite existing tasks
.\scripts\Install-ScheduledTasks.ps1 -Force
```

### Installed Tasks

The installation creates the following scheduled tasks:

| Task Name | Schedule | Description |
|-----------|----------|-------------|
| MyScripts-Monthly System Health Check | Monthly (1st day, 2:00 AM) | Runs SFC and DISM system integrity checks |
| MyScripts-Postgres Log Cleanup | Weekly (Saturday, 3:00 PM) | Removes old PostgreSQL log files |
| MyScripts-Delete Old Downloads | Monthly (15th day, 11:00 AM) | Cleans old files from Downloads folder |
| MyScripts-Drive Space Monitor | Daily (weekdays 8:00 AM, weekends every 2 hours) | Monitors Google Drive space usage |
| MyScripts-Clear Old Recycle Bin Items | Weekly (Sunday, 7:54 AM) | Empties old items from Recycle Bin |
| MyScripts-PostgreSQL Gnucash Backup | Daily (10:10 AM, 9:00 PM) | Backs up GnuCash database |
| MyScripts-PostgreSQL timeline_data Backup | Weekly (Sunday, 6:00 PM) | Backs up timeline database |
| MyScripts-PostgreSQL job_scheduler Backup | Daily (7:00 AM) | Backs up job scheduler database |
| MyScripts-Sync Macrium Backups | Weekly (Tuesday, 7:30 AM) | Syncs Macrium backups to Google Drive |

**Note:** All tasks include randomized delays to prevent simultaneous execution.

### Customization

To customize task schedules or settings:

1. **Edit template files** in `config/tasks/*.xml.template`:
   - Modify triggers (schedule)
   - Adjust execution time limits
   - Change task parameters
   - Update descriptions

2. **Reinstall tasks** after editing:
   ```powershell
   .\scripts\Install-ScheduledTasks.ps1 -Force
   ```

3. **Or use Task Scheduler GUI:**
   - Open Task Scheduler (taskschd.msc)
   - Navigate to your tasks (search for "MyScripts-")
   - Edit properties as needed

### Managing Tasks

**View installed tasks:**
```powershell
Get-ScheduledTask -TaskName "MyScripts-*"
```

**Run a task manually:**
```powershell
Start-ScheduledTask -TaskName "MyScripts-Monthly System Health Check"
```

**Check task status:**
```powershell
Get-ScheduledTask -TaskName "MyScripts-*" | Format-Table TaskName, State, LastRunTime, NextRunTime
```

**View task history:**
1. Open Task Scheduler (taskschd.msc)
2. Select the task
3. Click the "History" tab

### Uninstallation

To remove all scheduled tasks:

```powershell
# Remove all My-Scripts scheduled tasks
.\scripts\Uninstall-ScheduledTasks.ps1

# Skip confirmation prompt
.\scripts\Uninstall-ScheduledTasks.ps1 -Force

# Preview removal
.\scripts\Uninstall-ScheduledTasks.ps1 -WhatIf
```

### Troubleshooting

**Tasks not running:**
1. Check Task Scheduler Event Log for errors
2. Verify script paths are correct in the XML files
3. Test script manually:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File "C:\path\to\script.ps1"
   ```
4. Ensure required dependencies are installed (PowerShell modules, Python packages, etc.)

**Permission errors:**
1. Run installation script as Administrator
2. Check script execution policy:
   ```powershell
   Get-ExecutionPolicy -List
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

**Tasks exist but won't update:**
- Use `-Force` parameter to overwrite existing tasks:
  ```powershell
  .\scripts\Install-ScheduledTasks.ps1 -Force
  ```

**Task runs but script fails:**
1. Check log files (if script supports logging)
2. Verify environment variables are set correctly
3. Run script interactively to see error messages
4. Check that database connections work (for backup tasks)

## Verification

### Quick Verification Script

For a comprehensive installation check, run the automated verification script:

```powershell
# Windows PowerShell or PowerShell Core
.\scripts\Verify-Installation.ps1

# Or with detailed output
.\scripts\Verify-Installation.ps1 -Verbose
```

**Expected output:**
```
Installation Verification for My-Scripts Repository
==================================================

✅ PowerShell 7.4.0 (Minimum: 5.1.0)
✅ Python 3.11.5 (Minimum: 3.8.0)
✅ Git 2.42.0 (Minimum: 2.30.0)

PowerShell Modules:
✅ PostgresBackup (2.0.0)
✅ PowerShellLoggingFramework (2.0.0)
✅ PurgeLogs (2.0.0)
✅ RandomName (2.1.0)
✅ Videoscreenshot (3.0.2)

Python Packages:
✅ requests
✅ numpy
✅ pandas
✅ opencv-python

Git Hooks:
✅ pre-commit hook configured
✅ commit-msg hook configured
✅ post-commit hook configured

Installation verification complete! ✅
```

### Verify PowerShell Modules

```powershell
# List all installed modules from My-Scripts
Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework,PurgeLogs,RandomName,Videoscreenshot

# Import and test a module
Import-Module PostgresBackup
Get-Command -Module PostgresBackup

# Check module version
(Get-Module -ListAvailable PostgresBackup).Version
```

**Expected output:**
```
ModuleType Version Name                      ExportedCommands
---------- ------- ----                      ----------------
Script     2.0.0   PostgresBackup            Backup-PostgresDatabase
Script     2.0.0   PowerShellLoggingFramework {Initialize-Logger, Write-LogDebug, Write-LogInfo, Write-LogWarning, Write-LogError, Write-LogCritical}
Script     2.0.0   PurgeLogs                 {Clear-LogFile, ConvertTo-Bytes}
Script     2.1.0   RandomName                Get-RandomFileName
Script     3.0.2   Videoscreenshot           Start-VideoBatch
```

### Verify Python Modules

```bash
# Check if module is installed
pip show my-scripts-logging

# Test import
python3 -c "import python_logging_framework; print('python_logging_framework loaded successfully')"

# Check module version
python3 -c "import python_logging_framework; print(python_logging_framework.__version__ if hasattr(python_logging_framework, '__version__') else 'Version info not available')"
```

### Verify Repository Setup

```bash
# Check git hooks are installed
ls -la .git/hooks/

# Verify configuration
cat config/module-deployment-config.txt

# Check repository structure
tree -L 2 -I 'node_modules|.git'
```

## Troubleshooting

### PowerShell Modules Not Found

**Problem**: `Get-Module -ListAvailable ModuleName` returns nothing

**Solutions**:

1. Check module path:
   ```powershell
   $env:PSModulePath -split [System.IO.Path]::PathSeparator
   ```

2. Verify deployment completed successfully:
   ```powershell
   ./scripts/Deploy-Modules.ps1 -Verbose
   ```

3. Check if modules are in the expected location:
   ```powershell
   # Windows
   Get-ChildItem "C:\Program Files\PowerShell\Modules" -Directory

   # Linux/macOS
   ls -la /usr/local/share/powershell/Modules/
   ```

4. Try importing directly by path:
   ```powershell
   Import-Module "C:\Program Files\PowerShell\Modules\PostgresBackup\2.0.0\PostgresBackup.psd1"
   ```

### Permission Denied Errors

**Problem**: "Access denied" or "Permission denied" during installation

**Solutions**:

- **Windows**: Run PowerShell as Administrator
- **Linux/macOS**: Use `sudo` for system-wide installation:
  ```bash
  sudo ./scripts/install-modules.sh --force
  ```
- **Alternative**: Install to user directory by editing `config/module-deployment-config.txt` and changing `System` to `User`

### Python Module Import Fails

**Problem**: `ModuleNotFoundError: No module named 'python_logging_framework'`

**Solutions**:

1. Verify installation:
   ```bash
   pip show my-scripts-logging
   ```

2. Reinstall:
   ```bash
   pip uninstall my-scripts-logging
   pip install -e .
   ```

3. Check Python path:
   ```python
   import sys
   print('\n'.join(sys.path))
   ```

4. Verify you're using the correct Python:
   ```bash
   which python3
   pip3 --version
   ```

### Git Hooks Not Working

**Problem**: Hooks don't run on commit/push

**Solutions**:

1. Verify hooks are executable:
   ```bash
   chmod +x .git/hooks/*
   ```

2. Reinstall hooks:
   ```bash
   ./scripts/install-hooks.sh
   ```

3. Check hook scripts exist:
   ```bash
   ls -la .git/hooks/
   ```

### Manifest Validation Fails

**Problem**: `Test-ModuleManifest` reports errors

**Solutions**:

1. Validate manifest syntax:
   ```powershell
   Test-ModuleManifest -Path src/common/ModuleName.psd1
   ```

2. Check for common issues:
   - Invalid GUID format
   - Missing or incorrect RootModule path
   - Mismatched FunctionsToExport

3. Regenerate GUID if needed:
   ```powershell
   [guid]::NewGuid()
   ```

### VLC Not Found (Videoscreenshot Module)

**Problem**: `VLC not found on PATH` when using Videoscreenshot module

**Solutions**:

1. **Windows - Add VLC to PATH:**
   ```powershell
   # Temporary (current session)
   $env:Path += ";C:\Program Files\VideoLAN\VLC"

   # Permanent (as Administrator)
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\VideoLAN\VLC", "Machine")
   ```

2. **Or specify VLC path directly in script:**
   ```powershell
   Start-VideoBatch -VlcPath "C:\Program Files\VideoLAN\VLC\vlc.exe"
   ```

3. **Linux/macOS - Verify VLC is installed:**
   ```bash
   which vlc
   # If not found, install VLC (see Optional Software Installation section)
   ```

### PostgreSQL Connection Fails

**Problem**: `could not connect to server` when running database backup scripts

**Solutions**:

1. **Verify PostgreSQL is running:**
   ```bash
   # Linux
   sudo systemctl status postgresql

   # macOS
   brew services list | grep postgresql

   # Windows (PowerShell as Administrator)
   Get-Service -Name postgresql*
   ```

2. **Check connection parameters:**
   ```bash
   # Test connection manually
   psql -h localhost -U your-username -d postgres
   ```

3. **Verify environment variables:**
   ```powershell
   # Windows PowerShell
   Write-Host "PGHOST: $env:PGHOST"
   Write-Host "PGPORT: $env:PGPORT"
   Write-Host "PGUSER: $env:PGUSER"

   # Linux/macOS
   echo "PGHOST: $PGHOST"
   echo "PGPORT: $PGPORT"
   echo "PGUSER: $PGUSER"
   ```

4. **Use .pgpass file for credentials (recommended):**
   ```bash
   # Create ~/.pgpass file
   echo "localhost:5432:*:your-username:your-password" > ~/.pgpass
   chmod 600 ~/.pgpass
   ```

### PowerShell Execution Policy Error

**Problem**: `File cannot be loaded because running scripts is disabled on this system`

**Solutions**:

1. **Check current execution policy:**
   ```powershell
   Get-ExecutionPolicy -List
   ```

2. **Set execution policy for current user:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Or bypass for a specific script (not recommended for regular use):**
   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Deploy-Modules.ps1
   ```

### psycopg2 Installation Fails

**Problem**: `Error: pg_config executable not found` when installing psycopg2

**Solutions**:

1. **Ubuntu/Debian:**
   ```bash
   sudo apt-get install libpq-dev python3-dev
   pip install psycopg2
   ```

2. **Fedora/RHEL/CentOS:**
   ```bash
   sudo yum install postgresql-devel python3-devel
   pip install psycopg2
   ```

3. **macOS:**
   ```bash
   brew install postgresql
   pip install psycopg2
   ```

4. **Alternative - Use binary package (easier but not recommended for production):**
   ```bash
   pip install psycopg2-binary
   ```

### opencv-python Installation Fails

**Problem**: `ERROR: Could not build wheels for opencv-python`

**Solutions**:

1. **Install system dependencies first:**

   **Ubuntu/Debian:**
   ```bash
   sudo apt-get update
   sudo apt-get install python3-opencv
   # Or install build dependencies
   sudo apt-get install build-essential cmake python3-dev
   ```

   **Fedora/RHEL/CentOS:**
   ```bash
   sudo yum install python3-opencv
   ```

   **macOS:**
   ```bash
   brew install opencv
   ```

2. **Then install Python package:**
   ```bash
   pip install opencv-python
   ```

3. **Or use pre-built wheel:**
   ```bash
   pip install opencv-python-headless  # Headless version (no GUI support)
   ```

## Uninstallation

### Remove PowerShell Modules

```powershell
# Remove all My-Scripts modules
$modules = @('PostgresBackup', 'PowerShellLoggingFramework', 'PurgeLogs', 'RandomName', 'Videoscreenshot')

foreach ($module in $modules) {
    $modulePath = Get-Module -ListAvailable -Name $module | Select-Object -First 1 -ExpandProperty ModuleBase
    if ($modulePath) {
        $parentPath = Split-Path -Parent $modulePath
        Remove-Item -Path $parentPath -Recurse -Force
        Write-Host "Removed $module from $parentPath"
    }
}
```

### Remove Python Modules

```bash
pip uninstall my-scripts-logging
```

### Remove Git Hooks

```bash
# Linux/macOS/Git Bash
rm .git/hooks/pre-commit
rm .git/hooks/commit-msg
rm .git/hooks/post-commit
rm .git/hooks/post-merge

# Or remove all hooks
rm .git/hooks/*
```

### Remove Repository

```bash
# Navigate to parent directory
cd ..

# Remove repository
rm -rf My-Scripts
```

## Next Steps

After installation:

1. **Explore the scripts**: Browse `src/` directory for available scripts
2. **Read the documentation**: Check `docs/` for guides and specifications
3. **Review examples**: Look at existing scripts for usage patterns
4. **Test a module**: Try importing and using a module in your own script
5. **Read the module deployment guide**: See [docs/guides/module-deployment.md](docs/guides/module-deployment.md)

## Additional Resources

- [README.md](README.md) - Repository overview and features
- [Configuration Guide](config/CONFIG_GUIDE.md) - Comprehensive configuration guide
- [Module Deployment Guide](docs/guides/module-deployment.md) - Comprehensive module documentation
- [Git Hooks Guide](docs/guides/git-hooks.md) - Git hooks documentation
- [Logging Specification](docs/logging_specification.md) - Logging framework details
- [CONTRIBUTING.md](CONTRIBUTING.md) - Coding standards and guidelines

## Support

For issues or questions:

1. Check this installation guide and troubleshooting section
2. Review the [module deployment guide](docs/guides/module-deployment.md)
3. Search existing [GitHub issues](https://github.com/manoj-bhaskaran/My-Scripts/issues)
4. Open a new issue if your problem isn't covered
