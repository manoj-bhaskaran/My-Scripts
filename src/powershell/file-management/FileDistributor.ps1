<#
.SYNOPSIS
The script recursively enumerates files from the source directory and ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

 .VERSION
 4.6.14

 CHANGELOG:
   See CHANGELOG.md in this directory for full release history.

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
## 4.6.13 — 2026-03-27
### Changed
- Restored candidate-subfolder fallback when directory scans fail in `Get-SubfolderFileCounts`, so distribution/redistribution can continue with known candidates instead of aborting the phase.
- Full changelog: `./CHANGELOG.md`.

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
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PurgeLogs.psm1" -Force

# Import FileQueue module for queue management
Import-Module "$PSScriptRoot\..\modules\FileManagement\FileQueue\FileQueue.psd1" -Force
Import-Module "$PSScriptRoot\..\modules\FileManagement\FileDistributor\FileDistributor.psd1" -Force
. "$PSScriptRoot\..\modules\FileManagement\FileDistributor\Private\PathHelpers.ps1"

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
$script:Version = "4.6.14"
$script:Warnings = 0
$script:Errors = 0

# ===== Windows path resolution helpers (executed before any logging) =====
# Determine script root (works in PS 5.1+ when running as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

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

function Invoke-FileMove {
    param (
        [Parameter(Mandatory = $true)][string]$SourceFilePath,
        [Parameter(Mandatory = $true)][string]$OriginalFileName,
        [Parameter(Mandatory = $true)][string]$DestinationFolder,
        [Parameter(Mandatory = $true)][ref]$FolderCountRef,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [int]$TotalFiles = 0,
        [int]$RetryDelay = 5,
        [int]$RetryCount = 3,
        [string]$ProgressActivity = "Distributing Files",
        [string]$ProgressStatusTemplate = "Processed {0} of {1} files",
        [string]$CopyFailureMessageTemplate = "Failed to copy '{0}' to '{1}'.",
        [string]$PostCopyFailureMessageTemplate = "Post-copy handling failed for '{0}': {1}",
        [switch]$CopyFailureIsWarning,
        [switch]$IncrementOnSuccessOnly
    )

    $newFileName = ResolveFileNameConflict -TargetFolder $DestinationFolder -OriginalFileName $OriginalFileName
    $destinationFile = Join-Path -Path $DestinationFolder -ChildPath $newFileName

    Copy-ItemWithRetry -Path $SourceFilePath -Destination $destinationFile -RetryDelay $RetryDelay -RetryCount $RetryCount

    $copySucceeded = Test-Path -LiteralPath $destinationFile
    $queuedForEndOfScriptDeletion = $null
    if ($copySucceeded) {
        $FolderCountRef.Value++
        try {
            if ($DeleteMode -eq "RecycleBin") {
                Move-ToRecycleBin -FilePath $SourceFilePath
            }
            elseif ($DeleteMode -eq "Immediate") {
                Remove-File -FilePath $SourceFilePath
            }
            elseif ($DeleteMode -eq "EndOfScript") {
                $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $SourceFilePath -ValidateFile $false
                $queuedForEndOfScriptDeletion = [bool]$queueResult
                if (-not $queuedForEndOfScriptDeletion) {
                    LogMessage -Message "Failed to queue file for deletion: $SourceFilePath" -IsWarning
                }
            }
        }
        catch {
            if ($DeleteMode -eq "EndOfScript") {
                $queuedForEndOfScriptDeletion = $false
            }
            LogMessage -Message ($PostCopyFailureMessageTemplate -f $SourceFilePath, $_.Exception.Message) -IsWarning
        }
    }
    else {
        if ($CopyFailureIsWarning) {
            LogMessage -Message ($CopyFailureMessageTemplate -f $OriginalFileName, $destinationFile) -IsWarning
        }
        else {
            LogMessage -Message ($CopyFailureMessageTemplate -f $OriginalFileName, $destinationFile) -IsError
        }
    }

    if (-not $IncrementOnSuccessOnly -or $copySucceeded) {
        $GlobalFileCounter.Value++
    }

    if ($ShowProgress -and $TotalFiles -gt 0 -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
        $percentComplete = [math]::Floor(($GlobalFileCounter.Value / $TotalFiles) * 100)
        $status = $ProgressStatusTemplate -f $GlobalFileCounter.Value, $TotalFiles
        Write-Progress -Activity $ProgressActivity -Status $status -PercentComplete $percentComplete
    }

    return [pscustomobject]@{
        Success         = $copySucceeded
        DestinationFile = $destinationFile
        QueueQueued     = $queuedForEndOfScriptDeletion
    }
}

