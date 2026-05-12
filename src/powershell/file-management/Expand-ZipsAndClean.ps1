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
    - CollisionPolicy (for overlapping paths in Flat mode AND for the zip-move-to-parent step):
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
    Version  : 2.2.2
    Author   : Manoj Bhaskaran
    Requires : PowerShell 7+ (uses ternary operator, null-coalescing ??, and -Parallel),
               Microsoft.PowerShell.Archive (Expand-Archive) for subfolder mode;
               System.IO.Compression (ZipArchive) is used for streaming in Flat mode.

    ── Version History ───────────────────────────────────────────────────────────
    2.2.2  De-duplicated stat computations and consolidated assembly load (issue #974):
           - Moved single Add-Type -AssemblyName System.IO.Compression.FileSystem
             call to script start; removed per-invocation calls from Get-ZipFileStats
             and Expand-ZipFlat.
           - Dropped caller-side CompressedBytes overwrite in Invoke-ZipExtractions;
             the value from Get-ZipFileStats is now used directly.
           - Refactored Expand-ZipToSubfolder to accept [int]$ExpectedFileCount (from
             Get-ZipFileStats) and return it directly, eliminating the post-extraction
             Get-ChildItem -Recurse walk of the destination folder.
           - Expand-ZipSmart threads ExpectedFileCount to Expand-ZipToSubfolder.
           - Added Pester regression tests for file count vs archive entry count in
             both PerArchiveSubfolder and Flat extraction modes.
           Version bump: patch.

    2.2.1  Hardened Flat-mode Zip Slip protection and centralized encrypted-archive
           error detection (issue #973):
           - Added Resolve-ZipEntryDestinationPath helper to normalize archive entry
             separators, reject rooted paths, and validate destination containment
             using OS-appropriate path comparisons.
           - Removed duplicated "zip may be encrypted" regex checks from multiple
             catch blocks; extraction errors now flow through Resolve-ExtractionError
             + Test-IsEncryptedZipError for consistent messaging.
           - Added Pester coverage for rooted-path rejection and encrypted error
             classification with nested exceptions.
           Version bump: patch (security hardening + internal refactor).

    2.2.0  Honored CollisionPolicy during zip-move-to-parent step (issue #972):
           - Added -CollisionPolicy parameter to Move-ZipFilesToParent.
           - Skip: leaves the existing parent zip untouched and records skipped count.
           - Overwrite: replaces the existing parent zip using Move-Item -Force.
           - Rename: prior behavior via Resolve-UniquePath (unchanged default).
           - Summary now reports MoveSkipped, MoveOverwritten, MoveRenamed counts.
           - .PARAMETER CollisionPolicy help updated to enumerate both phases.
           - Added Pester tests for each policy on a colliding move.
           - Fixed Remove-SourceDirectory data-loss: zip files remaining after a
             Skip-policy move now block -DeleteSource (matching non-zip file guard)
             so skipped archives are never silently deleted.
           Version bump: minor (behavior change for Skip/Overwrite users).

    2.1.9  Refactored Move-ZipFilesToParent to eliminate parent-scope reads:
           - Added [bool]$QuietMode parameter to avoid reading $Quiet from parent scope
           - Added drive-root edge case check with clear error message
           - Made writability probe leak-free by cleaning up temp directory on failure
           - Added comprehensive Pester tests for standalone function exercise
           - Updated function help documentation for new parameter

    2.1.8  Fixed Remove-SourceDirectory silent short-circuit when SourceDir
           was passed as a PSDrive-qualified path:
           - Resolve SourceDir to its native provider path (Resolve-Path |
             ProviderPath) before any [System.IO.Directory] call. .NET APIs are
             unaware of PowerShell PSDrives, so a caller (or test harness)
             passing a path like `TestDrive:\source-nested` would make
             [Directory]::Exists return $false, causing both delete attempts
             to be skipped silently and leaving the directory on disk with no
             error recorded. This matches the CI symptom where $errors was
             empty yet Test-Path reported the directory still present.
           - The deepest-first Sort-Object regex and the Get-ChildItem scan
             also use the resolved path so item FullName values consistently
             strip the expected prefix.

    2.1.7  Fixed Remove-SourceDirectory source-dir deletion reliability on Linux:
           - Replaced the two-pass Remove-Item -Recurse -Force dance with
             [System.IO.Directory]::Delete($path, recursive: $true), which is
             synchronous, cross-platform, and not subject to PowerShell #8211.
             Remove-Item is retained as a single-shot fallback only if the .NET
             call fails. On GitHub Actions Linux runners the two-pass Remove-Item
             pattern was leaving the source directory on disk even after the
             per-item cleanup loop had successfully removed its contents, which
             manifested as `Test-Path $sourceDir | Should -BeFalse` failing in
             the nested-cleanup Pester case.
           - Also captures the pipeline item as $item before the per-item cleanup
             try-block so that under Set-StrictMode -Version Latest, a diagnostic
             Write-LogDebug inside the catch cannot raise a terminating
             PropertyNotFoundException on the ErrorRecord. This was a latent
             hazard for callers running under StrictMode even though Pester
             itself disables StrictMode inside test scopes.

    2.1.6  Fixed Remove-SourceDirectory double-counting of final delete failures
           and strict-mode noise in the deepest-first sort:
           - The deepest-first Sort-Object expression now wraps its split/filter
             result in @(...) so .Count is always valid under Set-StrictMode
             -Version Latest (previously a single-segment relative path produced
             a scalar string and emitted non-terminating errors).
           - The final source-delete failure is now recorded in exactly one place,
             eliminating the "Expected 0, but got 2" failure observed in CI when
             Remove-Item threw and the directory still existed.
           - The failure is recorded whenever the retry threw, regardless of
             whether Test-Path subsequently reports the directory absent. This
             preserves error reporting when ACLs make the path unreadable but
             Remove-Item genuinely failed (review feedback on 2.1.5).

    2.1.5  Fixed Remove-SourceDirectory final error accounting: record a delete
           failure only if SourceDir still exists after all delete attempts. This
           avoids transient retry exceptions being counted as failures when the
           directory is ultimately removed.

    2.1.4  Fixed Remove-SourceDirectory CI flake for nested -CleanNonZips cleanup:
           per-item non-zip removal failures are now treated as best-effort debug
           diagnostics, and ErrorList is reserved for final source directory deletion
           failures only (the operation's true success criterion).

    2.1.3  Fixed Remove-SourceDirectory false-positive cleanup errors on Linux/CI:
           when Remove-Item reports a transient error but the target path is already
           gone, the function no longer records a failure in ErrorList. Applied to
           both per-item cleanup and final source directory removal paths.

    2.1.2  Fixed Remove-SourceDirectory cleanup robustness for nested trees when
           -CleanNonZips is set: directory entries are now removed with -Recurse so
           parent folders do not fail with "directory not empty" when same-depth
           ordering is non-deterministic. No functional changes to warning behavior.

    2.1.1  Fixed Remove-SourceDirectory: simplified non-zip filter (dropped the dead
           .zip-exclusion branch, since Move-ZipFilesToParent has already relocated all
           zips before this function runs); differentiated warning message between
           "non-zip files present" and "only empty subdirectories remain"; added
           deepest-first sort (FullName descending) when -CleanNonZips is set to prevent
           "directory not empty" failures on nested trees; wrapped Get-ChildItem with
           -ErrorVariable so unreadable items surface as Write-Warning rather than
           being silently dropped. Updated -DeleteSource / -CleanNonZips parameter help.

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
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

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
    Returns $true when an exception/message indicates archive encryption/password protection.
#>
function Test-IsEncryptedZipError {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$ErrorObject)

    $encryptionPattern = '(?i)encrypt(?:ed|ion)?|password|protected|unsupported compression method'

    if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        if ($ErrorObject.Exception -and (Test-IsEncryptedZipError -ErrorObject $ErrorObject.Exception)) {
            return $true
        }
        if ([string]$ErrorObject -match $encryptionPattern) { return $true }
        return $false
    }

    if ($ErrorObject -is [System.Exception]) {
        $ex = [System.Exception]$ErrorObject
        while ($null -ne $ex) {
            if (($ex.Message ?? '') -match $encryptionPattern) { return $true }
            $ex = $ex.InnerException
        }
        return $false
    }

    return ([string]$ErrorObject -match $encryptionPattern)
}

<#
.SYNOPSIS
    Throws a normalized encrypted-archive extraction error when applicable.
#>
function Resolve-ExtractionError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if (Test-IsEncryptedZipError -ErrorObject $ErrorRecord) {
        throw "Extraction failed for '$ZipPath' (zip may be encrypted): $($ErrorRecord.Exception.Message)"
    }
    throw $ErrorRecord
}

<#
.SYNOPSIS
    Resolves a ZipArchive entry destination and blocks path traversal (Zip Slip).
#>
function Resolve-ZipEntryDestinationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DestinationRootFull,
        [Parameter(Mandatory)][string]$EntryFullName
    )

    if ([string]::IsNullOrWhiteSpace($EntryFullName)) { return $null }

    # Reject rooted/archive-absolute inputs before normalization/trimming.
    if (
        $EntryFullName.StartsWith('/') -or
        $EntryFullName.StartsWith('\') -or
        $EntryFullName -match '^[A-Za-z]:[\\/]' -or
        $EntryFullName.StartsWith('//') -or
        $EntryFullName.StartsWith('\\')
    ) {
        return $null
    }

    # Normalize separators and explicitly reject traversal segments.
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
    $normalizedEntry = ($EntryFullName -replace '\\', '/')
    $segments = @($normalizedEntry -split '/+' | Where-Object { $_ -ne '' -and $_ -ne '.' })
    if ($segments.Count -eq 0) { return $null }
    if (@($segments | Where-Object { $_ -eq '..' }).Count -gt 0) { return $null }

    $relativePath = ($segments -join [string]$directorySeparator)
    if ([System.IO.Path]::IsPathRooted($relativePath)) { return $null }

    # Compute canonical paths from fully-qualified roots to compare like-for-like.
    $rootFull = [System.IO.Path]::GetFullPath($DestinationRootFull)
    $candidate = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($rootFull, $relativePath))
    $rootWithSep = if ($rootFull.EndsWith($directorySeparator)) { $rootFull } else { $rootFull + $directorySeparator }
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }

    if ($candidate.StartsWith($rootWithSep, $comparison)) {
        return $candidate
    }

    return $null
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
.PARAMETER ExpectedFileCount
    Pre-computed file count from Get-ZipFileStats. Returned directly to avoid
    a post-extraction Get-ChildItem walk of the destination folder.
