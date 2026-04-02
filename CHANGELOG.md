# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **FileDistributor retry/file-operation modularization cleanup (issue #779)**
  - Replaced remaining FileDistributor helper calls with shared Core modules: `Copy-FileWithRetry`, `Remove-FileWithRetry`, and `Invoke-WithRetry` from `Core/ErrorHandling`/`Core/FileOperations`
  - Updated recycle-bin and folder cleanup retry paths to use `Invoke-WithRetry -IgnoreFileNotFound` for file-not-found warning-and-skip behavior
  - Removed `Private/RetryOps.ps1` from FileDistributor loading path and imported Core dependencies directly in `FileDistributor.ps1` and `FileManagement/FileDistributor` module entrypoint
  - Bumped versions: `FileDistributor.ps1` to `4.7.1` and `FileManagement/FileDistributor` module to `1.1.1`

### Fixed

- **FileDistributor modularization: fixed parameter propagation in post-processing APIs**
  - Added `WarningCount`, `ErrorCount`, `RetryDelay`, and `RetryCount` parameters to `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`, and `Invoke-FolderConsolidation`
  - Updated script calls to pass script-scoped warning/error counters and retry settings to prevent incorrect EndOfScript deletion decisions and retry behavior changes
  - Ensures post-processing warnings/errors are properly tracked for `EndOfScript` deletion mode and retry parameters are correctly propagated from script to module functions

## [2.12.4] - 2026-03-29

### Fixed

- **FileDistributor.ps1 v4.6.16: restore compatible New-FileQueue call signature**
  - Removed unsupported `-WarningsSoFar` and `-ErrorsSoFar` arguments from `Invoke-ParameterValidation` when creating `FilesToDelete`
  - Prevents startup parameter-binding failures by aligning the call with `New-FileQueue`'s supported parameters (`Name`, `SessionId`, `MaxSize`, `StatePath`)

## [2.12.3] - 2026-03-29

### Changed

