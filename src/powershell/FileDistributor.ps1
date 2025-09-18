<#
.SYNOPSIS
The script recursively enumerates files from the source directory and ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed. 

 .VERSION
 3.0.8
 
 (Distribution update: random-balanced placement; EndOfScript deletions hardened; state-file corruption handling. See CHANGELOG.)

File name conflicts are resolved using the **RandomName** module’s `Get-RandomFileName`. After ensuring successful copying, the script handles the original files based on the specified `DeleteMode`:

- `RecycleBin`: Moves the files to the Recycle Bin.
- `Immediate`: Deletes the files immediately after successful copying.
- `EndOfScript`: Deletes the files at the end of the script if no critical errors or warnings (as configured) are encountered.

All actions are logged to a specified log file. Progress updates are displayed during processing if enabled, configurable by file count.

.PARAMETER SourceFolder
Mandatory. Specifies the path to the source folder containing the files to be copied.

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
CHANGELOG
## 3.0.8 — 2025-09-18
### Fixed
- Added missing line continuation when calling `DistributeFilesToSubfolders` during target-root redistribution.
  Without the backtick, PowerShell invoked the function with only `-Files`, then interactively prompted for
  the mandatory `-TargetRoot` (visible especially when resuming from checkpoint 3).

## 3.0.7 — 2025-09-18
### Fixed
- Progress denominator now reflects the current **phase** (source distribution, target-root redistribution, and per-overloaded-folder redistribution). The per-phase counter resets so logs like “Processed N of M” are accurate.
- Prevent copies from landing in the target **root** during source distribution. If a sanitized destination resolves to the root but subfolders exist, we re-select a real subfolder (least-filled) and log a warning once.

## 3.0.6 — 2025-09-18
### Fixed
- Crash on fresh runs: avoid overwriting `[ref]` holders (e.g., `$FilesToDelete`) with plain arrays; instead, only assign to their `.Value`. This prevents "The property 'Value' cannot be found..." errors.
- Added a small helper `New-Ref` to create stable `[ref]` containers.
- Missing line continuation in a `DistributeFilesToSubfolders` call that could mis-parse parameters.

## 3.0.5 — 2025-09-18
### Fixed
- **Relative destinations like `D\file.jpg`:** Added a normalization guard so any subfolder string that is not an absolute path (or looks like a bare drive letter such as `D` or `D:`) is remapped to the absolute `-TargetFolder` root. This prevents `Join-Path` from producing `D\file` which PowerShell resolves as a relative path (e.g., `C:\Users\<user>\D\file`).
- **Hardening:** `DistributeFilesToSubfolders` now receives the target root and ensures the chosen destination folder is rooted and exists before copying.

## 3.0.4 — 2025-09-18
### Fixed
- **Destination path collapsing to drive letter (`D\file`)**: Prevent implicit string-casting of `DirectoryInfo` values that could shrink paths to a single-letter drive designator. `DistributeFilesToSubfolders` and `RedistributeFilesInTarget` now accept object arrays and normalize each entry to `.FullName`. `CreateRandomSubfolders` now returns `DirectoryInfo` objects (not strings) so absolute paths are preserved end-to-end.
- **Hardening**: Added consistent path normalization when building internal subfolder lists.

## 3.0.3 — 2025-09-18
### Fixed
- **Invoke-WithRetry call typo:** Added missing line-continuation (`` ` ``) after `-MaxBackoff $MaxBackoff` in `Copy-ItemWithRetry` which caused `The term '-RetryDelay' is not recognized...` when the next line was parsed as a new command.
- **Fresh-run state lock:** Pass `-RetryCount $RetryCount` when calling `AcquireFileLock` after deleting a stale state file for consistency with other call sites.

## 3.0.2 — 2025-09-17
### Fixed
- **Split-Path param set error:** Replaced `Split-Path -LiteralPath ... -Parent` with a compatible call to avoid `Parameter set cannot be resolved...` in PowerShell 5.1.
- **State lock reacquire:** Corrected variable name inside `LoadState` and ensured `-RetryCount` is passed when (re)acquiring the file lock.
- **Lock acquire in fresh-run path:** Now passes `-RetryCount` when acquiring the initial state lock.

## 3.0.1 — 2025-09-17
### Fixed
- **Log/state path normalization:** If `-LogFilePath` or `-StateFilePath` points to an **existing directory**, the script now
  creates/uses `FileDistributor-log.txt` or `FileDistributor-State.json` **inside that directory** automatically.
- **Auto-create:** The log directory and file are created before first write to avoid "path is a directory" errors.
- **Docs:** Parameter docs updated to clarify directory inputs are accepted for both paths.

## 3.0.0 — 2025-09-14
### Changed (⚠️ Breaking)
- **Random name provider is now module-only:** the legacy `randomname.ps1` script is no longer supported.
- Removed the `-RandomNameScriptPath` parameter.
- The script now imports **RandomName** via: `-RandomNameModulePath` → script-root `powershell\module\RandomName\RandomName.psd1/.psm1` → `Import-Module RandomName` from `$env:PSModulePath`.
### Added
- `-RandomNameModulePath` parameter to explicitly point to the RandomName module.

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

param(
    [string]$SourceFolder = $null,
    [string]$TargetFolder = $null,
    [int]$FilesPerFolderLimit = 20000,
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
    [switch]$Help
)

# Display help and exit if -Help is specified
if ($Help) {
    Write-Host "FileDistributor.ps1 - File Distribution Script" -ForegroundColor Cyan
    Write-Host "`nSYNOPSIS" -ForegroundColor Yellow
    Write-Host "This PowerShell script copies files from a source folder to a target folder, distributing them across subfolders while maintaining a maximum file count per subfolder. It supports configurable deletion modes, progress updates, and automatic conflict resolution for file names." -ForegroundColor White

    Write-Host "`nDESCRIPTION" -ForegroundColor Yellow
    Write-Host "The script recursively enumerates files from the source directory and ensures they are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed." -ForegroundColor White

    Write-Host "`nPARAMETERS" -ForegroundColor Yellow
    Write-Host "- SourceFolder:" -ForegroundColor Green
    Write-Host "  Mandatory. Specifies the path to the source folder containing the files to be copied." -ForegroundColor White
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
$script:Warnings = 0
$script:Errors = 0
$script:SessionId = $null

# ===== Windows path resolution helpers (executed before any logging) =====
# Determine script root (works in PS 5.1+ when running as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

Function New-Ref {
    param($Initial = $null)
    # Create a stable [ref] container and assign its initial value safely
    $r = [ref]$null
    $r.Value = $Initial
    return $r
}

function New-Directory {
    param([Parameter(Mandatory=$true)][string]$DirectoryPath)
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null } catch { }
    }
    return (Test-Path -LiteralPath $DirectoryPath)
}