function Get-SubfolderFileCounts {
    param(
        [Parameter(Mandatory)][string]$TargetFolder,
        [switch]$IncludeEmpty,
        [object[]]$FallbackSubfolders
    )

    $subfolders = $null
    $scanFailed = $false
    try {
        $subfolders = @(Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction Stop)
    }
    catch {
        $scanFailed = $true
        LogMessage -Message ("Failed to enumerate subfolders under '{0}': {1}" -f $TargetFolder, $_.Exception.Message) -IsWarning
        $subfolders = @()

        if ($FallbackSubfolders -and $FallbackSubfolders.Count -gt 0) {
            LogMessage -Message "Continuing with fallback subfolder candidates after scan failure." -IsWarning
            foreach ($candidate in $FallbackSubfolders) {
                $candidatePath = if ($candidate -is [IO.FileSystemInfo]) { $candidate.FullName } else { [string]$candidate }
                if ([string]::IsNullOrWhiteSpace($candidatePath)) { continue }

                $resolved = Resolve-SubfolderPath -Path $candidatePath -TargetRoot $TargetFolder
                if (-not $resolved) { continue }
                if (-not (Test-Path -LiteralPath $resolved -PathType Container)) { continue }

                try {
                    $normalized = [IO.Path]::GetFullPath($resolved)
                    $subfolders += [pscustomobject]@{ FullName = $normalized }
                }
                catch {
                    continue
                }
            }
        }
    }

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        if ($scanFailed) {
            LogMessage -Message "No usable fallback subfolders were available after scan failure." -IsError
            return $null
        }
        return @{}
    }

    $subfolders = @($subfolders | Sort-Object FullName -Unique)

    $folderCounts = @{}
    $totalFiles = 0
    foreach ($sf in $subfolders) {
        try {
            $count = (Get-ChildItem -LiteralPath $sf.FullName -File -Force -ErrorAction Stop | Measure-Object).Count
        }
        catch {
            LogMessage -Message ("Failed to count files in subfolder '{0}': {1}" -f $sf.FullName, $_.Exception.Message) -IsWarning
            $count = 0
        }

        $totalFiles += [int]$count
        if ($IncludeEmpty -or $count -gt 0) {
            $folderCounts[$sf.FullName] = [int]$count
        }
    }

    if ($totalFiles -eq 0) {
        LogMessage -Message "No files found across target subfolders."
    }

    return $folderCounts
}

