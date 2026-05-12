# My Scripts Collection

[![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=manoj-bhaskaran_My-Scripts&metric=alert_status)](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)
[![codecov](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![Python Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=python)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![PowerShell Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=powershell)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![Code Formatting](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/code-formatting.yml/badge.svg)](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/code-formatting.yml)

**Version:** 2.12.10 | **Last Updated:** 2026-04-05

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

- **Automated Data Backups:** Scripts for taking comprehensive backups of my computer's data and seamlessly uploading them to Google Drive.
- **System Maintenance:** Automated Windows system health checks with scheduled tasks for SFC and DISM operations, including comprehensive logging and monitoring.
- **Image Processing Utilities:** Specific utilities for personal image manipulation and processing tasks.
- **Database Management:** Tools for taking backups of personal PostgreSQL databases and managing their Data Definition Language (DDL).
- **Google Timeline Data Processing:** Utilities designed to process and derive insights from personal Google Timeline data.
- **Unified Logging Framework:** Cross-platform logging system providing standardized log formats across Python, PowerShell, and Batch scripts with built-in retention management.

---

## Repository Structure

This repository is organized by **programming language** and **functional domain** to enhance discoverability and maintainability. Understanding this structure will help you locate specific types of scripts:

- `src/` – Source code organized by language and domain
  - `src/powershell/` – PowerShell scripts and modules
    - `backup/` – Database backup and synchronization scripts
    - `file-management/` – File distribution, copying, archiving
    - `system/` – System cleanup and maintenance
    - `git/` – Git automation and hooks
    - `media/` – Image and video processing
    - `cloud/` – Cloud service integrations
    - `automation/` – General automation utilities
    - `modules/` – Reusable PowerShell modules
      - `Core/Logging/` – Logging frameworks (PowerShellLoggingFramework, PurgeLogs)
      - `Database/PostgresBackup/` – PostgreSQL backup utilities
      - `Utilities/RandomName/` – Random name generation
      - `Media/Videoscreenshot/` – Video screenshot capture module
  - `src/python/` – Python scripts and modules
    - `data/` – Data processing and transformation
    - `cloud/` – Google Drive and cloud service integrations
    - `media/` – Image processing and manipulation
    - `modules/` – Shared Python modules
      - `logging/` – Python logging framework
      - `auth/` – Authentication modules (Google Drive, elevation)
  - `src/sql/` – SQL DDL files organized by database
    - `gnucash/` – GnuCash database schemas
    - `timeline/` – Timeline data schemas
    - `job_scheduler/` – Job scheduler schemas
  - `src/sh/` – Bash scripts
  - `src/batch/` – Windows batch scripts
- `config/` – Configuration files
  - `config/modules/` – Module deployment configurations
  - `config/tasks/` – Windows Task Scheduler task definitions
- `docs/` – Documentation, specifications, guides
- `tests/` – Unit and integration tests
- `logs/` – Log files (per logging specification)
- `.github/` – GitHub Actions workflows and configurations

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

Quick start assumes **PowerShell**, **Python 3.10+**, and **Git** are installed.

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

**Configuration Guide**: See [config/CONFIG_GUIDE.md](config/CONFIG_GUIDE.md) for detailed configuration instructions.

---

## Module Installation

This repository includes reusable PowerShell and Python modules. Module installation is **optional** but recommended for the best experience.

```bash
# Install all modules (PowerShell + Python)
./scripts/install-modules.sh

# Python modules only
pip install -e .
```

```powershell
# PowerShell modules only
./scripts/Deploy-Modules.ps1 -Force
```

**Available Modules:**

- **[RandomName](src/powershell/modules/Utilities/RandomName/)** – Windows-safe random filename generation
- **[Videoscreenshot](src/powershell/modules/Media/Videoscreenshot/)** – Video frame capture via VLC or GDI+
- **[PostgresBackup](src/powershell/modules/Database/PostgresBackup/)** – PostgreSQL database backup with retention management
- **[PowerShellLoggingFramework](src/powershell/modules/Core/Logging/PowerShellLoggingFramework/)** – Cross-platform structured logging
- **[PurgeLogs](src/powershell/modules/Core/Logging/PurgeLogs/)** – Log file purging and retention management
- **[FileSystem](src/powershell/modules/Core/FileSystem/)** – Common file system operations
- **[FileQueue](src/powershell/modules/FileManagement/FileQueue/)** – File queue management for distribution operations
- **[FileDistributor](src/powershell/modules/FileManagement/FileDistributor/)** – Support helpers for FileDistributor orchestration
- **[AdbHelpers](src/powershell/modules/Android/AdbHelpers/)** – Android Debug Bridge helpers for device checks and shell execution
- **[python_logging_framework](src/python/modules/logging/)** – Cross-platform structured logging for Python

See individual module READMEs for detailed documentation, usage examples, and API reference.
For installation troubleshooting, see the [Module Deployment Guide](docs/guides/module-deployment.md).

---

## Logging

This repository includes a standardized, cross-platform logging framework for Python, PowerShell, and Batch scripts with consistent formatting and centralized log handling.

Log levels: DEBUG (10), INFO (20), WARNING (30), ERROR (40), CRITICAL (50).

```python
import python_logging_framework as plog
plog.initialise_logger(log_file_path="auto", level="INFO")
plog.log_info("Script started successfully")
```

```powershell
Import-Module "PowerShellLoggingFramework.psm1"
Initialize-Logger -LogLevel 20
Write-LogInfo "Script started successfully"
```

See [docs/logging_specification.md](docs/logging_specification.md) for the full logging standard and [CONTRIBUTING.md](CONTRIBUTING.md#logging-framework) for usage guidelines.

---

## Featured Scripts and Tools

### System Maintenance

- **[Monthly System Health Check](docs/system-health-check.md)** - Automated Windows system integrity checks (SFC/DISM) with scheduled tasks and comprehensive logging. Runs monthly to ensure your system stays healthy.
  - Scripts: `Invoke-SystemHealthCheck.ps1`, `Install-SystemHealthCheckTask.ps1`
  - Location: `src/powershell/`

### Video Processing

- **Videoscreenshot Module** - PowerShell module for automated video screenshot capture and image cropping.
  - Documentation: `src/powershell/module/Videoscreenshot/README.md`
  - Location: `src/powershell/module/Videoscreenshot/`

For detailed documentation on specific scripts, see the `docs/` directory or the script headers.

---

## Versioning

This repository follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to script interfaces or module APIs
- **MINOR**: New features (new scripts, module enhancements)
- **PATCH**: Bug fixes and minor improvements
  Current version: **2.12.10**
  See [CHANGELOG.md](CHANGELOG.md) for release history and [docs/guides/versioning.md](docs/guides/versioning.md) for the release/versioning workflow.

CHANGELOG maintenance note: entries older than the current minor release line are condensed to architectural highlights; full detail remains available through `git log` and release tags. The CHANGELOG legend uses `#NNN` for GitHub issue references unless otherwise prefixed.

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

This repository uses **mypy** for static type checking to catch type-related issues early.
Type checking runs in pre-commit and CI/CD as informational, non-blocking feedback.
Configuration lives in [mypy.ini](mypy.ini), and you can run it locally with `mypy src/python --config-file=mypy.ini`.

---

## Security

Automated security scanning via [pip-audit](https://pypi.org/project/pip-audit/) runs on every push, pull request, and weekly schedule; [GitHub Dependency Review](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review) additionally annotates pull requests. Builds fail on detected vulnerabilities to ensure prompt remediation.

```bash
# Run a local security scan
pip-audit -r requirements.lock --desc
```

See [`.github/workflows/security-scan.yml`](.github/workflows/security-scan.yml) for implementation details.

---

## Naming Conventions

Scripts follow language-standard naming conventions (PowerShell Verb-Noun, Python snake_case). See [docs/guides/naming-conventions.md](docs/guides/naming-conventions.md).

---

## Git Hooks

Git hooks provide lightweight quality and automation checks in your local workflow.

- **pre-commit**: Runs code-quality checks before commit.
- **commit-msg**: Enforces [Conventional Commits](https://www.conventionalcommits.org/) message format.
- **post-commit**: Runs repository automation after each commit.
- **post-merge**: Runs repository automation after merges.

Install hooks after cloning:

```bash
./scripts/install-hooks.sh
```

See [docs/guides/git-hooks.md](docs/guides/git-hooks.md) for full behavior, troubleshooting, and testing details.

---

## Code Style

Code is formatted with Black (Python), PSScriptAnalyzer (PowerShell), and SQLFluff (SQL). See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/guides/code-style.md](docs/guides/code-style.md).

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

- [Configuration Guide](config/CONFIG_GUIDE.md) - Setup, local deployment options, and troubleshooting.
- [Environment Variables Reference](docs/ENVIRONMENT.md) - Variable definitions, credential guidance, and quick reference.

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
