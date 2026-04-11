# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **FileSystem module** bumped to v1.1.0 (issue #937)
  - New path utility functions extracted from `Expand-ZipsAndClean.ps1`:
    - `Get-FullPath`: Normalize paths to absolute Windows paths
    - `Format-Bytes`: Format byte counts into human-readable strings (B, KB, MB, GB, TB)
    - `Resolve-UniquePath`: Generate unique file paths with timestamp suffixes
    - `Resolve-UniqueDirectoryPath`: Generate unique directory paths with timestamp suffixes
    - `Get-SafeName`: Sanitize filenames by removing invalid characters and optionally truncating
    - `Test-LongPathsEnabled`: Check OS registry for Windows long paths support
    - `Resolve-UniquePathCore` (private helper): Shared suffix logic for unique path generation
  - Comprehensive Pester test coverage added for all new functions
  - All functions follow module style conventions with comment-based help

- **BackupState module** (`src/powershell/modules/Backup/BackupState.psm1`, v1.0.0)
  - New module extracted from `Sync-MacriumBackups.ps1` containing all eight state
    management functions: `Format-Duration`, `Read-StateFile`, `Write-StateFile`,
    `Mark-InterruptedState`, `Initialize-StateFile`, `Update-StateStep`,
    `Complete-StateFile`, and `Invoke-AutoResumeLogic`.
  - All functions accept explicit parameters (`StateFile`, `State`, `AutoResume`,
    `Force`, etc.) so the state object is initialised once and passed through the
    call chain, eliminating redundant disk reads.
  - `Export-ModuleMember` explicitly lists all eight public functions.

### Changed

