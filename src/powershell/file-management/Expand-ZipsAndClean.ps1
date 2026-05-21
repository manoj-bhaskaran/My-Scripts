#requires -Version 7.0
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

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
    Directory containing .zip files to extract.
    Default resolved in order:
      1. Environment variable EXPAND_ZIPS_SOURCE_DIR (if set, non-null, and non-blank)
      2. Join-Path $HOME 'Downloads/picconvert'
    Blank or whitespace-only values for EXPAND_ZIPS_SOURCE_DIR are treated as unset
    and the profile-relative fallback is used instead.

.PARAMETER DestinationDirectory
    Directory to extract contents into.
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
    Version  : 2.5.2
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
    [string]$SourceDirectory = ($env:EXPAND_ZIPS_SOURCE_DIR ? $env:EXPAND_ZIPS_SOURCE_DIR : (Join-Path $HOME 'Downloads/picconvert')),

    [Parameter()]
    [Alias('Dest')]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationDirectory = ($env:EXPAND_ZIPS_DEST_DIR ? $env:EXPAND_ZIPS_DEST_DIR : (Join-Path $HOME 'Desktop/New folder')),

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
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\FileSystem\FileSystem.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\Zip\Zip.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\Progress\ProgressReporter.psm1" -Force

# Initialize logger (script name will be extracted from the script file name)
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

if ($ThrottleLimit -gt [Environment]::ProcessorCount) {
    Write-Warning "ThrottleLimit ($ThrottleLimit) exceeds the logical processor count ($([Environment]::ProcessorCount)). Consider reducing it to avoid scheduling overhead."
}

#region Helpers

<#
.SYNOPSIS
    Centralized Write-Progress wrapper that respects -Quiet mode.
.DESCRIPTION
    Consolidates percentage math and -Quiet suppression for all phase progress bars.
    Callers pass raw Current/Total counts; the helper computes PercentComplete.
.PARAMETER Activity
    The progress-bar activity label.
.PARAMETER Status
    The status message shown on the progress bar.
.PARAMETER Current
    Current item index used to compute the percentage complete.
.PARAMETER Total
    Total item count (denominator for percentage).
.PARAMETER QuietMode
    When $true, all progress output is suppressed and the function returns immediately.
.PARAMETER CurrentOperation
    Optional sub-operation text shown beneath the status line.
.PARAMETER Completed
    Switch. When set, closes the named progress bar instead of updating it.
#>
<#
.SYNOPSIS
    Validates source/destination safety constraints before any file operations.
