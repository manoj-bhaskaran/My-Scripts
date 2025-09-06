function Wait-ForSnapshotFrames {
  <#
  .SYNOPSIS
  Polls the save folder for VLC snapshot frames with the given prefix.
  .DESCRIPTION
  Returns timing and count statistics. Throws on invalid parameters; does not throw
  if frames are not produced (the caller decides how to interpret that).
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix,
    [ValidateRange(1,36000)][int]$MaxSeconds = 300
  )
  if (-not (Test-Path -LiteralPath $SaveFolder)) { throw "SaveFolder not found: $SaveFolder" }

  $pattern = "${ScenePrefix}*.png"
  $start   = Get-Date
  $pre     = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
  $now     = Get-Date

  while (($now - $start).TotalSeconds -lt $MaxSeconds) {
    Start-Sleep -Milliseconds $script:Config.PollIntervalMs
    $now = Get-Date
    # lightweight count; existence is enough to wake the pipeline
    $null = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1)
  }

  $post   = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
  $delta  = [int]($post - $pre)
  [pscustomobject]@{
    StartTime      = $start
    EndTime        = $now
    ElapsedSeconds = [Math]::Round(($now - $start).TotalSeconds, 3)
    FramesBefore   = $pre
    FramesAfter    = $post
    FramesDelta    = $delta
  }
}
*** End Patch
*** Begin Patch
*** Add File: src/powershell/module/Videoscreenshot/Private/Gdi.Capture.ps1
function Invoke-GdiCapture {
  <#
  .SYNOPSIS
  Captures desktop frames via GDI+ for the given duration and FPS.
  .DESCRIPTION
  Saves PNG images to SaveFolder with the provided ScenePrefix. Throws on parameter
  errors or capture failures.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateRange(1,36000)][int]$DurationSeconds,
    [Parameter(Mandatory)][ValidateRange(1,60)][int]$Fps,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix
  )
  if (-not (Test-Path -LiteralPath $SaveFolder)) { throw "SaveFolder not found: $SaveFolder" }

  try {
    Add-Type -AssemblyName System.Drawing | Out-Null
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
  } catch {
    throw "Failed to load GDI+ assemblies: $($_.Exception.Message)"
  }

  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $width  = $screen.Width
  $height = $screen.Height
  if ($width -le 0 -or $height -le 0) { throw "Invalid screen size ($width x $height)" }

  $intervalMs = [int][Math]::Max(1, [Math]::Round(1000 / [double]$Fps))
  $start      = Get-Date
  $endTarget  = $start.AddSeconds($DurationSeconds)
  $count      = 0

  while ((Get-Date) -lt $endTarget) {
    $bmp = $null
    $gfx = $null
    try {
      $bmp = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
      $gfx = [System.Drawing.Graphics]::FromImage($bmp)
      $gfx.CopyFromScreen($screen.X, $screen.Y, 0, 0, $bmp.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)

      $ts = (Get-Date).ToString('yyyyMMdd_HHmmss_fff')
      $name = '{0}{1}_{2:D5}.png' -f $ScenePrefix, $ts, $count
      $path = Join-Path $SaveFolder $name
      $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
      $count++
    }
    catch {
      throw "GDI capture failed: $($_.Exception.Message)"
    }
    finally {
      if ($gfx) { $gfx.Dispose() }
      if ($bmp) { $bmp.Dispose() }
    }
    Start-Sleep -Milliseconds $intervalMs
  }

  [pscustomobject]@{
    StartTime      = $start
    EndTime        = Get-Date
    ElapsedSeconds = [Math]::Round(((Get-Date) - $start).TotalSeconds, 3)
    FramesSaved    = $count
    AchievedFps    = if ($count -gt 0) { [math]::Round($count / ([double]$DurationSeconds), 3) } else { 0 }
  }
}