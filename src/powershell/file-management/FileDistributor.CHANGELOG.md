# CHANGELOG — FileDistributor

## 4.8.3 — 2026-04-12

### Changed

- Made `$script:Version` the single hand-maintained script-version literal in `FileDistributor.ps1`.
  The comment-based help `.VERSION` field and `.NOTES` version line now reference `$script:Version`
  instead of duplicating hardcoded numeric values.
- Added CI-covered drift protection via a dedicated Pester test that checks script version metadata
  and verifies the latest `FileDistributor.CHANGELOG.md` release heading matches `$script:Version`.
- Documented the versioning model distinction: script version (`FileDistributor.ps1`) and module
  version (`FileDistributor.psd1`) are intentionally independent.

## 4.8.2 — 2026-04-11

### Changed

- Moved the `-Help` short-circuit check to immediately after the `param(...)` block, before any
  `Import-Module` calls, so requesting help on a workstation with Core/FileManagement modules
  uninstalled still prints help and exits 0 without import errors.
- Replaced the ~70-line hardcoded `Write-Host` help block with a single
  `Get-Help -Full $PSCommandPath` call; comment-based help is now the sole source of truth and
  includes all parameters (`-MaxFilesToCopy`, `-StateFilePath`, `-RandomNameModulePath`,
  `-ConsolidateToMinimum`, `-RebalanceToAverage`, `-RebalanceTolerance`, `-RandomizeDistribution`,
  `-MaxBackoff`) that were absent from the old hardcoded block.
- Changed bare `exit` in the help branch to `exit 0` for an explicit success exit code.
- Repaired mojibake in comment-based help (`module's`, `Source→Target`, `±10%`) caused by a prior
  Windows-1252 save; file is now saved as UTF-8 with BOM (PowerShell 5.1 compatible).

## 4.8.1 — 2026-04-11

### Changed

- Moved `Get-BestReceiver` helper out of the nested function definition inside `Invoke-FolderRebalance`
  and into module-private scope (`Private/Distribution.ps1`), alongside the other distribution
  helpers. The function is no longer re-defined on every call to `Invoke-FolderRebalance` and can
  now be unit-tested in isolation.
- Changed `Remove-Item -Path $StateFilePath -Force` in `Invoke-PostRunCleanup` to use
  `-LiteralPath` and `-ErrorAction SilentlyContinue` so a missing or already-removed state file
  no longer emits a spurious non-terminating error on clean first runs.
- Bumped `FileDistributor` module version to `1.2.1`.

## 4.8.0 — 2026-04-05

### Changed

- Consolidated `FileDistributor` module loading so private helpers are loaded once in module scope instead of being re-dot-sourced in `FileDistributor.ps1`.
- Removed redundant `ErrorHandling` and `FileOperations` imports from `FileDistributor.psm1`; these Core modules are now imported once in `FileDistributor.ps1` before loading `FileDistributor.psd1`.
- Promoted orchestration functions to module `Public/` exports: `Initialize-FileDistributorPaths`, `Invoke-ParameterValidation`, `Invoke-RestoreCheckpoint`, `New-CheckpointPayload`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-PostRunCleanup`, and `Invoke-DistributionLockRelease`.
- Replaced remaining private-module `LogMessage` calls with framework-native `Write-Log*` functions in `Private/FileLock.ps1`, `Private/State.ps1`, and `Private/Serialization.ps1`.
- Moved `Test-EndOfScriptCondition` to `Private/OrchestratorHelpers.ps1` to support module-scope `Invoke-EndOfScriptDeletion`.
- Removed the dead `Write-DistributionSummary` duplicate from `FileDistributor.ps1`; the canonical implementation remains in `Private/Distribution.ps1`.
- Bumped `FileDistributor` module version to `1.2.0`.
- Bumped script version to `4.8.0`.

## 4.7.2 — 2026-04-02

### Fixed

- Updated `Invoke-FileMove` race handling so source files that disappear between discovery and copy are logged as warnings and skipped instead of aborting distribution.
- Bumped `FileDistributor` module version to `1.1.2`.

## 4.7.1 — 2026-04-02

### Changed

- Replaced script-local retry/file-operation helpers with shared Core modules (`Core/ErrorHandling` + `Core/FileOperations`) and removed direct `Private/RetryOps.ps1` loading from script orchestration.
- Updated orchestration call paths to use `Copy-FileWithRetry`, `Remove-FileWithRetry`, and `Invoke-WithRetry -IgnoreFileNotFound`.
- Bumped `FileDistributor` module version to `1.1.1`.

## 4.7.x (rollup) — 2026-04-01 to 2026-04-05

Addresses script-scope coupling issues that surfaced after functions were moved into the `FileDistributor` module in 4.7.0. Module versions advanced from `1.1.0` to `1.1.13`.

### Changed

- Replaced all `LogMessage` calls (a script-scope helper defined only in `FileDistributor.ps1`) with framework-native `Write-Log*` functions (`Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, `Write-LogDebug`) in `Private/PathHelpers.ps1` (`Resolve-SubfolderPath`), `Private/Distribution.ps1` (`Write-DistributionSummary`), and the post-processing functions `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize`. Removed the stale `Write-Host` completion line from `Invoke-FileDistribution` in favour of `Write-LogInfo`.

