<#
.SYNOPSIS
  Return immutable module defaults used by helpers and entrypoints.
.DESCRIPTION
  Centralizes timing knobs, video discovery patterns, GDI capture defaults,
  and cropper (Python) dependency hints. Callers typically *read* these values.
  Some areas have CLI/module overrides to keep behavior flexible:

    - Discovery: Start-VideoBatch honors -IncludeExtensions; otherwise uses
      Config.VideoExtensions.
    - Timing: Helpers (e.g., Start-VlcProcess / Stop-Vlc) read PollIntervalMs,
      VideoProbeTimeoutSeconds, StopVlcWaitMs, and WaitProcessTimeoutSeconds.
    - GDI: When neither MaxPerVideoSeconds nor TimeLimitSeconds is set,
      Invoke-GdiCapture uses GdiCaptureDefaultSeconds as a safe fallback.
    - Cropper: Invoke-Cropper consults Python.RequiredPackages for preflight.

  These defaults are intended to be sane and conservative. Tune with care.
.OUTPUTS
  [hashtable] with well-known keys:
    - Timing: PollIntervalMs, VideoProbeTimeoutSeconds,
              SnapshotFallbackTimeoutSeconds, SnapshotDurationGraceSeconds,
              SnapshotTerminationExtraSeconds, StopVlcWaitMs, WaitProcessTimeoutSeconds
    - Discovery: VideoExtensions
    - GDI: GdiCaptureDefaultSeconds
    - Python: RequiredPackages (used by Invoke-Cropper preflight)
.NOTES
  Units and suggested ranges are documented inline per key for maintainability.
  Versioning is sourced from the module manifest; this function does not embed
  version information.
#>
function Get-DefaultConfig {
    @{
        # =========================
        # Timing (ms / seconds)
        # =========================

        # Poll interval (milliseconds) used by Start-VlcProcess while waiting for
        # VLC to start/exit. Smaller = snappier detection, higher CPU; larger =
        # lower CPU, slower responsiveness. Typical range: 100–500 ms.
        PollIntervalMs                  = 200

        # Maximum seconds to wait for the optional Test-VideoPlayable pre-flight
        # VLC probe. If the probe does not exit in this window, it is force-killed
        # and the video is treated as not playable. Typical range: 3–15 s.
        VideoProbeTimeoutSeconds        = 5

        # Last-resort cap (seconds) used when no explicit per-video limit is given
        # AND duration detection fails. When duration is detectable, Start-VideoBatch
        # computes cap = video_duration + SnapshotDurationGraceSeconds instead.
        # Typical range: 60–600 s depending on expected clip durations.
        SnapshotFallbackTimeoutSeconds  = 300

        # Grace margin (seconds) added to a probed video duration to form the
        # per-video snapshot cap: cap = duration + SnapshotDurationGraceSeconds.
        # Accounts for VLC startup, buffering, and slow-flush at end of playback.
        # Typical range: 15–60 s.
        SnapshotDurationGraceSeconds    = 30

        # Extra grace seconds allowed after requesting termination of snapshotting,
        # giving VLC time to flush/close cleanly before any force-kill paths.
        # Typical range: 2–10 s.
        SnapshotTerminationExtraSeconds = 5

        # Seconds without a new frame before Wait-ForSnapshotFrames abandons a stalled
        # VLC session (idle-frame stall detection). Only triggers after the warm-up window
        # elapses. Set to 0 to disable. Typical range: 10–60 s.
        SnapshotIdleTimeoutSeconds      = 20

        # Seconds at the start of a snapshot session during which idle detection is
        # suppressed, to allow slow-starting sources (e.g., cold network shares) to
        # produce their first frame before the idle timer starts counting.
        # Typical range: 5–30 s.
        SnapshotIdleWarmUpSeconds       = 10

        # Milliseconds to wait after CloseMainWindow() before force-terminating VLC
        # in Stop-Vlc. Larger values are gentler on VLC; smaller values speed up
        # teardown on stubborn processes. Typical range: 2000–10000 ms.
        StopVlcWaitMs                   = 5000

        # Seconds to wait in Wait-Process after issuing Stop-Process -Force when
        # VLC doesn’t exit in time. Keep small to avoid long hangs. Typical range:
        # 1–10 s.
        WaitProcessTimeoutSeconds       = 3

        # =========================
        # Discovery (file types)
        # =========================

        # Default extension set for video discovery when callers don’t supply
        # -IncludeExtensions. Keep values lowercase and with a leading dot.
        # Start-VideoBatch will use this list unless overridden.
        VideoExtensions                 = @(
            '.mp4', '.mkv', '.avi', '.mov', '.m4v', '.wmv', '.webm'
        )

        # =========================
        # GDI capture (fallback)
        # =========================

        # Default duration (seconds) for desktop/GDI capture when neither
        # MaxPerVideoSeconds nor TimeLimitSeconds is provided. This ensures
        # finite capture sessions by default. Typical range: 5–30 s.
        GdiCaptureDefaultSeconds        = 10

        # =========================
        # Python / Cropper preflight
        # =========================

        Python                          = @{
            # Packages required by the default cropper script (crop_colours.py).
            # Used by Invoke-Cropper preflight to verify/install dependencies
            # (subject to -NoAutoInstall and environment policy).
            # Keep in sync with crop_colours.py and README dependency notes.
            RequiredPackages = @('opencv-python', 'numpy')
        }
    }
}
