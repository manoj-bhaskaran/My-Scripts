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
        * Flat: extract all files directly into the destination (supports collision policy).
    - CollisionPolicy (for overlapping paths and/or Flat mode):
        * Skip | Overwrite | Rename (default: Rename)
    - Progress bars for long runs (suppressed by -Quiet).
    - End-of-run summary includes uncompressed bytes and total compressed zip bytes (savings).
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
      - Flat

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
    # Dry run (no changes), show what would happen
    .\Expand-ZipsAndClean.ps1 -WhatIf

.INPUTS
    None.

.OUTPUTS
    Summary is written to the host at the end. Errors are collected and summarized.

.NOTES
    Name     : Expand-ZipsAndClean.ps1
    Version  : 1.1.0
    Author   : Manoj Bhaskaran
    Requires : PowerShell 5.1 or 7+, Microsoft.PowerShell.Archive (Expand-Archive)

    ── Version History ───────────────────────────────────────────────────────────
    1.0.0  Initial release: extraction (PerArchiveSubfolder/Flat), collision policy,
           move zips to parent, optional delete, summary.
    1.1.0  Added progress bars, converted -DeleteSource to [switch] (no default),
           aliases for Source/Destination, compressed-bytes metric, clearer error
           for password-protected zips, unique subfolder naming if exists, parent
           writability check, optional -CleanNonZips, consistent summary printing,
           table summary, ms in duration, and expanded docs/FAQ.

    ── Setup / Module check ─────────────────────────────────────────────────────
    Expand-Archive is provided by Microsoft.PowerShell.Archive.
    • Check availability:
        Get-Module -ListAvailable Microsoft.PowerShell.Archive
    • If missing (PowerShell 7+):
        Install-Module -Name Microsoft.PowerShell.Archive -Scope CurrentUser -Force
      (You may need: Set-PSRepository PSGallery -InstallationPolicy Trusted)

    ── Long Path Support (Windows) ──────────────────────────────────────────────
    If you expect paths > 260 chars, enable LongPathsEnabled:
      HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem
        (DWORD) LongPathsEnabled = 1
    Or via Group Policy: Computer Configuration > Administrative Templates > System > Filesystem
      “Enable Win32 long paths” = Enabled
    PowerShell 7+ and modern .NET improve long path handling, but this script is defensive.

TROUBLESHOOTING & FAQ
    Q: Script seems to hang on large zips.
       A: Use -Verbose to monitor progress; consider running in PowerShell 7+ for better performance.

    Q: I get errors mentioning long paths or path too long.
       A: Enable Long Path Support as noted above. Prefer PowerShell 7+. Keep destination close to drive root.

    Q: Extraction fails for one archive but others work.
       A: Try -Verbose to inspect the failing file. The archive may be corrupted or password-protected.
          Password-protected zips aren’t supported by Expand-Archive; the script will flag this.

    Q: Files in separate zips collide (same names).
       A: Use the default -ExtractMode PerArchiveSubfolder to keep each zip isolated.

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
    [switch]$Quiet
)

#region Helpers

function Write-Info {
    param([string]$Message)
    if (-not $Quiet) { Write-Host $Message }
}

