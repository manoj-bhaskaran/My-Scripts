# PowerShell Logging Framework

## Overview
Cross-platform structured logging framework implementing the [Logging Specification](../../../../../docs/specifications/logging_specification.md) for consistent log output across PowerShell scripts.

## Version
Current version: **2.0.0**

## Features

- **Structured log format:** `[TIMESTAMP] [LEVEL] [SCRIPT] [HOST] [PID] [MESSAGE] [metadata]`
- **Multiple log levels:** DEBUG (10), INFO (20), WARNING (30), ERROR (40), CRITICAL (50)
- **Dual output:** File and console with automatic fallback
- **Format options:** Plain text or JSON structured logging
- **Cross-platform:** Windows, Linux, macOS
- **Timezone-aware:** Timestamps with timezone abbreviation (IST, UTC, etc.)
- **Metadata validation:** Recommended keys for structured logging
- **Automatic log file naming:** `<script_name>_powershell_<YYYY-MM-DD>.log`

## Installation

**Module import:**
```powershell
Import-Module PowerShellLoggingFramework
```

**Manual import with path:**
```powershell
Import-Module .\src\powershell\modules\Core\Logging\PowerShellLoggingFramework.psd1
```

**Using deployment script:**
```powershell
.\scripts\Deploy-Modules.ps1
```

## Functions

### Initialize-Logger

Initializes the logging framework for a script.

**Syntax:**
```powershell
Initialize-Logger [[-LogDirectory] <string>] [[-ScriptName] <string>]
    [[-LogLevel] <int>] [-JsonFormat]
```

**Parameters:**

- **LogDirectory** (string, optional)
  - Directory where log files will be created
  - Default: `<script_root>/logs`
  - Created automatically if it doesn't exist

- **ScriptName** (string, optional)
  - Script name used in log entries and file naming
  - Default: Auto-detected from `$MyInvocation.MyCommand.Name`
  - Example: `my_script.ps1`

- **LogLevel** (int, optional)
  - Minimum log level to output
  - Values: 10 (DEBUG), 20 (INFO), 30 (WARNING), 40 (ERROR), 50 (CRITICAL)
  - Default: 20 (INFO)

- **JsonFormat** (switch, optional)
  - Enable JSON structured logging
  - Default: Plain text format

**Examples:**

```powershell
# Basic initialization (auto-detect script name, INFO level)
Initialize-Logger

# Specify log directory and script name
Initialize-Logger -LogDirectory "C:\logs" -ScriptName "my_script.ps1"

# Set DEBUG level for verbose logging
Initialize-Logger -LogLevel 10

# Enable JSON output
Initialize-Logger -JsonFormat

# Complete custom configuration
Initialize-Logger `
    -LogDirectory "D:\app\logs" `
    -ScriptName "backup_job.ps1" `
    -LogLevel 20 `
    -JsonFormat
```

### Write-LogDebug

Writes a DEBUG level log entry.

**Syntax:**
```powershell
Write-LogDebug [-Message] <string> [[-Metadata] <hashtable>]
```

**Examples:**

```powershell
Write-LogDebug "Starting database connection"

Write-LogDebug "Query parameters" -Metadata @{
    Query = "SELECT * FROM users"
    Timeout = 30
}
```

### Write-LogInfo

Writes an INFO level log entry.

**Syntax:**
```powershell
Write-LogInfo [-Message] <string> [[-Metadata] <hashtable>]
```

**Examples:**

```powershell
Write-LogInfo "Backup completed successfully"

Write-LogInfo "Files processed" -Metadata @{
    Count = 150
    Duration = "00:05:32"
}
```

### Write-LogWarning

Writes a WARNING level log entry.

**Syntax:**
```powershell
Write-LogWarning [-Message] <string> [[-Metadata] <hashtable>]
```

**Examples:**

```powershell
Write-LogWarning "Disk space running low"

Write-LogWarning "Retry attempt" -Metadata @{
    Attempt = 2
    MaxAttempts = 5
}
```

### Write-LogError

Writes an ERROR level log entry.

**Syntax:**
```powershell
Write-LogError [-Message] <string> [[-Metadata] <hashtable>]
```

**Examples:**

```powershell
Write-LogError "Database connection failed"

Write-LogError "Backup failed" -Metadata @{
    Database = "mydb"
    Error = $_.Exception.Message
}
```

### Write-LogCritical

Writes a CRITICAL level log entry.

**Syntax:**
```powershell
Write-LogCritical [-Message] <string> [[-Metadata] <hashtable>]
```

**Examples:**

```powershell
Write-LogCritical "System failure - shutting down"

Write-LogCritical "Data corruption detected" -Metadata @{
    Table = "transactions"
    RecordsAffected = 1500
}
```

## Log Format

### Plain Text Format

```
[YYYY-MM-DD HH:MM:SS.fff TIMEZONE] [LEVEL] [SCRIPT] [HOST] [PID] Message [Key=Value ...]
```

**Example:**
```
[2025-11-19 14:30:22.123 IST] [INFO] [backup_job.ps1] [SERVER01] [12345] Backup started [Database=mydb Duration=120]
```

### JSON Format

```json
{
  "timestamp": "2025-11-19T14:30:22.123+05:30",
  "level": "INFO",
  "script": "backup_job.ps1",
  "host": "SERVER01",
  "pid": 12345,
  "message": "Backup started",
  "metadata": {
    "Database": "mydb",
    "Duration": 120
  }
}
```

