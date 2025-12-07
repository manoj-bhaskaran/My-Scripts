<#
.SYNOPSIS
  Capture desktop frames via GDI and save them as PNGs.
.DESCRIPTION
  Hardened capture with clearer docs and safer defaults:
   - Robust monitor selection: prefer PrimaryScreen; fall back to first detected screen;
     throw a clear error when no displays are available.
   - Retry on file saves to absorb transient I/O issues (AV scans, network hiccups).
   - Rich inline comments for resource lifecycle (HDC/Bitmap/Graphics) and timing.
  Helpers follow the “helpers throw; caller owns user-facing messages” policy.
#>

function Save-ImageWithRetry {
    <#
  .SYNOPSIS
    Save a System.Drawing.Bitmap with retries (caller disposes the bitmap).
  .PARAMETER Bitmap
    The bitmap instance to save.
  .PARAMETER Path
    Destination file path (PNG).
  .PARAMETER Attempts
    Number of save attempts with linear backoff (default: 3).
  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(1, 10)][int]$Attempts = 3
    )
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
            return
        }
        catch {
            if ($i -ge $Attempts) {
                throw ("GDI capture: failed to save '{0}' after {1} attempt(s): {2}" -f $Path, $Attempts, $_.Exception.Message)
            }
            Start-Sleep -Milliseconds (150 * $i)
        }
    }
}

function Invoke-GdiCapture {
    <#
    .SYNOPSIS
    Capture desktop frames using GDI+ for a fixed duration at a target FPS.
    .DESCRIPTION
    Uses System.Drawing to copy the primary screen to bitmaps at a fixed cadence, saving
    PNG files with the given prefix into SaveFolder. Throws on failure.
    .PARAMETER DurationSeconds
    How long to capture (seconds). Must be >= 1.
    .PARAMETER Fps
    Target frames per second (1–60).
    .PARAMETER SaveFolder
    Destination folder for frames.
    .PARAMETER ScenePrefix
    File prefix for saved frames (files are named '<prefix><index>.png').
    .OUTPUTS
    [pscustomobject] with FramesSaved, AchievedFps, ElapsedSeconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateRange(1, 86400)][int]$DurationSeconds,
        [Parameter(Mandatory)][ValidateRange(1, 60)][int]$Fps,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix
    )

    # Ensure dependencies (Windows-only API surface)
    try {
        Add-Type -AssemblyName System.Drawing | Out-Null
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
    }
    catch {
        throw "GDI capture requires Windows (System.Drawing & System.Windows.Forms). $_"
    }

    if (-not (Test-Path -LiteralPath $SaveFolder)) {
        try {
            New-Item -ItemType Directory -Path $SaveFolder -Force | Out-Null
        }
        catch {
            throw "Unable to create SaveFolder '$SaveFolder': $($_.Exception.Message)"
        }
    }

    # ---- Monitor discovery (robust) -----------------------------------------
    # Prefer the primary screen; if not reported, fall back to the first detected.
    $allScreens = [System.Windows.Forms.Screen]::AllScreens
    if ($null -eq $allScreens -or $allScreens.Count -le 0) {
        throw "GDI capture: no displays detected (Screen.AllScreens is empty)."
    }
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    if ($null -eq $screen) { $screen = $allScreens[0] }
    $bounds = $screen.Bounds  # includes X/Y offsets for multi-monitor layouts
    $deviceName = '<unknown>'
    try { $deviceName = $screen.DeviceName } catch {
        # DeviceName property may not be available in all environments
    }
    Write-Debug ("GDI: capturing screen {0} {1}x{2} at ({3},{4})" -f $deviceName, $bounds.Width, $bounds.Height, $bounds.X, $bounds.Y)
    $width = [int]$bounds.Width
    $height = [int]$bounds.Height
    if ($width -le 0 -or $height -le 0) { throw "Invalid screen bounds reported: ${width}x${height}." }

    # Cadence control
    $intervalMs = [int][Math]::Round(1000 / [double]$Fps, 0)
    if ($intervalMs -lt 1) { $intervalMs = 1 }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $deadline = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
    $framesSaved = 0

    # Pre-create a reusable bitmap/graphics buffer to reduce GC pressure
    $bitmap = $null
    $g = $null
    try {
        $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        # Warm-up one copy; include X/Y so multi-monitor offsets are respected.
        $g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
    }
    catch {
        if ($g) { try { $g.Dispose() } catch {
                # Graphics object may already be disposed
            } 
        }
        if ($bitmap) { try { $bitmap.Dispose() } catch {
                # Bitmap may already be disposed
            } 
        }
        throw "Failed to initialize GDI capture surface: $($_.Exception.Message)"
    }

    try {
        $index = 0
        while ([DateTime]::UtcNow -lt $deadline) {
            $frameStart = $stopwatch.ElapsedMilliseconds
            try {
                # Copy pixels from the chosen screen's top-left (accounts for offsets).
                $g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
                # Zero-padded index to keep lexical ordering stable across viewers.
                $name = ('{0}{1}.png' -f $ScenePrefix, $index.ToString('D6'))
                $path = Join-Path $SaveFolder $name
                # Retry saves to absorb transient I/O issues (AV scans, network hiccups).
                Save-ImageWithRetry -Bitmap $bitmap -Path $path -Attempts 3
                $framesSaved++
                $index++
            }
            catch {
                throw ("GDI capture save failed at frame {0}: {1}" -f $index, $_.Exception.Message)
            }

            # Sleep remaining time in cadence interval
            $elapsedThisFrame = [int]($stopwatch.ElapsedMilliseconds - $frameStart)
            $sleepMs = $intervalMs - $elapsedThisFrame
            if ($sleepMs -gt 0) {
                Start-Sleep -Milliseconds $sleepMs
            }
            else {
                # If we can't keep up, continue without additional delay
            }
        }
    }
    finally {
        if ($g) { try { $g.Dispose() } catch {
                # Graphics object may already be disposed
            } 
        }
        if ($bitmap) { try { $bitmap.Dispose() } catch {
                # Bitmap may already be disposed
            } 
        }
        $stopwatch.Stop()
    }

    $elapsedSeconds = [Math]::Max(0.001, $stopwatch.Elapsed.TotalSeconds)
    $achieved = [Math]::Round($framesSaved / $elapsedSeconds, 3)
    [pscustomobject]@{
        FramesSaved    = [int]$framesSaved
        AchievedFps    = [double]$achieved
        ElapsedSeconds = [double]$elapsedSeconds
    }
}
