# My Scripts Collection

[![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=manoj-bhaskaran_My-Scripts&metric=alert_status)](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)

**Version:** 2.0.0 | **Last Updated:** 2025-11-18

---

## Description

This repository serves as my personal project space for developing various utility scripts and automation tools. It's designed to streamline everyday tasks and personal data management. This collection includes a diverse range of scripts crafted for specific needs, ensuring efficient handling of my digital assets and workflows.

**Repository Stats:**
- 79 executable scripts (PowerShell, Python, SQL, Bash, Batch)
- 9 shared modules (logging, database utilities, media processing)
- 10 functional domains (backup, file management, media, cloud, git, etc.)
- Coherence Score: 7/10

---

## Features and Highlights

This collection of scripts addresses a variety of personal computing and data management requirements:

* **Automated Data Backups:** Scripts for taking comprehensive backups of my computer's data and seamlessly uploading them to Google Drive.
* **System Maintenance:** Automated Windows system health checks with scheduled tasks for SFC and DISM operations, including comprehensive logging and monitoring.
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
    * `src/batch/`: Batch scripts for common command-line operations. Log files are stored in `src/batch/logs/`.
    * `src/sql/`: SQL query files, organised by the specific external database they target (e.g., `gnucash_db`).
    * `src/common/`: Shared modules or functions used across different scripts, including:
        * **PowerShellLoggingFramework.psm1**: Centralized logging framework used by all PowerShell scripts
* `logs/`: Directory where PowerShell scripts write their log files (automatically created)
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

## Module Installation

This repository includes reusable PowerShell and Python modules that can be installed to your system for easy access across all scripts. Module installation is **optional** but recommended for the best experience.

### Quick Start

**Automated installation (recommended):**

```bash
# Install all modules (PowerShell + Python)
./scripts/install-modules.sh

# Force overwrite existing modules
./scripts/install-modules.sh --force
```

**Windows users** can run the script in Git Bash/WSL, or use PowerShell directly:

```powershell
# PowerShell modules only
./scripts/Deploy-Modules.ps1 -Force

# Python modules only
pip install -e .
```

### Available Modules

**PowerShell Modules:**
- **PostgresBackup** (v2.0.0) - PostgreSQL database backup with retention management
- **PowerShellLoggingFramework** (v2.0.0) - Cross-platform structured logging
- **PurgeLogs** (v2.0.0) - Log file purging and retention management
- **RandomName** (v2.1.0) - Windows-safe random filename generation
- **Videoscreenshot** (v3.0.2) - Video frame capture via VLC or GDI+

**Python Modules:**
- **python_logging_framework** (v0.2.0) - Cross-platform structured logging for Python

### After Installation

Once installed, modules can be used from any script:

```powershell
# Import and use PowerShell modules
Import-Module PostgresBackup
Backup-PostgresDatabase -dbname "mydb" -backup_folder "D:\backups" ...
```

```python
# Import and use Python modules
import python_logging_framework as plog
plog.initialise_logger(log_file_path="auto", level="INFO")
```

### Documentation

For detailed installation instructions, configuration, and troubleshooting:
- [Module Deployment Guide](docs/guides/module-deployment.md) - Complete guide to module installation and management

---

## Logging Framework

All PowerShell scripts in this repository use a centralized logging framework (`PowerShellLoggingFramework.psm1`) that provides:

* **Standardized Logging**: Consistent timestamp formats, log levels, and output structure
* **Automatic Log Files**: Logs are automatically written to `logs/{ScriptName}_powershell_YYYY-MM-DD.log`
* **Log Levels**: DEBUG (10), INFO (20), WARNING (30), ERROR (40), CRITICAL (50)
* **Flexible Output**: Plain-text or JSON structured logging
* **Metadata Support**: Optional metadata tagging for enhanced context

### Log Levels

The framework supports five log levels, controllable via the `-LogLevel` parameter when initializing the logger:

* **10 (DEBUG)**: Detailed information for debugging
* **20 (INFO)**: General informational messages (default)
* **30 (WARNING)**: Warning messages for potentially problematic situations
* **40 (ERROR)**: Error messages for failures
* **50 (CRITICAL)**: Critical errors that may cause script termination

### Example Usage

```powershell
# Import the logging framework
Import-Module "$PSScriptRoot\..\common\PowerShellLoggingFramework.psm1" -Force

# Initialize logger with script name and log level
Initialize-Logger -ScriptName "MyScript" -LogLevel 20

# Use logging functions
Write-LogInfo "Script started successfully"
Write-LogDebug "Processing file: example.txt"
Write-LogWarning "File not found, using default"
Write-LogError "Failed to connect to database"
```

For more details, see the [PowerShellLoggingFramework documentation](src/common/PowerShellLoggingFramework.psm1).

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

## Featured Scripts and Tools

### System Maintenance

* **[Monthly System Health Check](docs/system-health-check.md)** - Automated Windows system integrity checks (SFC/DISM) with scheduled tasks and comprehensive logging. Runs monthly to ensure your system stays healthy.
  * Scripts: `Invoke-SystemHealthCheck.ps1`, `Install-SystemHealthCheckTask.ps1`
  * Location: `src/powershell/`

### Video Processing

* **Videoscreenshot Module** - PowerShell module for automated video screenshot capture and image cropping.
  * Documentation: `src/powershell/module/Videoscreenshot/README.md`
  * Location: `src/powershell/module/Videoscreenshot/`

