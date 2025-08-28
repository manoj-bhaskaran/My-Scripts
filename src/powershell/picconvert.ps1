<#
.SYNOPSIS
    Renames *.jpeg to *.jpg and copies files from a source tree into
    extension-based, size-limited subfolders at the destination, with
    progress, robust error handling, deletion-after-copy, and a clear summary.

.DESCRIPTION
    Typical use-cases:
      - Normalise image extensions (.jpeg → .jpg) across a large photo library.
      - Copy a large set of files into per-extension subfolders for easier
        browsing, backup, or transfer.
      - Get reliable progress, input validation, and a final summary with totals,
        per-extension counts, directory breakdown, and elapsed time.

    What it does (high-level flow):
      1) Validates input and ensures destination exists.
      2) Renames .jpeg → .jpg (case-insensitive).
         - Skips if the target .jpg already exists.
         - Robust try/catch and error tracking.
         - Optional progress via Write-Progress.
         - Note: The .jpeg → .jpg renaming phase always evaluates .jpeg files
           regardless of -IncludeExtensions (the extension filter applies only
           to the copy phase).
      3) Copies all files (post-rename) into per-extension subfolders under DestDir:
           <BatchPrefix>_<RunStamp>_<ext>\ <ext>_0000, <ext>_0001, ...
         - **Rule:** Skip ALL .png files.
         - **Rule:** Copy .jpg only if filename starts with 'img' (case-sensitive).
         - Respects FilesPerFolderLimit (per subfolder); rolls to the next counter.
         - **Deletes the source file after a successful copy** (move semantics).
         - Robust try/catch and error tracking; optional progress; verbose logging.
      4) Prints a comprehensive summary:
         - Total files processed
         - Renamed count (.jpeg → .jpg)
         - Copied count
         - Per-extension copied counts
         - Directories created (with breakdown: batch vs root/log)
         - Error count (and writes a detailed error log if any)
         - Elapsed execution time

.PARAMETER SourceDir
    Source directory to scan (recursively). Default:
    C:\Users\manoj\OneDrive\Desktop\New folder

.PARAMETER DestDir
    Destination directory. Will be created if missing. Default:
    C:\Users\manoj\OneDrive\Desktop

.PARAMETER FilesPerFolderLimit
    Maximum number of files per extension subfolder. Default: 200.
    Use a positive integer. If 0 or less is supplied, the script treats it as unlimited.

.PARAMETER BatchPrefix
    Prefix for the per-extension root folders. Default: 'picconvert'.
      Example layout:
        <BatchPrefix>_<RunStamp>_<ext>\ <ext>_0000, <ext>_0001, ...

.PARAMETER ShowProgress
    If set, displays Write-Progress for the renaming and copying phases.
    The progress bars are explicitly completed at the end of each phase.

.PARAMETER IncludeExtensions
    Optional list of file extensions to include for the **copy phase**
    (e.g., '.jpg','.jpeg','.heic'). Case-insensitive.
      • **.jpeg files are ALWAYS considered for the rename phase**, regardless of
        this filter.
      • Copy phase still enforces the rules:
          - Skip all .png
          - For .jpg, only copy files whose names start with 'img' (case-sensitive)
        even if these extensions are listed here.
      • Validation: only alphanumeric extensions are accepted (e.g., .jpg, .heic).

.PARAMETER LogFilePath
    Optional path to a log file. If provided, detailed errors are appended here.
    If omitted and errors occur, a file named 'picconvert_errors_yyyyMMdd_HHmmss.log'
    will be created under DestDir. The path is validated and the directory is created
    if missing.

.INPUTS
    None. You cannot pipe input to this script.

.OUTPUTS
    None. Writes status/progress to the console and a summary at the end.

.EXAMPLE
    .\picconvert.ps1 -ShowProgress

.EXAMPLE
    .\picconvert.ps1 -SourceDir "D:\Photos\2024" -DestDir "F:\Media\Photos" `
      -FilesPerFolderLimit 150 -IncludeExtensions '.jpg','.heic' -BatchPrefix 'archive' `
      -ShowProgress -Verbose

