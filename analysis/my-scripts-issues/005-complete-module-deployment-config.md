# Complete Module Deployment Configuration

## Priority
**MODERATE** 🟡

## Background
The My-Scripts repository has a module deployment framework but it's **incomplete**:

**Current State:**
- `config/module-deployment-config.txt` exists
- **Only 1 of 6 modules configured** (PostgresBackup)
- Other modules require manual installation:
  - `RandomName` (v2.1.0)
  - `Videoscreenshot` (v3.0.1)
  - `PowerShellLoggingFramework`
  - `PurgeLogs`
  - `python_logging_framework` (Python, has setup.py but not deployed)

**Impact:**
- Modules must be manually imported with full paths
- No standardized deployment process
- Difficult to share modules across scripts
- Users must know module locations
- No automatic module updates

## Objectives
- Configure all PowerShell modules for PSModulePath deployment
- Complete `config/module-deployment-config.txt` for all modules
- Create automated deployment script
- Document module installation process
- Optionally: Publish modules to PowerShell Gallery / PyPI

## Tasks

### Phase 1: Inventory Modules
- [ ] List all PowerShell modules:
  ```
  1. PostgresBackup (src/common/PostgresBackup.psm1) ✅ Configured
  2. RandomName (src/powershell/module/RandomName/)
  3. Videoscreenshot (src/powershell/module/Videoscreenshot/)
  4. PowerShellLoggingFramework (src/common/PowerShellLoggingFramework.psm1)
  5. PurgeLogs (src/common/PurgeLogs.psm1)
  ```
- [ ] List all Python modules:
  ```
  1. python_logging_framework (src/common/python_logging_framework.py)
     - Has setup.py ✅
     - Not installed to site-packages
  ```
- [ ] Verify each module has proper manifest/metadata:
  - PowerShell: `.psd1` manifest files
  - Python: `setup.py` or `pyproject.toml`

### Phase 2: Create Missing Module Manifests
- [ ] Create `PowerShellLoggingFramework.psd1`:
  ```powershell
  @{
      ModuleVersion = '1.0.0'
      RootModule = 'PowerShellLoggingFramework.psm1'
      Description = 'Cross-platform structured logging framework'
      Author = 'Your Name'
      FunctionsToExport = @('Write-Log', 'Initialize-Logger', ...)
      RequiredModules = @()
  }
  ```
- [ ] Create `PurgeLogs.psd1`:
  ```powershell
  @{
      ModuleVersion = '1.0.0'
      RootModule = 'PurgeLogs.psm1'
      Description = 'Log file purging and retention management'
      Author = 'Your Name'
      FunctionsToExport = @('Remove-OldLogs', 'Get-LogRetentionPolicy', ...)
      RequiredModules = @()
  }
  ```
- [ ] Verify existing manifests are complete:
  - `RandomName.psd1` (exists, check completeness)
  - `Videoscreenshot.psd1` (exists, check completeness)
  - `PostgresBackup` (may need manifest creation if missing)

### Phase 3: Update Module Deployment Configuration
- [ ] Read `config/module-deployment-config.txt` to understand format
- [ ] Add all modules to configuration:
  ```txt
  # Module Deployment Configuration
  # Format: ModuleName|SourcePath|TargetPath|DeploymentType

  PostgresBackup|src/common/PostgresBackup.psm1|$PSModulePath/PostgresBackup|Copy
  PowerShellLoggingFramework|src/common/PowerShellLoggingFramework.psm1|$PSModulePath/PowerShellLoggingFramework|Copy
  PurgeLogs|src/common/PurgeLogs.psm1|$PSModulePath/PurgeLogs|Copy
  RandomName|src/powershell/module/RandomName|$PSModulePath/RandomName|Copy
  Videoscreenshot|src/powershell/module/Videoscreenshot|$PSModulePath/Videoscreenshot|Copy
  ```
- [ ] Document configuration format in header comments

### Phase 4: Create Automated Deployment Script
- [ ] Create `scripts/Deploy-Modules.ps1`:
  ```powershell
  <#
  .SYNOPSIS
      Deploys PowerShell modules to PSModulePath

  .DESCRIPTION
      Reads config/module-deployment-config.txt and deploys all
      configured modules to the user's PowerShell module path.
      Validates module manifests before deployment.

  .PARAMETER Force
      Overwrite existing modules without prompting

  .EXAMPLE
      .\Deploy-Modules.ps1 -Force
  #>
  [CmdletBinding()]
  param(
      [switch]$Force
  )

  # Read configuration
  $configPath = Join-Path $PSScriptRoot "../config/module-deployment-config.txt"
  $deployments = Get-Content $configPath | Where-Object { $_ -notmatch '^#|^$' }

  # Parse and deploy each module
  foreach ($line in $deployments) {
      $parts = $line -split '\|'
      $moduleName = $parts[0]
      $sourcePath = $parts[1]
      $targetPath = $parts[2] -replace '\$PSModulePath', $env:PSModulePath.Split(';')[0]

      Write-Host "Deploying $moduleName..."

      # Validate module
      Test-ModuleManifest (Join-Path $sourcePath "$moduleName.psd1") -ErrorAction Stop

      # Copy to destination
      Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force:$Force
  }

  Write-Host "All modules deployed successfully!"
  ```
- [ ] Make script executable and test deployment
- [ ] Add error handling and logging