function Resolve-PathWithFallback {
    param(
        [string]$UserPath,
        [Parameter(Mandatory=$true)][string]$ScriptRelativePath,
        [Parameter(Mandatory=$true)][string]$WindowsDefaultPath,
        [Parameter(Mandatory=$true)][string]$TempFallbackPath
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
        [Parameter(Mandatory=$true)][ref]$Path,
        [Parameter(Mandatory=$true)][string]$DefaultFileName
    )
    $p = $Path.Value
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    try {
        if (Test-Path -LiteralPath $p -PathType Container) {
            $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
            return
        }
    } catch { }
    # If it doesn't exist but clearly looks like a directory (trailing slash), treat as directory
    if ($p -match '[\\/]\s*$') {
        $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
        return
    }
}

# Ensure the parent directory exists; optionally "touch" the file so that subsequent Add-Content works.
function Initialize-FilePath {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
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
        [switch]$ConsoleOutput,  # Explicit control for always printing to the console
        [switch]$IsError,        # Indicates if the message is an error
        [switch]$IsWarning       # Indicates if the message is a warning
    )
    # Get the timestamp and format the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$($timestamp): $($Message)"

    # Append the log entry to the log file
    $logEntry | Add-Content -Path $LogFilePath

    # Use appropriate PowerShell cmdlet for errors, warnings, or console output
    if ($IsError) {
        Write-Error -Message $logEntry
        $script:Errors++
    } elseif ($IsWarning) {
        Write-Warning -Message $logEntry
        $script:Warnings++
    } elseif ($ConsoleOutput -or $VerbosePreference -eq 'Continue') {
        Write-Host -Object $logEntry
    }
}

# General-purpose retry helper with exponential backoff
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)][ScriptBlock]$Operation,
        [Parameter(Mandatory=$true)][string]$Description,
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
        } catch {
            $attempt++
            $err = $_.Exception.Message
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
        [Parameter(Mandatory=$true)][string]$Condition, # "NoWarnings" | "WarningsOnly"
        [int]$Warnings = 0,
        [int]$Errors = 0
    )
    switch ($Condition) {
        "NoWarnings"  { return ($Warnings -eq 0 -and $Errors -eq 0) }
        "WarningsOnly"{ return ($Errors -eq 0) }
        default {
            LogMessage -Message "Unknown EndOfScriptDeletionCondition '$Condition'. Failing closed." -IsWarning
            return $false
        }
    }
}

# --- Helpers for robust state-file handling ---
function ConvertTo-Hashtable {
    param([Parameter(Mandatory=$true)]$Object)
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
        foreach ($i in $Object) { $list += ,(ConvertTo-Hashtable -Object $i) }
        return $list
    }
    return $Object
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $h = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
        return $h.Hash.ToUpperInvariant()
    } catch {
        LogMessage -Message "Failed to compute SHA256 for '$Path': $($_.Exception.Message)" -IsWarning
        return $null
    }
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory=$true)][hashtable]$StateObject,
        [Parameter(Mandatory=$true)][string]$Path
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
    } catch {
        LogMessage -Message "Atomic move for state file failed: $($_.Exception.Message)" -IsError
        throw
    }
    if ($hash) {
        try { Set-Content -LiteralPath $sha -Value $hash -Encoding ASCII } catch { LogMessage -Message "Failed to write state sidecar '$sha': $($_.Exception.Message)" -IsWarning }
    }
}

