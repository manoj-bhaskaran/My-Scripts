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

        $mt = Resolve-MoveTarget -Zip $zf -Parent $parent -CollisionPolicy $CollisionPolicy

        if ($mt.PolicyTag -eq 'Skip') {
            $skipped++
            continue
        }

        Move-FileWithRetry -Source $zf.FullName -Destination $mt.TargetPath -Force:($mt.PolicyTag -eq 'Overwrite')
        if ($mt.PolicyTag -eq 'Overwrite') { $overwritten++ }
        elseif ($mt.PolicyTag -eq 'Rename') { $renamed++ }
        $moved++
        $bytes += $zf.Length
    }

    Show-ProgressPhase -Activity "Moving zip files to parent" -Status "Done" `
        -Current $total -Total $total -QuietMode $QuietMode -Completed

    [pscustomobject]@{ Count = $moved; Bytes = $bytes; Destination = $parent; Skipped = $skipped; Overwritten = $overwritten; Renamed = $renamed }
}
