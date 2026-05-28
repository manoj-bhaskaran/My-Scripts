<#
.SYNOPSIS
  Frame-rate and duration probes for video files.

.DESCRIPTION
  Provides two public helpers used by the VLC snapshot pipeline:
    - Get-VideoFps      — approximate frames-per-second
    - Get-VideoDuration — duration in seconds

  Both share a common two-strategy pattern:
    1) ffprobe (if on PATH)
    2) Windows Shell COM metadata (best-effort, locale-aware)

  Both return 0.0 on failure; callers are responsible for applying their own
  fallback defaults.

  Private module-level helpers (not exported):
    ConvertTo-FpsFromFraction, Invoke-Ffprobe, Find-ShellColumnIndex,
    Get-ShellMetadataValue,
    Get-FfprobeFps, Get-FfprobeDuration,
    Get-WindowsShellFps, Get-WindowsShellDuration

.NOTES
  - ffprobe invocations use stable switches and should work across FFmpeg releases.
  - Windows Shell column scan covers [0..300] (mirrors common Explorer metadata columns).
  - Shell header matching uses two passes: name-pattern first, then value-pattern
    fallback for fully-localized headers (e.g. "Länge", "Durée").
  - Some metadata providers store FPS as milli-FPS (e.g. `29970`); plain integers
    >300 without an `fps` suffix are divided by 1000 (documented heuristic).
#>

# ── Shared helpers ─────────────────────────────────────────────────────────

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
function ConvertTo-FpsFromFraction {
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
    $normalized = $raw -replace ',', '.'
    try { return [double]::Parse($normalized, [Globalization.CultureInfo]::InvariantCulture) } catch {
        # Failed to parse FPS value, will return null
    }
    return $null
}

<#
.SYNOPSIS
  Run ffprobe and return non-empty stdout lines, or $null on failure.
.PARAMETER FfprobeExe
  Path to the ffprobe binary.
.PARAMETER FilePath
  Path to the media file to probe.
.PARAMETER ShowArgs
  Arguments inserted between the common preamble (-v error) and the
  output-format/file suffix (-of default=nk=1:nw=1 <file>).
  Typically: -show_entries <spec> optionally preceded by -select_streams <stream>.
.OUTPUTS
  [string[]] stdout lines (non-empty), or $null on non-zero exit / exception.
#>
function Invoke-Ffprobe {
    param(
        [Parameter(Mandatory)][string]$FfprobeExe,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ShowArgs
    )
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $FfprobeExe
        $null = $psi.ArgumentList.Add('-v'); $null = $psi.ArgumentList.Add('error')
        foreach ($a in $ShowArgs) { $null = $psi.ArgumentList.Add($a) }
        $null = $psi.ArgumentList.Add('-of'); $null = $psi.ArgumentList.Add('default=nk=1:nw=1')
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
            Write-Debug ("Invoke-Ffprobe: exit={0}; stderr={1}" -f $p.ExitCode, $err)
            return $null
        }
        return ($out -split '(\r\n|\n|\r)') | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    }
    catch {
        Write-Debug ("Invoke-Ffprobe exception: {0}" -f $_.Exception.Message)
        return $null
    }
}

<#
.SYNOPSIS
  Find a Shell namespace column index using a two-pass heuristic.
.DESCRIPTION
  Pass 1: scan column header names against NamePattern (handles English and
          locales where the translated name contains the root word).
  Pass 2: scan item values against ValuePattern (locale-independent fallback
          for headers that are fully translated, e.g. "Länge", "Durée").
.PARAMETER Namespace
  Shell namespace object (IShellFolder / Folder).
.PARAMETER Item
  Shell item (FolderItem) for the file being probed.
.PARAMETER NamePattern
  Regex applied to column header names in Pass 1.
.PARAMETER ValuePattern
  Regex applied to item values in Pass 2.
.OUTPUTS
  [int] column index, or $null when no match is found in either pass.
#>
function Find-ShellColumnIndex {
    param(
        [Parameter(Mandatory)]$Namespace,
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$NamePattern,
        [Parameter(Mandatory)][string]$ValuePattern
    )
    for ($i = 0; $i -le 300; $i++) {
        $name = $Namespace.GetDetailsOf($Namespace.Items, $i)
        if (-not [string]::IsNullOrWhiteSpace($name) -and $name -match $NamePattern) { return $i }
    }
    for ($i = 0; $i -le 300; $i++) {
        $val = $Namespace.GetDetailsOf($Item, $i)
        if ($val -and $val -match $ValuePattern) { return $i }
    }
    return $null
}

<#
.SYNOPSIS
  Retrieve a raw Shell metadata value for a file using a two-pass column search.
.DESCRIPTION
  Consolidates the Shell.Application COM setup, column index lookup via
  Find-ShellColumnIndex, and value fetch used by both Get-WindowsShellFps
  and Get-WindowsShellDuration.
.PARAMETER FilePath
  Absolute path to the media file.