.NOTES
    VERSION
      1.1.2

    CHANGELOG
      1.1.2
        - Added per-extension copied counts to the summary.
        - Split directory counters:
            • BatchDirsCreated (per-extension folders)
            • RootDirsCreated (DestDir, log dir)
          Summary shows both and total.
        - Introduced -BatchPrefix (default 'picconvert') to customise folder prefix.
        - Validated IncludeExtensions entries (alphanumeric-only extensions).
        - Restored defaults for SourceDir and DestDir to original paths.
        - Retained:
            • .png always skipped; .jpg copied only when name starts with 'img' (case-sensitive)
            • Delete source file after successful copy (move semantics)
            • Progress bars completed; elapsed time in summary; robust logging & error handling

      1.1.1
        - Enforced .png skip and .jpg '^img' rule; extension-based foldering with counters.
        - Delete-after-copy; progress completion; LogFilePath validation; elapsed time; verbose.

      1.1.0
        - Param block, input validation, modular functions, progress, structured summary.

      1.0.0
        - Initial version (assumed baseline).

    PREREQUISITES
      - PowerShell 5.1 or 7+ on Windows.
      - Read access to SourceDir, write access to DestDir.

    TROUBLESHOOTING
      - If "SourceDir not found", check the path and permissions.
      - If copies fail due to access being denied, verify read/write permissions.
      - If existing .jpg prevents rename of .jpeg, the script logs and skips safely.
      - For performance, avoid real-time AV scanning on DestDir during heavy copies.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDir = "C:\Users\manoj\OneDrive\Desktop\New folder",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DestDir   = "C:\Users\manoj\OneDrive\Desktop",

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 10000000)]
    [int]$FilesPerFolderLimit = 200,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$BatchPrefix = 'picconvert',

    [Parameter(Mandatory=$false)]
    [switch]$ShowProgress,

    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string[]]$IncludeExtensions,

    [Parameter(Mandatory=$false)]
    [string]$LogFilePath
)

# region: Globals / State -------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# Counters and tracking
$script:ErrList          = New-Object System.Collections.Generic.List[string]
$script:ErrCount         = 0
$script:RenamedCount     = 0
$script:CopiedCount      = 0
$script:BatchDirsCreated = 0
$script:RootDirsCreated  = 0
$script:CopiedByExt      = @{}   # e.g., @{ "jpg" = 123; "heic" = 45 }

# Timestamp for naming
$script:RunStamp = (Get-Date).ToString('yyyyMMdd_HHmmss')

# Stopwatch for elapsed time
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Normalise/validate IncludeExtensions early (copy phase only)
if ($IncludeExtensions) {
    $norm = @()
    foreach ($e in $IncludeExtensions) {
        $candidate = ($e.StartsWith('.')) ? $e : ('.' + $e)
        if ($candidate -notmatch '^\.[A-Za-z0-9]+$') {
            throw "Invalid extension in -IncludeExtensions: '$e' (expected like .jpg, .heic)"
        }
        $norm += $candidate.ToLowerInvariant()
    }
    $IncludeExtensions = $norm | Select-Object -Unique
}

# endregion ----------------------------------------------------------------------------------------

# region: Helpers ---------------------------------------------------------------------------------

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-ErrTrack {
    param([string]$Message)
    $script:ErrCount++
    $script:ErrList.Add($Message) | Out-Null
    Write-Error $Message
}

function Initialize-Directories {
    <#
    .SYNOPSIS
        Validates source and ensures destination exists.
    .PARAMETER SourceDir
        Path to validate.
    .PARAMETER DestDir
        Path to create if missing.
    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true)][string]$SourceDir,
        [Parameter(Mandatory=$true)][string]$DestDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "SourceDir not found or not a directory: $SourceDir"
    }

    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($DestDir, "Create destination directory")) {
            try {
                New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                $script:RootDirsCreated++
                Write-Info "Created destination directory: $DestDir"
            } catch {
                throw "Failed to create DestDir '$DestDir': $($_.Exception.Message)"
            }
        }
    }
}

function Get-SourceFiles {
    <#
    .SYNOPSIS
        Retrieves source files with optional extension filtering for the copy phase.
    .PARAMETER SourceDir
        Root directory to enumerate.
    .PARAMETER IncludeExtensions
        Optional list of extensions (e.g., '.jpg','.heic'). Case-insensitive.
        Note: The .jpeg → .jpg rename phase always considers .jpeg, regardless of this filter.
    .OUTPUTS
        [System.IO.FileInfo[]]
    #>
    param(
        [Parameter(Mandatory=$true)][string]$SourceDir,
        [string[]]$IncludeExtensions
    )

    $files = Get-ChildItem -LiteralPath $SourceDir -File -Recurse

    if ($IncludeExtensions -and $IncludeExtensions.Count -gt 0) {
        $files = $files | Where-Object {
            $IncludeExtensions -contains $_.Extension.ToLowerInvariant()
        }
    }

    return ,$files
}