function Write-DistributionSummary {
    param(
        [Parameter(Mandatory)][hashtable]$FolderCounts,
        [Parameter(Mandatory)][double]$Average,
        [string]$Label = "CURRENT DISTRIBUTION",
        [int]$UpperBound = -1,
        [int]$LowerBound = -1
    )

    if ($Label -match '===') {
        LogMessage -Message $Label
    }
    else {
        LogMessage -Message "=== $Label ==="
    }
    foreach ($folderPath in ($FolderCounts.Keys | Sort-Object { [int]$FolderCounts[$_] } -Descending)) {
        $count = [int]$FolderCounts[$folderPath]
        $folderName = Split-Path -Leaf $folderPath
        $deviation = $count - $Average
        $deviationPct = if ($Average -gt 0) { ($deviation / $Average) * 100 } else { 0 }

        if ($UpperBound -ge 0 -and $LowerBound -ge 0) {
            $status = if ($count -gt $UpperBound) { "DONOR" } elseif ($count -lt $LowerBound) { "RECEIVER" } else { "BALANCED" }
            LogMessage -Message ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files) [{4}]" -f $folderName, $count, $deviationPct, $deviation, $status)
        }
        else {
            LogMessage -Message ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files)" -f $folderName, $count, $deviationPct, $deviation)
        }
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

    $targetNormalized = [IO.Path]::GetFullPath($TargetRoot)
    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetRoot -IncludeEmpty -FallbackSubfolders $Subfolders
    if ($null -eq $folderCounts) {
        return
    }
    $subfolderPaths = @($folderCounts.Keys)

    if ($Subfolders) {
        foreach ($candidate in $Subfolders) {
            $pathCandidate = if ($candidate -is [IO.FileSystemInfo]) { $candidate.FullName } else { [string]$candidate }
            if ([string]::IsNullOrWhiteSpace($pathCandidate)) { continue }

            $resolved = Resolve-SubfolderPath -Path $pathCandidate -TargetRoot $TargetRoot
            if (-not $resolved) { continue }
            if (-not (Test-Path -LiteralPath $resolved -PathType Container)) { continue }
            if (-not $folderCounts.ContainsKey($resolved)) {
                $folderCounts[$resolved] = 0
                $subfolderPaths += $resolved
            }
        }
    }

    $subfolderPaths = @($subfolderPaths | Select-Object -Unique)
    if ($subfolderPaths.Count -eq 0) {
        $emergency = Join-Path -Path $TargetRoot -ChildPath (Get-RandomFileName)
        New-Item -ItemType Directory -Path $emergency -Force | Out-Null
        $subfolderPaths = @($emergency)
        $folderCounts[$emergency] = 0
        LogMessage -Message ("Distribution: created emergency destination subfolder '{0}' (no valid candidates)." -f $emergency) -IsWarning
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

        $folderCount = if ($folderCounts.ContainsKey($destinationFolder)) { [int]$folderCounts[$destinationFolder] } else { 0 }
        $folderCountRef = New-Ref -Initial $folderCount
        $moveResult = Invoke-FileMove -SourceFilePath $filePath `
            -OriginalFileName $originalName `
            -DestinationFolder $destinationFolder `
            -FolderCountRef $folderCountRef `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency $UpdateFrequency `
            -TotalFiles $TotalFiles `
            -RetryDelay $RetryDelay `
            -RetryCount $RetryCount `
            -ProgressActivity "Distributing Files" `
            -ProgressStatusTemplate "Processed {0} of {1} files" `
            -CopyFailureMessageTemplate "Failed to copy '{0}' to '{1}'. Original file not moved." `
            -PostCopyFailureMessageTemplate "Failed to process file '{0}' after copying. Error: {1}"

        if ($moveResult.Success) {
            $destinationFile = $moveResult.DestinationFile
            LogMessage -Message "Assigning randomized destination name for '$filePath' -> '$destinationFile'."
            $folderCounts[$destinationFolder] = $folderCountRef.Value
            if ($DeleteMode -eq "RecycleBin") {
                LogMessage -Message "Copied from $file to $destinationFile and moved original to Recycle Bin."
            }
            elseif ($DeleteMode -eq "Immediate") {
                LogMessage -Message "Copied from $file to $destinationFile and immediately deleted original."
            }
            elseif ($DeleteMode -eq "EndOfScript") {
                if ($moveResult.QueueQueued -eq $true) {
                    LogMessage -Message "Copied from $file to $destinationFile. Original pending deletion at end of script."
                }
                else {
                    LogMessage -Message "Copied from $file to $destinationFile, but original could not be queued for end-of-script deletion." -IsWarning
                }
            }
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

    $folderFilesMap = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty -FallbackSubfolders $Subfolders
    if ($null -eq $folderFilesMap) {
        return
    }
    $normalizedSubfolders = @($folderFilesMap.Keys)

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

    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $folderCounts) { return }
    $subfolderPaths = @($folderCounts.Keys)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })
    $totalFiles = [int](($folderCounts.Values | Measure-Object -Sum).Sum)

    if (-not $subfolders -or $subfolders.Count -le 1) {
        LogMessage -Message "Rebalance: need at least two subfolders. Nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Rebalance: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $folderCounts[$p]) -IsDebug
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Rebalance: no files to rebalance." -ConsoleOutput
        return
    }

    $avg = [double]$totalFiles / [double]$subfolders.Count
    $low = [int][math]::Floor($avg * $lowerMultiplier)
    $high = [int][math]::Ceiling($avg * $upperMultiplier)

    LogMessage -Message ("Rebalance: totalFiles={0}, subfolders={1}, avg={2:N2}, lowerBound={3}, upperBound={4} (limit={5}, tolerance=±{6}%)" -f $totalFiles, $subfolders.Count, $avg, $low, $high, $FilesPerFolderLimit, $Tolerance)

    Write-DistributionSummary -FolderCounts $folderCounts -Average $avg -Label "Rebalance: === CURRENT DISTRIBUTION ===" -UpperBound $high -LowerBound $low

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

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, $srcFolderName, $destFolderName) -IsDebug

            $folderCountRef = New-Ref -Initial 0
            $moveResult = Invoke-FileMove -SourceFilePath $file.FullName `
                -OriginalFileName $file.Name `
                -DestinationFolder $destFolder `
                -FolderCountRef $folderCountRef `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency $UpdateFrequency `
                -TotalFiles $plannedMoves `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -ProgressActivity "Rebalancing subfolders" `
                -ProgressStatusTemplate "Moved {0} of {1}" `
                -CopyFailureMessageTemplate "Rebalance: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Rebalance: post-copy handling failed for '{0}': {1}" `
                -IncrementOnSuccessOnly

            if ($moveResult.Success) {
                # Update receiver deficit and donor surplus
                $receiverMap[$destFolder] = [Math]::Max(0, ([int]$receiverMap[$destFolder]) - 1)
                if ($receiverMap[$destFolder] -le 0) { $receiverMap.Remove($destFolder) }
                $totalMoved++

                # Log progress periodically
                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge ($plannedMoves / 10)) {
                    $pct = if ($plannedMoves -gt 0) { ($GlobalFileCounter.Value / $plannedMoves) * 100 } else { 0 }
                    LogMessage -Message ("Rebalance: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $plannedMoves, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            }
            else {
                $totalFailed++
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
    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avg -Label "Rebalance: === FINAL DISTRIBUTION (verification) ===" -UpperBound $high -LowerBound $low
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

    $currentCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $currentCounts) { return }
    $subfolderPaths = @($currentCounts.Keys)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        LogMessage -Message "Randomize: no subfolders present; nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)

    # Enumerate all files in all subfolders and track current counts
    $allFiles = @()
    $totalFiles = 0

    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        try {
            $files = @(Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop)
            $allFiles += $files
            $totalFiles += $files.Count
            LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $files.Count) -IsDebug
        }
        catch {
            LogMessage -Message "Randomize: failed to enumerate files in '$p': $($_.Exception.Message)" -IsWarning
        }
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Randomize: no files to redistribute." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: found {0} file(s) total across {1} subfolder(s)" -f $totalFiles, $subfolders.Count)

    $avg = [double]$totalFiles / [double]$subfolders.Count
    Write-DistributionSummary -FolderCounts $currentCounts -Average $avg -Label "Randomize: === CURRENT DISTRIBUTION ==="
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

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, (Split-Path -Leaf $currentFolder), $destFolderName) -IsDebug

            $folderCountRef = New-Ref -Initial 0
            $moveResult = Invoke-FileMove -SourceFilePath $file.FullName `
                -OriginalFileName $file.Name `
                -DestinationFolder $destFolder `
                -FolderCountRef $folderCountRef `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency $UpdateFrequency `
                -TotalFiles $filesMoving `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -ProgressActivity "Randomizing distribution" `
                -ProgressStatusTemplate "Moved {0} of {1} files" `
                -CopyFailureMessageTemplate "Randomize: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Randomize: failed to handle original file '{0}': {1}" `
                -CopyFailureIsWarning `
                -IncrementOnSuccessOnly

            if ($moveResult.Success) {
                $totalMoves++

                # Log progress periodically
                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge ($filesMoving / 10)) {
                    $pct = if ($filesMoving -gt 0) { ($GlobalFileCounter.Value / $filesMoving) * 100 } else { 0 }
                    LogMessage -Message ("Randomize: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $filesMoving, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            }
            else {
                $totalErrors++
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
    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avg -Label "Randomize: === FINAL DISTRIBUTION (verification) ==="
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

    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $folderCounts) { return }
    $subfolderPaths = @($folderCounts.Keys)
    $totalFiles = [int](($folderCounts.Values | Measure-Object -Sum).Sum)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        LogMessage -Message "Consolidation: no subfolders present; nothing to do." -ConsoleOutput
        return
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
    $avgBefore = if ($existingCount -gt 0) { [double]$totalFiles / [double]$existingCount } else { 0.0 }
    Write-DistributionSummary -FolderCounts $folderCounts -Average $avgBefore -Label "Consolidation: === CURRENT DISTRIBUTION ==="

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

            $folderCount = if ($liveCounts.ContainsKey($destFolder)) { [int]$liveCounts[$destFolder] } else { 0 }
            $folderCountRef = New-Ref -Initial $folderCount
            $moveResult = Invoke-FileMove -SourceFilePath $file.FullName `
                -OriginalFileName $file.Name `
                -DestinationFolder $destFolder `
                -FolderCountRef $folderCountRef `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency $UpdateFrequency `
                -TotalFiles $totalMoves `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -ProgressActivity "Consolidating subfolders" `
                -ProgressStatusTemplate "Moved {0} of {1}" `
                -CopyFailureMessageTemplate "Consolidation: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Consolidation: post-copy handling failed for '{0}': {1}"

            if ($moveResult.Success) {
                # Update counts/capacity
                $liveCounts[$destFolder] = $folderCountRef.Value
                $capacity[$destFolder] = [Math]::Max(0, $FilesPerFolderLimit - $liveCounts[$destFolder])
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

    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        $finalFolderCount = @($finalCounts.Keys).Count
        $finalTotalFiles = [int](($finalCounts.Values | Measure-Object -Sum).Sum)
        $avgAfter = if ($finalFolderCount -gt 0) { [double]$finalTotalFiles / [double]$finalFolderCount } else { 0.0 }
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avgAfter -Label "Consolidation: === FINAL DISTRIBUTION (verification) ==="
    }
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
            Path             = $item.SourcePath
            Size             = $item.Size
            LastWriteTimeUtc = $item.LastWriteTimeUtc
            QueuedAtUtc      = $item.QueuedAtUtc
            SessionId        = $item.SessionId
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
        [ref]$fileLock,
        [Parameter(Mandatory = $true)][string]$SessionId
    )

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
        SessionId     = $SessionId
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

# Main script logic

function Invoke-ParameterValidation {
    param([hashtable]$RunState)

    LogMessage -Message "Validating parameters: SourceFolder - $SourceFolder, TargetFolder - $TargetFolder, FilesPerFolderLimit - $FilesPerFolderLimit, MaxFilesToCopy - $MaxFilesToCopy"

    $RunState.SessionId = [guid]::NewGuid().ToString()

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        $RunState.MaxFilesToCopy = 0
        LogMessage -Message "SourceFolder not specified. Running in rebalance-only mode (no files will be copied)." -ConsoleOutput
    }
    else {
        $RunState.MaxFilesToCopy = $MaxFilesToCopy
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
        $RunState.FilesPerFolderLimit = 20000
    }
    else {
        $RunState.FilesPerFolderLimit = $FilesPerFolderLimit
    }

    if (!(Test-Path -Path $TargetFolder)) {
        LogMessage -Message "Target folder '$TargetFolder' does not exist. Creating it." -IsWarning
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    }

    if (-not ("RecycleBin", "Immediate", "EndOfScript" -contains $DeleteMode)) {
        LogMessage -Message "Invalid value for DeleteMode: $DeleteMode. Valid options are 'RecycleBin', 'Immediate', 'EndOfScript'." -IsError
        throw "Invalid DeleteMode."
    }

    $exclusiveOptions = @($ConsolidateToMinimum, $RebalanceToAverage, $RandomizeDistribution)
    $enabledCount = ($exclusiveOptions | Where-Object { $_ }).Count
    if ($enabledCount -gt 1) {
        LogMessage -Message "Parameters -ConsolidateToMinimum, -RebalanceToAverage, and -RandomizeDistribution are mutually exclusive. Choose only one." -IsError
        throw "Mutually exclusive options: only one of -ConsolidateToMinimum, -RebalanceToAverage, or -RandomizeDistribution can be specified"
    }

    if (-not ("NoWarnings", "WarningsOnly" -contains $EndOfScriptDeletionCondition)) {
        LogMessage -Message "Invalid value for EndOfScriptDeletionCondition: $EndOfScriptDeletionCondition. Valid options are 'NoWarnings', 'WarningsOnly'." -IsError
        throw "Invalid EndOfScriptDeletionCondition."
    }

    if ($RunState.MaxFilesToCopy -lt -1) {
        LogMessage -Message "Invalid MaxFilesToCopy '$($RunState.MaxFilesToCopy)'. Using -1 (no limit)." -IsWarning
        $RunState.MaxFilesToCopy = -1
    }

    $RunState.FilesToDelete = New-FileQueue -Name "FilesToDelete" -SessionId $RunState.SessionId -MaxSize -1
    $RunState.GlobalFileCounter = New-Ref 0
    LogMessage -Message "Parameter validation completed"
}