- **FileDistributor.ps1 v4.6.15: modularized state persistence and lock management**
  - Moved state file helpers (`ConvertTo-Hashtable`, `Get-FileSha256Hex`, `Write-JsonAtomically`, `Get-StateFromPath`, `ConvertFrom-FileQueue`) into `FileManagement/FileDistributor/Private/State.ps1`
  - Renamed checkpoint persistence functions to approved verbs (`Save-DistributionState`, `Restore-DistributionState`) and converted warnings/errors/session state inputs to explicit parameters at call sites
  - Moved lock helpers into `FileManagement/FileDistributor/Private/FileLock.ps1` and renamed them to `Lock-DistributionStateFile` and `Unlock-DistributionStateFile`
  - Updated orchestration call sites (`Invoke-RestoreCheckpoint`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`, `Invoke-PostRunCleanup`, and `Main` finally block) to use the new function names

### Fixed

- **FileDistributor module v1.0.1**
  - Incremented module manifest version to include the new private state and lock modules as part of the modularization series

## [2.12.2] - 2026-03-27

### Fixed

- **PurgeLogs v2.2.2: cross-runtime timestamp parsing compatibility**
  - Updated `Clear-LogFile` timestamp parsing to use explicit compatible `TryParseExact`/`TryParse` overloads
  - Fixes `MethodException` seen in CI tests for `-BeforeTimestamp` and `-RetentionDays` log filtering paths

## [2.12.1] - 2026-03-27

### Fixed

- **PurgeLogs v2.2.1: standalone Clear-LogFile compatibility in tests/import-only contexts**
  - `Clear-LogFile` now checks for `Initialize-Logger` before calling it, preventing `CommandNotFoundException` when PowerShellLoggingFramework is not preloaded
  - Root `PurgeLogs` module entrypoint now provides a fallback `Write-LogMessage` implementation for isolated manifest imports

## [2.12.0] - 2026-03-27

### Changed

- **FileDistributor.ps1 v4.6.10: modularized startup log cleanup via PurgeLogs**
  - Removed inline `RemoveLogEntries` and inline truncation logic from `FileDistributor.ps1`
  - Imported `Core/Logging/PurgeLogs` and replaced startup cleanup paths with a single `Clear-LogFile` call
  - Mapped existing script parameters to module equivalents (`RemoveEntriesOlderThan` -> `RetentionDays`, truncation switches pass-through)

- **PurgeLogs v2.2.0: added explicit timestamp cutoff filtering**
  - Added `-BeforeTimestamp` support to `Clear-LogFile`
  - Updated filtering flow so timestamp filtering can be combined with truncation checks in one invocation

## [2.11.0] - 2026-03-26

### Added

- **ErrorHandling v1.1.0: optional file-not-found skip in `Invoke-WithRetry`**
  - Added `-IgnoreFileNotFound` switch to `Invoke-WithRetry` in `Core/ErrorHandling`
  - When enabled, `ItemNotFoundException` and matching "Cannot find path ... does not exist" errors now log a warning and return without retry/rethrow
  - Default behavior remains unchanged for existing callers that do not set the switch
  - Updated ErrorHandling module documentation and tests to cover the new switch behavior

## [2.10.6] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.7: accept scalar checkpoint payload inputs**
  - Updated `New-CheckpointPayload` parameter typing so single `FileInfo`/`DirectoryInfo` values for `sourceFiles` or `subfolders` bind correctly
  - Prevents valid one-item scenarios (for example `MaxFilesToCopy=1` or a single target subfolder) from failing before `SaveState`

## [2.10.5] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.6: deduplicate checkpoint payload creation**
  - Added `New-CheckpointPayload` to build standard checkpoint state keys (`totalSourceFiles`, `totalSourceFilesAll`, `totalTargetFilesBefore`, `subfolders`, `deleteMode`, `SourceFolder`, `MaxFilesToCopy`) with optional inclusion of `sourceFiles` and `FilesToDelete`
  - Updated `Invoke-DistributionPhase` and `Invoke-PostProcessingPhase` to use the helper for checkpoints 2-8, removing repeated hashtable assembly logic

## [2.10.4] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.5: restore containment and fallback safety in shared subfolder helper**
  - `Get-SubfolderFileCounts` now enforces target-root containment for resolved candidate subfolders before they are used as destinations
  - Fresh-scan enumeration failures no longer force an early empty return; the helper now continues with existing candidates and still allows emergency-subfolder fallback when requested

## [2.10.3] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.4: shared subfolder enumerate/count helper refactor**
  - Added `Get-SubfolderFileCounts` to centralize subfolder normalization, per-folder file counting, empty-candidate handling, and aggregate counting
  - Updated all five distribution algorithms to consume the shared helper for their enumerate-and-count setup sequence, removing duplicated prolog logic

## [2.10.2] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.3: preserve EndOfScript queue-failure signal**
  - `Invoke-FileMove` now surfaces EndOfScript queue outcome and logs a warning when `Add-FileToQueue` fails
  - `DistributeFilesToSubfolders` now emits "pending deletion" only when queue insertion succeeds; otherwise it logs a warning for easier troubleshooting

## [2.10.1] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.2: shared move helper refactor**
  - Extracted a private `Invoke-FileMove` helper in `FileDistributor.ps1` to unify file-name conflict resolution, retried copy, delete-mode handling (`RecycleBin` / `Immediate` / `EndOfScript` queue), global counter updates, and progress reporting
  - Updated all five distribution algorithms (`DistributeFilesToSubfolders`, `RedistributeFilesInTarget` via `DistributeFilesToSubfolders`, `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum`) to reuse the shared helper and remove duplicated move-loop logic

## [2.10.0] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.0: decomposed Main into orchestration sub-functions**
  - Extracted Main into targeted phase functions to improve readability and maintainability:
    - `Invoke-ParameterValidation`
    - `Invoke-RestoreCheckpoint`
    - `Invoke-DistributionPhase`
    - `Invoke-PostProcessingPhase`
    - `Invoke-EndOfScriptDeletion`
    - `Invoke-PostRunCleanup`
  - Main now acts as orchestration glue while checkpoint, restart, deletion-queue, and post-run cleanup behavior remains structured by phase

## [2.9.1] - 2026-03-25

### Fixed

- **Security scan: ignore pygments ReDoS advisory `GHSA-5239-wwwm-4pmq`**
  - No patched version of pygments has been released; upstream has not yet responded to the disclosure
  - Added `--ignore-vuln GHSA-5239-wwwm-4pmq` to the `pip-audit` invocation in `security-scan.yml` and `.pre-commit-config.yaml` to unblock CI until a fix is available, following the same pattern as the existing `CVE-2026-0994` ignore
  - Comment added as a reminder to remove the ignore once pygments ships a patched release

## [2.9.0] - 2026-03-25

### Added

- **FileDistributor.ps1 v4.5.0: support `.mp4` files**
  - Added `.mp4` to the list of allowed extensions so MP4 video files are distributed alongside `.jpg` and `.png` images

## [2.8.0] - 2026-03-24

### Changed

- **Renamed `Convert-ImageFile.ps1` → `Move-ImageFileToBatch.ps1`**
  - The script organises files into batched subfolders and renames extensions; it does not convert image formats
  - `Move` better reflects the primary action (move semantics: copy then delete source) and aligns with the PowerShell approved verb list
  - Updated `src/powershell/media/README.md`, `docs/guides/naming-conventions.md`, `docs/FOLDER_MIGRATION.md`, and `docs/RENAME_MAPPING.md` to reflect the new name

## [2.7.6] - 2026-03-23

### Fixed

- **Removed Safety from the security toolchain to eliminate vulnerable transitive NLTK installs**
  - Dropped `safety` from `requirements.txt` and `requirements.lock`, keeping `pip-audit` as the repository's dependency scanner
  - Replaced the Safety-based pre-commit hook with a local `python-pip-audit` hook pinned to `pip-audit==2.7.3`
  - Simplified `.github/workflows/security-scan.yml` to install and run only `pip-audit`, while preserving the existing temporary `CVE-2026-0994` ignore
  - Updated README and installation guidance to document the new single-tool scanning workflow and the rationale for removing Safety's vulnerable `nltk` transitive dependency

### Fixed

- **pip-audit resolver conflict with Safety/filelock** (v2.7.5)
  - Replaced the stale `safety==3.2.11` lockfile pin with `safety==3.7.0` and aligned it to the Python 3.9+ support window already required by newer Safety releases
  - Kept the patched `filelock==3.20.3` override intact so the `pre-commit` stack stays on the secure dependency set while `pip-audit` can now install `requirements.lock` successfully
  - Updated README and installation guidance to document the new Safety pin and the Python-version marker used by security tooling

- **Python dev dependency security overrides** (v2.7.4)
  - Added explicit `virtualenv>=20.36.1` and `filelock>=3.20.3` constraints to `requirements.txt` so future resolves avoid the known TOCTOU advisories reported in the `pre-commit` runtime stack
  - Pinned `virtualenv==20.36.1` and `filelock==3.20.3` in `requirements.lock` so Safety and `pip-audit` scan the same patched dependency set used by CI
  - Updated README installation and security guidance to document the patched lockfile-based workflow

- **pip-audit lockfile install compatibility**
  - Replaced the unavailable `virtualenv==20.36.2` lockfile pin with `virtualenv==20.36.1`, which is present on the package index used by automation
  - Relaxed the floating `requirements.txt` lower bound to `virtualenv>=20.36.1` so development installs stay aligned with the lockfile
  - Updated installation guidance to explain the `pip-audit` failure mode and the compatible replacement pin

- **Security scans: audit the locked dependency set**
  - Updated GitHub Actions security scanning to install pinned `safety` and `pip-audit` versions from `requirements.lock`
  - Switched Safety and `pip-audit` checks from `requirements.txt` to `requirements.lock` so CI audits the reproducible dependency set instead of re-resolving floating ranges
  - Updated the README security commands to match the lockfile-based workflow and reduce false positives from transient dependency resolution

- **Sync-MacriumBackups.ps1: Align rclone log format with documentation** (v2.6.5)
  - Set rclone log format to `date,time,microseconds` (documented options) for consistent timestamps
  - Removed unsupported log time format probing to avoid unknown-flag errors

- **Sync-MacriumBackups.ps1: Rclone flag compatibility and logging fixups** (v2.6.4)
  - Detects supported rclone log time flags before adding them to avoid "unknown flag" errors
  - Avoids $Args parameter collisions so sanitized command logs include all arguments

- **Sync-MacriumBackups.ps1: Improved sanitized rclone command logging** (v2.6.3)
  - Added single-line sanitized command output for easy copy/paste reproduction
  - Logged multi-line arguments without a dangling backslash-only line

- **Remove-MergedGitBranch.ps1: Dry-run safety and log file output** (v2.7.3)
  - Dry-run now avoids pruning remote-tracking branches to prevent accidental deletion prompts
  - `-LogFile` now routes logging output to the specified file path

- **Sync-MacriumBackups.ps1: MaxChunkMB 4096 honored** (v2.6.1)
  - Added 4096 MB to the allowed rclone chunk size options so the documented MaxChunkMB range is honored
  - Prevents 4096 MB inputs from silently capping to 2048 MB

- **FileDistributor.ps1: Console Feedback for Rebalancing Operations** (v4.4.1)
  - Added console output for early exit conditions in `-RebalanceToAverage`, `-ConsolidateToMinimum`, and `-RandomizeDistribution` modes
  - Users now see clear messages when operations are skipped due to:
    - All subfolders already balanced within tolerance
    - Insufficient subfolders for rebalancing
    - No files to process
    - Already at or below minimal subfolder count
    - No feasible moves or capacity issues
  - Previously these conditions were only logged to file, making it unclear why operations completed without action
  - **Impact**: Improved user experience by providing immediate feedback on why rebalancing operations were skipped

- **FileDistributor.ps1: Cleaner Output in Rebalance-Only Mode** (v4.4.1)
  - Suppressed source-related messages when SourceFolder is not provided (rebalance-only mode)
  - Changes include:
    - "Preparing for distribution" message only shown when copying from source
    - "Enumerating source and target files..." changed to "Enumerating target files..." in rebalance-only mode
    - Removed redundant "Skipping source enumeration (rebalance-only mode)." message
    - File count summary shows only target count in rebalance-only mode
    - Separate "File Rebalancing Summary" with relevant information only (excludes source file counts, skipped extensions, and files selected for copying)
  - **Impact**: Reduced console noise in rebalance-only operations, making output more concise and relevant to the actual operation being performed

- **Conventional Commits Validation Duplication** (#653)
  - Resolved duplicate commit message validation between manual hook and commitizen
  - Manual `hooks/commit-msg` was removed in commit 874c5d9 (2025-12-09)
  - Standardized on commitizen hook via `.pre-commit-config.yaml`
  - Updated analysis documentation with resolution status
  - **Impact**: Eliminated duplicate validation, reduced maintenance burden
  - **Related**: Part of broader migration to single pre-commit framework system (PR #655, Issue #647)

- **Git Hook Permission Issues** (#648)
  - Issue automatically resolved by migration to pre-commit framework (PR #655, issue #647)
  - Removed hooks with permission problems: `post-checkout` and `pre-push`
  - Remaining hooks (`post-commit`, `post-merge`) have correct executable permissions
  - All hook management now standardized via `.pre-commit-config.yaml`
  - Updated analysis documentation to reflect resolution status
  - **Impact**: Eliminated permission-related hook execution failures

### Added

- **Lift Simulator Database Backup Job**
  - Added scheduled backup automation for `lift_simulator` PostgreSQL database
  - New script: `src/powershell/backup/Backup-LiftSimulatorDatabase.ps1`
  - Scheduled task template: `config/tasks/PostgreSQL lift_simulator Backup.xml.template`
  - Comprehensive setup documentation: `src/powershell/backup/README-LiftSimulator.md`
  - Features:
    - Daily backups at 07:30 UTC with 1-hour random delay
    - 90-day retention policy with minimum 3 backups always retained
    - Secure authentication via .pgpass file with ACL validation
    - Timestamped backup files in custom PostgreSQL format
    - Integrated logging via PowerShellLoggingFramework
    - Automatic backup cleanup and maintenance
    - Task Scheduler integration for unattended operation
  - Documentation includes:
    - PostgreSQL user privilege verification queries
    - Step-by-step privilege grant instructions
    - Authentication setup with .pgpass configuration
    - Security hardening recommendations
    - Troubleshooting guide
    - Backup restoration procedures
  - Leverages existing PostgresBackup module for consistent backup operations
  - Compatible with lift-simulator project documentation references

- **FileQueue Module** (#602)
  - Created new `FileManagement/FileQueue` module for queue management operations
  - Public Functions:
    - `New-FileQueue`: Create file distribution queues with configurable size limits
    - `Add-FileToQueue`: Add files with metadata tracking
    - `Get-NextQueueItem`: Retrieve next item (dequeue or peek)
    - `Remove-QueueItem`: Remove items by path, session, or custom filter
    - `Save-QueueState`: Persist queue to JSON
    - `Restore-QueueState`: Restore queue from saved state
  - Private Functions:
    - `Initialize-QueueState`: Helper for state structure initialization
    - `Update-QueueMetrics`: Helper for queue statistics management
  - Features:
    - Session tracking for queue ownership
    - Metadata capture (size, timestamps, custom properties)
    - State persistence across sessions
    - FIFO processing with peek support
    - Flexible item removal with filters
- **Sync-MacriumBackups Logging Enhancements**
  - Log the sanitized rclone command line for auditing
  - Log framework, rclone, and state file paths to the framework log
  - Align rclone log timestamp format with the logging framework for consistency

### Changed

- **FileDistributor.ps1 Refactoring** (#602, Phase 2)
  - Extracted queue management logic into FileQueue module
  - Replaced inline queue operations with module function calls
  - Added `ConvertFrom-FileQueue` helper function for state persistence
  - Improved code maintainability and reusability
  - Queue now uses object-oriented approach with methods (Enqueue, Dequeue, Peek, Clear)
  - Maintains backward compatibility with existing state files
  - Part of Phase 2 refactoring to address large complex scripts (#008)

### Technical Details

- Module Location: `src/powershell/modules/FileManagement/FileQueue/`
- Comprehensive Pester test suite with 70%+ coverage
- PowerShell 5.1+ compatible
- Supports unlimited queue size with `-MaxSize -1`
- Queue items track: SourcePath, TargetPath, Size, LastWriteTimeUtc, QueuedAtUtc, SessionId, Attempts, Metadata

## [2.7.2] - 2025-12-07

### Changed

- Replaced `Write-Host` with `Write-Information` in `scripts/Load-Environment.ps1` to keep environment-loading messages redirectable while remaining user-visible.
- Documented intentional `Write-Host` usage in `scripts/Check-DocumentationPaths.ps1` with PSScriptAnalyzer suppression for interactive color-coded diagnostics.
- Added console output stream guidelines to `README.md` and `CONTRIBUTING.md`, including code review checks for logging and `Write-Host` justification.

## [2.7.1] - 2025-12-06

### Fixed

- **Empty Catch Blocks in PowerShell Scripts** (#001)
  - Fixed all 33 empty catch blocks across PowerShell scripts and modules
  - **Best-effort operations**: Added debug-level logging for non-critical failures
    - Git merge-base detection (`Invoke-PostMergeHook.ps1`)
    - File metadata retrieval (`FileDistributor.ps1`, `Remove-DuplicateFiles.ps1`)
    - Path validation (`FileDistributor.ps1`)
    - Directory creation attempts (`FileDistributor.ps1`, `Remove-DuplicateFiles.ps1`)
    - FPS parsing (`Video.Fps.ps1`)
    - Device name retrieval (`Gdi.Capture.ps1`)
    - ReadOnly attribute clearing (`Remove-OldDownload.ps1`)
  - **Resource cleanup operations**: Added explanatory comments for intentional silent handling
    - FileStream disposal (`FileDistributor.ps1`, `IO.Helpers.ps1`)
    - Graphics object disposal (`Gdi.Capture.ps1`)
    - Bitmap disposal (`Gdi.Capture.ps1`)
    - Process cleanup (`Vlc.Process.ps1`, `Cropper.Invoke.ps1`)
    - StandardError stream reading (`Vlc.Process.ps1`)
  - **Console/UI operations**: Added comments for environment-specific failures
    - Console width detection (`Expand-ZipsAndClean.ps1`)
    - Resume file path resolution (`Start-VideoBatch.ps1`)
    - Timestamp parsing in log files (`Clear-LogFile.ps1`)
  - **Impact**: Improved debugging capability and code maintainability
  - **Module Updates**:
    - PurgeLogs: v2.0.0 → v2.0.1
    - Videoscreenshot: v3.0.2 → v3.0.3

## [2.7.0] - 2025-12-06

### Added

- **CI Checks Investigation Report** (#632)
  - Comprehensive analysis of GitHub Actions workflow configurations
  - Verified all CI workflows are correctly configured for pull requests
  - Root cause identified: Issue is in GitHub repository settings, not workflow files
  - Documented required status checks and branch protection configuration
  - Created `CI_INVESTIGATION_REPORT.md` with detailed findings and remediation steps
  - Workflow analysis confirms: sonarcloud.yml, security-scan.yml, code-formatting.yml all properly configured
  - Recommendations for ensuring all CI checks run on pull requests to main branch

- **Comprehensive Environment Variable Documentation** (#606 Phase 1 of #010)
  - Created `docs/ENVIRONMENT.md` - Complete environment variable reference guide
  - **Documentation Sections**:
    - Quick start guide for environment setup
    - Required variables (MY_SCRIPTS_ROOT, Google Drive, CloudConvert)
    - Optional variables (PostgreSQL, logging, backup, email, advanced settings)
    - CI/CD secrets configuration (GitHub Actions)
    - Standard OS environment variables reference
    - Comprehensive setup instructions (dev, CI/CD, production)
    - Security best practices (secret management, key rotation, file permissions)
    - Troubleshooting guide with common issues and solutions
    - Validation script documentation
    - Quick reference tables
  - **Variable Documentation** (23 application-defined variables):
    - Each variable includes: description, format, how to obtain, example, used by, security notes
    - Clear marking of required vs optional variables
    - Default values and fallback behavior
    - Line number references for code usage
  - **Security Features**:
    - Never commit secrets guidelines
    - Different keys per environment recommendations
    - Key rotation best practices
    - File permission instructions (Windows/Linux/Mac)
    - Secret management tool recommendations (Credential Manager, Keychain, Vault)
  - **Troubleshooting Coverage**:
    - Environment variable not found
    - Invalid credentials/authentication failures
    - Scripts can't find .env file
    - Permission denied errors
    - PostgreSQL connection failures
    - Log file location issues
  - **Integration**:
    - Updated README.md with reference to environment documentation
    - Updated .gitignore with comprehensive environment file patterns (.env, .env.local, .env.\*.local)
    - Cross-references to Configuration Guide, Installation Guide, Contributing Guidelines
  - **Benefits**:
    - ✅ Single source of truth for environment variables
    - ✅ Clear onboarding path for new users
    - ✅ Security best practices documented
    - ✅ Comprehensive troubleshooting guide
    - ✅ Supports all 3 environments (dev, CI/CD, production)
    - ✅ Foundation for future environment improvements (Phase 2: Validation, Phase 3: Templates)

## [2.6.0] - 2025-12-06

### Added

- **TOML-based Module Deployment Configuration** (#604 Phase 1 of #009)
  - Created `psmodule.toml` - Single source of truth for PowerShell module deployment
  - Created `psmodule.local.toml.example` - Example user-specific configuration overrides
  - **Configuration Consolidation**:
    - Replaced multiple configuration files (deployment.txt, local-deployment-config.json) with single TOML file
    - Reduced configuration complexity from 3 files to 1
    - Supports all 8 PowerShell modules with proper metadata
    - Standard TOML format with comments support
  - **Module Configuration Features**:
    - Auto-detect PowerShell module paths or use custom paths
    - Testing and validation options (test-on-deploy, validate-manifest, import-after-deploy)
    - Module discovery with auto-discover and source-paths configuration
    - Module dependencies support (e.g., PurgeLogs depends on PowerShellLoggingFramework)
    - Per-module settings (auto-deploy, test-on-deploy, description, author)
  - **Implementation Scripts**:
    - `scripts/Read-ModuleConfig.ps1` - TOML parser with Tomlyn.Signed support and fallback
    - `scripts/Migrate-ModuleConfig.ps1` - Migration script from legacy format to TOML
    - Automatic installation of TOML parser (Tomlyn.Signed) if not available
    - Configuration merging for local overrides (psmodule.local.toml)
  - **Configuration Structure**:
    - `[deployment]` section with global deployment settings
    - `[[modules]]` array defining all 8 PowerShell modules:
      - PowerShellLoggingFramework (Core logging framework)
      - ErrorHandling (Standardized error handling with retry logic)
      - FileOperations (Resilient file operations)
      - ProgressReporter (Progress tracking with logging integration)
      - PurgeLogs (Log retention management)
      - PostgresBackup (PostgreSQL backup with retention)
      - RandomName (Windows-safe random filename generation)
      - Videoscreenshot (Video frame capture via VLC or GDI+)
  - **Benefits**:
    - ✅ Single configuration file (reduced from 3 to 1)
    - ✅ Standard TOML format easier to read and edit
    - ✅ Schema validation possible
    - ✅ Comments supported for documentation
    - ✅ Module dependencies explicitly defined
    - ✅ User-specific overrides without modifying shared config
  - **Documentation**:
    - Updated README.md with TOML configuration section
    - Updated .gitignore to exclude psmodule.local.toml
    - Migration guide in Migrate-ModuleConfig.ps1
    - Comprehensive inline documentation in all TOML files

## [2.5.0] - 2025-12-06

### Added

- **FileSystem Core Module** (#601 Phase 1 of #008)
  - Created new `FileSystem` module under `src/powershell/modules/Core/FileSystem/`
  - **Public Functions**:
    - `New-DirectoryIfMissing` - Creates directories with error handling and Force parameter support
    - `Test-FileAccessible` - Tests file accessibility for Read, Write, or ReadWrite operations
    - `Test-PathValid` - Validates paths according to filesystem rules with optional wildcard support
    - `Test-FileLocked` - Detects if a file is locked by another process
  - **Private Functions**:
    - `Get-FileLockInfo` - Internal helper to identify locking processes
  - **Module Features**:
    - Proper error handling with verbose logging
    - PowerShell 5.1+ compatibility
    - Comprehensive parameter validation
    - Follows Public/Private module structure pattern
  - **Testing**:
    - Complete unit test suite in `tests/powershell/unit/FileSystem.Tests.ps1`
    - Tests cover all public functions and edge cases
    - Validates module exports and function isolation
  - **Script Migrations**:
    - Updated `Expand-ZipsAndClean.ps1` to use `New-DirectoryIfMissing` (5 instances)
    - Updated `Remove-EmptyFolders.ps1` to use `New-DirectoryIfMissing`
    - Updated `Remove-DuplicateFiles.ps1` to use `New-DirectoryIfMissing`
  - **Benefits**:
    - ✅ Reusable file system operations across scripts
    - ✅ Consistent error handling and validation
    - ✅ Easier to test and maintain
    - ✅ Reduces code duplication in large scripts
    - ✅ Foundation for further refactoring (Issue #008)

## [2.4.1] - 2025-12-06

### Added

- **Type Hints for Data Processing Scripts** (#005 Phase 3)
  - Added explicit type annotations to `src/python/data/csv_to_gpx.py`, `src/python/data/validators.py`, and `src/python/data/extract_timeline_locations.py`
  - Updated docstrings to reflect typed arguments and return values for CSV, GPX, and timeline data flows
  - Ensured mypy compatibility for critical data-processing paths

- **Type Hints for Error Handling Module** (#596 Phase 2 of #005)
  - Added comprehensive type hints to `src/python/modules/utils/error_handling.py`
  - **New Functions with Full Type Support**:
    - `retry_on_exception()` decorator with generic type preservation using `TypeVar[T]`
    - `error_handler()` context manager with proper Iterator type hints
    - Enhanced `safe_execute()` with generics accepting \*args and \*\*kwargs
  - **Improved Existing Functions**:
    - `retry_operation()` now uses generic `TypeVar[T]` for return type preservation
    - `with_retry()` decorator updated with proper tuple type annotations
    - `ErrorContext` class with properly typed `__enter__` and `__exit__` methods
  - **Type Annotations Added**:
    - `retry_on_exception()` with signature: `Callable[[Callable[..., T]], Callable[..., T]]`
    - `retry_operation()` with return type: `T` (preserves operation return type)
    - `safe_execute()` with signature: `Callable[..., T], *args, **kwargs -> Union[T, None]`
    - `error_handler()` with signature: `Iterator[None]` context manager
    - All wrapper functions properly annotated with `*args: Any, **kwargs: Any`
  - **Testing**:
    - Added comprehensive type preservation tests (13 new tests)
    - Tests verify return type preservation for int, str, list, dict types
    - Tests validate decorator behavior with different exception types
    - Tests confirm proper argument passing with \*args and \*\*kwargs
  - **Benefits**:
    - ✅ Passes mypy --strict validation
    - ✅ Complete type safety with generic decorators
    - ✅ IDE autocomplete shows correct return types
    - ✅ Type errors caught at development time
    - ✅ Self-documenting code with clear type signatures
    - ✅ Backward compatible with all existing code
  - **Technical Notes**:
    - Used `from __future__ import annotations` for forward reference support
    - Added proper `TypeVar[T]` for return type preservation
    - Used `type: ignore` comments for standard library compatibility issues
    - All 42 unit tests pass successfully

- **Type Hints for Logging Framework Module** (#005b Phase 2 of #005)
  - Added comprehensive type hints to `src/python/modules/logging/python_logging_framework.py`
  - All public functions and classes now have complete type annotations
  - All internal functions have proper type hints
  - Docstrings updated to match type signatures
  - **Type Annotations Added**:
    - `SpecFormatter` class with `format() -> str` return type
    - `JSONFormatter` class with `format() -> str` return type
    - `initialise_logger()` with `Logger` return type and all parameter types including `Union[str, Path]` for `log_dir`
    - `validate_metadata_keys()` with `Dict[str, Any]` parameter and `None` return type
    - `log_debug()`, `log_info()`, `log_warning()`, `log_error()`, `log_critical()` with proper signatures
  - **Benefits**:
    - ✅ Passes mypy --strict validation
    - ✅ Clear API documentation through type signatures
    - ✅ Better IDE support with autocomplete and inline documentation
    - ✅ Type errors caught at development time instead of runtime
    - ✅ Self-documenting code that's easier to maintain
  - **Technical Notes**:
    - Used `# type: ignore` comments to handle local logging package shadowing stdlib
    - Added `from __future__ import annotations` for forward reference support
    - Maintained backward compatibility with all existing code

- **Type Hints Infrastructure Setup** (#594 Phase 1 of #005)
  - Installed mypy 1.7.1 for static type checking
  - Added type stub packages: types-requests 2.31.0, types-tqdm 4.66.0
  - Configured mypy.ini with permissive settings (python 3.11)
  - Added mypy to pre-commit hooks (informational, non-blocking)
  - Integrated mypy into CI/CD pipeline (SonarCloud workflow)
  - **Current Status**: Infrastructure ready, 117 type errors identified across 10 files
  - **Benefits**:
    - ✅ Infrastructure ready for gradual type hint adoption
    - ✅ Developers see type errors locally during development
    - ✅ CI tracks type coverage over time
    - ✅ No disruption to existing workflow (informational only)
  - **Next Steps**: Phase 2 will add type hints to core modules

- **Comprehensive Tests for Shared PowerShell Modules** (#003f Phase 2)
  - Added comprehensive unit tests for critical shared PowerShell infrastructure modules
  - **Priority**: HIGH - High reuse means high impact from bugs
  - **Coverage Achievements**:
    - `PowerShellLoggingFramework`: 50%+ coverage (40 tests)
    - `ProgressReporter`: 50%+ coverage (70 tests total, 55 new)
    - `ErrorHandling`: 80%+ coverage (already existed)
    - `FileOperations`: 60%+ coverage (already existed)
  - **New Test Coverage**:
    - **PowerShellLoggingFramework Tests** (40 new tests):
      - Logger initialization (default settings, custom directory, log levels)
      - All log levels (Debug, Info, Warning, Error, Critical)
      - Plain text and JSON format support
      - Log level filtering (DEBUG, INFO, WARNING, ERROR, CRITICAL)
      - Timezone handling and abbreviation
      - Metadata key validation
      - Error handling and fallback to console
      - Integration tests for full logging workflows
    - **ProgressReporter Enhanced Tests** (55 new tests):
      - Show-Progress with all parameters and edge cases
      - Write-ProgressLog with percentage calculation
      - New-ProgressTracker with edge cases
      - Update-ProgressTracker with update frequency logic
      - Complete-ProgressTracker with various states
      - Write-ProgressStatus with special characters
      - Full workflow integration tests
      - Multiple independent trackers
      - Edge case workflows (zero total, overflow)
  - **Benefits**:
    - ✅ Validates shared PowerShell infrastructure
    - ✅ Prevents widespread failures across scripts
    - ✅ Documents module APIs and expected behavior
    - ✅ Enables safe refactoring with high test coverage
    - ✅ Cross-platform logging validation
    - ✅ Progress tracking reliability for long-running operations
  - **Total**: 110 tests passing, 95 new tests added

- **Comprehensive Tests for Shared Python Modules** (#003e Phase 2)
  - Added comprehensive unit tests for critical shared infrastructure modules
  - **Priority**: HIGH - High reuse means high impact from bugs
  - **Coverage Achievements**:
    - `python_logging_framework.py`: 91% coverage (target: 60%+)
    - `error_handling.py`: 84% coverage (target: 70%+)
    - `file_operations.py`: 63% coverage (target: 60%+)
  - **New Test Coverage**:
    - **Logging Framework Tests** (6 new tests):
      - Logger initialization with custom log directory
      - Logging with structured metadata
      - All log levels (debug, info, warning, error, critical)
      - File handler creation and log persistence
    - **Error Handling Advanced Tests** (5 new tests):
      - Retry decorator with mock functions
      - Max retries enforcement
      - Custom exception filtering
      - Exponential backoff validation
      - Retry operation exponential backoff
    - **File Operations Tests** (4 new tests):
      - Nested directory creation
      - Existing directory handling
      - Parent directory creation for files
      - Unicode encoding support
  - **Benefits**:
    - Validates critical shared infrastructure
    - Prevents bugs in widely-used utilities
    - Enables confident refactoring
    - Documents expected behavior
  - **Total**: 76 tests passing, 17 new tests added

- **Google Drive destructive-operation safeguards** (#003 Phase 1)
  - Added fully mocked unit tests for root-level deletion and trash recovery flows
  - Verifies folder exclusion, pagination, and API error handling to prevent accidental data loss
  - Recovery helper tests ensure trashed items are identified without calling live APIs

- **Comprehensive PostgreSQL Backup Tests** (#003 Phase 1) - Expanded test coverage for database backup scripts
  - **Priority**: HIGH - Critical path testing for financial data (GnuCash) backups
  - **Impact**: Prevents data loss, validates backup reliability, enables confident refactoring
  - **Files Modified**:
    - `tests/powershell/unit/PostgresBackup.Tests.ps1` - Added 21 new test cases (770 → 1320 lines)
  - **New Test Coverage**:
    - **Invalid Database Scenarios** (4 tests):
      - Non-existent database handling
      - Database connection timeout handling
      - Authentication failure handling
      - Insufficient permissions handling
    - **Retention Policy Edge Cases** (6 tests):
      - Exactly min_backups count boundary
      - retention_days=0 edge case
      - min_backups=0 edge case
      - Multiple databases in same folder isolation
      - Very large number of old backups (50+) efficiency
    - **Special Characters and URL Encoding** (4 tests):
      - Password with special characters (@, !, #, $, %, &, \*)
      - Password with spaces
      - Database names with underscores and numbers
      - Username with special characters
    - **Additional Error Scenarios** (7 tests):
      - Disk full during backup
      - Permission denied on backup folder
      - pg_dump executable not found
      - pg_dump warnings logging
      - Service stop failure after successful backup
      - Backup creation when zero-byte cleanup fails

- **Data transformation tests for GPS/timeline processing** (#003 Phase 1)
  - Added unit tests for CSV→GPX conversion, geospatial validators, and timeline extraction helpers
  - Validates elevation inclusion, malformed CSV handling, JSON parsing errors, and activity enrichment flows
  - **Test Statistics**:
    - Total test cases: 40 (19 existing + 21 new)
    - Test code lines: 1,320
    - Integration tests: 2 (Test-BackupRestore.Tests.ps1)
    - Test-to-code ratio: 8.1:1 (1,320 test lines / 162 implementation lines)
  - **Benefits**:
    - ✅ Validates financial data backup reliability
    - ✅ Prevents data loss through comprehensive error handling tests
    - ✅ Documents expected behavior for all edge cases
    - ✅ Enables safe refactoring with high test coverage
    - ✅ Tests URL encoding for passwords with special characters
    - ✅ Validates retention policy in complex scenarios

- **Re-enabled Bandit B113 Timeout Check** (#004c) - Enabled security enforcement for HTTP request timeouts
  - **Priority**: MEDIUM-HIGH - Security and code quality enforcement
  - **Impact**: Prevents new code from missing timeouts, enforced in CI/CD pipeline
  - **Files Modified**:
    - `pyproject.toml` - Removed B113 from skips list to enable timeout checking
    - `src/python/modules/utils/README.md` - Updated documentation examples to include timeout parameters
  - **Files Added**:
    - `tests/python/unit/test_security_compliance.py` - Automated regression tests
      - `test_all_requests_have_timeouts()` - Verifies all HTTP requests include timeout parameter
      - `test_bandit_b113_enabled()` - Ensures B113 check is not in skip list
      - `test_security_documentation_examples()` - Validates documentation examples comply with security requirements
  - **CI/CD Integration**: Bandit B113 now enforced in GitHub Actions and pre-commit hooks
  - **Benefits**: Catches timeout violations before merge, maintains code quality standards

- **HTTP Timeout Guidelines Documentation** (#004b) - Comprehensive documentation for HTTP request timeout best practices
  - **Priority**: MEDIUM - Developer education and code quality improvement
  - **Impact**: Improved code reliability, prevents indefinite hangs, establishes timeout standards
  - **Files Modified**:
    - `src/python/modules/utils/error_handling.py` - Fixed example code to include timeout parameters
      - Line 94: Updated `requests.get(url)` to `requests.get(url, timeout=(5, 30))`
      - Line 173: Updated lambda example to include timeout parameter
    - `CONTRIBUTING.md` - Added "HTTP Request Guidelines" section
      - "Always Specify Timeouts" with good/bad examples
      - "Recommended Timeout Values" for different operation types
      - "Handle Timeout Exceptions" with error handling examples
  - **Files Added**:
    - `docs/guides/http-requests.md` - Comprehensive HTTP request best practices guide
      - Timeout configuration and tuple format explanation
      - Guidelines by operation type (API endpoints, file operations, third-party APIs)
      - Dynamic timeout calculation for file uploads/downloads
      - Error handling patterns and examples
      - Testing timeout behavior with pytest examples
      - Common patterns section with complete code examples
      - References to related documentation
  - **Benefits**:
    - ✅ Developers understand timeout requirements
    - ✅ Example code demonstrates correct usage
    - ✅ Consistent timeout values across codebase
    - ✅ Prevents indefinite hangs in HTTP requests
    - ✅ Clear guidelines for different operation types
    - ✅ Dynamic timeout calculation for large files
    - ✅ Comprehensive error handling patterns
  - **Version Impact**: PATCH bump - documentation improvement, no breaking changes

### Changed

- Replaced `Write-Host` usage in system maintenance scripts with the centralized logging framework and structured run outputs for automation (`Invoke-SystemHealthCheck.ps1`, `Install-SystemHealthCheckTask.ps1`, `Remove-DuplicateFiles.ps1`).
- Corrected git hook launchers to call the PowerShell hook implementations from their canonical path under `src/powershell/git`.
- Cached the PowerShell logging module's default log directory at import time to reduce repeated path resolution during logger initialization.
- Removed the tracked `python_logging_framework.egg-info` build artifacts and expanded `.gitignore` to keep egg-info, log, and tmp files out of version control.
- Introduced a hybrid dependency pinning strategy with a reproducible `requirements.lock` alongside range-based `requirements.txt` constraints.

### Added

- **Automated Dependency Security Scanning** (#520) - Comprehensive vulnerability scanning for Python dependencies
  - **Priority**: MEDIUM - Proactive security vulnerability detection and remediation
  - **Impact**: Enhanced security posture, automated vulnerability detection, reduced risk of supply chain attacks
  - **Problem Solved**:
    - No automated vulnerability scanning for dependencies
    - Security issues could go undetected until exploited
    - Manual dependency auditing was time-consuming and error-prone
    - No integration with GitHub security features
  - **Solution Implemented**:
    - **GitHub Actions Workflow**: `.github/workflows/security-scan.yml`
      - Runs on push, pull requests, and weekly schedule (Sundays 2:00 AM UTC)
      - Manual trigger support via workflow_dispatch
      - Multiple security scanning tools for comprehensive coverage
    - **Security Scanning Tools**:
      - **Safety** - Checks dependencies against known vulnerability database
      - **pip-audit** - Python package auditing against OSV and PyPI Advisory databases
      - **Dependency Review Action** - GitHub native dependency vulnerability scanning (PR only)
    - **Pre-commit Hook**: Added python-safety-dependencies-check to `.pre-commit-config.yaml`
      - Scans requirements.txt files before commit
      - Prevents committing known vulnerable dependencies
      - Uses Lucas-C/pre-commit-hooks-safety v1.3.3
    - **CI/CD Integration**:
      - Automated vulnerability reports in GitHub Actions summary
      - Artifact uploads for detailed analysis (30-day retention)
      - Fails build on security vulnerabilities (configurable)
- Git hook integration test suite (`tests/integration/GitHooks.Integration.Tests.ps1`) that provisions a temporary repository, installs hooks, and validates staging mirror updates, deployment targets, and configuration handling for post-commit and post-merge workflows.
  - **Integration Test Coverage**:
    - Added `tests/integration/Test-BackupRestore.Tests.ps1` to validate PostgreSQL backup/restore flows end-to-end
    - Exercises backup creation, restore validation, data integrity checks, and retention cleanup with temporary PostgreSQL instances
      - Dependency review comments on pull requests
  - **Dependencies Added** (requirements.txt):
    - safety==3.2.11 - Python dependency security scanner
    - pip-audit==2.7.3 - PyPI package auditor
  - **Workflow Features**:
    - **Scheduled Scans**: Weekly security audits (cron: '0 2 \* \* 0')
    - **Trigger Events**: push, pull_request, schedule, manual workflow_dispatch
    - **Multi-tool Scanning**: Safety, pip-audit, and GitHub Dependency Review
    - **Detailed Reporting**: Step-by-step results in GitHub Actions summary
    - **Artifact Preservation**: JSON/text reports uploaded for 30 days
    - **Severity Configuration**: Dependency Review fails on moderate+ severity
    - **PR Integration**: Automatic dependency review comments on pull requests
    - **Continue-on-error**: Non-blocking scans with summary at the end
  - **Security Scan Process**:
    1. **On Every Push/PR**: Runs safety and pip-audit checks
    2. **Weekly Schedule**: Automated scans every Sunday at 2:00 AM UTC
    3. **Pre-commit Hook**: Validates dependencies before allowing commits
    4. **Dependency Review**: GitHub native scanning on pull requests
    5. **Reports**: Detailed vulnerability reports in Actions summary and artifacts
  - **Documentation**:
    - Security scanning process documented in README.md
    - GitHub workflow includes inline comments and examples
    - Pre-commit hook configuration with file pattern matching
  - **Benefits**:
    - ✅ Automated detection of known security vulnerabilities
    - ✅ Multi-tool coverage (Safety, pip-audit, GitHub Dependency Review)
    - ✅ Weekly scheduled scans for continuous monitoring
    - ✅ Pre-commit hooks prevent vulnerable dependencies from being committed
    - ✅ Detailed reports with remediation guidance
    - ✅ Integration with GitHub Security features (Dependabot alerts)
    - ✅ Fail-fast CI/CD on security issues
    - ✅ Artifact retention for historical analysis
    - ✅ Manual trigger support for ad-hoc scans
  - **Files Added**:
    - `.github/workflows/security-scan.yml` - Security scanning workflow

## [2.3.1] - 2024-06-07

### Added

- Enabled pip caching across CI workflows (formatting, security, SonarCloud, module validation) with cache hit/miss reporting. (#519)
- npm cache restoration for `sql-lint` in SonarCloud workflow.
- User-scoped PowerShell module caching for linting and deployment jobs.

### Changed

- Documented CI/CD caching strategy in README.

### Security

- Updated vulnerable packages: `requests` 2.31→2.32.4, `tqdm` 4.66.1→4.66.3, `black` 24.1.1→24.3.0, `bandit` 1.7.5→1.7.9. (#520)
- Removed `continue-on-error` from CI quality gates; pre-commit, Pylint, Bandit, PSScriptAnalyzer, Safety, pip-audit, and SonarCloud quality gate are now blocking. (#521)
- Pinned all 23 Python dependencies to exact versions in `requirements.txt` for reproducible builds. (#519)

## [Pre-release] - 2024

### Added

- **Testing Framework** — Python (pytest) and PowerShell (Pester) test suites with `pytest.ini`, shared fixtures, SonarCloud CI integration, and initial tests for validators, logging, CSV-to-GPX, RandomName, and FileDistributor.
  - `tests/python/conftest.py`, `tests/README.md`, and `docs/guides/testing.md` set up shared fixtures and testing standards.
  - Coverage reporting integrated with SonarCloud; XML reports uploaded as CI artifacts.
- **Git Hooks for Quality Enforcement** (#455) — Tracked `hooks/` templates covering pre-commit linting, commit-msg Conventional Commits validation, and post-commit/merge automation.
  - Pre-commit runs PSScriptAnalyzer and Pylint; commit-msg enforces `type(scope): description` format.
  - Post-commit and post-merge hooks call PowerShell scripts for file mirroring and module deployment.
  - `scripts/install-hooks.sh` installs hooks into `.git/hooks/` and makes them executable.
- **Module Deployment Configuration** (#456) — `.psd1` manifests for `PostgresBackup`, `PowerShellLoggingFramework`, and `PurgeLogs` (v2.0.0); `config/module-deployment-config.txt` lists all five modules.
  - `scripts/Deploy-Modules.ps1` validates manifests and deploys to System, User, or custom paths with cross-platform support.
  - `scripts/install-modules.sh` installs both PowerShell and Python modules with selective and force-overwrite options.
- **Test Coverage Infrastructure** (#459) — `tests/powershell/Invoke-Tests.ps1` runs Pester with JaCoCo output for SonarCloud/Codecov upload.
  - Python coverage enforced via `pytest.ini`; both languages upload to Codecov with per-language flags.
  - Phased ramp-up roadmap in `docs/COVERAGE_ROADMAP.md` (baseline → 30% over six months); coverage badges added to README.
- **Shared Utilities Modules** (#461) — PowerShell `ErrorHandling` (retry with exponential backoff, privilege detection), `FileOperations` (resilient ops with retry), and `ProgressReporter` (progress bars with logging).
  - Python equivalents: `error_handling` (decorators for retry/error handling) and `file_operations` (resilient file I/O with atomic writes).
  - All five modules have ≥70% unit test coverage; usage guide at `docs/guides/using-shared-utilities.md`.
- **Architecture Documentation** (#462) — `ARCHITECTURE.md` covers design principles, component architecture, and six key design decisions with rationale.
  - `docs/architecture/` contains database ER diagrams, PowerShell/Python module dependency graphs, external integration guides, and seven Mermaid data-flow sequence diagrams.
- **Pre-Commit Framework** (#463) — `.pre-commit-config.yaml` integrates Black, Pylint, Bandit, PSScriptAnalyzer, SQLFluff, Commitizen, and general hooks (whitespace, YAML/JSON validation, large-file detection).
  - CI workflow runs hooks on all files; weekly automated hook-update PR via `.github/workflows/pre-commit-autoupdate.yml`.
- **Code Formatting Automation** (#464) — Black (Python), PSScriptAnalyzer OTBS (PowerShell), and SQLFluff PostgreSQL (SQL) configured via `.editorconfig` and `.vscode/settings.json`.
  - `scripts/format-all.sh` formats all languages in one command; `.github/workflows/code-formatting.yml` fails CI on formatting violations.
- **Automated Release Workflow** (#465) — `.github/workflows/release.yml` validates version format, extracts CHANGELOG entry, and publishes a GitHub Release on version tag push.
  - `scripts/bump-version.sh` bumps `VERSION` and adds a dated CHANGELOG section (major/minor/patch).
  - `.github/RELEASE_CHECKLIST.md` and `docs/guides/versioning.md` cover the full release and rollback process.
- **Configuration Guide and Validation Tools** (#517) — `config/CONFIG_GUIDE.md` with quick-start, platform-specific instructions, and troubleshooting for common setup issues.
  - `scripts/Initialize-Configuration.ps1` interactive wizard covers deployment config, environment variables, and PostgreSQL secrets (Windows DPAPI).
  - `scripts/Verify-Configuration.ps1` validates staging mirror, git hooks, PowerShell modules, and env vars with CI-friendly exit codes.
- **Centralized Environment Configuration** (#510) — `.env.example` documents all variables; Bash/PowerShell loaders in `scripts/`; `docs/guides/environment-variables.md` for cross-platform setup.
  - Google Drive credential paths made configurable via `GDRIVE_CREDENTIALS_PATH`/`GDRIVE_TOKEN_PATH` environment variables. (#506)
- **Portable Task Scheduler Templates** (#512) — Nine Windows Task Scheduler XML files converted to `.xml.template` with `{{SCRIPT_ROOT}}` placeholder.
  - `scripts/Install-ScheduledTasks.ps1` generates, validates, and registers tasks; `scripts/Uninstall-ScheduledTasks.ps1` removes them.
- `Sync-Directory.ps1` v1.1.0: `ExcludeFromDeletion` glob patterns preserve non-repository files (logs, virtual environments, configs) during repository-to-working-copy sync.
- Automated Python dependency security scanning (Safety, pip-audit, GitHub Dependency Review) on push, PR, and weekly schedule. (#520)
- Pester unit tests for `PostgresBackup` (#507), Git hooks (#508), `ErrorHandling` (#516), and `FileOperations` (#515); pytest tests for Google Drive auth, module logger initialisation, Bandit B113 compliance, and GPS/timeline data transformations.

### Changed

- Unified version management: `setup.py` reads `VERSION` file as single source of truth; `pyproject.toml` aligned. (#518)
- `create_github_issues.sh` processes all files in the issues directory (not just `issue*`-prefixed) with a configurable `--issues-dir` parameter. (#500, #504)
- Replaced `Write-Host` with the centralised logging framework in backup and maintenance scripts; standardised PowerShell modules to Public/Private folder structure.

### Fixed

- Removed hardcoded paths from PowerShell scripts and batch files; credentials configured via `PGBACKUP_PASSWORD_FILE`, `HANDLE_EXE_PATH`, and related environment variables. (#513)
- Replaced hardcoded paths in documentation with `<REPO_PATH>`/`<SCRIPT_ROOT>` placeholders; `scripts/Check-DocumentationPaths.ps1` enforces this in CI. (#514)
- Python modules no longer raise `AttributeError` on standalone import; each calls `plog.initialise_logger(__name__)` at module level. (#511)
