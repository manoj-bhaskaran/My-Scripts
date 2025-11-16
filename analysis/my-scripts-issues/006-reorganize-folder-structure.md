# Reorganize Folder Structure by Domain

## Priority
**MODERATE** 🟡

## Background
The My-Scripts repository currently organizes scripts **by language** only:

```
src/
├── powershell/          # 30+ scripts in single flat folder
├── python/              # 11+ scripts in single flat folder
├── common/              # Shared modules
├── sql/                 # Mixed database scripts
├── sh/                  # 1 Bash script
└── batch/               # 2 Batch scripts
```

**Issues:**
- All PowerShell scripts in one folder (difficult to navigate)
- No grouping by functionality (backup, git, media, etc.)
- Configuration files scattered (Windows Task Scheduler in root, timeline_data in root)
- Difficult to find related scripts
- No clear module boundaries

**Functional Domains Identified:**
1. Database/Backup (12 scripts)
2. File Management (8 scripts)
3. System Cleanup (6 scripts)
4. Cloud/Google Services (5 scripts)
5. Media Processing (5 scripts)
6. Git Operations (3 scripts)
7. Logging/Monitoring (3 scripts)
8. Data Processing (3 scripts)

## Objectives
- Reorganize scripts by **domain/functionality** while preserving language separation
- Move scattered configuration files to logical locations
- Create per-folder README files
- Preserve git history during reorganization
- Update all import paths and references

## Tasks

### Phase 1: Design Target Structure
- [ ] Finalize folder hierarchy (see Proposed Structure below)
- [ ] Map each script to target folder
- [ ] Identify shared scripts that belong in multiple domains
- [ ] Plan module reorganization (src/powershell/modules/ → categorized)

### Phase 2: Create Migration Plan
- [ ] Create `docs/FOLDER_MIGRATION.md` mapping old → new paths:
  ```markdown
  | Old Path | New Path | Domain |
  |----------|----------|--------|
  | src/powershell/gnucash_pg_backup.ps1 | src/powershell/backup/Backup-GnucashDatabase.ps1 | Backup |
  | src/powershell/FileDistributor.ps1 | src/powershell/file-management/Invoke-FileDistributor.ps1 | File Mgmt |
  | ... | ... | ... |
  ```
- [ ] Combine with Issue #003 (Naming) if both applied together

### Phase 3: Execute Reorganization (Preserve History)
Use `git mv` to preserve history:

**PowerShell Scripts:**
```bash
# Create domain folders
mkdir -p src/powershell/{backup,file-management,system,git,media,automation}
mkdir -p src/powershell/modules/{Core,Database,Utilities,Media}

# Move backup scripts
git mv src/powershell/gnucash_pg_backup.ps1 src/powershell/backup/
git mv src/powershell/job_scheduler_pg_backup.ps1 src/powershell/backup/
git mv src/powershell/timeline_data_pg_backup.ps1 src/powershell/backup/
git mv src/powershell/Sync-MacriumBackups.ps1 src/powershell/backup/

# Move file management scripts
git mv src/powershell/FileDistributor.ps1 src/powershell/file-management/
git mv src/powershell/Copy-AndroidFiles.ps1 src/powershell/file-management/
git mv src/powershell/Expand-ZipsAndClean.ps1 src/powershell/file-management/

# Move system cleanup scripts
git mv src/powershell/ClearOldRecycleBinItems.ps1 src/powershell/system/
git mv src/powershell/DeleteOldDownloads.ps1 src/powershell/system/
git mv src/powershell/Remove-DuplicateFiles.ps1 src/powershell/system/
git mv src/powershell/Remove-EmptyFolders.ps1 src/powershell/system/

# Move git scripts
git mv src/powershell/cleanup-git-branches.ps1 src/powershell/git/
git mv src/powershell/post-commit-my-scripts.ps1 src/powershell/git/
git mv src/powershell/post-merge-my-scripts.ps1 src/powershell/git/

# Move media scripts
git mv src/powershell/ConvertTo-Jpeg.ps1 src/powershell/media/
git mv src/powershell/picconvert.ps1 src/powershell/media/

# Move modules to categorized structure
git mv src/common/PostgresBackup.psm1 src/powershell/modules/Database/PostgresBackup/
git mv src/common/PowerShellLoggingFramework.psm1 src/powershell/modules/Core/Logging/
git mv src/common/PurgeLogs.psm1 src/powershell/modules/Core/Logging/
git mv src/powershell/module/RandomName src/powershell/modules/Utilities/RandomName
git mv src/powershell/module/Videoscreenshot src/powershell/modules/Media/Videoscreenshot
```

**Python Scripts:**
```bash
# Create domain folders
mkdir -p src/python/{data,cloud,media,modules}

# Move data processing scripts
git mv src/python/extract_timeline_locations.py src/python/data/
git mv src/python/csv-to-gpx.py src/python/data/
git mv src/python/validators.py src/python/data/

# Move cloud scripts
git mv src/python/gdrive_recover.py src/python/cloud/
git mv src/python/google_drive_root_files_delete.py src/python/cloud/
git mv src/python/drive_space_monitor.py src/python/cloud/
git mv src/python/cloudconvert_utils.py src/python/cloud/

# Move media scripts
git mv src/python/find-duplicate-images.py src/python/media/
git mv src/python/crop_colours.py src/python/media/

# Move shared modules
git mv src/common/python_logging_framework.py src/python/modules/logging/
git mv src/common/google_drive_auth.py src/python/modules/auth/
git mv src/common/elevation.py src/python/modules/auth/
```