### Changed

- Refactored `Save-DistributionState`, `Restore-DistributionState`, and `Write-JsonAtomically` in `Private/State.ps1` to accept `$StateFilePath`, `$RetryDelay`, `$RetryCount`, and `$MaxBackoff` as explicit parameters instead of reading from outer script scope. Updated checkpoint/restart call sites in `FileDistributor.ps1` accordingly.

### Fixed

- Fixed CP3 `New-CheckpointPayload` call in `Invoke-DistributionPhase` to include `-IncludeSourceFiles` and `-SourceFiles $RunState.sourceFiles`, preventing a restart from CP3 from silently skipping the distribution phase.
- Fixed `Invoke-EndOfScriptDeletion` using unqualified `$Warnings`/`$Errors` instead of `$script:Warnings`/`$script:Errors`, which could silently yield `0` and allow deletion to proceed despite accumulated warnings or errors.

### Changed

- Restored warning/error accounting for module-scope functions: added optional `[ref]$WarningCount` and `[ref]$ErrorCount` parameters to `Invoke-FileMove`, `Invoke-FileDistribution`, `Invoke-TargetRedistribution`, and `Resolve-SubfolderPath`; all `Write-LogWarning`/`Write-LogError` call sites now increment the provided counter refs. Call sites in `Invoke-DistributionPhase` and post-processing functions pass `([ref]$script:Warnings)` / `([ref]$script:Errors)`, preserving the `EndOfScriptDeletionCondition` gate.
- Propagated `$MaxBackoff` to `Remove-DistributionFile` and to `Invoke-FolderRebalance`, `Invoke-FolderConsolidation`, and `Invoke-DistributionRandomize`, threading it through to every `Invoke-FileMove` and `Invoke-WithRetry` call site so a user-supplied value is no longer silently ignored during post-processing.

### Changed

- Moved post-processing algorithms `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum` into `FileManagement/FileDistributor/Public` as `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`, and `Invoke-FolderConsolidation`; updated `Invoke-PostProcessingPhase` accordingly.

### Fixed

- Fixed division-by-zero / flood logging in `Invoke-FolderRebalance` and `Invoke-DistributionRandomize`: replaced inline division expressions in progress-log guards with a pre-computed `$threshold` set to `[int]::MaxValue` when the denominator is 0.
- Fixed a race condition in `Invoke-TargetRedistribution` where `Get-Random -Count $excess` could throw if files were deleted between the cached snapshot and the actual enumeration; excess count is now clamped with `[Math]::Min()`.

### Fixed

- Fixed `-Files` parameter type in `Invoke-FileDistribution` from `[string[]]` to `[object[]]` so `FileSystemInfo` inputs are not silently coerced to strings at binding time.
- Removed vestigial `[int]$TotalFiles` from `Invoke-TargetRedistribution` and updated `Invoke-DistributionPhase` call sites to stop passing `-TotalFiles 0`.
- Removed an unreachable inner `if ($normalizedSubfolders.Count -eq 0)` guard in `Invoke-TargetRedistribution`; the earlier normalization guard already ensures at least one valid destination subfolder.