function Invoke-RestoreCheckpoint {
    param(
        [hashtable]$RunState,
        [ref]$FileLockRef,
        [ref]$PriorWarnings,
        [ref]$PriorErrors
    )

    $RunState.LastCheckpoint = 0

    if ($Restart) {
        $FileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
        LogMessage -Message "Restart requested. Loading checkpoint..." -ConsoleOutput

        $state = LoadState -fileLock $FileLockRef
        $RunState.State = $state
        $RunState.LastCheckpoint = $state.Checkpoint

        if ($RunState.LastCheckpoint -gt 0) {
            if ($state.PSObject.Properties.Name -contains 'SessionId' -and $state.SessionId) {
                $RunState.SessionId = [string]$state.SessionId
            }
            else {
                $RunState.SessionId = [guid]::NewGuid().ToString()
                LogMessage -Message "Legacy state without SessionId; generated new SessionId for this resume." -IsWarning
            }

            if ($state.PSObject.Properties.Name -contains 'WarningsSoFar') { $PriorWarnings.Value = [int]$state.WarningsSoFar }
            if ($state.PSObject.Properties.Name -contains 'ErrorsSoFar') { $PriorErrors.Value = [int]$state.ErrorsSoFar }
            LogMessage -Message "Restarting from checkpoint $($RunState.LastCheckpoint)" -ConsoleOutput
        }
        else {
            LogMessage -Message "Checkpoint not found. Executing from top..." -IsWarning
        }

        if ($state.ContainsKey("SourceFolder")) {
            $savedSourceFolder = $state.SourceFolder
            if (-not [string]::IsNullOrWhiteSpace($savedSourceFolder)) {
                if ($SourceFolder -ne $savedSourceFolder) {
                    throw "SourceFolder mismatch: Restarted script must use the saved SourceFolder ('$savedSourceFolder'). Aborting."
                }
            }
        }
        else {
            throw "State file does not contain SourceFolder. Unable to enforce."
        }

        if ($state.ContainsKey("deleteMode")) {
            $savedDeleteMode = $state.deleteMode
            if ($DeleteMode -ne $savedDeleteMode) {
                throw "DeleteMode mismatch: Restarted script must use the saved DeleteMode ('$savedDeleteMode'). Aborting."
            }
        }
        else {
            throw "State file does not contain DeleteMode. Unable to enforce."
        }

        if ($RunState.LastCheckpoint -in 2..7 -and $null -ne $state) {
            if ($state.ContainsKey('totalSourceFiles')) { $RunState.totalSourceFiles = [int]$state['totalSourceFiles'] }
            if ($state.ContainsKey('totalTargetFilesBefore')) { $RunState.totalTargetFilesBefore = [int]$state['totalTargetFilesBefore'] }
            if ($state.ContainsKey('totalSourceFilesAll')) { $RunState.totalSourceFilesAll = [int]$state['totalSourceFilesAll'] }
            if ($state.ContainsKey('MaxFilesToCopy')) {
                $savedMax = [int]$state['MaxFilesToCopy']
                if ($RunState.MaxFilesToCopy -ne $savedMax) {
                    throw "MaxFilesToCopy mismatch: Restarted script must use the saved MaxFilesToCopy ($savedMax). Aborting."
                }
                $RunState.MaxFilesToCopy = $savedMax
            }
            if ($state.ContainsKey('subfolders')) { $RunState.subfolders = ConvertPathsToItems($state['subfolders']) }
            if ($RunState.LastCheckpoint -in 2, 3 -and $state.ContainsKey('sourceFiles')) { $RunState.sourceFiles = ConvertPathsToItems($state['sourceFiles']) }
        }

        if ($DeleteMode -eq "EndOfScript" -and $RunState.LastCheckpoint -in 3, 4, 5, 6, 7 -and $state.ContainsKey("FilesToDelete")) {
            foreach ($e in $state.FilesToDelete) {
                if ($e -is [string]) {
                    Add-FileToQueue -Queue $RunState.FilesToDelete -FilePath $e -ValidateFile $false | Out-Null
                }
                else {
                    $RunState.FilesToDelete.Items.Enqueue([pscustomobject]@{
                        SourcePath       = $e.Path
                        TargetPath       = $null
                        Size             = $e.Size
                        LastWriteTimeUtc = $e.LastWriteTimeUtc
                        QueuedAtUtc      = if ($e.PSObject.Properties.Name -contains 'QueuedAtUtc') { $e.QueuedAtUtc } else { (Get-Date).ToUniversalTime() }
                        SessionId        = if ($e.PSObject.Properties.Name -contains 'SessionId') { $e.SessionId } else { $RunState.SessionId }
                        Attempts         = 0
                        Metadata         = @{}
                    })
                }
            }
        }
    }
    else {
        if (Test-Path -Path $StateFilePath) {
            LogMessage -Message "Restart state file found but restart not requested. Deleting state file..." -IsWarning
            Remove-Item -Path $StateFilePath -Force
        }
        $FileLockRef.Value = AcquireFileLock -FilePath $StateFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
    }
}


