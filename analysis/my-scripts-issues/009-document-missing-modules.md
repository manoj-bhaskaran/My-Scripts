# Document Missing Modules (RandomName, PostgresBackup, Logging)

## Priority
**MODERATE** 🟡

## Background
The My-Scripts repository has **inconsistent module documentation**:

**Well-Documented:**
- ✅ **Videoscreenshot** (v3.0.1) – Comprehensive README.md, CHANGELOG.md, inline help

**Undocumented:**
- ❌ **RandomName** (v2.1.0) – No README, no CHANGELOG, minimal inline documentation
- ❌ **PostgresBackup** – No README, no CHANGELOG, only inline comments
- ❌ **PowerShellLoggingFramework** – Referenced in logging specification but no usage guide
- ❌ **PurgeLogs** – No documentation beyond inline comments
- ❌ **python_logging_framework** (v0.1.0) – Has setup.py but no README

**Impact:**
- Users don't know how to use modules
- No version history tracked
- Difficult to understand module capabilities
- Hard to contribute improvements

## Objectives
- Create comprehensive README.md for each undocumented module
- Create CHANGELOG.md for each module (following Videoscreenshot example)
- Document all public functions/cmdlets
- Add usage examples
- Document dependencies and prerequisites

## Tasks

### Module 1: RandomName
- [ ] Create `src/powershell/modules/Utilities/RandomName/README.md`:
  ```markdown
  # RandomName PowerShell Module

  ## Overview
  Generates random, Windows-compatible filenames for safe file operations.

  ## Version
  Current version: **2.1.0**

  ## Installation
  ```powershell
  Import-Module RandomName
  ```

  Or use deployment script:
  ```powershell
  .\scripts\Deploy-Modules.ps1
  ```

  ## Functions

  ### Get-RandomFileName
  Generates a random filename that is safe for Windows filesystems.

  **Syntax:**
  ```powershell
  Get-RandomFileName [-Extension <string>] [-Length <int>] [-Prefix <string>]
  ```

  **Parameters:**
  - `Extension`: File extension (default: none)
  - `Length`: Length of random portion (default: 8)
  - `Prefix`: Optional prefix for filename

  **Examples:**
  ```powershell
  # Generate random filename
  Get-RandomFileName
  # Output: a7f3k2m9

  # Generate with extension
  Get-RandomFileName -Extension "txt"
  # Output: a7f3k2m9.txt

  # Generate with prefix and custom length
  Get-RandomFileName -Prefix "backup_" -Length 12 -Extension "zip"
  # Output: backup_a7f3k2m9x5y1.zip
  ```

  ## Dependencies
  None

  ## Used By
  - FileDistributor.ps1
  - (add others)

  ## License
  MIT License
  ```
- [ ] Create `src/powershell/modules/Utilities/RandomName/CHANGELOG.md`:
  ```markdown
  # RandomName Module – Changelog

  ## [2.1.0] - YYYY-MM-DD
  ### Added
  - Initial versioned release
  - Windows-safe filename generation
  - Configurable prefix and length

  ## [Unreleased]
  (Future changes)
  ```

### Module 2: PostgresBackup
- [ ] Create `src/powershell/modules/Database/PostgresBackup/README.md`:
  ```markdown
  # PostgresBackup PowerShell Module

  ## Overview
  Provides abstraction layer for PostgreSQL database backups using pg_dump.

  ## Version
  Current version: **1.0.0**

  ## Installation
  ```powershell
  Import-Module PostgresBackup
  ```

  ## Prerequisites
  - PostgreSQL client tools (pg_dump, psql)
  - Appropriate database credentials
  - Environment variables (optional): PGHOST, PGPORT, PGUSER, PGPASSWORD

  ## Functions

  ### Invoke-PostgresBackup
  Executes pg_dump to create database backup.

  **Syntax:**
  ```powershell
  Invoke-PostgresBackup -Database <string> -OutputPath <string> [-Host <string>] [-Port <int>] [-User <string>]
  ```

  **Examples:**
  ```powershell
  # Basic backup
  Invoke-PostgresBackup -Database "mydb" -OutputPath "C:\backups\mydb.sql"

  # Backup with custom connection
  Invoke-PostgresBackup \
    -Database "mydb" \
    -OutputPath "C:\backups\mydb.sql" \
    -Host "localhost" \
    -Port 5432 \
    -User "postgres"
  ```

  ### Test-PostgresConnection
  Verifies PostgreSQL server connectivity.

  ## Used By
  - gnucash_pg_backup.ps1
  - job_scheduler_pg_backup.ps1
  - timeline_data_pg_backup.ps1

  ## License
  MIT License
  ```