#>
function Show-ProgressPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][int]$Current,
        [Parameter(Mandatory)][int]$Total,
        [Parameter(Mandatory)][bool]$QuietMode,
        [string]$CurrentOperation,
        [switch]$Completed
    )

    if ($QuietMode) { return }

    $pct = [int]($Current / [math]::Max(1, $Total) * 100)

    if (Get-Command -Name Show-Progress -ErrorAction SilentlyContinue) {
        Show-Progress -Activity $Activity -Status $Status -PercentComplete $pct `
            -CurrentOperation $CurrentOperation -Completed:$Completed
        return
    }

    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
        return
    }

    $params = @{
        Activity        = $Activity
        Status          = $Status
        PercentComplete = $pct
    }
    if ($CurrentOperation ?? '') {
        $params['CurrentOperation'] = $CurrentOperation
    }
    Write-Progress @params
}

<#
.SYNOPSIS
    Validates source/destination safety constraints before any file operations.
#>
function Test-ScriptPreconditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir
    )

    $srcFull = Get-FullPath -Path $SourceDir
    $dstFull = Get-FullPath -Path $DestinationDir

    if ($srcFull -eq $dstFull) {
        throw "Source and destination cannot be the same: $srcFull"
    }

    if (Test-PathContainment -Container $srcFull -Candidate $dstFull) {
        throw "Destination cannot be inside the source directory."
    }
    if (Test-PathContainment -Container $dstFull -Candidate $srcFull) {
        throw "Source cannot be inside the destination directory."
    }

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source directory not found: $SourceDir"
    }

    if (-not (Test-LongPathsEnabled)) {
        Write-LogDebug "LongPathsEnabled=0; consider enabling to avoid path-length issues."
    }
}

<#
.SYNOPSIS
    Ensures destination root exists before extraction begins.
#>
function Initialize-Destination {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DestinationDir)

    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        if ($PSCmdlet.ShouldProcess($DestinationDir, "Create destination directory")) {
            New-DirectoryIfMissing -Path $DestinationDir -Force | Out-Null
        }
    }
}

<# Builds the standard extraction-summary object returned by all extraction paths. #>
function New-ExtractionSummary {
    param([int]$ZipCount, [int]$ProcessedZips, [int]$FilesExtracted, [int64]$UncompressedBytes, [int64]$CompressedBytes)
    return [pscustomobject]@{
        ZipCount          = $ZipCount
        ProcessedZips     = $ProcessedZips
        FilesExtracted    = $FilesExtracted
        UncompressedBytes = $UncompressedBytes
        CompressedBytes   = $CompressedBytes
    }
}

<#
.SYNOPSIS
    Runs zip extraction inside a ForEach-Object -Parallel runspace.
.NOTES
    Serialized via ${function:Expand-ZipInRunspace} and dot-sourced inside each
    runspace. The logging framework is not thread-safe, so log lines are
    collected in $localLogs and flushed by the caller after the parallel loop.
    I/O contention: concurrent writes to the same DestDir may degrade throughput
    on spinning-disk systems; SSDs and NVMe drives are not materially affected.
#>
function Expand-ZipInRunspace {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$Zip,
        [Parameter(Mandatory)][string]$DestDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$MaxLen,
        [string]$FsModulePath,
        [string]$ZipModulePath,
        [Parameter(Mandatory)][System.Collections.Concurrent.ConcurrentBag[string]]$ErrorBag
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    if ($FsModulePath)  { Import-Module $FsModulePath  -Force }
    if ($ZipModulePath) { Import-Module $ZipModulePath -Force }

    $localLogs = [System.Collections.Generic.List[string]]::new()
    try {
        $stats        = Get-ZipFileStats -ZipPath $Zip.FullName
        $filesFromZip = Expand-ZipSmart -ZipPath $Zip.FullName -DestinationRoot $DestDir `
            -ExtractMode $Mode -CollisionPolicy $Policy -SafeNameMaxLen $MaxLen `
            -ExpectedFileCount $stats.FileCount
        $actualFiles  = ($filesFromZip -is [int]) ? $filesFromZip : $stats.FileCount
        $localLogs.Add("Extracted '$($Zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)")
        return [pscustomobject]@{
            Success           = $true
            FilesExtracted    = $actualFiles
            UncompressedBytes = $stats.UncompressedBytes
            CompressedBytes   = $stats.CompressedBytes
            Logs              = $localLogs.ToArray()
        }
    } catch {
        $ErrorBag.Add("Extraction failed for '$($Zip.FullName)': $($_.Exception.Message)") | Out-Null
        $localLogs.Add("Extraction error for '$($Zip.Name)': $($_.Exception.Message)")
        return [pscustomobject]@{
            Success           = $false
            FilesExtracted    = 0
            UncompressedBytes = [int64]0
            CompressedBytes   = [int64]0
            Logs              = $localLogs.ToArray()
        }
    }
}

<#
.SYNOPSIS
    Aggregates per-runspace results into a single summary object.
#>
function Merge-ParallelZipResults {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList,
        [Parameter(Mandatory)][System.Collections.Concurrent.ConcurrentBag[string]]$ConcurrentErrors
    )
    $processedZips           = 0
    $totalFilesExtracted     = 0
    $totalUncompressedBytes  = [int64]0
    $totalCompressedZipBytes = [int64]0

    foreach ($r in $Results) {
        foreach ($log in $r.Logs) { Write-LogDebug $log }
        if ($r.Success) {
            $processedZips++
            $totalFilesExtracted     += $r.FilesExtracted
            $totalUncompressedBytes  += $r.UncompressedBytes
            $totalCompressedZipBytes += $r.CompressedBytes
        }
    }
    foreach ($e in $ConcurrentErrors) { $ErrorList.Add($e) | Out-Null }
    Write-LogInfo "Parallel extraction complete: $processedZips / $ZipCount archive(s) processed."
    return New-ExtractionSummary -ZipCount $ZipCount -ProcessedZips $processedZips `
        -FilesExtracted $totalFilesExtracted -UncompressedBytes $totalUncompressedBytes `
        -CompressedBytes $totalCompressedZipBytes
}

<#
.SYNOPSIS
    Runs ForEach-Object -Parallel extraction and returns aggregated summary totals.
#>
function Invoke-ParallelZipExtractions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.IO.FileInfo[]]$Zips, [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][string]$DestinationDir,     [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,             [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode,            [Parameter(Mandatory)][int]$ThrottleLimit,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    $concurrentErrors = [ConcurrentBag[string]]::new()
    $fsModulePath     = (Get-Module -Name FileSystem -ErrorAction SilentlyContinue)?.Path
    $zipModulePath    = (Get-Module -Name Zip        -ErrorAction SilentlyContinue)?.Path
    # Serialize the helper so each runspace can dot-source it (session functions are
    # not available in ForEach-Object -Parallel runspaces by default).
    $runspaceFnDef    = "function Expand-ZipInRunspace { ${function:Expand-ZipInRunspace} }"
    $progressCounter  = 0

    $results = @(
        $Zips | ForEach-Object -Parallel {
            . ([ScriptBlock]::Create($using:runspaceFnDef))
            Expand-ZipInRunspace -Zip $_ -DestDir $using:DestinationDir -Mode $using:Mode `
                -Policy $using:Policy -MaxLen $using:SafeNameMaxLen `
                -FsModulePath $using:fsModulePath -ZipModulePath $using:zipModulePath `
                -ErrorBag $using:concurrentErrors
        } -ThrottleLimit $ThrottleLimit | ForEach-Object {
            $progressCounter++
            Show-ProgressPhase -Activity "Extracting archives" `
                -Status "$progressCounter / $ZipCount completed" `
                -Current $progressCounter -Total $ZipCount -QuietMode $QuietMode
            $_
        }
    )

    Show-ProgressPhase -Activity "Extracting archives" -Status "Done" `
        -Current $ZipCount -Total $ZipCount -QuietMode $QuietMode -Completed
    return Merge-ParallelZipResults -Results $results -ZipCount $ZipCount `
        -ErrorList $ErrorList -ConcurrentErrors $concurrentErrors
}