function Get-SafeName {
    param([Parameter(Mandatory)][string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Name.ToCharArray()) {
        if ($invalid -contains $ch -or $ch -eq [char]':') { [void]$sb.Append('_') } else { [void]$sb.Append($ch) }
    }
    $san = $sb.ToString().TrimEnd('.', ' ')
    if ([string]::IsNullOrWhiteSpace($san)) { $san = 'archive' }
    return $san
}

function Resolve-UniquePath {
    param([Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Path $Path -Parent
    $file = Split-Path -Path $Path -Leaf
    $base = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $ext  = [System.IO.Path]::GetExtension($file)
    $stamp = (Get-Date -Format 'yyyyMMddHHmmss')
    $i = 0
    do {
        $suffix = if ($i -eq 0) { "_$stamp" } else { "_$stamp`_$i" }
        $candidate = Join-Path $dir ($base + $suffix + $ext)
        $i++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

function Resolve-UniqueDirectoryPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }
    $parent = Split-Path -Path $Path -Parent
    $leaf   = Split-Path -Path $Path -Leaf
    $stamp = (Get-Date -Format 'yyyyMMddHHmmss')
    $i = 0
    do {
        $suffix = if ($i -eq 0) { "_$stamp" } else { "_$stamp`_$i" }
        $candidate = Join-Path $parent ($leaf + $suffix)
        $i++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

function Test-LongPathsEnabled {
    try {
        $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop
        return ($val.LongPathsEnabled -eq 1)
    } catch { return $false }
}

# Get file stats from a zip (number of files and total uncompressed bytes)
function Get-ZipFileStats {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ZipPath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    # Precompute to avoid parser quirks and to support PS 5.1 cleanly
    $zipItem = Get-Item -LiteralPath $ZipPath
    $compressedLen = [int64]$zipItem.Length

    $result = [pscustomobject]@{
        FileCount         = 0;
        UncompressedBytes = [int64]0;
        CompressedBytes   = $compressedLen
    }

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
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
        Write-Verbose "Failed to read zip stats for: $ZipPath. $_"
    }
    return $result
}

function Expand-ZipSmart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [ValidateSet('PerArchiveSubfolder','Flat')][string]$ExtractMode = 'PerArchiveSubfolder',
        [ValidateSet('Skip','Overwrite','Rename')][string]$CollisionPolicy = 'Rename'
    )

    if (-not (Test-Path -LiteralPath $DestinationRoot)) {
        New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    }

    $baseName   = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
    $safeSub    = Get-SafeName -Name $baseName
    $movedCount = 0

    try {
        if ($ExtractMode -eq 'PerArchiveSubfolder') {
            $target = Join-Path $DestinationRoot $safeSub
            $target = Resolve-UniqueDirectoryPath -Path $target  # avoid clobbering an existing folder
            if (-not (Test-Path -LiteralPath $target)) {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
            }
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $target -Force
            $movedCount = (Get-ChildItem -Path $target -Recurse -File | Measure-Object).Count
            return $movedCount
        }

        # Flat mode
        if ($CollisionPolicy -eq 'Overwrite') {
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $DestinationRoot -Force
            # Count after extraction (best-effort; directories ignored)
            $movedCount = (Get-ChildItem -Path $DestinationRoot -Recurse -File | Measure-Object).Count
            return $movedCount
        } else {
            # For Skip/Rename, extract to a temp staging folder, then move files individually
            $temp = Join-Path $DestinationRoot (".extract_tmp_{0}" -f ([guid]::NewGuid().ToString('N')))
            New-Item -ItemType Directory -Path $temp -Force | Out-Null
            try {
                Expand-Archive -LiteralPath $ZipPath -DestinationPath $temp -Force
                Get-ChildItem -Path $temp -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($temp.Length).TrimStart('\','/')
                    $dest = Join-Path $DestinationRoot $rel
                    $destDir = Split-Path -Path $dest -Parent
                    if (-not (Test-Path -LiteralPath $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    if (Test-Path -LiteralPath $dest) {
                        switch ($CollisionPolicy) {
                            'Skip'    { return }
                            'Rename'  { $dest = Resolve-UniquePath -Path $dest }
                        }
                    }
                    Move-Item -LiteralPath $_.FullName -Destination $dest
                    $movedCount++
                }
            } finally {
                Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
            }
            return $movedCount
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -imatch 'encrypt|password|protected') {
            throw "Extraction failed for '$ZipPath' (zip may be encrypted): $msg"
        }
        throw
    }
}

function Move-Zips-ToParent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourceDir)

    $parentItem = Get-Item -LiteralPath $SourceDir
    $parent = $parentItem.Parent.FullName

    if (-not (Test-Path -LiteralPath $parent)) {
        throw "Parent directory not found: $parent"
    }

    # quick writability check (skip if WhatIf)
    if (-not $WhatIfPreference) {
        $testFile = Join-Path $parent ("._write_test_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
        try {
            "" | Out-File -LiteralPath $testFile -Encoding ascii -NoNewline
            Remove-Item -LiteralPath $testFile -Force
        } catch {
            throw "Parent directory is not writable: $parent"
        }
    }

    $moved = 0
    $bytes = [int64]0
    Get-ChildItem -LiteralPath $SourceDir -Filter *.zip -File | ForEach-Object {
        $target = Join-Path $parent $_.Name
        if (Test-Path -LiteralPath $target) {
            $target = Resolve-UniquePath -Path $target
        }
        Move-Item -LiteralPath $_.FullName -Destination $target
        $moved++
        $bytes += $_.Length
    }
    [pscustomobject]@{ Count = $moved; Bytes = $bytes; Destination = $parent }
}

#endregion Helpers

#------------------------------- Main -------------------------------#

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$errors = New-Object System.Collections.Generic.List[string]

# State for summary
$zipCount                 = 0
$processedZips            = 0
$totalFilesExtracted      = 0
$totalUncompressedBytes   = [int64]0
$totalCompressedZipBytes  = [int64]0
$moveSummary              = [pscustomobject]@{ Count = 0; Bytes = 0; Destination = "" }

try {
    if (-not (Test-Path -LiteralPath $SourceDirectory)) {
        throw "Source directory not found: $SourceDirectory"
    }

    # Destination readiness
    if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
        if ($PSCmdlet.ShouldProcess($DestinationDirectory, "Create destination directory")) {
            New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
        }
    }

    if (-not (Test-LongPathsEnabled)) {
        Write-Verbose "LongPathsEnabled=0; consider enabling to avoid path-length issues."
    }

    $zips = @(Get-ChildItem -LiteralPath $SourceDirectory -Filter *.zip -File -ErrorAction Stop)
    $zipCount = $zips.Count

    Write-Info "Found $zipCount zip file(s) in: $SourceDirectory"
    Write-Info "Extracting to: $DestinationDirectory (Mode: $ExtractMode, Policy: $CollisionPolicy)"

    if ($zipCount -gt 0) {
        $index = 0
        foreach ($zip in $zips) {
            $index++
            try {
                if (-not $Quiet) {
                    $pct = [int](($index - 1) / [math]::Max(1,$zipCount) * 100)
                    Write-Progress -Activity "Extracting archives" -Status $zip.Name -PercentComplete $pct
                }

                if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                    $stats = Get-ZipFileStats -ZipPath $zip.FullName
                    $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName -DestinationRoot $DestinationDirectory -ExtractMode $ExtractMode -CollisionPolicy $CollisionPolicy
                    $totalFilesExtracted     += ( ($filesFromZip -is [int]) ? $filesFromZip : $stats.FileCount )
                    $totalUncompressedBytes  += $stats.UncompressedBytes
                    $totalCompressedZipBytes += $stats.CompressedBytes
                    $processedZips++
                    Write-Verbose "Extracted '$($zip.Name)': files=$($stats.FileCount), uncompressed=$($stats.UncompressedBytes), compressed=$($stats.CompressedBytes)"
                }
            } catch {
                $msg = $_.Exception.Message
                $errors.Add("Extraction failed for '$($zip.FullName)': $msg") | Out-Null
                Write-Verbose $msg
            }
        }

        if (-not $Quiet) {
            Write-Progress -Activity "Extracting archives" -Completed
        }
    }

    # Move zips to parent
    try {
        if ($PSCmdlet.ShouldProcess($SourceDirectory, "Move .zip files to parent")) {
            if (-not $Quiet) {
                Write-Progress -Activity "Moving zip files to parent" -Status "Preparing..." -PercentComplete 0
            }
            $moveSummary = Move-Zips-ToParent -SourceDir $SourceDirectory
            if (-not $Quiet) {
                Write-Progress -Activity "Moving zip files to parent" -Completed
            }
        }
    } catch {
        $msg = "Moving .zip files to parent failed: $($_.Exception.Message)"
        Write-Verbose $msg
        $errors.Add($msg) | Out-Null
    }

    # Optionally delete/clean source directory
    if ($DeleteSource) {
        try {
            # If not cleaning non-zips, warn and list if anything other than zip remains
            $remaining = Get-ChildItem -LiteralPath $SourceDirectory -Recurse -Force -ErrorAction SilentlyContinue
            $nonZips = @($remaining | Where-Object { -not $_.PSIsContainer -and $_.Extension -ne '.zip' -or $_.PSIsContainer })
            if ($nonZips.Count -gt 0 -and -not $CleanNonZips) {
                $errors.Add("DeleteSource skipped: non-zip items remain. Use -CleanNonZips to remove them.") | Out-Null
                Write-Verbose ("Remaining items: `n" + ($nonZips | Select-Object -ExpandProperty FullName | Out-String))
            } else {
                if ($CleanNonZips -and $nonZips.Count -gt 0) {
                    if ($PSCmdlet.ShouldProcess($SourceDirectory, "Clean non-zip items before delete")) {
                        # Remove non-zip files and directories
                        $nonZips | ForEach-Object {
                            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { $errors.Add("Failed to remove: $($_.FullName) -> $($_.Exception.Message)") | Out-Null }
                        }
                    }
                }
                if ($PSCmdlet.ShouldProcess($SourceDirectory, "Delete source directory")) {
                    Remove-Item -LiteralPath $SourceDirectory -Recurse -Force
                }
            }
        } catch {
            $msg = "Failed to delete source directory '$SourceDirectory': $($_.Exception.Message)"
            Write-Verbose $msg
            $errors.Add($msg) | Out-Null
        }
    }

} catch {
    $errors.Add("Fatal error: $($_.Exception.Message)") | Out-Null
} finally {
    $stopwatch.Stop()
}

#------------------------------ Summary -----------------------------#

function Format-Bytes {
    param([Parameter(Mandatory)][int64]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

# Always print a summary (even if no zips)
$summary = [pscustomobject]@{
    SourceDirectory          = $SourceDirectory
    DestinationDirectory     = $DestinationDirectory
    ExtractMode              = $ExtractMode
    CollisionPolicy          = $CollisionPolicy
    ZipsFound                = $zipCount
    ZipsProcessed            = $processedZips
    FilesExtracted           = $totalFilesExtracted
    TotalUncompressedBytes   = $totalUncompressedBytes
    TotalCompressedZipBytes  = $totalCompressedZipBytes
    ZipsMoved                = ($moveSummary.Count)
    ZipsMovedBytes           = ($moveSummary.Bytes)
    ZipsMovedTo              = ($moveSummary.Destination)
    Errors                   = ($errors.Count)
    Duration                 = ("{0:hh\:mm\:ss\.fff}" -f $stopwatch.Elapsed)
}

Write-Host ""
Write-Host "==== Expand-ZipsAndClean Summary ===="
$summary |
    Select-Object `
        SourceDirectory, DestinationDirectory, ExtractMode, CollisionPolicy,
        ZipsFound, ZipsProcessed, FilesExtracted,
        @{n='TotalUncompressed'; e={ Format-Bytes $_.TotalUncompressedBytes }},
        @{n='TotalCompressedZips'; e={ Format-Bytes $_.TotalCompressedZipBytes }},
        ZipsMoved, @{n='ZipsMovedBytes'; e={ Format-Bytes $_.ZipsMovedBytes }},
        ZipsMovedTo, Errors, Duration |
    Format-Table -AutoSize

if ($errors.Count -gt 0) {
    Write-Host "`nNotes / Errors:"
    $errors | ForEach-Object { Write-Host " - $_" }
}

# End of script