function New-CheckpointPayload {
    param(
        [hashtable]$RunState,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [string]$SourceFolder,
        [int]$MaxFilesToCopy,
        [object]$Subfolders,
        [object]$SourceFiles,
        [switch]$IncludeSourceFiles,
        [switch]$IncludeFilesToDelete
    )

    $payload = @{
        totalSourceFiles       = $RunState.totalSourceFiles
        totalSourceFilesAll    = $RunState.totalSourceFilesAll
        totalTargetFilesBefore = $RunState.totalTargetFilesBefore
        deleteMode             = $DeleteMode
        SourceFolder           = $SourceFolder
        MaxFilesToCopy         = $MaxFilesToCopy
    }

    if ($null -ne $Subfolders) {
        $payload.subfolders = ConvertItemsToPaths($Subfolders)
    }

    if ($IncludeSourceFiles -and $null -ne $SourceFiles) {
        $payload.sourceFiles = ConvertItemsToPaths($SourceFiles)
    }

    if ($IncludeFilesToDelete -and $DeleteMode -eq "EndOfScript") {
        $payload.FilesToDelete = ConvertFrom-FileQueue -Queue $RunState.FilesToDelete
    }

    return $payload
}
function Invoke-DistributionPhase {
    param([hashtable]$RunState,[ref]$FileLockRef)

    if ($RunState.LastCheckpoint -lt 1) {
        if (-not [string]::IsNullOrWhiteSpace($SourceFolder)) {
            LogMessage -Message "Preparing for distribution (no upfront renaming; rename occurs at copy time)." -ConsoleOutput
        }
        SaveState -Checkpoint 1 -AdditionalVariables @{ deleteMode = $DeleteMode; SourceFolder = $SourceFolder } -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RunState.LastCheckpoint -lt 2) {
        if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
            LogMessage -Message "Enumerating target files..." -ConsoleOutput
            $RunState.sourceFiles = @(); $RunState.totalSourceFiles = 0; $RunState.totalSourceFilesAll = 0
        }
        else {
            LogMessage -Message "Enumerating source and target files..." -ConsoleOutput
            $allSourceFiles = Get-ChildItem -Path $SourceFolder -Recurse -File
            $allowedExtensions = @('.jpg', '.png', '.mp4')
            $sourceFilesAll = @()
            foreach ($file in $allSourceFiles) {
                $ext = $file.Extension.ToLower()
                if ($ext -in $allowedExtensions) { $sourceFilesAll += $file }
                else {
                    if (-not $RunState.skippedFilesByExtension.ContainsKey($ext)) { $RunState.skippedFilesByExtension[$ext] = 0 }
                    $RunState.skippedFilesByExtension[$ext]++
                    $RunState.totalSkippedFiles++
                }
            }
            $RunState.totalSourceFilesAll = $sourceFilesAll.Count
            if ($RunState.MaxFilesToCopy -eq 0) { $RunState.sourceFiles = @() }
            elseif ($RunState.MaxFilesToCopy -gt 0) { $RunState.sourceFiles = $sourceFilesAll | Select-Object -First $RunState.MaxFilesToCopy }
            else { $RunState.sourceFiles = $sourceFilesAll }
            $RunState.totalSourceFiles = $RunState.sourceFiles.Count
        }

        $RunState.totalTargetFilesBefore = (Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object).Count
        $RunState.totalTargetFilesBefore = if ($null -eq $RunState.totalTargetFilesBefore) { 0 } else { $RunState.totalTargetFilesBefore }
        $totalFiles = $RunState.totalSourceFiles + $RunState.totalTargetFilesBefore

        $RunState.subfolders = @(Get-ChildItem -LiteralPath $TargetFolder -Force | Where-Object { $_.PSIsContainer })
        if ($totalFiles / $RunState.FilesPerFolderLimit -gt $RunState.subfolders.Count) {
            $additionalFolders = [math]::Ceiling($totalFiles / $RunState.FilesPerFolderLimit) - $RunState.subfolders.Count
            $RunState.subfolders += CreateRandomSubfolders -TargetPath $TargetFolder -NumberOfFolders $additionalFolders -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency
        }

        SaveState -Checkpoint 2 -AdditionalVariables (New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.subfolders -SourceFiles $RunState.sourceFiles -IncludeSourceFiles) -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RunState.LastCheckpoint -lt 3) {
        $cp3 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.subfolders -IncludeFilesToDelete
        SaveState -Checkpoint 3 -AdditionalVariables $cp3 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RunState.LastCheckpoint -lt 4) {
        if ($RunState.totalSourceFiles -gt 0 -and $RunState.sourceFiles.Count -gt 0) {
            DistributeFilesToSubfolders -Files $RunState.sourceFiles -Subfolders $RunState.subfolders -TargetRoot $TargetFolder -Limit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -TotalFiles $RunState.totalSourceFiles
        }
        $cp4 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders $RunState.subfolders -SourceFiles $RunState.sourceFiles -IncludeSourceFiles -IncludeFilesToDelete
        SaveState -Checkpoint 4 -AdditionalVariables $cp4 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RunState.LastCheckpoint -lt 5) {
        RedistributeFilesInTarget -TargetFolder $TargetFolder -Subfolders $RunState.subfolders -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter -TotalFiles 0
        $cp5 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -IncludeFilesToDelete
        SaveState -Checkpoint 5 -AdditionalVariables $cp5 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }
}

