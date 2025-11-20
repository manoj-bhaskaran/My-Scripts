# PurgeLogs Module

## Overview
Log file purging and retention management module implementing multiple cleanup strategies per [Logging Specification](../../../../../docs/specifications/logging_specification.md).

## Version
Current version: **2.0.0**

## Features

- **Multiple cleanup strategies:**
  - Time-based retention (age-based cleanup)
  - Size-based retention (trim to fit within size limit)
  - Conditional truncation (clear if exceeds threshold)
  - Unconditional truncation
- **Safe deletion with logging** - Integration with PowerShellLoggingFramework
- **Dry-run mode** - Preview changes without modifying files
- **Timestamp parsing** - Supports standardized log format
- **WhatIf support** - PowerShell best practices compliance

## Installation

**Module import:**
```powershell
Import-Module PurgeLogs
```

**Manual import with path:**
```powershell
Import-Module .\src\powershell\modules\Core\Logging\PurgeLogs.psd1
```

**Using deployment script:**
```powershell
.\scripts\Deploy-Modules.ps1
```

## Functions

### Clear-LogFile

Purges log file entries based on various retention strategies.

**Syntax:**
```powershell
Clear-LogFile [-LogFilePath] <string> [[-RetentionDays] <int>] [[-MaxSizeMB] <int>]
    [[-TruncateIfLarger] <string>] [-TruncateLog] [-DryRun] [-Verbose]
```

**Parameters:**

- **LogFilePath** (string, mandatory)
  - Path to log file to purge
  - Can be relative or absolute
  - File must exist for retention/size operations

- **RetentionDays** (int, optional)
  - Remove log entries older than N days
  - Mutually exclusive with other strategies
  - Example: `30` for 30-day retention

- **MaxSizeMB** (int, optional)
  - Trim log file to fit within size limit (in MB)
  - Keeps most recent entries that fit within size
  - Mutually exclusive with other strategies
  - Example: `20` for 20 MB limit

- **TruncateIfLarger** (string, optional)
  - Clear entire file if size exceeds threshold
  - Human-readable format: "500MB", "1GB", "100KB"
  - Mutually exclusive with other strategies
  - Example: `"250MB"`

- **TruncateLog** (switch, optional)
  - Clear file unconditionally
  - Mutually exclusive with other strategies
  - Use with caution

- **DryRun** (switch, optional)
  - Simulate operation without making changes
  - Shows what would be deleted/kept
  - Safe for testing retention policies

- **Verbose** (switch, optional)
  - Enable detailed output
  - Shows processing steps and decisions

**Strategy Precedence:**

Strategies are applied in this order (only one is executed):
1. **RetentionDays** - Age-based cleanup
2. **MaxSizeMB** - Size-based trimming
3. **TruncateIfLarger** - Conditional truncation
4. **TruncateLog** - Unconditional truncation

**Examples:**

```powershell
# Remove entries older than 30 days
Clear-LogFile -LogFilePath "C:\logs\application.log" -RetentionDays 30

# Trim log to fit within 20 MB (keeps most recent)
Clear-LogFile -LogFilePath "C:\logs\application.log" -MaxSizeMB 20

# Clear log if larger than 250 MB
Clear-LogFile -LogFilePath "C:\logs\application.log" -TruncateIfLarger "250MB"

# Unconditionally clear log file
Clear-LogFile -LogFilePath "C:\logs\application.log" -TruncateLog

# Dry run - show what would be deleted
Clear-LogFile -LogFilePath "C:\logs\application.log" -RetentionDays 15 -DryRun

# Verbose output for debugging
Clear-LogFile -LogFilePath "C:\logs\application.log" -RetentionDays 30 -Verbose

# Using relative path
Clear-LogFile -LogFilePath ".\logs\backup.log" -MaxSizeMB 50
```

### ConvertTo-Bytes

Converts human-readable size strings to bytes.

**Syntax:**
```powershell
ConvertTo-Bytes [-Size] <string>
```

**Parameters:**

