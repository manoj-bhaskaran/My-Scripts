<#
.SYNOPSIS
The script recursively enumerates files from the source directory and ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

 .VERSION
 4.4.0

 CHANGELOG:
   4.4.0 - Made SourceFolder optional; omitting it enables rebalance-only mode (no -MaxFilesToCopy 0 needed)
   4.3.0 - Added -RandomizeDistribution to completely redistribute all files randomly across folders
   4.2.0 - Added -RebalanceTolerance parameter to make rebalance tolerance configurable (default: 10%)
   4.1.0 - Distribution algorithm: weighted random selection based on available capacity
   4.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
   3.5.0 - Distribution update: random-balanced placement; EndOfScript deletions hardened; state-file corruption handling

File name conflicts are resolved using the **RandomName** module’s `Get-RandomFileName`. After ensuring successful copying, the script handles the original files based on the specified `DeleteMode`:

- `RecycleBin`: Moves the files to the Recycle Bin.
- `Immediate`: Deletes the files immediately after successful copying.
- `EndOfScript`: Deletes the files at the end of the script if no critical errors or warnings (as configured) are encountered.

All actions are logged to a specified log file. Progress updates are displayed during processing if enabled, configurable by file count.

.PARAMETER SourceFolder
Optional. Specifies the path to the source folder containing the files to be copied.
If not specified, the script runs in rebalance-only mode (no files are copied from source).
Use rebalance-only mode with `-RebalanceToAverage`, `-ConsolidateToMinimum`, or `-RandomizeDistribution`.

.PARAMETER TargetFolder
Mandatory. Specifies the path to the target folder where the files will be distributed.

.PARAMETER FilesPerFolderLimit
Optional. Specifies the maximum number of files allowed in each subfolder of the target folder. Defaults to 20,000.

.PARAMETER LogFilePath
Optional. Specifies the path to the log file for recording script activities.
Resolution order (Windows): (1) user-provided, (2) script-root relative `.\logs\FileDistributor-log.txt`,
(3) `%LOCALAPPDATA%\FileDistributor\logs\FileDistributor-log.txt`, (4) `%TEMP%\FileDistributor\logs\FileDistributor-log.txt`.
If you pass a **directory** path (e.g. `C:\Logs`), the script will create/use
`FileDistributor-log.txt` inside that directory automatically.

.PARAMETER StateFilePath
Optional. Specifies the path to the state file used for checkpoint/restart.
Resolution order (Windows): (1) user-provided, (2) script-root relative `.\state\FileDistributor-State.json`,
(3) `%LOCALAPPDATA%\FileDistributor\state\FileDistributor-State.json`, (4) `%TEMP%\FileDistributor\state\FileDistributor-State.json`.
If you pass a **directory** path (e.g. `C:\State`), the script will create/use
`FileDistributor-State.json` inside that directory automatically.

.PARAMETER Restart
Optional. If specified, the script will restart from the last checkpoint, resuming its previous state.

.PARAMETER MaxBackoff
Optional. Maximum backoff (in seconds) used by the exponential retry helper when `-RetryCount` is non-zero.
Defaults to 60 seconds. Applies to state-file locking and all file operations that use the retry helper
(`Copy-ItemWithRetry`, `Remove-ItemWithRetry`, `Rename-ItemWithRetry`, Recycle Bin moves).

.PARAMETER ShowProgress
Optional. Displays progress updates during the script's execution. Use this parameter to enable progress reporting.

.PARAMETER UpdateFrequency
Optional. Specifies how often progress updates are displayed. Can be set to a specific file count (e.g., every 100 files). Defaults to 100.

.PARAMETER DeleteMode
Optional. Specifies how the original files should be handled after successful copying. Options are:
- `RecycleBin`: Moves the files to the Recycle Bin (default).
- `Immediate`: Deletes the files immediately after copying.
- `EndOfScript`: Deletes the files at the end of the script if conditions are met.

.PARAMETER MaxFilesToCopy
Optional. Limits how many files (from the recursive source enumeration) will be copied this run.
`-1` (default) means **all** files. `0` means **none** will be copied. Post-processing steps
(target redistribution, duplicate cleanup, empty-folder cleanup) still run. Only files actually
copied in this session are eligible for deletion per `-DeleteMode`.

.PARAMETER EndOfScriptDeletionCondition
Optional. Specifies the conditions under which files are deleted in `EndOfScript` mode. Options are:
- `NoWarnings`: Deletes files only if there are no warnings or errors (default).
- `WarningsOnly`: Deletes files if there are no errors, even if warnings exist.

.PARAMETER RetryDelay
Optional. Base delay in seconds before retrying I/O on failure/lock. Exponential backoff is applied. Defaults to 10 seconds. Applies to state-file locking and all file operations.

.PARAMETER RetryCount
Optional. Number of times to retry I/O on failure. Defaults to 3. A value of 0 means unlimited retries (with backoff cap). Applies to state-file locking and all file operations.

.PARAMETER CleanupDuplicates
Optional. If specified, invokes the duplicate file removal script after distribution.

.PARAMETER CleanupEmptyFolders
Optional. If specified, invokes the empty folder cleanup script after distribution.

.PARAMETER TruncateLog
Optional. If specified, the log file will be truncated (cleared) at the start of the script. This option is ignored during a restart.

.PARAMETER TruncateIfLarger
Optional. Specifies a size threshold for truncating the log file at the start of the script. The size can be specified in formats like 1K (kilobytes), 2M (megabytes), or 3G (gigabytes). This option is ignored during a restart.

.PARAMETER RemoveEntriesBefore
Optional. Specifies a timestamp in the format "YYYY-MM-DD HH:MM:SS" or ISO 8601. All log entries before this timestamp will be removed.

.PARAMETER RemoveEntriesOlderThan
Optional. Specifies an age in days. All log entries older than the specified number of days will be removed.

.PARAMETER Help
Optional. Displays the script's synopsis/help text and exits without performing any operations.

.PARAMETER RandomNameModulePath
Optional. Path to the **RandomName** module (either a `.psd1`/`.psm1` file or the module directory). Resolution order:
1) `-RandomNameModulePath` (if provided),
2) script-root `.\powershell\module\RandomName\RandomName.psd1` (or `.psm1`),
3) `Import-Module RandomName` via `$env:PSModulePath`.
The script errors out if the module cannot be located.

.PARAMETER ConsolidateToMinimum
Optional. **Opt-in** consolidation phase. When specified, after Source→Target distribution and target-root redistribution, pack all files into the **minimum number of subfolders** allowed by `FilesPerFolderLimit`. Randomly selects the required number of *keeper* subfolders, moves files from the others, and deletes any subfolders that become empty.

.PARAMETER RebalanceToAverage
Optional. **Opt-in** *rebalancing* phase. When specified, after Source→Target distribution and target-root redistribution, compute the **average files per existing subfolder** and move files **among existing subfolders only** so that no subfolder deviates by more than the specified tolerance from that average.
- Does **not** create or delete subfolders.
- Always honors `FilesPerFolderLimit`.
- Incompatible with `-ConsolidateToMinimum`; both switches **cannot** be used together (the script will error).

.PARAMETER RebalanceTolerance
Optional. Specifies the tolerance percentage for rebalancing when using `-RebalanceToAverage`. Defaults to 10, meaning folders are rebalanced to be within ±10% of the average. For example, if the tolerance is 15, folders will be rebalanced to be within ±15% of the average file count.

.PARAMETER RandomizeDistribution
Optional. **Opt-in** *full randomization* phase. When specified, after Source→Target distribution and target-root redistribution, redistributes **ALL files** across **ALL existing subfolders** from scratch, ignoring current distribution. Files are randomly shuffled and evenly redistributed to achieve balanced distribution.
- Does **not** create or delete subfolders.
- Always honors `FilesPerFolderLimit`.
- Incompatible with `-ConsolidateToMinimum` and `-RebalanceToAverage`; cannot be used together with either (the script will error).
- **Warning**: This will move many files. Use when you want to completely randomize the distribution.

.EXAMPLE
Tune retries (unlimited attempts, capped backoff 5 minutes) while copying:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "D:\Target" -RetryDelay 5 -RetryCount 0 -MaxBackoff 300

.EXAMPLE
Use end-of-script deletion gated on no *errors* (warnings allowed), and resume safely:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "D:\Target" -DeleteMode EndOfScript -EndOfScriptDeletionCondition WarningsOnly
# ...if interrupted, restart with:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "D:\Target" -Restart

.EXAMPLE
Write logs to a script-root relative file (auto-created), show progress every 250 files:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "D:\Target" -ShowProgress -UpdateFrequency 250 -LogFilePath ".\logs\FileDistributor-log.txt"

.EXAMPLE
Use Windows default locations for state/logs (no need to pass paths) and prune logs older than 14 days:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "D:\Target" -RemoveEntriesOlderThan 14

.EXAMPLE
To copy files from "C:\Source" to "C:\Target" with a default file limit:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target"

.EXAMPLE
# Pass a directory for -LogFilePath and -StateFilePath; default filenames are created inside
.\FileDistributor.ps1 `
  -SourceFolder "C:\Source" -TargetFolder "C:\Target" `
  -LogFilePath "C:\Users\manoj\Documents\Scripts\logs" `
  -StateFilePath "C:\Users\manoj\Documents\Scripts\logs"

.EXAMPLE
To copy files with progress updates every 50 files:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -ShowProgress -UpdateFrequency 50

.EXAMPLE
To restart the script from the last checkpoint:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Restart

.EXAMPLE
To delete files immediately after copying:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -DeleteMode Immediate

.EXAMPLE
To delete files at the end of the script only if no warnings occur:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -DeleteMode EndOfScript -EndOfScriptDeletionCondition NoWarnings

.EXAMPLE
To enable verbose logging using PowerShell's built-in `-Verbose` switch:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -Verbose

.EXAMPLE
To invoke cleanup scripts for duplicates and empty folders:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -CleanupDuplicates -CleanupEmptyFolders

.EXAMPLE
To truncate the log file and start afresh:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -TruncateLog

.EXAMPLE
Pack existing files into the minimum required subfolders (e.g., 168,869 files at limit 20,000 → 9 keepers):
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -ConsolidateToMinimum

.EXAMPLE
Rebalance existing subfolders to within ±10% of the current average (no new folders, no deletions):
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -RebalanceToAverage

.EXAMPLE
Rebalance-only mode: rebalance existing files without copying any new files (no SourceFolder required):
.\FileDistributor.ps1 -TargetFolder "C:\Target" -RebalanceToAverage

.EXAMPLE
Rebalance-only mode with custom tolerance: rebalance to within ±15% without copying:
.\FileDistributor.ps1 -TargetFolder "C:\Target" -RebalanceToAverage -RebalanceTolerance 15

.EXAMPLE
Consolidate-only mode: pack existing files into minimum folders without copying new files:
.\FileDistributor.ps1 -TargetFolder "C:\Target" -ConsolidateToMinimum

.EXAMPLE
Randomize-only mode: completely redistribute all existing files randomly:
.\FileDistributor.ps1 -TargetFolder "C:\Target" -RandomizeDistribution

.EXAMPLE
To truncate the log file if it exceeds 10 megabytes:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -TruncateIfLarger 10M

.EXAMPLE
To remove log entries before a specific timestamp:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -RemoveEntriesBefore "2023-01-01 00:00:00"

.EXAMPLE
To remove log entries older than 30 days:
.\FileDistributor.ps1 -SourceFolder "C:\Source" -TargetFolder "C:\Target" -RemoveEntriesOlderThan 30

.EXAMPLE
To display the script's help text:
.\FileDistributor.ps1 -Help

.NOTES
# CHANGELOG
## 4.4.1 — 2026-01-05
### Fixed
- **Console feedback for rebalancing operations:** Added console output for early exit conditions in `-RebalanceToAverage`, `-ConsolidateToMinimum`, and `-RandomizeDistribution` modes. Users now see clear messages when operations are skipped due to:
  - All subfolders already balanced within tolerance
  - Insufficient subfolders for rebalancing
  - No files to process
  - Already at or below minimal subfolder count
  - No feasible moves or capacity issues
- Previously these conditions were only logged to file, making it unclear why operations completed without action.

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
- No breaking changes; feature is *not* performed unless `-RebalanceToAverage` is passed.

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
- No breaking changes. Consolidation is *not* performed unless `-ConsolidateToMinimum` is passed.

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
- No breaking parameter changes. Logging now includes a banner: *“Distributing N source file(s) to subfolders…”* for the new phase.

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
- **State & restarts:** Persist enumeration totals and deterministic *selected* files; restarts must match.
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

Script Workflow:

Initialization:
- Validates input parameters and checks if the source and target folders exist.
- Initializes logging and ensures the random name generator script is available.

Subfolder Management:
- Counts existing subfolders in the target folder.
- Creates new subfolders as needed while providing progress updates if enabled.

File Processing:
- Files are copied from the source folder to subfolders.
- Files in the target folder (not in subfolders) are redistributed to adhere to folder limits.
- File name conflicts are resolved using the random name generator.
- Successful copying is verified before handling the original files based on the `DeleteMode`.
- Progress updates are displayed based on the specified `UpdateFrequency`.

Deletion Modes:
- Handles files according to the `DeleteMode`:
  - `RecycleBin`: Moves files to the Recycle Bin.
  - `Immediate`: Deletes files immediately.
  - `EndOfScript`: Deletes files conditionally at the end of the script.

Error Handling:
- Logs errors and warnings with detailed messages during file operations.
- Skips problematic files without stopping the script.

Completion:
- Logs the completion of the operation and reports any unprocessed files.
- Provides a final summary message, including the original number of files in the source folder, the original number of files in the target folder hierarchy, and the final number of files in the target folder hierarchy.
- Throws a warning if the sum of the original counts is not equal to the final count in the target.

Post-Processing:
- Optionally invokes cleanup scripts for duplicate files and empty folders based on parameters.

Prerequisites:
- Ensure permissions for reading and writing in both source and target directories.
- **RandomName module** must be available via `-RandomNameModulePath`, script-root `powershell\module\RandomName`, or in `$env:PSModulePath`.

Limitations:
 - The script processes files only (directories are ignored) and will recurse all nested folders under the specified source.
#>

[CmdletBinding()]
param(
    [string]$SourceFolder = $null,
    [string]$TargetFolder = $null,
    [int]$FilesPerFolderLimit = 20000,
    [int]$MaxFilesToCopy = -1, # -1 = all, 0 = none, N = first N files from enumeration
    [string]$LogFilePath = $null,
    [string]$StateFilePath = $null,
    [string]$RandomNameModulePath = $null,
    [switch]$Restart,
    [switch]$ShowProgress = $false,
    [int]$MaxBackoff = 60, # Cap for exponential backoff used by retry helper
    [int]$UpdateFrequency = 100, # Default: 100 files
    [string]$DeleteMode = "RecycleBin", # Options: "RecycleBin", "Immediate", "EndOfScript"
    [string]$EndOfScriptDeletionCondition = "NoWarnings", # Options: "NoWarnings", "WarningsOnly"
    [int]$RetryDelay = 10, # Time to wait before retrying file access (seconds)
    [int]$RetryCount = 3, # Number of times to retry file access (0 for unlimited retries)
    [switch]$CleanupDuplicates,
    [switch]$CleanupEmptyFolders,
    [switch]$TruncateLog,
    [string]$TruncateIfLarger,
    [string]$RemoveEntriesBefore,
    [int]$RemoveEntriesOlderThan,
    [switch]$Help,
    [switch]$ConsolidateToMinimum,
    [switch]$RebalanceToAverage,
    [int]$RebalanceTolerance = 10,
    [switch]$RandomizeDistribution
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Import FileQueue module for queue management
Import-Module "$PSScriptRoot\..\modules\FileManagement\FileQueue\FileQueue.psd1" -Force

# Note: Logger initialization moved to after LogFilePath resolution

# Display help and exit if -Help is specified
if ($Help) {
    Write-Host "FileDistributor.ps1 - File Distribution Script" -ForegroundColor Cyan
    Write-Host "`nSYNOPSIS" -ForegroundColor Yellow
    Write-Host "This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It supports configurable deletion modes, progress updates, and automatic conflict resolution for file names." -ForegroundColor White

    Write-Host "`nDESCRIPTION" -ForegroundColor Yellow
    Write-Host "The script recursively enumerates files from the source directory and ensures they are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed." -ForegroundColor White

    Write-Host "`nPARAMETERS" -ForegroundColor Yellow
    Write-Host "- SourceFolder:" -ForegroundColor Green
    Write-Host "  Optional. Specifies the path to the source folder containing the files to be copied." -ForegroundColor White
    Write-Host "  If not specified, runs in rebalance-only mode (no files copied from source)." -ForegroundColor White
    Write-Host "- TargetFolder:" -ForegroundColor Green
    Write-Host "  Mandatory. Specifies the path to the target folder where the files will be distributed." -ForegroundColor White
    Write-Host "- FilesPerFolderLimit:" -ForegroundColor Green
    Write-Host "  Optional. Maximum number of files allowed in each subfolder. Defaults to 20,000." -ForegroundColor White
    Write-Host "- LogFilePath:" -ForegroundColor Green
    Write-Host "  Optional. Path to the log file for recording script activities. Defaults to 'FileDistributor-log.txt'." -ForegroundColor White
    Write-Host "- Restart:" -ForegroundColor Green
    Write-Host "  Optional. Resumes the script from the last checkpoint." -ForegroundColor White
    Write-Host "- ShowProgress:" -ForegroundColor Green
    Write-Host "  Optional. Displays progress updates during execution." -ForegroundColor White
    Write-Host "- UpdateFrequency:" -ForegroundColor Green
    Write-Host "  Optional. Frequency of progress updates. Defaults to 100 files." -ForegroundColor White
    Write-Host "- DeleteMode:" -ForegroundColor Green
    Write-Host "  Optional. Specifies how original files are handled after copying. Options: RecycleBin (default), Immediate, EndOfScript." -ForegroundColor White
    Write-Host "- EndOfScriptDeletionCondition:" -ForegroundColor Green
    Write-Host "  Optional. Conditions for deletion in EndOfScript mode. Options: NoWarnings (default), WarningsOnly." -ForegroundColor White
    Write-Host "- RetryDelay:" -ForegroundColor Green
    Write-Host "  Optional. Delay in seconds before retrying file access. Defaults to 10 seconds." -ForegroundColor White
    Write-Host "- RetryCount:" -ForegroundColor Green
    Write-Host "  Optional. Number of retries for file access. Defaults to 3. A value of 0 means unlimited retries (with backoff cap)." -ForegroundColor White
    Write-Host "- MaxBackoff:" -ForegroundColor Green
    Write-Host "  Optional. Maximum backoff (seconds) for exponential retry. Defaults to 60 seconds." -ForegroundColor White
    Write-Host "- CleanupDuplicates:" -ForegroundColor Green
    Write-Host "  Optional. Invokes duplicate file removal script after distribution." -ForegroundColor White
    Write-Host "- CleanupEmptyFolders:" -ForegroundColor Green
    Write-Host "  Optional. Invokes empty folder cleanup script after distribution." -ForegroundColor White
    Write-Host "- TruncateLog:" -ForegroundColor Green
    Write-Host "  Optional. Clears the log file at the start of the script." -ForegroundColor White
    Write-Host "- TruncateIfLarger:" -ForegroundColor Green
    Write-Host "  Optional. Truncates the log file if it exceeds a specified size." -ForegroundColor White
    Write-Host "- RemoveEntriesBefore:" -ForegroundColor Green
    Write-Host "  Optional. Removes log entries before a specific timestamp." -ForegroundColor White
    Write-Host "- RemoveEntriesOlderThan:" -ForegroundColor Green
    Write-Host "  Optional. Removes log entries older than a specified number of days." -ForegroundColor White
    Write-Host "- Help:" -ForegroundColor Green
    Write-Host "  Displays this help text and exits." -ForegroundColor White

    Write-Host "`nEXAMPLES" -ForegroundColor Yellow
    Write-Host "To copy files from 'C:\Source' to 'C:\Target' with a default file limit:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target'" -ForegroundColor DarkCyan
    Write-Host "`nTo display progress updates every 50 files:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target' -ShowProgress -UpdateFrequency 50" -ForegroundColor DarkCyan
    Write-Host "`nTo restart the script from the last checkpoint:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -SourceFolder 'C:\Source' -TargetFolder 'C:\Target' -Restart" -ForegroundColor DarkCyan
    Write-Host "`nTo display this help text:" -ForegroundColor White
    Write-Host ".\FileDistributor.ps1 -Help" -ForegroundColor DarkCyan

    Write-Host "`nNOTES" -ForegroundColor Yellow
    Write-Host "Ensure permissions for reading and writing in both source and target directories." -ForegroundColor White
    Write-Host "Random name provider (module) resolution order:" -ForegroundColor White
    Write-Host "  1) -RandomNameModulePath (.psd1/.psm1 or module folder)" -ForegroundColor DarkCyan
    Write-Host "  2) Script-root 'powershell\\module\\RandomName\\RandomName.psd1' (or .psm1)" -ForegroundColor DarkCyan
    Write-Host "  3) Import-Module RandomName (from PSModulePath)" -ForegroundColor DarkCyan
    Write-Host "The script errors out if the RandomName module cannot be located." -ForegroundColor White

    exit
}

