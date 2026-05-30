# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The current minor release series is documented in full. Earlier entries are condensed to
architectural highlights; full history is available in `git log` and release tags. For
changes that are fully documented in a component's own changelog, only a stub entry is
kept here — see the linked file for details.

### Legend

- `#NNN` references GitHub issues in this repository unless explicitly prefixed otherwise.

## [Unreleased]

### Changed

- **[gdrive_recover 1.27.0]** Removed `DriveTrashRecoveryTool` pass-through delegation wrappers, retargeted recovery tests to owning helper objects, routed fresh-run reset output through `RecoveryReporter`, and replaced the streaming `_seen_total_ref` list box with `SeenTotalCounter` (issue #1118).
  → Full detail: [src/python/cloud/CHANGELOG-gdrive-recover.md](src/python/cloud/CHANGELOG-gdrive-recover.md)
- **[Invoke-PostMergeHook 3.2.1]** Refactored `Deploy-ModuleFromConfig` to reduce cognitive
  complexity from 77 to ≤15: extracted `Test-TargetList`, `Get-ParsedConfigLine`,
  `Resolve-ModuleSourcePath`, `Get-TargetBaseRoot`, `Invoke-ModuleTargetDeployment`, and
  `Invoke-SingleModuleDeployment` helpers; no behaviour change.
- **[Invoke-PostCommitHook 3.2.0]** Refactored `Deploy-ModuleFromConfig` to reduce cognitive
  complexity from 77 to ≤15: extracted `Test-TargetList`, `Get-ParsedConfigLine`,
  `Resolve-ModuleSourcePath`, `Get-TargetBaseRoot`, `Invoke-ModuleTargetDeployment`, and
  `Invoke-SingleModuleDeployment` helpers; no behaviour change.

### Fixed

- **[Update-ScheduledTaskScriptPaths 3.0.1]** Consistent pipeline stage indentation: each cmdlet on its own line with pipe at end of preceding line.
  → Full detail: [automation/CHANGELOG.md](src/powershell/automation/CHANGELOG.md)

### Security

- **[Expand-ZipsAndClean/ZipWorkflow]** Added module-scope `Write-LogDebug` fallback to prevent helper-load failures when logging framework is not imported in test/module scope (issue #1096 follow-up).
- **[Expand-ZipsAndClean tests]** Imported `FileManagement/ZipWorkflow` in helper-region test setups so extracted helper wrappers resolve module-qualified commands in helper-only loads (issue #1096 follow-up).
- **[Expand-ZipsAndClean]** Modularized precondition/destination and zip-move target helpers into `FileManagement/ZipWorkflow`; moved ZIP `Add-Type` loading from script to `ZipExtraction` module (issue #1096).
- **[Dependencies]** Raised `sqlfluff` to `>=4.2.0,<5.0.0` (locked `4.2.0`) to remediate
  GHSA-wmhf-fqc8-vxhh and GHSA-73jc-5mrq-prw7 (parser resource-exhaustion DoS).
- **[Dependencies]** Bumped `pytest` minimum to `9.0.3` (`pytest>=9.0.3,<10.0.0`) to resolve
  GHSA-6w46-j5rx-g56g (predictable `/tmp/pytest-of-{user}` directory on UNIX).
- **[Expand-ZipsAndClean]** Hardened Flat-mode Zip Slip path validation (issue #973):
  `Resolve-ZipEntryDestinationPath` helper centralises entry-name normalisation, rooted-entry
  rejection, and OS-appropriate containment comparison; Pester coverage added.
  → Full detail: [Expand-ZipsAndClean.CHANGELOG.md](src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md)

### Added

- **[FileSystem module 1.1.0]** Extracted `Get-FullPath`, `Format-Bytes`, `Resolve-UniquePath`,
  `Resolve-UniqueDirectoryPath`, `Get-SafeName`, and `Test-LongPathsEnabled` from
  `Expand-ZipsAndClean.ps1` into the reusable `FileSystem` module (issue #937).
- **[BackupState module 1.0.0]** New module extracted from `Sync-MacriumBackups.ps1` containing
  all eight state-management functions (`Format-Duration`, `Read-StateFile`, `Write-StateFile`,
  `Mark-InterruptedState`, `Initialize-StateFile`, `Update-StateStep`, `Complete-StateFile`,
  `Invoke-AutoResumeLogic`) with explicit parameter passing to eliminate redundant disk reads.

### Changed

- **[gdrive_recover 1.26.13]** Unified duplicated folder BFS traversal logic across batch and streaming discovery paths in `gdrive_discovery.py`, reducing drift risk while preserving folder-prefix and limit behaviour (issue #1088).
  → Full detail: [src/python/cloud/CHANGELOG-gdrive-recover.md](src/python/cloud/CHANGELOG-gdrive-recover.md)
- **[Expand-ZipsAndClean tests]** Collapsed redundant helper assertions in `Show-ProgressPhase` and `Write-ExtractionSummary` blocks to keep script-helper coverage behavior-focused while reducing duplicate setup/output checks (issue #1080).
- **[Expand-ZipsAndClean tests]** Restored explicit interactive (ConsoleHost) header assertion for `Write-ExtractionSummary` without `-PassThru`, protecting the default output path from regressions after helper-test consolidation (issue #1080 follow-up).
- **[Core/Zip tests]** Relocated Zip module extraction tests from `Expand-ZipsAndClean.Tests.ps1` into dedicated `tests/powershell/modules/Core/Zip/Zip.Tests.ps1` for module-scoped ownership and clearer suite boundaries (issue #1076).
- **[gdrive_recover docs]** Moved `gdrive_recover.py` embedded usage examples to `docs/gdrive-recover-usage.md` and linked the new page from README (issue #1117).
- **[Expand-ZipsAndClean 2.5.2]** Replaced script-local `Write-PhaseProgress` usage with shared `Core/Progress` `Show-Progress` (via `Show-ProgressPhase` adapter) and added `Show-Progress -Suppress` for quiet-mode suppression (issue #1063).
  → Full detail: [Expand-ZipsAndClean.CHANGELOG.md](src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md)
- **[FileDistributor]** `SupportsShouldProcess` added to the entry script and to all
  distribution, post-processing, and deletion phase functions (issues #932, #933); `EndOfScript`
  queue no longer consumed by denied `ShouldProcess`.
  → Full detail: [FileDistributor.CHANGELOG.md](src/powershell/file-management/FileDistributor.CHANGELOG.md)
- **[FileDistributor]** Logging refactor: script-local `LogMessage` wrapper removed; all call
  sites now use `Write-Log*` framework APIs directly; `Get-LogWarningCount`,
  `Get-LogErrorCount`, and `Reset-LogCounters` added to `PowerShellLoggingFramework` (issue #929).
  → Full detail: [FileDistributor.CHANGELOG.md](src/powershell/file-management/FileDistributor.CHANGELOG.md)
- **[Expand-ZipsAndClean]** Refactored through v2.0.4: seven generic helpers extracted to the
  `FileSystem` module; `Main` decomposed into named phase functions; `Expand-ZipSmart` split into
  `Expand-ZipToSubfolder` / `Expand-ZipFlat` with `Expand-ZipSmart` retained as a dispatcher
  (issues #937–#939).
  → Full detail: [Expand-ZipsAndClean.CHANGELOG.md](src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md)
- **[Sync-MacriumBackups.ps1 2.7.3]** Reduced `Test-Network` cognitive complexity from 25 → 6
  (limit: 15) by extracting two helpers: `Invoke-FallbackUpgrade` (upgrade from fallback SSID to
  preferred when available) and `Connect-KnownWiFiNetwork` (connect from a fully disconnected
  state). No functional changes; `Get-AvailableWiFiNetworks` added to eliminate the duplicated
  `netsh wlan show networks` one-liner.
- **[Sync-MacriumBackups.ps1 2.7.0–2.7.2]** State management extracted to `BackupState` module;
  `Connect-WiFiNetwork` inner helper extracted to remove duplicated netsh/sleep/SSID pattern;
  117-line inline CHANGELOG removed from `.NOTES` (replaced with pointer to `CHANGELOG.md`).

### Fixed

- **[Profile-Helpers]** Suppressed non-fatal import warnings during lazy repo module loading (`Import-Module ... -WarningAction SilentlyContinue`) so profile-driven script dispatch no longer surfaces PostgresBackup `pg_dump` detection warnings during unrelated command usage.

- **[gdrive_recover 1.26.14]** Restored streaming folder traversal behavior to continue processing queued sibling folders after a per-folder fetch error while still returning a non-success status for the run (issue #1088 review follow-up).
  → Full detail: [src/python/cloud/CHANGELOG-gdrive-recover.md](src/python/cloud/CHANGELOG-gdrive-recover.md)
- **[Show-RandomImage 2.3.1]** Added an explicit read-permission pre-check before `Invoke-Item`; permission-denied selections now emit a console-visible error with the full path and skip viewer handoff (issue #1151).
- **[Move-ImageFileToBatch 2.1.0]** Renamed `-LogFilePath` to `-LogDirectory` and passed it
  to `Initialize-Logger` so the framework log is written to the caller-supplied directory
  instead of the module default; fixed error-log path derivation in `Write-RunSummary` to
  construct a timestamped filename inside `-LogDirectory` rather than treating the directory
  path as a literal file path (issue #1150).

- **[Expand-ZipsAndClean 2.6.4]** Fixed misattributed comment-help for env-var default
  overrides (`SourceDirectory` → `EXPAND_ZIPS_SOURCE_DIR`, `DestinationDirectory` →
  `EXPAND_ZIPS_DEST_DIR`) and corrected parameter-default resolution so whitespace-only
  env-var values are treated as unset and correctly fall back to profile-relative defaults
  (issue #1094).
- **[Core/Zip tests]** Corrected relative `Import-Module` paths in `tests/powershell/modules/Core/Zip/Zip.Tests.ps1` after relocation so `Invoke-Pester` resolves `src/powershell/modules/...` correctly from `tests/powershell/modules/Core/Zip` (issue #1076).
- **[Expand-ZipsAndClean]** `Remove-SourceDirectory` reliability series (v2.1.2–v2.1.8):
  iterative fixes to non-zip filter logic, deepest-first deletion ordering, transient
  `Remove-Item` error double-counting, Linux CI race with `.NET` `Directory::Delete`, and
  PSDrive-qualified path handling via `Resolve-Path -ProviderPath`. Encrypted-archive error
  classification centralised in `Resolve-ExtractionError` / `Test-IsEncryptedZipError` (v2.2.1).
  → Full detail: [Expand-ZipsAndClean.CHANGELOG.md](src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md)
- **[Python / data]** `seat_assignment.py` now lazy-loads `pandas` and `networkx` via
  `_get_pandas()` / `_get_networkx()` to prevent CI smoke-import failures in minimal
  dependency environments.

### Removed

- **[Expand-ZipsAndClean]** Removed non-behavioral env-var expression and smoke-parse tests
  from the Pester suite (#1068) to keep coverage focused on runtime behaviour.

## [2.17.0] - 2026-05-18

### Added

- **[Expand-ZipsAndClean 2.4.0]** PS 7 parallel extraction via `-ThrottleLimit` (default `1` =
  serial); `ConcurrentBag`-backed error aggregation; live aggregate progress counter; null-
  conditional fix in `Move-ZipFilesToParent`; CPU-count warning; WhatIf limitation documented.
  → Full detail: [Expand-ZipsAndClean.CHANGELOG.md](src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md)

## [2.16.0] - 2026-05-17

### Added

- **[gdrive_recover 1.26.0]** `--timestamped-output` flag inserts a microsecond-precision run
  timestamp into `--log-file` and `--failed-file` paths so each run writes to its own files;
  independent of `--fresh-run`.
  → Full detail: [src/python/cloud/CHANGELOG.md](src/python/cloud/CHANGELOG.md)

## [2.15.0]–[2.15.2] - 2026-05-16

### Changed

- **[PostgresBackup 2.1.0–2.1.2]** `pg_dump` path auto-detected (env override → `PGBIN` →
  `PATH` → Windows install roots, newest major first) replacing a hardcoded drive-specific path;
  cross-install-root version comparison fixed; `Resolve-PgDumpPath` refactored into single-
  purpose helpers to reduce cognitive complexity.
  → Full detail: [PostgresBackup/CHANGELOG.md](src/powershell/modules/Database/PostgresBackup/CHANGELOG.md)

### Fixed

- **[Backup-GnuCashDatabase 3.0.1]** Script-level `[CmdletBinding()] param()` block added;
  previously all parameters (e.g. `-BackupRoot`, `-Database`, `-RetentionDays`) were declared
  only on the internal `Invoke-BackupMain` function and silently ignored when the script was
  invoked by Task Scheduler on a machine without the hardcoded `D:` drive.

## [2.14.0] - 2026-05-14

### Added

- **[gdrive_recover 1.25.0]** `--skip-existing` flag for `recover-and-download`: skips download
  when the local target already exists as a regular file (`Path.is_file()`); mutually exclusive
  with `--overwrite`; successful skips counted in `stats["skipped_existing"]` and included in
  the success-rate numerator; collision-handling and re-run idempotency documented.
  → Full detail: [src/python/cloud/CHANGELOG.md](src/python/cloud/CHANGELOG.md)

## [2.13.0]–[2.13.9] - 2026-05-12

### Added

- **[Python]** Python 3.14 compatibility declared and verified across all source, tests, and
  tooling; PyPI classifiers added for 3.12, 3.13, 3.14; `python_requires` raised from `>=3.7`
  to `>=3.10` (PEP 604 union-type syntax is the true minimum).

### Changed

- **[requirements / tooling]** Python 3.14 compatibility pass: numpy widened to
  `>=2.3.0,<3.0.0`; opencv relaxed to `>=4.13.0,<5.0.0`; `psycopg2` switched to
  `psycopg2-binary`; `oauth2client` removed (unmaintained, covered by `google-auth`);
  `google-auth-httplib2` floor raised to `>=0.2.0`; Black `target-version` corrected to
  `py312` (invalid `py314` caused Python 2-compatible output); mypy `python_version` corrected
  to `3.10`; pre-commit interpreter version pin removed; lock file refreshed.
- **[CI]** All workflow `python-version` pins updated to `3.14`; `concurrency` groups added
  to `sonarcloud.yml`, `code-formatting.yml`, `security-scan.yml`, `validate-modules.yml`, and
  `environment-validation.yml` to prevent duplicate scans on PR merge.

### Fixed

- **[gdrive_auth]** Four-patch hardening series: `PermissionError` in `_load_creds_from_token`
  no longer swallowed silently; distinct read/write permission log messages added; token write
  uses atomic write-via-temp-rename to avoid `ERROR_ACCESS_DENIED` on hidden files (Windows);
  `_RequestsHttpAdapter._Resp` now lowercases response headers, fixing silent 1 MiB download
  truncation for multi-chunk files.
  → Full detail: [src/python/cloud/CHANGELOG.md](src/python/cloud/CHANGELOG.md)
- **[gdrive_state]** `_save_state` now creates the state-file parent directory if absent.
  → Full detail: [src/python/cloud/CHANGELOG.md](src/python/cloud/CHANGELOG.md)

## [2.12.10] - 2026-04-05

### Fixed

- **[FileDistributor]** Removed direct `Write-Host` from `Invoke-FileDistribution`; completion
  messages now flow exclusively through `Write-LogInfo` (issue #819). Bumped to
  `FileDistributor.ps1` 4.7.12 / module 1.1.12.

## [2.12.9] - 2026-04-05

### Fixed / Changed

- **[FileDistributor]** State helpers made parameter-explicit (no script-scope free variables);
  post-processing functions switched from `LogMessage` to `Write-Log*` framework APIs;
  division-by-zero progress threshold guarded; `Move-ToRecycleBin` / `Remove-DistributionFile`
  use `-LiteralPath`; CP3 checkpoint now saves `sourceFiles`; retry helpers consolidated from
  `Private/RetryOps.ps1` into `Core/ErrorHandling` / `Core/FileOperations`; missing source
  files no longer abort distribution (race handling) (issues #779, #816, #817).
  → Full detail: [FileDistributor.CHANGELOG.md](src/powershell/file-management/FileDistributor.CHANGELOG.md)

## [2.12.5]–[2.12.8]

- Internal iterations rolled into [2.12.9].

## [2.12.0]–[2.12.4] - 2026-03-27 → 2026-03-29

### Changed

- **FileDistributor state/lock modularization + PurgeLogs integration**
  - Moved state helpers to `FileManagement/FileDistributor/Private/State.ps1` and lock helpers
    to `Private/FileLock.ps1`.
  - Renamed persistence/locking to approved verbs (`Save-DistributionState`,
    `Restore-DistributionState`, `Lock-DistributionStateFile`, `Unlock-DistributionStateFile`).
  - Replaced inline startup log cleanup with `Core/Logging/PurgeLogs` `Clear-LogFile`.
  - Added `Clear-LogFile -BeforeTimestamp` support and cross-runtime timestamp parsing
    compatibility for `-BeforeTimestamp` and `-RetentionDays`.
  - Added standalone/import-only compatibility so `Clear-LogFile` safely runs when
    `Initialize-Logger` is unavailable.

### Fixed

- **FileDistributor startup binding safety**: removed unsupported `-WarningsSoFar` /
  `-ErrorsSoFar` arguments from `New-FileQueue` calls in parameter validation.

## [2.10.0]–[2.11.0] - 2026-03-26

### Changed

- **FileDistributor Main decomposition + shared helpers**
  - `Main` decomposed into 6 phase functions: `Invoke-ParameterValidation`,
    `Invoke-RestoreCheckpoint`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`,
    `Invoke-EndOfScriptDeletion`, `Invoke-PostRunCleanup`.
  - `Invoke-FileMove` private helper unifying conflict resolution, retry, delete-mode handling,
    and progress reporting across all 5 distribution algorithms.
  - `Get-SubfolderFileCounts` shared enumerate/count helper centralizing subfolder normalization
    and per-folder file counting.
  - `New-CheckpointPayload` helper for standardized checkpoint state.
  - `Core/ErrorHandling` v1.1.0: `-IgnoreFileNotFound` switch on `Invoke-WithRetry` — skips
    with a warning on `ItemNotFoundException` without retry or rethrow.
  - Plus targeted bug fixes for checkpoint binding, target-root containment, and EndOfScript
    signalling.

## [2.9.0]–[2.9.1] - 2026-03-25

- Added `.mp4` support to FileDistributor (v4.5.0).
- Ignored pygments ReDoS `GHSA-5239-wwwm-4pmq` in pip-audit until patch available.

## [2.8.0] - 2026-03-24

- Renamed `Convert-ImageFile.ps1` → `Move-ImageFileToBatch.ps1` to reflect actual behavior;
  updated docs.

## [2.7.0]–[2.7.6] — CI/logging cleanup series

- Removed Safety; standardized on `pip-audit`; fixed Remove-MergedGitBranch dry-run and
  FileDistributor v4.4.1 output.
- Added `FileManagement/FileQueue` module (#602), `docs/ENVIRONMENT.md` (#606), and PostgreSQL
  backup automation; replaced `Write-Host` → `Write-Information` with stream guidelines (#632).
- Replaced 33 empty catch blocks with explicit intent across PowerShell scripts/modules. (#1)

## [2.6.0] - 2025-12-06

- Replaced legacy module deployment config with TOML (`psmodule.toml`) and optional local
  overrides. (#604)

## [2.5.0] - 2025-12-06

- Added `FileSystem` core module with directory/path helpers; migrated key scripts with unit
  tests. (#601)

## [2.4.1] - 2025-12-06

- Established mypy/typing infrastructure with CI/pre-commit integration; added coverage for
  error-handling, logging, data-processing, and backup reliability tests. (#594)

## [2.3.1] - 2024-06-07

- Enabled pip, npm, and PowerShell module caching; pinned all 23 Python dependencies; updated
  vulnerable packages; CI quality gates made blocking. (#519, #520, #521)

---

## Sync-MacriumBackups.ps1 — Pre-2.7.6 Script Version History (archived)

Archived script-only history from before numbered project releases. For consolidated release
tracking, see [2.7.6] and [Unreleased].

- **v2.6.0** (2026-01-15) - Refactored `Initialize-StateFile`; introduced `$ScriptVersion` and
  state file `scriptVersion` tracking.
- **v2.5.0** (2026-01-14) - Added sync duration tracking and corrupt state file recovery.
- **v2.4.0** (2026-01-13) - Added `-AutoResume` / `-Force` flags and `Invoke-AutoResumeLogic`.
- **v2.3.0** (2026-01-13) - Added named-mutex single-instance locking with
  `AbandonedMutexException` handling.
- **v2.2.0** (2026-01-13) - Added persistent JSON state tracking
  (`Sync-MacriumBackups_state.json`).
- **v2.1.0** (2026-01-13) - Centralised logging in `Scripts\\logs` and switched rclone logging
  to `--log-file`.
- **v2.0.0** (2025-11-16) - Migrated logging to `PowerShellLoggingFramework.psm1`.
- **v2.6.1–v2.6.6** (2026-01-15) - rclone flag compatibility, sanitised command logging
  refinements, and AutoResume `reason` property bug fix.

---

## [Pre-release] — 2024 Foundation

- Testing framework — pytest + Pester + SonarCloud integration.
- Git hooks + pre-commit framework — PSScriptAnalyzer, Pylint, Bandit, Black, SQLFluff,
  Commitizen.
- Module deployment — `.psd1` manifests, `Deploy-Modules.ps1`, `install-modules.sh`.
- Shared utilities — `ErrorHandling`, `FileOperations`, `ProgressReporter` (PowerShell) +
  Python equivalents.
- `ARCHITECTURE.md` + `docs/architecture/` diagrams.
- Automated release workflow + `bump-version.sh`.
- Centralised env vars (`.env.example`, `scripts/*-Environment.ps1`) + portable Task Scheduler
  templates.
- CI quality gates (blocking pre-commit, Pylint, Bandit, PSScriptAnalyzer, SonarCloud).
- Pinned Python dependencies + automated dependency security scanning.

*See #455–#521 for issue-by-issue detail.*