- [ ] Create CHANGELOG.md for PostgresBackup
- [ ] Add inline comment-based help to all exported functions

### Module 3: PowerShellLoggingFramework
- [ ] Create `src/powershell/modules/Core/Logging/PowerShellLoggingFramework/README.md`:
  ```markdown
  # PowerShell Logging Framework

  ## Overview
  Cross-platform structured logging framework implementing the [Logging Specification](../../../../docs/specifications/logging_specification.md).

  ## Version
  Current version: **1.0.0**

  ## Features
  - Structured log format: `[TIMESTAMP] [LEVEL] [SCRIPT] [HOST] [PID] [MESSAGE] [metadata]`
  - Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
  - File and console output
  - Automatic log rotation
  - Cross-platform (Windows, Linux, macOS)

  ## Installation
  ```powershell
  Import-Module PowerShellLoggingFramework
  ```

  ## Functions

  ### Write-Log
  Writes structured log entry.

  **Syntax:**
  ```powershell
  Write-Log -Message <string> [-Level <string>] [-Metadata <hashtable>]
  ```

  **Examples:**
  ```powershell
  # Info log
  Write-Log -Message "Backup completed successfully"

  # Error log with metadata
  Write-Log \
    -Message "Database connection failed" \
    -Level "ERROR" \
    -Metadata @{Database="mydb"; Error=$_.Exception.Message}
  ```

  ### Initialize-Logger
  Initializes logging framework for script.

  ### Get-LogFilePath
  Returns current log file path per specification.

  ## Configuration
  Log files written to: `<script_root>/logs/<script_name>_powershell_YYYY-MM-DD.log`

  ## License
  MIT License
  ```
- [ ] Create CHANGELOG.md for PowerShellLoggingFramework

### Module 4: PurgeLogs
- [ ] Create `src/powershell/modules/Core/Logging/PurgeLogs/README.md`:
  ```markdown
  # PurgeLogs Module

  ## Overview
  Log file purging and retention management per [Logging Specification](../../../../docs/specifications/logging_specification.md).

  ## Version
  Current version: **1.0.0**

  ## Features
  - Time-based retention (default: 30 days)
  - Size-based retention (configurable threshold)
  - Safe deletion with logging
  - Dry-run mode

  ## Functions

  ### Remove-OldLogs
  Purges log files based on retention policy.

  **Syntax:**
  ```powershell
  Remove-OldLogs [-LogDirectory <string>] [-RetentionDays <int>] [-MaxSizeMB <int>] [-WhatIf]
  ```

  **Examples:**
  ```powershell
  # Purge logs older than 30 days
  Remove-OldLogs -LogDirectory "C:\logs" -RetentionDays 30

  # Dry run (show what would be deleted)
  Remove-OldLogs -LogDirectory "C:\logs" -WhatIf

  # Size-based purge
  Remove-OldLogs -LogDirectory "C:\logs" -MaxSizeMB 500
  ```

  ## Scheduling
  Recommended: Run weekly via Task Scheduler (Sunday 2:00 PM per specification).

  See `config/tasks/purge_logs.xml` for example.

  ## License
  MIT License
  ```
- [ ] Create CHANGELOG.md for PurgeLogs

### Module 5: python_logging_framework
- [ ] Create `src/python/modules/logging/README.md`:
  ```markdown
  # Python Logging Framework

  ## Overview
  Cross-platform structured logging framework implementing the [Logging Specification](../../../../docs/specifications/logging_specification.md).

  ## Version
  Current version: **0.2.0**

  ## Installation
  ```bash
  pip install -e src/python/modules/logging
  ```

  ## Usage

  ### Basic Logging
  ```python
  from python_logging_framework import init_logger, log_info, log_error

  # Initialize logger for script
  logger = init_logger(__file__)

  # Log messages
  log_info("Processing started", metadata={"count": 100})
  log_error("Failed to connect", metadata={"host": "localhost", "port": 5432})
  ```

  ### Advanced Configuration
  ```python
  from python_logging_framework import configure_logger

  logger = configure_logger(
      script_name="my_script.py",
      log_level="DEBUG",
      log_dir="/var/log/my-scripts"
  )
  ```

  ## Features
  - Structured log format matching PowerShell framework
  - Automatic log file creation: `<script_name>_python_YYYY-MM-DD.log`
  - Console and file output
  - Timezone support (IST by default)
  - JSON output mode (optional)

  ## Dependencies
  - pytz

  ## License
  MIT License
  ```
