#requires -Version 7.0
using namespace System.Collections.Generic
using namespace System.IO.Compression

<#
.SYNOPSIS
    Unzips all .zip files from a source folder into a destination folder, moves the .zip files
    to the parent of the source folder, and (optionally) deletes/cleans the source folder.
    Prints a summary at the end.

.DESCRIPTION
    Typical workflow:
      - Source folder (example): C:\Users\manoj\Downloads\picconvert
      - Destination folder (example): C:\Users\manoj\OneDrive\Desktop\New folder
      - After extraction, all .zip files in the source are moved to the source’s parent
        (example: C:\Users\manoj\Downloads)
      - Optionally delete/clean the source folder using -DeleteSource (switch) and
        optionally -CleanNonZips to remove non-zip leftovers.

    Highlights
    - Handles unusually long & special-character file names via -LiteralPath and safe naming.
    - Extraction modes:
        * PerArchiveSubfolder (default): each .zip to its own subfolder (avoids collisions).
          If the subfolder exists, a unique folder name is created (timestamped).
        * Flat: STREAMING extraction via ZipArchive (no temp folder). Collisions handled
          per CollisionPolicy before writing each file (Skip/Overwrite/Rename).
    - CollisionPolicy (for overlapping paths and/or Flat mode):
        * Skip | Overwrite | Rename (default: Rename)
    - Progress bars for long runs (suppressed by -Quiet). Move progress shows cumulative AND total bytes.
    - End-of-run summary includes uncompressed bytes, total compressed zip bytes, and compression ratio.
      (CompressionRatio > 1.0 means the original content is larger than the archives; compression saved space.)
    - Robust error handling and diagnostics (WhatIf/Confirm; -Verbose); clearer message if an
      archive appears to be password-protected.

.PARAMETER SourceDirectory
    Directory containing .zip files to extract.
    Default: C:\Users\manoj\Downloads\picconvert

.PARAMETER DestinationDirectory
    Directory to extract contents into.
    Default: C:\Users\manoj\OneDrive\Desktop\New folder

.PARAMETER ExtractMode
    Extraction strategy. One of:
      - PerArchiveSubfolder (default)
      - Flat   (streams entries directly without temp folder; collisions handled per policy)

.PARAMETER CollisionPolicy
    Behavior when a target file already exists:
      - Skip       : leave existing files untouched, skip the incoming file
      - Overwrite  : replace existing files
      - Rename     : save incoming file with a unique suffix
    Default: Rename

.PARAMETER DeleteSource
    Switch. If present, deletes the source directory after zips are moved and,
    if -CleanNonZips is also set, after non-zip items are removed.

.PARAMETER CleanNonZips
    Switch. If present (and -DeleteSource is also specified), deletes non-zip items remaining
    in the source directory before deleting the source directory. Without this switch, the
    script will WARN and list remaining items instead of deleting.

.PARAMETER MaxSafeNameLength
    Optional maximum length for generated safe names (e.g., subfolder names derived from zip files).
    0 (default) means no truncation. Use a positive value (e.g., 200) to cap names in edge cases.
    255 aligns with common NTFS filename component limits.

.PARAMETER Quiet
    Suppress non-essential console output and progress (summary still prints).

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
    # Dry run (no changes), show what would happen
    .\Expand-ZipsAndClean.ps1 -WhatIf

.INPUTS
    None.

.OUTPUTS
    Summary is written to the host at the end. Errors are collected and summarized.

