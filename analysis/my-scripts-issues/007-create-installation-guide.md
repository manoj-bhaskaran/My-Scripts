# Create Comprehensive Installation Guide

## Priority
**MODERATE** 🟡

## Background
The My-Scripts repository currently has **insufficient installation documentation**:

**Current State:**
- README.md lists prerequisites (PowerShell 5.1+, Python 3+, Git)
- No step-by-step installation instructions
- No dependency installation guidance
- No environment setup instructions
- No module deployment instructions
- No troubleshooting for common setup issues

**Impact:**
- Difficult to set up in new environments
- Time-consuming to configure from scratch
- Risk of missing dependencies
- No standardized setup process

This is particularly problematic for:
- Setting up new development machines
- Sharing repository with others (future collaboration)
- Disaster recovery scenarios

## Objectives
- Create comprehensive `INSTALLATION.md` guide
- Document all prerequisites and dependencies
- Provide step-by-step setup instructions
- Include platform-specific guidance (Windows, Linux, macOS)
- Document module installation process
- Add troubleshooting section

## Tasks

### Phase 1: Document Prerequisites
- [ ] Create `INSTALLATION.md` at repository root
- [ ] List all system requirements:
  ```markdown
  ## Prerequisites

  ### Required Software
  - **PowerShell**: 5.1+ (Windows) or PowerShell 7+ (cross-platform)
  - **Python**: 3.8+ (3.11+ recommended)
  - **Git**: 2.30+

  ### Optional Software (for specific scripts)
  - **VLC Media Player**: Required for Videoscreenshot module
  - **ADB (Android Debug Bridge)**: Required for Copy-AndroidFiles.ps1
  - **PostgreSQL Client**: Required for database backup scripts
  - **CloudConvert API Key**: Required for cloudconvert_utils.py
  - **Google Cloud Project**: Required for Google Drive scripts

  ### Operating System Support
  - **Windows 10/11**: Full support (primary platform)
  - **Linux**: Partial support (Python scripts, PowerShell Core scripts)
  - **macOS**: Partial support (Python scripts, PowerShell Core scripts)
  ```

### Phase 2: Write Installation Instructions

**Windows Installation:**
- [ ] Document PowerShell installation:
  ```markdown
  ## Windows Installation

  ### 1. Verify PowerShell Version
  ```powershell
  $PSVersionTable.PSVersion
  # Should be 5.1+ or 7+
  ```

  ### 2. Clone Repository
  ```powershell
  git clone https://github.com/manoj-bhaskaran/My-Scripts.git
  cd My-Scripts
  ```

  ### 3. Install Python Dependencies
  ```powershell
  pip install -r requirements.txt
  ```

  ### 4. Install PowerShell Modules
  ```powershell
  .\scripts\Deploy-Modules.ps1 -Force
  ```

  ### 5. Install Git Hooks
  ```powershell
  .\scripts\install-hooks.sh  # or use bash/pwsh equivalent
  ```

  ### 6. Verify Installation
  ```powershell
  # Test PowerShell modules
  Import-Module PostgresBackup
  Import-Module RandomName
  Import-Module Videoscreenshot

  # Test Python modules
  python -c "import python_logging_framework"
  ```
  ```

**Linux Installation:**
- [ ] Document PowerShell Core installation:
  ```markdown
  ## Linux Installation

  ### 1. Install PowerShell Core
  ```bash
  # Ubuntu/Debian
  wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y powershell

  # Or use snap
  sudo snap install powershell --classic
  ```

  ### 2. Install Python 3.8+
  ```bash
  sudo apt-get install python3 python3-pip
  ```

  ### 3. Clone and Setup
  ```bash
  git clone https://github.com/manoj-bhaskaran/My-Scripts.git
  cd My-Scripts
  pip3 install -r requirements.txt
  pwsh -Command "./scripts/Deploy-Modules.ps1 -Force"
  ./scripts/install-hooks.sh
  ```
  ```

**macOS Installation:**
- [ ] Document macOS-specific steps:
  ```markdown
  ## macOS Installation

  ### 1. Install Homebrew (if not installed)
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

  ### 2. Install PowerShell and Python
  ```bash
  brew install --cask powershell
  brew install python@3.11
  ```

  ### 3. Clone and Setup
  ```bash
  git clone https://github.com/manoj-bhaskaran/My-Scripts.git
  cd My-Scripts
  pip3 install -r requirements.txt
  pwsh -Command "./scripts/Deploy-Modules.ps1 -Force"
  ./scripts/install-hooks.sh
  ```
  ```

### Phase 3: Document Optional Dependencies