- [ ] Create `src/python/modules/logging/CHANGELOG.md`:
  ```markdown
  # python_logging_framework – Changelog

  ## [0.2.0] - YYYY-MM-DD
  ### Added
  - Comprehensive README and documentation
  - Installable via pip

  ### Changed
  - Updated version from 0.1.0
  - Improved structured output

  ## [0.1.0] - YYYY-MM-DD
  ### Added
  - Initial release
  - Cross-platform logging
  - Logging specification compliance
  ```

### Phase 6: Add Comment-Based Help
- [ ] Ensure all PowerShell functions have complete comment-based help:
  ```powershell
  <#
  .SYNOPSIS
      Brief description

  .DESCRIPTION
      Detailed description

  .PARAMETER ParameterName
      Parameter description

  .EXAMPLE
      Usage example

  .NOTES
      Author: Your Name
      Version: X.Y.Z
      Last Modified: YYYY-MM-DD
  #>
  ```
- [ ] Audit and complete inline help for:
  - RandomName functions
  - PostgresBackup functions
  - PowerShellLoggingFramework functions
  - PurgeLogs functions

### Phase 7: Update Main README.md
- [ ] Add module documentation section to root README.md:
  ```markdown
  ## Modules

  ### PowerShell Modules
  - [**RandomName**](src/powershell/modules/Utilities/RandomName/) (v2.1.0) – Windows-safe filename generation
  - [**Videoscreenshot**](src/powershell/modules/Media/Videoscreenshot/) (v3.0.1) – Video capture and screenshots
  - [**PostgresBackup**](src/powershell/modules/Database/PostgresBackup/) (v1.0.0) – Database backup utilities
  - [**PowerShellLoggingFramework**](src/powershell/modules/Core/Logging/PowerShellLoggingFramework/) (v1.0.0) – Structured logging
  - [**PurgeLogs**](src/powershell/modules/Core/Logging/PurgeLogs/) (v1.0.0) – Log retention management

  ### Python Modules
  - [**python_logging_framework**](src/python/modules/logging/) (v0.2.0) – Structured logging

  See individual module READMEs for detailed documentation.
  ```

## Acceptance Criteria
- [x] README.md created for all 5 undocumented modules
- [x] CHANGELOG.md created for all 5 undocumented modules
- [x] All READMEs include:
  - Overview
  - Version
  - Installation instructions
  - Function/API documentation
  - Usage examples (minimum 2 per module)
  - Dependencies
  - License
- [x] All PowerShell functions have comment-based help
- [x] Root README.md updated with module links
- [x] CHANGELOGs follow Keep a Changelog format (matching Videoscreenshot)
- [x] Documentation reviewed for accuracy

## Related Files
- `src/powershell/modules/Utilities/RandomName/README.md` (to be created)
- `src/powershell/modules/Database/PostgresBackup/README.md` (to be created)
- `src/powershell/modules/Core/Logging/PowerShellLoggingFramework/README.md` (to be created)
- `src/powershell/modules/Core/Logging/PurgeLogs/README.md` (to be created)
- `src/python/modules/logging/README.md` (to be created)
- CHANGELOGs for all above
- `README.md` (root, to be updated)
- `docs/specifications/logging_specification.md` (reference)

## Estimated Effort
**2-3 days** (documentation writing, review, examples)

## Dependencies
- Issue #006 (Folder Reorganization) – for final module paths
- Issue #002 (Versioning) – for version alignment

## References
- [Videoscreenshot README.md](../src/powershell/module/Videoscreenshot/README.md) – example format
- [Videoscreenshot CHANGELOG.md](../src/powershell/module/Videoscreenshot/CHANGELOG.md) – example format
- [PowerShell Comment-Based Help](https://learn.microsoft.com/en-us/powershell/scripting/developer/help/examples-of-comment-based-help)