.NOTES
    Name     : Expand-ZipsAndClean.ps1
    Version  : 2.1.0
    Author   : Manoj Bhaskaran
    Requires : PowerShell 7+ (uses ternary operator, null-coalescing ??, and -Parallel),
               Microsoft.PowerShell.Archive (Expand-Archive) for subfolder mode;
               System.IO.Compression (ZipArchive) is used for streaming in Flat mode.

    ── Version History ───────────────────────────────────────────────────────────
    2.1.0  Enforced PowerShell 7+ as the minimum runtime: added #requires -Version 7.0,
           added using namespace directives (System.Collections.Generic,
           System.IO.Compression), updated .NOTES Requires line and Setup/Module
           section (removed PS 5.1 compatibility note), replaced New-Object
           List[string] with [List[string]]::new(), and shortened ZipFile /
           ZipFileExtensions type references to use the declared namespaces.
           Version bump: minor (supported-runtime contract change, no new features).

    2.0.4  Refactored extraction internals by splitting Expand-ZipSmart into
           mode-specific helpers: Expand-ZipToSubfolder and Expand-ZipFlat.
           Expand-ZipSmart now acts as a dispatcher only (no behavior changes).

    2.0.3  Review follow-up: added comment-based help to extracted phase functions
           (Test-ScriptPreconditions, Initialize-Destination, Invoke-ZipExtractions,
           Remove-SourceDirectory) for clarity and script documentation consistency.
           No behavioral changes.

    2.0.2  Refactored orchestration into named phase functions:
           - Test-ScriptPreconditions, Initialize-Destination,
             Invoke-ZipExtractions, Move-ZipFilesToParent, Remove-SourceDirectory
           Renamed Move-Zips-ToParent -> Move-ZipFilesToParent to follow Verb-Noun.
           Removed duplicate 1.1.1-1.2.2 entries from version history block.
           Script behavior unchanged.

    2.0.1  Refactored: Moved generic helper functions to FileSystem.psm1 module
           for shared reuse across scripts. Moved functions:
           - Get-FullPath, Format-Bytes, Resolve-UniquePathCore
           - Resolve-UniquePath, Resolve-UniqueDirectoryPath
           - Get-SafeName, Test-LongPathsEnabled
           Script behavior unchanged; all functions still available via module import.

    2.0.0  Refactored to use PowerShellLoggingFramework.psm1 for standardized logging:
           - Removed Write-Info helper function
           - Replaced Write-Info calls with Write-LogInfo
           - Replaced Write-Verbose calls with Write-LogDebug
           - All log messages now written to standardized log files
           - Retained user-facing summary output as Write-Host for UX

    1.2.2  Fixes & UX: Move Format-Bytes to Helpers (scope); adaptive summary layout
           (table for wide consoles, list for narrow) to prevent header wrapping.
    1.2.1  Docs/UX polish: .NOTES calls out Zip Slip protection; parameter doc & NOTES
           reiterate 255-char rationale; verbose truncation message retained (with
           original length); clarify ExtractToFile overwrite flag comment; progress shows
           total bytes target; FAQ explains CompressionRatio; minor comments on caching.
    1.2.0  Flat mode now streams via ZipArchive (no temp folder; pre-check collisions);
           function-level help & more inline comments; cache minor lookups;
           progress shows cumulative bytes moved; docs extend security caveats and
           rationale for 255-char limit; notes clarify ratio meaning.
    1.1.2  Quick wins: path separator normalization for comparisons, verbose notice
           on truncation, bytes shown in move progress, compression ratio rounded
           to 1 decimal, `.EXAMPLE` for MaxSafeNameLength + -Verbose, notes on
           typical MaxSafeNameLength values, FAQ includes 7-Zip example.
    1.1.1  Safety/UX: guard against same/overlapping source/destination, optional
           MaxSafeNameLength, per-file move progress, compression ratio, de-duped
           suffix logic, directory write probe, docs for novices, PS 5.1 note.
    1.1.0  Added progress bars, converted -DeleteSource to [switch] (no default),
           aliases for Source/Destination, compressed-bytes metric, clearer error
           for password-protected zips, unique subfolder naming if exists, parent
           writability check, optional -CleanNonZips, consistent summary printing,
           table summary, ms in duration, and expanded docs/FAQ.
    ── Setup / Module check ─────────────────────────────────────────────────────
    Expand-Archive is provided by Microsoft.PowerShell.Archive.
    If missing on PowerShell 7+, install from PSGallery:
        Install-Module -Name Microsoft.PowerShell.Archive -Scope CurrentUser -Force
      (You may need: Set-PSRepository PSGallery -InstallationPolicy Trusted)

    ── Security (Flat mode / Zip Slip protection) ───────────────────────────────
    Flat mode validates each entry’s resolved full path stays within the destination root
    before writing, preventing path traversal (“Zip Slip”). Suspicious entries are skipped
    and logged at -Verbose level.

    ── Long Path Support (Windows) ──────────────────────────────────────────────
    If you expect paths > 260 chars, enable LongPathsEnabled:
      HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem
        (DWORD) LongPathsEnabled = 1
    Or via Group Policy: Computer Configuration > Administrative Templates > System > Filesystem
      “Enable Win32 long paths” = Enabled
    PowerShell 7+ and modern .NET improve long path handling, but this script is defensive.

    ── Note for new users ───────────────────────────────────────────────────────
    Optional features like ExtractMode and CollisionPolicy are advanced/optional.
    For a simple run, you can just execute the script with no parameters.

    ── Tips for MaxSafeNameLength ───────────────────────────────────────────────
    Typical values: 200 for defensive truncation; 100 for stricter limits. Leave as 0 to disable truncation.
    The 255-character cap aligns with common NTFS filename component limits.

