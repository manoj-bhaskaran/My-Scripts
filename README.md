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
    * `src/powershell/`: PowerShell scripts for various tasks, including system administration and automation.
    * `src/python/`: Python scripts for data processing, specialised image processing, and other utility functions.
    * `src/batch/`: Batch scripts for common command-line operations.
    * `src/common/`: Shared modules or functions used across different scripts (e.g., a common logging framework).
* `docs/`: Comprehensive documentation, usage guides, and any architectural notes.
* `config/`: Configuration files used by various scripts.
* `tests/`: Unit and integration tests for validating script functionality.
* `timeline_data/`: Database Definition Language (DDL) files, organised by database type, specifically for personal PostgreSQL databases.
* `windows_task_scheduler/`: XML files defining tasks for Windows Task Scheduler.
* `.github/`: GitHub-specific files, such as workflow definitions.

---

## Prerequisites

To make use of the scripts in this repository, you'll need the following installed on your system:

* **PowerShell 7+**
* **Python 3+**
* **Git**
* Specific Python package requirements can be found in the `requirements.txt` file located in the root of the repository.

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