### Added

- Added a unit test asserting `Invoke-FileDistribution` exposes `System.Object[]` for `-Files`.

## 4.7.0 — 2026-04-01

### Changed

- Moved `DistributeFilesToSubfolders` → `Invoke-FileDistribution` (public) and `RedistributeFilesInTarget` → `Invoke-TargetRedistribution` (public) from `FileDistributor.ps1` into `Public/Invoke-FileDistribution.ps1` and `Public/Invoke-TargetRedistribution.ps1` in the `FileManagement/FileDistributor` module.
- Moved retry I/O helpers (`Invoke-WithRetry`, `Copy-ItemWithRetry`, `Remove-ItemWithRetry`, `Rename-ItemWithRetry`) from `FileDistributor.ps1` into new `Private/RetryOps.ps1` in the module; replaced `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError` and added `$MaxBackoff` parameter to the `*-ItemWithRetry` wrappers.
- Moved `Get-SubfolderFileCounts` from `FileDistributor.ps1` into new `Private/Distribution.ps1` in the module; replaced `LogMessage` calls with framework-native `Write-Log*` calls.
- Updated `Private/FolderOps.ps1`: replaced all `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError`; added explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff` parameters to `Move-ToRecycleBin` and `Remove-DistributionFile`; added `$MaxBackoff` parameter to `Invoke-FileMove` and threaded it through to `Move-ToRecycleBin` and `Copy-ItemWithRetry`.
- Updated `FileDistributor.ps1` to dot-source `Private/RetryOps.ps1` and `Private/Distribution.ps1`; updated `Invoke-DistributionPhase` to call `Invoke-FileDistribution` and `Invoke-TargetRedistribution` with explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff`; updated `Invoke-EndOfScriptDeletion` to pass retry params to `Remove-DistributionFile`.
- Bumped `FileDistributor` module version to `1.1.0`; updated `FunctionsToExport` in `FileDistributor.psd1` to include `Invoke-FileDistribution` and `Invoke-TargetRedistribution`.
- Script reduces by ~475 lines (2102 → 1627).

## 4.6.x (module-extraction sprint rollup) — 2026-03-26 to 2026-04-01

### Changed

- Split `FileDistributor.ps1` orchestration into phase functions and extracted shared algorithm helpers (including `Invoke-FileMove`, `Get-SubfolderFileCounts`, and `New-CheckpointPayload`) to remove duplicated copy/move/checkpoint/counting logic across distribution and post-processing flows.
- Introduced the internal `FileManagement/FileDistributor` module scaffold and migrated serialization, path, file/folder operation, and state-adjacent helper functions out of script scope into module private files with approved PowerShell verb naming.
- Consolidated startup log cleanup by delegating inline log-trimming logic to `Core/Logging/PurgeLogs` (`Clear-LogFile`), while preserving retention, timestamp filtering, and truncation behavior.
- Reduced script-scope coupling by threading runtime values explicitly through checkpoint/orchestration paths (`SessionId`, `DeleteMode`, `SourceFolder`, `MaxFilesToCopy`, `FilesPerFolderLimit`) and by standardizing helper contracts around explicit parameters.
- Moved detailed FileDistributor release notes from script `.NOTES` to this standalone changelog and kept script header notes concise with a direct changelog pointer.

### Fixed

- Restored queue-signal integrity and safety checks during modularization: EndOfScript queue failures are surfaced as warnings, single-item checkpoint payloads are accepted, and subfolder candidate normalization enforces target-root containment with fallback candidate handling on scan failures.
- Restored post-run file-count integrity validation/warnings for both distribution and rebalance-only modes, preserving discrepancy detection that regressed during early 4.6 refactors.

## 4.1.0–4.5.0 (feature/checkpoint rollup) — 2026-01-05 to 2026-03-25

### Added

