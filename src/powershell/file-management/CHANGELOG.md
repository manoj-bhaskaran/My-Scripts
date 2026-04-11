# CHANGELOG

## Table of Contents

- [Copy-AndroidFiles](#copy-androidfiles)
- [FileDistributor](#filedistributor)

## Copy-AndroidFiles

### 2.3.2 — 2026-04-11

#### Changed

- **Extracted reusable ADB helpers into a new `Android/AdbHelpers` PowerShell module.**
  `Copy-AndroidFiles.ps1` now imports `src/powershell/modules/Android/AdbHelpers/AdbHelpers.psd1`
  and consumes the shared `Test-Adb`, `Confirm-Device`, `Test-HostTar`, `Test-PhoneTar`,
  `Invoke-AdbSh`, `Get-RemoteSize`, and `Get-RemoteFileCount` functions instead of defining them
  inline.
- **Made ADB helper state explicit at call sites.** `Invoke-AdbSh`, `Test-PhoneTar`,
  `Get-RemoteSize`, and `Get-RemoteFileCount` now accept debug log inputs as parameters, and tar
  prechecks accept the active transfer mode explicitly instead of relying on script scope.

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

### 4.8.2 — 2026-04-11

#### Changed

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

### 4.8.1 — 2026-04-11

#### Changed

- Moved `Get-BestReceiver` helper out of the nested function definition inside `Invoke-FolderRebalance`
  and into module-private scope (`Private/Distribution.ps1`), alongside the other distribution
  helpers. The function is no longer re-defined on every call to `Invoke-FolderRebalance` and can
  now be unit-tested in isolation.
- Changed `Remove-Item -Path $StateFilePath -Force` in `Invoke-PostRunCleanup` to use
  `-LiteralPath` and `-ErrorAction SilentlyContinue` so a missing or already-removed state file
  no longer emits a spurious non-terminating error on clean first runs.
- Bumped `FileDistributor` module version to `1.2.1`.

### 4.8.0 — 2026-04-05

#### Changed

- Consolidated `FileDistributor` module loading so private helpers are loaded once in module scope instead of being re-dot-sourced in `FileDistributor.ps1`.
- Removed redundant `ErrorHandling` and `FileOperations` imports from `FileDistributor.psm1`; these Core modules are now imported once in `FileDistributor.ps1` before loading `FileDistributor.psd1`.
- Promoted orchestration functions to module `Public/` exports: `Initialize-FileDistributorPaths`, `Invoke-ParameterValidation`, `Invoke-RestoreCheckpoint`, `New-CheckpointPayload`, `Invoke-DistributionPhase`, `Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-PostRunCleanup`, and `Invoke-DistributionLockRelease`.
- Replaced remaining private-module `LogMessage` calls with framework-native `Write-Log*` functions in `Private/FileLock.ps1`, `Private/State.ps1`, and `Private/Serialization.ps1`.
- Moved `Test-EndOfScriptCondition` to `Private/OrchestratorHelpers.ps1` to support module-scope `Invoke-EndOfScriptDeletion`.
- Removed the dead `Write-DistributionSummary` duplicate from `FileDistributor.ps1`; the canonical implementation remains in `Private/Distribution.ps1`.
- Bumped `FileDistributor` module version to `1.2.0`.
- Bumped script version to `4.8.0`.

### 4.7.2 — 2026-04-02

#### Fixed

- Updated `Invoke-FileMove` race handling so source files that disappear between discovery and copy are logged as warnings and skipped instead of aborting distribution.
- Bumped `FileDistributor` module version to `1.1.2`.

### 4.7.1 — 2026-04-02

#### Changed

- Replaced script-local retry/file-operation helpers with shared Core modules (`Core/ErrorHandling` + `Core/FileOperations`) and removed direct `Private/RetryOps.ps1` loading from script orchestration.
- Updated orchestration call paths to use `Copy-FileWithRetry`, `Remove-FileWithRetry`, and `Invoke-WithRetry -IgnoreFileNotFound`.
- Bumped `FileDistributor` module version to `1.1.1`.

### 4.7.x (rollup) — 2026-04-01 to 2026-04-05

Addresses script-scope coupling issues that surfaced after functions were moved into the `FileDistributor` module in 4.7.0. Module versions advanced from `1.1.0` to `1.1.13`.

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
- Removed vestigial `[int]$TotalFiles` from `Invoke-TargetRedistribution` and updated `Invoke-DistributionPhase` call sites to stop passing `-TotalFiles 0`.
- Removed an unreachable inner `if ($normalizedSubfolders.Count -eq 0)` guard in `Invoke-TargetRedistribution`; the earlier normalization guard already ensures at least one valid destination subfolder.

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

### 4.1.0–4.5.0 (feature/checkpoint rollup) — 2026-01-05 to 2026-03-25

#### Added

- Added optional post-processing modes for target-only balancing:
  - `-RandomizeDistribution` (full randomized redistribution; **Checkpoint 8**)
  - `-RebalanceTolerance` (custom tolerance for `-RebalanceToAverage`)
  - Rebalance-only execution by omitting `-SourceFolder` (auto `MaxFilesToCopy=0`)
- Added `.mp4` support to the distributed extension set in v4.5.0.

#### Changed

- Switched placement from "fill emptiest first" to weighted-random assignment based on remaining per-folder capacity to improve spread across eligible subfolders.
- Rebalance-only flows now suppress source-copy messaging and show target-only summaries.

#### Fixed

- Improved operator feedback for no-op/early-exit rebalance/consolidation/randomization paths (for example: already balanced, insufficient folders, no feasible moves, no files).

#### Notes

- All features in this range are opt-in and non-breaking.
- Checkpoint map in this range: **CP8** = randomization complete.

### 3.3.0–3.5.0 (feature/checkpoint rollup) — 2025-10-02

#### Added

- Added staged post-copy workflows:
  - Source→target distribution phase inserted before within-target redistribution (**Checkpoint 4**)
  - `-ConsolidateToMinimum` for packing into the minimum number of folders (**Checkpoint 6**)
  - `-RebalanceToAverage` for ±10% average balancing (**Checkpoint 7**)

#### Changed

- Renumbered "within-target redistribution completed" from **CP4** to **CP5** after introducing the new source→target stage.
- Preserved restart-aware gating so each optional phase runs only when requested and only when its checkpoint has not yet been recorded.

#### Notes

- `-RebalanceToAverage` and `-ConsolidateToMinimum` are mutually exclusive.
- No breaking parameter changes in this range.

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