- [ ] Create section for optional software:
  ```markdown
  ## Optional Software Installation

  ### VLC Media Player (for Videoscreenshot module)
  **Windows:**
  - Download from https://www.videolan.org/vlc/
  - Add to PATH: `C:\Program Files\VideoLAN\VLC`

  **Linux:**
  ```bash
  sudo apt-get install vlc
  ```

  **macOS:**
  ```bash
  brew install --cask vlc
  ```

  ### ADB (for Android file operations)
  **Windows:**
  - Install Android SDK Platform Tools
  - Add to PATH

  **Linux:**
  ```bash
  sudo apt-get install android-tools-adb
  ```

  ### PostgreSQL Client (for database backups)
  **Windows:**
  - Download from https://www.postgresql.org/download/windows/
  - Install client tools only

  **Linux:**
  ```bash
  sudo apt-get install postgresql-client
  ```
  ```

### Phase 4: Document Environment Configuration

- [ ] Add environment variables section:
  ```markdown
  ## Environment Configuration

  ### Required Environment Variables (for specific scripts)

  **Google Drive Scripts:**
  ```bash
  export GOOGLE_CLIENT_ID="your-client-id"
  export GOOGLE_CLIENT_SECRET="your-client-secret"
  ```

  **CloudConvert Scripts:**
  ```bash
  export CLOUDCONVERT_API_KEY="your-api-key"
  ```

  **Database Backups:**
  ```bash
  export PGHOST="localhost"
  export PGPORT="5432"
  export PGUSER="your-username"
  export PGPASSWORD="your-password"  # or use .pgpass file
  ```

  ### Configuration Files
  - `config/modules/deployment.txt` – Module deployment targets
  - `config/tasks/*.xml` – Windows Task Scheduler definitions
  - `.vscode/settings.json` – Editor configuration (optional)
  ```

### Phase 5: Add Module Installation Details

- [ ] Document module installation process:
  ```markdown
  ## Module Installation

  ### PowerShell Modules
  The repository includes several reusable PowerShell modules:
  - **PostgresBackup** – Database backup utilities
  - **PowerShellLoggingFramework** – Structured logging
  - **PurgeLogs** – Log retention management
  - **RandomName** – Windows-safe filename generation
  - **Videoscreenshot** – Video capture and screenshot utilities

  **Automated Installation:**
  ```powershell
  .\scripts\Deploy-Modules.ps1 -Force
  ```

  **Manual Installation:**
  ```powershell
  # Find your module path
  $env:PSModulePath -split ';' | Select-Object -First 1

  # Copy modules manually
  Copy-Item -Path src/powershell/modules/Database/PostgresBackup -Destination $modulePath -Recurse
  # Repeat for other modules
  ```

  **Verification:**
  ```powershell
  Get-Module -ListAvailable PostgresBackup
  Import-Module PostgresBackup -Verbose
  ```

  ### Python Modules
  **python_logging_framework:**
  ```bash
  # Development install (editable)
  pip install -e src/python/modules/logging

  # Or: Install to site-packages
  pip install src/python/modules/logging
  ```

  **Verification:**
  ```python
  import python_logging_framework
  print(python_logging_framework.__version__)
  ```
  ```

### Phase 6: Add Verification Steps

- [ ] Create comprehensive verification section:
  ```markdown
  ## Installation Verification

  ### Quick Verification Script
  **PowerShell:**
  ```powershell
  # Run verification script
  .\scripts\Verify-Installation.ps1
  ```

  **Expected Output:**
  - ✅ PowerShell version: X.Y.Z
  - ✅ Python version: X.Y.Z
  - ✅ Git version: X.Y.Z
  - ✅ Required Python packages installed
  - ✅ PowerShell modules available
  - ✅ Git hooks configured

  ### Manual Verification
  ```powershell
  # Check PowerShell modules
  Get-Module -ListAvailable | Where-Object {$_.Name -in @('PostgresBackup', 'RandomName', 'Videoscreenshot')}

  # Check Python packages
  pip list | Select-String -Pattern "requests|numpy|pandas|opencv"

  # Check git hooks
  Test-Path .git/hooks/pre-commit
  Test-Path .git/hooks/post-commit
  ```
  ```

### Phase 7: Add Troubleshooting Section

- [ ] Document common issues:
  ```markdown
  ## Troubleshooting

  ### PowerShell Execution Policy Error
  **Error:** `cannot be loaded because running scripts is disabled`

  **Solution:**
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

  ### Module Import Fails
  **Error:** `The specified module 'ModuleName' was not loaded`

  **Solution:**
  1. Verify module deployed: `Get-Module -ListAvailable ModuleName`
  2. Check PSModulePath: `$env:PSModulePath`
  3. Redeploy: `.\scripts\Deploy-Modules.ps1 -Force`

  ### Python Package Installation Fails
  **Error:** `pip: command not found` or `No module named 'X'`

  **Solution:**
  ```bash
  # Ensure pip is installed
  python -m ensurepip --upgrade

  # Install packages
  python -m pip install -r requirements.txt
  ```

  ### VLC Not Found (Videoscreenshot)
  **Error:** `VLC not found on PATH`

  **Solution:**
  - Add VLC to PATH: `C:\Program Files\VideoLAN\VLC` (Windows)
  - Or specify path: `Start-VideoBatch -VlcPath "C:\path\to\vlc.exe"`

  ### PostgreSQL Connection Fails
  **Error:** `could not connect to server`

  **Solution:**
  1. Verify PostgreSQL is running
  2. Check connection parameters (host, port, user)
  3. Verify credentials in environment variables or .pgpass

  ### Git Hooks Not Running
  **Error:** Hooks don't execute on commit/push

  **Solution:**
  1. Verify hooks are executable: `ls -la .git/hooks/`
  2. Run installation script: `./scripts/install-hooks.sh`
  3. Test manually: `.git/hooks/pre-commit`
  ```

### Phase 8: Create Verification Script

- [ ] Create `scripts/Verify-Installation.ps1`:
  ```powershell
  <#
  .SYNOPSIS
      Verifies My-Scripts installation completeness

  .DESCRIPTION
      Checks prerequisites, dependencies, modules, and configuration
      to ensure the My-Scripts repository is properly installed.
  #>
  [CmdletBinding()]
  param()

  function Test-Prerequisite {
      param($Name, $Command, $MinVersion)
      # ... check if software exists and meets version requirement
  }

  # Check PowerShell
  Test-Prerequisite -Name "PowerShell" -MinVersion "5.1.0"

  # Check Python
  Test-Prerequisite -Name "Python" -Command "python --version" -MinVersion "3.8.0"

  # Check Git
  Test-Prerequisite -Name "Git" -Command "git --version" -MinVersion "2.30.0"

  # Check PowerShell modules
  $modules = @('PostgresBackup', 'RandomName', 'Videoscreenshot')
  foreach ($module in $modules) {
      if (Get-Module -ListAvailable $module) {
          Write-Host "✅ $module module available" -ForegroundColor Green
      } else {
          Write-Warning "❌ $module module not found"
      }
  }

  # Check Python packages
  $packages = @('requests', 'numpy', 'pandas', 'opencv-python')
  foreach ($package in $packages) {
      # ... check if package installed
  }

  # Check git hooks
  if (Test-Path .git/hooks/pre-commit) {
      Write-Host "✅ Git hooks configured" -ForegroundColor Green
  } else {
      Write-Warning "❌ Git hooks not configured"
  }

  Write-Host "`nInstallation verification complete!"
  ```

### Phase 9: Update README.md

- [ ] Add installation section to README.md:
  ```markdown
  ## Installation

  For detailed installation instructions, see [INSTALLATION.md](INSTALLATION.md).

  **Quick Start:**
  1. Clone repository: `git clone https://github.com/manoj-bhaskaran/My-Scripts.git`
  2. Install dependencies: `pip install -r requirements.txt`
  3. Deploy modules: `.\scripts\Deploy-Modules.ps1`
  4. Install hooks: `.\scripts\install-hooks.sh`
  5. Verify: `.\scripts\Verify-Installation.ps1`
  ```

## Acceptance Criteria
- [x] `INSTALLATION.md` created at repository root
- [x] Installation instructions for Windows, Linux, macOS
- [x] All prerequisites documented with version requirements
- [x] Dependency installation steps included
- [x] Module installation process documented
- [x] Environment configuration section included
- [x] Verification steps documented
- [x] Troubleshooting section with common issues (minimum 5 issues)
- [x] `scripts/Verify-Installation.ps1` created and functional
- [x] README.md updated with link to installation guide
- [x] Installation tested on at least one clean environment

## Related Files
- `INSTALLATION.md` (to be created)
- `scripts/Verify-Installation.ps1` (to be created)
- `README.md` (to be updated)
- `requirements.txt` (exists)
- `scripts/Deploy-Modules.ps1` (from Issue #005)
- `scripts/install-hooks.sh` (from Issue #004)

## Estimated Effort
**1-2 days** (documentation, verification script, testing)

## Dependencies
- Issue #004 (Git Hooks) – for hook installation instructions
- Issue #005 (Module Deployment) – for module installation instructions

## Testing
- [ ] Test installation on clean Windows VM
- [ ] Test installation on clean Linux VM (optional)
- [ ] Verify all links in INSTALLATION.md work
- [ ] Verify all code blocks execute without errors
- [ ] Test verification script catches missing dependencies

## References
- [PowerShell Installation](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- [Python Installation](https://www.python.org/downloads/)
- [Git Installation](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