- **Size** (string, mandatory)
  - Human-readable size string
  - Supported units: KB, MB, GB, TB
  - Case-insensitive
  - Examples: "500MB", "1GB", "1024KB", "2.5GB"

**Examples:**

```powershell
ConvertTo-Bytes "500MB"
# Returns: 524288000

ConvertTo-Bytes "1GB"
# Returns: 1073741824

ConvertTo-Bytes "100KB"
# Returns: 102400

ConvertTo-Bytes "2.5GB"
# Returns: 2684354560
```

## Log Format Support

The module parses standardized log timestamps in the format:

```
[YYYY-MM-DD HH:MM:SS.fff TIMEZONE] [LEVEL] ...
```

**Supported variations:**
- `[2025-11-19 14:30:22 IST]` - Without milliseconds
- `[2025-11-19 14:30:22.123 IST]` - With milliseconds
- `[2025-11-19 14:30:22.123 UTC]` - Different timezone
- `[2025-11-19 14:30:22]` - Without timezone

## Usage Examples

### Time-Based Retention (Age-Based Cleanup)

```powershell
Import-Module PurgeLogs

# Keep only last 30 days of logs
Clear-LogFile -LogFilePath "C:\logs\job_scheduler.log" -RetentionDays 30 -Verbose

# More aggressive retention (7 days)
Clear-LogFile -LogFilePath "C:\logs\debug.log" -RetentionDays 7
```

**How it works:**
1. Parses each log line's timestamp
2. Compares against retention threshold
3. Keeps entries within retention period
4. Removes older entries
5. Writes filtered content back to file

### Size-Based Retention (Trim to Fit)

```powershell
Import-Module PurgeLogs

# Trim log to fit within 20 MB (keeps most recent)
Clear-LogFile -LogFilePath "C:\logs\application.log" -MaxSizeMB 20

# Smaller limit for verbose logs
Clear-LogFile -LogFilePath "C:\logs\debug.log" -MaxSizeMB 5
```

**How it works:**
1. Reads log file in reverse order
2. Accumulates entries until size limit reached
3. Keeps most recent entries that fit within size
4. Removes oldest entries
5. Writes trimmed content back to file

### Conditional Truncation (Clear if Too Large)

```powershell
Import-Module PurgeLogs

# Clear log if it exceeds 500 MB
Clear-LogFile -LogFilePath "C:\logs\application.log" -TruncateIfLarger "500MB"

# Use smaller threshold for frequent cleanup
Clear-LogFile -LogFilePath "C:\logs\temp.log" -TruncateIfLarger "100MB"
```

**How it works:**
1. Checks current file size
2. Compares against threshold
3. If larger: clears entire file
4. If smaller: no action taken

### Dry Run Mode (Testing)

```powershell
Import-Module PurgeLogs

# Preview what would be deleted (safe)
Clear-LogFile -LogFilePath "C:\logs\application.log" -RetentionDays 30 -DryRun

# Test size-based trimming
Clear-LogFile -LogFilePath "C:\logs\application.log" -MaxSizeMB 20 -DryRun -Verbose
```

**Benefits:**
- Safe testing of retention policies
- Preview impact before applying
- Validate configuration
- No file modifications

### Scheduled Cleanup Script

```powershell
# cleanup_logs.ps1
Import-Module PurgeLogs
Import-Module PowerShellLoggingFramework

Initialize-Logger -ScriptName "cleanup_logs"

$logFiles = @(
    @{Path = "C:\logs\application.log"; RetentionDays = 30}
    @{Path = "C:\logs\backup.log"; RetentionDays = 90}
    @{Path = "C:\logs\debug.log"; MaxSizeMB = 10}
)

foreach ($log in $logFiles) {
    try {
        Write-LogInfo "Processing log file: $($log.Path)"

        if ($log.RetentionDays) {
            Clear-LogFile -LogFilePath $log.Path -RetentionDays $log.RetentionDays -Verbose
            Write-LogInfo "Applied retention policy" -Metadata @{
                File = $log.Path
                RetentionDays = $log.RetentionDays
            }
        }
        elseif ($log.MaxSizeMB) {
            Clear-LogFile -LogFilePath $log.Path -MaxSizeMB $log.MaxSizeMB -Verbose
            Write-LogInfo "Applied size limit" -Metadata @{
                File = $log.Path
                MaxSizeMB = $log.MaxSizeMB
            }
        }
    }
    catch {
        Write-LogError "Failed to process log file" -Metadata @{
            File = $log.Path
            Error = $_.Exception.Message
        }
    }
}

Write-LogInfo "Log cleanup completed"
```