# Define script-scoped variables for warnings and errors
$script:Version = "4.4.1"
$script:Warnings = 0
$script:Errors = 0
$script:SessionId = $null

# ===== Windows path resolution helpers (executed before any logging) =====
# Determine script root (works in PS 5.1+ when running as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

function New-Ref {
    param($Initial = $null)
    # Create a stable [ref] container and assign its initial value safely
    $r = [ref]$null
    $r.Value = $Initial
    return $r
}

function New-Directory {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null } catch {
            Write-LogDebug "Failed to create directory ${DirectoryPath}: $_"
        }
    }
    return (Test-Path -LiteralPath $DirectoryPath)
}

function Resolve-PathWithFallback {
    param(
        [string]$UserPath,
        [Parameter(Mandatory = $true)][string]$ScriptRelativePath,
        [Parameter(Mandatory = $true)][string]$WindowsDefaultPath,
        [Parameter(Mandatory = $true)][string]$TempFallbackPath
    )
    # 1) User-provided
    if ($UserPath) {
        $parent = Split-Path -Path $UserPath -Parent
        if (New-Directory -DirectoryPath $parent) { return $UserPath }
    }
    # 2) Script-root relative
    $scriptCandidate = Join-Path -Path $script:ScriptRoot -ChildPath $ScriptRelativePath
    $parent = Split-Path -Path $scriptCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $scriptCandidate }
    # 3) Windows default (LOCALAPPDATA)
    $winCandidate = $WindowsDefaultPath
    $parent = Split-Path -Path $winCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $winCandidate }
    # 4) TEMP fallback
    $tempCandidate = $TempFallbackPath
    $parent = Split-Path -Path $tempCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $tempCandidate }
    # If all fail, return TEMP even if directory creation failed (subsequent operations will error & be logged)
    return $TempFallbackPath
}

# Normalize a path that may actually be a directory; if it's a directory (or ends with a slash),
# append the provided default filename. No-op if it's already a file path.
function Resolve-FilePathIfDirectory {
    param(
        [Parameter(Mandatory = $true)][ref]$Path,
        [Parameter(Mandatory = $true)][string]$DefaultFileName
    )
    $p = $Path.Value
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    try {
        if (Test-Path -LiteralPath $p -PathType Container) {
            $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
            return
        }
    }
    catch {
        Write-LogDebug "Failed to test path ${p}: $_"
    }
    # If it doesn't exist but clearly looks like a directory (trailing slash), treat as directory
    if ($p -match '[\\/]\s*$') {
        $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
        return
    }
}

# Ensure the parent directory exists; optionally "touch" the file so that subsequent Add-Content works.
function Initialize-FilePath {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [switch]$CreateFile
    )
    # Use -Path with -Parent to avoid parameter-set ambiguity on older PowerShell versions
    $dir = Split-Path -Path $FilePath -Parent
    if ($dir) { [void][System.IO.Directory]::CreateDirectory($dir) }
    if ($CreateFile -and -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { New-Item -ItemType File -Path $FilePath -Force | Out-Null }
}

# Function to log messages
function LogMessage {
    param (
        [string]$Message,
        [switch]$ConsoleOutput,
        [switch]$IsError,
        [switch]$IsWarning,
        [switch]$IsDebug
    )

    # Map to PowerShellLoggingFramework functions
    if ($IsError) {
        Write-LogError $Message
        $script:Errors++
        if ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
            Write-Host "ERROR: $Message" -ForegroundColor Red
        }
    }
    elseif ($IsWarning) {
        Write-LogWarning $Message
        $script:Warnings++
        if ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
            Write-Host "WARNING: $Message" -ForegroundColor Yellow
        }
    }
    elseif ($IsDebug) {
        if ($script:DebugMode) {
            Write-LogDebug $Message
            if ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
                Write-Host "DEBUG: $Message" -ForegroundColor Cyan
            }
        }
    }
    else {
        Write-LogInfo $Message
        if ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
            Write-Host $Message
        }
    }
}

# General-purpose retry helper with exponential backoff
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][ScriptBlock]$Operation,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )
    $attempt = 0
    while ($true) {
        try {
            & $Operation
            if ($attempt -gt 0) {
                LogMessage -Message "Succeeded after $attempt retry attempt(s): $Description"
            }
            return
        }
        catch {
            $attempt++
            $err = $_.Exception.Message

            # Check if this is a "file not found" error - handle gracefully without crashing
            $isFileNotFound = ($err -match "Cannot find path" -and $err -match "does not exist") -or
                              ($_.Exception -is [System.Management.Automation.ItemNotFoundException])

            if ($isFileNotFound) {
                # File doesn't exist - log as warning and skip this file instead of crashing
                LogMessage -Message "File not found (skipping): $Description. Error: $err" -IsWarning
                return
            }

            if ($RetryCount -ne 0 -and $attempt -ge $RetryCount) {
                LogMessage -Message "Operation failed after $attempt attempt(s): $Description. Error: $err" -IsError
                throw
            }
            $delay = [Math]::Min([int]($RetryDelay * [Math]::Pow(2, $attempt - 1)), $MaxBackoff)
            LogMessage -Message "Attempt $attempt failed for $Description. Error: $err. Retrying in $delay second(s)..." -IsWarning
            Start-Sleep -Seconds $delay
        }
    }
}

# Evaluate EndOfScript deletion condition using aggregated counts
function Test-EndOfScriptCondition {
    param(
        [Parameter(Mandatory = $true)][string]$Condition, # "NoWarnings" | "WarningsOnly"
        [int]$Warnings = 0,
        [int]$Errors = 0
    )
    switch ($Condition) {
        "NoWarnings" { return ($Warnings -eq 0 -and $Errors -eq 0) }
        "WarningsOnly" { return ($Errors -eq 0) }
        default {
            LogMessage -Message "Unknown EndOfScriptDeletionCondition '$Condition'. Failing closed." -IsWarning
            return $false
        }
    }
}