function Get-StateFromPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $sha = "$Path.sha256"
    # Verify sidecar hash if present
    if (Test-Path -LiteralPath $sha) {
        $expected = (Get-Content -LiteralPath $sha -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        $actual   = Get-FileSha256Hex -Path $Path
        if ($expected -and $actual -and ($expected -ne $actual)) {
            LogMessage -Message "Checksum mismatch for '$Path' (expected $expected, got $actual). Treating as corrupt." -IsWarning
            return $null
        }
    }
    # Read and parse JSON safely
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $ht  = ConvertTo-Hashtable -Object $obj
        return $ht
    } catch {
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
$defaultLog_Windows   = Join-Path -Path (Join-Path $localAppData 'FileDistributor\logs') -ChildPath 'FileDistributor-log.txt'
$defaultLog_Temp      = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\logs') -ChildPath 'FileDistributor-log.txt'
$defaultLog_ScriptRel = 'logs\FileDistributor-log.txt'

$defaultState_Windows   = Join-Path -Path (Join-Path $localAppData 'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
$defaultState_Temp      = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
$defaultState_ScriptRel = 'state\FileDistributor-State.json'

# If parameters are currently unset, they'll be $null; compute effective values
$script:LogFilePath  = Resolve-PathWithFallback -UserPath $LogFilePath `
    -ScriptRelativePath $defaultLog_ScriptRel -WindowsDefaultPath $defaultLog_Windows -TempFallbackPath $defaultLog_Temp
$script:StateFilePath = Resolve-PathWithFallback -UserPath $StateFilePath `
    -ScriptRelativePath $defaultState_ScriptRel -WindowsDefaultPath $defaultState_Windows -TempFallbackPath $defaultState_Temp

# If user passed a directory for either path, coerce to default filename within that directory
Resolve-FilePathIfDirectory -Path ([ref]$script:LogFilePath)   -DefaultFileName 'FileDistributor-log.txt'
Resolve-FilePathIfDirectory -Path ([ref]$script:StateFilePath) -DefaultFileName 'FileDistributor-State.json'

# From here on, use the resolved script-scoped variables
$LogFilePath   = $script:LogFilePath
$StateFilePath = $script:StateFilePath

# Ensure log directory exists and create the file so Add-Content always succeeds
Initialize-FilePath -FilePath $LogFilePath -CreateFile
# Ensure state directory exists early (file may be created later by locking/atomic write)
Initialize-FilePath -FilePath $StateFilePath
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
        } catch {
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
            } catch {
                LogMessage -Message "Failed to import RandomName module from '$c': $($_.Exception.Message)" -IsWarning
            }
        }
    }

    # 3) PSModulePath
    try {
        Import-Module -Name RandomName -ErrorAction Stop
        LogMessage -Message "Imported RandomName module from PSModulePath."
        return
    } catch {
        LogMessage -Message "Failed to import 'RandomName' from PSModulePath: $($_.Exception.Message)" -IsError
        throw "Random name provider (module) not found."
    }
}

# I/O wrappers
function Copy-ItemWithRetry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Destination,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    Invoke-WithRetry -Operation { Copy-Item -Path $Path -Destination $Destination -Force -ErrorAction Stop } `
                     -Description "Copy '$Path' -> '$Destination'" -MaxBackoff $MaxBackoff `
                     -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Remove-ItemWithRetry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )
    Invoke-WithRetry -Operation { Remove-Item -Path $Path -Force -ErrorAction Stop } `
                     -Description "Delete '$Path'" -MaxBackoff $MaxBackoff `
                     -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Rename-ItemWithRetry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$NewName,
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
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$TargetRoot
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $TargetRoot }
    # Bare drive letter or drive designator should not be used as a destination folder
    if ($Path -match '^[A-Za-z]$' -or $Path -match '^[A-Za-z]:$') { return $TargetRoot }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    # Anything else that's relative: anchor it under TargetRoot
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
    } catch {
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
        } else {
            LogMessage -Message "File $FilePath not found. Skipping deletion." -IsWarning
        }
    } catch {
        # Log failure
        LogMessage -Message "Failed to delete file $FilePath. Error: $($_.Exception.Message)" -IsWarning
    }
}