.OUTPUTS
    Int ($ExpectedFileCount as supplied by the caller).
#>
function Expand-ZipToSubfolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$SafeSubfolderName,
        [Parameter(Mandatory)][int]$ExpectedFileCount
    )

    try {
        $target = Join-Path $DestinationRoot $SafeSubfolderName
        $target = Resolve-UniqueDirectoryPath -Path $target
        if (-not (Test-Path -LiteralPath $target)) {
            New-DirectoryIfMissing -Path $target -Force | Out-Null
        }

        Expand-Archive -LiteralPath $ZipPath -DestinationPath $target -Force
        Write-LogDebug "Expand-ZipToSubfolder: '$($ZipPath | Split-Path -Leaf)' -> '$target' ($ExpectedFileCount file(s) per archive manifest)"
        return $ExpectedFileCount

    } catch { Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_ }
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

    $written = 0

    try {
        $zip = [ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                if ([string]::IsNullOrEmpty($entry.Name)) { continue }
                if ($entry.FullName.Contains('..') -or $entry.FullName -match '(^|[\\/])\.\.([\\/]|$)') {
                    Write-LogDebug "Skipped traversal-segment entry: $($entry.FullName)"
                    continue
                }

                $destFull = Resolve-ZipEntryDestinationPath -DestinationRootFull $DestinationRootFull -EntryFullName $entry.FullName
                if ($null -eq $destFull) {
                    Write-LogDebug "Skipped path traversal: $($entry.FullName)"
                    continue
                }

                $destDir = Split-Path -Path $destFull -Parent
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-DirectoryIfMissing -Path $destDir -Force | Out-Null
                }

                $targetPath = $destFull
                if ([System.IO.File]::Exists($targetPath)) {
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
                    # Defensive fallback: if a race or path normalization mismatch causes
                    # a late "already exists" exception under Skip policy, honor Skip.
                    if ($CollisionPolicy -eq 'Skip' -and $_.Exception.Message -imatch 'already exists') { continue }
                    Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_
                }
            }
        } finally {
            $zip.Dispose()
        }

        return $written

    } catch { Resolve-ExtractionError -ZipPath $ZipPath -ErrorRecord $_ }
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
.PARAMETER ExpectedFileCount
    Pre-computed file count from Get-ZipFileStats, threaded to Expand-ZipToSubfolder
    for PerArchiveSubfolder mode so it can be returned without a post-extraction
    directory walk.
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
        [int]$SafeNameMaxLen = 0,
        [int]$ExpectedFileCount = 0
    )

    if (-not (Test-Path -LiteralPath $DestinationRoot)) {
        New-DirectoryIfMissing -Path $DestinationRoot -Force | Out-Null
    }

    $destRootFull = Get-FullPath -Path $DestinationRoot
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
    $safeSub = Get-SafeName -Name $baseName -MaxLength $SafeNameMaxLen

    if ($ExtractMode -eq 'PerArchiveSubfolder') {
        return Expand-ZipToSubfolder -ZipPath $ZipPath -DestinationRoot $DestinationRoot -SafeSubfolderName $safeSub -ExpectedFileCount $ExpectedFileCount
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

                    $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName `
                        -DestinationRoot $DestinationDir `
                        -ExtractMode $Mode `
                        -CollisionPolicy $Policy `
                        -SafeNameMaxLen $SafeNameMaxLen `
                        -ExpectedFileCount $stats.FileCount

                    if ($filesFromZip -is [int]) {
                        $totalFilesExtracted += $filesFromZip
                    } else {
                        $totalFilesExtracted += $stats.FileCount
                    }
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
        ZipCount          = $zipCount
        ProcessedZips     = $processedZips
        FilesExtracted    = $totalFilesExtracted
        UncompressedBytes = $totalUncompressedBytes
        CompressedBytes   = $totalCompressedZipBytes
    }
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
    if (-not $parentItem.Parent) {
        throw "Cannot move zip files: source directory '$SourceDir' is at drive root (no parent directory exists)"
    }
    $parent = $parentItem.Parent.FullName

    if (-not [System.IO.Directory]::Exists($parent)) {
        throw "Parent directory not found: $parent"
    }

    # Writability probe using a temporary file (skip if WhatIf)
    if (-not $WhatIfPreference) {
        $probe = Join-Path $parent ("_write_test_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
        try {
            New-Item -ItemType File -Path $probe -Force | Out-Null
            Remove-Item -LiteralPath $probe -Force
        } catch {
            # Clean up probe file even on failure
            try { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue } catch { }
            throw "Parent directory is not writable: $parent"
        }
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
        if (-not $QuietMode) {
            $pct = [int](($idx) / [math]::Max(1, $total) * 100)
            Write-Progress -Activity "Moving zip files to parent" `
                -Status "$idx / $total : $($zf.Name) ($(Format-Bytes $zf.Length))" `
                -CurrentOperation ("Moved {0} of {1}" -f (Format-Bytes $bytes), (Format-Bytes $totalBytes)) `
                -PercentComplete $pct
        }

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

    if (-not $QuietMode) { Write-Progress -Activity "Moving zip files to parent" -Completed }

    [pscustomobject]@{ Count = $moved; Bytes = $bytes; Destination = $parent; Skipped = $skipped; Overwritten = $overwritten; Renamed = $renamed }
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
        -ErrorList $errors

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

