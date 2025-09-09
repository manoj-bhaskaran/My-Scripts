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
    } catch {
        throw "GDI capture requires Windows (System.Drawing & System.Windows.Forms). $_"
    }

    if (-not (Test-Path -LiteralPath $SaveFolder)) {
        try {
            New-Item -ItemType Directory -Path $SaveFolder -Force | Out-Null
        } catch {
            throw "Unable to create SaveFolder '$SaveFolder': $($_.Exception.Message)"
        }
    }

    # Determine capture bounds (primary screen)
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    if ($null -eq $screen) { throw "No primary screen detected for GDI capture." }
    $bounds = $screen.Bounds
    $width  = [int]$bounds.Width
    $height = [int]$bounds.Height
    if ($width -le 0 -or $height -le 0) { throw "Invalid screen bounds reported: ${width}x${height}." }

    # Cadence control
    $intervalMs = [int][Math]::Round(1000 / [double]$Fps, 0)
    if ($intervalMs -lt 1) { $intervalMs = 1 }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $deadline  = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
    $framesSaved = 0

    # Pre-create a reusable bitmap/graphics buffer to reduce GC pressure
    $bitmap = $null
    $g      = $null
    try {
        $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g      = [System.Drawing.Graphics]::FromImage($bitmap)
        $g.CopyFromScreen(0, 0, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy) # warm-up
    } catch {
        if ($g) { try { $g.Dispose() } catch {} }
        if ($bitmap) { try { $bitmap.Dispose() } catch {} }
        throw "Failed to initialize GDI capture surface: $($_.Exception.Message)"
    }

    try {
        $index = 0
        while ([DateTime]::UtcNow -lt $deadline) {
            $frameStart = $stopwatch.ElapsedMilliseconds
            try {
                $g.CopyFromScreen(0, 0, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
                # Zero-padded index to keep lexical order (matches VLC snapshot ordering semantics)
                $name = ('{0}{1}.png' -f $ScenePrefix, $index.ToString('D6'))
                $path = Join-Path $SaveFolder $name
                $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
                $framesSaved++
                $index++
            } catch {
                throw ("GDI capture save failed at frame {0}: {1}" -f $index, $_.Exception.Message)
            }

            # Sleep remaining time in cadence interval
            $elapsedThisFrame = [int]($stopwatch.ElapsedMilliseconds - $frameStart)
            $sleepMs = $intervalMs - $elapsedThisFrame
            if ($sleepMs -gt 0) {
                Start-Sleep -Milliseconds $sleepMs
            } else {
                # If we can't keep up, continue without additional delay
            }
        }
    } finally {
        if ($g)      { try { $g.Dispose() } catch {} }
        if ($bitmap) { try { $bitmap.Dispose() } catch {} }
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