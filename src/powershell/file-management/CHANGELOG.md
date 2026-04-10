# CHANGELOG

## Table of Contents
- [Copy-AndroidFiles](#copy-androidfiles)
- [FileDistributor](#filedistributor)

## Copy-AndroidFiles


### 2.3.1 — 2026-04-10

#### Changed

- **Consolidated `Copy-AndroidFiles.ps1` version history into this changelog.** Removed the long inline multi-version `CHANGELOG` block from the script's comment-based help `.NOTES` section and replaced it with a concise version stamp plus a pointer to `CHANGELOG.md`, while preserving the existing `PREREQUISITES` and `TROUBLESHOOTING` help content unchanged.


### 2.3.0 — 2026-04-10

#### Changed

- **Implemented PowerShell parameter sets `Pull` and `Tar`.** Mode-specific parameters are now
  restricted to their respective parameter sets: `-Resume` and `-ProgressIntervalSeconds` belong
  to the `Pull` set; `-StreamTar` and `-MaxRetries` belong to the `Tar` set. PowerShell now
  rejects invalid combinations at binding time (e.g., `-Resume` with `-StreamTar`). The default
  parameter set is `Tar`, preserving existing default behaviour.

- **Retired the `-Mode` parameter.** The active transfer mode is now determined implicitly by
  `$PSCmdlet.ParameterSetName`. All internal `$Mode -eq 'tar'` / `$Mode -eq 'pull'` checks
  have been replaced with `$PSCmdlet.ParameterSetName -eq 'Tar'` / `'Pull'` comparisons. This
  eliminates the possibility of conflicting mode signals (e.g., `-Mode tar -Resume`).

- **Made `-PhonePath` and `-Dest` mandatory.** Personal hard-coded default values for both
  parameters have been removed. Both paths must be supplied explicitly on every invocation.


### 2.2.0 — 2026-04-10

#### Changed

- **Extracted `Invoke-ProgressWhileProcess` helper function** from `Copy-AndroidFiles.ps1`.
  The progress-polling loop (`while (-not $proc.HasExited) { ... Write-Progress ... }`) was
  duplicated across the pull-mode `$ShowProgress` block (lines 731–743) and the tar-to-file
  `$ShowProgress` block (lines 857–868). A single parameterised helper now handles both call
  sites: it accepts `Process`, `Activity`, `GetCurrentBytes` (scriptblock), `TotalBytes`, and
  `IntervalSeconds`, covers both the known-size (percentage) and unknown-size (MB-only) display
  branches, and calls `Write-Progress -Completed` before returning. The hard-coded `Start-Sleep 1`
  in tar mode is replaced by the explicit `-IntervalSeconds 1` argument, making the interval
  visible and documentable.


### 2.1.0 — 2026-04-07

#### Changed

- **Extracted `Write-VerifySummary` helper function** from `Copy-AndroidFiles.ps1`. The
  post-transfer verification output block was copy-pasted across all four transfer modes
  (resume pull, pull, stream-tar, tar-to-file), totalling ~95 redundant lines. A single
  parameterised helper now handles all modes: it accepts `LocalRoot`, `FilesBefore`,
  `BytesBefore`, `RemoteParent`, `RemoteLeaf`, `TotalBytes`, and `WarnMessage`, calculates
  post-transfer local counts/sizes, retrieves the remote file count, renders the comparison
  table, and emits any warning via `Write-LogWarning`.

#### Fixed

- **`Write-Warning` logging bug in TAR-to-file mode.** The verify path for tar-to-file
  called `Write-Warning` (built-in) instead of `Write-LogWarning` (framework). Warnings
  were displayed on-screen but not written to log files. The extracted `Write-VerifySummary`
  helper always uses `Write-LogWarning`, fixing the bug for all modes.


### 2.0.0 — 2025-11-16

#### Changed

- Refactored to use `PowerShellLoggingFramework.psm1` for standardized logging.
- Replaced `Write-Host` with `Write-LogInfo` for informational messages.
- Replaced `Write-Warning` with `Write-LogWarning` for warnings.
- Replaced `Write-Verbose` with `Write-LogDebug` for debug messages.
- Retained ADB-specific `DebugMode` for low-level adb diagnostics.
- All log messages are now written to standardized log files.


### 1.3.9 — 2025-08-27

#### Changed

- Verify summary shows Local before → after (+Δ) for both file count and size (MB).
- Baseline adapts to mode:
  - pull (default): baseline = `$Dest\$leaf` if that subfolder is used by adb; otherwise `$Dest`
  - pull `-Resume`, tar (stream or file): baseline = `$Dest`
- Remote values remain best-effort counts/sizes; no transfer-logic change.


### 1.3.8 — 2025-08-27

#### Fixed

- Fixed `Start-Process` parameter handling in TAR-to-file and pull modes:
  - Previously, `-RedirectStandardError` / `-RedirectStandardOutput` were passed `$null` when
    `-DebugMode` was disabled, causing validation errors.
  - Now uses conditional splatting so redirection keys are set only when `DebugMode` is on.
- Eliminates `RedirectStandardError` validation errors when running without `DebugMode`.


### 1.3.7 — 2025-08-27

#### Changed

- Hardened `Invoke-AdbSh`:
  - Rewrote multi-line collapsing to avoid extra semicolons.
  - Added deduplication of whitespace-only lines.
  - Standardized left-hand-side `$null` comparisons.
- Improves stability of phone-side script execution on toybox/busybox shells.


### 1.3.6 — 2025-08-27

#### Added

- Added optional `DebugMode` for transfer troubleshooting without TAR stream corruption:
  - Logs the exact single-line shell sent via `Invoke-AdbSh` (with short stdout prefix + length).
  - Captures adb stderr for TAR-to-file and both stdout/stderr for pull mode.
  - Does not enable `ADB_TRACE` by default (minimal, safe, low-noise).

#### Changed

- Updated documentation for `DebugMode` behavior, log location, and sharing caveats.


### 1.3.5 — 2025-08-27

#### Changed

- Improved adb shell delivery in `Invoke-AdbSh`:
  - Normalizes line endings and joins multi-line scripts to avoid toybox/busybox parsing errors
    (for example, `unexpected 'elif'`).
- `Test-PhoneTar` now prefers `command -v tar` with `--help` fallback, while keeping toybox/busybox fallback.
- Hardened parsing of adb outputs to avoid null/empty `Trim()` crashes.


### 1.3.4 — 2025-08-27

#### Fixed

- Corrected phone-side tar detection (`Test-PhoneTar`) to use `command -v tar` and accept
  `tar --help` instead of requiring `tar --version`.
- Maintains fallback to `toybox tar` / `busybox tar`.
- Resolves false negatives introduced in 1.3.3 on devices where `--version` is unsupported.


### 1.3.3 — 2025-08-27

#### Changed

- Reworked adb shell invocations: removed `sh -lc` and `$0` argument trick.
- Inlined remote path via placeholder replacement to avoid quoting issues.
- Restored full comment-based help for all functions.
- Retained awk-free remote size logic (`du`/`stat`/`find` + shell arithmetic).


### 1.3.2 — 2025-08-27

#### Changed

- Removed awk usage from `Get-RemoteSize`; replaced with POSIX shell arithmetic using `du`/`stat`/`find`.
- Hardened adb quoting and timestamped warnings (including `$ts:` parse fix).
- Inlined remote path argument to satisfy analyzers.


### 1.3.1 — 2025-08-27

#### Changed

- Documented TAR mode as non-resumable; recommended pull + `-Resume` for resumable transfers.
- Added timestamped warnings/retries and verify summary table (Local vs Remote counts/sizes).
- Reduced pull progress polling to 5 seconds (configurable).


### 1.3.0 — 2025-08-27

#### Added

- Added `-Verify` and local/remote file-count helpers.
- Logged local/remote summaries after TAR extraction and after pull.


### 1.2.x — 2025-08-27

#### Added

- Added disk-space precheck, resumable pull, TAR retries/cleanup, and `-StreamTar`.


---
## FileDistributor


### 4.8.0 — 2026-04-05

#### Changed

- **Option A — module consolidation.**

- **Eliminated double-loading of private module files.** `FileDistributor.ps1` previously dot-sourced all six `Private/*.ps1` files after importing the module, causing each private function to be defined twice (once in module scope, once in script scope). The script-scope copies shadowed the module-scope copies for script-level callers.
- **Eliminated duplicate `ErrorHandling`/`FileOperations` imports from `FileDistributor.psm1`.** Both Core modules are now imported once, by `FileDistributor.ps1`, before the `FileDistributor.psd1` module is loaded. Removed the redundant `Import-Module` calls from the module loader.
- **Moved orchestration functions to the module as public functions.** The following functions, which previously existed only in `FileDistributor.ps1` and depended on private module helpers, have been promoted to `Public/` files in `FileManagement/FileDistributor` and exported by the module: `Initialize-FileDistributorPaths`, `Invoke-ParameterValidation`, `Invoke-RestoreCheckpoint`, `New-CheckpointPayload`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-PostRunCleanup`, `Invoke-DistributionLockRelease`.
- **Fixed `LogMessage` calls in private module files.** `Private/FileLock.ps1`, `Private/State.ps1`, and `Private/Serialization.ps1` called `LogMessage` (a script-scope function defined only in `FileDistributor.ps1`), causing `CommandNotFoundException` when those private functions were invoked from module scope. All `LogMessage` calls have been replaced with the appropriate `Write-Log*` framework calls (`Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, `Write-LogDebug`).
- **Moved `Test-EndOfScriptCondition` to `Private/OrchestratorHelpers.ps1`** so it is available to the module-scope `Invoke-EndOfScriptDeletion`.
- **Removed dead `Write-DistributionSummary` duplicate** from `FileDistributor.ps1`. The function was never called from the script; the canonical version lives in `Private/Distribution.ps1`.
- Bumped `FileDistributor` module version to `1.2.0`.
- Bumped script version to `4.8.0`.

#### Fixed

- Removed a vestigial `[int]$TotalFiles` parameter from `Invoke-TargetRedistribution` in `src/powershell/modules/FileManagement/FileDistributor/Public/Invoke-TargetRedistribution.ps1`. The parameter was not used anywhere in the function body and had become stale after redistribution progress was refactored to use per-phase totals. Updated the `FileDistributor.ps1` call site in `Invoke-DistributionPhase` to stop passing `-TotalFiles 0`.
- Removed a dead inner null-subfolder guard inside the root-redistribution block of `Invoke-TargetRedistribution` (`if ($normalizedSubfolders.Count -eq 0) { ... }`). This branch was unreachable because the earlier normalization guard already guarantees at least one destination subfolder by creating an emergency subfolder when needed.
- Bumped `FileDistributor` module version to `1.1.13`.

### 4.7.x (rollup) — 2026-04-01 to 2026-04-05

Addresses script-scope coupling issues that surfaced after functions were moved into the `FileDistributor` module in 4.7.0. Module versions advanced from `1.1.0` to `1.1.12`.

#### Changed

- Replaced all `LogMessage` calls (a script-scope helper defined only in `FileDistributor.ps1`) with framework-native `Write-Log*` functions (`Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, `Write-LogDebug`) in `Private/PathHelpers.ps1` (`Resolve-SubfolderPath`), `Private/Distribution.ps1` (`Write-DistributionSummary`), and the post-processing functions `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize`. Removed the stale `Write-Host` completion line from `Invoke-FileDistribution` in favour of `Write-LogInfo`.

#### Changed

- Refactored `Save-DistributionState`, `Restore-DistributionState`, and `Write-JsonAtomically` in `Private/State.ps1` to accept `$StateFilePath`, `$RetryDelay`, `$RetryCount`, and `$MaxBackoff` as explicit parameters instead of reading from outer script scope. Updated checkpoint/restart call sites in `FileDistributor.ps1` accordingly.
 
#### Fixed

- Fixed CP3 `New-CheckpointPayload` call in `Invoke-DistributionPhase` to include `-IncludeSourceFiles` and `-SourceFiles $RunState.sourceFiles`, preventing a restart from CP3 from silently skipping the distribution phase.
- Fixed `Invoke-EndOfScriptDeletion` using unqualified `$Warnings`/`$Errors` instead of `$script:Warnings`/`$script:Errors`, which could silently yield `0` and allow deletion to proceed despite accumulated warnings or errors.

#### Changed

- Restored warning/error accounting for module-scope functions: added optional `[ref]$WarningCount` and `[ref]$ErrorCount` parameters to `Invoke-FileMove`, `Invoke-FileDistribution`, `Invoke-TargetRedistribution`, and `Resolve-SubfolderPath`; all `Write-LogWarning`/`Write-LogError` call sites now increment the provided counter refs. Call sites in `Invoke-DistributionPhase` and post-processing functions pass `([ref]$script:Warnings)` / `([ref]$script:Errors)`, preserving the `EndOfScriptDeletionCondition` gate.
- Propagated `$MaxBackoff` to `Remove-DistributionFile` and to `Invoke-FolderRebalance`, `Invoke-FolderConsolidation`, and `Invoke-DistributionRandomize`, threading it through to every `Invoke-FileMove` and `Invoke-WithRetry` call site so a user-supplied value is no longer silently ignored during post-processing.

#### Changed

- Moved post-processing algorithms `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum` into `FileManagement/FileDistributor/Public` as `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`, and `Invoke-FolderConsolidation`; updated `Invoke-PostProcessingPhase` accordingly.

#### Fixed

- Fixed division-by-zero / flood logging in `Invoke-FolderRebalance` and `Invoke-DistributionRandomize`: replaced inline division expressions in progress-log guards with a pre-computed `$threshold` set to `[int]::MaxValue` when the denominator is 0.
- Fixed a race condition in `Invoke-TargetRedistribution` where `Get-Random -Count $excess` could throw if files were deleted between the cached snapshot and the actual enumeration; excess count is now clamped with `[Math]::Min()`.

#### Fixed

- Fixed `-Files` parameter type in `Invoke-FileDistribution` from `[string[]]` to `[object[]]` so `FileSystemInfo` inputs are not silently coerced to strings at binding time.

#### Added

- Added a unit test asserting `Invoke-FileDistribution` exposes `System.Object[]` for `-Files`.

### 4.7.0 — 2026-04-01

#### Changed

- Moved `DistributeFilesToSubfolders` → `Invoke-FileDistribution` (public) and `RedistributeFilesInTarget` → `Invoke-TargetRedistribution` (public) from `FileDistributor.ps1` into `Public/Invoke-FileDistribution.ps1` and `Public/Invoke-TargetRedistribution.ps1` in the `FileManagement/FileDistributor` module.
- Moved retry I/O helpers (`Invoke-WithRetry`, `Copy-ItemWithRetry`, `Remove-ItemWithRetry`, `Rename-ItemWithRetry`) from `FileDistributor.ps1` into new `Private/RetryOps.ps1` in the module; replaced `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError` and added `$MaxBackoff` parameter to the `*-ItemWithRetry` wrappers.
- Moved `Get-SubfolderFileCounts` from `FileDistributor.ps1` into new `Private/Distribution.ps1` in the module; replaced `LogMessage` calls with framework-native `Write-Log*` calls.
- Updated `Private/FolderOps.ps1`: replaced all `LogMessage` calls with `Write-LogInfo`/`Write-LogWarning`/`Write-LogError`; added explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff` parameters to `Move-ToRecycleBin` and `Remove-DistributionFile`; added `$MaxBackoff` parameter to `Invoke-FileMove` and threaded it through to `Move-ToRecycleBin` and `Copy-ItemWithRetry`.
- Updated `FileDistributor.ps1` to dot-source `Private/RetryOps.ps1` and `Private/Distribution.ps1`; updated `Invoke-DistributionPhase` to call `Invoke-FileDistribution` and `Invoke-TargetRedistribution` with explicit `$RetryDelay`, `$RetryCount`, `$MaxBackoff`; updated `Invoke-EndOfScriptDeletion` to pass retry params to `Remove-DistributionFile`.
- Bumped `FileDistributor` module version to `1.1.0`; updated `FunctionsToExport` in `FileDistributor.psd1` to include `Invoke-FileDistribution` and `Invoke-TargetRedistribution`.
- Script reduces by ~475 lines (2102 → 1627).

### 4.6.x (module-extraction sprint rollup) — 2026-03-26 to 2026-04-01

#### Changed

- Split `FileDistributor.ps1` orchestration into phase functions and extracted shared algorithm helpers (including `Invoke-FileMove`, `Get-SubfolderFileCounts`, and `New-CheckpointPayload`) to remove duplicated copy/move/checkpoint/counting logic across distribution and post-processing flows.
- Introduced the internal `FileManagement/FileDistributor` module scaffold and migrated serialization, path, file/folder operation, and state-adjacent helper functions out of script scope into module private files with approved PowerShell verb naming.
- Consolidated startup log cleanup by delegating inline log-trimming logic to `Core/Logging/PurgeLogs` (`Clear-LogFile`), while preserving retention, timestamp filtering, and truncation behavior.
- Reduced script-scope coupling by threading runtime values explicitly through checkpoint/orchestration paths (`SessionId`, `DeleteMode`, `SourceFolder`, `MaxFilesToCopy`, `FilesPerFolderLimit`) and by standardizing helper contracts around explicit parameters.
- Moved detailed FileDistributor release notes from script `.NOTES` to this standalone changelog and kept script header notes concise with a direct changelog pointer.

#### Fixed

- Restored queue-signal integrity and safety checks during modularization: EndOfScript queue failures are surfaced as warnings, single-item checkpoint payloads are accepted, and subfolder candidate normalization enforces target-root containment with fallback candidate handling on scan failures.
- Restored post-run file-count integrity validation/warnings for both distribution and rebalance-only modes, preserving discrepancy detection that regressed during early 4.6 refactors.

### 4.5.0 — 2026-03-25

#### Added

- **`.mp4` file extension support:** Added `.mp4` to the list of allowed file extensions for distribution.

### 4.4.1 — 2026-01-05

#### Fixed

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

### 4.4.0 — 2026-01-05

#### Added

- **Optional SourceFolder for rebalance-only mode:** SourceFolder parameter is now optional. When omitted, the script automatically runs in rebalance-only mode (no files copied from source).
  - **Use case:** Run `-RebalanceToAverage`, `-ConsolidateToMinimum`, or `-RandomizeDistribution` on existing target files without providing a source folder.
  - **Examples:**
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -RebalanceToAverage`
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -ConsolidateToMinimum`
    - `.\FileDistributor.ps1 -TargetFolder "C:\Target" -RandomizeDistribution`
  - **Automatic behavior:** When SourceFolder is not provided, `MaxFilesToCopy` is automatically set to 0 and source enumeration is skipped.

#### Changed

- Parameter validation logic: SourceFolder omission automatically enables rebalance-only mode
- Source file enumeration is completely skipped when running in rebalance-only mode
- State file restoration handles empty SourceFolder gracefully for rebalance-only sessions

#### Notes

- No breaking changes. Existing behavior unchanged when SourceFolder is provided.
- Enhanced UX: Users no longer need to specify `-MaxFilesToCopy 0` for rebalance-only operations.

### 4.3.0 — 2026-01-05

#### Added

- **`-RandomizeDistribution` parameter:** New optional switch to perform full randomized redistribution of ALL files across ALL existing subfolders. Completely ignores current distribution and redistributes from scratch.
  - **Behavior:** Enumerates all files in all subfolders, shuffles them randomly, then redistributes evenly using round-robin assignment through the shuffled list.
  - **Use case:** When you want to completely reset the distribution and achieve perfect randomization and balance. Particularly useful after multiple batches have created uneven distribution.
  - **Performance:** Moves many files (all files not already in their assigned destination). Use with caution on large datasets.
  - **Safety:** Respects `FilesPerFolderLimit`, uses existing `DeleteMode` for handling originals, supports progress tracking and retries.
  - **Mutual exclusivity:** Cannot be used with `-ConsolidateToMinimum` or `-RebalanceToAverage` (script will error).

#### Notes

- **Restart semantics:** Introduces **Checkpoint 8** recorded after randomization. Randomization runs when `-RandomizeDistribution` is specified and `lastCheckpoint < 8`; otherwise it is skipped.

#### Notes

- No breaking changes. Feature is opt-in and not performed unless `-RandomizeDistribution` is specified.

### 4.2.0 — 2026-01-05

#### Added

- **`-RebalanceTolerance` parameter:** New optional parameter to configure the tolerance percentage for the `-RebalanceToAverage` feature. Defaults to 10, meaning folders are rebalanced to be within ±10% of the average file count.
  - **Usage:** `-RebalanceTolerance 15` will rebalance folders to be within ±15% of average instead of the default ±10%.
  - **Flexibility:** Allows users to control how strictly folders should be balanced. Lower values (e.g., 5) create tighter balance; higher values (e.g., 20) allow more variance.
  - The tolerance is applied to both donor identification (folders above `avg * (1 + tolerance/100)`) and receiver identification (folders below `avg * (1 - tolerance/100)`).

#### Notes

- No breaking changes. Default behavior remains ±10% when `-RebalanceTolerance` is not specified.

### 4.1.0 — 2026-01-05

#### Changed

- **Distribution algorithm:** Switched from "fill emptiest folder first" to **weighted random selection** based on available capacity. Files are now distributed randomly across multiple eligible folders, with probability weighted by each folder's remaining capacity (`FilesPerFolderLimit - currentCount`).
  - **Benefit:** Prevents all files from a batch going to a single newly-created folder. When new folders are created due to existing folders reaching the limit, files are spread across multiple folders rather than sequentially filling one at a time.
  - **Behavior:** Folders with more available capacity have higher probability of receiving files, but all eligible folders can receive files from the same batch, maintaining better distribution randomness.
  - The change applies to both source-to-target distribution and within-target redistribution phases.

#### Notes

- No breaking changes or new parameters. Existing scripts will work unchanged but will see improved file distribution across folders.

### 3.5.0 — 2025-10-02

#### Added

- **`-RebalanceToAverage` (opt-in):** After Source→Target and target-root redistribution, compute the **average files per existing subfolder** and move files so every subfolder is within **±10%** of that average. No subfolders are created or deleted, and `FilesPerFolderLimit` is always respected.
  - Identifies **donor** folders (`count > ceil(avg*1.1)` capped by limit) and **receiver** folders (`count < floor(avg*0.9)`), then transfers randomly selected files to meet deficits without exceeding per-folder limits.
  - Rebalancing uses existing safety semantics (randomized destination names, `DeleteMode`, retries, progress).

#### Notes

- **Incompatibility:** `-RebalanceToAverage` is **mutually exclusive** with `-ConsolidateToMinimum`; specifying both results in an error.

#### Notes

- **Restart semantics:** Introduces **Checkpoint 7** recorded after rebalancing. Rebalancing runs when `-RebalanceToAverage` is specified and `lastCheckpoint < 7`; otherwise it is skipped.

#### Notes

- No breaking changes; feature is _not_ performed unless `-RebalanceToAverage` is passed.

### 3.4.0 — 2025-10-02

#### Added

- **`-ConsolidateToMinimum` (opt-in):** New command-line switch that packs files into the **minimum number of subfolders** while honoring `FilesPerFolderLimit`. Runs **after** Source→Target copy and target-root redistribution **only when specified**.
  - Computes `needed = ceil(total_files / FilesPerFolderLimit)`.
  - Randomly chooses `needed` existing subfolders as keepers; moves files from other subfolders into keepers (never exceeding the limit).
  - Deletes subfolders that become empty after the move.
  - Uses existing safety semantics (randomized destination names, `DeleteMode`, retries, progress).

#### Notes

- **Restart semantics:** Introduces **Checkpoint 6** recorded after consolidation. Consolidation runs when `-ConsolidateToMinimum` is specified and `lastCheckpoint < 6`; otherwise it is skipped.

#### Notes

- No breaking changes. Consolidation is _not_ performed unless `-ConsolidateToMinimum` is passed.

### 3.3.0 — 2025-10-02

#### Added

- **Checkpoint 4 + Source → Target distribution phase:** Selected source files (subject to `-MaxFilesToCopy`) are now copied into eligible target subfolders **before** any within-target redistribution (root or overloaded folders). This phase respects `-FilesPerFolderLimit` and your `-DeleteMode` (including `EndOfScript`, which queues originals for final cleanup).

#### Changed

- The earlier “within-target redistribution completed” checkpoint has been **renumbered from CP4 to CP5**.

#### Notes

- **Restart semantics:** Resume at **CP3** → runs the new Source→Target copy and saves **CP4**.
- Resume at **CP4** → skips Source→Target copy and runs within-target redistribution, then saves **CP5**.
- Resume at **CP5** → skips redistribution and proceeds to end-of-script actions (e.g., deletions).

#### Notes

- No breaking parameter changes. Logging now includes a banner: _“Distributing N source file(s) to subfolders…”_ for the new phase.

### 3.2.0 — 2025-09-30

#### Added

- **Conditional debug logging:** Debug messages ("DEBUG:") are now only written to the log file and console (via Write-Debug) when the script is run with the built-in -Debug switch. Added [CmdletBinding()] to enable common parameters, $script:DebugMode to detect mode, [switch]$IsDebug to LogMessage, and conditioned logging/output accordingly. This reduces log clutter in normal runs.

### 3.1.0–3.1.26 (rollup) — 2025-09-28 → 2025-09-30

#### Added

- **`-MaxFilesToCopy`:** Cap per-run copies (`-1` all, `0` none, `N` first N); persisted and restart-aware.
- **Deeper diagnostics:** DEBUG tracing across enumeration, conversions, state I/O, candidate counts (eligible/min/candidates), and pre-normalization destination selection. `Resolve-SubfolderPath` logs `GetFullPath` attempts/exceptions.
- **Defensive last-mile checks:** Re-validate final destination; if invalid or the target root, auto-select a safe validated subfolder (create an emergency one if needed).

#### Changed

- **Chooser hardening:** `DistributeFilesToSubfolders` builds candidates from a fresh enumeration of the target root plus caller input; canonicalizes with `GetFullPath`, enforces “under target root & not the root,” and dedupes. Wildcard tests removed.
- **State & restarts:** Persist enumeration totals and deterministic _selected_ files; restarts must match.
- **Enumeration:** Prefer `Get-ChildItem -LiteralPath -Force` with `.PSIsContainer`.
- **Progress/noise:** Separate **enumerated** vs **selected**; keep one consolidated DEBUG line per decision; drop verbose/duplicate logs.
- **Locking/backoff:** State-file locking now uses capped exponential backoff + small jitter and logs the last exception on failure; sidecar contention wait reduced 10s → 1s (still honors max-attempt backoff).
- **Typo fix:** Log label now prints `FilesPerFolderLimit`.

#### Fixed

- **Root safety:** Block writes to the target **root** even if “under target”; reroute to a validated subfolder.
- **Normalization & escapes:** Replace wildcard checks with `[IO.Path]::GetFullPath(...)` + case-insensitive `StartsWith(...)` against a normalized target root; prevent root escapes, mixed-case false positives, and accidental root placement.
- **False “escaped target root ('')” warnings:** Recompute `targetRootNormalized` at function entry (or pass explicitly). Guard triggers only when `startsWithTarget` is false, destination equals root, or normalization fails.
- **Null-safe debug logging:** Recompute `$destNormalized` after fallback/emergency creation; warnings print `<null>` when unknown; all `StartsWith`/`IsPathRooted` calls are null-safe.
- **Candidate selection (scalar pipeline):** Wrap `$candidates` in `@()` to force array semantics; prevents string indexing that yielded drive letter `D` for single-item sets and eliminated “Destination escaped target root ('<null>')” during single-min-count redistribution.
- **Input/path hygiene:** Early-reject `C`, `C:`, `C:foo` forms; anchor relatives under `TargetRoot`; preserve special chars `()!@$~`.
- **Stability:** `ReleaseFileLock` is null-safe; enumeration filter no longer zeroes valid directories; sidecar writes (`FileDistributor-State.json.sha256`) are retried with clearer errors.

#### Notes

- Eliminates spurious warnings like “Sanitizing non-rooted destination folder ''” and “using subfolder 'D'.”
- No breaking parameter/state changes beyond persisting `MaxFilesToCopy`; behavior is stricter and diagnostics clearer.

### 3.0.0–3.0.9 (rollup) — 2025-09-18 → 2025-09-25

#### Changed

- **⚠️ Breaking.**

- **Random name provider is module-only.** Removed legacy `randomname.ps1` and `-RandomNameScriptPath`. Import order: `-RandomNameModulePath` → script-root `powershell\module\RandomName\RandomName.psd1/.psm1` → `Import-Module RandomName` from `$env:PSModulePath`.

#### Added

- **`-RandomNameModulePath`** to explicitly point to the RandomName module.

#### Fixed

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

#### Notes

- If you previously ran with `-Restart`, delete stale state files (and `.bak`/`.sha256`) before rerunning to avoid inheriting malformed subfolder lists.

### 2.0.0 — 2025-09-14

#### Changed

- **⚠️ Breaking.**

- **Source enumeration is now recursive by default (and only behavior):** All files under `-SourceFolder` (including nested subdirectories) are processed. Previously only top-level files were handled.
- Help/description updated to reflect recursion.
- Limitations updated (top-level only note removed).

### 1.0.0–1.7.0 (rollup) — 2025-09-14

#### Added

- Exponential I/O retry wrappers (copy/delete/Recycle Bin moves) with `-ErrorAction Stop` and backoff.
- `-MaxBackoff` parameter to cap exponential backoff (default 60s).
- Windows-only dynamic path resolution for logs/state: user-provided → script-root → `%LOCALAPPDATA%` → `%TEMP%`.
- `-RandomNameScriptPath` parameter; resolves `randomname.ps1` via parameter → script root → `%PATH%` (errors if not found).
- Robust state-file handling: atomic write via same-directory `*.tmp` then replace, persistent `.bak`, `.sha256` integrity sidecar, auto-recovery from `.bak`, quarantine of corrupt primaries.
- Script header `.VERSION` and `CHANGELOG` sections.

#### Changed

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

#### Notes

- State saves now include `WarningsSoFar`, `ErrorsSoFar`, and `SessionId` to enable safe resumptions.
- No functional changes in the 1.0.x patch rollup; behavior remained identical to 1.0.0 aside from documentation and traceability improvements.