## Metadata

### Recommended Metadata Keys

The framework validates metadata against recommended keys to ensure consistency:

- **CorrelationId** - Unique identifier for related operations
- **User** - User context for the operation
- **TaskId** - Task or job identifier
- **FileName** - File being processed
- **Duration** - Operation duration (seconds or formatted)

**Example:**

```powershell
Write-LogInfo "File processed" -Metadata @{
    FileName = "data.csv"
    Duration = 45.2
    CorrelationId = "abc123"
}
```

Non-recommended keys trigger a warning but are still logged.

## Usage Examples

### Basic Script Logging

```powershell
# Import module
Import-Module PowerShellLoggingFramework

# Initialize logger
Initialize-Logger -ScriptName "my_backup.ps1" -LogLevel 20

# Log messages
Write-LogInfo "Backup process started"

try {
    # Your code here
    Write-LogInfo "Processing files" -Metadata @{Count = 100}
}
catch {
    Write-LogError "Backup failed" -Metadata @{
        Error = $_.Exception.Message
    }
    exit 1
}

Write-LogInfo "Backup completed successfully"
```

### Advanced Logging with Correlation

```powershell
Import-Module PowerShellLoggingFramework

Initialize-Logger -LogDirectory "C:\logs" -LogLevel 10

$correlationId = [guid]::NewGuid().ToString()

Write-LogInfo "Job started" -Metadata @{
    CorrelationId = $correlationId
    User = $env:USERNAME
}

foreach ($file in $files) {
    Write-LogDebug "Processing file" -Metadata @{
        FileName = $file.Name
        CorrelationId = $correlationId
    }

    # Process file...

    Write-LogInfo "File completed" -Metadata @{
        FileName = $file.Name
        Duration = 12.5
        CorrelationId = $correlationId
    }
}

Write-LogInfo "Job completed" -Metadata @{
    CorrelationId = $correlationId
    TotalFiles = $files.Count
}
```

### JSON Logging for Log Aggregation

```powershell
# Perfect for shipping to ELK, Splunk, etc.
Initialize-Logger -JsonFormat

Write-LogInfo "Application event" -Metadata @{
    EventType = "UserLogin"
    User = "john.doe"
    CorrelationId = "xyz789"
}
```

## Configuration

### Global Configuration

The module uses a global configuration hashtable:

```powershell
$Global:LogConfig = @{
    ScriptName   = $MyInvocation.MyCommand.Name
    LogLevel     = 20  # INFO by default
    LogFilePath  = $null
    JsonFormat   = $false
}
```

### Log Levels

| Level | Value | Description |
|-------|-------|-------------|
| DEBUG | 10 | Detailed debugging information |
| INFO | 20 | General informational messages |
| WARNING | 30 | Warning messages for potential issues |
| ERROR | 40 | Error messages for failures |
| CRITICAL | 50 | Critical failures requiring immediate attention |

### Log File Location

Default: `<script_root>/logs/<script_name>_powershell_<YYYY-MM-DD>.log`

Example: `C:\Scripts\logs\backup_job_powershell_2025-11-19.log`

## Integration with Other Modules

### PurgeLogs Integration

Use the [PurgeLogs](../PurgeLogs/) module for log retention management:

```powershell
Import-Module PowerShellLoggingFramework
Import-Module PurgeLogs

Initialize-Logger

# Your logging operations...

# Clean up old logs (retain 30 days)
$logPath = $Global:LogConfig.LogFilePath
Clear-LogFile -LogFilePath $logPath -RetentionDays 30
```

## Dependencies

- PowerShell 5.1 or later
- No external dependencies

## Technical Details

**Module GUID:** `3c8d5e2a-9f4b-4e6c-8d7a-5b9c3f6e1a2d`

**Tags:** logging, framework, structured-logging, json, cross-platform

**Author:** Manoj Bhaskaran

## Used By

- `src/powershell/backup/Backup-JobSchedulerDatabase.ps1` - Database backup logging
- `src/powershell/cloud/Invoke-CloudConvert.ps1` - Cloud conversion logging
- `src/powershell/git/Remove-MergedGitBranch.ps1` - Git operations logging
- 20+ additional scripts across the repository

## Logging Specification Compliance

This module implements the [Cross-Platform Logging Specification](../../../../../docs/specifications/logging_specification.md) which ensures:

- Consistent log format across PowerShell and Python scripts
- Standard timestamp format with timezone
- Structured metadata support
- Log level standardization
- Cross-platform compatibility

## Troubleshooting

### "Log file not created"
- Check LogDirectory exists and is writable
- Verify Initialize-Logger was called
- Check console output for fallback messages

### "Metadata validation warnings"
- Use recommended metadata keys (CorrelationId, User, TaskId, FileName, Duration)
- Warnings don't prevent logging, just indicate non-standard keys

### "Timestamps showing wrong timezone"
- Module uses system timezone by default
- Timezone abbreviation is automatically detected
- Check system timezone configuration

### "JSON format not working"
- Ensure `-JsonFormat` switch is passed to `Initialize-Logger`
- Check log file for proper JSON structure
- Verify no syntax errors in metadata hashtables

## Performance Considerations

- File writes use buffered I/O
- Automatic fallback to console if file operations fail
- Minimal overhead for disabled log levels
- Metadata validation adds negligible performance impact

## License

MIT License

---

For module history, see [CHANGELOG.md](./CHANGELOG.md).
