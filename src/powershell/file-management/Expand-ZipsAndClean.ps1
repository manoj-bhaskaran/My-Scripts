#requires -Version 7.0
<#
.SYNOPSIS
    Unzips all .zip files from a source folder into a destination folder, moves the .zip files
    to the parent of the source folder, and (optionally) deletes/cleans the source folder.
    Prints a summary at the end.

.DESCRIPTION
    Typical workflow:
      - Source folder (example): $HOME\Downloads\picconvert   (or $env:EXPAND_ZIPS_SOURCE_DIR)
      - Destination folder (example): $HOME\Desktop\New folder (or $env:EXPAND_ZIPS_DEST_DIR)
      - After extraction, all .zip files in the source are moved to the source’s parent
        (example: $HOME\Downloads)
      - Optionally delete/clean the source folder using -DeleteSource (switch) and
        optionally -CleanNonZips to remove non-zip leftovers.

    Highlights
    - Handles unusually long & special-character file names via -LiteralPath and safe naming.
    - Extraction modes:
        * PerArchiveSubfolder (default): each .zip to its own subfolder (avoids collisions).
          If the subfolder exists, a unique folder name is created (timestamped).
        * Flat: STREAMING extraction via ZipArchive (no temp folder). Collisions handled
          per CollisionPolicy before writing each file (Skip/Overwrite/Rename).
    - CollisionPolicy (for overlapping paths in Flat mode AND for the zip-move-to-parent step):
        * Skip | Overwrite | Rename (default: Rename)
    - Progress bars for long runs (suppressed by -Quiet). Move progress shows cumulative AND total bytes.
    - End-of-run summary includes uncompressed bytes, total compressed zip bytes, and compression ratio.
      (CompressionRatio > 1.0 means the original content is larger than the archives; compression saved space.)
    - Robust error handling and diagnostics (WhatIf/Confirm; -Verbose); clearer message if an
      archive appears to be password-protected.

.PARAMETER SourceDirectory
    Directory containing .zip files to extract (default override via EXPAND_ZIPS_SOURCE_DIR).
    Default resolved in order:
      1. Environment variable EXPAND_ZIPS_SOURCE_DIR (if set, non-null, and non-blank)
      2. Join-Path $HOME 'Downloads/picconvert'
    Blank or whitespace-only values for EXPAND_ZIPS_SOURCE_DIR are treated as unset
    and the profile-relative fallback is used instead.

.PARAMETER DestinationDirectory
    Directory to extract contents into (default override via EXPAND_ZIPS_DEST_DIR).
    Default resolved in order:
      1. Environment variable EXPAND_ZIPS_DEST_DIR (if set, non-null, and non-blank)
      2. Join-Path $HOME 'Desktop/New folder'
    Blank or whitespace-only values for EXPAND_ZIPS_DEST_DIR are treated as unset
    and the profile-relative fallback is used instead.

.PARAMETER ExtractMode
    Extraction strategy. One of:
      - PerArchiveSubfolder (default)
      - Flat   (streams entries directly without temp folder; collisions handled per policy)

.PARAMETER CollisionPolicy
    Behavior when a target file or zip already exists. Applied during both the
    extraction phase and the zip-move-to-parent phase:
      - Skip       : leave the existing item untouched; skip the incoming file/zip.
                     Skipped zip count is reported in the summary.
      - Overwrite  : replace the existing item (Move-Item -Force for zips; direct
                     write for extracted files).
      - Rename     : save the incoming item with a unique suffix (default behavior).
    Default: Rename

.PARAMETER DeleteSource
    Switch. If present, deletes the source directory after zips are moved and,
    if -CleanNonZips is also set, after non-zip items are removed. If leftovers remain
    and -CleanNonZips is not specified, deletion is skipped with a warning that
    distinguishes between "non-zip files present" and "only empty subdirectories remain".

.PARAMETER CleanNonZips
    Switch. If present (and -DeleteSource is also specified), deletes non-zip items remaining
    in the source directory before deleting the source directory, processing paths deepest-first
    to avoid "directory not empty" errors on nested trees. Without this switch, the
    script will WARN and list remaining items instead of deleting.