# --- Helpers for robust state-file handling ---
function ConvertTo-Hashtable {
    param([Parameter(Mandatory = $true)]$Object)
    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable]) { return $Object }
    if ($Object -is [System.Collections.IDictionary]) { return @{} + $Object }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        foreach ($p in $Object.PSObject.Properties) {
            $ht[$p.Name] = ConvertTo-Hashtable -Object $p.Value
        }
        return $ht
    }
    if ($Object -is [System.Collections.IEnumerable] -and -not ($Object -is [string])) {
        $list = @()
        foreach ($i in $Object) { $list += , (ConvertTo-Hashtable -Object $i) }
        return $list
    }
    return $Object
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $h = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
        return $h.Hash.ToUpperInvariant()
    }
    catch {
        LogMessage -Message "Failed to compute SHA256 for '$Path': $($_.Exception.Message)" -IsWarning
        return $null
    }
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory = $true)][hashtable]$StateObject,
        [Parameter(Mandatory = $true)][string]$Path
    )
    # Use -Path with -Parent to avoid parameter-set ambiguity on older PowerShell versions
    $dir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = "$Path.tmp"
    $bak = "$Path.bak"
    $sha = "$Path.sha256"

    # Backup existing file once per write (best-effort)
    if (Test-Path -LiteralPath $Path) {
        try { Copy-Item -LiteralPath $Path -Destination $bak -Force -ErrorAction Stop } catch { LogMessage -Message "Failed to update state backup '$bak': $($_.Exception.Message)" -IsWarning }
    }

    # Serialize and write to temp, then atomically move
    $json = $StateObject | ConvertTo-Json -Depth 100
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8

    # Compute hash on the temp bytes and persist sidecar after final move
    $hash = Get-FileSha256Hex -Path $tmp
    try {
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }
    catch {
        LogMessage -Message "Atomic move for state file failed: $($_.Exception.Message)" -IsError
        throw
    }
    if ($hash) {
        try {
            # Use a shorter, lighter retry for the sidecar to avoid long stalls
            $sidecarRetryDelay = 1
            $sidecarMaxBackoff = [Math]::Min(5, $MaxBackoff)
            # Preserve "unlimited" semantics if RetryCount==0; otherwise ensure at least one retry
            $sidecarRetryCount = if ($RetryCount -eq 0) { 0 } else { [Math]::Max(1, $RetryCount) }
            Invoke-WithRetry -Operation {
                Set-Content -LiteralPath $sha -Value $hash -Encoding ASCII -ErrorAction Stop
            } -Description "Write state sidecar '$sha'" `
                -RetryDelay $sidecarRetryDelay `
                -RetryCount $sidecarRetryCount `
                -MaxBackoff $sidecarMaxBackoff
        }
        catch {
            # best-effort: keep as warning
            LogMessage -Message "Failed to write state sidecar '$sha': $($_.Exception.Message)" -IsWarning
        }
    }
}

function Get-StateFromPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $sha = "$Path.sha256"
    # Verify sidecar hash if present
    if (Test-Path -LiteralPath $sha) {
        $expected = (Get-Content -LiteralPath $sha -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        $actual = Get-FileSha256Hex -Path $Path
        if ($expected -and $actual -and ($expected -ne $actual)) {
            LogMessage -Message "Checksum mismatch for '$Path' (expected $expected, got $actual). Treating as corrupt." -IsWarning
            return $null
        }
    }
    # Read and parse JSON safely
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $ht = ConvertTo-Hashtable -Object $obj
        return $ht
    }
    catch {
        LogMessage -Message "Failed to parse state file '$Path': $($_.Exception.Message)" -IsWarning
        return $null
    }
}

# ===== Resolve effective LogFilePath and StateFilePath (before first LogMessage call) =====
# Parameter block (updated below) may set these to $null; compute effective paths now.
# Windows defaults:
$localAppData = $env:LOCALAPPDATA
$tempRoot = $env:TEMP

# Build default targets
$defaultLog_Windows = Join-Path -Path (Join-Path $localAppData 'FileDistributor\logs') -ChildPath 'FileDistributor-log.txt'
$defaultLog_Temp = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\logs') -ChildPath 'FileDistributor-log.txt'
$defaultLog_ScriptRel = 'logs\FileDistributor-log.txt'

$defaultState_Windows = Join-Path -Path (Join-Path $localAppData 'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
$defaultState_Temp = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
$defaultState_ScriptRel = 'state\FileDistributor-State.json'

# If parameters are currently unset, they'll be $null; compute effective values
$script:LogFilePath = Resolve-PathWithFallback -UserPath $LogFilePath `
    -ScriptRelativePath $defaultLog_ScriptRel -WindowsDefaultPath $defaultLog_Windows -TempFallbackPath $defaultLog_Temp
$script:StateFilePath = Resolve-PathWithFallback -UserPath $StateFilePath `
    -ScriptRelativePath $defaultState_ScriptRel -WindowsDefaultPath $defaultState_Windows -TempFallbackPath $defaultState_Temp

# If user passed a directory for either path, coerce to default filename within that directory
Resolve-FilePathIfDirectory -Path ([ref]$script:LogFilePath)   -DefaultFileName 'FileDistributor-log.txt'
Resolve-FilePathIfDirectory -Path ([ref]$script:StateFilePath) -DefaultFileName 'FileDistributor-State.json'

# From here on, use the resolved script-scoped variables
$LogFilePath = $script:LogFilePath
$StateFilePath = $script:StateFilePath

# Ensure log directory exists and create the file so Add-Content always succeeds
Initialize-FilePath -FilePath $LogFilePath -CreateFile
# Ensure state directory exists early (file may be created later by locking/atomic write)
Initialize-FilePath -FilePath $StateFilePath

# Initialize logger with the resolved log directory
$logDirectory = Split-Path -Path $LogFilePath -Parent
Initialize-Logger -resolvedLogDir $logDirectory -ScriptName "FileDistributor" -LogLevel 20
# Override the framework's auto-generated filename to use the user's exact path
$Global:LogConfig.LogFilePath = $LogFilePath

# ===== Random name provider resolution (module-only) =====
function Import-RandomNameProvider {
    param(
        [string]$ModulePath
    )

    # Already available?
    if (Get-Command -Name Get-RandomFileName -ErrorAction SilentlyContinue) {
        LogMessage -Message "RandomName provider already available (Get-RandomFileName found)."
        return
    }

    # 1) Explicit module path (psd1/psm1 or module directory)
    if ($ModulePath) {
        try {
            $resolved = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
            Import-Module -LiteralPath $resolved.Path -Force -ErrorAction Stop
            LogMessage -Message "Imported RandomName module from '$($resolved.Path)'."
            return
        }
        catch {
            LogMessage -Message "Failed to import RandomName module from '$ModulePath': $($_.Exception.Message)" -IsWarning
        }
    }

    # 2) Script-root conventional location
    $scriptRootCandidates = @(
        (Join-Path $script:ScriptRoot 'powershell\module\RandomName\RandomName.psd1'),
        (Join-Path $script:ScriptRoot 'powershell\module\RandomName\RandomName.psm1')
    )
    foreach ($c in $scriptRootCandidates) {
        if (Test-Path -LiteralPath $c) {
            try {
                Import-Module -LiteralPath $c -Force -ErrorAction Stop
                LogMessage -Message "Imported RandomName module from script-root '$c'."
                return
            }
            catch {
                LogMessage -Message "Failed to import RandomName module from '$c': $($_.Exception.Message)" -IsWarning
            }
        }
    }

    # 3) PSModulePath
    try {
        Import-Module -Name RandomName -ErrorAction Stop
        LogMessage -Message "Imported RandomName module from PSModulePath."
        return
    }
    catch {
        LogMessage -Message "Failed to import 'RandomName' from PSModulePath: $($_.Exception.Message)" -IsError
        throw "Random name provider (module) not found."
    }
}

# I/O wrappers
function Copy-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    Invoke-WithRetry -Operation { Copy-Item -Path $Path -Destination $Destination -Force -ErrorAction Stop } `
        -Description "Copy '$Path' -> '$Destination'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Remove-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    Invoke-WithRetry -Operation { Remove-Item -Path $Path -Force -ErrorAction Stop } `
        -Description "Delete '$Path'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Rename-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$NewName,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    Invoke-WithRetry -Operation { Rename-Item -LiteralPath $Path -NewName $NewName -Force -ErrorAction Stop } `
        -Description "Rename '$Path' -> '$NewName'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}

# (randomname.ps1 will be resolved and loaded inside Main via Initialize-RandomNameGenerator)

function ResolveFileNameConflict {
    param (
        [string]$TargetFolder,
        [string]$OriginalFileName
    )

    # Get the extension of the original file
    $extension = [System.IO.Path]::GetExtension($OriginalFileName)

    # Loop to generate a unique file name
    do {
        $newFileName = (Get-RandomFileName) + $extension
        $newFilePath = Join-Path -Path $TargetFolder -ChildPath $newFileName
    } while (Test-Path -Path $newFilePath)

    return $newFileName
}

function Resolve-SubfolderPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    # Reject bare drive and drive-relative forms
    if ($Path -match '^[A-Za-z]$' -or $Path -match '^[A-Za-z]:$' -or $Path -match '^[A-Za-z]:[^\\/].*') { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        try {
            # Add this before GetFullPath:
            LogMessage -Message "DEBUG: Attempting GetFullPath for '$Path'" -IsDebug
            return [IO.Path]::GetFullPath($Path)
        }
        catch {
            # Add this in catch:
            LogMessage -Message "DEBUG: GetFullPath threw for '$Path': $($_.Exception.Message)" -IsWarning
            return $null
        }
    }
    return (Join-Path -Path $TargetRoot -ChildPath $Path)
}

function CreateRandomSubfolders {
    param (
        [string]$TargetPath,
        [int]$NumberOfFolders,
        [switch]$ShowProgress,
        [int]$UpdateFrequency
    )

    # Initialize an array to store created folder paths
    $createdFolders = @()

    for ($i = 1; $i -le $NumberOfFolders; $i++) {
        do {
            # Generate a random folder name
            $randomFolderName = Get-RandomFileName
            $folderPath = Join-Path -Path $TargetPath -ChildPath $randomFolderName
        } while (Test-Path -Path $folderPath)

        # Create the new directory and keep a DirectoryInfo so we retain FullName later
        $dirInfo = New-Item -ItemType Directory -Path $folderPath -Force
        $createdFolders += $dirInfo

        # Log the creation of the folder
        LogMessage -Message "Created folder: $folderPath"

        # Show progress if enabled
        if ($ShowProgress -and ($i % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($i / $NumberOfFolders) * 100)
            Write-Progress -Activity "Creating Subfolders" `
                -Status "Created $i of $NumberOfFolders folders" `
                -PercentComplete $percentComplete
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Creating Subfolders" -Status "Complete" -Completed
    }

    return $createdFolders
}

function Move-ToRecycleBin {
    param (
        [string]$FilePath
    )

    try {
        # Create a new Shell.Application COM object
        $shell = New-Object -ComObject Shell.Application

        # 10 is the folder type for Recycle Bin
        $recycleBin = $shell.NameSpace(10)

        # Get the file to be moved to the Recycle Bin
        $file = Get-Item $FilePath

        # Move the file to the Recycle Bin with retry, suppressing confirmation (0x100)
        Invoke-WithRetry -Operation { $recycleBin.MoveHere($file.FullName, 0x100) } -MaxBackoff $MaxBackoff `
            -Description "Recycle '$($file.FullName)'" `
            -RetryDelay $RetryDelay -RetryCount $RetryCount

        # Log success
        LogMessage -Message "Moved $FilePath to Recycle Bin."
    }
    catch {
        # Log failure
        LogMessage -Message "Failed to move $FilePath to Recycle Bin. Error: $($_.Exception.Message)" -IsWarning
    }
}

# Function to delete files
function Remove-File {
    param (
        [string]$FilePath
    )

    try {
        # Check if the file exists before attempting deletion
        if (Test-Path -Path $FilePath) {
            Remove-ItemWithRetry -Path $FilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
            LogMessage -Message "Deleted file: $FilePath."
        }
        else {
            LogMessage -Message "File $FilePath not found. Skipping deletion." -IsWarning
        }
    }
    catch {
        # Log failure
        LogMessage -Message "Failed to delete file $FilePath. Error: $($_.Exception.Message)" -IsWarning
    }
}

function DistributeFilesToSubfolders {
    param (
        [string[]]$Files,
        [object[]]$Subfolders,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [int]$Limit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency,
        [string]$DeleteMode,
        $FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [ref]$GlobalFileCounter,
        [int]$TotalFiles
    )

    # --- Build canonical candidate set strictly from the target root ---
    $targetNormalized = [IO.Path]::GetFullPath($TargetRoot)

    $subfolderPaths =
    @(
        # 1) Whatever caller passed (normalize or discard)
        $Subfolders | ForEach-Object {
            if ($_ -is [IO.FileSystemInfo]) { $_.FullName } else { [string]$_ }
        }
        # 2) Always include a fresh scan of the actual target root
        (Get-ChildItem -LiteralPath $TargetRoot -Directory -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName })
        ) |
            Where-Object { $_ } |
            ForEach-Object {
                # Drop invalid/drive-relative, then canonicalize
                $p = Resolve-SubfolderPath -Path $_ -TargetRoot $TargetRoot
                if ([string]::IsNullOrWhiteSpace($p)) { return }
                try { [IO.Path]::GetFullPath($p) } catch { return }
            } |
            Where-Object {
                # Under target AND not the root itself
                $_ -ne $TargetRoot -and
                $_.StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path -LiteralPath $_ -PathType Container)
            } |
            Select-Object -Unique

    if (($subfolderPaths | Measure-Object).Count -eq 0) {
        # Create a guaranteed-safe place to land
        $emergency = Join-Path -Path $TargetRoot -ChildPath (Get-RandomFileName)
        New-Item -ItemType Directory -Path $emergency -Force | Out-Null
        $subfolderPaths = @($emergency)
        LogMessage -Message "Created emergency destination subfolder '$emergency' (no valid candidates)." -IsWarning
    }

    $folderCounts = @{}
    foreach ($p in $subfolderPaths) {
        try {
            $folderCounts[$p] = (Get-ChildItem -LiteralPath $p -File -Force | Measure-Object).Count
        }
        catch {
            $folderCounts[$p] = 0
            LogMessage -Message "Failed to count files in subfolder '$p'. Defaulting count to 0. Error: $($_.Exception.Message)" -IsWarning
        }
    }

    LogMessage -Message ("DEBUG: Eligible subfolders ({0}): {1}" -f $subfolderPaths.Count, ($subfolderPaths -join ', ')) -IsDebug

    # --- Randomize processing order of files to reduce bias ---
    $filesToProcess = $Files
    try {
        if ($Files.Count -gt 1) { $filesToProcess = $Files | Get-Random -Count $Files.Count }
    }
    catch {
        $filesToProcess = $Files
        LogMessage -Message "Could not shuffle file list due to: $($_.Exception.Message). Proceeding without shuffle." -IsWarning
    }

    foreach ($file in $filesToProcess) {
        $filePath = if ($file -is [System.IO.FileSystemInfo]) { $file.FullName } else { [string]$file }
        $originalName = if ($file -is [System.IO.FileSystemInfo]) { $file.Name } else { [System.IO.Path]::GetFileName($filePath) }

        # Choose eligible targets (under limit) using weighted random selection
        $eligible = @()
        foreach ($p in $subfolderPaths) {
            if ($folderCounts[$p] -lt $Limit) { $eligible += $p }
        }
        if ($eligible.Count -eq 0) {
            $eligible = $subfolderPaths
            LogMessage -Message "All subfolders appear at/over limit ($Limit). Selecting among all subfolders (best effort)." -IsWarning
        }

        # Weighted random selection based on available capacity
        if ($eligible.Count -eq 1) {
            $destinationFolder = $eligible[0]
        }
        else {
            # Calculate weights based on available capacity (Limit - current count)
            $weights = @{}
            $totalWeight = 0
            foreach ($p in $eligible) {
                $availableCapacity = $Limit - $folderCounts[$p]
                $weight = [Math]::Max(1, $availableCapacity)  # Ensure minimum weight of 1
                $weights[$p] = $weight
                $totalWeight += $weight
            }

            # Select folder using weighted random selection
            $randomValue = Get-Random -Minimum 0 -Maximum $totalWeight
            $cumulativeWeight = 0
            $destinationFolder = $eligible[0]  # fallback
            foreach ($p in $eligible) {
                $cumulativeWeight += $weights[$p]
                if ($randomValue -lt $cumulativeWeight) {
                    $destinationFolder = $p
                    break
                }
            }
        }

        LogMessage -Message "DEBUG: Eligible count: $($eligible.Count), Selected: $destinationFolder (count: $($folderCounts[$destinationFolder]))" -IsDebug
        LogMessage -Message "Selected destination before resolve: '$destinationFolder'"

        # Last-mile guards (never root, always under TargetRoot, must exist)
        $destinationFolder = Resolve-SubfolderPath -Path $destinationFolder -TargetRoot $TargetRoot
        $destNormalized = if ($destinationFolder) { [IO.Path]::GetFullPath($destinationFolder) } else { $null }
        $targetNormalized = [IO.Path]::GetFullPath($TargetRoot)

        $isBad = (
            [string]::IsNullOrWhiteSpace($destNormalized) -or
            $destNormalized -match '^[A-Za-z]$' -or
            $destNormalized -match '^[A-Za-z]:$' -or
            -not [System.IO.Path]::IsPathRooted($destNormalized) -or
            (-not $destNormalized.StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase))
        )

        if ($destNormalized -eq $targetNormalized -or $isBad) {
            $safe = $subfolderPaths | Where-Object {
                $_ -ne $TargetRoot -and (Test-Path -LiteralPath $_ -PathType Container) -and `
                ([IO.Path]::GetFullPath($_)).StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase)
            }
            if ($safe.Count -gt 0) {
                $fallback = $safe | Get-Random
                if ($destNormalized -eq $targetNormalized) {
                    LogMessage -Message "Destination resolved to the target ROOT; selecting a subfolder instead: '$fallback'." -IsWarning
                }
                else {
                    $destDisplay = if ($destNormalized) { $destNormalized } else { '<null>' }
                    LogMessage -Message "Destination escaped target root ('$destDisplay'); forcing subfolder '$fallback'." -IsWarning
                }
                $destinationFolder = $fallback
            }
            else {
                $destinationFolder = Join-Path -Path $TargetRoot -ChildPath (Get-RandomFileName)
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                $folderCounts[$destinationFolder] = 0
                LogMessage -Message "Created emergency destination subfolder '$destinationFolder' to avoid using target root." -IsWarning
            }
        }

        # Recompute normalized destination AFTER any fallback/emergency selection.
        # (Fixes null dereference when logging/inspecting $destNormalized.)
        $destNormalized = if ($destinationFolder) { [IO.Path]::GetFullPath($destinationFolder) } else { $null }

        if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
            try {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                LogMessage -Message "Created missing destination folder: $destinationFolder"
            }
            catch {
                LogMessage -Message "Failed to ensure destination folder '$destinationFolder': $($_.Exception.Message)" -IsError
                continue
            }
        }

        # Single, consistent DEBUG line using normalized paths (null-safe)
        $rooted = if ($destNormalized) { [System.IO.Path]::IsPathRooted($destNormalized) } else { $false }
        $startsWithTarget = if ($destNormalized) { $destNormalized.StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase) } else { $false }
        LogMessage -Message ("DEBUG: destNormalized='{0}' targetRootNormalized='{1}' rooted={2} startsWithTarget={3}" -f $destNormalized, $targetNormalized, $rooted, $startsWithTarget) -IsDebug

        # Randomized destination name (preserve extension)
        $newFileName = ResolveFileNameConflict -TargetFolder $destinationFolder -OriginalFileName $originalName
        $destinationFile = Join-Path -Path $destinationFolder -ChildPath $newFileName
        LogMessage -Message "Assigning randomized destination name for '$filePath' -> '$destinationFile'."

        Copy-ItemWithRetry -Path $filePath -Destination $destinationFile -RetryDelay $RetryDelay -RetryCount $RetryCount

        if (Test-Path -LiteralPath $destinationFile) {
            if ($folderCounts.ContainsKey($destinationFolder)) { $folderCounts[$destinationFolder]++ } else { $folderCounts[$destinationFolder] = 1 }
            try {
                if ($DeleteMode -eq "RecycleBin") {
                    Move-ToRecycleBin -FilePath $filePath
                    LogMessage -Message "Copied from $file to $destinationFile and moved original to Recycle Bin."
                }
                elseif ($DeleteMode -eq "Immediate") {
                    Remove-File -FilePath $filePath
                    LogMessage -Message "Copied from $file to $destinationFile and immediately deleted original."
                }
                elseif ($DeleteMode -eq "EndOfScript") {
                    # Use FileQueue module to add file to deletion queue
                    $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $filePath -ValidateFile $false
                    if ($queueResult) {
                        LogMessage -Message "Copied from $file to $destinationFile. Original pending deletion at end of script."
                    }
                    else {
                        LogMessage -Message "Failed to queue file for deletion: $filePath" -IsWarning
                    }
                }
            }
            catch {
                LogMessage -Message "Failed to process file $file after copying to $destinationFile. Error: $($_.Exception.Message)" -IsWarning
            }
        }
        else {
            LogMessage -Message "Failed to copy $file to $destinationFile. Original file not moved." -IsError
        }

        $GlobalFileCounter.Value++

        if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($GlobalFileCounter.Value / $TotalFiles) * 100)
            Write-Progress -Activity "Distributing Files" -Status "Processed $($GlobalFileCounter.Value) of $TotalFiles files" -PercentComplete $percentComplete
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Distributing Files" -Status "Complete" -Completed }
    LogMessage -Message "File distribution completed: Processed $($GlobalFileCounter.Value) of $TotalFiles files." -ConsoleOutput
}

function RedistributeFilesInTarget {
    param (
        [string]$TargetFolder,
        [object[]]$Subfolders,
        [int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency,
        [string]$DeleteMode,
        $FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [ref]$GlobalFileCounter,
        [int]$TotalFiles
    )

    # Build initial folder file count map from normalized full paths
    $folderFilesMap = @{}
    $normalizedSubfolders = @()

    # FIXED: First, ensure we have actual DirectoryInfo objects
    $validSubfolderObjects = @()
    foreach ($sf in $Subfolders) {
        if ($null -eq $sf) { continue }

        # Convert to DirectoryInfo if it's a string
        if ($sf -is [string]) {
            if ([string]::IsNullOrWhiteSpace($sf)) { continue }
            try {
                $dirInfo = Get-Item -LiteralPath $sf -ErrorAction Stop
                if ($dirInfo -is [System.IO.DirectoryInfo]) {
                    $validSubfolderObjects += $dirInfo
                }
            }
            catch {
                LogMessage -Message "Failed to resolve subfolder path '$sf': $($_.Exception.Message)" -IsWarning
            }
        }
        elseif ($sf -is [System.IO.FileSystemInfo]) {
            $validSubfolderObjects += $sf
        }
    }

    LogMessage -Message "DEBUG: Valid subfolder objects collected: $($validSubfolderObjects.Count)" -IsDebug

    # Now process the validated objects
    foreach ($dirInfo in $validSubfolderObjects) {
        $sfPath = $dirInfo.FullName

        if ([string]::IsNullOrWhiteSpace($sfPath)) { continue }

        # Resolve to absolute path and verify it's under target root (but not the root itself)
        $sfPath = Resolve-SubfolderPath -Path $sfPath -TargetRoot $TargetFolder
        if (-not $sfPath -or $sfPath -eq $TargetFolder) { continue }

        # Verify it still exists
        if (-not (Test-Path -LiteralPath $sfPath -PathType Container)) {
            LogMessage -Message "Subfolder no longer exists: '$sfPath'" -IsWarning
            continue
        }

        # Add to collections
        $normalizedSubfolders += $sfPath

        try {
            $folderFilesMap[$sfPath] = (Get-ChildItem -LiteralPath $sfPath -File -ErrorAction Stop).Count
        }
        catch {
            $folderFilesMap[$sfPath] = 0
            LogMessage -Message "Failed to count files in subfolder '$sfPath'. Defaulting count to 0. Error: $($_.Exception.Message)" -IsWarning
        }
    }

    # Make unique
    $normalizedSubfolders = $normalizedSubfolders | Select-Object -Unique

    LogMessage -Message ("DEBUG: Normalized subfolders for redistribution ({0} items): {1}" -f $normalizedSubfolders.Count, ($normalizedSubfolders -join ', ')) -IsDebug

    if ($normalizedSubfolders.Count -eq 0) {
        LogMessage -Message "No valid subfolders available for redistribution. Creating emergency subfolder." -IsWarning
        $randomName = Get-RandomFileName
        $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
        New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
        $normalizedSubfolders = @($newFolder)
        $folderFilesMap[$newFolder] = 0
    }

    # Step 2: Redistribute files from root of target folder (not subfolders)
    LogMessage -Message "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -LiteralPath $TargetFolder -File -ErrorAction Stop
    $redistributionTotal = 0
    $redistributionProcessed = 0

    if ($rootFiles.Count -gt 0) {
        # Use the already normalized subfolders directly
        if ($normalizedSubfolders.Count -eq 0) {
            # Create a new subfolder if none exist
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            LogMessage -Message "Created new target subfolder: $newFolder for redistribution from root folder."
            $normalizedSubfolders = @($newFolder)
        }

        # Reset phase counter and compute correct denominator
        $GlobalFileCounter.Value = 0
        $redistributionTotal += $rootFiles.Count

        LogMessage -Message ("DEBUG (redistribute-root) candidates={0}" -f ($normalizedSubfolders -join '; ')) -IsDebug

        DistributeFilesToSubfolders -Files $rootFiles `
            -Subfolders $normalizedSubfolders `
            -TargetRoot $TargetFolder `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $rootFiles.Count
        $redistributionProcessed += $GlobalFileCounter.Value
    }

    # Step 3: Identify overloaded folders and select random files for redistribution
    $filesToRedistributeMap = @{}

    foreach ($folder in $folderFilesMap.Keys) {
        $fileCount = $folderFilesMap[$folder]
        if ($fileCount -gt $FilesPerFolderLimit) {
            $excess = $fileCount - $FilesPerFolderLimit
            $overloadedFiles = Get-ChildItem -Path $folder -File | Get-Random -Count $excess
            $filesToRedistributeMap[$folder] = $overloadedFiles
            LogMessage -Message "Folder $folder is overloaded by $excess file(s), queuing for redistribution."
            $redistributionTotal += $overloadedFiles.Count
        }
    }

    # Step 4: Redistribute files from overloaded folders, excluding the source folder from targets
    foreach ($sourceFolder in $filesToRedistributeMap.Keys) {
        $sourceFiles = $filesToRedistributeMap[$sourceFolder]

        $eligibleTargets = $folderFilesMap.GetEnumerator() |
            Where-Object {
                $_.Key -ne $TargetFolder -and $_.Key -ne $sourceFolder -and $_.Value -lt $FilesPerFolderLimit
            } |
            ForEach-Object { $_.Key } |
            Select-Object -Unique

        if ($eligibleTargets.Count -eq 0) {
            # Create a new subfolder using Get-RandomFileName
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            LogMessage -Message "Created new target subfolder: $newFolder for redistribution from overloaded folder $sourceFolder."

            # Update maps
            $eligibleTargets = @($newFolder)
            $Subfolders += (Get-Item -LiteralPath $newFolder)
            $folderFilesMap[$newFolder] = 0
        }

        # Reset phase counter and use per-batch denominator
        LogMessage -Message ("DEBUG (redistribute-overload from '{0}') candidates={1}" -f `
                $sourceFolder, ($eligibleTargets -join '; ')) -IsDebug

        $GlobalFileCounter.Value = 0
        DistributeFilesToSubfolders -Files $sourceFiles `
            -Subfolders $eligibleTargets `
            -TargetRoot $TargetFolder `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $sourceFiles.Count
        $redistributionProcessed += $GlobalFileCounter.Value
    }

    LogMessage -Message "File redistribution completed: Processed $redistributionProcessed of $redistributionTotal files in the target folder."
}

function RebalanceSubfoldersByAverage {
    param (
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][int]$FilesPerFolderLimit,
        [int]$Tolerance = 10,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter
    )

    # Calculate tolerance multipliers
    $toleranceDecimal = [double]$Tolerance / 100.0
    $lowerMultiplier = 1.0 - $toleranceDecimal
    $upperMultiplier = 1.0 + $toleranceDecimal

    LogMessage -Message ("Rebalance: computing average and deviation thresholds (±{0}%)..." -f $Tolerance)

    # Enumerate subfolders and counts
    $subfolders = @()
    try {
        $subfolders = Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction Stop
    }
    catch {
        LogMessage -Message "Rebalance: failed to enumerate subfolders under '$TargetFolder': $($_.Exception.Message)" -IsError
        return
    }
    if (-not $subfolders -or $subfolders.Count -le 1) {
        LogMessage -Message "Rebalance: need at least two subfolders. Nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Rebalance: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)

    $folderCounts = @{}
    $totalFiles = 0
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        $count = 0
        try {
            $count = (Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop | Measure-Object).Count
            LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $count) -IsDebug
        }
        catch {
            LogMessage -Message "Rebalance: failed to count files in '$p': $($_.Exception.Message)" -IsWarning
        }
        $folderCounts[$p] = [int]$count
        $totalFiles += [int]$count
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Rebalance: no files to rebalance." -ConsoleOutput
        return
    }

    $avg = [double]$totalFiles / [double]$subfolders.Count
    $low = [int][math]::Floor($avg * $lowerMultiplier)
    $high = [int][math]::Ceiling($avg * $upperMultiplier)

    LogMessage -Message ("Rebalance: totalFiles={0}, subfolders={1}, avg={2:N2}, lowerBound={3}, upperBound={4} (limit={5}, tolerance=±{6}%)" -f $totalFiles, $subfolders.Count, $avg, $low, $high, $FilesPerFolderLimit, $Tolerance)

    # Log current distribution summary
    LogMessage -Message "Rebalance: === CURRENT DISTRIBUTION ==="
    foreach ($sf in ($subfolders | Sort-Object { $folderCounts[$_.FullName] } -Descending)) {
        $p = $sf.FullName
        $count = $folderCounts[$p]
        $folderName = Split-Path -Leaf $p
        $deviation = $count - $avg
        $deviationPct = if ($avg -gt 0) { ($deviation / $avg) * 100 } else { 0 }
        $status = if ($count -gt $high) { "DONOR" } elseif ($count -lt $low) { "RECEIVER" } else { "BALANCED" }
        LogMessage -Message ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files) [{4}]" -f $folderName, $count, $deviationPct, $deviation, $status)
    }

    # Classify donors and receivers
    $donors = @()
    $receivers = @()
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        $c = [int]$folderCounts[$p]
        $surplus = $c - $high
        $deficit = $low - $c
        if ($surplus -gt 0) {
            $donors += [pscustomobject]@{ Path = $p; Surplus = $surplus }
        }
        elseif ($deficit -gt 0) {
            $receivers += [pscustomobject]@{ Path = $p; Deficit = $deficit }
        }
    }

    if (-not $donors -and -not $receivers) {
        LogMessage -Message ("Rebalance: all subfolders already within ±{0}% of average. Nothing to do." -f $Tolerance) -ConsoleOutput
        return
    }
    if (-not $receivers) {
        LogMessage -Message "Rebalance: no receivers below lower bound; cannot reduce above-average folders without capacity. Nothing to do." -ConsoleOutput
        return
    }

    $totalSurplus = ($donors   | Measure-Object -Property Surplus -Sum).Sum
    $totalDeficit = ($receivers | Measure-Object -Property Deficit -Sum).Sum
    $plannedMoves = [int][Math]::Min([int]$totalSurplus, [int]$totalDeficit)

    LogMessage -Message ("Rebalance: donors={0} (surplus={1}), receivers={2} (deficit={3}), plannedMoves={4}" -f $donors.Count, $totalSurplus, $receivers.Count, $totalDeficit, $plannedMoves)

    # Log detailed donor/receiver breakdown
    if ($donors.Count -gt 0) {
        LogMessage -Message "Rebalance: === DONORS (above upper bound) ==="
        foreach ($d in ($donors | Sort-Object -Property Surplus -Descending)) {
            $folderName = Split-Path -Leaf $d.Path
            $currentCount = $folderCounts[$d.Path]
            LogMessage -Message ("  {0}: {1} files (surplus: {2})" -f $folderName, $currentCount, $d.Surplus)
        }
    }

    if ($receivers.Count -gt 0) {
        LogMessage -Message "Rebalance: === RECEIVERS (below lower bound) ==="
        foreach ($r in ($receivers | Sort-Object -Property Deficit -Descending)) {
            $folderName = Split-Path -Leaf $r.Path
            $currentCount = $folderCounts[$r.Path]
            LogMessage -Message ("  {0}: {1} files (deficit: {2})" -f $folderName, $currentCount, $r.Deficit)
        }
    }

    LogMessage -Message ("Rebalance: beginning file transfers ({0} files to move)..." -f $plannedMoves)

    if ($plannedMoves -le 0) {
        LogMessage -Message "Rebalance: no feasible moves. Nothing to do." -ConsoleOutput
        return
    }

    # Sort donors by largest surplus first; receivers tracked by mutable deficits
    $donors = $donors | Sort-Object -Property Surplus -Descending
    $receiverMap = @{}
    foreach ($r in $receivers) { $receiverMap[$r.Path] = [int]$r.Deficit }

    # Build a helper to pick the receiver with the largest remaining deficit
    function Get-BestReceiver([hashtable]$map) {
        if ($map.Keys.Count -eq 0) { return $null }
        $bestKey = $null; $bestVal = -1
        foreach ($k in $map.Keys) {
            $v = [int]$map[$k]
            if ($v -gt $bestVal) { $bestVal = $v; $bestKey = $k }
        }
        if ($bestVal -le 0) { return $null }
        return $bestKey
    }

    $GlobalFileCounter.Value = 0
    $totalMoved = 0
    $totalFailed = 0
    $lastLoggedProgress = 0

    foreach ($d in $donors) {
        if ($GlobalFileCounter.Value -ge $plannedMoves) { break }
        $src = $d.Path
        $srcFolderName = Split-Path -Leaf $src
        $moveCount = [int][Math]::Min([int]$d.Surplus, [int]($plannedMoves - $GlobalFileCounter.Value))
        if ($moveCount -le 0) { continue }

        # Randomly choose exactly what we need from this donor
        $candidates = @()
        try {
            $allFiles = Get-ChildItem -LiteralPath $src -File -Force -ErrorAction Stop
            if ($allFiles.Count -gt 0) {
                $moveCount = [Math]::Min($moveCount, $allFiles.Count)
                $candidates = if ($moveCount -lt $allFiles.Count) { $allFiles | Get-Random -Count $moveCount } else { $allFiles }
                LogMessage -Message ("DEBUG: Selected {0} file(s) from donor '{1}'" -f $candidates.Count, $srcFolderName) -IsDebug
            }
        }
        catch {
            LogMessage -Message "Rebalance: failed to enumerate files in donor '$src': $($_.Exception.Message)" -IsWarning
            continue
        }
        if (-not $candidates) { continue }

        foreach ($file in $candidates) {
            if ($GlobalFileCounter.Value -ge $plannedMoves) { break }
            $destFolder = Get-BestReceiver $receiverMap
            if (-not $destFolder) { break } # no more capacity anywhere

            $destFolderName = Split-Path -Leaf $destFolder

            # Prepare destination and copy
            $newName = ResolveFileNameConflict -TargetFolder $destFolder -OriginalFileName $file.Name
            $dest = Join-Path -Path $destFolder -ChildPath $newName

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, $srcFolderName, $destFolderName) -IsDebug

            Copy-ItemWithRetry -Path $file.FullName -Destination $dest -RetryDelay $RetryDelay -RetryCount $RetryCount
            if (Test-Path -LiteralPath $dest) {
                # Update receiver deficit and donor surplus
                $receiverMap[$destFolder] = [Math]::Max(0, ([int]$receiverMap[$destFolder]) - 1)
                if ($receiverMap[$destFolder] -le 0) { $receiverMap.Remove($destFolder) }

                # Handle original via DeleteMode
                try {
                    if ($DeleteMode -eq "RecycleBin") {
                        Move-ToRecycleBin -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "Immediate") {
                        Remove-File -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "EndOfScript") {
                        # Use FileQueue module to add file to deletion queue
                        $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $file.FullName -ValidateFile $false
                        if (-not $queueResult) {
                            Write-LogDebug "Failed to queue file for deletion: $($file.FullName)"
                        }
                    }
                }
                catch {
                    LogMessage -Message "Rebalance: post-copy handling failed for '$($file.FullName)': $($_.Exception.Message)" -IsWarning
                }
                $totalMoved++
                $GlobalFileCounter.Value++

                # Show progress (visual and logged)
                if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
                    $pct = [math]::Floor(($GlobalFileCounter.Value / $plannedMoves) * 100)
                    Write-Progress -Activity "Rebalancing subfolders" -Status "Moved $($GlobalFileCounter.Value) of $plannedMoves" -PercentComplete $pct
                }

                # Log progress periodically
                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge ($plannedMoves / 10)) {
                    $pct = if ($plannedMoves -gt 0) { ($GlobalFileCounter.Value / $plannedMoves) * 100 } else { 0 }
                    LogMessage -Message ("Rebalance: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $plannedMoves, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            }
            else {
                $totalFailed++
                LogMessage -Message "Rebalance: failed to copy '$($file.FullName)' to '$dest'." -IsError
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Rebalancing subfolders" -Status "Complete" -Completed }

    # Log final results
    LogMessage -Message "Rebalance: === FINAL RESULTS ==="
    LogMessage -Message ("  Files moved successfully: {0}" -f $totalMoved)
    if ($totalFailed -gt 0) {
        LogMessage -Message ("  Files failed to move: {0}" -f $totalFailed) -IsWarning
    }
    LogMessage -Message ("Rebalance: redistribution complete - moved {0} of {1} planned file(s)" -f $totalMoved, $plannedMoves)

    # Log final distribution (verify)
    LogMessage -Message "Rebalance: === FINAL DISTRIBUTION (verification) ==="
    foreach ($sf in ($subfolders | Sort-Object FullName)) {
        $p = $sf.FullName
        try {
            $finalCount = (Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop | Measure-Object).Count
            $folderName = Split-Path -Leaf $p
            $originalCount = $folderCounts[$p]
            $delta = $finalCount - $originalCount
            $finalDeviation = $finalCount - $avg
            $finalDeviationPct = if ($avg -gt 0) { ($finalDeviation / $avg) * 100 } else { 0 }
            $status = if ($finalCount -gt $high) { "DONOR" } elseif ($finalCount -lt $low) { "RECEIVER" } else { "BALANCED" }
            LogMessage -Message ("  {0}: {1} files (was {2}, {3:+0;-0;0}) [avg {4:+0.0;-0.0;0}%] [{5}]" -f $folderName, $finalCount, $originalCount, $delta, $finalDeviationPct, $status)
        }
        catch {
            LogMessage -Message ("  {0}: unable to verify (error enumerating)" -f (Split-Path -Leaf $p)) -IsWarning
        }
    }
}

function RandomizeDistributionAcrossFolders {
    param (
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter
    )

    LogMessage -Message "Randomize: redistributing ALL files randomly across all subfolders..."

    # Enumerate subfolders
    $subfolders = @()
    try {
        $subfolders = Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction Stop
    }
    catch {
        LogMessage -Message "Randomize: failed to enumerate subfolders under '$TargetFolder': $($_.Exception.Message)" -IsError
        return
    }
    if (-not $subfolders -or $subfolders.Count -eq 0) {
        LogMessage -Message "Randomize: no subfolders present; nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)

    # Enumerate all files in all subfolders and track current counts
    $allFiles = @()
    $totalFiles = 0
    $currentCounts = @{}

    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        try {
            $files = @(Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop)
            $allFiles += $files
            $totalFiles += $files.Count
            $currentCounts[$p] = $files.Count
            LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $files.Count) -IsDebug
        }
        catch {
            LogMessage -Message "Randomize: failed to enumerate files in '$p': $($_.Exception.Message)" -IsWarning
            $currentCounts[$p] = 0
        }
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Randomize: no files to redistribute." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: found {0} file(s) total across {1} subfolder(s)" -f $totalFiles, $subfolders.Count)

    # Log current distribution summary
    LogMessage -Message "Randomize: === CURRENT DISTRIBUTION ==="
    $avg = [double]$totalFiles / [double]$subfolders.Count
    foreach ($sf in ($subfolders | Sort-Object { $currentCounts[$_.FullName] } -Descending)) {
        $p = $sf.FullName
        $count = $currentCounts[$p]
        $folderName = Split-Path -Leaf $p
        $deviation = $count - $avg
        $deviationPct = if ($avg -gt 0) { ($deviation / $avg) * 100 } else { 0 }
        LogMessage -Message ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files)" -f $folderName, $count, $deviationPct, $deviation)
    }
    LogMessage -Message ("Randomize: average = {0:N2} files per folder" -f $avg)

    # Shuffle files randomly
    LogMessage -Message "Randomize: shuffling file list randomly..."
    try {
        if ($allFiles.Count -gt 1) {
            $allFiles = $allFiles | Get-Random -Count $allFiles.Count
            LogMessage -Message "Randomize: shuffle complete"
        }
    }
    catch {
        LogMessage -Message "Randomize: failed to shuffle files: $($_.Exception.Message). Proceeding without shuffle." -IsWarning
    }

    # Calculate target files per folder (even distribution)
    $targetPerFolder = [int][Math]::Ceiling([double]$totalFiles / [double]$subfolders.Count)
    LogMessage -Message ("Randomize: target = {0} files per folder (ceiling of {1} total / {2} folders)" -f $targetPerFolder, $totalFiles, $subfolders.Count)

    # Assign files to folders using round-robin
    LogMessage -Message "Randomize: assigning files to folders using round-robin through shuffled list..."
    $assignments = @{}
    foreach ($sf in $subfolders) {
        $assignments[$sf.FullName] = @()
    }

    $folderIndex = 0
    $subfolderPaths = @($subfolders | ForEach-Object { $_.FullName })

    foreach ($file in $allFiles) {
        $targetFolderPath = $subfolderPaths[$folderIndex]
        $assignments[$targetFolderPath] += $file

        # Move to next folder (round-robin)
        $folderIndex = ($folderIndex + 1) % $subfolderPaths.Count
    }

    # Log planned distribution summary
    LogMessage -Message "Randomize: === PLANNED DISTRIBUTION ==="
    foreach ($sf in ($subfolders | Sort-Object { $assignments[$_.FullName].Count } -Descending)) {
        $p = $sf.FullName
        $plannedCount = $assignments[$p].Count
        $currentCount = $currentCounts[$p]
        $delta = $plannedCount - $currentCount
        $folderName = Split-Path -Leaf $p
        LogMessage -Message ("  {0}: {1} files (currently {2}, {3:+0;-0;0})" -f $folderName, $plannedCount, $currentCount, $delta)
    }

    # Calculate move statistics
    $filesStaying = 0
    $filesMoving = 0
    foreach ($file in $allFiles) {
        $currentFolder = Split-Path -Path $file.FullName -Parent
        $assignedFolder = $null
        foreach ($p in $subfolderPaths) {
            if ($assignments[$p] -contains $file) {
                $assignedFolder = $p
                break
            }
        }
        if ($currentFolder -eq $assignedFolder) {
            $filesStaying++
        }
        else {
            $filesMoving++
        }
    }

    $stayingPct = if ($totalFiles -gt 0) { ($filesStaying / $totalFiles) * 100 } else { 0 }
    $movingPct = if ($totalFiles -gt 0) { ($filesMoving / $totalFiles) * 100 } else { 0 }

    LogMessage -Message "Randomize: === MOVE STATISTICS ==="
    LogMessage -Message ("  Files staying in current folder: {0} ({1:N1}%)" -f $filesStaying, $stayingPct)
    LogMessage -Message ("  Files moving to different folder: {0} ({1:N1}%)" -f $filesMoving, $movingPct)
    LogMessage -Message ("Randomize: beginning file redistribution ({0} files to move)..." -f $filesMoving)

    # Move files to their assigned destinations
    $GlobalFileCounter.Value = 0
    $totalMoves = 0
    $totalSkipped = 0
    $totalErrors = 0
    $lastLoggedProgress = 0

    foreach ($destFolder in $subfolderPaths) {
        $filesToMove = $assignments[$destFolder]
        if ($filesToMove.Count -eq 0) { continue }

        $destFolderName = Split-Path -Leaf $destFolder
        LogMessage -Message ("DEBUG: Processing {0} file(s) assigned to folder '{1}'" -f $filesToMove.Count, $destFolderName) -IsDebug

        foreach ($file in $filesToMove) {
            # Skip if file is already in the target folder
            $currentFolder = Split-Path -Path $file.FullName -Parent
            if ($currentFolder -eq $destFolder) {
                $totalSkipped++
                LogMessage -Message ("DEBUG: Skipping '{0}' - already in assigned folder" -f $file.Name) -IsDebug
                continue
            }

            # Resolve file name conflict
            $newName = ResolveFileNameConflict -TargetFolder $destFolder -OriginalFileName $file.Name
            $dest = Join-Path -Path $destFolder -ChildPath $newName

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, (Split-Path -Leaf $currentFolder), $destFolderName) -IsDebug

            # Copy file to destination
            Copy-ItemWithRetry -Path $file.FullName -Destination $dest -RetryDelay $RetryDelay -RetryCount $RetryCount

            if (Test-Path -LiteralPath $dest) {
                $totalMoves++
                $GlobalFileCounter.Value++

                # Handle original via DeleteMode
                try {
                    if ($DeleteMode -eq "RecycleBin") {
                        Move-ToRecycleBin -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "Immediate") {
                        Remove-File -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "EndOfScript") {
                        $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $file.FullName -ValidateFile $false
                        if (-not $queueResult) {
                            Write-LogDebug "Failed to queue file for deletion: $($file.FullName)"
                        }
                    }
                }
                catch {
                    LogMessage -Message "Randomize: failed to handle original file '$($file.FullName)': $($_.Exception.Message)" -IsWarning
                }

                # Show progress (visual and logged)
                if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
                    Write-Progress -Activity "Randomizing distribution" -Status ("Moved {0} of {1} files" -f $GlobalFileCounter.Value, $filesMoving) -PercentComplete (($GlobalFileCounter.Value / $filesMoving) * 100)
                }

                # Log progress periodically
                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge ($filesMoving / 10)) {
                    $pct = if ($filesMoving -gt 0) { ($GlobalFileCounter.Value / $filesMoving) * 100 } else { 0 }
                    LogMessage -Message ("Randomize: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $filesMoving, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            }
            else {
                $totalErrors++
                LogMessage -Message "Randomize: failed to copy '$($file.FullName)' to '$dest'" -IsWarning
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Randomizing distribution" -Status "Complete" -Completed }

    # Log final results
    LogMessage -Message "Randomize: === FINAL RESULTS ==="
    LogMessage -Message ("  Files moved successfully: {0}" -f $totalMoves)
    LogMessage -Message ("  Files skipped (already in assigned folder): {0}" -f $totalSkipped)
    if ($totalErrors -gt 0) {
        LogMessage -Message ("  Files failed to move: {0}" -f $totalErrors) -IsWarning
    }
    LogMessage -Message ("Randomize: redistribution complete - moved {0} file(s) to achieve random even distribution" -f $totalMoves)

    # Log final distribution (verify)
    LogMessage -Message "Randomize: === FINAL DISTRIBUTION (verification) ==="
    foreach ($sf in ($subfolders | Sort-Object FullName)) {
        $p = $sf.FullName
        try {
            $finalCount = (Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop | Measure-Object).Count
            $folderName = Split-Path -Leaf $p
            $originalCount = $currentCounts[$p]
            $delta = $finalCount - $originalCount
            LogMessage -Message ("  {0}: {1} files (was {2}, {3:+0;-0;0})" -f $folderName, $finalCount, $originalCount, $delta)
        }
        catch {
            LogMessage -Message ("  {0}: unable to verify (error enumerating)" -f (Split-Path -Leaf $p)) -IsWarning
        }
    }
}

function ConsolidateSubfoldersToMinimum {
    param (
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter
    )

    LogMessage -Message "Consolidation: computing minimal subfolder set..."

    # Enumerate subfolders and counts
    $subfolders = @()
    try {
        $subfolders = Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction Stop
    }
    catch {
        LogMessage -Message "Consolidation: failed to enumerate subfolders under '$TargetFolder': $($_.Exception.Message)" -IsError
        return
    }
    if (-not $subfolders -or $subfolders.Count -eq 0) {
        LogMessage -Message "Consolidation: no subfolders present; nothing to do." -ConsoleOutput
        return
    }

    $folderCounts = @{}
    $totalFiles = 0
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        $count = 0
        try {
            $count = (Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop | Measure-Object).Count
        }
        catch {
            LogMessage -Message "Consolidation: failed to count files in '$p': $($_.Exception.Message)" -IsWarning
        }
        $folderCounts[$p] = [int]$count
        $totalFiles += [int]$count
    }

    # If any files remain in the target root, include them in total (should be 0 after prior phases)
    try {
        $rootResidual = (Get-ChildItem -LiteralPath $TargetFolder -File -Force -ErrorAction Stop | Measure-Object).Count
        if ($rootResidual -gt 0) {
            LogMessage -Message "Consolidation: found $rootResidual file(s) in target root. They will be moved during consolidation." -IsWarning
            $totalFiles += [int]$rootResidual
        }
    }
    catch {
        LogMessage -Message "Consolidation: failed to check target root for residual files: $($_.Exception.Message)" -IsWarning
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Consolidation: no files to consolidate." -ConsoleOutput
        return
    }

    $needed = [Math]::Ceiling([double]$totalFiles / [double]$FilesPerFolderLimit)
    if ($needed -lt 1) { $needed = 1 }

    $existingCount = $subfolders.Count
    LogMessage -Message ("Consolidation: totalFiles={0}, limit={1}, existingSubfolders={2}, needed={3}" -f $totalFiles, $FilesPerFolderLimit, $existingCount, $needed)

    if ($existingCount -le $needed) {
        LogMessage -Message "Consolidation: already at or below minimal subfolder count ($existingCount ≤ $needed). Nothing to do." -ConsoleOutput
        return
    }

    # Choose keepers randomly
    $keepers = @($subfolders | Get-Random -Count $needed | ForEach-Object { $_.FullName })
    $others = @($subfolders | Where-Object { $keepers -notcontains $_.FullName } | ForEach-Object { $_.FullName })
    LogMessage -Message ("Consolidation: selected {0} keeper(s), {1} to drain." -f $keepers.Count, $others.Count)

    # Capacity and live counts for keepers
    $liveCounts = @{}; $capacity = @{}
    foreach ($k in $keepers) {
        $c = if ($folderCounts.ContainsKey($k)) { [int]$folderCounts[$k] } else { 0 }
        $liveCounts[$k] = $c
        $capacity[$k] = [Math]::Max(0, $FilesPerFolderLimit - $c)
    }

    # Collect files to move from non-keepers (and optionally root residuals)
    $filesToMove = @()
    foreach ($o in $others) {
        try { $filesToMove += (Get-ChildItem -LiteralPath $o -File -Force -ErrorAction Stop) } catch {
            LogMessage -Message "Consolidation: failed enumerating files in '$o': $($_.Exception.Message)" -IsWarning
        }
    }
    try { $filesToMove += (Get-ChildItem -LiteralPath $TargetFolder -File -Force -ErrorAction Stop) } catch {
        Write-LogDebug "Failed to enumerate files in target folder root: $_"
    }

    if (-not $filesToMove -or $filesToMove.Count -eq 0) {
        LogMessage -Message "Consolidation: nothing to move; proceeding to delete empty subfolders (if any)."
    }
    else {
        # Shuffle to reduce bias
        try { if ($filesToMove.Count -gt 1) { $filesToMove = $filesToMove | Get-Random -Count $filesToMove.Count } } catch {
            Write-LogDebug "Failed to shuffle files for consolidation: $_"
        }

        $totalMoves = $filesToMove.Count
        $GlobalFileCounter.Value = 0
        LogMessage -Message ("Consolidation: moving {0} file(s) into {1} keeper(s)..." -f $totalMoves, $keepers.Count)

        foreach ($file in $filesToMove) {
            # Find eligible keepers with remaining capacity
            $eligible = @()
            foreach ($k in $keepers) { if ($capacity[$k] -gt 0) { $eligible += $k } }
            if ($eligible.Count -eq 0) {
                # Safety: all keepers exhausted; create a new keeper (rare unless counts changed concurrently)
                $newK = Join-Path -Path $TargetFolder -ChildPath (Get-RandomFileName)
                try { New-Item -ItemType Directory -Path $newK -Force | Out-Null } catch {
                    Write-LogDebug "Failed to create new keeper directory ${newK}: $_"
                }
                $keepers += $newK
                $liveCounts[$newK] = 0
                $capacity[$newK] = $FilesPerFolderLimit
                $eligible = @($newK)
                LogMessage -Message "Consolidation: keeper capacity exhausted; created additional keeper '$newK'." -IsWarning
            }

            # Choose destination: among eligible, pick those with minimum current count to balance
            $minCount = ($eligible | ForEach-Object { $liveCounts[$_] } | Measure-Object -Minimum).Minimum
            $cands = @($eligible | Where-Object { $liveCounts[$_] -eq $minCount })
            $destFolder = if ($cands.Count -gt 1) { $cands | Get-Random } else { $cands[0] }

            $originalName = $file.Name
            $newFileName = ResolveFileNameConflict -TargetFolder $destFolder -OriginalFileName $originalName
            $destination = Join-Path -Path $destFolder -ChildPath $newFileName

            Copy-ItemWithRetry -Path $file.FullName -Destination $destination -RetryDelay $RetryDelay -RetryCount $RetryCount

            if (Test-Path -LiteralPath $destination) {
                # Update counts/capacity
                $liveCounts[$destFolder]++
                $capacity[$destFolder] = [Math]::Max(0, $FilesPerFolderLimit - $liveCounts[$destFolder])

                # Handle the original per DeleteMode
                try {
                    if ($DeleteMode -eq "RecycleBin") {
                        Move-ToRecycleBin -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "Immediate") {
                        Remove-File -FilePath $file.FullName
                    }
                    elseif ($DeleteMode -eq "EndOfScript") {
                        # Use FileQueue module to add file to deletion queue
                        $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $file.FullName -ValidateFile $false
                        if (-not $queueResult) {
                            Write-LogDebug "Failed to queue file for deletion: $($file.FullName)"
                        }
                    }
                }
                catch {
                    LogMessage -Message "Consolidation: post-copy handling failed for '$($file.FullName)': $($_.Exception.Message)" -IsWarning
                }
            }
            else {
                LogMessage -Message "Consolidation: failed to copy '$($file.FullName)' to '$destination'." -IsError
            }

            $GlobalFileCounter.Value++
            if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
                $percent = [math]::Floor(($GlobalFileCounter.Value / $totalMoves) * 100)
                Write-Progress -Activity "Consolidating subfolders" -Status "Moved $($GlobalFileCounter.Value) of $totalMoves" -PercentComplete $percent
            }
        }
        if ($ShowProgress) { Write-Progress -Activity "Consolidating subfolders" -Status "Complete" -Completed }
    }

    # Delete empty non-keeper subfolders
    $deleted = 0; $skipped = 0
    foreach ($o in $others) {
        try {
            $entries = (Get-ChildItem -LiteralPath $o -Force -ErrorAction Stop | Measure-Object).Count
            if ($entries -eq 0) {
                Remove-ItemWithRetry -Path $o -RetryDelay $RetryDelay -RetryCount $RetryCount
                LogMessage -Message "Consolidation: deleted empty subfolder '$o'."
                $deleted++
            }
            else {
                $skipped++
                LogMessage -Message "Consolidation: subfolder '$o' not empty after move; skipping deletion." -IsWarning
            }
        }
        catch {
            $skipped++
            LogMessage -Message "Consolidation: failed to delete su^bfolder '$o': $($_.Exception.Message)" -IsWarning
        }
    }
    LogMessage -Message ("Consolidation: removed {0} empty subfolder(s); {1} skipped." -f $deleted, $skipped)
}

function ConvertFrom-FileQueue {
    <#
    .SYNOPSIS
        Converts a FileQueue to an array for state persistence.
    #>
    param (
        [PSCustomObject]$Queue
    )

    $queueArray = @()
    $tempQueue = [System.Collections.Generic.Queue[PSCustomObject]]::new()

    while ($Queue.Items.Count -gt 0) {
        $item = $Queue.Items.Dequeue()
        $queueArray += [pscustomobject]@{
            Path = $item.SourcePath
            Size = $item.Size
            LastWriteTimeUtc = $item.LastWriteTimeUtc
            QueuedAtUtc = $item.QueuedAtUtc
            SessionId = $item.SessionId
        }
        $tempQueue.Enqueue($item)
    }

    # Restore the queue
    $Queue.Items = $tempQueue

    return $queueArray
}

function SaveState {
    param (
        [int]$Checkpoint,
        [hashtable]$AdditionalVariables = @{ },
        [ref]$fileLock
    )

    # Ensure a session id exists before persisting
    if (-not $script:SessionId) {
        $script:SessionId = [guid]::NewGuid().ToString()
    }

    # Capture aggregated counters for restart safety
    $warningsSoFar = $script:Warnings
    $errorsSoFar = $script:Errors

    # Release the file lock before saving state
    ReleaseFileLock -FileStream $fileLock.Value

    # Ensure the state file exists
    if (-not (Test-Path -Path $StateFilePath)) {
        New-Item -Path $StateFilePath -ItemType File -Force | Out-Null
        LogMessage -Message "State file created at $StateFilePath"
    }

    # Combine state information
    $state = @{
        Checkpoint    = $Checkpoint
        SessionId     = $script:SessionId
        WarningsSoFar = $warningsSoFar
        ErrorsSoFar   = $errorsSoFar
        Timestamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    # Merge additional variables into the state
    foreach ($key in $AdditionalVariables.Keys) {
        $state[$key] = $AdditionalVariables[$key]
    }

    # Save the state to the file in JSON format with appropriate depth
    Write-JsonAtomically -StateObject $state -Path $StateFilePath

    # Log the save operation
    LogMessage -Message "Saved state: Checkpoint $Checkpoint and additional variables: $($AdditionalVariables.Keys -join ', ')"

    # Reacquire the file lock after saving state
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
}

# Function to load state
function LoadState {
    param (
        [ref]$fileLock
    )

    # Release the file lock before loading state
    ReleaseFileLock -FileStream $fileLock.Value

    $state = $null
    $primary = $StateFilePath
    $backup = "$StateFilePath.bak"

    # Try primary first
    $state = Get-StateFromPath -Path $primary

    # If primary fails, try backup, recover if successful, or quarantine the corrupt file
    if (-not $state) {
        $stateBak = Get-StateFromPath -Path $backup
        if ($stateBak) {
            try {
                Copy-Item -LiteralPath $backup -Destination $primary -Force
                # also refresh sidecar
                $bakHashPath = "$backup.sha256"
                $priHashPath = "$primary.sha256"
                if (Test-Path -LiteralPath $bakHashPath) {
                    Copy-Item -LiteralPath $bakHashPath -Destination $priHashPath -Force -ErrorAction SilentlyContinue
                }
                else {
                    $rehash = Get-FileSha256Hex -Path $primary
                    if ($rehash) { Set-Content -LiteralPath $priHashPath -Value $rehash -Encoding ASCII }
                }
                LogMessage -Message "Recovered state from backup '$backup'."
            }
            catch {
                LogMessage -Message "Failed to restore state from backup '$backup': $($_.Exception.Message)" -IsWarning
            }
            $state = $stateBak
        }
        elseif (Test-Path -LiteralPath $primary) {
            # Quarantine corrupt primary for diagnostics
            try {
                $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $corruptName = "$primary.corrupt-$stamp.json"
                Rename-Item -LiteralPath $primary -NewName (Split-Path -Leaf $corruptName) -ErrorAction Stop
                # Sidecar too
                $priHashPath = "$primary.sha256"
                if (Test-Path -LiteralPath $priHashPath) {
                    Rename-Item -LiteralPath $priHashPath -NewName ((Split-Path -Leaf $corruptName) + ".sha256") -ErrorAction SilentlyContinue
                }
                LogMessage -Message "Quarantined corrupt state file to '$corruptName'." -IsWarning
            }
            catch {
                LogMessage -Message "Failed to quarantine corrupt state file '$primary': $($_.Exception.Message)" -IsWarning
            }
        }
    }

    # Fallback to default state if still not available
    if (-not $state) { $state = @{ Checkpoint = 0 } }

    # Reacquire the file lock after loading state
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff

    return $state
}

# Function to extract paths from items
function ConvertItemsToPaths {
    param ([array]$Items)

    LogMessage -Message "DEBUG: ConvertItemsToPaths - Input count: $(if ($Items) { $Items.Count } else { '0 (null)' })" -IsDebug

    if (-not $Items) {
        LogMessage -Message "DEBUG: ConvertItemsToPaths - Returning empty array (null input)" -IsDebug
        return @()
    }

    $out = @()
    $index = 0
    foreach ($i in $Items) {
        $index++

        if ($null -eq $i) {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index is null, skipping" -IsDebug
            continue
        }

        $itemType = $i.GetType().Name
        LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index type is $itemType" -IsDebug

        if ($i -is [System.IO.FileSystemInfo]) {
            if ($i.FullName) {
                $fullPath = $i.FullName
                if (-not [string]::IsNullOrWhiteSpace($fullPath)) {
                    LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index converting '$($i.Name)' to '$fullPath'" -IsDebug
                    $out += $fullPath
                }
                else {
                    LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index has whitespace-only FullName for '$($i.Name)'" -IsDebug
                }
            }
            else {
                LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index has no FullName property for '$($i.Name)'"
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$i)) {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index is string '$i'" -IsDebug
            $out += [string]$i
        }
        else {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index skipped (empty/whitespace)"
        }
    }

    LogMessage -Message "DEBUG: ConvertItemsToPaths - Output count: $($out.Count)" -IsDebug
    return $out
}

# Function to convert paths to items
function ConvertPathsToItems {
    param ([array]$Paths)

    LogMessage -Message "DEBUG: ConvertPathsToItems - Input count: $(if ($Paths) { $Paths.Count } else { '0 (null)' })" -IsDebug

    if (-not $Paths) {
        LogMessage -Message "DEBUG: ConvertPathsToItems - Returning empty array (null input)" -IsDebug
        return @()
    }

    $out = @()
    $index = 0
    foreach ($path in $Paths) {
        $index++

        if ([string]::IsNullOrWhiteSpace($path)) {
            LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index is null/whitespace, skipping" -IsDebug
            continue
        }

        LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index processing path '$path'" -IsDebug

        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($item -and $item.FullName -and -not [string]::IsNullOrWhiteSpace($item.FullName)) {
                LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index successfully converted to $($item.GetType().Name)"
                $out += $item
            }
            else {
                LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index has invalid FullName after Get-Item"
            }
        }
        catch {
            LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index failed to convert '$path' - $($_.Exception.Message)" -IsWarning
        }
    }

    LogMessage -Message "DEBUG: ConvertPathsToItems - Output count: $($out.Count)"
    return $out
}

# Function to acquire a lock on the state file
function AcquireFileLock {
    param (
        [string]$FilePath,
        [int]$RetryDelay,
        [int]$RetryCount,
        [int]$MaxBackoff
    )

    $attempts = 0
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($FilePath, 'OpenOrCreate', 'ReadWrite', 'None')
            LogMessage -Message "Acquired lock on $FilePath"
            return $fileStream
        }
        catch {
            $attempts++
            $lastErr = $_.Exception.Message
            if ($RetryCount -ne 0 -and $attempts -ge $RetryCount) {
                LogMessage -Message "Failed to acquire lock on $FilePath after $attempts attempt(s). Last error: $lastErr" -IsError
                throw "Failed to acquire lock on $FilePath after $attempts attempt(s). Last error: $lastErr"
            }
            $delay = [Math]::Min([int]([Math]::Max(1, $RetryDelay) * [Math]::Pow(2, $attempts - 1)), [Math]::Max(1, $MaxBackoff))
            $jitterMs = Get-Random -Minimum 50 -Maximum 250
            LogMessage -Message "Attempt $attempts failed to lock '$FilePath'. Error: $lastErr. Retrying in ${delay}s (+${jitterMs}ms jitter)..." -IsWarning
            Start-Sleep -Seconds $delay
            Start-Sleep -Milliseconds $jitterMs
        }
    }
}