**SQL Scripts:**
```bash
# Organize by database
mkdir -p src/sql/{gnucash,timeline,job_scheduler}
git mv src/sql/gnucash_*.sql src/sql/gnucash/
# (Move timeline DDL from timeline_data/ folder)
git mv timeline_data/*.sql src/sql/timeline/
```

**Configuration Files:**
```bash
# Move Windows Task Scheduler XMLs
mkdir -p config/tasks
git mv "Windows Task Scheduler"/*.xml config/tasks/
rmdir "Windows Task Scheduler"

# Move deployment config
git mv config/module-deployment-config.txt config/modules/deployment.txt
```

- [ ] Commit reorganization:
  ```bash
  git commit -m "refactor: reorganize folder structure by domain"
  ```

### Phase 4: Update Import Paths
- [ ] Find all import/dot-source statements:
  ```powershell
  # PowerShell
  Get-ChildItem -Recurse -Filter *.ps1 | Select-String -Pattern '\. .*\.ps1|Import-Module'

  # Python
  grep -r "^from src\." src/python/
  grep -r "^import" src/python/
  ```
- [ ] Update each import to new paths:
  ```powershell
  # OLD
  . "$PSScriptRoot/../../common/PostgresBackup.psm1"

  # NEW
  Import-Module PostgresBackup  # (if deployed)
  # OR
  . "$PSScriptRoot/../modules/Database/PostgresBackup/PostgresBackup.psm1"
  ```
- [ ] Test each script after updating imports

### Phase 5: Update References
- [ ] Update `config/tasks/*.xml` (Windows Task Scheduler) with new script paths
- [ ] Update `.github/workflows/sonarcloud.yml` if specific scripts referenced
- [ ] Update git hooks with new paths
- [ ] Update `config/modules/deployment.txt` with new module paths
- [ ] Update documentation with new paths

### Phase 6: Create Per-Folder READMEs
- [ ] Create `src/powershell/backup/README.md`:
  ```markdown
  # Database & Backup Scripts

  Scripts for automated database backups and synchronization.

  ## Scripts
  - `Backup-GnucashDatabase.ps1` – PostgreSQL backup for GnuCash
  - `Backup-JobScheduler.ps1` – Job scheduler database backup
  - `Backup-TimelineData.ps1` – Timeline data backup
  - `Sync-MacriumBackups.ps1` – Macrium backup synchronization

  ## Shared Modules
  - `PostgresBackup` (src/powershell/modules/Database/PostgresBackup)

  ## Scheduling
  See `config/tasks/` for Windows Task Scheduler definitions.
  ```
- [ ] Create README for each domain folder:
  - `src/powershell/file-management/README.md`
  - `src/powershell/system/README.md`
  - `src/powershell/git/README.md`
  - `src/powershell/media/README.md`
  - `src/python/data/README.md`
  - `src/python/cloud/README.md`
  - `src/python/media/README.md`
- [ ] Create `src/powershell/modules/README.md` explaining module organization

### Phase 7: Update Root README
- [ ] Update repository structure section in `README.md`:
  ```markdown
  ## Repository Structure

  This repository is organized by **programming language** and **functional domain**:

  * `src/` – Source code organized by language and domain
    * `src/powershell/` – PowerShell scripts and modules
      * `backup/` – Database backup and synchronization scripts
      * `file-management/` – File distribution, copying, archiving
      * `system/` – System cleanup and maintenance
      * `git/` – Git automation and hooks
      * `media/` – Image and video processing
      * `automation/` – General automation utilities
      * `modules/` – Reusable PowerShell modules
        * `Core/` – Logging, error handling, file operations
        * `Database/` – PostgreSQL and database utilities
        * `Utilities/` – General-purpose utilities
        * `Media/` – Media processing modules (Videoscreenshot)
    * `src/python/` – Python scripts and modules
      * `data/` – Data processing and transformation
      * `cloud/` – Google Drive and cloud service integrations
      * `media/` – Image processing and manipulation
      * `modules/` – Shared Python modules (logging, auth)
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
  ```

### Phase 8: Validation
- [ ] Verify all scripts are accounted for (none lost)
- [ ] Run linting on all moved scripts
- [ ] Test representative scripts from each domain
- [ ] Verify git history preserved: `git log --follow <new-path>`
- [ ] Run full test suite (if exists)

## Proposed Target Structure

