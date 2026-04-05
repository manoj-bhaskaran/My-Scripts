# CHANGELOG

## 4.8.0 — 2026-04-05

### Fixed

- Fixed `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize` in the `FileManagement/FileDistributor` module calling the script-scope helper `LogMessage` (defined only in `FileDistributor.ps1`) and the script-scope helper `Write-DistributionSummary` (also defined only in `FileDistributor.ps1`) instead of the framework-native `Write-Log*` functions. When called as standalone module functions these calls resolved to nothing (or threw `CommandNotFoundException`), silently suppressing all log output and distribution-summary tables from post-processing operations. All `LogMessage` calls have been replaced with the appropriate `Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, or `Write-LogDebug` call; warning and error increments that `LogMessage` provided via `$script:Warnings`/`$script:Errors` are now applied directly to the passed `$WarningCount`/`$ErrorCount` refs. `Write-DistributionSummary` has been added as a private module function in `Private/Distribution.ps1`, replacing its `LogMessage` calls with `Write-LogInfo`. Bumped `FileDistributor` module version to `1.1.9`.

## 4.7.9 — 2026-04-04

### Fixed

- Fixed `Resolve-SubfolderPath` in `Private/PathHelpers.ps1` silently dropping the warning counter increment when `[IO.Path]::GetFullPath` throws for a malformed rooted path. The original `LogMessage -IsWarning` call both logged and incremented `$script:Warnings`; the replacement `Write-LogWarning` only logs. Added an optional `[ref]$WarningCount` parameter to `Resolve-SubfolderPath` and increment it in the catch block. Threaded `-WarningCount $WarningCount` through both call sites in `Invoke-FileDistribution.ps1` so that `GetFullPath` failures are correctly reflected in the run's warning totals and the `-DeleteMode EndOfScript -EndOfScriptDeletionCondition NoWarnings` gate behaves as expected. Bumped `FileDistributor` module version to `1.1.8`.

## 4.7.8 — 2026-04-04

### Fixed

- Fixed `Resolve-SubfolderPath` in `Private/PathHelpers.ps1` calling the non-existent `LogMessage` function (a script-scope helper defined only in `FileDistributor.ps1`) from inside the module. Replaced the two `LogMessage` calls with `Write-LogDebug` and `Write-LogWarning`, consistent with every other logging call in the module. This caused a fatal `"LogMessage is not recognized"` error whenever `Resolve-SubfolderPath` was invoked during distribution. Bumped `FileDistributor` module version to `1.1.7`.

## 4.7.7 — 2026-04-02

### Fixed

- Fixed `Invoke-EndOfScriptDeletion` using unqualified `$Warnings` and `$Errors` instead of `$script:Warnings` and `$script:Errors` when computing the effective warning/error counts for the deletion gate. The unqualified references relied on PowerShell's implicit scope-chain resolution, which is inconsistent with every other reference to these accumulators in the script and could silently yield `0` in edge-case execution contexts, causing `EndOfScript` deletion to proceed even when the current session had accumulated warnings or errors. Fixed by qualifying both references with the explicit `$script:` prefix.

## 4.7.6 — 2026-04-02

### Fixed

- Fixed division-by-zero / flood logging in `Invoke-FolderRebalance` and `Invoke-DistributionRandomize`: replaced the inline `($plannedMoves / 10)` and `($filesMoving / 10)` expressions in the progress-log guard with a pre-computed `$threshold` that is set to `[int]::MaxValue` when the denominator is 0. This prevents the condition from becoming `0 -ge 0.0` (always true) and flooding the log with a progress line on every loop iteration when there is nothing to move. Bumped `FileDistributor` module version to `1.1.6`.

## 4.7.5 — 2026-04-02

### Fixed

- Fixed a race condition in `Invoke-TargetRedistribution` where `Get-Random -Count $excess` could throw _"Cannot process argument because the value of argument 'Count' is not valid"_ if another process deleted files from an overloaded folder between the cached file-count snapshot and the actual `Get-ChildItem` enumeration. The fix collects all current files into a variable first, then clamps the excess count to the actual file count using `[Math]::Min()`, and skips `Get-Random` entirely when all files need to be redistributed. Bumped `FileDistributor` module version to `1.1.5`.

## 4.7.4 — 2026-04-02

### Fixed

- Propagated `$MaxBackoff` to `Invoke-FolderRebalance`, `Invoke-FolderConsolidation`, and `Invoke-DistributionRandomize`: added `[int]$MaxBackoff = 60` parameter to each function and threaded it through to every `Invoke-FileMove` call (and the `Invoke-WithRetry` subfolder-deletion call in `Invoke-FolderConsolidation`). Updated the three call sites in `Invoke-PostProcessingPhase` to pass `-MaxBackoff $MaxBackoff`, ensuring a user-supplied `-MaxBackoff` value is no longer silently ignored during post-processing.
- Bumped `FileDistributor` module version to `1.1.3`.

## 4.7.3 — 2026-04-02

### Fixed

- Added `-IncludeSourceFiles` and `-SourceFiles $RunState.sourceFiles` to the CP3 `New-CheckpointPayload` call in `Invoke-DistributionPhase`. Previously the CP3 payload omitted `sourceFiles`, so restarting from CP3 left `$RunState.sourceFiles` empty and silently skipped the entire source-to-target distribution phase.

## 4.7.1 — 2026-04-01

### Fixed

- Restored warning/error accounting for module-scope distribution functions: added optional `[ref]$WarningCount` and `[ref]$ErrorCount` parameters to `Invoke-FileMove`, `Invoke-FileDistribution`, and `Invoke-TargetRedistribution`; all `Write-LogWarning`/`Write-LogError` call sites now increment the provided counter refs. Call sites in `Invoke-DistributionPhase` and the three remaining script-level algorithms pass `([ref]$script:Warnings)` / `([ref]$script:Errors)`, preserving the `EndOfScriptDeletionCondition` gate.
- Propagated `$MaxBackoff` to `Remove-DistributionFile` (added parameter with default 60) and threaded it through from `Invoke-FileMove`'s immediate-delete path, matching the recycle-bin and copy paths for consistent backoff behaviour.
- Modularised post-processing algorithms: moved `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum` into `FileManagement/FileDistributor/Public` as `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`, and `Invoke-FolderConsolidation`, and updated `Invoke-PostProcessingPhase` accordingly.

## 4.7.0 — 2026-04-01

### Changed

- Moved `DistributeFilesToSubfolders` → `Invoke-FileDistribution` (public) and `RedistributeFilesInTarget` → `Invoke-TargetRedistribution` (public) from `FileDistributor.ps1` into `Public/Invoke-FileDistribution.ps1` and `Public/Invoke-TargetRedistribution.ps1` in the `FileManagement/FileDistributor` module.
- Moved retry I/O helpers (`Invoke-WithRetry`, `Copy-ItemWithRetry`, `Remove-ItemWithRetry`, `Rename-ItemWithRetry`) from `FileDistributor.ps1` into new `Private/RetryOps.ps1` in the module; replaced `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError` and added `$MaxBackoff` parameter to the `*-ItemWithRetry` wrappers.
- Moved `Get-SubfolderFileCounts` from `FileDistributor.ps1` into new `Private/Distribution.ps1` in the module; replaced `LogMessage` calls with framework-native `Write-Log*` calls.
- Updated `Private/FolderOps.ps1`: replaced all `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError`; added explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff` parameters to `Move-ToRecycleBin` and `Remove-DistributionFile`; added `$MaxBackoff` parameter to `Invoke-FileMove` and threaded it through to `Move-ToRecycleBin` and `Copy-ItemWithRetry`.
- Updated `FileDistributor.ps1` to dot-source `Private/RetryOps.ps1` and `Private/Distribution.ps1`; updated `Invoke-DistributionPhase` to call `Invoke-FileDistribution` and `Invoke-TargetRedistribution` with explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff`; updated `Invoke-EndOfScriptDeletion` to pass retry params to `Remove-DistributionFile`.
- Bumped `FileDistributor` module version to `1.1.0`; updated `FunctionsToExport` in `FileDistributor.psd1` to include `Invoke-FileDistribution` and `Invoke-TargetRedistribution`.
- Script reduces by ~475 lines (2102 → 1627).

## 4.6.17 — 2026-04-01

### Changed

- Moved serialization helpers `ConvertItemsToPaths` and `ConvertPathsToItems` from `FileDistributor.ps1` into `Private/Serialization.ps1` in the `FileManagement/FileDistributor` module.
- Moved folder/file operation helpers from `FileDistributor.ps1` into `Private/FolderOps.ps1`: renamed `ResolveFileNameConflict` → `Resolve-DistributionFileName`, `CreateRandomSubfolders` → `New-DistributionSubfolders`, `Remove-File` → `Remove-DistributionFile`; retained `Move-ToRecycleBin` (added Windows-only guard comment) and `Invoke-FileMove` unchanged.
- Updated `Invoke-FileMove` (now in `FolderOps.ps1`) to call `Resolve-DistributionFileName` and `Remove-DistributionFile` via the new approved names.
- Updated `Invoke-DistributionPhase` call site to use `New-DistributionSubfolders` instead of `CreateRandomSubfolders`.
- Updated `Invoke-EndOfScriptDeletion` call site to use `Remove-DistributionFile` instead of `Remove-File`.
- Added dot-source imports for `Private/Serialization.ps1` and `Private/FolderOps.ps1` in `FileDistributor.ps1`.
- Bumped `FileDistributor` module version to `1.0.2`.

## 4.6.14 — 2026-03-29

### Changed

- Added a new internal `FileManagement/FileDistributor` support module scaffold (`FileDistributor.psd1`, `FileDistributor.psm1`, and `Private/PathHelpers.ps1`) as the first step of Proposal 6 module splitting.
- Moved six low-risk path/filesystem helper functions from `FileDistributor.ps1` into `Private/PathHelpers.ps1`: `New-Ref`, `New-Directory`, `Resolve-PathWithFallback`, `Resolve-FilePathIfDirectory`, `Initialize-FilePath`, and `Resolve-SubfolderPath`.
- Updated `FileDistributor.ps1` to import the new `FileDistributor` module alongside `FileQueue`, reducing script size and centralizing helper loading.

## 4.6.13 — 2026-03-27

### Fixed

- Restored fallback-candidate behavior in `Get-SubfolderFileCounts` for scan failures: when subfolder enumeration throws, the helper now attempts to continue with caller-provided candidates (after target-root normalization/validation) instead of unconditionally returning `$null`.
- Updated distribution/redistribution call sites to pass known subfolder candidates to the helper so transient enumeration issues do not skip the phase when safe fallback inputs are available.

## 4.6.12 — 2026-03-27

### Changed

- Refactored subfolder enumeration/counting into a streamlined private `Get-SubfolderFileCounts` helper with optional zero-file inclusion and shared error handling for all five algorithms (`DistributeFilesToSubfolders`, `RedistributeFilesInTarget`, `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, `ConsolidateSubfoldersToMinimum`).
- Added private `Write-DistributionSummary` helper and wired it into rebalancing/randomization/consolidation flows for shared before/after distribution-table logging.
- Updated algorithm call sites to derive total file counts by summing helper-returned hashtable values instead of maintaining duplicated inline counting blocks.

