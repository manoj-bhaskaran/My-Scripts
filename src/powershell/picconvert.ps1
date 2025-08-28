<#
.SYNOPSIS
    Renames *.jpeg to *.jpg and copies files from a source tree into
    size-limited subfolders at the destination, with progress, robust
    error handling, and a clear summary.

.DESCRIPTION
    Typical use-cases:
      - Normalise image extensions (.jpeg → .jpg) across a large photo library.
      - Copy a large set of files into "sharded" subfolders (e.g., 200 files
        per folder) for easier browsing, backup, or transfer.
      - Get reliable progress, input validation, and a final summary with totals.

    What it does:
      1) Input validation and destination bootstrap (creates the destination).
      2) Renames files with a .jpeg extension to .jpg (case-insensitive).
         - Skips renaming if the resulting .jpg already exists.
         - Uses robust try/catch and tracks errors.
         - Optional progress via Write-Progress.
      3) Copies all files (post-rename) into numbered subfolders at the destination,
         each capped at FilesPerFolderLimit files (e.g., batch_0000, batch_0001, …).
         - Continues creating new batch folders as limits are reached.
         - Robust try/catch and error tracking; optional progress.
      4) Prints a comprehensive summary at the end:
         - Total files processed
         - Renamed count (.jpeg → .jpg)
         - Copied count
         - Number of directories created
         - Error count (and writes a detailed error log if any)

.PARAMETER SourceDir
    Source directory to scan (recursively). Must exist.

.PARAMETER DestDir
    Destination directory. Will be created if missing. Batch subfolders
    (batch_0000, batch_0001, ...) are created under this path.

.PARAMETER FilesPerFolderLimit
    Maximum number of files per batch subfolder. Default: 2000.
    Use a positive integer. If 0 or less is supplied, the script treats it as unlimited.

.PARAMETER ShowProgress
    If set, displays Write-Progress for the renaming and copying phases.

.PARAMETER IncludeExtensions
    Optional list of file extensions to include (e.g., '.jpg','.jpeg','.png').
    Defaults to all files when not supplied. Extensions are case-insensitive.
    Note: .jpeg files are always considered for the rename phase, even if this
    filter excludes them; the filter applies to the copy phase.

.PARAMETER LogFilePath
    Optional path to a log file. If provided, detailed errors are also appended here.
    If omitted and errors occur, a file named 'picconvert_errors_yyyyMMdd_HHmmss.log'
    will be created under DestDir.

.INPUTS
    None. You cannot pipe input to this script.

.OUTPUTS
    None. Writes status/progress to the console and a summary at the end.

.EXAMPLE
    .\picconvert.ps1 -SourceDir "D:\Photos\Inbox" -DestDir "E:\Archive" -ShowProgress