.PARAMETER MaxSafeNameLength
    Optional maximum length for generated safe names (e.g., subfolder names derived from zip files).
    0 (default) means no truncation. Use a positive value (e.g., 200) to cap names in edge cases.
    255 aligns with common NTFS filename component limits.

.PARAMETER Quiet
    Suppress non-essential console output and progress (summary still prints).

.PARAMETER ThrottleLimit
    Maximum number of archives to extract concurrently. Default is 1 (serial).
    Set to 2 or more to enable ForEach-Object -Parallel extraction on PS 7+.
    Values above [Environment]::ProcessorCount trigger a performance warning.
    When -WhatIf is active, extraction automatically falls back to serial mode
    so that -WhatIf/-Confirm are honoured correctly.

.EXAMPLE
    # Run with defaults (robust mode with per-archive subfolders)
    .\Expand-ZipsAndClean.ps1

.EXAMPLE
    # Extract all zips into one flat folder, overwrite collisions, show verbose logs
    .\Expand-ZipsAndClean.ps1 -ExtractMode Flat -CollisionPolicy Overwrite -Verbose

.EXAMPLE
    # Delete the source folder after processing (and also delete any non-zip leftovers)
    .\Expand-ZipsAndClean.ps1 -DeleteSource -CleanNonZips

.EXAMPLE
    # Limit generated subfolder names to 200 characters (defensive) and show truncation via -Verbose
    .\Expand-ZipsAndClean.ps1 -MaxSafeNameLength 200 -Verbose

.EXAMPLE
    # Extract using 4 parallel workers (faster when processing many archives on a multi-core system with fast storage)
    .\Expand-ZipsAndClean.ps1 -ThrottleLimit 4

.EXAMPLE
    # Dry run (no changes), show what would happen
    .\Expand-ZipsAndClean.ps1 -WhatIf

.INPUTS
    None.

.OUTPUTS
    Summary is written to the host at the end. Errors are collected and summarized.

.NOTES
    Name     : Expand-ZipsAndClean.ps1
    Version  : 2.6.17
    Author   : Manoj Bhaskaran
    Requires : PowerShell 7+ (uses ternary operator, null-coalescing ??, null-conditional ?.,
               and ForEach-Object -Parallel); Microsoft.PowerShell.Archive (Expand-Archive)
               for subfolder mode; System.IO.Compression (ZipArchive) for streaming in Flat mode.

    Parallel extraction notes:
    - Setting -ThrottleLimit to 2+ enables ForEach-Object -Parallel.
    - Values above [Environment]::ProcessorCount can reduce performance due to I/O contention.
    - When -WhatIf/-Confirm is active, extraction falls back to serial mode so ShouldProcess is honoured.
    - Logging is buffered per runspace and flushed serially after parallel extraction.

    Version history has moved to:
    - src/powershell/file-management/Expand-ZipsAndClean.CHANGELOG.md
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [Alias('Src')]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory = ([string]::IsNullOrWhiteSpace($env:EXPAND_ZIPS_SOURCE_DIR) ? (Join-Path $HOME 'Downloads/picconvert') : $env:EXPAND_ZIPS_SOURCE_DIR),

    [Parameter()]
    [Alias('Dest')]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationDirectory = ([string]::IsNullOrWhiteSpace($env:EXPAND_ZIPS_DEST_DIR) ? (Join-Path $HOME 'Desktop/New folder') : $env:EXPAND_ZIPS_DEST_DIR),

    [Parameter()]
    [ValidateSet('PerArchiveSubfolder', 'Flat')]
    [string]$ExtractMode = 'PerArchiveSubfolder',

    [Parameter()]
    [ValidateSet('Skip', 'Overwrite', 'Rename')]
    [string]$CollisionPolicy = 'Rename',

    [Parameter()]
    [switch]$DeleteSource,

    [Parameter()]
    [switch]$CleanNonZips,

    [Parameter()]
    [ValidateRange(0, 255)]
    [int]$MaxSafeNameLength = 0,

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [ValidateRange(1, 2147483647)]
    [int]$ThrottleLimit = 1
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\Core\FileSystem\FileSystem.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\Core\Zip\Zip.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\Core\Progress\ProgressReporter.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\Core\FileOperations\FileOperations.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\FileManagement\ZipExtraction\ZipExtraction.psm1" -Force -ErrorAction Stop
Import-Module "$PSScriptRoot\..\modules\FileManagement\ZipWorkflow\ZipWorkflow.psm1" -Force -ErrorAction Stop

