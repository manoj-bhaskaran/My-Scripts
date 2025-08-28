<#
.SYNOPSIS
    Unzips all .zip files from a source folder into a destination folder, moves the .zip files
    to the parent of the source folder, and deletes the now-empty source folder. Prints a summary.

.DESCRIPTION
    This script is designed for the workflow:
      - Source folder (default): C:\Users\manoj\Downloads\picconvert
      - Destination folder (default): C:\Users\manoj\OneDrive\Desktop\New folder
      - After extraction, all .zip files in the source are moved to the source’s parent
        (default: C:\Users\manoj\Downloads)
      - Finally, the source folder is deleted.

    Highlights
    - Handles unusually long and special-character file names using -LiteralPath and safe naming.
    - Collision policies for extracted files (Skip/Overwrite/Rename).
    - Extraction mode:
        * PerArchiveSubfolder (default): extracts each zip to its own subfolder (robust, avoids collisions)
        * Flat: extracts all files directly into the destination (faster to browse, add collision handling)
    - Detailed end-of-run summary: number of zips, files extracted, bytes, moves, errors, duration.
    - Robust error handling, ShouldProcess support (WhatIf/Confirm), Verbose logging.
    - Self-contained documentation, setup, usage, troubleshooting & FAQs.

.PARAMETER SourceDirectory
    Directory containing .zip files to extract.
    Default: C:\Users\manoj\Downloads\picconvert

.PARAMETER DestinationDirectory
    Directory to extract contents into.
    Default: C:\Users\manoj\OneDrive\Desktop\New folder

.PARAMETER ExtractMode
    Extraction strategy. One of:
      - PerArchiveSubfolder (default): extract each .zip into its own subfolder named after the zip
      - Flat: extract all files directly into DestinationDirectory
    Default: PerArchiveSubfolder

.PARAMETER CollisionPolicy
    What to do when a target file already exists (only applicable/meaningful in Flat mode or when
    a zip contains overlapping file paths):
      - Skip       : leave existing files untouched, skip the incoming file
      - Overwrite  : replace existing files
      - Rename     : save incoming file with a unique suffix
    Default: Rename

.PARAMETER DeleteSource
    If specified, deletes the source directory after moving the zips out.
    Default: On (switch present by default). To keep source directory, pass -DeleteSource:$false

.PARAMETER Quiet
    Suppress non-essential console output (summary still prints).

.EXAMPLE
    # Run with defaults (recommended robust mode):
    .\Expand-ZipsAndClean.ps1

.EXAMPLE
    # Extract all zips into one flat folder, overwrite collisions, show verbose logs:
    .\Expand-ZipsAndClean.ps1 -ExtractMode Flat -CollisionPolicy Overwrite -Verbose

.EXAMPLE
    # Dry run: see what would happen without making changes
    .\Expand-ZipsAndClean.ps1 -WhatIf

.EXAMPLE
    # Custom paths
    .\Expand-ZipsAndClean.ps1 -SourceDirectory "D:\temp\picconvert" -DestinationDirectory "E:\New folder"

.INPUTS
    None.

.OUTPUTS
    Summary is written to the host at the end. Errors are collected and summarized.

.NOTES
    Version   : 1.0.0
    Requires  : PowerShell 5.1 or PowerShell 7+, Microsoft.PowerShell.Archive (Expand-Archive)
    Author    : Manoj Bhaskaran

    Long Path Support (Windows):
      - If you expect paths > 260 chars, enable LongPathsEnabled:
        * Local Group Policy: Computer Configuration > Administrative Templates > System > Filesystem > "Enable Win32 long paths" = Enabled
        * Or set registry key (requires reboot):
            HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem
            (DWORD) LongPathsEnabled = 1
      - PowerShell 7+ and modern .NET improve long path handling. This script still tries to be defensive.

TROUBLESHOOTING & FAQ
    Q: I get errors mentioning long paths or path too long.
       A: Enable Long Path Support as noted above. Prefer PowerShell 7+. Keep destination closer to the drive root.

    Q: Extraction fails for one archive but others work.
       A: Try -Verbose to inspect the failing file. Check if the zip is corrupted. Run again with -ExtractMode PerArchiveSubfolder
          to isolate conflicts. If collision is the issue in Flat mode, try -CollisionPolicy Overwrite or Rename.

    Q: Files in separate zips collide (same names).
       A: Use the default -ExtractMode PerArchiveSubfolder to keep each zip’s content isolated.

    Q: I want to preview actions without changing files.
       A: Use -WhatIf (and optionally -Confirm for prompts).

    Q: The source folder didn’t delete.
       A: It will only delete after zips are moved and if -DeleteSource is true. Check if any non-zip files remain or
          something locks the folder (e.g., open Explorer window). Close apps holding files and try again.

    Q: How to see more detail?
       A: Use -Verbose.