# Function to release the file lock
function ReleaseFileLock {
    param (
        [System.IO.FileStream]$FileStream
    )

    if ($null -eq $FileStream) {
        LogMessage -Message "ReleaseFileLock called with null stream; nothing to release."
        return
    }
    $fileName = "<unknown>"
    try { $fileName = $FileStream.Name } catch {
        # Stream may not have a name if already disposed
    }
    try { $FileStream.Close() } catch {
        # Stream may already be closed
    }
    try { $FileStream.Dispose() } catch {
        # Stream may already be disposed
    }
    LogMessage -Message "Released lock on $fileName"
}

# Function to convert size string to bytes
function ConvertToBytes {
    param (
        [string]$Size
    )
    if ($Size -match '^(\d+)([KMG])$') {
        $value = [int]$matches[1]
        switch ($matches[2]) {
            'K' { return $value * 1KB }
            'M' { return $value * 1MB }
            'G' { return $value * 1GB }
        }
    }
    else {
        throw "Invalid size format: $Size. Use formats like 1K, 2M, or 3G."
    }
}

# Function to remove log entries based on timestamp or age
function RemoveLogEntries {
    param (
        [string]$LogFilePath,
        [datetime]$BeforeTimestamp,
        [int]$OlderThanDays
    )

    try {
        if (-not (Test-Path -Path $LogFilePath)) {
            LogMessage -Message "Log file not found: $LogFilePath. Skipping log entry removal." -IsWarning
            return
        }

        $logEntries = Get-Content -Path $LogFilePath
        $filteredEntries = @()

        foreach ($entry in $logEntries) {
            if ($entry -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                $entryTimestamp = [datetime]::ParseExact($matches[0], "yyyy-MM-dd HH:mm:ss", $null)

                if ($BeforeTimestamp -and $entryTimestamp -ge $BeforeTimestamp) {
                    $filteredEntries += $entry
                }
                elseif ($OlderThanDays -and $entryTimestamp -ge (Get-Date).AddDays(-$OlderThanDays)) {
                    $filteredEntries += $entry
                }
            }
            else {
                # Preserve entries without a valid timestamp
                $filteredEntries += $entry
            }
        }

        # Overwrite the log file with filtered entries
        $filteredEntries | Set-Content -Path $LogFilePath
        LogMessage -Message "Log entries filtered successfully. Updated log file: $LogFilePath"
    }
    catch {
        LogMessage -Message "Failed to filter log entries: $($_.Exception.Message)" -IsError
    }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput
    LogMessage -Message "Version: $script:Version" -ConsoleOutput
    $script:DebugMode = ($DebugPreference -ne 'SilentlyContinue')
    Import-RandomNameProvider -ModulePath $RandomNameModulePath

    # Track prior counters from any persisted state for cross-restart safety
    $priorWarnings = 0; $priorErrors = 0
    # Handle log entry removal
    if (-not $Restart) {
        $beforeTimestamp = $null
        if ($RemoveEntriesBefore) {
            try {
                $beforeTimestamp = [datetime]::Parse($RemoveEntriesBefore)
            }
            catch {
                LogMessage -Message "Invalid timestamp format for RemoveEntriesBefore: $RemoveEntriesBefore" -IsError
                throw "Invalid timestamp format. Use 'YYYY-MM-DD HH:MM:SS' or ISO 8601."
            }
        }

        if ($RemoveEntriesOlderThan -lt 0) {
            LogMessage -Message "Invalid value for RemoveEntriesOlderThan: $RemoveEntriesOlderThan. Must be a non-negative integer." -IsError
            throw "Invalid value for RemoveEntriesOlderThan. Must be a non-negative integer."
        }

        if ($beforeTimestamp -or $RemoveEntriesOlderThan) {
            RemoveLogEntries -LogFilePath $LogFilePath -BeforeTimestamp $beforeTimestamp -OlderThanDays $RemoveEntriesOlderThan
        }
    }

    # Handle log truncation for fresh runs
    if (-not $Restart) {
        if ($TruncateIfLarger) {
            try {
                $thresholdBytes = ConvertToBytes -Size $TruncateIfLarger
                if ((Test-Path -Path $LogFilePath) -and ((Get-Item -Path $LogFilePath).Length -gt $thresholdBytes)) {
                    Clear-Content -Path $LogFilePath -Force
                    LogMessage -Message "Log file truncated due to size exceeding ${TruncateIfLarger}: $LogFilePath"
                }
            }
            catch {
                LogMessage -Message "Failed to evaluate or truncate log file based on size: $($_.Exception.Message)" -IsError
            }
        }
        elseif ($TruncateLog) {
            try {
                Clear-Content -Path $LogFilePath -Force
                LogMessage -Message "Log file truncated: $LogFilePath"
            }
            catch {
                LogMessage -Message "Failed to truncate log file: $($_.Exception.Message)" -IsError
            }
        }
    }

    LogMessage -Message "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilesPerFolderLimit - $FilesPerFolderLimit, MaxFilesToCopy - $MaxFilesToCopy"

    try {
        # Ensure source and target folders exist
        if (-not $script:SessionId) { $script:SessionId = [guid]::NewGuid().ToString() }

        # Require SourceFolder/TargetFolder explicitly (removed user-specific defaults)
        # SourceFolder is optional for rebalance-only mode (automatically sets MaxFilesToCopy = 0)
        if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
            # No source folder = rebalance-only mode
            $MaxFilesToCopy = 0
            LogMessage -Message "SourceFolder not specified. Running in rebalance-only mode (no files will be copied)." -ConsoleOutput
        }
        if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
            LogMessage -Message "TargetFolder not specified. Provide -TargetFolder with a valid path." -IsError
            throw "Missing required parameter: -TargetFolder"
        }

        if (-not [string]::IsNullOrWhiteSpace($SourceFolder) -and !(Test-Path -Path $SourceFolder)) {
            LogMessage -Message "Source folder '$SourceFolder' does not exist." -IsError
            throw "Source folder not found."
        }

        if (!($FilesPerFolderLimit -gt 0)) {
            LogMessage -Message "Incorrect value for FilesPerFolderLimit. Resetting to default: 20000." -IsWarning
            $FilesPerFolderLimit = 20000
        }

        if (!(Test-Path -Path $TargetFolder)) {
            LogMessage -Message "Target folder '$TargetFolder' does not exist. Creating it." -IsWarning
            New-Item -ItemType Directory -Path $TargetFolder -Force
        }

        # Validate input parameters
        if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $DeleteMode)) {
            LogMessage -Message "Invalid value for DeleteMode: $DeleteMode. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'." -IsError
            exit 1
        }

        # Enforce mutual exclusivity
        $exclusiveOptions = @($ConsolidateToMinimum, $RebalanceToAverage, $RandomizeDistribution)
        $enabledCount = ($exclusiveOptions | Where-Object { $_ }).Count
        if ($enabledCount -gt 1) {
            LogMessage -Message "Parameters -ConsolidateToMinimum, -RebalanceToAverage, and -RandomizeDistribution are mutually exclusive. Choose only one." -IsError
            throw "Mutually exclusive options: only one of -ConsolidateToMinimum, -RebalanceToAverage, or -RandomizeDistribution can be specified"
        }

        if (-not ("NoWarnings", "WarningsOnly" -contains $EndOfScriptDeletionCondition)) {
            LogMessage -Message "Invalid value for EndOfScriptDeletionCondition: $EndOfScriptDeletionCondition. Valid options are 'NoWarnings', 'WarningsOnly'." -IsError
            exit 1
        }

        # Validate MaxFilesToCopy
        if ($MaxFilesToCopy -lt -1) {
            LogMessage -Message "Invalid MaxFilesToCopy '$MaxFilesToCopy'. Using -1 (no limit)." -IsWarning
            $MaxFilesToCopy = -1
        }

        LogMessage -Message "Parameter validation completed"

        # Initialize stable [ref] holders (do not overwrite these variables later, only set .Value)
        $FilesToDelete = New-FileQueue -Name "FilesToDelete" -SessionId $script:SessionId -MaxSize -1
        $GlobalFileCounter = New-Ref 0   # running count

        $fileLockRef = [ref]$null

        # Initialize variables that will be used in the summary section
        # These must be initialized before checkpoint blocks to ensure they're always available
        $totalSourceFilesAll = 0
        $totalSourceFiles = 0
        $totalTargetFilesBefore = 0
        $subfolders = @()
        $sourceFiles = @()
        $skippedFilesByExtension = @{}  # Hashtable to track skipped files by extension
        $totalSkippedFiles = 0

        try {
            # Restart logic
            $lastCheckpoint = 0
            if ($Restart) {
                # Acquire a lock on the state file
                $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff

                LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput
                $state = LoadState -fileLock $fileLockRef
                $lastCheckpoint = $state.Checkpoint
                if ($lastCheckpoint -gt 0) {
                    # Restore session id (or create if missing for legacy states)
                    if ($state.PSObject.Properties.Name -contains 'SessionId' -and $state.SessionId) {
                        $script:SessionId = [string]$state.SessionId
                    }
                    else {
                        $script:SessionId = [guid]::NewGuid().ToString()
                        LogMessage -Message "Legacy state without SessionId; generated new SessionId for this resume." -IsWarning
                    }
                    # Capture prior counters to aggregate with current run
                    if ($state.PSObject.Properties.Name -contains 'WarningsSoFar') { $priorWarnings = [int]$state.WarningsSoFar }
                    if ($state.PSObject.Properties.Name -contains 'ErrorsSoFar') { $priorErrors = [int]$state.ErrorsSoFar }
                    LogMessage -Message "Restarting from checkpoint $lastCheckpoint" -ConsoleOutput
                }
                else {
                    LogMessage -Message "Checkpoint not found. Executing from top..." -IsWarning
                }

                # Restore SourceFolder
                if ($state.ContainsKey("SourceFolder")) {
                    $savedSourceFolder = $state.SourceFolder

                    # Validate the loaded SourceFolder (allow empty for rebalance-only mode)
                    if (-not [string]::IsNullOrWhiteSpace($savedSourceFolder)) {
                        if ($SourceFolder -ne $savedSourceFolder) {
                            throw "SourceFolder mismatch: Restarted script must use the saved SourceFolder ('$savedSourceFolder'). Aborting."
                        }
                        $SourceFolder = $savedSourceFolder
                        LogMessage -Message "SourceFolder restored from state file: $SourceFolder"
                    }
                    else {
                        LogMessage -Message "SourceFolder was empty in state file (rebalance-only mode)."
                    }
                }
                else {
                    throw "State file does not contain SourceFolder. Unable to enforce."
                }

                # Restore DeleteMode
                if ($state.ContainsKey("deleteMode")) {
                    $savedDeleteMode = $state.deleteMode

                    # Validate the loaded DeleteMode
                    if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $savedDeleteMode)) {
                        throw "Invalid value for DeleteMode in state file: '$savedDeleteMode'. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'."
                    }

                    if ($DeleteMode -ne $savedDeleteMode) {
                        throw "DeleteMode mismatch: Restarted script must use the saved DeleteMode ('$savedDeleteMode'). Aborting."
                    }
                    $DeleteMode = $savedDeleteMode
                    Write-Output "DeleteMode restored from state file: $DeleteMode"
                }
                else {
                    throw "State file does not contain DeleteMode. Unable to enforce."
                }

                # Load checkpoint-specific state (scalars + collections) in one place
                if ($lastCheckpoint -in 2..7 -and $null -ne $state) {

                    # --- Scalars (cheap; always safe to load) ---
                    if ($state.ContainsKey('totalSourceFiles')) { $totalSourceFiles = [int]$state['totalSourceFiles'] }
                    if ($state.ContainsKey('totalTargetFilesBefore')) { $totalTargetFilesBefore = [int]$state['totalTargetFilesBefore'] }
                    if ($state.ContainsKey('totalSourceFilesAll')) { $totalSourceFilesAll = [int]$state['totalSourceFilesAll'] }

                    if ($state.ContainsKey('MaxFilesToCopy')) {
                        $savedMax = [int]$state['MaxFilesToCopy']
                        if ($MaxFilesToCopy -ne $savedMax) {
                            throw "MaxFilesToCopy mismatch: Restarted script must use the saved MaxFilesToCopy ($savedMax). Aborting."
                        }
                        $MaxFilesToCopy = $savedMax
                    }

                    # --- Collections (path -> object conversions only when needed) ---
                    if ($state.ContainsKey('subfolders')) {
                        # Needed by both phases and for post-phase logging
                        $subfolders = ConvertPathsToItems($state['subfolders'])
                    }

                    if ($lastCheckpoint -in 2, 3 -and $state.ContainsKey('sourceFiles')) {
                        # Only needed to run/finish the Source→Target copy before CP4 is saved
                        $sourceFiles = ConvertPathsToItems($state['sourceFiles'])
                    }

                }

                # Load FilesToDelete using FileQueue module for EndOfScript mode and lastCheckpoint 3..7
                if ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4, 5, 6, 7 -and $state.ContainsKey("FilesToDelete")) {
                    $loadedQueue = $state.FilesToDelete
                    $restoredCount = 0

                    # Add items from state to the queue
                    foreach ($e in $loadedQueue) {
                        # Normalize legacy string entries to object format
                        if ($e -is [string]) {
                            $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $e -ValidateFile $false
                        }
                        else {
                            # Add with existing metadata
                            $FilesToDelete.Items.Enqueue([pscustomobject]@{
                                SourcePath = $e.Path
                                TargetPath = $null
                                Size = $e.Size
                                LastWriteTimeUtc = $e.LastWriteTimeUtc
                                QueuedAtUtc = if ($e.PSObject.Properties.Name -contains 'QueuedAtUtc') { $e.QueuedAtUtc } else { (Get-Date).ToUniversalTime() }
                                SessionId = if ($e.PSObject.Properties.Name -contains 'SessionId') { $e.SessionId } else { $script:SessionId }
                                Attempts = 0
                                Metadata = @{}
                            })
                        }
                        $restoredCount++
                    }

                    if ($restoredCount -eq 0) {
                        Write-Output "No files to delete from the previous session."
                    }
                    else {
                        Write-Output "Loaded $restoredCount files to delete from the previous session."
                    }
                }
                elseif ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4, 5, 6, 7) {
                    # If DeleteMode is EndOfScript but no FilesToDelete key exists
                    LogMessage -Message "State file does not contain FilesToDelete key for EndOfScript mode." -IsWarning
                }
            }
            else {

                # Check if a restart state file exists
                if (Test-Path -Path $StateFilePath) {

                    LogMessage -Message "Restart state file found but restart not requested. Deleting state file..." -IsWarning

                    try {
                        Remove-Item -Path $StateFilePath -Force
                        LogMessage -Message "State file $StateFilePath deleted."
                    }
                    catch {
                        LogMessage -Message "Failed to delete state file $StateFilePath. Error: $_" -IsError
                        throw "An error occurred while deleting the state file: $($_.Exception.Message)"
                    }
                }
                # Acquire the file lock after deleting the file
                $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
            }
        }
        catch {
            LogMessage -Message "An unexpected error occurred: $($_.Exception.Message)" -IsError
            throw
        }

        if ($lastCheckpoint -lt 1) {
            # No upfront renaming: we now rename at copy time to preserve source integrity until copy succeeds.
            LogMessage -Message "Preparing for distribution (no upfront renaming; rename occurs at copy time)." -ConsoleOutput
            $additionalVars = @{
                deleteMode   = $DeleteMode # Persist DeleteMode
                SourceFolder = $SourceFolder # Persist SourceFolder
            }
            SaveState -Checkpoint 1 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 2) {
            LogMessage -Message "Enumerating source and target files..." -ConsoleOutput

            # Skip source enumeration if SourceFolder not provided (rebalance-only mode)
            if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
                LogMessage -Message "Skipping source enumeration (rebalance-only mode)." -ConsoleOutput
                $sourceFilesAll = @()
                $totalSourceFilesAll = 0
                $sourceFiles = @()
                $totalSourceFiles = 0
            }
            else {
                # Count files in the source and target folder before distribution
                # First, get ALL files to track what's being skipped
                $allSourceFiles = Get-ChildItem -Path $SourceFolder -Recurse -File
                $totalEnumeratedFiles = $allSourceFiles.Count

                # Define allowed extensions
                $allowedExtensions = @('.jpg', '.png')

                # Filter to only include .jpg and .png files and track skipped files by extension
                $sourceFilesAll = @()
                foreach ($file in $allSourceFiles) {
                    $ext = $file.Extension.ToLower()
                    if ($ext -in $allowedExtensions) {
                        $sourceFilesAll += $file
                    }
                    else {
                        # Track skipped files by extension
                        if (-not $skippedFilesByExtension.ContainsKey($ext)) {
                            $skippedFilesByExtension[$ext] = 0
                        }
                        $skippedFilesByExtension[$ext]++
                        $totalSkippedFiles++
                    }
                }
                $totalSourceFilesAll = $sourceFilesAll.Count

                # Log skipped file statistics
                if ($totalSkippedFiles -gt 0) {
                    LogMessage -Message "Skipped $totalSkippedFiles file(s) with non-compliant extensions:" -ConsoleOutput
                    foreach ($ext in ($skippedFilesByExtension.Keys | Sort-Object)) {
                        $count = $skippedFilesByExtension[$ext]
                        $extDisplay = if ([string]::IsNullOrEmpty($ext)) { "(no extension)" } else { $ext }
                        LogMessage -Message "  $extDisplay : $count file(s)" -ConsoleOutput
                    }
                }

                # Apply copy cap
                if ($MaxFilesToCopy -eq 0) {
                    $sourceFiles = @()
                }
                elseif ($MaxFilesToCopy -gt 0) {
                    # Selection policy: maintain enumeration order; change to | Get-Random -Count $MaxFilesToCopy to sample
                    $sourceFiles = $sourceFilesAll | Select-Object -First $MaxFilesToCopy
                }
                else {
                    $sourceFiles = $sourceFilesAll
                }
                $totalSourceFiles = $sourceFiles.Count
            }

            $totalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
            $totalTargetFilesBefore = if ($null -eq $totalTargetFilesBefore) { 0 } else { $totalTargetFilesBefore }
            $totalFiles = $totalSourceFiles + $totalTargetFilesBefore # per-phase denominator
            LogMessage -Message "Source File Count (selected): $totalSourceFiles of $totalSourceFilesAll total. Target File Count Before: $totalTargetFilesBefore." -ConsoleOutput

            # Get subfolders in the target folder
            LogMessage -Message "DEBUG: About to enumerate subfolders in: '$TargetFolder'" -IsDebug
            LogMessage -Message "DEBUG: Target folder exists: $(Test-Path -LiteralPath $TargetFolder)" -IsDebug
            LogMessage -Message "DEBUG: Target folder is directory: $(Test-Path -LiteralPath $TargetFolder -PathType Container)" -IsDebug

            try {
                $allItems = Get-ChildItem -LiteralPath $TargetFolder -Force -ErrorAction Stop
                LogMessage -Message "DEBUG: Total items found: $($allItems.Count)" -IsDebug

                $subfolders = @($allItems | Where-Object { $_.PSIsContainer })

                LogMessage -Message "DEBUG: Directory items found: $($subfolders.Count)" -IsDebug
                if ($subfolders -and $subfolders.Count -gt 0) {
                    $subfolderNames = @($subfolders | ForEach-Object {
                            if ($_ -and $_.FullName) {
                                "'$($_.FullName)'"
                            }
                        })
                    LogMessage -Message ("DEBUG: Initial subfolders collected ({0} items): {1}" -f $subfolders.Count, ($subfolderNames -join ', ')) -IsDebug
                }
                else {
                    LogMessage -Message "DEBUG: Initial subfolders collected: NONE"
                }
            }
            catch {
                LogMessage -Message "DEBUG: Error during Get-ChildItem: $($_.Exception.Message)" -IsError
                $subfolders = @()
            }
            # Determine if subfolders need to be created
            LogMessage -Message "Total Files Before: $totalFiles."
            $currentFolderCount = $subfolders.Count
            LogMessage -Message "Sub-folder Count Before: $currentFolderCount."

            if ($totalFiles / $FilesPerFolderLimit -gt $currentFolderCount) {
                $additionalFolders = [math]::Ceiling($totalFiles / $FilesPerFolderLimit) - $currentFolderCount
                LogMessage -Message "Need to create $additionalFolders subfolders"
                $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
            }

            $additionalVars = @{
                sourceFiles            = ConvertItemsToPaths($sourceFiles)             # selected-only
                totalSourceFiles       = $totalSourceFiles                        # selected-only
                totalSourceFilesAll    = $totalSourceFilesAll                  # full enumeration
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths($subfolders)
                deleteMode             = $DeleteMode # Persist DeleteMode
                SourceFolder           = $SourceFolder # Persist SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }

            SaveState -Checkpoint 2 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 3) {
            # Add this diagnostic before calling DistributeFilesToSubfolders
            if ($state.subfolders) {
                LogMessage -Message ("DEBUG: State subfolders raw count: {0}" -f $state.subfolders.Count) -IsDebug
            }
            if ($subfolders -and $subfolders.Count -gt 0) {
                $subfolderNames = @($subfolders | ForEach-Object {
                        if ($_ -and $_.FullName) { "'$($_.FullName)'" }
                    })
                LogMessage -Message ("DEBUG: Converted subfolders ({0} items): {1}" -f $subfolders.Count, ($subfolderNames -join ', ')) -IsDebug
            }
            else {
                LogMessage -Message "DEBUG: Converted subfolders: NONE (count: $(if ($subfolders) { $subfolders.Count } else { 'null' }))" -IsDebug
            }

            # Common base for additional variables
            $additionalVars = @{
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths($subfolders)
                deleteMode             = $DeleteMode # Persist DeleteMode
                SourceFolder           = $SourceFolder # Persist SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }

            # Conditionally add FilesToDelete for EndOfScript mode
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }

            # Save the state with the consolidated additional variables
            SaveState -Checkpoint 3 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }
        # --- NEW: Source → Target distribution phase (Checkpoint 4) ---
        if ($lastCheckpoint -lt 4) {
            if ($totalSourceFiles -gt 0 -and $null -ne $sourceFiles -and $sourceFiles.Count -gt 0 -and $subfolders -and $subfolders.Count -gt 0) {
                LogMessage -Message ("Distributing {0} source file(s) to subfolders..." -f $totalSourceFiles) -ConsoleOutput
                $GlobalFileCounter.Value = 0
                DistributeFilesToSubfolders -Files $sourceFiles `
                    -Subfolders $subfolders `
                    -TargetRoot $TargetFolder `
                    -Limit $FilesPerFolderLimit `
                    -ShowProgress:$ShowProgress `
                    -UpdateFrequency:$UpdateFrequency `
                    -DeleteMode $DeleteMode `
                    -FilesToDelete $FilesToDelete `
                    -GlobalFileCounter $GlobalFileCounter `
                    -TotalFiles $totalSourceFiles
            }
            else {
                # Log why we're skipping distribution
                if ($totalSourceFiles -eq 0) {
                    LogMessage -Message "No files to distribute from source folder." -ConsoleOutput
                }
                elseif (-not $subfolders -or $subfolders.Count -eq 0) {
                    LogMessage -Message "No subfolders available in target. Creating first subfolder..." -ConsoleOutput
                    # Create at least one subfolder if source has files but target has none
                    if ($totalSourceFiles -gt 0) {
                        $subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders 1 -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
                    }
                }
            }

            # Persist after Source → Target copy (Checkpoint 4)
            $additionalVars = @{
                sourceFiles            = ConvertItemsToPaths($sourceFiles)
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths($subfolders)
                deleteMode             = $DeleteMode
                SourceFolder           = $SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }
            SaveState -Checkpoint 4 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 5) {
            # Redistribute files within the target folder and subfolders if needed (now Checkpoint 5)
            LogMessage -Message "Redistributing files in target folders..." -ConsoleOutput
            LogMessage -Message ("DEBUG: About to call RedistributeFilesInTarget with {0} subfolders" -f $subfolders.Count) -IsDebug
            RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders `
                -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress `
                -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete -GlobalFileCounter $GlobalFileCounter `
                -TotalFiles 0 # Not used now; function computes its own totals

            # Save post-redistribution state (Checkpoint 5)
            # Base additional variables
            $additionalVars = @{
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                deleteMode             = $DeleteMode # Persist DeleteMode
                SourceFolder           = $SourceFolder # Persist SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }

            # Conditionally add FilesToDelete if DeleteMode is EndOfScript
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }

            # Save state with checkpoint 4 and additional variables
            SaveState -Checkpoint 5 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        # --- Optional: Consolidate into minimum # of subfolders (Checkpoint 6) ---
        if ($ConsolidateToMinimum -and $lastCheckpoint -lt 6) {
            LogMessage -Message "Consolidating files into the minimum number of subfolders... (opt-in)"

            ConsolidateSubfoldersToMinimum -TargetFolder $TargetFolder `
                -FilesPerFolderLimit $FilesPerFolderLimit `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency:$UpdateFrequency `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter

            # Save post-consolidation state (Checkpoint 6)
            $additionalVars = @{
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths( (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force | ForEach-Object { $_ }) )
                deleteMode             = $DeleteMode
                SourceFolder           = $SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }
            SaveState -Checkpoint 6 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        # --- Optional: Rebalance among existing subfolders (Checkpoint 7) ---
        if ($RebalanceToAverage -and $lastCheckpoint -lt 7) {
            LogMessage -Message ("Rebalancing files among existing subfolders to within ±{0}% of average... (opt-in)" -f $RebalanceTolerance)

            RebalanceSubfoldersByAverage -TargetFolder $TargetFolder `
                -FilesPerFolderLimit $FilesPerFolderLimit `
                -Tolerance $RebalanceTolerance `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency:$UpdateFrequency `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter

            # Save post-rebalance state (Checkpoint 7)
            $additionalVars = @{
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths( (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force | ForEach-Object { $_ }) )
                deleteMode             = $DeleteMode
                SourceFolder           = $SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }
            SaveState -Checkpoint 7 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        # --- Optional: Randomize distribution across all subfolders (Checkpoint 8) ---
        if ($RandomizeDistribution -and $lastCheckpoint -lt 8) {
            LogMessage -Message "Randomizing ALL files across all subfolders... (opt-in)"

            RandomizeDistributionAcrossFolders -TargetFolder $TargetFolder `
                -FilesPerFolderLimit $FilesPerFolderLimit `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency:$UpdateFrequency `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter

            # Save post-randomization state (Checkpoint 8)
            $additionalVars = @{
                totalSourceFiles       = $totalSourceFiles
                totalSourceFilesAll    = $totalSourceFilesAll
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders             = ConvertItemsToPaths( (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force | ForEach-Object { $_ }) )
                deleteMode             = $DeleteMode
                SourceFolder           = $SourceFolder
                MaxFilesToCopy         = $MaxFilesToCopy
            }
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = ConvertFrom-FileQueue -Queue $FilesToDelete
            }
            SaveState -Checkpoint 8 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($DeleteMode -eq "EndOfScript") {
            # Use aggregated counters across restarts for safe evaluation
            $effectiveWarnings = [Math]::Max($Warnings, $priorWarnings)
            $effectiveErrors = [Math]::Max($Errors, $priorErrors)

            if (Test-EndOfScriptCondition -Condition $EndOfScriptDeletionCondition -Warnings $effectiveWarnings -Errors $effectiveErrors) {

                # Process deletion queue using FileQueue module
                while ($FilesToDelete.Items.Count -gt 0) {
                    $entry = Get-NextQueueItem -Queue $FilesToDelete -IncrementAttempts $false

                    if ($null -eq $entry) {
                        break
                    }

                    $entryPath = $entry.SourcePath
                    $entrySession = $entry.SessionId
                    $entrySize = $entry.Size
                    $entryMtimeUtc = $entry.LastWriteTimeUtc

                    if ($entrySession -ne $script:SessionId) {
                        LogMessage -Message "Skipping deletion for '$entryPath' — queued by a different session ($entrySession)." -IsWarning
                        continue
                    }

                    try {
                        if (Test-Path -Path $entryPath) {
                            # Verify unchanged if metadata exists
                            $okToDelete = $true
                            try {
                                $fi = Get-Item -LiteralPath $entryPath -ErrorAction Stop
                                if ($null -ne $entrySize -and $fi.Length -ne $entrySize) { $okToDelete = $false }
                                if ($null -ne $entryMtimeUtc -and $fi.LastWriteTimeUtc -ne $entryMtimeUtc) { $okToDelete = $false }
                            }
                            catch {
                                LogMessage -Message "Could not stat '$entryPath' prior to deletion: $($_.Exception.Message)" -IsWarning
                            }

                            if ($okToDelete) {
                                Remove-File -FilePath $entryPath
                                LogMessage -Message "Deleted file: $entryPath during EndOfScript cleanup."
                            }
                            else {
                                LogMessage -Message "Skipped deletion for '$entryPath' due to metadata mismatch (size/time changed)." -IsWarning
                            }
                        }
                        else {
                            LogMessage -Message "File $entryPath not found during EndOfScript deletion." -IsWarning
                        }
                    }
                    catch {
                        # Log a warning for failure to delete
                        LogMessage -Message "Failed to delete file $entryPath. Error: $($_.Exception.Message)" -IsWarning
                    }
                }
            }
            else {
                # Log a message if conditions are not met
                LogMessage -Message "End-of-script deletion skipped due to warnings or errors."
            }
        }

        # Count files in the target folder after distribution
        $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
        $totalTargetFilesAfter = if ($null -eq $totalTargetFilesAfter) { 0 } else { $totalTargetFilesAfter }

        # Log summary message
        LogMessage -Message "===== File Distribution Summary =====" -ConsoleOutput
        LogMessage -Message "Original number of files in the source folder (enumerated): $totalSourceFilesAll" -ConsoleOutput

        # Display skipped file statistics
        if ($totalSkippedFiles -gt 0) {
            LogMessage -Message "Files skipped (non-compliant extensions): $totalSkippedFiles" -ConsoleOutput
            foreach ($ext in ($skippedFilesByExtension.Keys | Sort-Object)) {
                $count = $skippedFilesByExtension[$ext]
                $extDisplay = if ([string]::IsNullOrEmpty($ext)) { "(no extension)" } else { $ext }
                LogMessage -Message "  $extDisplay : $count file(s)" -ConsoleOutput
            }
        }
        else {
            LogMessage -Message "Files skipped (non-compliant extensions): 0" -ConsoleOutput
        }

        LogMessage -Message "Files selected for copying this run: $totalSourceFiles" -ConsoleOutput
        LogMessage -Message "Original number of files in the target folder hierarchy: $totalTargetFilesBefore" -ConsoleOutput
        LogMessage -Message "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput
        LogMessage -Message "Total warnings: $script:Warnings" -ConsoleOutput
        LogMessage -Message "Total errors: $script:Errors" -ConsoleOutput

        if ($totalSourceFiles + $totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage -Message "Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -IsWarning
        }
        else {
            LogMessage -Message "File distribution and cleanup completed successfully." -ConsoleOutput
        }

        # Release the file lock before deleting state file
        if ($fileLockRef -and ($fileLockRef.PSObject.Properties.Name -contains 'Value') -and $fileLockRef.Value) {
            ReleaseFileLock -FileStream $fileLockRef.Value
        }

        Remove-Item -Path $StateFilePath -Force
        LogMessage -Message "Deleted state file: $StateFilePath"

        # Post-processing: Cleanup duplicates
        if ($CleanupDuplicates) {
            $dupScript = Join-Path -Path $script:ScriptRoot -ChildPath "Remove-DuplicateFiles.ps1"
            if (Test-Path -LiteralPath $dupScript) {
                LogMessage -Message "Invoking duplicate file cleanup script..."
                & $dupScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false
                LogMessage -Message "Duplicate file cleanup completed."
            }
            else {
                LogMessage -Message "Duplicate cleanup helper not found at '$dupScript'. Skipping." -IsWarning
            }
        }
        else {
            LogMessage -Message "Skipping duplicate file cleanup."
        }

        # Post-processing: Cleanup empty folders
        if ($CleanupEmptyFolders) {
            $emptyScript = Join-Path -Path $script:ScriptRoot -ChildPath "Remove-EmptyFolders.ps1"
            if (Test-Path -LiteralPath $emptyScript) {
                LogMessage -Message "Invoking empty folder cleanup script..."
                & $emptyScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false
                LogMessage -Message "Empty folder cleanup completed."
            }
            else {
                LogMessage -Message "Empty-folder cleanup helper not found at '$emptyScript'. Skipping." -IsWarning
            }
        }
        else {
            LogMessage -Message "Skipping empty folder cleanup."
        }

        LogMessage -Message "File distribution and optional cleanup completed."

    }
    catch {
        LogMessage -Message "FATAL ERROR: $($_.Exception.Message)" -IsError -ConsoleOutput
        LogMessage -Message "Stack Trace: $($_.ScriptStackTrace)" -IsError
        throw
    }
    finally {
        if ($fileLockRef -and ($fileLockRef.PSObject.Properties.Name -contains 'Value') -and $fileLockRef.Value) {
            ReleaseFileLock -FileStream $fileLockRef.Value
        }
    }
}

# Run the script
Main