### Windows Task Scheduler Integration

**Recommended Schedule:** Weekly on Sunday at 2:00 PM

**Task Configuration:**
- **Action:** Start a program
- **Program:** `powershell.exe`
- **Arguments:** `-ExecutionPolicy Bypass -File "C:\Scripts\cleanup_logs.ps1"`
- **Run whether user is logged on or not:** Yes

**Using XML Configuration:**

See `config/tasks/purge_logs.xml` for example Task Scheduler configuration.

```powershell
# Import task
schtasks /Create /XML "C:\Scripts\config\tasks\purge_logs.xml" /TN "LogCleanup"
```

## Integration with PowerShellLoggingFramework

```powershell
Import-Module PowerShellLoggingFramework
Import-Module PurgeLogs

# Initialize logging
Initialize-Logger -ScriptName "my_application.ps1"

# Your application code...
Write-LogInfo "Processing data"

# Cleanup old log entries periodically
$logPath = $Global:LogConfig.LogFilePath
Clear-LogFile -LogFilePath $logPath -RetentionDays 30
```

## Dependencies

- **PowerShellLoggingFramework** - For module's own logging operations
- PowerShell 5.1 or later

## Technical Details

**Module GUID:** `8e9f2b4d-6c3a-4f7e-9d5b-2a8c4e6f1b3d`

**Tags:** logging, purge, retention, cleanup, maintenance

**Author:** Manoj Bhaskaran

## Used By

- `src/powershell/system/Clear-LogFile.ps1` - Log cleanup wrapper script
- Scheduled maintenance tasks
- Log rotation workflows

## Logging Specification Compliance

This module implements log retention features specified in the [Cross-Platform Logging Specification](../../../../../docs/specifications/logging_specification.md):

- Standard timestamp format parsing
- Time-based retention policies
- Size-based retention policies
- Integration with PowerShellLoggingFramework

## Troubleshooting

### "Log file not found"
- Verify file path is correct
- Use absolute paths for clarity
- Check file permissions

### "Failed to parse timestamp"
- Ensure log file uses standardized format: `[YYYY-MM-DD HH:MM:SS.fff TIMEZONE]`
- Module supports multiple timestamp variations
- Non-parseable lines are kept by default (safe fallback)

### "RetentionDays not working"
- Verify log entries have valid timestamps
- Check timezone in timestamps
- Use `-Verbose` to see parsing details
- Try `-DryRun` first to validate

### "MaxSizeMB removes too much"
- Module keeps most recent entries
- Increase MaxSizeMB if needed
- Consider time-based retention instead

### "Permission denied"
- Ensure PowerShell has write access to log file
- Close applications that may have file open
- Run as Administrator if needed

## Performance Considerations

- **Large files:** RetentionDays and MaxSizeMB read entire file into memory
- **Frequent cleanup:** Use TruncateIfLarger for better performance
- **Concurrent access:** Module doesn't lock files - ensure no concurrent writes
- **Dry run:** No performance impact, safe for testing

## Best Practices

1. **Test first:** Always use `-DryRun` before applying to production logs
2. **Regular schedule:** Run cleanup weekly or monthly
3. **Retention policy:** Match business/compliance requirements
4. **Monitor disk space:** Set up alerts for log directories
5. **Backup before purge:** Keep archives of important logs
6. **Use appropriate strategy:**
   - RetentionDays: Compliance/audit requirements
   - MaxSizeMB: Disk space management
   - TruncateIfLarger: Emergency cleanup
   - TruncateLog: Development/testing only

## License

MIT License

---

For module history, see [CHANGELOG.md](./CHANGELOG.md).
