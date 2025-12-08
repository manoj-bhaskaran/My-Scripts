# My Scripts Collection

[![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=manoj-bhaskaran_My-Scripts&metric=alert_status)](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)
[![codecov](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![Python Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=python)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![PowerShell Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=powershell)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![Code Formatting](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/code-formatting.yml/badge.svg)](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/code-formatting.yml)

**Version:** 2.7.1 | **Last Updated:** 2025-12-06

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

This repository is organized by **programming language** and **functional domain** to enhance discoverability and maintainability. Understanding this structure will help you locate specific types of scripts:

* `src/` – Source code organized by language and domain
  * `src/powershell/` – PowerShell scripts and modules
    * `backup/` – Database backup and synchronization scripts
    * `file-management/` – File distribution, copying, archiving
    * `system/` – System cleanup and maintenance
    * `git/` – Git automation and hooks
    * `media/` – Image and video processing
    * `cloud/` – Cloud service integrations
    * `automation/` – General automation utilities
    * `modules/` – Reusable PowerShell modules
      * `Core/Logging/` – Logging frameworks (PowerShellLoggingFramework, PurgeLogs)
      * `Database/PostgresBackup/` – PostgreSQL backup utilities
      * `Utilities/RandomName/` – Random name generation
      * `Media/Videoscreenshot/` – Video screenshot capture module
  * `src/python/` – Python scripts and modules
    * `data/` – Data processing and transformation
    * `cloud/` – Google Drive and cloud service integrations
    * `media/` – Image processing and manipulation
    * `modules/` – Shared Python modules
      * `logging/` – Python logging framework
      * `auth/` – Authentication modules (Google Drive, elevation)
  * `src/sql/` – SQL DDL files organized by database
    * `gnucash/` – GnuCash database schemas
    * `timeline/` – Timeline data schemas
    * `job_scheduler/` – Job scheduler schemas
  * `src/sh/` – Bash scripts
  * `src/batch/` – Windows batch scripts
* `config/` – Configuration files
  * `config/modules/` – Module deployment configurations
  * `config/tasks/` – Windows Task Scheduler task definitions
* `docs/` – Documentation, specifications, guides
* `tests/` – Unit and integration tests
* `logs/` – Log files (per logging specification)
* `.github/` – GitHub Actions workflows and configurations

---

## Architecture

For architectural overview, design decisions, and technical documentation, see:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** – High-level architecture, design principles, and key design decisions
- **[Database Schemas](docs/architecture/database-schemas.md)** – PostgreSQL database schemas with ER diagrams (Timeline, GnuCash, Job Scheduler)
- **[Module Dependencies](docs/architecture/module-dependencies.md)** – Module dependency graphs and relationships (PowerShell and Python)
- **[External Integrations](docs/architecture/external-integrations.md)** – External service integrations (Google Drive, CloudConvert, PostgreSQL, VLC, Task Scheduler)
- **[Data Flows](docs/architecture/data-flows.md)** – Data flow diagrams for key workflows (backup, timeline processing, log management)

These documents provide comprehensive insights into the system design, helping you understand how components interact and make informed decisions when modifying or extending the codebase.

---

## Installation

For comprehensive installation instructions, see **[INSTALLATION.md](INSTALLATION.md)**.

**Quick Start:**

```bash
# 1. Clone repository
git clone https://github.com/manoj-bhaskaran/My-Scripts.git
cd My-Scripts

# 2. Configure repository (interactive wizard)
./scripts/Initialize-Configuration.ps1

# 3. Install Python dependencies (deterministic)
pip install -r requirements.lock

# Or install the latest compatible versions within the supported ranges
pip install -r requirements.txt

# 4. Deploy PowerShell modules
./scripts/Deploy-Modules.ps1 -Force

# 5. Install Git hooks
./scripts/install-hooks.sh

# 6. Verify installation and configuration
./scripts/Verify-Configuration.ps1
```

The [INSTALLATION.md](INSTALLATION.md) guide includes:
- Step-by-step installation for Windows, Linux, and macOS
- Prerequisites and system requirements
- Configuration setup (local deployment, environment variables, secrets)
- Optional software installation (VLC, ADB, PostgreSQL)
- Module installation and verification
- Comprehensive troubleshooting guide

The repository now ships with **dual dependency manifests**:

- Use `requirements.lock` for deterministic, reproducible installs (CI, production machines).
- Use `requirements.txt` for local development when you want the latest compatible releases within vetted version ranges.

**Configuration Guide**: See [config/CONFIG_GUIDE.md](config/CONFIG_GUIDE.md) for detailed configuration instructions.

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
- **[RandomName](src/powershell/modules/Utilities/RandomName/)** (v2.1.0) – Windows-safe random filename generation
- **[Videoscreenshot](src/powershell/modules/Media/Videoscreenshot/)** (v3.0.2) – Video frame capture via VLC or GDI+
- **[PostgresBackup](src/powershell/modules/Database/PostgresBackup/)** (v2.0.0) – PostgreSQL database backup with retention management
- **[PowerShellLoggingFramework](src/powershell/modules/Core/Logging/PowerShellLoggingFramework/)** (v2.0.0) – Cross-platform structured logging
- **[PurgeLogs](src/powershell/modules/Core/Logging/PurgeLogs/)** (v2.0.0) – Log file purging and retention management
- **[FileSystem](src/powershell/modules/Core/FileSystem/)** (v1.0.0) – Common file system operations (directory creation, file accessibility checks, path validation, file locking detection)
- **[FileQueue](src/powershell/modules/FileManagement/FileQueue/)** (v1.0.0) – File queue management for distribution operations with state persistence and session tracking

**Python Modules:**
- **[python_logging_framework](src/python/modules/logging/)** (v0.1.0) – Cross-platform structured logging for Python

See individual module READMEs for detailed documentation, usage examples, and API reference.

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
* **Precomputed Defaults**: The PowerShell module caches its default log directory on import to minimize repeated path resolution during initialization

> **Console output guidance:** Production scripts should log via `PowerShellLoggingFramework`. Lightweight utilities that skip logger initialization should use `Write-Information` (with `-InformationAction Continue`) for user-facing messages so output remains redirectable. Reserve `Write-Host` for interactive, color-coded tools only and document its intentional use.

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
pip install -r requirements.lock

# Run all tests
pytest tests/python

# Run with coverage
pytest tests/python --cov=src/python --cov=src/common --cov-report=term-missing

# Focused data-transformation checks (CSV→GPX, timeline parsing)
pytest tests/python/unit/test_csv_to_gpx.py tests/python/unit/test_extract_timeline_locations.py

# Safety-critical Google Drive delete/recover tests (fully mocked, no API calls)
pytest tests/python/unit/test_google_drive_delete.py tests/python/unit/test_gdrive_recover.py
```

**PowerShell Tests**:
```powershell
# Install Pester
Install-Module -Name Pester -Force -Scope CurrentUser

# Run all tests
Invoke-Pester -Path tests/powershell
```

**Integration Tests (PostgreSQL + PowerShell)**:
```powershell
# Requires PostgreSQL utilities on PATH: initdb, pg_ctl, psql, pg_dump, pg_restore
# Install Pester as shown above

# Run integration suite
Invoke-Pester -Path tests/integration
```

### Test Coverage

We maintain test coverage to ensure code quality and reliability:

**Coverage Status:**
- **Phase 1 Complete**: Infrastructure established, regression prevention in place
- **Phase 2 In Progress**: Core shared modules tested
  - `python_logging_framework.py`: 91% coverage ✅
  - `error_handling.py`: 84% coverage ✅
  - `file_operations.py`: 63% coverage ✅
- **Phase 2 Target** (Months 3-4): 15% coverage, focus on shared modules
- **Phase 3 Target** (Months 5-6): 30% overall coverage
- **Long-term Target**: 50%+ overall (60% Python, 50% PowerShell)

See [Coverage Roadmap](docs/COVERAGE_ROADMAP.md) for detailed ramp-up plan.

**View Coverage Reports:**
- [Codecov Dashboard](https://codecov.io/gh/manoj-bhaskaran/My-Scripts) - Detailed coverage analytics and trends
- [SonarCloud Quality Gate](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts) - Code quality and coverage metrics

**Local Coverage Reports:**
```bash
# Python coverage
pytest tests/python --cov=src/python --cov=src/common --cov-report=html
open coverage/python/html/index.html  # View HTML report

# PowerShell coverage
.\tests\powershell\Invoke-Tests.ps1
# View coverage output in terminal
```

Coverage reports are automatically generated in CI/CD and uploaded to both Codecov and SonarCloud for trend tracking and analysis.

### Documentation

- [Testing Guide](tests/README.md) - How to run and write tests
- [Testing Standards](docs/guides/testing.md) - Best practices and guidelines

---

## Code Quality

### Type Checking (Python)

This repository uses **mypy** for static type checking to improve code quality and catch type-related errors early.

**Run Type Checking Locally:**
```bash
# Install dependencies (if not already installed)
pip install -r requirements.txt

# Run mypy on Python source
mypy src/python --config-file=mypy.ini

# Type errors are informational only - they don't block commits or CI
```

**Type Checking Configuration:**
- Configuration file: `mypy.ini`
- Python version: 3.11
- Mode: Permissive (Phase 1 - Infrastructure)
- Tests excluded initially

**Integration:**
- ✅ **Pre-commit hook** - Shows type errors locally (informational, non-blocking)
- ✅ **CI/CD** - Runs on every push and PR (informational only)
- ✅ **Type stubs** - Includes stubs for `requests` and `tqdm`

**Current Status:**
- Phase 1 (Infrastructure): ✅ Complete
- Phase 2 (Type Hints): Planned - Will add type hints to core modules
- 117 type errors identified across 10 files for future cleanup

Type checking helps maintain code quality without disrupting the existing workflow.

---

## Security

### Dependency Security Scanning

This repository includes automated security scanning to detect vulnerabilities in Python dependencies.

**Security Tools:**
- **[Safety](https://pyup.io/safety/)** - Checks dependencies against known vulnerability databases
- **[pip-audit](https://pypi.org/project/pip-audit/)** - PyPI package auditor (OSV and PyPI Advisory databases)
- **[GitHub Dependency Review](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review)** - Native GitHub security scanning

**Automated Scans:**
- ✅ **On every push and PR** - Runs safety and pip-audit checks
- ✅ **Weekly schedule** - Automated scans every Sunday at 2:00 AM UTC
- ✅ **Pre-commit hook** - Validates dependencies before allowing commits
- ✅ **Pull request reviews** - GitHub Dependency Review action comments on PRs

**Running Security Scans Locally:**

```bash
# Install security scanning tools
pip install safety pip-audit

# Run safety check
safety check -r requirements.txt

# Run pip-audit
pip-audit -r requirements.txt --desc

# Run both via pre-commit
pre-commit run python-safety-dependencies-check --all-files
```

**Workflow Configuration:**
- Security scans are configured in `.github/workflows/security-scan.yml`
- Pre-commit hook configured in `.pre-commit-config.yaml`
- Reports are uploaded as GitHub Actions artifacts (30-day retention)
- Builds fail on detected vulnerabilities to ensure prompt remediation

**Enabling Dependabot (Recommended):**

To enable Dependabot security alerts on GitHub:
1. Go to **Settings** → **Security & analysis**
2. Enable **Dependabot alerts**
3. Enable **Dependabot security updates** (optional - auto-creates PRs for vulnerable dependencies)

See the [Security Scan workflow](.github/workflows/security-scan.yml) for implementation details.

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
- **Integration coverage**: `tests/integration/GitHooks.Integration.Tests.ps1` exercises staging mirror updates, deployment targets, and configuration handling to validate the end-to-end hook workflow.

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

## Code Style

This repository uses automated formatters to maintain consistent code style across all languages. Code formatting is enforced through pre-commit hooks and CI/CD pipelines.

### Formatters

- **Python**: [Black](https://github.com/psf/black) (line length: 100, target: Python 3.11)
- **PowerShell**: [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) / Invoke-Formatter (OTBS style, 4-space indentation)
- **SQL**: [SQLFluff](https://www.sqlfluff.com/) (PostgreSQL dialect, uppercase keywords)

### Format All Code

Use the convenience script to format all code:

```bash
./scripts/format-all.sh
```

Or format by language:

```bash
# Python
black src/python/ tests/python/

# PowerShell
pwsh ./scripts/Format-PowerShellCode.ps1

# SQL
sqlfluff fix src/sql/
```

### Editor Integration

The repository includes:
- **`.editorconfig`** - Universal editor configuration
- **`.vscode/settings.json`** - VS Code specific settings with format-on-save enabled

Recommended VS Code extensions:
- [Black Formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter)
- [PowerShell](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)
- [SQLFluff](https://marketplace.visualstudio.com/items?itemName=dorzey.vscode-sqlfluff)
- [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)

### Pre-Commit Enforcement

Code formatting is automatically checked on commit via pre-commit hooks:
- Black formatting check for Python
- PSScriptAnalyzer formatting check for PowerShell
- SQLFluff linting and auto-fix for SQL

### CI/CD Enforcement

The [Code Formatting workflow](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/code-formatting.yml) runs on all pull requests and pushes, ensuring all code meets formatting standards.

### CI/CD Caching

Caching keeps pipeline runs fast and repeatable:

- **Python (pip)**: `actions/setup-python@v5` enables the built-in pip cache for formatting checks, security scans, SonarCloud analysis, and module validation. Each step reports cache status via `Python cache hit: ...` so misses are visible in the logs.
- **npm (sql-lint)**: SQL linting in the SonarCloud workflow restores the `~/.npm` cache with the key `${{ runner.os }}-npm-sql-lint-v1` before installing `sql-lint`, with an explicit cache hit/miss message.
- **PowerShell modules**: PowerShell linting and module deployment cache the user module path derived from the first entry in `$PSModulePath`, using the shared key `${{ runner.os }}-psmodules-v1` and logging hit/miss status for traceability.

These caches are safe to invalidate by bumping the cache key suffix (e.g., `-v2`) whenever dependency versions change.

### Documentation

For detailed code style guidelines, configuration, and troubleshooting:
- [Code Style Guide](docs/guides/code-style.md) - Comprehensive formatting guide for all languages

---

## Configuration

**Quick Configuration:**

```powershell
# Interactive configuration wizard
.\scripts\Initialize-Configuration.ps1

# Validate configuration
.\scripts\Verify-Configuration.ps1
```

**Configuration Resources:**
- **[Configuration Guide](config/CONFIG_GUIDE.md)** - Comprehensive configuration documentation
  - Local deployment settings (git hooks)
  - Module deployment configuration
  - Environment variables
  - Secrets management (database passwords)
  - Platform-specific setup
  - Troubleshooting guide
- **[Environment Variables Reference](docs/ENVIRONMENT.md)** - Complete environment variable documentation
  - All variables with descriptions and formats
  - How to obtain API keys and credentials
  - Security best practices
  - Troubleshooting guide
  - Quick reference tables

**Module Deployment Configuration (TOML-based):**

The repository uses a modern TOML-based configuration system for PowerShell module deployment:

- **`psmodule.toml`** - Main module configuration (committed to git)
  - Defines all 8 PowerShell modules and their deployment settings
  - Single source of truth for module deployment
  - Supports module dependencies, auto-deployment, and testing options

- **`psmodule.local.toml`** - User-specific overrides (gitignored)
  - Override deployment paths and settings per-user/per-machine
  - Copy from `psmodule.local.toml.example` and customize
  - Allows local development without modifying shared config

**Migration from Legacy Configuration:**

```powershell
# Migrate from old deployment.txt to new psmodule.toml
.\scripts\Migrate-ModuleConfig.ps1

# Deploy modules using new configuration
.\scripts\Deploy-Modules.ps1 -Force
```

**Benefits:**
- ✅ Single configuration file (reduced from 3 files to 1)
- ✅ Standard TOML format with comments support
- ✅ Schema validation possible
- ✅ Easier to edit and understand
- ✅ Supports module dependencies

---

## Versioning and Releases

This repository follows [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 2.0.0)
- Current Version: **2.3.1** (see [VERSION](VERSION) file)

### Release Process

Releases are automated using GitHub Actions:

1. **Bump version** using the version bump script:
   ```bash
   ./scripts/bump-version.sh [major|minor|patch]
   ```

2. **Update CHANGELOG.md** with release notes

3. **Create and push tag** to trigger release:
   ```bash
   git commit -am "chore: release vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin main --tags
   ```

The workflow automatically:
- Extracts changelog for the version
- Creates GitHub Release
- Publishes release notes

### Documentation

- **[Versioning Guide](docs/guides/versioning.md)** - Complete versioning and release documentation
- **[Release Checklist](.github/RELEASE_CHECKLIST.md)** - Pre-release and post-release tasks
- **[CHANGELOG.md](CHANGELOG.md)** - Detailed change history

### Version History

All releases are available on the [Releases](https://github.com/manoj-bhaskaran/My-Scripts/releases) page.

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
# test change
# test
