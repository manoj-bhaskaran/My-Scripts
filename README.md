# My Scripts Collection

[![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=manoj-bhaskaran_My-Scripts&metric=alert_status)](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)

**Version:** 1.0.0 | **Last Updated:** 2025-11-16

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
* **Image Processing Utilities:** Specific utilities for personal image manipulation and processing tasks.
* **Database Management:** Tools for taking backups of personal PostgreSQL databases and managing their Data Definition Language (DDL).
* **Google Timeline Data Processing:** Utilities designed to process and derive insights from personal Google Timeline data.

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

Current version: **1.0.0**

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

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