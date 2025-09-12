<#
.SYNOPSIS
  Return the (approximate) frames-per-second (FPS) for a video file.

.DESCRIPTION
  Used by the VLC snapshot pipeline to approximate a sensible `--scene-ratio`.
  Strategy order:
    1) **ffprobe** (if on PATH) — parse `avg_frame_rate` / `r_frame_rate`
    2) **Windows Shell (COM)** — read the localized “Frame rate” column (best-effort)
  On failure, returns **0.0** and the caller should fall back to a default (the
  broader tool uses **30.0**). This function emits warnings when it must fall back
  so users understand cadence accuracy may be affected.

  Notes & limitations:
    - Shell parsing is **locale-dependent** and heuristic. We try to discover the
      correct column by name and, failing that, scan for values that look like “XX fps”.
      Decimal separators are normalized (e.g., `29,97` → `29.97`).
    - We aim for a **reasonable approximation**, not scientific precision. For
      accurate analysis, prefer ffprobe output directly.

.PARAMETER Path
  Path to a video file (must exist).

.OUTPUTS
  [double] FPS (0.0 if not detected — callers should fall back to a default).

.EXAMPLE
  Get-VideoFps -Path 'C:\clips\sample.mp4'
  # → 29.97 (via ffprobe) or a close approximation via Windows Shell

.EXAMPLE
  Get-VideoFps -Path '.\movie.mkv'
  # → 0.0 when no strategy is available; caller should use a default (e.g., 30.0).

.NOTES
  - ffprobe invocation uses stable switches and should work across FFmpeg releases.
  - Windows Shell column scan (0–300) mirrors common metadata columns on Windows Explorer.
  - Some metadata providers store FPS as milli-FPS (e.g., `29970`); we treat plain
    integers >300 without a `fps` suffix as milli-FPS and divide by 1000 (documented heuristic).
