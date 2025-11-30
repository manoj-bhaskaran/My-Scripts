# PowerShell Modules

Reusable PowerShell modules organized by functional category.

## Module Organization

Modules are organized into the following categories:

### Core Modules (`Core/`)
Fundamental modules used across multiple scripts:

#### Logging (`Core/Logging/`)
- **PowerShellLoggingFramework** - Cross-platform structured logging framework
  - Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
  - JSON output support
  - Configurable log rotation
  - Thread-safe logging operations

- **PurgeLogs** - Log file purging and retention management
  - Age-based retention policies
  - Size-based purging
  - Multiple purge strategies
  - Integration with PowerShellLoggingFramework

### Database Modules (`Database/`)
Database-related functionality:

#### PostgresBackup (`Database/PostgresBackup/`)
- PostgreSQL database backup automation
- Retention management
- Service control integration
- Backup verification
- Compression support

### Utility Modules (`Utilities/`)
General-purpose utility modules:

#### RandomName (`Utilities/RandomName/`)
- Generates Windows-safe random file names
- Conservative character allow-list
- Collision detection
- Configurable length and format

### Media Modules (`Media/`)
Media processing functionality:

#### Videoscreenshot (`Media/Videoscreenshot/`)
- Video frame capture via VLC or GDI+
- Batch processing support
- Optional Python cropper integration
- PID registry for process management
- Configurable capture intervals

## Module Deployment

Modules are configured for deployment via the module deployment system.

Configuration file: `config/modules/deployment.txt`

### Deployment Targets

Modules can be deployed to:
- **System**: `C:\Program Files\WindowsPowerShell\Modules\`
- **User**: `%USERPROFILE%\Documents\WindowsPowerShell\Modules\`
- **Custom**: Alternate paths as configured

### Importing Modules

Once deployed, modules can be imported using standard PowerShell cmdlets:

```powershell
# Import by name (if deployed)
Import-Module PowerShellLoggingFramework
Import-Module PostgresBackup

# Import by path (development)
Import-Module "$PSScriptRoot\modules\Core\Logging\PowerShellLoggingFramework.psm1"
```

## Module Development

### Directory Structure

Each module should follow PowerShell module conventions:
```
ModuleName/
├── ModuleName.psm1      # Module script file
├── ModuleName.psd1      # Module manifest
├── Public/              # Public functions (exported)
├── Private/             # Private functions (internal)
├── README.md            # Module documentation
└── CHANGELOG.md         # Version history
```

All module loaders dot-source the `Private/` folder first and `Public/` second, exporting only the public surface discovered in
`Public/*.ps1`.

### Best Practices

1. **Versioning**: Use semantic versioning (SemVer)
2. **Documentation**: Include inline help for all public functions
3. **Testing**: Write Pester tests for module functionality
4. **Logging**: Use PowerShellLoggingFramework for consistent logging
5. **Error Handling**: Implement proper error handling and terminating errors

## Module Dependencies

Module dependencies are declared in the `.psd1` manifest file:

```powershell
@{
    RequiredModules = @('PowerShellLoggingFramework')
    # ...
}
```

## See Also

- Module Deployment Configuration: `config/modules/deployment.txt`
- Logging Specification: `docs/specifications/logging_specification.md`