function DistributeFilesToSubfolders {
    param (
        [string[]]$Files,
        [object[]]$Subfolders,
        [Parameter(Mandatory=$true)][string]$TargetRoot,
        [int]$Limit,
        [switch]$ShowProgress,        # Enable/disable progress updates
        [int]$UpdateFrequency,       # Frequency for progress updates
        [string]$DeleteMode,         # Specifies the deletion mode
        [ref]$FilesToDelete,         # Reference to the files pending deletion
        [ref]$GlobalFileCounter,     # Reference to a global file counter
        [int]$TotalFiles             # Total number of files to process
    )

    # Normalize subfolder inputs to full path strings and seed counts for balance tracking
    $subfolderPaths = @()
    $folderCounts = @{}
    foreach ($sf in $Subfolders) {
        $sfPath = if ($sf -is [System.IO.FileSystemInfo]) { $sf.FullName } else { [string]$sf }
        # Force absolute, rooted paths under TargetRoot (guards against 'D'/'D:'/relative)
        $sfPath = Resolve-SubfolderPath -Path $sfPath -TargetRoot $TargetRoot
        if (-not [string]::IsNullOrWhiteSpace($sfPath)) {
            $subfolderPaths += $sfPath
            try {
                $folderCounts[$sfPath] = (Get-ChildItem -Path $sfPath -File | Measure-Object).Count
            } catch {
                $folderCounts[$sfPath] = 0
                LogMessage -Message "Failed to count files in subfolder '$sfPath'. Defaulting count to 0. Error: $($_.Exception.Message)" -IsWarning
            }
        }
    }
    if ($subfolderPaths.Count -eq 0) {
        LogMessage -Message "No subfolders provided to DistributeFilesToSubfolders. Aborting distribution for this batch." -IsError
        return
    }

    # Randomize processing order of files to reduce bias
    $filesToProcess = $Files
    try {
        if ($Files.Count -gt 1) {
            $filesToProcess = $Files | Get-Random -Count $Files.Count
        }
    } catch {
        $filesToProcess = $Files
        LogMessage -Message "Could not shuffle file list due to: $($_.Exception.Message). Proceeding without shuffle." -IsWarning
    }

    foreach ($file in $filesToProcess) {
        # Resolve file path and name safely (supports FileInfo or string path)
        $filePath = if ($file -is [System.IO.FileSystemInfo]) { $file.FullName } else { [string]$file }
        $originalName = if ($file -is [System.IO.FileSystemInfo]) { $file.Name } else { [System.IO.Path]::GetFileName($filePath) }

        # Build eligible target list (under limit), bias toward least-filled
        $eligible = @()
        foreach ($p in $subfolderPaths) {
            if ($folderCounts[$p] -lt $Limit) { $eligible += $p }
        }
        if ($eligible.Count -eq 0) {
            # Best-effort fallback if all at/over limit
            $eligible = $subfolderPaths
            LogMessage -Message "All subfolders appear at/over limit ($Limit). Selecting among all subfolders (best effort)." -IsWarning
        }
        $minCount = ($eligible | ForEach-Object { $folderCounts[$_] } | Measure-Object -Minimum).Minimum
        $candidates = $eligible | Where-Object { $folderCounts[$_] -eq $minCount }
        $destinationFolder = if ($candidates.Count -gt 1) { $candidates | Get-Random } else { $candidates[0] }
        # Sanitize/anchor destination in case anything slipped through
        $destinationFolder = Resolve-SubfolderPath -Path $destinationFolder -TargetRoot $TargetRoot
        if ($destinationFolder -match '^[A-Za-z]$' -or $destinationFolder -match '^[A-Za-z]:$' -or -not [System.IO.Path]::IsPathRooted($destinationFolder)) {
            LogMessage -Message "Sanitizing non-rooted destination folder '$destinationFolder' -> '$TargetRoot'." -IsWarning
            $destinationFolder = $TargetRoot
        }
        # Hard guard: if we somehow ended up at the target root but we have subfolders, force a subfolder pick.
        if ($destinationFolder -ieq $TargetRoot) {
            $subOnly = $subfolderPaths | Where-Object { $_ -ne $TargetRoot }
            if ($subOnly.Count -gt 0) {
                $min2 = ($subOnly | ForEach-Object { $folderCounts[$_] } | Measure-Object -Minimum).Minimum
                $cand2 = $subOnly | Where-Object { $folderCounts[$_] -eq $min2 }
                $destinationFolder = if ($cand2.Count -gt 1) { $cand2 | Get-Random } else { $cand2[0] }
                LogMessage -Message "Destination normalized away from target root; using subfolder '$destinationFolder'." -IsWarning
            }
        }
        if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
            try {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                LogMessage -Message "Created missing destination folder: $destinationFolder"
            } catch {
                LogMessage -Message "Failed to ensure destination folder '$destinationFolder': $($_.Exception.Message)" -IsError
                continue
            }
        }

        # Always generate a randomized destination name (preserve extension)
        $newFileName = ResolveFileNameConflict -TargetFolder $destinationFolder -OriginalFileName $originalName
 
        # Build the final destination path
        $destinationFile = Join-Path -Path $destinationFolder -ChildPath $newFileName
        
        # (Optional) Log the rename intent for traceability
        LogMessage -Message "Assigning randomized destination name for '$filePath' -> '$destinationFile'."

        # Copy with retries and stop-on-error semantics
        Copy-ItemWithRetry -Path $filePath -Destination $destinationFile -RetryDelay $RetryDelay -RetryCount $RetryCount

        # Verify the file was copied successfully
        if (Test-Path -Path $destinationFile) {
            # Update in-memory count for balance tracking
            if ($folderCounts.ContainsKey($destinationFolder)) {
                $folderCounts[$destinationFolder]++
            } else {
                $folderCounts[$destinationFolder] = 1
            }
            try {
                # Handle file deletion based on DeleteMode
                if ($DeleteMode -eq "RecycleBin") {
                    Move-ToRecycleBin -FilePath $filePath
                    LogMessage -Message "Copied from $file to $destinationFile and moved original to Recycle Bin."
                } elseif ($DeleteMode -eq "Immediate") {
                    Remove-File -FilePath $filePath
                    LogMessage -Message "Copied from $file to $destinationFile and immediately deleted original."
                } elseif ($DeleteMode -eq "EndOfScript") {
                    # Ensure FilesToDelete.Value is initialized as an array
                    if (-not $FilesToDelete.Value) {
                        $FilesToDelete.Value = @()
                    }
                    # Gather metadata for safe deletion across restarts
                    $queuedSize = $null; $queuedMtimeUtc = $null
                    try {
                        $finfo = Get-Item -LiteralPath $filePath -ErrorAction Stop
                        $queuedSize = $finfo.Length
                        $queuedMtimeUtc = $finfo.LastWriteTimeUtc
                    } catch { }
                    $FilesToDelete.Value += [pscustomobject]@{
                        Path = $filePath
                        Size = $queuedSize
                        LastWriteTimeUtc = $queuedMtimeUtc
                        QueuedAtUtc = (Get-Date).ToUniversalTime()
                        SessionId = $script:SessionId
                    }
                    LogMessage -Message "Copied from $file to $destinationFile. Original pending deletion at end of script."
                }
            } catch {
                LogMessage -Message "Failed to process file $file after copying to $destinationFile. Error: $($_.Exception.Message)" -IsWarning
            }
        } else {
            LogMessage -Message "Failed to copy $file to $destinationFile. Original file not moved." -IsError
        }

        # Increment the global file counter
        $GlobalFileCounter.Value++

        # Show progress if enabled and only after every $UpdateFrequency files
        if ($ShowProgress -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($GlobalFileCounter.Value / $TotalFiles) * 100)
            Write-Progress -Activity "Distributing Files" `
                           -Status "Processed $($GlobalFileCounter.Value) of $TotalFiles files" `
                           -PercentComplete $percentComplete
            LogMessage -Message "Processed $($GlobalFileCounter.Value) of $TotalFiles files." -ConsoleOutput
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Distributing Files" -Status "Complete" -Completed
    }
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
        [ref]$FilesToDelete,
        [ref]$GlobalFileCounter,
        [int]$TotalFiles
    )

    # Step 1: Build initial folder file count map from normalized full paths
    $folderFilesMap = @{}
    $normalizedSubfolders = @()
    foreach ($sf in $Subfolders) {
        $sfPath = if ($sf -is [System.IO.FileSystemInfo]) { $sf.FullName } else { [string]$sf }
        $sfPath = Resolve-SubfolderPath -Path $sfPath -TargetRoot $TargetFolder
        if (-not [string]::IsNullOrWhiteSpace($sfPath)) {
            $normalizedSubfolders += $sfPath
            try {
                $folderFilesMap[$sfPath] = (Get-ChildItem -Path $sfPath -File).Count
            } catch {
                $folderFilesMap[$sfPath] = 0
                LogMessage -Message "Failed to count files in subfolder '$sfPath'. Defaulting count to 0. Error: $($_.Exception.Message)" -IsWarning
            }
        }
    }

    # Step 2: Redistribute files from root of target folder (not subfolders)
    LogMessage -Message "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -Path $TargetFolder -File
    $redistributionTotal = 0
    $redistributionProcessed = 0

    if ($rootFiles.Count -gt 0) {
        $eligibleTargets = $folderFilesMap.GetEnumerator() |
            Where-Object { $_.Value -lt $FilesPerFolderLimit } |
            ForEach-Object { $_.Key }

        if ($eligibleTargets.Count -eq 0) {
            # Create a new subfolder using Get-RandomFileName
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            LogMessage -Message "Created new target subfolder: $newFolder for redistribution from root folder."

            # Update maps
            $eligibleTargets = @($newFolder)
            $Subfolders += (Get-Item -LiteralPath $newFolder)
            $folderFilesMap[$newFolder] = 0
        }

        # Reset phase counter and compute correct denominator
        $GlobalFileCounter.Value = 0
        $redistributionTotal += $rootFiles.Count
        DistributeFilesToSubfolders -Files $rootFiles `
            -Subfolders $eligibleTargets `
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
                $_.Key -ne $sourceFolder -and $_.Value -lt $FilesPerFolderLimit
            } |
            ForEach-Object { $_.Key }

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
    $errorsSoFar   = $script:Errors

    # Release the file lock before saving state
    ReleaseFileLock -FileStream $fileLock.Value

    # Ensure the state file exists
    if (-not (Test-Path -Path $StateFilePath)) {
        New-Item -Path $StateFilePath -ItemType File -Force | Out-Null
        LogMessage -Message "State file created at $StateFilePath"
    }

    # Combine state information
    $state = @{
        Checkpoint = $Checkpoint
        SessionId  = $script:SessionId
        WarningsSoFar = $warningsSoFar
        ErrorsSoFar   = $errorsSoFar
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
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
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
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
    $backup  = "$StateFilePath.bak"

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
                } else {
                    $rehash = Get-FileSha256Hex -Path $primary
                    if ($rehash) { Set-Content -LiteralPath $priHashPath -Value $rehash -Encoding ASCII }
                }
                LogMessage -Message "Recovered state from backup '$backup'."
            } catch {
                LogMessage -Message "Failed to restore state from backup '$backup': $($_.Exception.Message)" -IsWarning
            }
            $state = $stateBak
        } elseif (Test-Path -LiteralPath $primary) {
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
            } catch {
                LogMessage -Message "Failed to quarantine corrupt state file '$primary': $($_.Exception.Message)" -IsWarning
            }
        }
    }

    # Fallback to default state if still not available
    if (-not $state) { $state = @{ Checkpoint = 0 } }

    # Reacquire the file lock after loading state
    $fileLock.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount

    return $state
}

