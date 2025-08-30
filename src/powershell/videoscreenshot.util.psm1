<#
.SYNOPSIS
Utility helpers for videoscreenshot.ps1.

.DESCRIPTION
Optional helpers (logging + safe file append). Loaded by the script if present.
Versioning and changelog are tracked by the main script/release tags.

.NOTES
Author: Manoj Bhaskaran
Streams:
  - Warn/Error: native streams (Write-Warning / Write-Error) and mirrored to Debug for diagnosis.
  - Info: primary to Information stream (with -InformationAction Continue); fallback is Write-Output (pipeline-friendly).
#>

function Write-Message {
    <#
    .SYNOPSIS
    Structured console logging with timestamp and color.
    .PARAMETER Level
    One of Info, Warn, Error.
    .PARAMETER Message
    Text to print.
    #>
    param(
        [ValidateSet('Info','Warn','Error')]
        [string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $prefixed = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"
    switch ($Level) {
        'Warn'  { Write-Warning $prefixed }
        'Error' { Write-Error   $prefixed }
        Default {
            try {
                # Route Info to the Information stream; let the host decide how to render it
                Write-Information -MessageData $prefixed -InformationAction Continue
            } catch {
                # Legacy/locked-down shells: fall back to Host only if Information fails
                Write-Host $prefixed -ForegroundColor Cyan
            }
        }
    }
}

function Add-ContentWithRetry {
    <#
    .SYNOPSIS
    Append to a file with limited retries to absorb transient locks.
    .DESCRIPTION
    Attempts an exclusive append to avoid interleaved writes across processes.
    .PARAMETER Path
    Target file.
    .PARAMETER Value
    Line of text to append.
    .PARAMETER MaxAttempts
    Retry attempts (default 3).
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value,
        [int]$MaxAttempts = 3
    )
    for ($i=1; $i -le $MaxAttempts; $i++) {
        try {
            $newline = [Environment]::NewLine
            $bytes   = [System.Text.Encoding]::UTF8.GetBytes($Value + $newline)
            $fs = [System.IO.File]::Open($Path,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None) # exclusive append
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Close()
            return $true
        } catch {
            if ($i -eq $MaxAttempts) {
                Write-Message -Level Error -Message "Failed to append to ${Path}: $($_.Exception.Message)"
                return $false
            }
            Start-Sleep -Milliseconds (200 * $i)
        }
    }
}

function Assert-FolderWritable {
    <#
    .SYNOPSIS
    Ensures a folder exists and is writable (throws if not).
    .PARAMETER Folder
    Target directory path; created if missing.
    #>
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Folder)
    try {
        if (-not (Test-Path -LiteralPath $Folder)) {
            New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        }
        $tmp = Join-Path $Folder (".writetest_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
        [IO.File]::WriteAllText($tmp, 'ok')
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        throw "Folder is not writable: $Folder – $($_.Exception.Message)"
    }
}

function Measure-PostCapture {
    <#
    .SYNOPSIS
    Post-capture measurement/validation and (snapshot) FPS deviation handling.
    .DESCRIPTION
    Determines whether frames were produced and computes frames delta. In snapshot mode,
    also computes achieved FPS and warns if it deviates ≥20% from the requested value.
    #>
    param(
        [switch]$UseVlcSnapshots,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix,
        [int]$PreCount = 0,
        $GdiResult,
        $SnapResult,
        [Parameter(Mandatory)][ValidateRange(1,1000)][int]$RequestedFps,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$VideoPath
    )
    $hadFrames = $false
    $framesDelta = 0
    $achieved = $null

    if ($UseVlcSnapshots) {
        $postCount = (Get-ChildItem -Path $SaveFolder -Filter "$ScenePrefix*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $framesDelta = $postCount - $PreCount
        $hadFrames   = ($framesDelta -gt 0)
        if ($SnapResult -and $SnapResult.ElapsedSeconds -gt 0) {
            $achieved = [Math]::Round($framesDelta / $SnapResult.ElapsedSeconds, 3)
            Write-Debug "Snapshot achieved FPS: $achieved (requested=$RequestedFps, frames=$framesDelta, elapsed=$($SnapResult.ElapsedSeconds)s)"
            if ($RequestedFps -gt 0) {
                $dev = [Math]::Abs($achieved - $RequestedFps) / [double]$RequestedFps
                if ($dev -ge 0.20) {
                    Write-Message -Level Warn -Message ("Snapshot cadence deviates by {0:P0} from requested FPS (requested={1}, achieved={2}) for: {3}" -f $dev, $RequestedFps, $achieved, $VideoPath)
                }
            }
        }
    } else {
        $framesSaved = if ($null -ne $GdiResult) { [int]$GdiResult.FramesSaved } else { 0 }
        $hadFrames   = ($framesSaved -gt 0)
        $framesDelta = $framesSaved
        $achieved    = ($GdiResult?.AchievedFps)
    }

    [pscustomobject]@{
        HadFrames   = [bool]$hadFrames
        FramesDelta = [int]$framesDelta
        AchievedFps = $achieved
    }
}

Export-ModuleMember -Function Write-Message,Add-ContentWithRetry,Assert-FolderWritable,Measure-PostCapture
