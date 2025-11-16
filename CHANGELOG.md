# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-11-16

### Added
- PowerShellLoggingFramework.psm1: Centralized logging framework for all PowerShell scripts
  - Standardized logging with consistent timestamp formats (YYYY-MM-DD HH:mm:ss.fff TZ)
  - Log level support (DEBUG=10, INFO=20, WARNING=30, ERROR=40, CRITICAL=50)
  - Automatic log file creation in `logs/` directory with format: `{ScriptName}_powershell_YYYY-MM-DD.log`
  - Optional JSON structured logging support
  - Metadata support for enhanced logging context
  - Cross-platform compliance with timezone abbreviation support

### Changed
- **BREAKING**: Refactored 21 PowerShell scripts to use PowerShellLoggingFramework
  - All scripts now use standardized logging functions: Write-LogDebug, Write-LogInfo, Write-LogWarning, Write-LogError, Write-LogCritical
  - Removed ad-hoc logging configurations from individual scripts
  - Removed custom logging helper functions in favor of framework functions
  - All scripts bumped to version 2.0.0 to reflect major refactoring

#### Scripts Refactored:
1. **ClearOldRecycleBinItems.ps1** (v1.0.0 → v2.0.0)
   - Replaced Write-Warning with Write-LogWarning
   - Added comprehensive logging for Recycle Bin cleanup operations

2. **SelObj.ps1** (v2.1.1 → v2.2.0)
   - Replaced Write-Warning and Write-Host with framework logging
   - Enhanced debug logging for file selection process

3. **cloudconvert_driver.ps1** (v1.0.0 → v2.0.0)
   - Replaced Write-Host with Write-LogInfo
   - Added error handling with Write-LogError

4. **handle.ps1** (v1.0.0 → v2.0.0)
   - Replaced Write-Host with Write-LogInfo
   - Enhanced logging for file handle checking

5. **ConvertTo-Jpeg.ps1** (v1.0.0 → v2.0.0)
   - Replaced Write-Host with Write-LogInfo and Write-LogWarning
   - Added summary statistics logging

6. **cleanup-git-branches.ps1** (v1.0.0 → v2.0.0)
   - Removed custom Log function
   - Replaced with Write-LogInfo, Write-LogWarning, Write-LogError
   - Removed emoji characters for cleaner log output

7. **FileDistributor.ps1** (v3.5.0 → v4.0.0)
   - Replaced custom LogMessage function with framework wrapper
   - Maintained backward compatibility with existing 201 LogMessage calls
   - Added console output color coding

8. **picconvert.ps1** (v1.1.5 → v2.0.0)
   - Removed custom Write-Info, Write-Warn helper functions
   - Updated Write-ErrTrack to use Write-LogError

9. **Remove-DuplicateFiles.ps1** (v1.3.1 → v2.0.0)
   - Removed custom Log function
   - Created backward-compatible wrapper for existing Log calls

10. **DeleteOldDownloads.ps1** (v1.2.1 → v2.0.0)
    - Removed custom Write-Log function
    - Replaced all logging with framework functions

11. **post-commit-my-scripts.ps1** (v2.5 → v3.0.0)
    - Updated Write-Message function to use Write-LogInfo internally
    - Maintained backward compatibility

12. **post-merge-my-scripts.ps1** (v2.6 → v3.0.0)
    - Updated Write-Message function to use Write-LogInfo internally
    - Maintained backward compatibility

13. **scrubname.ps1** (v1.0.0 → v2.0.0)
    - Replaced Add-Content logging with Write-LogInfo
    - Added comprehensive documentation
    - Kept dual logging for backward compatibility

14. **Copy-AndroidFiles.ps1** (v1.3.9 → v2.0.0)
    - Replaced Write-Host with Write-LogInfo (11 occurrences)
    - Replaced Write-Warning with Write-LogWarning (6 occurrences)
    - Replaced Write-Verbose with Write-LogDebug (3 occurrences)
    - Retained ADB-specific DebugMode for specialized debugging

15. **Expand-ZipsAndClean.ps1** (v1.2.2 → v2.0.0)
    - Removed Write-Info helper function
    - Replaced Write-Info with Write-LogInfo (2 occurrences)
    - Replaced Write-Verbose with Write-LogDebug (11 occurrences)
    - Retained user-facing summary output

16. **recover-extensions.ps1** (v1.0.0 → v2.0.0)
    - Replaced Write-Host with Write-LogInfo

17. **pg_backup_common.ps1** (v1.0.0 → v2.0.0)
    - Replaced Write-Verbose with Write-LogDebug
    - Replaced Write-Error with Write-LogError

18. **Update-ScheduledTaskScriptPaths.ps1** (v1.0.0 → v2.0.0)
    - Replaced Write-Host with Write-LogInfo, Write-LogDebug, Write-LogWarning
    - Removed emoji-based status indicators

19. **SyncRepoToTarget.ps1** (v1.0 → v2.0.0)
    - Replaced Write-Host with Write-LogInfo, Write-LogError, Write-LogWarning

20. **Remove-EmptyFolders.ps1** (v1.3.1 → v2.0.0)
    - Removed custom Log and Initialize-LogDestination functions
    - Replaced all logging with framework functions

21. **Sync-MacriumBackups.ps1** (v1.0.0 → v2.0.0)
    - Removed custom Write-Log function
    - Replaced all logging with appropriate framework functions

22. **job_scheduler_pg_backup.ps1** (v1.8 → v2.0.0)
    - Removed custom Write-HostInfo helper function
    - Replaced all logging with Write-LogInfo and Write-LogError

23. **logCleanup.ps1** (v1.0.0 → v2.0.0)
    - Added complete script documentation
    - Replaced Add-Content manual logging with Write-LogInfo

### Deprecated
- Custom logging functions in individual scripts (all removed in favor of PowerShellLoggingFramework)

### Removed
- Ad-hoc logging configurations from all PowerShell scripts
- Custom helper functions: Log, Write-Log, Write-HostInfo, Write-Info, Write-Warn, Write-Err, LogMessage, Write-Message

### Fixed
- Inconsistent logging formats across PowerShell scripts
- Missing log levels in many scripts
- Lack of centralized log management

### Security
- Logs now follow a standardized format that's easier to audit and monitor
- Centralized logging configuration reduces the risk of inconsistent logging practices

## [1.0.0] - 2025-11-15

### Added
- Initial repository structure
- PowerShell scripts for various automation tasks
- Python scripts for data processing
- SQL queries for database management
- Batch scripts for common operations

[Unreleased]: https://github.com/manoj-bhaskaran/My-Scripts/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/manoj-bhaskaran/My-Scripts/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/manoj-bhaskaran/My-Scripts/releases/tag/v1.0.0