# Function to extract paths from items
function ConvertItemsToPaths {
    param (
        [array]$Items
    )

    # Return the array of item full paths
    return $Items.FullName
}

# Function to convert paths to items
function ConvertPathsToItems {
    param (
        [array]$Paths
    )

    # Use pipeline to retrieve items for all paths and return them as an array
    return $Paths | ForEach-Object { Get-Item -Path $_ }
}

# Function to acquire a lock on the state file
function AcquireFileLock {
    param (
        [string]$FilePath,
        [int]$RetryDelay,
        [int]$RetryCount
    )

    $attempts = 0
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($FilePath, 'OpenOrCreate', 'ReadWrite', 'None')
            LogMessage -Message "Acquired lock on $FilePath"
            return $fileStream
        } catch {
            $attempts++
            if ($RetryCount -ne 0 -and $attempts -ge $RetryCount) {
                LogMessage -Message "Failed to acquire lock on $FilePath after $attempts attempts. Aborting." -IsError
                throw "Failed to acquire lock on $FilePath after $attempts attempts."
            }
            LogMessage -Message "Failed to acquire lock on $FilePath. Retrying in $RetryDelay seconds... (Attempt $attempts)" -IsWarning
            Start-Sleep -Seconds $RetryDelay
        }
    }
}

# Function to release the file lock
function ReleaseFileLock {
    param (
        [System.IO.FileStream]$FileStream
    )

    $fileName = $FileStream.Name
    $FileStream.Close()
    $FileStream.Dispose()
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
    } else {
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
                } elseif ($OlderThanDays -and $entryTimestamp -ge (Get-Date).AddDays(-$OlderThanDays)) {
                    $filteredEntries += $entry
                }
            } else {
                # Preserve entries without a valid timestamp
                $filteredEntries += $entry
            }
        }

        # Overwrite the log file with filtered entries
        $filteredEntries | Set-Content -Path $LogFilePath
        LogMessage -Message "Log entries filtered successfully. Updated log file: $LogFilePath"
    } catch {
        LogMessage -Message "Failed to filter log entries: $($_.Exception.Message)" -IsError
    }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput
    Import-RandomNameProvider -ModulePath $RandomNameModulePath

    # Track prior counters from any persisted state for cross-restart safety
    $priorWarnings = 0; $priorErrors = 0
    # Handle log entry removal
    if (-not $Restart) {
        $beforeTimestamp = $null
        if ($RemoveEntriesBefore) {
            try {
                $beforeTimestamp = [datetime]::Parse($RemoveEntriesBefore)
            } catch {
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
            } catch {
                LogMessage -Message "Failed to evaluate or truncate log file based on size: $($_.Exception.Message)" -IsError
            }
        } elseif ($TruncateLog) {
            try {
                Clear-Content -Path $LogFilePath -Force
                LogMessage -Message "Log file truncated: $LogFilePath"
            } catch {
                LogMessage -Message "Failed to truncate log file: $($_.Exception.Message)" -IsError
            }
        }
    }

    LogMessage -Message "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilePerFolderLimit - $FilesPerFolderLimit"

    try {
        # Ensure source and target folders exist
        if (-not $script:SessionId) { $script:SessionId = [guid]::NewGuid().ToString() }

        # Require SourceFolder/TargetFolder explicitly (removed user-specific defaults)
        if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
            LogMessage -Message "SourceFolder not specified. Provide -SourceFolder with a valid path." -IsError
            throw "Missing required parameter: -SourceFolder"
        }
        if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
            LogMessage -Message "TargetFolder not specified. Provide -TargetFolder with a valid path." -IsError
            throw "Missing required parameter: -TargetFolder"
        }

        if (!(Test-Path -Path $SourceFolder)) {
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

        if (-not ("NoWarnings", "WarningsOnly" -contains $EndOfScriptDeletionCondition)) {
            LogMessage -Message "Invalid value for EndOfScriptDeletionCondition: $EndOfScriptDeletionCondition. Valid options are 'NoWarnings', 'WarningsOnly'." -IsError
            exit 1
        }

        LogMessage -Message "Parameter validation completed"

        # Initialize stable [ref] holders (do not overwrite these variables later, only set .Value)
        $FilesToDelete = New-Ref @()     # queue for EndOfScript deletions
        $GlobalFileCounter = New-Ref 0   # running count

        $fileLockRef = [ref]$null

        try {
            # Restart logic
            $lastCheckpoint = 0
            if ($Restart) {
                # Acquire a lock on the state file
                $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount

                LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput
                $state = LoadState -fileLock $fileLockRef
                $lastCheckpoint = $state.Checkpoint
                if ($lastCheckpoint -gt 0) {
                    # Restore session id (or create if missing for legacy states)
                    if ($state.PSObject.Properties.Name -contains 'SessionId' -and $state.SessionId) {
                        $script:SessionId = [string]$state.SessionId
                    } else {
                        $script:SessionId = [guid]::NewGuid().ToString()
                        LogMessage -Message "Legacy state without SessionId; generated new SessionId for this resume." -IsWarning
                    }
                    # Capture prior counters to aggregate with current run
                    if ($state.PSObject.Properties.Name -contains 'WarningsSoFar') { $priorWarnings = [int]$state.WarningsSoFar }
                    if ($state.PSObject.Properties.Name -contains 'ErrorsSoFar')   { $priorErrors   = [int]$state.ErrorsSoFar } 
                    LogMessage -Message "Restarting from checkpoint $lastCheckpoint" -ConsoleOutput
                } else {
                    LogMessage -Message "Checkpoint not found. Executing from top..." -IsWarning
                }

                # Restore SourceFolder
                if ($state.ContainsKey("SourceFolder")) {
                    $savedSourceFolder = $state.SourceFolder

                    # Validate the loaded SourceFolder
                    if ($SourceFolder -ne $savedSourceFolder) {
                        throw "SourceFolder mismatch: Restarted script must use the saved SourceFolder ('$savedSourceFolder'). Aborting."
                    }
                    $SourceFolder = $savedSourceFolder
                    LogMessage -Message "SourceFolder restored from state file: $SourceFolder"
                } else {
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
                } else {
                    throw "State file does not contain DeleteMode. Unable to enforce."
                }

                # Load checkpoint-specific additional variables
                if ($lastCheckpoint -in 2, 3, 4) {
                    $totalSourceFiles = $state.totalSourceFiles
                    $totalTargetFilesBefore = $state.totalTargetFilesBefore
                }

                if ($lastCheckpoint -in 2, 3) {
                    $subfolders = ConvertPathsToItems($state.subfolders)
                }

                if ($lastCheckpoint -eq 2) {
                    $sourceFiles = ConvertPathsToItems($state.sourceFiles)
                }

                # Load FilesToDelete only for EndOfScript mode and lastCheckpoint 3 or 4
                if ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4 -and $state.ContainsKey("FilesToDelete")) {
                    $loadedQueue = $state.FilesToDelete
                    # Normalize to object entries and wrap in [ref]
                    $normalized = @()
                    foreach ($e in $loadedQueue) {
                        if ($e -is [string]) {
                            $normalized += [pscustomobject]@{
                                Path = $e; Size = $null; LastWriteTimeUtc = $null; QueuedAtUtc = $null; SessionId = $script:SessionId
                            }
                        } else {
                            $normalized += $e
                        }
                    }
                    $FilesToDelete.Value = $normalized

                    if (-not $FilesToDelete.Value -or $FilesToDelete.Value.Count -eq 0) {
                        Write-Output "No files to delete from the previous session."
                    } else {
                        Write-Output "Loaded $($FilesToDelete.Value.Count) files to delete from the previous session."
                    }
                } elseif ($DeleteMode -eq "EndOfScript" -and $lastCheckpoint -in 3, 4) {
                    # If DeleteMode is EndOfScript but no FilesToDelete key exists
                    LogMessage -Message "State file does not contain FilesToDelete key for EndOfScript mode." -IsWarning
                    $FilesToDelete.Value = @() # Re-initialize queue (do not replace the [ref] holder)
                } else {
                    # Default initialisation when EndOfScript mode does not apply
                    $FilesToDelete.Value = @() # Ensure FilesToDelete is always defined without replacing [ref]
                }
            } else {

                # Check if a restart state file exists
                if (Test-Path -Path $StateFilePath) {
                  
                    LogMessage -Message "Restart state file found but restart not requested. Deleting state file..." -IsWarning

                    try {
                        Remove-Item -Path $StateFilePath -Force
                        LogMessage -Message "State file $StateFilePath deleted."
                    } catch {
                        LogMessage -Message "Failed to delete state file $StateFilePath. Error: $_" -IsError
                        throw "An error occurred while deleting the state file: $($_.Exception.Message)"
                    }  
                }
                # Acquire the file lock after deleting the file
                 $fileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
            }
        } catch {
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
            # Count files in the source and target folder before distribution
            $sourceFiles = Get-ChildItem -Path $SourceFolder -Recurse -File
            $totalSourceFiles = $sourceFiles.Count
            $totalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
            $totalTargetFilesBefore = if ($null -eq $totalTargetFilesBefore) { 0 } else { $totalTargetFilesBefore }
            $totalFiles = $totalSourceFiles + $totalTargetFilesBefore # Correctly calculate total files
            LogMessage -Message "Source File Count: $totalSourceFiles. Target File Count Before: $totalTargetFilesBefore."

            # Get subfolders in the target folder
            $subfolders = Get-ChildItem -Path $TargetFolder -Directory

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
                sourceFiles = ConvertItemsToPaths($sourceFiles)
                totalSourceFiles = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders = ConvertItemsToPaths($subfolders)
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }

            SaveState -Checkpoint 2 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }

        if ($lastCheckpoint -lt 3) {
            # Distribute files from the source folder to subfolders
            LogMessage -Message "Distributing files to subfolders..."
            # Reset phase counter and use per-phase total (sources only)
            $GlobalFileCounter.Value = 0
            DistributeFilesToSubfolders -Files $sourceFiles -Subfolders $subfolders -TargetRoot $TargetFolder -Limit $FilesPerFolderLimit `
                                        -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency `
                                        -DeleteMode $DeleteMode -FilesToDelete $FilesToDelete `
                                        -GlobalFileCounter $GlobalFileCounter -TotalFiles $totalSourceFiles
            LogMessage -Message "Completed file distribution"

            # Common base for additional variables
            $additionalVars = @{
                totalSourceFiles      = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                subfolders            = ConvertItemsToPaths($subfolders)
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }

            # Conditionally add FilesToDelete for EndOfScript mode
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = $FilesToDelete.Value
            }

            # Save the state with the consolidated additional variables
            SaveState -Checkpoint 3 -AdditionalVariables $additionalVars -fileLock $fileLockRef

        }

        if ($lastCheckpoint -lt 4) {
            # Redistribute files within the target folder and subfolders if needed
            LogMessage -Message "Redistributing files in target folders..."
            RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $subfolders `
                                      -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress `
                                      -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode `
                                      -FilesToDelete $FilesToDelete -GlobalFileCounter $GlobalFileCounter `
                                      -TotalFiles 0 # Not used now; function computes its own totals
        
            # Base additional variables
            $additionalVars = @{
                totalSourceFiles      = $totalSourceFiles
                totalTargetFilesBefore = $totalTargetFilesBefore
                deleteMode            = $DeleteMode # Persist DeleteMode
                SourceFolder          = $SourceFolder # Persist SourceFolder
            }
        
            # Conditionally add FilesToDelete if DeleteMode is EndOfScript
            if ($DeleteMode -eq "EndOfScript") {
                $additionalVars["FilesToDelete"] = $FilesToDelete.Value
            }
        
            # Save state with checkpoint 4 and additional variables
            SaveState -Checkpoint 4 -AdditionalVariables $additionalVars -fileLock $fileLockRef
        }        

        if ($DeleteMode -eq "EndOfScript") {
            # Use aggregated counters across restarts for safe evaluation
            $effectiveWarnings = [Math]::Max($Warnings, $priorWarnings)
            $effectiveErrors   = [Math]::Max($Errors,   $priorErrors)

            if (Test-EndOfScriptCondition -Condition $EndOfScriptDeletionCondition -Warnings $effectiveWarnings -Errors $effectiveErrors) {
                
                # Attempt to delete each queued entry (same-session only)
                foreach ($entry in $FilesToDelete.Value) {
                    $entryPath = $null; $entrySession = $null; $entrySize = $null; $entryMtimeUtc = $null
                    if ($entry -is [string]) {
                        # Legacy entry (should only happen if not normalized); treat conservatively
                        $entryPath = $entry
                        $entrySession = $script:SessionId
                    } else {
                        $entryPath   = $entry.Path
                        $entrySession= $entry.SessionId
                        $entrySize   = $entry.Size
                        $entryMtimeUtc = $entry.LastWriteTimeUtc
                    }

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
                            } catch {
                                LogMessage -Message "Could not stat '$entryPath' prior to deletion: $($_.Exception.Message)" -IsWarning
                            }

                            if ($okToDelete) {
                                Remove-File -FilePath $entryPath
                                LogMessage -Message "Deleted file: $entryPath during EndOfScript cleanup."
                            } else {
                                LogMessage -Message "Skipped deletion for '$entryPath' due to metadata mismatch (size/time changed)." -IsWarning
                            }
                        } else {
                            LogMessage -Message "File $entryPath not found during EndOfScript deletion." -IsWarning
                        }
                    } catch {
                        # Log a warning for failure to delete
                        LogMessage -Message "Failed to delete file $entryPath. Error: $($_.Exception.Message)" -IsWarning
                    }
                }
            } else {
                # Log a message if conditions are not met
                LogMessage -Message "End-of-script deletion skipped due to warnings or errors."
            }
        }        

        # Count files in the target folder after distribution
        $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
        $totalTargetFilesAfter = if ($null -eq $totalTargetFilesAfter) { 0 } else { $totalTargetFilesAfter }

        # Log summary message
        LogMessage -Message "Original number of files in the source folder: $totalSourceFiles" -ConsoleOutput
        LogMessage -Message "Original number of files in the target folder hierarchy: $totalTargetFilesBefore" -ConsoleOutput
        LogMessage -Message "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput

        if ($totalSourceFiles + $totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage -Message "Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -IsWarning
        } else {
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
            } else {
                LogMessage -Message "Duplicate cleanup helper not found at '$dupScript'. Skipping." -IsWarning
            }
        } else {
            LogMessage -Message "Skipping duplicate file cleanup."
        }

        # Post-processing: Cleanup empty folders
        if ($CleanupEmptyFolders) {
            $emptyScript = Join-Path -Path $script:ScriptRoot -ChildPath "Remove-EmptyFolders.ps1"
            if (Test-Path -LiteralPath $emptyScript) {
                LogMessage -Message "Invoking empty folder cleanup script..."
                & $emptyScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false
                LogMessage -Message "Empty folder cleanup completed."
            } else {
                LogMessage -Message "Empty-folder cleanup helper not found at '$emptyScript'. Skipping." -IsWarning
            }
        } else {
            LogMessage -Message "Skipping empty folder cleanup."
        }

        LogMessage -Message "File distribution and optional cleanup completed."

    } catch {
        LogMessage -Message "$($_.Exception.Message)" -IsError
    } finally {
        if ($fileLockRef -and ($fileLockRef.PSObject.Properties.Name -contains 'Value') -and $fileLockRef.Value) {
            ReleaseFileLock -FileStream $fileLockRef.Value
        }
    }
}

# Run the script
Main
