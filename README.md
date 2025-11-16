# My Scripts Collection

---

## Description

This repository serves as my personal project space for developing various utility scripts and automation tools. It's designed to streamline everyday tasks and personal data management. This collection includes a diverse range of scripts crafted for specific needs, ensuring efficient handling of my digital assets and workflows.

---

## Features and Highlights

This collection of scripts addresses a variety of personal computing and data management requirements:

* **Automated Data Backups:** Scripts for taking comprehensive backups of my computer's data and seamlessly uploading them to Google Drive.
* **Image Processing Utilities:** Specific utilities for personal image manipulation and processing tasks.
* **Database Management:** Tools for taking backups of personal PostgreSQL databases and managing their Data Definition Language (DDL).
* **Google Timeline Data Processing:** Utilities designed to process and derive insights from personal Google Timeline data.

---

## Repository Structure

This repository is organised into logical directories to enhance discoverability and maintainability following a recent refactoring. Understanding this structure will help you locate specific types of scripts:

* `src/`: Contains all source code for the scripts, further categorised by programming language.
    * * `src/powershell/`: PowerShell scripts for various tasks, including system administration and automation. This folder also contains the **Videoscreenshot** PowerShell module under `src/powershell/module/Videoscreenshot/` with its own README and changelog.
    * `src/python/`: Python scripts for data processing, specialised image processing, and other utility functions.
    * `src/batch/`: Batch scripts for common command-line operations. Log files are stored in `src/batch/logs/`.
    * `src/sql/`: SQL query files, organised by the specific external database they target (e.g., `gnucash_db`).
    * `src/common/`: Shared modules or functions used across different scripts (e.g., a common logging framework).
* `docs/`: Comprehensive documentation, usage guides, and any architectural notes.
* `config/`: Configuration files used by various scripts.
* `tests/`: Unit and integration tests for validating script functionality.
* `timeline_data/`: Database Definition Language (DDL) files, organised by database type, specifically for personal PostgreSQL databases.
* `Windows Task Scheduler/`: XML files defining tasks for Windows Task Scheduler.
* `.github/`: GitHub-specific files, such as workflow definitions.

---

## Prerequisites

To make use of the scripts in this repository, you'll need the following installed on your system:

* **PowerShell 5.1+ (Windows) or PowerShell 7+**
* **Python 3+**
* **Git**
* Python package requirements are script- or project-specific; see headers within individual scripts or any `requirements.txt` files colocated under `src/python/` subfolders.

---

## Logging

All scripts in this repository implement standardized logging to help with debugging, auditing, and monitoring script execution.

### Logging Standard

The repository follows a consistent logging format across all script types:

```
[YYYY-MM-DD HH:mm:ss.fff TIMEZONE] [LEVEL] [ScriptName] [HostName] [PID] Message
```

**Example:**
```
[2025-11-16 14:30:45.123 Eastern Standard Time] [INFO] [RunDeleteOldDownloads.bat] [WORKSTATION] [12345] Script started
```

### Log Levels

- **DEBUG** (10): Detailed diagnostic information
- **INFO** (20): General informational messages (default)
- **WARNING** (30): Warning messages for potentially problematic situations
- **ERROR** (40): Error messages for failures that don't stop execution
- **CRITICAL** (50): Critical errors that may stop execution

### PowerShell Scripts

PowerShell scripts use the **PowerShellLoggingFramework.psm1** module located in `src/common/`.

**Log File Location:** `<script_directory>/logs/<script_name>_powershell_YYYY-MM-DD.log`

**Usage Example:**
```powershell
Import-Module ".\src\common\PowerShellLoggingFramework.psm1"
Initialize-Logger -ScriptName "MyScript.ps1"
Write-LogInfo "Script started"
Write-LogError "An error occurred"
```

### Batch Scripts

Batch scripts (.bat, .cmd) implement inline logging functions that conform to the same standard format.

**Log File Location:** `src/batch/logs/<script_name>_batch_YYYY-MM-DD.log`

**Features:**
- Automatic log directory creation
- Timestamps with millisecond precision
- Hostname and Process ID tracking
- Multiple log levels (INFO, WARNING, ERROR)
- Same-day log file appending

**Available Batch Scripts:**
- **RunDeleteOldDownloads.bat** (v3.0.0): Wrapper for PowerShell file cleanup script
- **printcancel.cmd** (v2.0.0): Printer spooler maintenance utility

For detailed information about logging implementation and testing, see `docs/batch-logging-test-plan.md`.

---

## Contributing

Please note that at present, I am not inviting contributions to this personal project.

---

## Licence

This project is licensed under the [MIT Licence](LICENSE).

---

## Contact

For any questions or feedback, please feel free to open a Git issue within this repository.

---