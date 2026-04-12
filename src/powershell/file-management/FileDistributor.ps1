<#
.SYNOPSIS
The script recursively enumerates files from the source directory and ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

.DESCRIPTION
The script ensures that files are evenly distributed across subfolders in the target directory, adhering to a configurable file limit per subfolder. If the limit is exceeded, new subfolders are created dynamically. Files in the target folder (not in subfolders) are also redistributed.

 .VERSION
 See `$script:Version`.

  CHANGELOG:
    See FileDistributor.CHANGELOG.md in this directory for full release history.

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
(`Copy-FileWithRetry`, `Remove-FileWithRetry`, module `Invoke-WithRetry`, Recycle Bin moves).

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
Version: see `$script:Version` (runtime script version; module version is independently versioned).

For full release history (including v4.7.1 and v4.7.2), see:
- ./FileDistributor.CHANGELOG.md

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

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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

# Display help and exit if -Help is specified (short-circuit before module imports)
if ($Help) {
    Get-Help -Full $PSCommandPath
    exit 0
}

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PurgeLogs.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\ErrorHandling\ErrorHandling.psd1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\FileOperations\FileOperations.psd1" -Force

# Import FileQueue module for queue management
Import-Module "$PSScriptRoot\..\modules\FileManagement\FileQueue\FileQueue.psd1" -Force
Import-Module "$PSScriptRoot\..\modules\FileManagement\FileDistributor\FileDistributor.psd1" -Force

# Note: Logger initialization moved to after LogFilePath resolution

# Define script-scoped variables for warnings and errors
$script:Version = "4.8.7"
$script:Warnings = 0
$script:Errors = 0

# ===== Windows path resolution helpers (executed before any logging) =====
# Determine script root (works in PS 5.1+ when running as a script)
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $MyInvocation.MyCommand.Path -Parent }

# ===== Resolve effective LogFilePath and StateFilePath (before first Write-Log* call) =====
# Uses Initialize-FileDistributorPaths from the FileDistributor module (imported above).
$_paths = Initialize-FileDistributorPaths `
    -UserLogPath   $LogFilePath `
    -UserStatePath $StateFilePath `
    -CallerScriptRoot $script:ScriptRoot

$script:LogFilePath = $_paths.LogFilePath
$script:StateFilePath = $_paths.StateFilePath

# From here on, use the resolved script-scoped variables
$LogFilePath = $script:LogFilePath
$StateFilePath = $script:StateFilePath

# Initialize logger with the resolved log directory
$logDirectory = Split-Path -Path $LogFilePath -Parent
Initialize-Logger -resolvedLogDir $logDirectory -ScriptName "FileDistributor" -LogLevel 20
# Override the framework's auto-generated filename to use the user's exact path
$Global:LogConfig.LogFilePath = $LogFilePath
Reset-LogCounters

# Main script logic
function Main {
    Write-LogInfo "FileDistributor starting..."
    Write-Host "FileDistributor starting..."
    Write-LogInfo "Version: $script:Version"
    Write-Host "Version: $script:Version"
    $script:DebugMode = ($DebugPreference -ne 'SilentlyContinue')
    Import-RandomNameProvider -ModulePath $RandomNameModulePath -ScriptRoot $script:ScriptRoot
    $script:Warnings = Get-LogWarningCount
    $script:Errors = Get-LogErrorCount

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
            catch { Write-LogError "Failed to apply log file cleanup policy: $($_.Exception.Message)" }
        }
    }
    $script:Warnings = [Math]::Max($script:Warnings, (Get-LogWarningCount))
    $script:Errors = [Math]::Max($script:Errors, (Get-LogErrorCount))

    $runState = @{
        totalSourceFilesAll     = 0
        totalSourceFiles        = 0
        totalTargetFilesBefore  = 0
        subfolders              = @()
        sourceFiles             = @()
        skippedFilesByExtension = @{}
        totalSkippedFiles       = 0
    }
    $fileLockRef = [ref]$null

    try {
        Invoke-ParameterValidation -RunState $runState `
            -SourceFolder $SourceFolder -TargetFolder $TargetFolder `
            -FilesPerFolderLimit $FilesPerFolderLimit -MaxFilesToCopy $MaxFilesToCopy `
            -DeleteMode $DeleteMode `
            -ConsolidateToMinimum:$ConsolidateToMinimum `
            -RebalanceToAverage:$RebalanceToAverage `
            -RandomizeDistribution:$RandomizeDistribution `
            -EndOfScriptDeletionCondition $EndOfScriptDeletionCondition `
            -WarningCount ([ref]$script:Warnings) -ErrorCount ([ref]$script:Errors)
        Invoke-RestoreCheckpoint -RunState $runState -FileLockRef $fileLockRef `
            -PriorWarnings ([ref]$priorWarnings) -PriorErrors ([ref]$priorErrors) `
            -Restart:$Restart -StateFilePath $StateFilePath `
            -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff `
            -SourceFolder $SourceFolder -DeleteMode $DeleteMode `
            -WarningCount ([ref]$script:Warnings)
        Invoke-DistributionPhase -RunState $runState -FileLockRef $fileLockRef `
            -SourceFolder $SourceFolder -TargetFolder $TargetFolder `
            -DeleteMode $DeleteMode -StateFilePath $StateFilePath `
            -ShowProgress:$ShowProgress -UpdateFrequency $UpdateFrequency `
            -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff `
            -WarningCount ([ref]$script:Warnings) -ErrorCount ([ref]$script:Errors)
        Invoke-PostProcessingPhase -RunState $runState -FileLockRef $fileLockRef `
            -ConsolidateToMinimum:$ConsolidateToMinimum `
            -RebalanceToAverage:$RebalanceToAverage `
            -RandomizeDistribution:$RandomizeDistribution `
            -TargetFolder $TargetFolder -SourceFolder $SourceFolder -DeleteMode $DeleteMode `
            -ShowProgress:$ShowProgress -UpdateFrequency $UpdateFrequency `
            -RebalanceTolerance $RebalanceTolerance -StateFilePath $StateFilePath `
            -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff `
            -WarningCount ([ref]$script:Warnings) -ErrorCount ([ref]$script:Errors)
        Invoke-EndOfScriptDeletion -RunState $runState `
            -PriorWarnings $priorWarnings -PriorErrors $priorErrors `
            -DeleteMode $DeleteMode `
            -EndOfScriptDeletionCondition $EndOfScriptDeletionCondition `
            -RetryDelay $RetryDelay -RetryCount $RetryCount `
            -WarningCount ([ref]$script:Warnings) -ErrorCount ([ref]$script:Errors)
        Invoke-PostRunCleanup -RunState $runState -FileLockRef $fileLockRef `
            -TargetFolder $TargetFolder -StateFilePath $StateFilePath `
            -CleanupDuplicates:$CleanupDuplicates -CleanupEmptyFolders:$CleanupEmptyFolders `
            -LogFilePath $LogFilePath -ScriptRoot $script:ScriptRoot `
            -WarningCount ([ref]$script:Warnings) -ErrorCount ([ref]$script:Errors)

        Write-LogInfo "File distribution and optional cleanup completed."
    } catch {
        Write-LogError "FATAL ERROR: $($_.Exception.Message)"
        Write-Host "ERROR: FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogError "Stack Trace: $($_.ScriptStackTrace)"
        throw
    } finally {
        if ($fileLockRef -and ($fileLockRef.PSObject.Properties.Name -contains 'Value') -and $fileLockRef.Value) {
            Invoke-DistributionLockRelease -FileStream $fileLockRef.Value
        }
    }
}

# Run the script
Main