function Invoke-PostProcessingPhase {
    param([hashtable]$RunState,[ref]$FileLockRef)

    if ($ConsolidateToMinimum -and $RunState.LastCheckpoint -lt 6) {
        ConsolidateSubfoldersToMinimum -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter
        $cp6 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        SaveState -Checkpoint 6 -AdditionalVariables $cp6 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RebalanceToAverage -and $RunState.LastCheckpoint -lt 7) {
        RebalanceSubfoldersByAverage -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -Tolerance $RebalanceTolerance -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter
        $cp7 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        SaveState -Checkpoint 7 -AdditionalVariables $cp7 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }

    if ($RandomizeDistribution -and $RunState.LastCheckpoint -lt 8) {
        RandomizeDistributionAcrossFolders -TargetFolder $TargetFolder -FilesPerFolderLimit $RunState.FilesPerFolderLimit -ShowProgress:$ShowProgress -UpdateFrequency:$UpdateFrequency -DeleteMode $DeleteMode -FilesToDelete $RunState.FilesToDelete -GlobalFileCounter $RunState.GlobalFileCounter
        $cp8 = New-CheckpointPayload -RunState $RunState -DeleteMode $DeleteMode -SourceFolder $SourceFolder -MaxFilesToCopy $RunState.MaxFilesToCopy -Subfolders (Get-ChildItem -LiteralPath $TargetFolder -Directory -Force) -IncludeFilesToDelete
        SaveState -Checkpoint 8 -AdditionalVariables $cp8 -fileLock $FileLockRef -SessionId $RunState.SessionId
    }
}

