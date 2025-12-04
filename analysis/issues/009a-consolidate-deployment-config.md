# Issue #009a: Consolidate Module Deployment Configuration

**Parent Issue**: [#009: Module Deployment Complexity](./009-module-deployment-complexity.md)
**Phase**: Phase 1 - Configuration
**Effort**: 6-8 hours

## Description
Replace multiple configuration files (deployment.txt, local-deployment-config.json) with a single TOML configuration file. Reduce configuration complexity from 3 files to 1.

## Current State
- `config/modules/deployment.txt` - Pipe-separated manifest
- `config/local-deployment-config.json.example` - JSON deployment paths
- Module manifest files (.psd1) - Module metadata

## Implementation

### Create psmodule.toml
```toml
# psmodule.toml - Single source of truth for module deployment

[deployment]
# Auto-detect PowerShell module path or use custom
default-path = "auto"  # Uses $env:PSModulePath[0]

# Testing and validation
test-on-deploy = true
validate-manifest = true
import-after-deploy = false

# Module discovery
auto-discover = true
source-paths = ["src/powershell/modules"]

[[modules]]
name = "PowerShellLoggingFramework"
source = "src/powershell/modules/Core/Logging/PowerShellLoggingFramework"
auto-deploy = true
test-on-deploy = true
description = "Cross-platform structured logging"

[[modules]]
name = "PostgresBackup"
source = "src/powershell/modules/Database/PostgresBackup"
auto-deploy = true
dependencies = ["PowerShellLoggingFramework"]
description = "PostgreSQL backup with retention"

[[modules]]
name = "PurgeLogs"
source = "src/powershell/modules/Core/Logging/PurgeLogs"
auto-deploy = true
dependencies = ["PowerShellLoggingFramework"]
description = "Log retention management"

[[modules]]
name = "ErrorHandling"
source = "src/powershell/modules/Core/ErrorHandling"
auto-deploy = true
description = "Standardized error handling with retry"

[[modules]]
name = "FileOperations"
source = "src/powershell/modules/Core/FileOperations"
auto-deploy = true
description = "Resilient file operations"

[[modules]]
name = "ProgressReporter"
source = "src/powershell/modules/Core/Progress"
auto-deploy = true
description = "Progress tracking and reporting"

[[modules]]
name = "RandomName"
source = "src/powershell/modules/Utilities/RandomName"
auto-deploy = true
description = "Windows-safe random filename generation"

[[modules]]
name = "Videoscreenshot"
source = "src/powershell/modules/Media/Videoscreenshot"
auto-deploy = true
description = "Video frame capture via VLC or GDI+"
```

### Optional User Overrides (psmodule.local.toml)
```toml
# psmodule.local.toml - User-specific overrides (gitignored)

[deployment]
default-path = "C:/Custom/Path/Modules"

[[modules]]
name = "PowerShellLoggingFramework"
# Override to disable auto-deploy for specific module
auto-deploy = false
```

### TOML Parser Function
```powershell
# Read-ModuleConfig.ps1
function Read-ModuleConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "psmodule.toml",
        [string]$LocalConfigPath = "psmodule.local.toml"
    )

    # Use PowerShell's built-in or install TOML parser
    if (-not (Get-Command ConvertFrom-Toml -ErrorAction SilentlyContinue)) {
        Install-Module -Name Tomlyn.Signed -Force -Scope CurrentUser
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Toml

    # Merge local overrides if exists
    if (Test-Path $LocalConfigPath) {
        $localConfig = Get-Content $LocalConfigPath -Raw | ConvertFrom-Toml
        # Merge logic here
    }

    return $config
}
```

## Migration Script
```powershell
# scripts/Migrate-ModuleConfig.ps1
<#
.SYNOPSIS
    Migrates from old config format to new psmodule.toml
#>

# Read old deployment.txt
$oldModules = Get-Content "config/modules/deployment.txt" |
    Where-Object { $_ -and $_ -notmatch '^#' } |
    ForEach-Object {
        $parts = $_ -split '\|'
        [PSCustomObject]@{
            Name = $parts[0]
            Source = $parts[1]
        }
    }

# Read local-deployment-config.json if exists
$localConfig = if (Test-Path "config/local-deployment-config.json") {
    Get-Content "config/local-deployment-config.json" | ConvertFrom-Json
} else { $null }

# Generate psmodule.toml
$toml = Generate-TomlConfig -Modules $oldModules -LocalConfig $localConfig

# Write new config
$toml | Out-File "psmodule.toml" -Encoding UTF8

Write-Host "✓ Migrated to psmodule.toml"
Write-Host "⚠ Review and commit psmodule.toml"
Write-Host "⚠ Update Deploy-Modules.ps1 to use new format"
```

## Acceptance Criteria
- [ ] psmodule.toml created with all 8 modules
- [ ] psmodule.local.toml.example created
- [ ] Read-ModuleConfig function implemented
- [ ] Migration script tested
- [ ] Old config files deprecated (not removed yet)
- [ ] Documentation updated

## Benefits
- Single configuration file
- Standard TOML format
- Comments supported
- Schema validation possible
- Easier to edit and understand

## Effort
6-8 hours

## Related
- Issue #009b (update deployment script)
- Simplifies developer onboarding