#>
function Get-VideoFps {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
  )

  # ---- Validation -----------------------------------------------------------
  $full = try { [IO.Path]::GetFullPath($Path) } catch { $Path }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "Get-VideoFps: file not found: $full"
  }

  # ---- Helpers --------------------------------------------------------------
  function ConvertTo-FpsFromFraction {
    <#
    .SYNOPSIS
      Convert a fraction or numeric string to FPS.
    .DESCRIPTION
      Supports:
        - Fraction: "30000/1001"
        - Numeric:  "29.97", "29,97", optionally with trailing " fps"
    .PARAMETER Text
      Fraction or numeric text (possibly localized decimal separator).
    .OUTPUTS
      [double] or $null when parsing fails.
    #>
    param([Parameter(Mandatory)][string]$Text)

    $raw = $Text.Trim()
    # Strip trailing unit if present, e.g. "29.97 fps"
    if ($raw -match '(?i)^(?<num>.+?)\s*fps\s*$') {
      $raw = $Matches['num']
    }
    # Fraction form: N/D (common in ffprobe outputs, e.g., "30000/1001")
    if ($raw -match '^\s*(\d+)\s*/\s*(\d+)\s*$') {
      $num = [double]$Matches[1]
      $den = [double]$Matches[2]
      if ($den -gt 0) { return ($num / $den) }
      return $null
    }
    # Numeric form with locale decimal separators; normalize comma → dot.
    # Examples: "29.97", "29,97" (optionally after stripping " fps")
    $normalized = $raw -replace ',', '.'
    try { return [double]::Parse($normalized, [Globalization.CultureInfo]::InvariantCulture) } catch { }
    return $null
  }

  function Get-FfprobeFps {
    param([Parameter(Mandatory)][string]$FilePath)

    try {
      $ff = Get-Command -Name ffprobe -ErrorAction Stop
    } catch {
      Write-Debug "Get-VideoFps: ffprobe not found on PATH."
      return $null
    }

    try {
      # Equivalent CLI (documented for maintainers):
      #   ffprobe -v error -select_streams v:0 `
      #            -show_entries stream=avg_frame_rate,r_frame_rate `
      #            -of default=nk=1:nw=1 "file"
      $psi = [System.Diagnostics.ProcessStartInfo]::new()
      $psi.FileName = $ff.Source
      $null = $psi.ArgumentList.Add('-v');               $null = $psi.ArgumentList.Add('error')
      $null = $psi.ArgumentList.Add('-select_streams');  $null = $psi.ArgumentList.Add('v:0')
      $null = $psi.ArgumentList.Add('-show_entries');    $null = $psi.ArgumentList.Add('stream=avg_frame_rate,r_frame_rate')
      $null = $psi.ArgumentList.Add('-of');              $null = $psi.ArgumentList.Add('default=nk=1:nw=1')
      $null = $psi.ArgumentList.Add($FilePath)
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError  = $true
      $psi.UseShellExecute        = $false
      $psi.CreateNoWindow         = $true

      $p = [System.Diagnostics.Process]::new()
      $p.StartInfo = $psi
      $null = $p.Start()
      $out = $p.StandardOutput.ReadToEnd()
      $err = $p.StandardError.ReadToEnd()
      $p.WaitForExit()

      if ($p.ExitCode -ne 0) {
        Write-Debug ("Get-VideoFps(ffprobe): exit={0}; stderr={1}" -f $p.ExitCode, $err)
        return $null
      }

      # ffprobe may print multiple lines (avg then r_frame_rate).
      # Pick the first sensible (>0) value.
      $lines = ($out -split "(\r\n|\n|\r)") | Where-Object { $_ -and $_.Trim().Length -gt 0 }
      foreach ($ln in $lines) {
        $fps = ConvertTo-FpsFromFraction -Text $ln
        if ($fps -gt 0) { return [double]$fps }
      }
      return $null
    } catch {
      Write-Debug ("Get-VideoFps(ffprobe) exception: {0}" -f $_.Exception.Message)
      return $null
    }
  }

  function Get-WindowsShellFps {
    param([Parameter(Mandatory)][string]$FilePath)

    try {
      # COM setup
      $shell  = New-Object -ComObject Shell.Application
      $folder = Split-Path -Path $FilePath -Parent
      $file   = Split-Path -Path $FilePath -Leaf
      $sf = $shell.Namespace($folder)
      if ($null -eq $sf) { return $null }
      $item = $sf.ParseName($file)
      if ($null -eq $item) { return $null }

      $candidateIdx = $null
    # Pass 1: find a column whose *name* looks like "Frame rate" (localized).
    # We scan a bounded range [0..300] which covers typical Explorer columns.
      for ($i=0; $i -le 300; $i++) {
        $name = $sf.GetDetailsOf($sf.Items, $i)
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match '(?i)frame\s*rate' -or $name -match '(?i)\bfps\b') { $candidateIdx = $i; break }
      }
      # Pass 2: if not found by name, scan for a value that *looks* like "XX fps"
      if ($null -eq $candidateIdx) {
        for ($i=0; $i -le 300; $i++) {
          $val = $sf.GetDetailsOf($item, $i)
          if ($val -and ($val -match '(?i)\bfps\b')) { $candidateIdx = $i; break }
        }
      }
      if ($null -eq $candidateIdx) { return $null }
      Write-Debug ("Windows Shell: using column index {0} for frame rate." -f $candidateIdx)

      $rawVal = $sf.GetDetailsOf($item, $candidateIdx)
      if ([string]::IsNullOrWhiteSpace($rawVal)) { return $null }

      # Examples seen:
      #   "29.97 fps" (en)
      #   "29,97 fps" (de/fr)
      #   "29970"     (some providers store milli-FPS; we divide by 1000 as a heuristic)
      # The scrub below removes units/symbols prior to parsing
      $scrub = ($rawVal -replace '[^\d\.,/ ]','').Trim()

      $fps = ConvertTo-FpsFromFraction -Text $scrub
      if ($fps) { return [double]$fps }

      if ($scrub -match '^\s*\d+\s*$') {
        $n = [double]$scrub
        if ($n -gt 300) {
        # Heuristic: plain integer with no "fps" suffix and >300 → treat as milli-FPS.
        Write-Warning ("Windows Shell returned large numeric value '{0}' for FPS; interpreting as milli-FPS (dividing by 1000)." -f $scrub)
          return ($n / 1000.0)
        }
        return $n
      }
    } catch {
    # COM can fail in headless contexts; keep this best-effort and continue.
    Write-Debug ("Windows Shell FPS probe failed: {0}" -f $_.Exception.Message)
    }
    return $null
  }

  # ---- Strategy chain -------------------------------------------------------
  $ffFps = Get-FfprobeFps -FilePath $full
  if ($ffFps -gt 0) { return [double]$ffFps }

  $shellFps = Get-WindowsShellFps -FilePath $full
  if ($shellFps -gt 0) {
    Write-Warning ("FPS derived from Windows Shell metadata for '{0}' (ffprobe unavailable or unhelpful). Value={1}" -f $full, $shellFps)
    return [double]$shellFps
  }

  # Unknown — emit a single fallback warning so callers know accuracy may be affected
  Write-Warning ("FPS detection failed for '{0}'. Falling back to default cadence (e.g., 30.0). Snapshot cadence may be approximate." -f $full)
  return 0.0
}
