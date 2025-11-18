# Module Deployment Guide

This guide explains how the module deployment system works in the My-Scripts repository, how to use it, and how to add new modules.

## Table of Contents

- [Overview](#overview)
- [Available Modules](#available-modules)
- [Installation](#installation)
  - [Automated Installation (Recommended)](#automated-installation-recommended)
  - [Manual PowerShell Module Deployment](#manual-powershell-module-deployment)
  - [Manual Python Module Installation](#manual-python-module-installation)
- [How Module Deployment Works](#how-module-deployment-works)
- [Module Deployment Configuration](#module-deployment-configuration)
- [Adding New Modules](#adding-new-modules)
- [Module Versioning](#module-versioning)
- [Publishing to Galleries](#publishing-to-galleries-optional)
- [Troubleshooting](#troubleshooting)

## Overview

The My-Scripts repository contains reusable PowerShell and Python modules that can be installed to your system's module paths for easy access across scripts. The deployment system automates the installation process and ensures modules are properly configured with manifests and metadata.

### Benefits

- **No manual path management**: Modules are installed to standard locations
- **Version control**: Each module has a manifest with version information
- **Standardized deployment**: Consistent installation across all environments
- **Automated validation**: CI/CD pipelines ensure modules are always valid
- **Cross-platform support**: Works on Windows, Linux, and macOS

## Available Modules

### PowerShell Modules

| Module | Version | Description | Key Functions |
|--------|---------|-------------|---------------|
| **PostgresBackup** | 2.0.0 | PostgreSQL database backup with retention management | `Backup-PostgresDatabase` |
| **PowerShellLoggingFramework** | 2.0.0 | Cross-platform structured logging | `Initialize-Logger`, `Write-LogInfo`, `Write-LogError`, etc. |
| **PurgeLogs** | 2.0.0 | Log file purging and retention management | `Clear-LogFile`, `ConvertTo-Bytes` |
| **RandomName** | 2.1.0 | Windows-safe random filename generation | `Get-RandomFileName` |
| **Videoscreenshot** | 3.0.2 | Video frame capture via VLC or GDI+ | `Start-VideoBatch` |

### Python Modules

| Module | Version | Description | Package Name |
|--------|---------|-------------|--------------|
| **python_logging_framework** | 0.2.0 | Cross-platform structured logging for Python | `my-scripts-logging` |

## Installation

### Automated Installation (Recommended)

The easiest way to install all modules is using the cross-platform installer:

```bash
# Install all modules (PowerShell + Python)
./scripts/install-modules.sh

# Force overwrite existing modules
./scripts/install-modules.sh --force

# Install only PowerShell modules
./scripts/install-modules.sh --powershell-only

# Install only Python modules
./scripts/install-modules.sh --python-only
```

**Windows users** can run the same script in Git Bash or WSL, or use PowerShell directly:

```powershell
# PowerShell only
./scripts/Deploy-Modules.ps1 -Force

# Python only
pip install -e .
```

### Manual PowerShell Module Deployment

To manually deploy PowerShell modules:

```powershell
# Deploy all configured modules
./scripts/Deploy-Modules.ps1

# Deploy with force (overwrite existing)
./scripts/Deploy-Modules.ps1 -Force

# Dry run (see what would be deployed)
./scripts/Deploy-Modules.ps1 -WhatIf

# Use custom config file
./scripts/Deploy-Modules.ps1 -ConfigPath "path/to/config.txt"
```

The deployment script will:

1. Read the configuration from `config/module-deployment-config.txt`
2. Validate each module manifest (`.psd1`)
3. Copy modules to the appropriate target locations
4. Create version-specific directories (e.g., `PostgresBackup/2.0.0/`)
5. Report deployment status

**Default deployment locations:**

- **Windows (PowerShell 5.1)**: `C:\Program Files\WindowsPowerShell\Modules\`
- **Windows (PowerShell Core)**: `C:\Program Files\PowerShell\Modules\`
- **Linux/macOS**: `/usr/local/share/powershell/Modules/`

### Manual Python Module Installation

To manually install the Python logging framework:

```bash
# Development installation (editable mode - recommended)
pip install -e .

# Standard installation
pip install .

# Uninstall
pip uninstall my-scripts-logging
```

After installation, you can use it in any Python script:

```python
import python_logging_framework

# Your code here
```

## How Module Deployment Works

### PowerShell Module Deployment

1. **Configuration**: Modules are defined in `config/module-deployment-config.txt`
2. **Manifest Validation**: Each module must have a `.psd1` manifest file
3. **Version Resolution**: The manifest version determines the deployment directory
4. **File Copying**: Module files are copied to `<ModulePath>/<ModuleName>/<Version>/`
5. **Auto-discovery**: PowerShell automatically finds modules in standard paths

### Python Module Installation

1. **setup.py Configuration**: The `setup.py` file defines the module metadata
2. **Editable Installation**: Using `pip install -e .` creates a link to the source
3. **Site-packages**: The module becomes available system-wide via Python's import system

## Module Deployment Configuration

The configuration file `config/module-deployment-config.txt` uses a pipe-delimited format:

```
ModuleName | RelativePathFromRepoRoot | Targets | [Author] | [Description]
```

### Configuration Fields

1. **ModuleName** (required): Name of the module
2. **RelativePathFromRepoRoot** (required): Path to the module source
   - For directory modules: `src/powershell/module/ModuleName`
   - For single-file modules: `src/common/ModuleName.psm1`
3. **Targets** (required): Comma-separated deployment targets
   - `System`: Deploy to system-wide module path
   - `User`: Deploy to user-specific module path
   - `Alt:<path>`: Deploy to custom absolute path
4. **Author** (optional): Module author (defaults to `$env:USERNAME`)
5. **Description** (optional): Module description (defaults to "PowerShell module")

### Configuration Examples

```powershell
# System-wide deployment with full metadata
PostgresBackup|src\common\PostgresBackup.psm1|System|Manoj Bhaskaran|PostgreSQL database backup module

# Multiple targets
MyModule|src\common\MyModule.psm1|System,User|Author Name|My custom module

# Custom deployment path
CustomModule|Modules\Custom\Custom.psm1|Alt:D:\Tools\PSModules|Team Name|Custom tooling

# Minimal configuration (3 fields)
SimpleModule|src\common\SimpleModule.psm1|System
```

### Current Configuration

See `config/module-deployment-config.txt` for the active module configuration.

## Adding New Modules

### Adding a PowerShell Module

#### Step 1: Create the Module File

Create your module file (e.g., `src/common/MyModule.psm1`):

```powershell
function Get-MyData {
    <#
    .SYNOPSIS
        Gets data from somewhere.
    #>
    param([string]$Source)

    # Your implementation
}

Export-ModuleMember -Function Get-MyData
```

#### Step 2: Create the Module Manifest

Create a manifest file (e.g., `src/common/MyModule.psd1`):

```powershell
@{
    RootModule        = 'MyModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'YOUR-UNIQUE-GUID-HERE'  # Generate with: [guid]::NewGuid()
    Author            = 'Your Name'
    CompanyName       = ''
    Description       = 'Description of your module'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-MyData')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('tag1','tag2')
            ProjectUri   = ''
            ReleaseNotes = '1.0.0: Initial release'
        }
    }
}
```

**Generate a GUID:**

```powershell
[guid]::NewGuid()
```

#### Step 3: Validate the Manifest

```powershell
Test-ModuleManifest -Path src/common/MyModule.psd1
```

#### Step 4: Add to Deployment Configuration

Add a line to `config/module-deployment-config.txt`:

```
MyModule|src\common\MyModule.psm1|System|Your Name|Description of your module
```

#### Step 5: Deploy and Test

```powershell
# Deploy the module
./scripts/Deploy-Modules.ps1 -Force

# Verify it's available
Get-Module -ListAvailable MyModule

# Import and test
Import-Module MyModule
Get-MyData -Source "test"
```

### Adding a Python Module

#### Step 1: Create the Module

Create your module file (e.g., `src/common/my_new_module.py`)

#### Step 2: Update setup.py

Add your module to the `py_modules` list in `setup.py`:

```python
py_modules=['python_logging_framework', 'my_new_module'],
```

Or if it's a package (directory with `__init__.py`):

```python
packages=['python_logging_framework', 'my_new_package'],
```

#### Step 3: Install and Test

```bash
# Install in editable mode
pip install -e .

# Test import
python3 -c "import my_new_module; print('OK')"
```

## Module Versioning

### Version Strategy

- **Major version changes**: Breaking API changes
- **Minor version changes**: New features, backward compatible
- **Patch version changes**: Bug fixes

### Repository Alignment

- Core modules (PostgresBackup, PowerShellLoggingFramework, PurgeLogs) track the repository version (currently 2.0.0)
- Standalone modules (RandomName, Videoscreenshot) maintain independent versions
- Python module (python_logging_framework) uses independent versioning (currently 0.2.0)

### Updating Module Versions

#### PowerShell Module

1. Update the `ModuleVersion` in the `.psd1` manifest
2. Update the `ReleaseNotes` in the manifest
3. Redeploy the module

#### Python Module

1. Update the `version` in `setup.py`
2. Reinstall: `pip install -e . --force-reinstall`

## Publishing to Galleries (Optional)

### Publishing to PowerShell Gallery

1. **Create an account** at [PowerShellGallery.com](https://www.powershellgallery.com/)
2. **Get your API key** from your account settings
3. **Publish the module:**

```powershell
# First time: Register the repository
Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/

# Publish the module
Publish-Module -Path "C:\Program Files\PowerShell\Modules\MyModule\1.0.0" `
               -NuGetApiKey "YOUR-API-KEY" `
               -Repository PSGallery
```

### Publishing to PyPI

1. **Create an account** at [PyPI.org](https://pypi.org/)
2. **Install build tools:**

```bash
pip install build twine
```

3. **Build and publish:**

```bash
# Build distribution packages
python -m build

# Upload to PyPI
python -m twine upload dist/*
```

## Troubleshooting

### Module Not Found After Deployment

**Problem**: `Get-Module -ListAvailable MyModule` returns nothing

**Solutions**:

1. Check if the module was deployed to the correct path:
   ```powershell
   $env:PSModulePath -split [System.IO.Path]::PathSeparator
   ```

2. Verify the deployment completed successfully:
   ```powershell
   ./scripts/Deploy-Modules.ps1 -Verbose
   ```

3. Check for errors in the manifest:
   ```powershell
   Test-ModuleManifest -Path src/common/MyModule.psd1
   ```

### Permission Denied During Deployment

**Problem**: Cannot write to system module path

**Solutions**:

- **Windows**: Run PowerShell as Administrator
- **Linux/macOS**: Use `sudo` or deploy to user path instead:

  ```powershell
  # Change target from System to User in config file
  MyModule|src\common\MyModule.psm1|User|Author|Description
  ```

### Python Module Import Fails

**Problem**: `ModuleNotFoundError: No module named 'python_logging_framework'`

**Solutions**:

1. Verify installation:
   ```bash
   pip show my-scripts-logging
   ```

2. Reinstall in editable mode:
   ```bash
   pip uninstall my-scripts-logging
   pip install -e .
   ```

3. Check Python path:
   ```python
   import sys
   print(sys.path)
   ```

### Manifest Validation Fails

**Problem**: `Test-ModuleManifest` reports errors

**Common Issues**:

1. **Invalid GUID format**: Use `[guid]::NewGuid()` to generate
2. **Missing RootModule**: Ensure `RootModule` points to the `.psm1` file
3. **Incorrect function exports**: Verify `FunctionsToExport` matches actual exports
4. **Path issues**: Use relative paths in manifest files

### CI/CD Pipeline Failures

**Problem**: GitHub Actions workflow fails during module validation

**Solutions**:

1. Check the workflow logs for specific errors
2. Validate manifests locally before pushing:
   ```powershell
   Get-ChildItem -Recurse -Filter *.psd1 | ForEach-Object {
       Test-ModuleManifest $_.FullName
   }
   ```

3. Ensure all modules in the config file have valid source paths

## Additional Resources

- [PowerShell Module Documentation](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Python Packaging Guide](https://packaging.python.org/)
- [PyPI](https://pypi.org/)

## Support

For issues or questions:

1. Check this guide and troubleshooting section
2. Review existing module examples in the repository
3. Open an issue on the GitHub repository