function Rename-JpegFiles {
    <#
    .SYNOPSIS
        Renames .jpeg files to .jpg with robust error handling and optional progress.
    .PARAMETER Files
        Files to evaluate for renaming (typically only .jpeg).
    .PARAMETER ShowProgress
        If set, shows Write-Progress and completes it at the end.
    .OUTPUTS
        [int] Renamed count
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$Files,
        [switch]$ShowProgress
    )

    if (-not $Files -or $Files.Count -eq 0) {
        if ($ShowProgress) { Write-Progress -Activity "Renaming .jpeg → .jpg" -Completed }
        return 0
    }

    $total = $Files.Count
    $i = 0

    foreach ($f in $Files) {
        $i++

        if ($ShowProgress) {
            $pct = [int]([math]::Floor(100 * $i / $total))
            Write-Progress -Activity "Renaming .jpeg → .jpg" -Status "[$i/$total] $($f.Name)" -PercentComplete $pct
        }

        try {
            if ($f.Extension -ieq '.jpeg') {
                $target = Join-Path -Path $f.DirectoryName -ChildPath ($f.BaseName + '.jpg')
                if (Test-Path -LiteralPath $target) {
                    Write-Verbose "Skip rename; target exists: $target"
                    continue
                }

                if ($PSCmdlet.ShouldProcess($f.FullName, "Rename to $target")) {
                    Rename-Item -LiteralPath $f.FullName -NewName ([System.IO.Path]::GetFileName($target)) -ErrorAction Stop
                    $script:RenamedCount++
                    Write-Verbose "Renamed: $($f.FullName) -> $target"
                }
            }
        } catch {
            Write-ErrTrack "Rename failed: '$($f.FullName)' → '.jpg' : $($_.Exception.Message)"
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Renaming .jpeg → .jpg" -Completed
    }

    return $script:RenamedCount
}