<#
.SYNOPSIS
    Runs serial extraction and returns aggregated summary totals.
.NOTES
    Also used as the WhatIf fallback: ForEach-Object -Parallel runspaces have no
    access to $PSCmdlet, so ShouldProcess cannot be called there. When WhatIf is
    active, the dispatcher routes here regardless of ThrottleLimit.
#>
function Invoke-SerialZipExtractions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.IO.FileInfo[]]$Zips, [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][string]$DestinationDir,     [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,             [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode,            [Parameter(Mandatory)][int]$ThrottleLimit,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    if ($ThrottleLimit -gt 1 -and $WhatIfPreference) {
        Write-Verbose "WhatIf is active — falling back to serial extraction so -WhatIf/-Confirm are honoured."
    }
    $processedZips           = 0
    $totalFilesExtracted     = 0
    $totalUncompressedBytes  = [int64]0
    $totalCompressedZipBytes = [int64]0
    $index                   = 0

    foreach ($zip in $Zips) {
        $index++
        try {
            Show-ProgressPhase -Activity "Extracting archives" -Status $zip.Name `
                -Current ($index - 1) -Total $ZipCount -QuietMode $QuietMode
            if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                $stats        = Get-ZipFileStats -ZipPath $zip.FullName
                $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName -DestinationRoot $DestinationDir `
                    -ExtractMode $Mode -CollisionPolicy $Policy -SafeNameMaxLen $SafeNameMaxLen `
                    -ExpectedFileCount $stats.FileCount
                if ($filesFromZip -is [int]) { $totalFilesExtracted += $filesFromZip }
                else                         { $totalFilesExtracted += $stats.FileCount }
                $totalUncompressedBytes  += $stats.UncompressedBytes
                $totalCompressedZipBytes += $stats.CompressedBytes
                $processedZips++
                Write-LogDebug "Extracted '$($zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)"
            }
        } catch {
            $msg = $_.Exception.Message
            $ErrorList.Add("Extraction failed for '$($zip.FullName)': $msg") | Out-Null
            Write-LogDebug $msg
        }
    }

    Show-ProgressPhase -Activity "Extracting archives" -Status "Done" `
        -Current $ZipCount -Total $ZipCount -QuietMode $QuietMode -Completed
    return New-ExtractionSummary -ZipCount $ZipCount -ProcessedZips $processedZips `
        -FilesExtracted $totalFilesExtracted -UncompressedBytes $totalUncompressedBytes `
        -CompressedBytes $totalCompressedZipBytes
}

<#
.SYNOPSIS
    Extracts all zip files from source to destination and returns summary totals.
.PARAMETER ThrottleLimit
    When greater than 1, archives are extracted in parallel using ForEach-Object
    -Parallel. Errors are aggregated thread-safely via ConcurrentBag.
    Default 1 preserves the original serial behaviour.
#>
function Invoke-ZipExtractions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList,
        [int]$ThrottleLimit = 1
    )

    $zips     = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File -ErrorAction Stop)
    $zipCount = $zips.Count
    Write-LogInfo "Found $zipCount zip file(s) in: $SourceDir"
    Write-LogInfo "Extracting to: $DestinationDir (Mode: $Mode, Policy: $Policy)"

    if ($zipCount -eq 0) {
        return New-ExtractionSummary -ZipCount 0 -ProcessedZips 0 -FilesExtracted 0 `
            -UncompressedBytes ([int64]0) -CompressedBytes ([int64]0)
    }

    $sharedParams = @{
        Zips           = $zips
        ZipCount       = $zipCount
        DestinationDir = $DestinationDir
        Mode           = $Mode
        Policy         = $Policy
        SafeNameMaxLen = $SafeNameMaxLen
        QuietMode      = $QuietMode
        ThrottleLimit  = $ThrottleLimit
        ErrorList      = $ErrorList
    }

    if ($ThrottleLimit -gt 1 -and -not $WhatIfPreference) {
        return Invoke-ParallelZipExtractions @sharedParams
    }
    return Invoke-SerialZipExtractions @sharedParams
}

<#
.SYNOPSIS
    Optionally cleans non-zip leftovers and removes the source directory.
#>
function Remove-SourceDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][bool]$ShouldDeleteSource,
        [Parameter(Mandatory)][bool]$ShouldCleanNonZips,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )

    if (-not $ShouldDeleteSource) {
        return
    }

    # Resolve to the native provider path so [System.IO.Directory] calls (which
    # are unaware of PowerShell PSDrives) see exactly the same path PowerShell
    # does. Without this, a caller passing e.g. `TestDrive:\source-nested`
    # would make Directory.Exists return $false (invalid path to .NET) while
    # Test-Path correctly reported $true, causing the delete logic to short-
    # circuit silently and leave the directory on disk.
    $resolvedSource = try {
        (Resolve-Path -LiteralPath $SourceDir -ErrorAction Stop).ProviderPath
    } catch {
        $SourceDir
    }

    try {
        $gcErrors = $null
        $remaining = Get-ChildItem -LiteralPath $resolvedSource -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable gcErrors
        foreach ($e in $gcErrors) {
            Write-Warning "Could not read item during source directory scan: $($e.Exception.Message)"
        }
        # Zip files left behind (e.g. by Skip collision policy) must block deletion
        # to prevent data loss: the caller chose Skip precisely to keep those archives.
        $remainingZips = @($remaining | Where-Object { -not $_.PSIsContainer -and $_.Extension -eq '.zip' })
        if ($remainingZips.Count -gt 0) {
            $ErrorList.Add("DeleteSource skipped: $($remainingZips.Count) zip file(s) remain in '$SourceDir' (not moved due to Skip collision policy). Resolve the collisions or change -CollisionPolicy before using -DeleteSource.") | Out-Null
            Write-LogDebug ("Remaining zips: `n" + ($remainingZips | Select-Object -ExpandProperty FullName | Out-String))
            return
        }

        $nonZips = @($remaining | Where-Object { $_.PSIsContainer -or $_.Extension -ne '.zip' })
        if ($nonZips.Count -gt 0 -and -not $ShouldCleanNonZips) {
            $hasFiles = @($nonZips | Where-Object { -not $_.PSIsContainer })
            if ($hasFiles.Count -gt 0) {
                $ErrorList.Add("DeleteSource skipped: non-zip files remain in '$SourceDir'. Use -CleanNonZips to remove them.") | Out-Null
            } else {
                $ErrorList.Add("DeleteSource skipped: only empty subdirectories remain in '$SourceDir'. Use -CleanNonZips to remove them.") | Out-Null
            }
            Write-LogDebug ("Remaining items: `n" + ($nonZips | Select-Object -ExpandProperty FullName | Out-String))
            return
        }

        if ($ShouldCleanNonZips -and $nonZips.Count -gt 0) {
            # Wrap the split/filter result with @(...) so .Count remains valid under
            # Set-StrictMode -Version Latest when a single-segment relative path
            # would otherwise make Where-Object return a scalar string.
            $nonZips | Sort-Object -Property `
            @{ Expression = { @($_.FullName -replace [regex]::Escape($resolvedSource), '' -split '[\\/]' | Where-Object { $_ -ne '' }).Count }; Descending = $true }, `
            @{ Expression = { $_.FullName }; Descending = $true } | ForEach-Object {
                # Capture the pipeline item; inside the catch below, $_ is rebound
                # to the ErrorRecord and reading $_.FullName would raise a
                # terminating PropertyNotFoundException under Set-StrictMode -Latest,
                # which would bubble past this catch into the outer handler and
                # prevent the final source-directory deletion from running.
                $item = $_
                try {
                    if (Test-Path -LiteralPath $item.FullName) {
                        if ($item.PSIsContainer) {
                            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                        } else {
                            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                        }
                    }
                } catch {
                    Write-LogDebug "Best-effort cleanup skip for '$($item.FullName)': $($_.Exception.Message)"
                }
            }
        }

        # Delete the source directory itself (no ShouldProcess check needed since $ShouldDeleteSource is explicit).
        #
        # Use [System.IO.Directory]::Delete($path, recursive: true) instead of
        # Remove-Item -Recurse -Force. On Linux, PowerShell's Remove-Item has a
        # long-standing rough edge with recursive deletion (PowerShell #8211):
        # it can emit non-terminating errors while still removing most content,
        # and on some CI filesystems (GitHub Actions runners in particular) it
        # leaves the root directory behind, producing a persistent
        # "source directory still exists after removal" failure in
        # the nested-cleanup Pester case. The .NET primitive is synchronous,
        # cross-platform, and has no such quirk. Remove-Item is kept as a
        # fallback only if the .NET call fails.
        $finalDeleteError = $null
        if ([System.IO.Directory]::Exists($resolvedSource)) {
            try {
                [System.IO.Directory]::Delete($resolvedSource, $true)
            } catch {
                $finalDeleteError = $_
                Write-LogDebug "Directory.Delete raised for '$resolvedSource': $($_.Exception.Message)"
            }
        }
        # Fallback: if .NET failed and the dir still exists, try Remove-Item once.
        if ([System.IO.Directory]::Exists($resolvedSource)) {
            try {
                Remove-Item -LiteralPath $resolvedSource -Recurse -Force -ErrorAction Stop
                $finalDeleteError = $null
            } catch {
                if ($null -eq $finalDeleteError) { $finalDeleteError = $_ }
                Write-LogDebug "Remove-Item fallback raised for '$resolvedSource': $($_.Exception.Message)"
            }
        }
        # Record a single failure entry if the directory still exists, or if the
        # last delete attempt threw (preserves error reporting when permission-
        # denied ACLs might make the directory appear absent while deletion
        # genuinely failed).
        if ([System.IO.Directory]::Exists($resolvedSource)) {
            $reason = if ($null -ne $finalDeleteError) { $finalDeleteError.Exception.Message } else { 'source directory still exists after removal' }
            $ErrorList.Add("Failed to delete source directory '$SourceDir': $reason") | Out-Null
        } elseif ($null -ne $finalDeleteError) {
            $ErrorList.Add("Failed to delete source directory '$SourceDir': $($finalDeleteError.Exception.Message)") | Out-Null
        }
    } catch {
        $msg = "Failed to delete source directory '$SourceDir': $($_.Exception.Message)"
        Write-LogDebug $msg
        $ErrorList.Add($msg) | Out-Null
    }
}