## 4.6.11 — 2026-03-27

### Changed

- Refined private `Invoke-FileMove` to use explicit move inputs (`SourceFilePath`, `OriginalFileName`, `DestinationFolder`, `FolderCountRef`, delete mode, queue, counters, retry/progress settings) so algorithm helpers no longer rely on implicit state.
- Updated the shared move path so successful copy operations increment the caller-provided per-folder counter via `FolderCountRef`, keeping destination count tracking in one place.
- Updated all algorithm call sites (`DistributeFilesToSubfolders`, `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, `ConsolidateSubfoldersToMinimum`, and redistribution flow via `DistributeFilesToSubfolders`) to pass explicit move context into `Invoke-FileMove`.

## 4.6.10 — 2026-03-27

### Changed

- Removed inline `RemoveLogEntries` and inline log truncation (`ConvertToBytes` + direct `Clear-Content`) from `FileDistributor.ps1`.
- Added `PurgeLogs` module import and consolidated startup log-management into one `Clear-LogFile` call using `-BeforeTimestamp`, `-RetentionDays`, `-TruncateIfLarger`, and `-TruncateLog` as applicable.
- Preserved existing startup log-cleanup behavior while delegating implementation to the shared logging module.

## 4.6.9 — 2026-03-26

### Changed

- Reduced script-scope variable coupling in `FileDistributor.ps1` orchestration helpers by keeping effective runtime values on `RunState` and passing them explicitly to checkpoint/deletion flows.
- `SaveState` now takes `SessionId` as an explicit parameter, and checkpoint payload construction receives `DeleteMode`, `SourceFolder`, and `MaxFilesToCopy` explicitly.
- Distribution/post-processing phases now consume the effective `FilesPerFolderLimit` from validated runtime state instead of relying on script-scoped mutation.

## 4.6.8 — 2026-03-26

### Changed

- Moved the detailed FileDistributor release history from the script header (`.NOTES`) into this standalone changelog file.
- Kept only the current-version summary in `FileDistributor.ps1` and added a direct pointer to `./CHANGELOG.md`.

## 4.6.7 — 2026-03-26

### Fixed

- **Single-item checkpoint payload inputs restored:** `New-CheckpointPayload` now accepts scalar `subfolders`/`sourceFiles` values (for example `MaxFilesToCopy=1` or a single existing target subfolder), preserving prior behavior where `ConvertItemsToPaths` wrapped single items.

## 4.6.6 — 2026-03-26

### Changed

- **Checkpoint payload helper extracted:** Added `New-CheckpointPayload` to centralize common checkpoint state construction (`totalSourceFiles`, `totalSourceFilesAll`, `totalTargetFilesBefore`, `subfolders`, `deleteMode`, `SourceFolder`, `MaxFilesToCopy`) with optional `sourceFiles` and `FilesToDelete`.
- **Phase checkpoints deduplicated:** `Invoke-DistributionPhase` and `Invoke-PostProcessingPhase` now call the shared helper for checkpoints 2–8 instead of manually rebuilding near-identical hashtables.

## 4.6.5 — 2026-03-26

### Fixed

- **Target-root safety restored:** `Get-SubfolderFileCounts` now validates that normalized candidate folders are rooted under `TargetFolder`, preventing escaped destinations from being selected by distribution algorithms.
- **Fresh-scan fallback preserved:** if optional fresh subfolder enumeration fails, the helper now logs and continues with already supplied candidates instead of returning early; emergency-subfolder creation still applies when requested.

## 4.6.4 — 2026-03-26

### Changed

- **Shared subfolder count helper extracted:** Added `Get-SubfolderFileCounts` to centralize subfolder normalization, per-folder file counting, empty-candidate handling, and count map construction for distribution/rebalance algorithms.
- **Algorithm prologs deduplicated:** `DistributeFilesToSubfolders`, `RedistributeFilesInTarget`, `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum` now reuse the shared helper for their enumerate-and-count setup sequence.

## 4.6.3 — 2026-03-26

### Fixed

- **EndOfScript queue signal preserved:** `Invoke-FileMove` now returns queueing status and logs a warning when `Add-FileToQueue` fails, and `DistributeFilesToSubfolders` reports "pending deletion" only when queue insertion succeeds.

## 4.6.2 — 2026-03-26

### Changed

- **Shared file-move helper extracted:** Added private `Invoke-FileMove` to centralize conflict-safe destination naming, retried copy, delete-mode dispatch (`RecycleBin` / `Immediate` / `EndOfScript` queue), global file-counter updates, and progress reporting.
- **Distribution algorithms deduplicated:** `DistributeFilesToSubfolders`, `RedistributeFilesInTarget` (via `DistributeFilesToSubfolders`), `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum` now reuse the shared helper instead of duplicating copy/delete/progress loop internals.

## 4.6.1 — 2026-03-26

### Fixed

- **File-count integrity warnings restored:** `Invoke-PostRunCleanup` now validates before/after file counts and warns on discrepancies, restoring behaviour that was accidentally dropped during the 4.6.0 refactor.
  - **Distribution mode:** warns if `totalSourceFiles + totalTargetFilesBefore ≠ totalTargetFilesAfter` ("Sum of original counts does not equal the final count in the target. Possible discrepancy detected.")
  - **Rebalancing mode:** warns if `totalTargetFilesBefore ≠ totalTargetFilesAfter` ("File count changed during rebalancing. Possible discrepancy detected.")
  - Both branches also log a success message when counts match, confirming a clean run.

## 4.6.0 — 2026-03-26

### Changed

- **Orchestration refactor:** Split the monolithic `Main` function into discrete phase functions (`Invoke-ParameterValidation`, `Invoke-RestoreCheckpoint`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-PostRunCleanup`) for improved readability, testability, and checkpoint isolation.

