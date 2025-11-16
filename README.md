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
* **Unified Logging Framework:** Cross-platform logging system providing standardized log formats across Python, PowerShell, and Batch scripts with built-in retention management.

---

## Repository Structure

This repository is organised into logical directories to enhance discoverability and maintainability following a recent refactoring. Understanding this structure will help you locate specific types of scripts:

* `src/`: Contains all source code for the scripts, further categorised by programming language.
    * * `src/powershell/`: PowerShell scripts for various tasks, including system administration and automation. This folder also contains the **Videoscreenshot** PowerShell module under `src/powershell/module/Videoscreenshot/` with its own README and changelog.
    * `src/python/`: Python scripts for data processing, specialised image processing, and other utility functions.
    * `src/batch/`: Batch scripts for common command-line operations.
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

## Logging Framework

This repository includes a **standardized, cross-platform logging framework** that ensures consistent log formatting and management across all scripts.

### Quick Start

**Python:**
```python
import python_logging_framework as plog
plog.initialise_logger(log_file_path="auto", level="INFO")
plog.log_info("Script started successfully")
```

**PowerShell:**
```powershell
Import-Module "PowerShellLoggingFramework.psm1"
Initialize-Logger -LogLevel 20
Write-LogInfo "Script started successfully"
```

### Key Features

- **Unified Format:** Consistent log structure across Python, PowerShell, and Batch scripts
- **Multiple Log Levels:** DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Structured Metadata:** Optional key-value pairs for enhanced context
- **Automatic Management:** Auto-creates log directories, handles file rotation
- **Log Purge Tools:** Built-in retention management (default: 30 days)
- **Timezone Support:** Timestamps in IST (Asia/Kolkata) by default
- **JSON Output:** Optional structured logging for aggregation tools

### Documentation

- **Full Specification:** [`docs/logging_specification.md`](docs/logging_specification.md)
- **Usage Guidelines:** [`CONTRIBUTING.md`](CONTRIBUTING.md#logging-framework) - Comprehensive examples and patterns
- **Log Purge Guide:** [`CONTRIBUTING.md`](CONTRIBUTING.md#log-purge-mechanism) - Retention management and scheduling

All logs are stored in the `logs/` directory with the naming pattern: `<script_name>_<language>_YYYY-MM-DD.log`

---

## Contributing

Please note that at present, I am not inviting contributions to this personal project. However, the [`CONTRIBUTING.md`](CONTRIBUTING.md) file documents coding standards, logging guidelines, and best practices used throughout this repository.

---

## Licence

This project is licensed under the [MIT Licence](LICENSE).

---

## Contact

For any questions or feedback, please feel free to open a Git issue within this repository.

---