<#
.SYNOPSIS
    Moves .zip files from SourceDir to its parent folder with per-file progress.

.PARAMETER SourceDir
    The source directory containing .zip files to move.

.PARAMETER QuietMode
    Suppresses progress bar output when $true.

.PARAMETER CollisionPolicy
    Behavior when a zip with the same name already exists in the parent directory:
      - Skip       : leave the existing parent zip untouched and do not move the source zip.
      - Overwrite  : replace the existing parent zip with the source zip (Move-Item -Force).
      - Rename     : move the source zip with a unique suffix (default, prior behavior).
#>
function Move-ZipFilesToParent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][bool]$QuietMode,
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename'
    )

    $parentItem = Get-Item -LiteralPath $SourceDir
    $parent = $parentItem.Parent?.FullName
    if (-not $parent) {
        throw "Cannot move zip files: source directory '$SourceDir' is at drive root (no parent directory exists)"
    }

    if (-not [System.IO.Directory]::Exists($parent)) {
        throw "Parent directory not found: $parent"
    }

    # Writability probe (skip if WhatIf)
    if (-not $WhatIfPreference) {
        $null = Test-DirectoryWritable -Path $parent -ThrowOnFailure
    }

    $zipsToMove = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File)
    $total = $zipsToMove.Count
    $totalBytes = [int64](($zipsToMove | Measure-Object Length -Sum).Sum)

    $idx = 0
    $moved = 0
    $bytes = [int64]0
    $skipped = 0
    $overwritten = 0
    $renamed = 0

    foreach ($zf in $zipsToMove) {
        $idx++
        # Include the current file's size in the display so the byte counter reflects
        # the running total up to and including the file being processed (fixes the
        # off-by-one where the caption previously showed only bytes from prior files).
        Show-ProgressPhase -Activity "Moving zip files to parent" `
            -Status "$idx / $total : $($zf.Name) ($(Format-Bytes $zf.Length))" `
            -Current $idx -Total $total -QuietMode $QuietMode `
            -CurrentOperation ("Moving: {0} of {1} bytes" -f (Format-Bytes ($bytes + $zf.Length)), (Format-Bytes $totalBytes))

        $target = Join-Path $parent $zf.Name
        $collides = [System.IO.File]::Exists($target)
        $useForce = $false

        if ($collides) {
            if ($CollisionPolicy -eq 'Skip') {
                Write-LogDebug "Move skip (collision): '$($zf.Name)' already exists in parent."
                $skipped++
                continue
            } elseif ($CollisionPolicy -eq 'Overwrite') {
                $useForce = $true
                $overwritten++
            } elseif ($CollisionPolicy -eq 'Rename') {
                $target = Resolve-UniquePath -Path $target
                $renamed++
            }
        }

        if ($useForce) {
            Move-Item -LiteralPath $zf.FullName -Destination $target -Force
        } else {
            Move-Item -LiteralPath $zf.FullName -Destination $target
        }
        $moved++
        $bytes += $zf.Length
    }

    Show-ProgressPhase -Activity "Moving zip files to parent" -Status "Done" `
        -Current $total -Total $total -QuietMode $QuietMode -Completed

    [pscustomobject]@{ Count = $moved; Bytes = $bytes; Destination = $parent; Skipped = $skipped; Overwritten = $overwritten; Renamed = $renamed }
}

