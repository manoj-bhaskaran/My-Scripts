# Cloud Services Scripts

Scripts for cloud service integration and automation.

## Scripts

- **Invoke-CloudConvert.ps1** - CloudConvert API integration for file format conversion

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Services
- CloudConvert API account and API key
- Internet connectivity

## CloudConvert Integration

The CloudConvert script provides programmatic access to the CloudConvert API for:
- Document conversion
- Image manipulation
- Video processing
- Archive operations

### Configuration

API credentials should be configured via:
- Environment variables
- Configuration file
- Script parameters

See the script documentation for specific configuration requirements.

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.
