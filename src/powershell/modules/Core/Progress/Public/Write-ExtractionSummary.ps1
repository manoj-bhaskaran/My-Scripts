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
        $compressionRatio = if ($CompressedBytes -gt 0) { "{0:N1}x" -f ($UncompressedBytes / [double]$CompressedBytes) } else { "n/a" }

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
        $effectiveWidth = if ($ConsoleWidth -gt 0) { $ConsoleWidth } elseif ($null -ne $rawWidth) { $rawWidth } else { 120 }

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