<#
.SYNOPSIS
    Writes the end-of-run extraction summary to the host.
.DESCRIPTION
    Formats and displays a summary table (or list on narrow consoles) of all
    extraction, move, and error statistics collected during the run.

    Behavior varies by host interactivity:
    - Interactive hosts (ConsoleHost, Visual Studio Code Host): full output —
      header, Format-Table/-List view, and error notes.
    - Non-interactive hosts (scheduled tasks, redirected streams): the
      formatted table is suppressed, but any accumulated errors are still
      written to the success stream so failures are never silent in
      automation logs.
.PARAMETER SourceDirectory
    Source directory passed to the script.
.PARAMETER DestinationDirectory
    Destination directory passed to the script.
.PARAMETER ExtractMode
    Extraction mode used (PerArchiveSubfolder or Flat).
.PARAMETER CollisionPolicy
    Collision policy used (Skip, Overwrite, or Rename).
.PARAMETER ZipCount
    Total number of zip files found.
.PARAMETER ProcessedZips
    Number of zip files successfully processed.
.PARAMETER FilesExtracted
    Total number of files extracted across all archives.
.PARAMETER UncompressedBytes
    Total uncompressed bytes extracted.
.PARAMETER CompressedBytes
    Total compressed (on-disk) bytes of the zip files processed.