function Invoke-EndOfScriptDeletion {
    param(
        [hashtable]$RunState,
        [int]$PriorWarnings,
        [int]$PriorErrors,
        [Parameter(Mandatory = $true)][string]$DeleteMode
    )

    if ($DeleteMode -ne "EndOfScript") { return }

    $effectiveWarnings = [Math]::Max($Warnings, $PriorWarnings)
    $effectiveErrors = [Math]::Max($Errors, $PriorErrors)

    if (-not (Test-EndOfScriptCondition -Condition $EndOfScriptDeletionCondition -Warnings $effectiveWarnings -Errors $effectiveErrors)) {
        LogMessage -Message "End-of-script deletion skipped due to warnings or errors."
        return
    }

    while ($RunState.FilesToDelete.Items.Count -gt 0) {
        $entry = Get-NextQueueItem -Queue $RunState.FilesToDelete -IncrementAttempts $false
        if ($null -eq $entry) { break }
        if ($entry.SessionId -ne $RunState.SessionId) { continue }
        if (-not (Test-Path -Path $entry.SourcePath)) { continue }

        $okToDelete = $true
        try {
            $fi = Get-Item -LiteralPath $entry.SourcePath -ErrorAction Stop
            if ($null -ne $entry.Size -and $fi.Length -ne $entry.Size) { $okToDelete = $false }
            if ($null -ne $entry.LastWriteTimeUtc -and $fi.LastWriteTimeUtc -ne $entry.LastWriteTimeUtc) { $okToDelete = $false }
        }
        catch { LogMessage -Message "Could not stat queued file before deletion: $($_.Exception.Message)" -IsDebug }

        if ($okToDelete) {
            try { Remove-File -FilePath $entry.SourcePath } catch { LogMessage -Message "Failed to delete file $($entry.SourcePath). Error: $($_.Exception.Message)" -IsWarning }
        }
    }
}