function Copy-FilesToBatches {
    <#
    .SYNOPSIS
        Copies files into per-extension, size-limited subfolders with robust error
        handling and optional progress, then deletes the source file on success.
    .PARAMETER Files
        Files to copy.
    .PARAMETER DestDir
        Destination root directory.
    .PARAMETER FilesPerFolderLimit
        Max files per extension subfolder (0 or less = unlimited).
    .PARAMETER ShowProgress
        If set, shows Write-Progress and completes it at the end.
    .OUTPUTS
        [int] Copied count
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$Files,
        [Parameter(Mandatory=$true)][string]$DestDir,
        [Parameter(Mandatory=$true)][int]$FilesPerFolderLimit,
        [switch]$ShowProgress
    )

    if (-not $Files -or $Files.Count -eq 0) {
        if ($ShowProgress) { Write-Progress -Activity "Copying to batches" -Completed }
        return 0
    }

    $total = $Files.Count
    $i = 0
    if (-not $script:ExtBatchState) { $script:ExtBatchState = @{} }

    foreach ($f in $Files) {
        $i++

        if ($ShowProgress) {
            $pct = [int]([math]::Floor(100 * $i / $total))
            Write-Progress -Activity "Copying to batches" -Status "[$i/$total] $($f.Name)" -PercentComplete $pct
        }

        try {
            $ext = $f.Extension.ToLowerInvariant()

            # RULE 1: Skip all .png files
            if ($ext -eq '.png') { Write-Verbose "Skip PNG: $($f.FullName)"; continue }

            # RULE 2: For .jpg, only allow names starting with 'img' (case-sensitive)
            if ($ext -eq '.jpg') {
                $nameOnly = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
                if ($nameOnly -cnotmatch '^img') {
                    Write-Verbose "Skip JPG not starting with 'img': $($f.Name)"
                    continue
                }
            }

            # Determine extension stem (without dot)
            $extStem = ($ext.StartsWith('.')) ? $ext.Substring(1) : $ext

            # Root folder for this extension
            $extRoot = Join-Path -Path $DestDir -ChildPath ("{0}_{1}_{2}" -f $BatchPrefix, $script:RunStamp, $extStem)

            # Per-extension state: Index (counter), Current (current dir), Count (files in current dir)
            if (-not $script:ExtBatchState.ContainsKey($extStem)) {
                $script:ExtBatchState[$extStem] = [pscustomobject]@{ Index = 0; Current = $null; Count = 0 }
            }
            $state = $script:ExtBatchState[$extStem]

            # Ensure current extension folder exists
            if (-not $state.Current) {
                $state.Current = Join-Path -Path $extRoot -ChildPath ("{0}_{1:D4}" -f $extStem, $state.Index)
                if (-not (Test-Path -LiteralPath $state.Current)) {
                    if ($PSCmdlet.ShouldProcess($state.Current, "Create extension batch directory")) {
                        New-Item -ItemType Directory -Path $state.Current -Force | Out-Null
                        $script:BatchDirsCreated++
                        Write-Verbose "Created directory: $($state.Current)"
                    }
                }
                $state.Count = (Get-ChildItem -LiteralPath $state.Current -File | Measure-Object).Count
            }

            # If limit reached (when > 0), roll to next folder
            if ($FilesPerFolderLimit -gt 0 -and $state.Count -ge $FilesPerFolderLimit) {
                $state.Index++
                $state.Current = Join-Path -Path $extRoot -ChildPath ("{0}_{1:D4}" -f $extStem, $state.Index)
                if (-not (Test-Path -LiteralPath $state.Current)) {
                    if ($PSCmdlet.ShouldProcess($state.Current, "Create extension batch directory")) {
                        New-Item -ItemType Directory -Path $state.Current -Force | Out-Null
                        $script:BatchDirsCreated++
                        Write-Verbose "Created directory: $($state.Current)"
                    }
                }
                $state.Count = 0
            }

            $targetPath = Join-Path -Path $state.Current -ChildPath $f.Name

            if ($PSCmdlet.ShouldProcess($f.FullName, "Copy to $targetPath then delete source")) {
                Copy-Item -LiteralPath $f.FullName -Destination $targetPath -Force -ErrorAction Stop
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $script:CopiedCount++
                $state.Count++
                # Per-extension count
                if (-not $script:CopiedByExt.ContainsKey($extStem)) { $script:CopiedByExt[$extStem] = 0 }
                $script:CopiedByExt[$extStem]++
                Write-Verbose "Copied+Deleted: $($f.FullName) -> $targetPath"
            }
        } catch {
            Write-ErrTrack "Copy/Delete failed: '$($f.FullName)' : $($_.Exception.Message)"
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Copying to batches" -Completed
    }

    return $script:CopiedCount
}

function Write-RunSummary {
    <#
    .SYNOPSIS
        Writes a human-friendly summary and persists errors to a log when present.
    .PARAMETER TotalFiles
        Total number of files processed post-rename.
    .PARAMETER Renamed
        How many .jpeg → .jpg renames occurred.
    .PARAMETER Copied
        How many files were copied (and deleted from source).
    .PARAMETER BatchDirsCreated
        How many per-extension directories were created.
    .PARAMETER RootDirsCreated
        How many root/log-related directories were created.
    .PARAMETER ErrCount
        Number of errors encountered.
    .PARAMETER DestDir
        Destination directory (used for default log creation).
    .PARAMETER LogFilePath
        Optional explicit log file path (validated/created if needed).
    .PARAMETER Elapsed
        [TimeSpan] The total execution time to display.
    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [int]$TotalFiles,
        [int]$Renamed,
        [int]$Copied,
        [int]$BatchDirsCreated,
        [int]$RootDirsCreated,
        [int]$ErrCount,
        [string]$DestDir,
        [string]$LogFilePath,
        [TimeSpan]$Elapsed
    )

    $totalDirs = $BatchDirsCreated + $RootDirsCreated