# Always print a summary (even if no zips)
$compressionRatio = if ($totalCompressedZipBytes -gt 0) {
    # Show as multiplier, one decimal (e.g., 3.3x). >1 means compression saved space.
    "{0:N1}x" -f ($totalUncompressedBytes / [double]$totalCompressedZipBytes)
} else { "n/a" }

# Build a view with shorter column names to avoid wrapping on narrow consoles
$summaryView = [pscustomobject]@{
    SrcDir          = $SourceDirectory
    DestDir         = $DestinationDirectory
    Mode            = $ExtractMode
    Policy          = $CollisionPolicy
    ZipsFound       = $zipCount
    ZipsDone        = $processedZips
    Files           = $totalFilesExtracted
    Uncompressed    = (Format-Bytes $totalUncompressedBytes)
    Compressed      = (Format-Bytes $totalCompressedZipBytes)
    Ratio           = $compressionRatio
    ZipsMoved       = ($moveSummary.Count)
    MoveSkipped     = ($moveSummary.Skipped)
    MoveOverwritten = ($moveSummary.Overwritten)
    MoveRenamed     = ($moveSummary.Renamed)
    MovedBytes      = (Format-Bytes $moveSummary.Bytes)
    MovedTo         = ($moveSummary.Destination)
    Errors          = ($errors.Count)
    Duration        = ("{0:hh\:mm\:ss\.fff}" -f $stopwatch.Elapsed)
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