$_zipExtractionCmd = Get-Command Invoke-ZipExtractions -ErrorAction SilentlyContinue
if (-not $_zipExtractionCmd -or $_zipExtractionCmd.Source -ne 'ZipExtraction') {
    throw "ZipExtraction module failed to import."
}
Remove-Variable _zipExtractionCmd

# Initialize logger (script name will be extracted from the script file name)
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

if ($ThrottleLimit -gt [Environment]::ProcessorCount) {
    Write-Warning "ThrottleLimit ($ThrottleLimit) exceeds the logical processor count ($([Environment]::ProcessorCount)). Consider reducing it to avoid scheduling overhead."
}


#------------------------------- Main -------------------------------#

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$errors = [System.Collections.Generic.List[string]]::new()

# State for summary
$zipCount = 0
$processedZips = 0
$totalFilesExtracted = 0
$totalUncompressedBytes = [int64]0
$totalCompressedZipBytes = [int64]0
$moveSummary = [pscustomobject]@{ Count = 0; Bytes = 0; Destination = ""; Skipped = 0; Overwritten = 0; Renamed = 0 }

try {
    ZipWorkflow\Test-ScriptPreconditions -SourceDir $SourceDirectory -DestinationDir $DestinationDirectory
    ZipWorkflow\Initialize-Destination -DestinationDir $DestinationDirectory

    $extractionResult = ZipExtraction\Invoke-ZipExtractions `
        -SourceDir $SourceDirectory `
        -DestinationDir $DestinationDirectory `
        -Mode $ExtractMode `
        -Policy $CollisionPolicy `
        -SafeNameMaxLen $MaxSafeNameLength `
        -QuietMode $Quiet.IsPresent `
        -ErrorList $errors `
        -ThrottleLimit $ThrottleLimit

    $zipCount = $extractionResult.ZipCount
    $processedZips = $extractionResult.ProcessedZips
    $totalFilesExtracted = $extractionResult.FilesExtracted
    $totalUncompressedBytes = $extractionResult.UncompressedBytes
    $totalCompressedZipBytes = $extractionResult.CompressedBytes

    try {
        if ($PSCmdlet.ShouldProcess($SourceDirectory, "Move .zip files to parent")) {
            $moveSummary = ZipWorkflow\Move-ZipFilesToParent -SourceDir $SourceDirectory -QuietMode $Quiet.IsPresent -CollisionPolicy $CollisionPolicy
        }
    } catch {
        $msg = "Moving .zip files to parent failed: $($_.Exception.Message)"
        Write-LogDebug $msg
        $errors.Add($msg) | Out-Null
    }

    FileSystem\Remove-SourceDirectory `
        -SourceDir $SourceDirectory `
        -ShouldDeleteSource $DeleteSource.IsPresent `
        -ShouldCleanNonZips $CleanNonZips.IsPresent `
        -ErrorList $errors

} catch {
    $errors.Add("Fatal error: $($_.Exception.Message)") | Out-Null
} finally {
    $stopwatch.Stop()
}

#------------------------------ Summary -----------------------------#

ProgressReporter\Write-ExtractionSummary `
    -SourceDirectory    $SourceDirectory `
    -DestinationDirectory $DestinationDirectory `
    -ExtractMode        $ExtractMode `
    -CollisionPolicy    $CollisionPolicy `
    -ZipCount           $zipCount `
    -ProcessedZips      $processedZips `
    -FilesExtracted     $totalFilesExtracted `
    -UncompressedBytes  $totalUncompressedBytes `
    -CompressedBytes    $totalCompressedZipBytes `
    -MoveSummary        $moveSummary `
    -Errors             $errors `
    -Elapsed            $stopwatch.Elapsed

# End of script