@"
==================== SUMMARY ====================
Total files processed : $TotalFiles
Renamed (.jpeg→.jpg)  : $Renamed
Copied (then deleted) : $Copied
Directories created   : $totalDirs (batch=$BatchDirsCreated, root/log=$RootDirsCreated)
Errors                : $ErrCount
Elapsed time          : {0:c}
"@ -f $Elapsed | Write-Host

    if ($script:CopiedByExt.Count -gt 0) {
        Write-Host "Per-extension copied counts:"
        $script:CopiedByExt.GetEnumerator() | Sort-Object Key | ForEach-Object {
            "{0,-10} : {1,8}" -f $_.Key, $_.Value | Write-Host
        }
    }

    Write-Host "================================================="

    if ($ErrCount -gt 0) {
        try {
            $resolvedLogPath = $LogFilePath
            if (-not $resolvedLogPath) {
                $resolvedLogPath = Join-Path -Path $DestDir -ChildPath ("picconvert_errors_{0}.log" -f $script:RunStamp)
            }

            # Ensure directory exists & is writable
            $logDir = Split-Path -Path $resolvedLogPath -Parent
            if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
                if ($PSCmdlet.ShouldProcess($logDir, "Create log directory")) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                    $script:RootDirsCreated++
                    Write-Verbose "Created log directory: $logDir"
                }
            }

            # Writability probe
            $probe = Join-Path $logDir ("._probe_{0}.tmp" -f [Guid]::NewGuid())
            "probe" | Out-File -FilePath $probe -Encoding UTF8
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue

            # Write the actual log
            "[{0}] Error details (count={1})" -f (Get-Date), $ErrCount | Out-File -FilePath $resolvedLogPath -Encoding UTF8
            $script:ErrList | Out-File -FilePath $resolvedLogPath -Append -Encoding UTF8
            Write-Warn "Errors were logged to: $resolvedLogPath"
        } catch {
            Write-Warn "Failed to write error log to '$resolvedLogPath': $($_.Exception.Message)"
        }
    }
}

# endregion ----------------------------------------------------------------------------------------

# region: Main ------------------------------------------------------------------------------------

try {
    Write-Info "Starting picconvert 1.1.2"
    Initialize-Directories -SourceDir $SourceDir -DestDir $DestDir

    # Phase 1: Gather all source files (for rename); always include .jpeg in consideration
    $allFiles = Get-ChildItem -LiteralPath $SourceDir -File -Recurse

    # Rename pass focuses only on .jpeg files (case-insensitive)
    $jpegFiles = $allFiles | Where-Object { $_.Extension -ieq '.jpeg' }
    if ($jpegFiles.Count -gt 0) {
        Write-Info "Renaming .jpeg files to .jpg (count: $($jpegFiles.Count)) ..."
        [void](Rename-JpegFiles -Files $jpegFiles -ShowProgress:$ShowProgress)
    } else {
        Write-Info "No .jpeg files found to rename."
    }

    # Phase 2: Refresh file list post-rename for the copy phase (respect -IncludeExtensions here)
    $postRenameFiles = Get-SourceFiles -SourceDir $SourceDir -IncludeExtensions $IncludeExtensions
    $totalAfter = $postRenameFiles.Count
    Write-Info "Files considered for copy after rename step: $totalAfter"

    # Phase 3: Copy into per-extension subfolders (with rules and deletion)
    if ($totalAfter -gt 0) {
        Write-Info "Copying files into extension-based subfolders under: $DestDir (Limit: $FilesPerFolderLimit)"
        [void](Copy-FilesToBatches -Files $postRenameFiles -DestDir $DestDir -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress)
    } else {
        Write-Info "No files found to copy."
    }

    # Stop timer and summarize
    $sw.Stop()
    Write-RunSummary -TotalFiles $totalAfter `
                     -Renamed $script:RenamedCount `
                     -Copied $script:CopiedCount `
                     -BatchDirsCreated $script:BatchDirsCreated `
                     -RootDirsCreated $script:RootDirsCreated `
                     -ErrCount $script:ErrCount `
                     -DestDir $DestDir `
                     -LogFilePath $LogFilePath `
                     -Elapsed $sw.Elapsed

} catch {
    $sw.Stop()
    Write-ErrTrack "Fatal: $($_.Exception.Message)"
    Write-RunSummary -TotalFiles 0 `
                     -Renamed $script:RenamedCount `
                     -Copied $script:CopiedCount `
                     -BatchDirsCreated $script:BatchDirsCreated `
                     -RootDirsCreated $script:RootDirsCreated `
                     -ErrCount $script:ErrCount `
                     -DestDir $DestDir `
                     -LogFilePath $LogFilePath `
                     -Elapsed $sw.Elapsed
    exit 1
}

# endregion ----------------------------------------------------------------------------------------