For detailed documentation on specific scripts, see the `docs/` directory or the script headers.

---

## Repository Review

A comprehensive review of this repository was conducted on **2025-11-16** using Claude.ai / code. The review assessed:
- Repository organization and coherence
- Folder structure and naming conventions
- Documentation completeness
- Test coverage and testing approach
- Tooling and automation

**Key Findings:**
- ✅ **Verdict**: Remain as single monolithic repository (not split)
- ✅ **Strengths**: Clear organization, sophisticated modules, exemplary logging specification, comprehensive CI/CD
- ⚠️ **Areas for Improvement**: Test infrastructure (0% coverage), naming consistency, documentation gaps

**Review Documents:**
- [Comprehensive Review Report](analysis/my-scripts-claude-review.md) – Detailed analysis and recommendations
- [Issue Drafts](analysis/my-scripts-issues/README.md) – 14 actionable improvement tasks

**Roadmap:**
The review generated a [prioritized roadmap](analysis/my-scripts-issues/README.md#recommended-implementation-order) with 4 phases:
1. **Foundation** (Weeks 1-2): Testing infrastructure, versioning, git hooks
2. **Standardization** (Weeks 3-4): Naming conventions, installation guide, module deployment
3. **Organization** (Weeks 5-6): Folder restructuring, documentation, shared utilities
4. **Polish** (Weeks 7-8): Architecture docs, code formatting, automated releases

---

## Versioning

This repository follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes to script interfaces or module APIs
- **MINOR**: New features (new scripts, module enhancements)
- **PATCH**: Bug fixes and minor improvements

Current version: **2.0.0**

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

---

## Testing

This repository includes comprehensive testing infrastructure to ensure code quality and reliability.

### Running Tests

**Python Tests**:
```bash
# Install dependencies
pip install -r requirements.txt

# Run all tests
pytest tests/python

# Run with coverage
pytest tests/python --cov=src/python --cov=src/common --cov-report=term-missing
```

**PowerShell Tests**:
```powershell
# Install Pester
Install-Module -Name Pester -Force -Scope CurrentUser

# Run all tests
Invoke-Pester -Path tests/powershell
```

### Test Coverage

Current coverage targets:
- Shared modules: ≥30%
- Core utilities: ≥50%
- Overall project: ≥25%

Coverage reports are automatically generated in CI and uploaded to [SonarCloud](https://sonarcloud.io/project/overview?id=manoj-bhaskaran_My-Scripts).

### Documentation

- [Testing Guide](tests/README.md) - How to run and write tests
- [Testing Standards](docs/guides/testing.md) - Best practices and guidelines

---

## Naming Conventions

All scripts in this repository follow standardized naming conventions based on language best practices:

### PowerShell Scripts

PowerShell scripts use the **Verb-Noun** pattern with PascalCase (e.g., `Get-FileHandle.ps1`, `Backup-Database.ps1`):
- **Verb**: Must be from the [PowerShell Approved Verbs list](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- **Noun**: Singular, descriptive noun in PascalCase
- **Examples**: `Clear-LogFile.ps1`, `Remove-MergedGitBranch.ps1`, `Invoke-PostCommitHook.ps1`

### Python Scripts

Python scripts use **snake_case** per [PEP 8](https://peps.python.org/pep-0008/) (e.g., `csv_to_gpx.py`, `find_duplicate_images.py`):
- All lowercase letters
- Words separated by underscores (`_`)
- Descriptive and concise
- **Examples**: `cloudconvert_utils.py`, `extract_timeline_locations.py`, `python_logging_framework.py`

### Documentation

For complete naming standards, examples, and migration guidance:
- [Naming Conventions Guide](docs/guides/naming-conventions.md) - Comprehensive naming standards with examples and FAQs
- [Rename Mapping](docs/RENAME_MAPPING.md) - Complete list of renamed scripts with justifications

---

## Git Hooks

This repository uses git hooks for quality enforcement to catch issues before they're committed or pushed.

### Active Hooks

- **pre-commit**: Validates code quality before commits
  - Checks for debug statements
  - Runs PowerShell linting (PSScriptAnalyzer)
  - Runs Python linting (pylint)
  - Warns about large files (>10MB)

- **commit-msg**: Enforces [Conventional Commits](https://www.conventionalcommits.org/) format
  - Required format: `type(scope): description`
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`
  - Example: `feat(logging): add structured JSON output`

- **post-commit**: Runs repository-specific automation
  - Mirrors committed files to staging directory
  - Deploys PowerShell modules per configuration
  - Requires PowerShell 7+ (pwsh)

- **post-merge**: Runs post-merge automation
  - Updates staging directory with merged changes
  - Deploys updated modules
  - Handles dependency updates and log rotation

### Installation

After cloning the repository, install the hooks:

```bash
./scripts/install-hooks.sh
```

The hooks will be installed to `.git/hooks/` and will run automatically.

### Bypassing Hooks

To bypass hooks for emergency commits (use sparingly):

```bash
git commit --no-verify -m "fix: emergency hotfix"
```

### Documentation

See [docs/guides/git-hooks.md](docs/guides/git-hooks.md) for complete documentation including:
- Detailed hook behavior and requirements
- Installation and troubleshooting
- Testing procedures
- When and how to bypass hooks safely
- FAQ and common issues

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