.PARAMETER NamePattern
  Regex applied to column header names in Pass 1.
.PARAMETER ValuePattern
  Regex applied to item values in Pass 2.
.PARAMETER Label
  Short label used in debug messages (e.g. 'frame rate', 'duration').
.OUTPUTS
  [string] raw metadata value, or $null when unavailable.
#>
function Get-ShellMetadataValue {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$NamePattern,
        [Parameter(Mandatory)][string]$ValuePattern,
        [string]$Label = 'metadata'
    )
    try {
        $shell = New-Object -ComObject Shell.Application
        $sf    = $shell.Namespace((Split-Path -Path $FilePath -Parent))
        if ($null -eq $sf) { return $null }
        $item  = $sf.ParseName((Split-Path -Path $FilePath -Leaf))
        if ($null -eq $item) { return $null }
        $idx = Find-ShellColumnIndex -Namespace $sf -Item $item `
            -NamePattern $NamePattern -ValuePattern $ValuePattern
        if ($null -eq $idx) { return $null }
        Write-Debug ("Windows Shell: using column index {0} for {1}." -f $idx, $Label)
        $rawVal = $sf.GetDetailsOf($item, $idx)
        if ([string]::IsNullOrWhiteSpace($rawVal)) { return $null }
        return $rawVal
    }
    catch {
        Write-Debug ("Windows Shell {0} probe failed for '{1}': {2}" -f $Label, $FilePath, $_.Exception.Message)
        return $null
    }
}

# ── FPS helpers ────────────────────────────────────────────────────────────

function Get-FfprobeFps {
    param([Parameter(Mandatory)][string]$FilePath)
    try { $ff = Get-Command -Name ffprobe -ErrorAction Stop }
    catch { Write-Debug 'Get-VideoFps: ffprobe not found on PATH.'; return $null }

    # Equivalent CLI: ffprobe -v error -select_streams v:0
    #   -show_entries stream=avg_frame_rate,r_frame_rate -of default=nk=1:nw=1 "file"
    $lines = Invoke-Ffprobe -FfprobeExe $ff.Source -FilePath $FilePath `
        -ShowArgs @('-select_streams', 'v:0', '-show_entries', 'stream=avg_frame_rate,r_frame_rate')
    if ($null -eq $lines) { return $null }

    # ffprobe may print multiple lines (avg then r_frame_rate); pick first >0.
    foreach ($ln in $lines) {
        $fps = ConvertTo-FpsFromFraction -Text $ln
        if ($fps -gt 0) { return [double]$fps }
    }
    return $null
}

function Get-WindowsShellFps {
    param([Parameter(Mandatory)][string]$FilePath)
    $rawVal = Get-ShellMetadataValue -FilePath $FilePath `
        -NamePattern '(?i)(frame\s*rate|\bfps\b)' -ValuePattern '(?i)\bfps\b' -Label 'frame rate'
    if ($null -eq $rawVal) { return $null }

    # Examples: "29.97 fps" (en), "29,97 fps" (de/fr), "29970" (milli-FPS heuristic)
    $scrub = ($rawVal -replace '[^\d\.,/ ]', '').Trim()
    $fps = ConvertTo-FpsFromFraction -Text $scrub
    if ($fps) { return [double]$fps }

    if ($scrub -match '^\s*\d+\s*$') {
        $n = [double]$scrub
        if ($n -gt 300) {
            Write-Warning ("Windows Shell returned large numeric value '{0}' for FPS; interpreting as milli-FPS (dividing by 1000)." -f $scrub)
            return ($n / 1000.0)
        }
        return $n
    }
    return $null
}

# ── Duration helpers ───────────────────────────────────────────────────────

function Get-FfprobeDuration {
    param([Parameter(Mandatory)][string]$FilePath)
    try { $ff = Get-Command -Name ffprobe -ErrorAction Stop }
    catch { Write-Debug 'Get-VideoDuration: ffprobe not found on PATH.'; return $null }

    # Equivalent CLI: ffprobe -v error -show_entries format=duration
    #   -of default=nk=1:nw=1 "file"
    $lines = Invoke-Ffprobe -FfprobeExe $ff.Source -FilePath $FilePath `
        -ShowArgs @('-show_entries', 'format=duration')
    if ($null -eq $lines) { return $null }

    $trimmed = $lines | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }
    try {
        $d = [double]::Parse(($trimmed -replace ',', '.'), [Globalization.CultureInfo]::InvariantCulture)
        if ($d -gt 0) { return [double]$d }
    }
    catch { Write-Debug ("Get-FfprobeDuration: failed to parse '{0}'" -f $trimmed) }
    return $null
}