## 4.5.0 — 2026-03-25

### Added

- **`.mp4` file extension support:** Added `.mp4` to the list of allowed file extensions for distribution.

## 4.4.1 — 2026-01-05

### Fixed

- **Console feedback for rebalancing operations:** Added console output for early exit conditions in `-RebalanceToAverage`, `-ConsolidateToMinimum`, and `-RandomizeDistribution` modes. Users now see clear messages when operations are skipped due to:
  - All subfolders already balanced within tolerance
  - Insufficient subfolders for rebalancing
  - No files to process
  - Already at or below minimal subfolder count
  - No feasible moves or capacity issues
- Previously these conditions were only logged to file, making it unclear why operations completed without action.
- **Cleaner output in rebalance-only mode:** Suppressed source-related messages when SourceFolder is not provided. Changes include:
  - "Preparing for distribution" message only shown when copying from source
  - "Enumerating source and target files..." changed to "Enumerating target files..." in rebalance-only mode
  - Removed redundant "Skipping source enumeration (rebalance-only mode)." message
  - File count summary shows only target count in rebalance-only mode
  - Separate "File Rebalancing Summary" with relevant information only (excludes source file counts, skipped extensions, and files selected for copying)

## 4.4.0 — 2026-01-05

### Added

- **Optional SourceFolder for rebalance-only mode:** SourceFolder parameter is now optional. When omitted, the script automatically runs in rebalance-only mode (no files copied from source).
  - **Use case:** Run `-RebalanceToAverage`, `-ConsolidateToMinimum`, or `-RandomizeDistribution` on existing target files without providing a source folder.
  - **Examples:**
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -RebalanceToAverage`
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -ConsolidateToMinimum`
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -RandomizeDistribution`
  - **Automatic behavior:** When SourceFolder is not provided, `MaxFilesToCopy` is automatically set to 0 and source enumeration is skipped.

### Changed

- Parameter validation logic: SourceFolder omission automatically enables rebalance-only mode
- Source file enumeration is completely skipped when running in rebalance-only mode
- State file restoration handles empty SourceFolder gracefully for rebalance-only sessions

### Notes

- No breaking changes. Existing behavior unchanged when SourceFolder is provided.
- Enhanced UX: Users no longer need to specify `-MaxFilesToCopy 0` for rebalance-only operations.

## 4.3.0 — 2026-01-05

### Added

- **`-RandomizeDistribution` parameter:** New optional switch to perform full randomized redistribution of ALL files across ALL existing subfolders. Completely ignores current distribution and redistributes from scratch.
  - **Behavior:** Enumerates all files in all subfolders, shuffles them randomly, then redistributes evenly using round-robin assignment through the shuffled list.
  - **Use case:** When you want to completely reset the distribution and achieve perfect randomization and balance. Particularly useful after multiple batches have created uneven distribution.
  - **Performance:** Moves many files (all files not already in their assigned destination). Use with caution on large datasets.
  - **Safety:** Respects `FilesPerFolderLimit`, uses existing `DeleteMode` for handling originals, supports progress tracking and retries.
  - **Mutual exclusivity:** Cannot be used with `-ConsolidateToMinimum` or `-RebalanceToAverage` (script will error).

### Restart semantics

- Introduces **Checkpoint 8** recorded after randomization. Randomization runs when `-RandomizeDistribution` is specified and `lastCheckpoint < 8`; otherwise it is skipped.

### Notes

- No breaking changes. Feature is opt-in and not performed unless `-RandomizeDistribution` is specified.

## 4.2.0 — 2026-01-05

### Added

- **`-RebalanceTolerance` parameter:** New optional parameter to configure the tolerance percentage for the `-RebalanceToAverage` feature. Defaults to 10, meaning folders are rebalanced to be within ±10% of the average file count.
  - **Usage:** `-RebalanceTolerance 15` will rebalance folders to be within ±15% of average instead of the default ±10%.
  - **Flexibility:** Allows users to control how strictly folders should be balanced. Lower values (e.g., 5) create tighter balance; higher values (e.g., 20) allow more variance.
  - The tolerance is applied to both donor identification (folders above `avg * (1 + tolerance/100)`) and receiver identification (folders below `avg * (1 - tolerance/100)`).

### Notes

- No breaking changes. Default behavior remains ±10% when `-RebalanceTolerance` is not specified.

## 4.1.0 — 2026-01-05

### Changed

- **Distribution algorithm:** Switched from "fill emptiest folder first" to **weighted random selection** based on available capacity. Files are now distributed randomly across multiple eligible folders, with probability weighted by each folder's remaining capacity (`FilesPerFolderLimit - currentCount`).
  - **Benefit:** Prevents all files from a batch going to a single newly-created folder. When new folders are created due to existing folders reaching the limit, files are spread across multiple folders rather than sequentially filling one at a time.
  - **Behavior:** Folders with more available capacity have higher probability of receiving files, but all eligible folders can receive files from the same batch, maintaining better distribution randomness.
  - The change applies to both source-to-target distribution and within-target redistribution phases.

### Notes

- No breaking changes or new parameters. Existing scripts will work unchanged but will see improved file distribution across folders.

## 3.5.0 — 2025-10-02

### Added

- **`-RebalanceToAverage` (opt-in):** After Source→Target and target-root redistribution, compute the **average files per existing subfolder** and move files so every subfolder is within **±10%** of that average. No subfolders are created or deleted, and `FilesPerFolderLimit` is always respected.
  - Identifies **donor** folders (`count > ceil(avg*1.1)` capped by limit) and **receiver** folders (`count < floor(avg*0.9)`), then transfers randomly selected files to meet deficits without exceeding per-folder limits.
  - Rebalancing uses existing safety semantics (randomized destination names, `DeleteMode`, retries, progress).

### Incompatibility

- `-RebalanceToAverage` is **mutually exclusive** with `-ConsolidateToMinimum`; specifying both results in an error.

### Restart semantics

- Introduces **Checkpoint 7** recorded after rebalancing. Rebalancing runs when `-RebalanceToAverage` is specified and `lastCheckpoint < 7`; otherwise it is skipped.

### Notes

- No breaking changes; feature is _not_ performed unless `-RebalanceToAverage` is passed.

## 3.4.0 — 2025-10-02

### Added

- **`-ConsolidateToMinimum` (opt-in):** New command-line switch that packs files into the **minimum number of subfolders** while honoring `FilesPerFolderLimit`. Runs **after** Source→Target copy and target-root redistribution **only when specified**.
  - Computes `needed = ceil(total_files / FilesPerFolderLimit)`.
  - Randomly chooses `needed` existing subfolders as keepers; moves files from other subfolders into keepers (never exceeding the limit).
  - Deletes subfolders that become empty after the move.
  - Uses existing safety semantics (randomized destination names, `DeleteMode`, retries, progress).

### Restart semantics

- Introduces **Checkpoint 6** recorded after consolidation. Consolidation runs when `-ConsolidateToMinimum` is specified and `lastCheckpoint < 6`; otherwise it is skipped.

### Notes

- No breaking changes. Consolidation is _not_ performed unless `-ConsolidateToMinimum` is passed.

## 3.3.0 — 2025-10-02

### Added

- **Checkpoint 4 + Source → Target distribution phase:** Selected source files (subject to `-MaxFilesToCopy`) are now copied into eligible target subfolders **before** any within-target redistribution (root or overloaded folders). This phase respects `-FilesPerFolderLimit` and your `-DeleteMode` (including `EndOfScript`, which queues originals for final cleanup).

### Changed

- The earlier “within-target redistribution completed” checkpoint has been **renumbered from CP4 to CP5**.

### Restart semantics

- Resume at **CP3** → runs the new Source→Target copy and saves **CP4**.
- Resume at **CP4** → skips Source→Target copy and runs within-target redistribution, then saves **CP5**.
- Resume at **CP5** → skips redistribution and proceeds to end-of-script actions (e.g., deletions).

### Notes

- No breaking parameter changes. Logging now includes a banner: _“Distributing N source file(s) to subfolders…”_ for the new phase.

## 3.2.0 — 2025-09-30

### Added

- **Conditional debug logging:** Debug messages ("DEBUG:") are now only written to the log file and console (via Write-Debug) when the script is run with the built-in -Debug switch. Added [CmdletBinding()] to enable common parameters, $script:DebugMode to detect mode, [switch]$IsDebug to LogMessage, and conditioned logging/output accordingly. This reduces log clutter in normal runs.

## 3.1.0–3.1.26 (rollup) — 2025-09-28 → 2025-09-30

### Added

- **`-MaxFilesToCopy`:** Cap per-run copies (`-1` all, `0` none, `N` first N); persisted and restart-aware.
- **Deeper diagnostics:** DEBUG tracing across enumeration, conversions, state I/O, candidate counts (eligible/min/candidates), and pre-normalization destination selection. `Resolve-SubfolderPath` logs `GetFullPath` attempts/exceptions.
- **Defensive last-mile checks:** Re-validate final destination; if invalid or the target root, auto-select a safe validated subfolder (create an emergency one if needed).

### Changed

- **Chooser hardening:** `DistributeFilesToSubfolders` builds candidates from a fresh enumeration of the target root plus caller input; canonicalizes with `GetFullPath`, enforces “under target root & not the root,” and dedupes. Wildcard tests removed.
- **State & restarts:** Persist enumeration totals and deterministic _selected_ files; restarts must match.
- **Enumeration:** Prefer `Get-ChildItem -LiteralPath -Force` with `.PSIsContainer`.
- **Progress/noise:** Separate **enumerated** vs **selected**; keep one consolidated DEBUG line per decision; drop verbose/duplicate logs.
- **Locking/backoff:** State-file locking now uses capped exponential backoff + small jitter and logs the last exception on failure; sidecar contention wait reduced 10s → 1s (still honors max-attempt backoff).
- **Typo fix:** Log label now prints `FilesPerFolderLimit`.

### Fixed

- **Root safety:** Block writes to the target **root** even if “under target”; reroute to a validated subfolder.
- **Normalization & escapes:** Replace wildcard checks with `[IO.Path]::GetFullPath(...)` + case-insensitive `StartsWith(...)` against a normalized target root; prevent root escapes, mixed-case false positives, and accidental root placement.
- **False “escaped target root ('')” warnings:** Recompute `targetRootNormalized` at function entry (or pass explicitly). Guard triggers only when `startsWithTarget` is false, destination equals root, or normalization fails.
- **Null-safe debug logging:** Recompute `$destNormalized` after fallback/emergency creation; warnings print `<null>` when unknown; all `StartsWith`/`IsPathRooted` calls are null-safe.
- **Candidate selection (scalar pipeline):** Wrap `$candidates` in `@()` to force array semantics; prevents string indexing that yielded drive letter `D` for single-item sets and eliminated “Destination escaped target root ('<null>')” during single-min-count redistribution.
- **Input/path hygiene:** Early-reject `C`, `C:`, `C:foo` forms; anchor relatives under `TargetRoot`; preserve special chars `()!@$~`.
- **Stability:** `ReleaseFileLock` is null-safe; enumeration filter no longer zeroes valid directories; sidecar writes (`FileDistributor-State.json.sha256`) are retried with clearer errors.

### Notes

- Eliminates spurious warnings like “Sanitizing non-rooted destination folder ''” and “using subfolder 'D'.”
- No breaking parameter/state changes beyond persisting `MaxFilesToCopy`; behavior is stricter and diagnostics clearer.

## 3.0.0–3.0.9 (rollup) — 2025-09-18 → 2025-09-25

### Changed (⚠️ Breaking)

- **Random name provider is module-only.** Removed legacy `randomname.ps1` and `-RandomNameScriptPath`. Import order: `-RandomNameModulePath` → script-root `powershell\module\RandomName\RandomName.psd1/.psm1` → `Import-Module RandomName` from `$env:PSModulePath`.

### Added

- **`-RandomNameModulePath`** to explicitly point to the RandomName module.

### Fixed

- **Path safety & normalization**
  - Block **relative/drive-like destinations** (e.g., `D\file.jpg`, `D`, `D:`). Non-absolute subfolder strings are remapped under **-TargetFolder**; chosen destinations are verified to be rooted and existing before copy.
  - Prevent destination collapsing to drive letters due to implicit `DirectoryInfo` casts. `DistributeFilesToSubfolders`/`RedistributeFilesInTarget` accept object arrays and normalize to `.FullName`; `CreateRandomSubfolders` returns `DirectoryInfo`. Consistent normalization when building subfolder lists.

- **Root-landing & restart hygiene (3.0.7–3.0.9)**
  - Avoid placing files in target **root** during source distribution; if a sanitized destination resolves to root while subfolders exist, re-select the least-filled subfolder.
  - On restart, **malformed subfolder entries** in state (e.g., `''`, `D`, `D:`, relative) no longer collapse to root. We filter out target root and non-folders; if none remain, create an **emergency** subfolder to avoid root placement.
  - Hardened `ConvertItemsToPaths` to handle `DirectoryInfo`/string mixes and skip empty values.
  - `RedistributeFilesInTarget` excludes the target root from its subfolder map and validates existence.

- **Deletion safety**
  - Prevent **double deletion** when `-DeleteMode EndOfScript`: target-root redistribution no longer queues root copies alongside sources in a way that removes both.

- **Progress & reliability**
  - Phase-aware progress denominators (source distribution, root redistribution, per-folder redistribution).
  - Fixed missing backticks in calls (including `Copy-ItemWithRetry` and a `DistributeFilesToSubfolders` invocation) that could mis-parse parameters.
  - Consistently pass `-RetryCount $RetryCount` when (re)acquiring the state lock; corrected a variable name in `LoadState`.

- **PowerShell 5.1 compatibility**
  - Replaced `Split-Path -LiteralPath ... -Parent` usages to avoid “Parameter set cannot be resolved…” errors.

- **Log/State path handling**
  - If `-LogFilePath`/`-StateFilePath` points to an **existing directory**, automatically use `FileDistributor-log.txt` / `FileDistributor-State.json` inside it and ensure directories/files exist before first write.

### Notes

- If you previously ran with `-Restart`, delete stale state files (and `.bak`/`.sha256`) before rerunning to avoid inheriting malformed subfolder lists.

## 2.0.0 — 2025-09-14

### Changed (⚠️ Breaking)

- **Source enumeration is now recursive by default (and only behavior):** All files under `-SourceFolder` (including nested subdirectories) are processed. Previously only top-level files were handled.
- Help/description updated to reflect recursion.
- Limitations updated (top-level only note removed).

## 1.0.0–1.7.0 (rollup) — 2025-09-14

### Added

- Exponential I/O retry wrappers (copy/delete/Recycle Bin moves) with `-ErrorAction Stop` and backoff.
- `-MaxBackoff` parameter to cap exponential backoff (default 60s).
- Windows-only dynamic path resolution for logs/state: user-provided → script-root → `%LOCALAPPDATA%` → `%TEMP%`.
- `-RandomNameScriptPath` parameter; resolves `randomname.ps1` via parameter → script root → `%PATH%` (errors if not found).
- Robust state-file handling: atomic write via same-directory `*.tmp` then replace, persistent `.bak`, `.sha256` integrity sidecar, auto-recovery from `.bak`, quarantine of corrupt primaries.
- Script header `.VERSION` and `CHANGELOG` sections.

### Changed

- **Distribution**: switched from round-robin to random-balanced placement biased to least-filled subfolders; applies to initial distribution and redistribution.
- **Naming**: removed upfront renaming of sources; destination names always randomized at copy time while preserving extensions.
- **End-of-script deletions hardened**:
  - Session-scoped deletion queue using persisted `SessionId`; only deletes items queued by the same session (including `-Restart`).
  - Aggregates warnings/errors across restarts when evaluating deletion conditions.
  - Queue stores metadata (`Path`, `Size`, `LastWriteTimeUtc`, `QueuedAtUtc`, `SessionId`) and verifies unchanged files before deletion; mismatches are skipped with a warning.
  - Back-compat: older string-only queues are wrapped with metadata on resume; persistence fixed to store the array (not a `[ref]`).
- **State I/O**: `SaveState`/`LoadState` refactored to atomic/verified helpers with precise recovery logging; loader always returns a Hashtable to keep `.ContainsKey()` reliable on Windows PowerShell 5.1+ and PowerShell 7+.
- **Paths & config**: removed user-specific defaults for `-SourceFolder`/`-TargetFolder` (must be provided); `LogFilePath`/`StateFilePath` now follow the dynamic resolution order; dropped hard-coded `$ScriptDirectory`.
- **Logging & docs**: centralized error/warning counting via `LogMessage`; updated `RetryDelay`/`RetryCount` docs; expanded examples (retry tuning, restart, end-of-script deletion); fixed `-RetryCount` default doc drift to 3.

### Notes

- State saves now include `WarningsSoFar`, `ErrorsSoFar`, and `SessionId` to enable safe resumptions.
- No functional changes in the 1.0.x patch rollup; behavior remained identical to 1.0.0 aside from documentation and traceability improvements.
