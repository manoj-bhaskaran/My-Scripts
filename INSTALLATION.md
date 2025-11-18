# Installation Guide

This guide provides comprehensive instructions for setting up and installing the My-Scripts repository and its modules.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Repository Setup](#repository-setup)
- [Module Installation](#module-installation)
- [Platform-Specific Instructions](#platform-specific-instructions)
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
- **PostgreSQL** - Required for database backup scripts
- **VLC Media Player** - Required for Videoscreenshot module
- **Image processing libraries** - Required for certain Python scripts (PIL, OpenCV)

### Permissions

- **Windows**: Administrator privileges for system-wide module installation
- **Linux/macOS**: `sudo` access for system-wide installation (or use user-level installation)

## Repository Setup

### 1. Clone the Repository

```bash
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts
```

### 2. Install Git Hooks (Optional but Recommended)

Git hooks enforce code quality and consistent commit messages:

```bash
# Linux/macOS/Git Bash
./scripts/install-hooks.sh

# Windows PowerShell
pwsh -File scripts/install-hooks.ps1
```

This installs:
- `pre-commit`: Code quality checks (linting, debug statements)
- `commit-msg`: Conventional commits format enforcement
- `post-commit`: Automatic module deployment to staging
- `post-merge`: Post-merge automation

See [docs/guides/git-hooks.md](docs/guides/git-hooks.md) for details.

### 3. Review Configuration

Check the module deployment configuration:

```bash
cat config/module-deployment-config.txt
```

This file controls which modules are deployed and where they go.

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

## Verification

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