```
/home/user/My-Scripts/
├── src/
│   ├── powershell/
│   │   ├── backup/                     # Database & backup automation
│   │   │   ├── README.md
│   │   │   ├── Backup-GnucashDatabase.ps1
│   │   │   ├── Backup-JobScheduler.ps1
│   │   │   ├── Backup-TimelineData.ps1
│   │   │   └── Sync-MacriumBackups.ps1
│   │   ├── file-management/            # File operations
│   │   │   ├── README.md
│   │   │   ├── Invoke-FileDistributor.ps1
│   │   │   ├── Copy-AndroidFiles.ps1
│   │   │   └── Expand-ZipsAndClean.ps1
│   │   ├── system/                     # System maintenance
│   │   │   ├── README.md
│   │   │   ├── Clear-OldRecycleBin.ps1
│   │   │   ├── Remove-OldDownloads.ps1
│   │   │   ├── Remove-DuplicateFiles.ps1
│   │   │   └── Remove-EmptyFolders.ps1
│   │   ├── git/                        # Git automation
│   │   │   ├── README.md
│   │   │   ├── Remove-StaleGitBranches.ps1
│   │   │   ├── Invoke-PostCommitHook.ps1
│   │   │   └── Invoke-PostMergeHook.ps1
│   │   ├── media/                      # Media processing
│   │   │   ├── README.md
│   │   │   ├── Convert-ToJpeg.ps1
│   │   │   └── Convert-ImageFormat.ps1
│   │   ├── automation/                 # General utilities
│   │   │   └── README.md
│   │   └── modules/                    # Reusable modules
│   │       ├── README.md
│   │       ├── Core/
│   │       │   ├── ErrorHandling/
│   │       │   ├── FileOperations/
│   │       │   └── Logging/
│   │       │       ├── PowerShellLoggingFramework.psm1
│   │       │       └── PurgeLogs.psm1
│   │       ├── Database/
│   │       │   └── PostgresBackup/
│   │       ├── Utilities/
│   │       │   └── RandomName/
│   │       └── Media/
│   │           └── Videoscreenshot/
│   ├── python/
│   │   ├── data/                       # Data processing
│   │   │   ├── README.md
│   │   │   ├── extract_timeline_locations.py
│   │   │   ├── csv_to_gpx.py
│   │   │   ├── validators.py
│   │   │   └── seat_assignment.py
│   │   ├── cloud/                      # Cloud integrations
│   │   │   ├── README.md
│   │   │   ├── gdrive_recover.py
│   │   │   ├── google_drive_root_files_delete.py
│   │   │   ├── drive_space_monitor.py
│   │   │   └── cloudconvert_utils.py
│   │   ├── media/                      # Image processing
│   │   │   ├── README.md
│   │   │   ├── find_duplicate_images.py
│   │   │   ├── crop_colours.py
│   │   │   └── recover_extensions.py
│   │   └── modules/                    # Shared modules
│   │       ├── logging/
│   │       │   └── python_logging_framework.py
│   │       └── auth/
│   │           ├── google_drive_auth.py
│   │           └── elevation.py
│   ├── sql/
│   │   ├── gnucash/                    # GnuCash schemas
│   │   ├── timeline/                   # Timeline schemas
│   │   └── job_scheduler/              # Job scheduler schemas
│   ├── sh/                             # Bash scripts
│   └── batch/                          # Batch scripts
├── config/
│   ├── modules/                        # Module deployment
│   │   └── deployment.txt
│   └── tasks/                          # Task scheduler (moved from root)
│       └── *.xml
├── docs/
│   ├── specifications/
│   │   └── logging_specification.md
│   ├── guides/
│   └── architecture/
├── tests/
│   ├── powershell/
│   └── python/
└── logs/
```

## Acceptance Criteria
- [x] All scripts moved to domain-specific folders
- [x] All modules moved to categorized structure
- [x] Configuration files moved to `config/` subdirectories
- [x] Windows Task Scheduler XMLs in `config/tasks/`
- [x] SQL files organized by database
- [x] Git history preserved for all files
- [x] Per-folder README files created (minimum 7 READMEs)
- [x] Root README.md updated with new structure
- [x] All import paths updated and tested
- [x] All Windows Task Scheduler tasks updated
- [x] Module deployment configuration updated
- [x] Migration documented in `docs/FOLDER_MIGRATION.md`
- [x] No broken imports or references
- [x] All scripts functional after move

## Related Files
- All files in `src/` (affected)
- `Windows Task Scheduler/` → `config/tasks/`
- `timeline_data/` → `src/sql/timeline/`
- `config/module-deployment-config.txt` → `config/modules/deployment.txt`
- `.github/workflows/sonarcloud.yml` (may need path updates)
- `README.md`

## Estimated Effort
**3-4 days** (planning, execution, testing, documentation)

## Dependencies
- Issue #003 (Naming Conventions) – ideally done together to minimize refactoring
- Issue #005 (Module Deployment) – update deployment config with new paths

## Risks
- ⚠️ Breaking Windows Task Scheduler tasks if paths not updated
- ⚠️ Breaking git hooks if paths not updated
- ⚠️ Import errors if paths not updated correctly
- **Mitigation:** Thorough testing, comprehensive migration documentation

## References
- [Git Documentation - git mv](https://git-scm.com/docs/git-mv)
- [Preserving Git History](https://git-scm.com/docs/git-log#Documentation/git-log.txt---follow)