### Phase 5: Python Module Installation
- [ ] Update `src/common/setup.py` for `python_logging_framework`:
  ```python
  from setuptools import setup

  setup(
      name='my-scripts-logging',
      version='0.2.0',
      py_modules=['python_logging_framework'],
      install_requires=[
          'pytz',
      ],
      description='Cross-platform structured logging framework',
      author='Your Name',
      license='MIT',
  )
  ```
- [ ] Create installation instructions:
  ```bash
  # Development install (editable)
  pip install -e src/common/

  # Or: Install to site-packages
  pip install src/common/
  ```
- [ ] Add to `INSTALLATION.md`

### Phase 6: Automated Module Installation
- [ ] Create `scripts/install-modules.sh` (cross-platform):
  ```bash
  #!/bin/bash
  # Install all modules (PowerShell and Python)

  echo "Installing PowerShell modules..."
  pwsh -Command "./scripts/Deploy-Modules.ps1 -Force"

  echo "Installing Python modules..."
  pip install -e src/common/

  echo "All modules installed!"
  ```
- [ ] Add to installation guide
- [ ] Test on clean environment

### Phase 7: Version Synchronization
- [ ] Ensure module versions align with repository version:
  - Repository: 1.0.0 (from VERSION file)
  - PostgresBackup: 1.0.0
  - PowerShellLoggingFramework: 1.0.0
  - PurgeLogs: 1.0.0
  - RandomName: 2.1.0 (keep existing)
  - Videoscreenshot: 3.0.1 (keep existing)
  - python_logging_framework: 0.2.0 (bump from 0.1.0)
- [ ] Document versioning strategy for modules in `docs/guides/versioning.md`

### Phase 8: CI Integration
- [ ] Add module deployment validation to CI:
  ```yaml
  # .github/workflows/validate-modules.yml
  name: Validate Modules
  on: [push, pull_request]
  jobs:
    validate:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Validate PowerShell Manifests
          shell: pwsh
          run: |
            Get-ChildItem -Recurse -Filter *.psd1 | ForEach-Object {
              Test-ModuleManifest $_.FullName
            }
        - name: Test Module Deployment
          shell: pwsh
          run: |
            ./scripts/Deploy-Modules.ps1 -Force
            Import-Module PostgresBackup
            Import-Module RandomName
            # Verify modules load correctly
  ```

### Phase 9: Documentation
- [ ] Create `docs/guides/module-deployment.md`:
  - How module deployment works
  - Adding new modules to configuration
  - Manual vs automated deployment
  - Module versioning
  - Publishing to galleries (optional)
- [ ] Update `INSTALLATION.md` with module installation steps
- [ ] Update README.md to mention module installation:
  ```markdown
  ## Module Installation

  To install shared modules for use across scripts:

  ```bash
  # Automated installation (recommended)
  ./scripts/install-modules.sh

  # Or manual PowerShell module deployment
  pwsh -Command "./scripts/Deploy-Modules.ps1"

  # Or manual Python module installation
  pip install -e src/common/
  ```

  See [docs/guides/module-deployment.md](docs/guides/module-deployment.md) for details.
  ```

## Acceptance Criteria
- [x] All 5 PowerShell modules have `.psd1` manifests
- [x] All modules listed in `config/module-deployment-config.txt`
- [x] `scripts/Deploy-Modules.ps1` successfully deploys all PowerShell modules
- [x] `scripts/install-modules.sh` installs all modules (PowerShell + Python)
- [x] Module manifests pass `Test-ModuleManifest` validation
- [x] Python `python_logging_framework` installable via pip
- [x] CI validates module manifests on every push
- [x] Module deployment documented in `docs/guides/module-deployment.md`
- [x] Installation guide updated with module steps
- [x] Modules loadable via `Import-Module` after deployment

## Testing Checklist
- [ ] Deploy modules on clean Windows environment
- [ ] Deploy modules on clean Linux environment (PowerShell Core)
- [ ] Verify `Import-Module PostgresBackup` works
- [ ] Verify `Import-Module RandomName` works
- [ ] Verify `Import-Module Videoscreenshot` works
- [ ] Verify `Import-Module PowerShellLoggingFramework` works
- [ ] Verify `Import-Module PurgeLogs` works
- [ ] Verify `import python_logging_framework` works (Python)
- [ ] Test module updates (redeploy with version bump)

## Related Files
- `config/module-deployment-config.txt` (exists)
- `scripts/Deploy-Modules.ps1` (to be created)
- `scripts/install-modules.sh` (to be created)
- `src/powershell/module/RandomName/RandomName.psd1` (exists)
- `src/powershell/module/Videoscreenshot/Videoscreenshot.psd1` (exists)
- `src/common/PostgresBackup.psm1` (needs manifest?)
- `src/common/PowerShellLoggingFramework.psm1` (needs manifest)
- `src/common/PurgeLogs.psm1` (needs manifest)
- `src/common/setup.py` (exists for Python)
- `docs/guides/module-deployment.md` (to be created)

## Estimated Effort
**2 days** (manifest creation, scripting, testing, documentation)

## Dependencies
- Issue #002 (Versioning) – for module version alignment

## Optional Enhancements
- [ ] Publish modules to PowerShell Gallery (requires account)
- [ ] Publish `python_logging_framework` to PyPI (requires account)
- [ ] Create NuGet packages for cross-platform distribution
- [ ] Implement module auto-update mechanism

## References
- [PowerShell Module Manifests](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Python Packaging](https://packaging.python.org/en/latest/tutorials/packaging-projects/)
- [PyPI Publishing](https://pypi.org/)