TROUBLESHOOTING & FAQ
    Q: Script seems to hang on large zips.
       A: Use -Verbose to monitor progress; consider running in PowerShell 7+ for better performance.

    Q: Can I process password-protected zips?
       A: Not supported by Expand-Archive. Use an external tool like 7-Zip, e.g.:
          7z x archive.zip -p"$env:ZIP_PASSWORD"
       ⚠ Avoid embedding passwords in scripts or plain command lines. Prefer interactive prompts,
         environment variables, or secret variables in CI systems.

    Q: What does CompressionRatio mean?
       A: Values > 1.0 indicate compression saved space (the total uncompressed content is larger
          than the combined archive sizes).

    Q: I get errors mentioning long paths or path too long.
       A: Enable Long Path Support as noted above. Prefer PowerShell 7+. Keep destination close to drive root.

    Q: Extraction fails for one archive but others work.
       A: Try -Verbose to inspect the failing file. The archive may be corrupted or password-protected;
          the script flags likely password cases in the error.

    Q: I want to preview actions without changing files.
       A: Use -WhatIf (and optionally -Confirm for prompts).

#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [Alias('Src')]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory = "C:\Users\manoj\Downloads\picconvert",

    [Parameter()]
    [Alias('Dest')]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationDirectory = "C:\Users\manoj\OneDrive\Desktop\New folder",

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
    [switch]$Quiet
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\FileSystem\FileSystem.psm1" -Force

# Initialize logger (script name will be extracted from the script file name)
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

#region Helpers

<#
.SYNOPSIS
    Returns quick stats for a zip (file count, uncompressed total, compressed bytes).
.DESCRIPTION
    Caches the FileInfo once to avoid redundant Get-Item/Length calls in loops.
.PARAMETER ZipPath
    Full path to the .zip file.
#>
function Get-ZipFileStats {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ZipPath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    # Precompute to avoid repeated Get-Item lookups (minor optimisation)
    $zipItem = Get-Item -LiteralPath $ZipPath
    $compressedLen = [int64]$zipItem.Length

    $result = [pscustomobject]@{
        FileCount         = 0;
        UncompressedBytes = [int64]0;
        CompressedBytes   = $compressedLen
    }

    try {
        $zip = [ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                if ($entry.Name) {
                    $result.FileCount++
                    $result.UncompressedBytes += [int64]$entry.Length
                }
            }
        } finally {
            $zip.Dispose()
        }
    } catch {
        Write-LogDebug "Failed to read zip stats for: $ZipPath. $_"
    }
    return $result
}

<#
.SYNOPSIS
    Extracts one ZIP archive into a unique subfolder under the destination root.
.DESCRIPTION
    This helper implements `PerArchiveSubfolder` mode. It uses `Expand-Archive` to extract
    into a sanitized subfolder name and resolves collisions by creating a unique directory path.
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder for extraction.
.PARAMETER SafeSubfolderName
    Safe destination subfolder name derived from the zip file name.
.OUTPUTS
    Int (number of files extracted into the resolved subfolder).
#>
function Expand-ZipToSubfolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$SafeSubfolderName
    )

    try {
        $target = Join-Path $DestinationRoot $SafeSubfolderName
        $target = Resolve-UniqueDirectoryPath -Path $target
        if (-not (Test-Path -LiteralPath $target)) {
            New-DirectoryIfMissing -Path $target -Force | Out-Null
        }

        Expand-Archive -LiteralPath $ZipPath -DestinationPath $target -Force
        return (Get-ChildItem -Path $target -Recurse -File | Measure-Object).Count

    } catch {
        $msg = $_.Exception.Message
        if ($msg -imatch 'encrypt|password|protected') {
            throw "Extraction failed for '$ZipPath' (zip may be encrypted): $msg"
        }
        throw
    }
}