.EXAMPLE
    .\picconvert.ps1 -SourceDir "D:\Photos\2024" -DestDir "F:\Media\Photos" `
      -FilesPerFolderLimit 1500 -IncludeExtensions '.jpg','.png' -ShowProgress

.NOTES
    VERSION
      1.1.0

    CHANGELOG
      1.1.0
        - Added param block with configurable Source/Dest/Limit (+ IncludeExtensions, LogFilePath).
        - Implemented robust directory validation and auto-creation of DestDir.
        - Added Write-Progress for rename and copy phases (toggle via -ShowProgress).
        - Introduced modular functions (Initialize-Directories, Get-SourceFiles, Rename-JpegFiles,
          Start-Batch, Copy-FilesToBatches, Write-RunSummary).
        - Comprehensive summary now shows totals, dirs created, and error count.
        - Implemented structured error tracking and optional log file.
        - Added thorough inline comments and PowerShell comment-based help.

      1.0.0
        - Initial version (assumed baseline).

    PREREQUISITES
      - PowerShell 5.1 or 7+ on Windows.
      - Read access to SourceDir, write access to DestDir.

    TROUBLESHOOTING
      - If the script reports "SourceDir not found", check the path and permissions.
      - If copies fail due to access being denied, verify you have permission to read
        source files and write to the destination drive.
      - If existing .jpg prevents rename of .jpeg, the script logs and skips safely.
      - For performance, avoid running antivirus scans on DestDir during heavy copies.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDir,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestDir,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 10000000)]
    [int]$FilesPerFolderLimit = 200,

    [Parameter(Mandatory=$false)]
    [switch]$ShowProgress,

    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string[]]$IncludeExtensions,

    [Parameter(Mandatory=$false)]
    [string]$LogFilePath
)

# region: Globals / State -------------------------------------------------------------------------

# Fail fast inside try/catch blocks
$ErrorActionPreference = 'Stop'

# Counters and tracking
$script:ErrList      = New-Object System.Collections.Generic.List[string]
$script:ErrCount     = 0
$script:RenamedCount = 0
$script:CopiedCount  = 0
$script:DirsCreated  = 0

# Create a timestamp for logs
$script:RunStamp = (Get-Date).ToString('yyyyMMdd_HHmmss')

# endregion ----------------------------------------------------------------------------------------

# region: Helpers ---------------------------------------------------------------------------------

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Warning $Message
}

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
                $script:DirsCreated++
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
        Retrieves source files with optional extension filtering.
    .PARAMETER SourceDir
        Root directory to enumerate.
    .PARAMETER IncludeExtensions
        Optional list of extensions (e.g., '.jpg','.png'). Case-insensitive.
    .OUTPUTS
        [System.IO.FileInfo[]]
    #>
    param(
        [Parameter(Mandatory=$true)][string]$SourceDir,
        [string[]]$IncludeExtensions
    )

    $files = Get-ChildItem -LiteralPath $SourceDir -File -Recurse

    if ($IncludeExtensions -and $IncludeExtensions.Count -gt 0) {
        # Normalise extensions to lower-case and ensure they start with '.'
        $normalized = $IncludeExtensions | ForEach-Object {
            if ($_ -notmatch '^\.') { ".$_" } else { $_ }
        } | ForEach-Object { $_.ToLowerInvariant() }

        $files = $files | Where-Object {
            $normalized -contains $_.Extension.ToLowerInvariant()
        }
    }

    return ,$files
}

function Rename-JpegFiles {
    <#
    .SYNOPSIS
        Renames .jpeg files to .jpg with robust error handling and optional progress.
    .PARAMETER Files
        Files to evaluate for renaming.
    .PARAMETER ShowProgress
        If set, shows Write-Progress.
    .OUTPUTS
        [int] Renamed count
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$Files,
        [switch]$ShowProgress
    )

    if (-not $Files -or $Files.Count -eq 0) { return 0 }

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
                    Write-Warn "Skip rename; target exists: $target"
                    continue
                }

                if ($PSCmdlet.ShouldProcess($f.FullName, "Rename to $target")) {
                    Rename-Item -LiteralPath $f.FullName -NewName ([System.IO.Path]::GetFileName($target)) -ErrorAction Stop
                    $script:RenamedCount++
                }
            }
        } catch {
            Write-ErrTrack "Rename failed: '$($f.FullName)' → '.jpg' : $($_.Exception.Message)"
        }
    }

    return $script:RenamedCount
}

function Start-Batch {
    <#
    .SYNOPSIS
        Ensures a batch folder exists (batch_####) and returns its path and current count.
    .PARAMETER DestDir
        Root destination directory.
    .PARAMETER BatchIndex
        Which batch number to create.
    .OUTPUTS
        [pscustomobject] @{ Path=..., Count=... }
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true)][string]$DestDir,
        [Parameter(Mandatory=$true)][int]$BatchIndex
    )

    $batchName = ('batch_{0:D4}' -f $BatchIndex)
    $batchPath = Join-Path -Path $DestDir -ChildPath $batchName

    if (-not (Test-Path -LiteralPath $batchPath -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($batchPath, "Create batch directory")) {
            try {
                New-Item -ItemType Directory -Path $batchPath -Force | Out-Null
                $script:DirsCreated++
                Write-Info "Created: $batchPath"
            } catch {
                throw "Failed to create batch folder '$batchPath': $($_.Exception.Message)"
            }
        }
    }

    # Count existing files in this batch to continue from there
    $existingCount = (Get-ChildItem -LiteralPath $batchPath -File | Measure-Object).Count
    return [pscustomobject]@{ Path = $batchPath; Count = $existingCount }
}

function Copy-FilesToBatches {
    <#
    .SYNOPSIS
        Copies files into size-limited batch folders with robust error handling and optional progress.
    .PARAMETER Files
        Files to copy.
    .PARAMETER DestDir
        Destination root directory.
    .PARAMETER FilesPerFolderLimit
        Max files per batch folder (0 or less = unlimited).
    .PARAMETER ShowProgress
        If set, shows Write-Progress.
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

    if (-not $Files -or $Files.Count -eq 0) { return 0 }

    $total = $Files.Count
    $i = 0
    $batchIndex = 0
    $batch = Start-Batch -DestDir $DestDir -BatchIndex $batchIndex

    foreach ($f in $Files) {
        $i++

        if ($ShowProgress) {
            $pct = [int]([math]::Floor(100 * $i / $total))
            Write-Progress -Activity "Copying to batches" -Status "[$i/$total] $($f.Name)" -PercentComplete $pct
        }

        try {
            # Move to a new batch if limit reached (only when limit > 0)
            if ($FilesPerFolderLimit -gt 0 -and $batch.Count -ge $FilesPerFolderLimit) {
                $batchIndex++
                $batch = Start-Batch -DestDir $DestDir -BatchIndex $batchIndex
            }

            $targetPath = Join-Path -Path $batch.Path -ChildPath $f.Name

            if ($PSCmdlet.ShouldProcess($f.FullName, "Copy to $targetPath")) {
                Copy-Item -LiteralPath $f.FullName -Destination $targetPath -Force -ErrorAction Stop
                $script:CopiedCount++
                $batch.Count++  # keep an in-memory counter to avoid repeated enumeration
            }
        } catch {
            Write-ErrTrack "Copy failed: '$($f.FullName)' → '$targetPath' : $($_.Exception.Message)"
        }
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
        How many files were copied.
    .PARAMETER DirsCreated
        How many directories were created in this run.
    .PARAMETER ErrCount
        Number of errors encountered.
    .PARAMETER DestDir
        Destination directory (used for default log creation).
    .PARAMETER LogFilePath
        Optional explicit log file path.
    .OUTPUTS
        None
    #>
    param(
        [int]$TotalFiles,
        [int]$Renamed,
        [int]$Copied,
        [int]$DirsCreated,
        [int]$ErrCount,
        [string]$DestDir,
        [string]$LogFilePath
    )

@"
==================== SUMMARY ====================
Total files processed : $TotalFiles
Renamed (.jpeg→.jpg)  : $Renamed
Copied                : $Copied
Directories created   : $DirsCreated
Errors                : $ErrCount
=================================================
"@ | Write-Host

    if ($ErrCount -gt 0) {
        try {
            $logPath = $LogFilePath
            if (-not $logPath) {
                $logPath = Join-Path -Path $DestDir -ChildPath ("picconvert_errors_{0}.log" -f $script:RunStamp)
            }

            "[{0}] Error details (count={1})" -f (Get-Date), $ErrCount | Out-File -FilePath $logPath -Encoding UTF8
            $script:ErrList | Out-File -FilePath $logPath -Append -Encoding UTF8
            Write-Warn "Errors were logged to: $logPath"
        } catch {
            Write-Warn "Failed to write error log: $($_.Exception.Message)"
        }
    }
}

# endregion ----------------------------------------------------------------------------------------

# region: Main ------------------------------------------------------------------------------------

try {
    Write-Info "Starting picconvert 1.1.0"
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

    # Phase 2: Refresh file list post-rename for the copy phase
    $postRenameFiles = Get-SourceFiles -SourceDir $SourceDir -IncludeExtensions $IncludeExtensions
    $totalAfter = $postRenameFiles.Count
    Write-Info "Files to copy after rename step: $totalAfter"

    # Phase 3: Copy into batch folders
    if ($totalAfter -gt 0) {
        Write-Info "Copying files into batches under: $DestDir (Limit: $FilesPerFolderLimit)"
        [void](Copy-FilesToBatches -Files $postRenameFiles -DestDir $DestDir -FilesPerFolderLimit $FilesPerFolderLimit -ShowProgress:$ShowProgress)
    } else {
        Write-Info "No files found to copy."
    }

    # Summary
    Write-RunSummary -TotalFiles $totalAfter `
                     -Renamed $script:RenamedCount `
                     -Copied $script:CopiedCount `
                     -DirsCreated $script:DirsCreated `
                     -ErrCount $script:ErrCount `
                     -DestDir $DestDir `
                     -LogFilePath $LogFilePath

} catch {
    Write-ErrTrack "Fatal: $($_.Exception.Message)"
    Write-RunSummary -TotalFiles 0 `
                     -Renamed $script:RenamedCount `
                     -Copied $script:CopiedCount `
                     -DirsCreated $script:DirsCreated `
                     -ErrCount $script:ErrCount `
                     -DestDir $DestDir `
                     -LogFilePath $LogFilePath
    exit 1
}

# endregion ----------------------------------------------------------------------------------------