- Added optional post-processing modes for target-only balancing:
  - `-RandomizeDistribution` (full randomized redistribution; **Checkpoint 8**)
  - `-RebalanceTolerance` (custom tolerance for `-RebalanceToAverage`)
  - Rebalance-only execution by omitting `-SourceFolder` (auto `MaxFilesToCopy=0`)
- Added `.mp4` support to the distributed extension set in v4.5.0.

### Changed

- Switched placement from "fill emptiest first" to weighted-random assignment based on remaining per-folder capacity to improve spread across eligible subfolders.
- Rebalance-only flows now suppress source-copy messaging and show target-only summaries.

### Fixed

- Improved operator feedback for no-op/early-exit rebalance/consolidation/randomization paths (for example: already balanced, insufficient folders, no feasible moves, no files).

### Notes

- All features in this range are opt-in and non-breaking.
- Checkpoint map in this range: **CP8** = randomization complete.

## 3.3.0–3.5.0 (feature/checkpoint rollup) — 2025-10-02

### Added

- Added staged post-copy workflows:
  - Source→target distribution phase inserted before within-target redistribution (**Checkpoint 4**)
  - `-ConsolidateToMinimum` for packing into the minimum number of folders (**Checkpoint 6**)
  - `-RebalanceToAverage` for ±10% average balancing (**Checkpoint 7**)

### Changed

- Renumbered "within-target redistribution completed" from **CP4** to **CP5** after introducing the new source→target stage.
- Preserved restart-aware gating so each optional phase runs only when requested and only when its checkpoint has not yet been recorded.

### Notes

- `-RebalanceToAverage` and `-ConsolidateToMinimum` are mutually exclusive.
- No breaking parameter changes in this range.

## 3.2.0 — 2025-09-30

### Added

- Conditional debug logging: `DEBUG:` messages are emitted only when running with the `-Debug` switch.

## 3.1.0–3.1.26 (rollup) — 2025-09-28 → 2025-09-30

### Added

- **`-MaxFilesToCopy`:** Cap per-run copies (`-1` = all, `0` = none, `N` = first N); persisted and restart-aware.

### Changed

- Chooser hardening: candidates built from fresh target enumeration, canonicalized with `GetFullPath`, deduplicated, and validated against target root; state persists selected files for restart-matching; locking uses capped exponential backoff with jitter.

### Fixed

- Hardened destination path normalization to prevent root-landing, drive-letter collapses, and mixed-case escapes.

## 3.0.0–3.0.9 (rollup) — 2025-09-18 → 2025-09-25

### Changed

- **⚠️ Breaking:** Random name provider is module-only; `-RandomNameScriptPath` removed. Import order: `-RandomNameModulePath` → script-root module → `Import-Module RandomName` from `$env:PSModulePath`.

### Added

- **`-RandomNameModulePath`** to explicitly point to the RandomName module.

### Fixed

- Path-safety normalization: block relative/drive-like destinations; normalize subfolder lists to `.FullName`; prevent root-landing during distribution and on restart (filter malformed state entries; create emergency subfolder if needed). Includes PowerShell 5.1 compatibility and auto-resolved log/state paths when pointing to an existing directory.

### Notes

- If you previously ran with `-Restart`, delete stale state files (and `.bak`/`.sha256`) before rerunning to avoid inheriting malformed subfolder lists.

## 2.0.0 — 2025-09-14

### Changed

- **⚠️ Breaking:** Source enumeration is now recursive; all files under `-SourceFolder` (including nested subdirectories) are processed. Previously only top-level files were handled.

## 1.0.0–1.7.0 (rollup) — 2025-09-14

### Added

- Exponential I/O retry wrappers with `-MaxBackoff` parameter to cap backoff (default 60 s).
- Dynamic path resolution for logs/state: user-provided → script-root → `%LOCALAPPDATA%` → `%TEMP%`.
- `-RandomNameScriptPath` parameter; resolves `randomname.ps1` via parameter → script root → `%PATH%`.
- Atomic state-file I/O: `.tmp`-then-replace write, `.bak` fallback, `.sha256` integrity sidecar.
- Session-scoped deletion queue using `SessionId` for end-of-script deletion hardening.

### Changed

- Distribution: switched from round-robin to random-balanced placement biased toward least-filled subfolders.