<#
.SYNOPSIS
    Streams one ZIP archive directly into the destination root (flat mode).
.DESCRIPTION
    Implements `Flat` extraction mode using `ZipArchive` streaming extraction. The function:
    - Normalizes each entry path and enforces a destination-root prefix check to prevent Zip Slip.
    - Applies per-file collision policy (`Skip`, `Overwrite`, `Rename`) before writing.
    - Creates required destination directories on demand.
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder for extraction.
.PARAMETER DestinationRootFull
    Fully-qualified destination root path used for Zip Slip boundary validation.
.PARAMETER CollisionPolicy
    File collision behavior: `Skip`, `Overwrite`, or `Rename`.
.OUTPUTS
    Int (number of files extracted).
#>
function Expand-ZipFlat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$DestinationRootFull,
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename'
    )

    $destRootFullWithSep = if ($DestinationRootFull.EndsWith('\')) { $DestinationRootFull } else { $DestinationRootFull + '\' }
    $written = 0

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                if ([string]::IsNullOrEmpty($entry.Name)) { continue }

                $rel = ($entry.FullName -replace '/', '\').TrimStart('\')
                $dest = Join-Path $DestinationRoot $rel
                $destFull = [System.IO.Path]::GetFullPath($dest)
                if (-not $destFull.StartsWith($destRootFullWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-LogDebug "Skipped path traversal: $($entry.FullName)"
                    continue
                }

                $destDir = Split-Path -Path $destFull -Parent
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-DirectoryIfMissing -Path $destDir -Force | Out-Null
                }

                $targetPath = $destFull
                if (Test-Path -LiteralPath $targetPath) {
                    switch ($CollisionPolicy) {
                        'Skip' { continue }
                        'Rename' { $targetPath = Resolve-UniquePath -Path $targetPath }
                        'Overwrite' { }
                    }
                }

                try {
                    [ZipFileExtensions]::ExtractToFile($entry, $targetPath, ($CollisionPolicy -eq 'Overwrite'))
                    $written++
                } catch {
                    $emsg = $_.Exception.Message
                    if ($emsg -imatch 'encrypt|password|protected') {
                        throw "Extraction failed for '$ZipPath' (zip may be encrypted): $emsg"
                    }
                    throw
                }
            }
        } finally {
            $zip.Dispose()
        }

        return $written

    } catch {
        $msg = $_.Exception.Message
        if ($msg -imatch 'encrypt|password|protected') {
            throw "Extraction failed for '$ZipPath' (zip may be encrypted): $msg"
        }
        throw
    }
}

<#
.SYNOPSIS
    Dispatches zip extraction to the configured extraction mode helper.
.DESCRIPTION
    Public-facing compatibility wrapper that preserves the existing signature and routes
    extraction to either `Expand-ZipToSubfolder` (`PerArchiveSubfolder`) or `Expand-ZipFlat` (`Flat`).
.PARAMETER ZipPath
    Path to the zip archive.
.PARAMETER DestinationRoot
    Root folder for extraction.
.PARAMETER ExtractMode
    `PerArchiveSubfolder` or `Flat`.
.PARAMETER CollisionPolicy
    `Skip` | `Overwrite` | `Rename`.
.PARAMETER SafeNameMaxLen
    Maximum safe-name length used to derive per-archive subfolder names.
.OUTPUTS
    Int (number of files written by the selected mode helper).