.PARAMETER MoveSummary
    PSCustomObject returned by Move-ZipFilesToParent containing Count, Bytes,
    Destination, Skipped, Overwritten, and Renamed.
.PARAMETER Errors
    List of non-fatal error messages accumulated during the run.
.PARAMETER Elapsed
    Total elapsed time for the run.
.PARAMETER HostName
    Name of the current host. Defaults to $Host.Name. Accepted as a parameter
    so that tests can inject a synthetic value without spawning a new host.
.PARAMETER ConsoleWidth
    Override the detected console width. 0 (default) means auto-detect via
    $Host.UI.RawUI.WindowSize.Width. Pass a positive value to force Format-Table
    (>= 120) or Format-List (< 120) regardless of the actual terminal width.
    Useful in tests and when piping output to a fixed-width formatter.
.PARAMETER PassThru
    Switch. When set, emits the summary PSCustomObject to the pipeline in addition
    to writing it to the host. Intended for testing so callers can inspect the
    computed fields without needing to intercept Format-Table/-List.
.NOTES
    Error notes are always emitted when errors exist, regardless of host type,
    so that failures are never silently swallowed in scheduled tasks or
    automation pipelines.
#>
function Write-ExtractionSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory,
        [Parameter(Mandatory)][string]$ExtractMode,
        [Parameter(Mandatory)][string]$CollisionPolicy,
        [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][int]$ProcessedZips,
        [Parameter(Mandatory)][int]$FilesExtracted,
        [Parameter(Mandatory)][int64]$UncompressedBytes,
        [Parameter(Mandatory)][int64]$CompressedBytes,
        [Parameter(Mandatory)][pscustomobject]$MoveSummary,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors,
        [Parameter(Mandatory)][timespan]$Elapsed,
        [string]$HostName = $Host.Name,
        [int]$ConsoleWidth = 0,
        [switch]$PassThru
    )

    $isInteractive = $HostName -in ('ConsoleHost', 'Visual Studio Code Host')

    if ($isInteractive) {
        $compressionRatio = ($CompressedBytes -gt 0) ? ("{0:N1}x" -f ($UncompressedBytes / [double]$CompressedBytes)) : "n/a"

        $summaryView = [pscustomobject]@{
            SrcDir          = $SourceDirectory
            DestDir         = $DestinationDirectory
            Mode            = $ExtractMode
            Policy          = $CollisionPolicy
            ZipsFound       = $ZipCount
            ZipsDone        = $ProcessedZips
            Files           = $FilesExtracted
            Uncompressed    = (Format-Bytes $UncompressedBytes)
            Compressed      = (Format-Bytes $CompressedBytes)
            Ratio           = $compressionRatio
            ZipsMoved       = ($MoveSummary.Count)
            MoveSkipped     = ($MoveSummary.Skipped)
            MoveOverwritten = ($MoveSummary.Overwritten)
            MoveRenamed     = ($MoveSummary.Renamed)
            MovedBytes      = (Format-Bytes $MoveSummary.Bytes)
            MovedTo         = ($MoveSummary.Destination)
            Errors          = ($Errors.Count)
            Duration        = ("{0:hh\:mm\:ss\.fff}" -f $Elapsed)
        }

        Write-Output ""
        Write-Output "==== Expand-ZipsAndClean Summary ===="

        $rawWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { $null }
        $effectiveWidth = ($ConsoleWidth -gt 0) ? $ConsoleWidth : ($rawWidth ?? 120)

        if ($effectiveWidth -lt 120) {
            $summaryView | Format-List
        } else {
            $summaryView | Format-Table -AutoSize
        }

        if ($PassThru) { $summaryView }
    }

    if ($Errors.Count -gt 0) {
        if ($isInteractive) { Write-Output "" }
        Write-Output "Notes / Errors:"
        $Errors | ForEach-Object { Write-Output " - $_" }
    }
}

#endregion Helpers

#------------------------------- Main -------------------------------#

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$errors = [List[string]]::new()

# State for summary
$zipCount = 0
$processedZips = 0
$totalFilesExtracted = 0
$totalUncompressedBytes = [int64]0
$totalCompressedZipBytes = [int64]0
$moveSummary = [pscustomobject]@{ Count = 0; Bytes = 0; Destination = ""; Skipped = 0; Overwritten = 0; Renamed = 0 }

try {
    Test-ScriptPreconditions -SourceDir $SourceDirectory -DestinationDir $DestinationDirectory
    Initialize-Destination -DestinationDir $DestinationDirectory

    $extractionResult = Invoke-ZipExtractions `
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
            $moveSummary = Move-ZipFilesToParent -SourceDir $SourceDirectory -QuietMode $Quiet.IsPresent -CollisionPolicy $CollisionPolicy
        }
    } catch {
        $msg = "Moving .zip files to parent failed: $($_.Exception.Message)"
        Write-LogDebug $msg
        $errors.Add($msg) | Out-Null
    }

    Remove-SourceDirectory `
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

Write-ExtractionSummary `
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