#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory = "C:\Users\manoj\Downloads\picconvert",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationDirectory = "C:\Users\manoj\OneDrive\Desktop\New folder",

    [Parameter()]
    [ValidateSet('PerArchiveSubfolder', 'Flat')]
    [string]$ExtractMode = 'PerArchiveSubfolder',

    [Parameter()]
    [ValidateSet('Skip', 'Overwrite', 'Rename')]
    [string]$CollisionPolicy = 'Rename',

    [Parameter()]
    [bool]$DeleteSource = $true,

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
    $result = [pscustomobject]@{ FileCount = 0; UncompressedBytes = [int64]0 }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                # Directory entries have empty Name
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

# Expand a zip with collision handling for Flat mode when needed
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

    if ($ExtractMode -eq 'PerArchiveSubfolder') {
        $target = Join-Path $DestinationRoot $safeSub
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
        # For Skip/Rename, extract to a temp subfolder, then move files individually
        $temp = Join-Path $DestinationRoot (".extract_tmp_{0}" -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        try {
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $temp -Force
            # Move each file from temp to destination, preserving relative structure
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
}

function Move-Zips-ToParent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourceDir)

    $parent = (Get-Item -LiteralPath $SourceDir).Parent.FullName
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

    # Warn about long paths if likely
    if (-not (Test-LongPathsEnabled)) {
        Write-Verbose "LongPathsEnabled=0; consider enabling to avoid path-length issues."
    }

    $zips = Get-ChildItem -LiteralPath $SourceDirectory -Filter *.zip -File -ErrorAction Stop
    $zipCount = ($zips | Measure-Object).Count

    if ($zipCount -eq 0) {
        Write-Info "No .zip files found in: $SourceDirectory"
        if ($DeleteSource -and $PSCmdlet.ShouldProcess($SourceDirectory, "Remove empty source directory")) {
            Remove-Item -LiteralPath $SourceDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
        return
    }

    Write-Info "Found $zipCount zip file(s) in: $SourceDirectory"
    Write-Info "Extracting to: $DestinationDirectory (Mode: $ExtractMode, Policy: $CollisionPolicy)"

    $totalFilesExtracted     = 0
    $totalUncompressedBytes  = [int64]0
    $processedZips           = 0

    foreach ($zip in $zips) {
        try {
            if ($PSCmdlet.ShouldProcess($zip.FullName, "Extract")) {
                $stats = Get-ZipFileStats -ZipPath $zip.FullName
                $filesFromZip = Expand-ZipSmart -ZipPath $zip.FullName -DestinationRoot $DestinationDirectory -ExtractMode $ExtractMode -CollisionPolicy $CollisionPolicy
                if ($filesFromZip -is [int]) { $totalFilesExtracted += $filesFromZip } else { $totalFilesExtracted += $stats.FileCount }
                $totalUncompressedBytes += $stats.UncompressedBytes
                $processedZips++
                Write-Verbose "Extracted '$($zip.Name)': files=$($stats.FileCount), bytes=$($stats.UncompressedBytes)"
            }
        } catch {
            $msg = "Extraction failed for '$($zip.FullName)': $($_.Exception.Message)"
            Write-Verbose $msg
            $errors.Add($msg) | Out-Null
        }
    }

    # Move zips to parent
    $moveSummary = [pscustomobject]@{ Count = 0; Bytes = 0; Destination = "" }
    try {
        if ($PSCmdlet.ShouldProcess($SourceDirectory, "Move .zip files to parent")) {
            $moveSummary = Move-Zips-ToParent -SourceDir $SourceDirectory
        }
    } catch {
        $msg = "Moving .zip files to parent failed: $($_.Exception.Message)"
        Write-Verbose $msg
        $errors.Add($msg) | Out-Null
    }

    # Delete source directory if requested
    if ($DeleteSource) {
        try {
            if ($PSCmdlet.ShouldProcess($SourceDirectory, "Delete source directory")) {
                Remove-Item -LiteralPath $SourceDirectory -Recurse -Force
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

$summary = [pscustomobject]@{
    SourceDirectory         = $SourceDirectory
    DestinationDirectory    = $DestinationDirectory
    ExtractMode             = $ExtractMode
    CollisionPolicy         = $CollisionPolicy
    ZipsFound               = $zipCount
    ZipsProcessed           = $processedZips
    FilesExtracted          = $totalFilesExtracted
    TotalUncompressedBytes  = $totalUncompressedBytes
    ZipsMoved               = ($moveSummary.Count)
    ZipsMovedBytes          = ($moveSummary.Bytes)
    ZipsMovedTo             = ($moveSummary.Destination)
    Errors                  = ($errors.Count)
    Duration                = ("{0:hh\:mm\:ss}" -f $stopwatch.Elapsed)
}

Write-Host ""
Write-Host "==== Unzip & Archive Summary ===="
$summary |
    Select-Object SourceDirectory, DestinationDirectory, ExtractMode, CollisionPolicy,
                  ZipsFound, ZipsProcessed, FilesExtracted,
                  @{n='TotalUncompressed'; e={ Format-Bytes $_.TotalUncompressedBytes }},
                  ZipsMoved, @{n='ZipsMovedBytes'; e={ Format-Bytes $_.ZipsMovedBytes }},
                  ZipsMovedTo, Errors, Duration |
    Format-List

if ($errors.Count -gt 0) {
    Write-Host "`nErrors:"
    $errors | ForEach-Object { Write-Host " - $_" }
}

# End of script