function Invoke-PostRunCleanup {
    param([hashtable]$RunState,[ref]$FileLockRef)

    $totalTargetFilesAfter = Get-ChildItem -Path $TargetFolder -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
    $totalTargetFilesAfter = if ($null -eq $totalTargetFilesAfter) { 0 } else { $totalTargetFilesAfter }

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        LogMessage -Message "===== File Rebalancing Summary =====" -ConsoleOutput
        LogMessage -Message "Original number of files in the target folder hierarchy: $($RunState.totalTargetFilesBefore)" -ConsoleOutput
        LogMessage -Message "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput
        if ($RunState.totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage -Message "File count changed during rebalancing. Possible discrepancy detected." -IsWarning
        }
        else {
            LogMessage -Message "File rebalancing completed successfully." -ConsoleOutput
        }
    }
    else {
        LogMessage -Message "===== File Distribution Summary =====" -ConsoleOutput
        LogMessage -Message "Original number of files in the source folder (enumerated): $($RunState.totalSourceFilesAll)" -ConsoleOutput
        LogMessage -Message "Files selected for copying this run: $($RunState.totalSourceFiles)" -ConsoleOutput
        LogMessage -Message "Original number of files in the target folder hierarchy: $($RunState.totalTargetFilesBefore)" -ConsoleOutput
        LogMessage -Message "Final number of files in the target folder hierarchy: $totalTargetFilesAfter" -ConsoleOutput
        if ($RunState.totalSourceFiles + $RunState.totalTargetFilesBefore -ne $totalTargetFilesAfter) {
            LogMessage -Message "Sum of original counts does not equal the final count in the target. Possible discrepancy detected." -IsWarning
        }
        else {
            LogMessage -Message "File distribution and cleanup completed successfully." -ConsoleOutput
        }
    }
    LogMessage -Message "Total warnings: $script:Warnings" -ConsoleOutput
    LogMessage -Message "Total errors: $script:Errors" -ConsoleOutput

    if ($FileLockRef.Value) { ReleaseFileLock -FileStream $FileLockRef.Value; $FileLockRef.Value = $null }
    Remove-Item -Path $StateFilePath -Force

    if ($CleanupDuplicates) {
        $dupScript = Join-Path -Path $script:ScriptRoot -ChildPath "Remove-DuplicateFiles.ps1"
        if (Test-Path -LiteralPath $dupScript) { & $dupScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false }
    }

    if ($CleanupEmptyFolders) {
        $emptyScript = Join-Path -Path $script:ScriptRoot -ChildPath "Remove-EmptyFolders.ps1"
        if (Test-Path -LiteralPath $emptyScript) { & $emptyScript -ParentDirectory $TargetFolder -LogFilePath $LogFilePath -DryRun:$false }
    }
}

# Main script logic
function Main {
    LogMessage -Message "FileDistributor starting..." -ConsoleOutput
    LogMessage -Message "Version: $script:Version" -ConsoleOutput
    $script:DebugMode = ($DebugPreference -ne 'SilentlyContinue')
    Import-RandomNameProvider -ModulePath $RandomNameModulePath

    $priorWarnings = 0
    $priorErrors = 0

    if (-not $Restart) {
        $beforeTimestamp = $null
        if ($RemoveEntriesBefore) {
            try { $beforeTimestamp = [datetime]::Parse($RemoveEntriesBefore) }
            catch { throw "Invalid timestamp format. Use 'YYYY-MM-DD HH:MM:SS' or ISO 8601." }
        }
        if ($RemoveEntriesOlderThan -lt 0) { throw "Invalid value for RemoveEntriesOlderThan. Must be a non-negative integer." }

        $purgeParams = @{ LogFilePath = $LogFilePath }
        if ($beforeTimestamp) { $purgeParams.BeforeTimestamp = $beforeTimestamp }
        if ($RemoveEntriesOlderThan) { $purgeParams.RetentionDays = $RemoveEntriesOlderThan }
        if ($TruncateIfLarger) { $purgeParams.TruncateIfLarger = $TruncateIfLarger }
        if ($TruncateLog) { $purgeParams.TruncateLog = $true }

        if ($purgeParams.Keys.Count -gt 1) {
            try { Clear-LogFile @purgeParams }
            catch { LogMessage -Message "Failed to apply log file cleanup policy: $($_.Exception.Message)" -IsError }
        }
    }

    $runState = @{
        totalSourceFilesAll = 0
        totalSourceFiles = 0
        totalTargetFilesBefore = 0
        subfolders = @()
        sourceFiles = @()
        skippedFilesByExtension = @{}
        totalSkippedFiles = 0
    }
    $fileLockRef = [ref]$null

    try {
        Invoke-ParameterValidation -RunState $runState
        Invoke-RestoreCheckpoint -RunState $runState -FileLockRef $fileLockRef -PriorWarnings ([ref]$priorWarnings) -PriorErrors ([ref]$priorErrors)
        Invoke-DistributionPhase -RunState $runState -FileLockRef $fileLockRef
        Invoke-PostProcessingPhase -RunState $runState -FileLockRef $fileLockRef
        Invoke-EndOfScriptDeletion -RunState $runState -PriorWarnings $priorWarnings -PriorErrors $priorErrors -DeleteMode $DeleteMode
        Invoke-PostRunCleanup -RunState $runState -FileLockRef $fileLockRef

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