- **Expand-ZipsAndClean.ps1** bumped to v2.0.1 (issue #937)
  - Refactored: seven generic helper functions moved to `FileSystem.psm1` module
    for reuse across other scripts (no behavioral changes to script)
  - Removed from script: `Get-FullPath`, `Format-Bytes`, `Resolve-UniquePathCore`,
    `Resolve-UniquePath`, `Resolve-UniqueDirectoryPath`, `Get-SafeName`,
    `Test-LongPathsEnabled` (now imported via `FileSystem.psm1`)

- **Sync-MacriumBackups.ps1** bumped to v2.7.2
  - v2.7.0: Extracted all eight state management functions into the new `BackupState`
    module (`BackupState.psm1`). `Test-BackupPath`, `Test-Rclone`, `Test-Network`, and
    `Sync-Backups` now accept an explicit `$State` parameter; state file is read once at
    startup and passed through the call chain. `README.md` updated to document the new
    `BackupState` module dependency.
  - v2.7.1: Extracted `Connect-WiFiNetwork` inner helper to eliminate duplicated
    `netsh wlan connect` + `Start-Sleep` + `Get-CurrentSSID` pattern from `Test-Network`.
    All three WiFi scenarios (preferred, fallback, neither) behave identically to before.
  - v2.7.2: Documentation-only — removed 117-line inline CHANGELOG from `.NOTES`;
    replaced with a pointer to `CHANGELOG.md`. Fixed stale SSID whitelist pattern in
    `PARAMETER_VALIDATION_TESTS.md` to use the current blacklist pattern
    `'^[^"\`$|;&<>\r\n\t]+$'`.

### Fixed

- **Python data smoke import stability:** `src/python/data/seat_assignment.py` now lazy-loads `pandas` and `networkx` via `_get_pandas()` / `_get_networkx()` instead of importing them at module import time, preventing CI smoke-import failures in minimal dependency environments.

## [2.12.10] - 2026-04-05

### Fixed

- **FileDistributor logging consistency (issue #819)**
  - Removed the direct `Write-Host` completion output from `Invoke-FileDistribution` so completion messages flow exclusively through `Write-LogInfo` and the central logging framework
  - Bumped versions: `FileDistributor.ps1` to `4.7.12` and `FileManagement/FileDistributor` module to `1.1.12`

## [2.12.9] - 2026-04-05

### Fixed

- **FileDistributor state helpers now use explicit state/retry parameters instead of script-scope free variables (issue #817)**
  - Added explicit `StateFilePath`, `RetryDelay`, `RetryCount`, and `MaxBackoff` parameters to `Save-DistributionState` and `Restore-DistributionState` in `Private/State.ps1`
  - Added explicit `RetryCount` and `MaxBackoff` parameters to `Write-JsonAtomically` so checksum sidecar writes no longer depend on outer script scope
  - Updated `FileDistributor.ps1` checkpoint and restore call sites to pass the current state path and retry settings explicitly, making the state helpers safe in module/test contexts
  - Added regression coverage for the state helpers to confirm they persist and re-lock using only passed parameters
  - Bumped versions: `FileDistributor.ps1` to `4.7.10` and `FileManagement/FileDistributor` module to `1.1.10`

- **Post-processing module functions used script-scope `LogMessage` and `Write-DistributionSummary` instead of `Write-Log*` (issue #816)**
  - Replaced all `LogMessage` calls in `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize` with the appropriate `Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, or `Write-LogDebug` framework calls; warning/error ref-counter increments previously implicit in `LogMessage` are now applied directly to `$WarningCount`/`$ErrorCount`
  - Added `Write-DistributionSummary` as a private module function in `Private/Distribution.ps1` (replacing `LogMessage` calls inside it with `Write-LogInfo`), making it available to all three post-processing public functions without depending on the script-scope definition in `FileDistributor.ps1`
  - Bumped `FileManagement/FileDistributor` module version to `1.1.9`

- **Division-by-zero / flood logging when `plannedMoves` or `filesMoving` is 0 in `Invoke-FolderRebalance` and `Invoke-DistributionRandomize`**
  - Replaced `($plannedMoves / 10)` and `($filesMoving / 10)` progress-log thresholds with a pre-computed `$threshold` variable that evaluates to `[int]::MaxValue` when the denominator is 0, preventing a flood of log output on every loop iteration
  - Bumped `FileManagement/FileDistributor` module version to `1.1.6`

- **FolderOps.ps1: use `-LiteralPath` in `Move-ToRecycleBin` and `Remove-DistributionFile` (issue #BUG)**
  - Changed `Get-Item $FilePath` to `Get-Item -LiteralPath $FilePath` in `Move-ToRecycleBin` to prevent wildcard expansion silently failing for file names containing `[`, `]`, `*`, or `?`
  - Changed `Test-Path -Path $FilePath` to `Test-Path -LiteralPath $FilePath` in `Remove-DistributionFile` for the same reason
  - Bumped versions: `FileDistributor.ps1` to `4.7.5` and `FileManagement/FileDistributor` module to `1.1.4`

- **FileDistributor.ps1 v4.7.3: CP3 checkpoint now saves source files**
  - Added `-IncludeSourceFiles` and `-SourceFiles $RunState.sourceFiles` to the CP3 `New-CheckpointPayload` call in `Invoke-DistributionPhase`
  - Previously the CP3 payload omitted `sourceFiles`, so restarting from CP3 left `$RunState.sourceFiles` empty and the CP4 guard evaluated to `$false`, silently skipping the entire source-to-target distribution phase

### Changed

- **FileDistributor retry/file-operation modularization cleanup (issue #779)**
  - Replaced remaining FileDistributor helper calls with shared Core modules: `Copy-FileWithRetry`, `Remove-FileWithRetry`, and `Invoke-WithRetry` from `Core/ErrorHandling`/`Core/FileOperations`
  - Updated recycle-bin and folder cleanup retry paths to use `Invoke-WithRetry -IgnoreFileNotFound` for file-not-found warning-and-skip behavior
  - Removed `Private/RetryOps.ps1` from FileDistributor loading path and imported Core dependencies directly in `FileDistributor.ps1` and `FileManagement/FileDistributor` module entrypoint
  - Bumped versions: `FileDistributor.ps1` to `4.7.1` and `FileManagement/FileDistributor` module to `1.1.1`

- **FileDistributor race regression: missing source files no longer abort distribution (issue #779 review)**
  - Updated `Invoke-FileMove` to detect source disappearance before/during `Copy-FileWithRetry` and treat it as warning-and-skip behavior
  - Prevents normal concurrent file churn from terminating an otherwise healthy distribution pass
  - Bumped versions: `FileDistributor.ps1` to `4.7.2` and `FileManagement/FileDistributor` module to `1.1.2`

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

- Renamed `Convert-ImageFile.ps1` to `Move-ImageFileToBatch.ps1` to match actual behavior (batching/moving, not format conversion) and approved PowerShell verb guidance.
- Updated repository documentation and migration mapping references to use the new script name.

## [2.7.6] - 2026-03-23

### Fixed

- Removed Safety from repository security tooling due to a vulnerable transitive `nltk` chain; standardized dependency scanning on `pip-audit` in pre-commit and CI.
- Resolved lockfile and resolver issues across follow-up fixes (v2.7.5/v2.7.4), including compatible `virtualenv`/`filelock` pins and lockfile-aligned scanning.
- Sync-MacriumBackups fixes from v2.6.1-v2.6.5: corrected `MaxChunkMB` handling, improved rclone flag compatibility, and aligned sanitized/logged command output with documented formats.
- Remove-MergedGitBranch fix (v2.7.3): dry-run no longer prunes remote-tracking refs, and `-LogFile` output routing was corrected.
- FileDistributor v4.4.1 output fixes: clearer rebalance skip reasons and reduced console noise in rebalance-only mode.
- Repository maintenance fixes tracked in this cycle: duplicate commit-validation cleanup (#653) and hook-permission cleanup completed through pre-commit migration (#648, #655, #647).

### Added

- Added scheduled PostgreSQL backup automation for the `lift_simulator` database (script, task template, and setup/restore documentation).
- Added the `FileManagement/FileQueue` module for reusable queue state/metadata operations used by distribution workflows. (#602)
- Added Sync-MacriumBackups logging enhancements to improve command traceability and timestamp consistency.

### Changed

- Refactored FileDistributor Phase 2 to use FileQueue module abstractions while preserving compatibility with existing queue state files. (#602, #008)

## [2.7.2] - 2025-12-07

### Changed

- Replaced `Write-Host` with `Write-Information` in `scripts/Load-Environment.ps1` to keep environment-loading messages redirectable while remaining user-visible.
- Documented intentional `Write-Host` usage in `scripts/Check-DocumentationPaths.ps1` with PSScriptAnalyzer suppression for interactive color-coded diagnostics.
- Added console output stream guidelines to `README.md` and `CONTRIBUTING.md`, including code review checks for logging and `Write-Host` justification.

## [2.7.1] - 2025-12-06

### Fixed

- Replaced 33 empty catch blocks across PowerShell scripts/modules with explicit intent (debug logging for best-effort failures or comments for intentionally silent cleanup paths). (#1)
- Improved troubleshooting signal without changing runtime behavior, and shipped related module patches for PurgeLogs and Videoscreenshot.

## [2.7.0] - 2025-12-06

### Added

- Added repository environment-variable reference documentation (`docs/ENVIRONMENT.md`) and linked onboarding/security guidance. (#606, #010)
- Added CI checks investigation report documenting that missing PR checks were caused by repository settings rather than workflow definitions. (#632)

## [2.6.0] - 2025-12-06

### Added

- Replaced legacy module deployment config files with TOML-based configuration (`psmodule.toml`) plus optional local overrides (`psmodule.local.toml`). (#604, #009)
- Added migration/reader scripts and updated deployment docs so module metadata, dependencies, and validation settings are managed from a single source of truth.

## [2.5.0] - 2025-12-06

### Added

- Added `FileSystem` core module with reusable directory/path/file-access helpers to reduce duplicated script-level filesystem logic. (#601, #008)
- Migrated key scripts to shared module functions and covered the module with unit tests for PowerShell 5.1+ compatibility.

## [2.4.1] - 2025-12-06

### Added

- Established repository type-hinting infrastructure with mypy/stubs and CI/pre-commit integration for gradual adoption. (#5, #594)
- Added substantial Python typing coverage for error-handling and logging modules, including generic retry/decorator pathways and strict-mode compatibility updates. (#596)
- Added type annotations for key data-processing scripts (`csv_to_gpx.py`, `validators.py`, `extract_timeline_locations.py`) to improve static validation and IDE feedback.
- Expanded shared-infrastructure test coverage across Python and PowerShell modules, including logging, error handling, file operations, progress reporting, and backup workflows.
- Added Google Drive destructive-operation safeguards and PostgreSQL backup reliability tests to reduce data-loss risk in critical automation paths.

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

---

## Sync-MacriumBackups.ps1 — Script Version History

The entries below document `Sync-MacriumBackups.ps1` script versions that pre-date
the numbered project releases above. They were previously kept as an inline CHANGELOG
inside the script's `.NOTES` block and have been moved here for centralised tracking.

### v2.6.6 — 2026-01-15

#### Fixed
- Added missing `reason` property to state object initialisation to fix AutoResume functionality.
- Resolved "property 'reason' cannot be found" error in `Mark-InterruptedState` function.

### v2.6.5 — 2026-01-15

#### Fixed
- Aligned rclone log formatting with supported `--log-format` options (`date,time,microseconds`).
- Removed unsupported log time format detection logic to match rclone documentation.

### v2.6.4 — 2026-01-15

#### Fixed
- Avoided unsupported rclone log date flags by detecting available options before adding them.
- Ensured sanitised rclone command logging always includes arguments by avoiding `$Args` parameter collisions.

### v2.6.3 — 2026-01-15

#### Fixed
- Added single-line and multi-line sanitised rclone command output for easier reconstruction and debugging.
- Avoided logging a dangling rclone backslash line without arguments.

### v2.6.2 — 2026-01-15

#### Fixed
- Enhanced rclone command logging to display each argument on a separate line for better debugging.
- Ensures full command can be reconstructed even when rclone fails with syntax errors.

### v2.6.1 — 2026-01-15

#### Fixed
- Allowed 4096 MB rclone chunk size when `MaxChunkMB` is set to the documented maximum.

### v2.6.0 — 2026-01-15

#### Changed
- Refactored `Initialize-StateFile` to eliminate duplicated interrupted state handling logic.
- Added `Mark-InterruptedState` helper function to consolidate state marking logic.
- Extracted script version from `.NOTES` into dedicated `$ScriptVersion` variable for programmatic access.
- Enhanced state file to include `scriptVersion` field for version tracking.
- Improved logging to include script version at startup and state initialisation.

### v2.5.1 — 2026-01-15

#### Added
- Sanitised rclone command line logging for auditability.
- Framework log entries for framework, rclone, and state file paths.
- Consistent rclone log timestamp formatting aligned with framework logs.

### v2.5.0 — 2026-01-14

#### Added
- Post-run verification summary showing exit code and sync duration after rclone completes.
- Sync duration tracking: captures `syncStartTime` and `syncDurationSeconds` in state file.
- `Format-Duration` helper function for human-readable duration formatting (e.g., "5h 23m 15s").
- Startup sanity check: corrupt/unreadable state files are renamed with timestamp instead of deleted.
- Corrupt state files preserved for debugging with `.corrupt_TIMESTAMP` suffix.

#### Changed
- `Complete-StateFile` now accepts and persists `SyncDurationSeconds` parameter.
- State structure includes `syncStartTime` and `syncDurationSeconds` fields.
- `Read-StateFile` handles corrupt files gracefully by renaming them before continuing.
- Enhanced state finalisation logging includes formatted sync duration when available.

#### Fixed
- Improved state consistency: all error paths guaranteed to update state to Failed before exit.
- State file corruption no longer blocks script execution.

### v2.4.0 — 2026-01-13

#### Added
- Auto-resume behaviour with `-AutoResume` flag to intelligently restart sync based on previous run status.
- `-Force` flag to override auto-resume logic and run sync regardless of previous success.
- `Invoke-AutoResumeLogic` function to evaluate previous run state and determine if sync should proceed.
- Clean start behaviour (default) that removes existing state file when AutoResume is not set.
- Enhanced logging for resume/retry scenarios showing previous run context.
- Exit code 0 when previous run succeeded and `-Force` not set (with AutoResume).
- Decision path logging clearly showing why sync is running or being skipped.

#### Changed
- `Initialize-StateFile` now accepts `CleanStart` parameter for explicit state cleanup.
- Modified state initialisation to log different messages for resume vs retry scenarios.
- Updated parameter documentation with AutoResume and Force usage examples.

### v2.3.0 — 2026-01-13

#### Added
- Single-instance locking using named mutex to prevent concurrent runs.
- Mutex-based lock with 120-second timeout when another instance is running.
- Graceful exit with exit code 2 when lock cannot be acquired.
- Automatic lock release in `finally` block to ensure cleanup.
- Detailed logging for lock acquisition, waiting, and release.

#### Fixed
- Handle `AbandonedMutexException` from crashed previous instances as successful lock acquisition.
- Prevent false-positive concurrent instance detection when previous run crashed unexpectedly.

### v2.2.0 — 2026-01-13

#### Added
- Persistent state tracking with JSON state file (`Sync-MacriumBackups_state.json`).
- State file records: `lastRunId` (GUID), `status`, `startTime`, `endTime`, `lastExitCode`, `lastStep`.
- Atomic state file writes using temporary file and rename.
- Detection and warning for interrupted runs (`status=InProgress` from previous run).
- State updates at each major step: Initialize, Test-BackupPath, Test-Rclone, Test-Network, Sync-Backups.
- State finalisation on success (`Succeeded`) and failure (`Failed`) with exit codes.
- Exception handling to mark state as Failed on unhandled errors.

### v2.1.0 — 2026-01-13

#### Changed
- Configure logging to centralised `Scripts\logs` directory.
- Removed `LogFile` parameter (now automatically set to logs directory).
- Framework logs: `Sync-MacriumBackups.ps1_powershell_YYYY-MM-DD.log`.
- Rclone logs: `Sync-MacriumBackups_rclone.log`.
- Added log path output on script start for verification.

#### Fixed
- Use rclone's `--log-file` parameter instead of PowerShell redirection.
- Eliminates PowerShell stderr errors when rclone writes INFO messages.
- Cleaner log output without `RemoteException` errors.

### v2.0.0 — 2025-11-16

#### Changed
- Migrated to `PowerShellLoggingFramework.psm1` for standardised logging.
- Removed custom `Write-Log` function.
- Replaced `Write-Log` calls with `Write-LogInfo`, `Write-LogError`, `Write-LogWarning`.

---

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