#>
function Expand-ZipSmart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [ValidateSet('PerArchiveSubfolder', 'Flat')][string]$ExtractMode = 'PerArchiveSubfolder',
        [ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy = 'Rename',
        [int]$SafeNameMaxLen = 0
    )

    if (-not (Test-Path -LiteralPath $DestinationRoot)) {
        New-DirectoryIfMissing -Path $DestinationRoot -Force | Out-Null
    }

    $destRootFull = Get-FullPath -Path $DestinationRoot
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
    $safeSub = Get-SafeName -Name $baseName -MaxLength $SafeNameMaxLen

    if ($ExtractMode -eq 'PerArchiveSubfolder') {
        return Expand-ZipToSubfolder -ZipPath $ZipPath -DestinationRoot $DestinationRoot -SafeSubfolderName $safeSub
    }

    return Expand-ZipFlat -ZipPath $ZipPath -DestinationRoot $DestinationRoot -DestinationRootFull $destRootFull -CollisionPolicy $CollisionPolicy
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

    $srcWithSep = if ($srcFull.EndsWith('\')) { $srcFull } else { $srcFull + '\' }
    $dstWithSep = if ($dstFull.EndsWith('\')) { $dstFull } else { $dstFull + '\' }

    if ($dstWithSep.StartsWith($srcWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Destination cannot be inside the source directory."
    }
    if ($srcWithSep.StartsWith($dstWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
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

<#
.SYNOPSIS
    Extracts all zip files from source to destination and returns summary totals.
#>
function Invoke-ZipExtractions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy,
        [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )

    $processedZips = 0
    $totalFilesExtracted = 0
    $totalUncompressedBytes = [int64]0
    $totalCompressedZipBytes = [int64]0

    $zips = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File -ErrorAction Stop)
    $zipCount = $zips.Count

    Write-LogInfo "Found $zipCount zip file(s) in: $SourceDir"
    Write-LogInfo "Extracting to: $DestinationDir (Mode: $Mode, Policy: $Policy)"

    if ($zipCount -gt 0) {
        $index = 0
        foreach ($zip in $zips) {
            $index++
            try {
                if (-not $QuietMode) {
                    $pct = [int](($index - 1) / [math]::Max(1, $zipCount) * 100)
                    Write-Progress -Activity "Extracting archives" -Status $zip.Name -PercentComplete $pct
                }

                if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                    $stats = Get-ZipFileStats -ZipPath $zip.FullName
                    $stats.CompressedBytes = [int64]$zip.Length

                    $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName `
                        -DestinationRoot $DestinationDir `
                        -ExtractMode $Mode `
                        -CollisionPolicy $Policy `
                        -SafeNameMaxLen $SafeNameMaxLen

                    $totalFilesExtracted += (($filesFromZip -is [int]) ? $filesFromZip : $stats.FileCount)
                    $totalUncompressedBytes += $stats.UncompressedBytes
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

        if (-not $QuietMode) {
            Write-Progress -Activity "Extracting archives" -Completed
        }
    }

    return [pscustomobject]@{
        ZipCount = $zipCount
        ProcessedZips = $processedZips
        FilesExtracted = $totalFilesExtracted
        UncompressedBytes = $totalUncompressedBytes
        CompressedBytes = $totalCompressedZipBytes
    }
}

<#
.SYNOPSIS
    Optionally cleans non-zip leftovers and removes the source directory.
#>
function Remove-SourceDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][bool]$ShouldDeleteSource,
        [Parameter(Mandatory)][bool]$ShouldCleanNonZips,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )

    if (-not $ShouldDeleteSource) {
        return
    }

    try {
        $remaining = Get-ChildItem -LiteralPath $SourceDir -Recurse -Force -ErrorAction SilentlyContinue
        $nonZips = @($remaining | Where-Object { (-not $_.PSIsContainer -and $_.Extension -ne '.zip') -or $_.PSIsContainer })
        if ($nonZips.Count -gt 0 -and -not $ShouldCleanNonZips) {
            $ErrorList.Add("DeleteSource skipped: non-zip items remain. Use -CleanNonZips to remove them.") | Out-Null
            Write-LogDebug ("Remaining items: `n" + ($nonZips | Select-Object -ExpandProperty FullName | Out-String))
            return
        }

        if ($ShouldCleanNonZips -and $nonZips.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($SourceDir, "Clean non-zip items before delete")) {
                $nonZips | ForEach-Object {
                    try {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                    } catch {
                        $ErrorList.Add("Failed to remove: $($_.FullName) -> $($_.Exception.Message)") | Out-Null
                    }
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($SourceDir, "Delete source directory")) {
            Remove-Item -LiteralPath $SourceDir -Recurse -Force
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
#>
function Move-ZipFilesToParent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourceDir)

    $parentItem = Get-Item -LiteralPath $SourceDir
    $parent = $parentItem.Parent.FullName

    if (-not (Test-Path -LiteralPath $parent)) {
        throw "Parent directory not found: $parent"
    }

    # Writability probe using an empty directory (skip if WhatIf)
    if (-not $WhatIfPreference) {
        $probe = Join-Path $parent ("._write_test_{0}" -f ([guid]::NewGuid().ToString('N')))
        try {
            New-DirectoryIfMissing -Path $probe -Force | Out-Null
            Remove-Item -LiteralPath $probe -Recurse -Force
        } catch {
            throw "Parent directory is not writable: $parent"
        }
    }

    $zipsToMove = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File)
    $total = $zipsToMove.Count
    $totalBytes = [int64](($zipsToMove | Measure-Object Length -Sum).Sum)

    $idx = 0
    $moved = 0
    $bytes = [int64]0

    foreach ($zf in $zipsToMove) {
        $idx++
        if (-not $Quiet) {
            $pct = [int](($idx) / [math]::Max(1, $total) * 100)
            Write-Progress -Activity "Moving zip files to parent" `
                -Status "$idx / $total : $($zf.Name) ($(Format-Bytes $zf.Length))" `
                -CurrentOperation ("Moved {0} of {1}" -f (Format-Bytes $bytes), (Format-Bytes $totalBytes)) `
                -PercentComplete $pct
        }

        $target = Join-Path $parent $zf.Name
        if (Test-Path -LiteralPath $target) {
            $target = Resolve-UniquePath -Path $target
        }
        Move-Item -LiteralPath $zf.FullName -Destination $target
        $moved++
        $bytes += $zf.Length
    }

    if (-not $Quiet) { Write-Progress -Activity "Moving zip files to parent" -Completed }

    [pscustomobject]@{ Count = $moved; Bytes = $bytes; Destination = $parent }
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
$moveSummary = [pscustomobject]@{ Count = 0; Bytes = 0; Destination = "" }

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
        -ErrorList $errors

    $zipCount = $extractionResult.ZipCount
    $processedZips = $extractionResult.ProcessedZips
    $totalFilesExtracted = $extractionResult.FilesExtracted
    $totalUncompressedBytes = $extractionResult.UncompressedBytes
    $totalCompressedZipBytes = $extractionResult.CompressedBytes

    try {
        if ($PSCmdlet.ShouldProcess($SourceDirectory, "Move .zip files to parent")) {
            $moveSummary = Move-ZipFilesToParent -SourceDir $SourceDirectory
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

# Always print a summary (even if no zips)
$compressionRatio = if ($totalCompressedZipBytes -gt 0) {
    # Show as multiplier, one decimal (e.g., 3.3x). >1 means compression saved space.
    "{0:N1}x" -f ($totalUncompressedBytes / [double]$totalCompressedZipBytes)
} else { "n/a" }

# Build a view with shorter column names to avoid wrapping on narrow consoles
$summaryView = [pscustomobject]@{
    SrcDir       = $SourceDirectory
    DestDir      = $DestinationDirectory
    Mode         = $ExtractMode
    Policy       = $CollisionPolicy
    ZipsFound    = $zipCount
    ZipsDone     = $processedZips
    Files        = $totalFilesExtracted
    Uncompressed = (Format-Bytes $totalUncompressedBytes)
    Compressed   = (Format-Bytes $totalCompressedZipBytes)
    Ratio        = $compressionRatio
    ZipsMoved    = ($moveSummary.Count)
    MovedBytes   = (Format-Bytes $moveSummary.Bytes)
    MovedTo      = ($moveSummary.Destination)
    Errors       = ($errors.Count)
    Duration     = ("{0:hh\:mm\:ss\.fff}" -f $stopwatch.Elapsed)
}

Write-Host ""
Write-Host "==== Expand-ZipsAndClean Summary ===="

# Detect console width; for narrow consoles, use a clean list view
$consoleWidth = 120
try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {
    # Console width unavailable (non-interactive or headless mode), using default
}

if ($consoleWidth -lt 120) {
    $summaryView | Format-List
} else {
    $summaryView | Format-Table -AutoSize
}

if ($errors.Count -gt 0) {
    Write-Host "`nNotes / Errors:"
    $errors | ForEach-Object { Write-Host " - $_" }
}

# End of script