function Get-WindowsShellDuration {
    param([Parameter(Mandatory)][string]$FilePath)
    # Pass 1: name matches English/similar; Pass 2: value is locale-independent H:MM:SS shape
    $rawVal = Get-ShellMetadataValue -FilePath $FilePath `
        -NamePattern '(?i)(\blength\b|\bduration\b)' `
        -ValuePattern '^\s*\d{1,3}:\d{2}:\d{2}\s*$' -Label 'duration'
    if ($null -eq $rawVal) { return $null }

    # Parse HH:MM:SS / H:MM:SS
    if ($rawVal -match '^\s*(\d+):(\d+):(\d+)\s*$') {
        return [double]([int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [int]$Matches[3])
    }
    # Parse MM:SS
    if ($rawVal -match '^\s*(\d+):(\d+)\s*$') {
        return [double]([int]$Matches[1] * 60 + [int]$Matches[2])
    }
    # Plain numeric seconds (with optional decimal)
    $scrub = ($rawVal -replace '[^\d\.,]', '').Trim() -replace ',', '.'
    if ($scrub -match '^\d+(\.\d+)?$') {
        try {
            $d = [double]::Parse($scrub, [Globalization.CultureInfo]::InvariantCulture)
            if ($d -gt 0) { return [double]$d }
        }
        catch { }
    }
    return $null
}

# ── Public functions ───────────────────────────────────────────────────────

<#
.SYNOPSIS
  Return the (approximate) frames-per-second (FPS) for a video file.

.DESCRIPTION
  Used by the VLC snapshot pipeline to approximate a sensible `--scene-ratio`.
  Strategy order:
    1) ffprobe (if on PATH) — parse `avg_frame_rate` / `r_frame_rate`
    2) Windows Shell (COM) — read the localized "Frame rate" column (best-effort)
  On failure, returns 0.0 and the caller should fall back to a default (the
  broader tool uses 30.0). This function emits warnings when it must fall back
  so users understand cadence accuracy may be affected.

  Notes & limitations:
    - Shell parsing is locale-dependent and heuristic. Decimal separators are
      normalized (e.g., `29,97` → `29.97`).
    - We aim for a reasonable approximation, not scientific precision.

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
#>
function Get-VideoFps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $full = try { [IO.Path]::GetFullPath($Path) } catch { $Path }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Get-VideoFps: file not found: $full"
    }

    $ffFps = Get-FfprobeFps -FilePath $full
    if ($ffFps -gt 0) { return [double]$ffFps }

    $shellFps = Get-WindowsShellFps -FilePath $full
    if ($shellFps -gt 0) {
        Write-Warning ("FPS derived from Windows Shell metadata for '{0}' (ffprobe unavailable or unhelpful). Value={1}" -f $full, $shellFps)
        return [double]$shellFps
    }

    Write-Warning ("FPS detection failed for '{0}'. Falling back to default cadence (e.g., 30.0). Snapshot cadence may be approximate." -f $full)
    return 0.0
}

<#
.SYNOPSIS
  Return the duration (in seconds) for a video file.

.DESCRIPTION
  Used by the VLC snapshot pipeline to compute a duration-aware per-video
  timeout cap instead of the flat SnapshotFallbackTimeoutSeconds constant.
  Strategy order:
    1) ffprobe (if on PATH) — parse `format=duration`
    2) Windows Shell (COM) — read the localized "Length"/"Duration" column (best-effort)
  On failure, returns 0.0 and the caller should fall back to SnapshotFallbackTimeoutSeconds.
  This function emits warnings when it must fall back so users understand cap accuracy
  may be affected.

  Notes & limitations:
    - Shell parsing is locale-dependent and heuristic. Both name-pattern and value-pattern
      passes are used to support fully-localized headers (e.g. "Länge", "Durée").
    - We aim for a reasonable approximation — sufficient to scale the backstop cap to the
      video's own duration rather than using a blind constant.

.PARAMETER Path
  Path to a video file (must exist).

.OUTPUTS
  [double] Duration in seconds (0.0 if not detected — callers should fall back to a default).

.EXAMPLE
  Get-VideoDuration -Path 'C:\clips\sample.mp4'
  # → 183.5 (via ffprobe)

.EXAMPLE
  Get-VideoDuration -Path '.\short.mkv'
  # → 0.0 when detection fails; caller should use SnapshotFallbackTimeoutSeconds.
#>
function Get-VideoDuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $full = try { [IO.Path]::GetFullPath($Path) } catch { $Path }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Get-VideoDuration: file not found: $full"
    }

    $ffDuration = Get-FfprobeDuration -FilePath $full
    if ($ffDuration -gt 0) { return [double]$ffDuration }

    $shellDuration = Get-WindowsShellDuration -FilePath $full
    if ($shellDuration -gt 0) {
        Write-Warning ("Duration derived from Windows Shell metadata for '{0}' (ffprobe unavailable or unhelpful). Value={1}s" -f $full, $shellDuration)
        return [double]$shellDuration
    }

    Write-Warning ("Duration detection failed for '{0}'. Caller should fall back to SnapshotFallbackTimeoutSeconds." -f $full)
    return 0.0
}
