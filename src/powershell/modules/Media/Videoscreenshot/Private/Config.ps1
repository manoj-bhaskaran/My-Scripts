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
      VideoProbeTimeoutSeconds, SnapshotTerminationExtraSeconds, StopVlcWaitMs, and WaitProcessTimeoutSeconds.
    - GDI: When neither MaxPerVideoSeconds nor TimeLimitSeconds is set,
      Invoke-GdiCapture uses GdiCaptureDefaultSeconds as a safe fallback.
    - Cropper: Invoke-Cropper consults Python.RequiredPackages for preflight.

  These defaults are intended to be sane and conservative. Tune with care.
.OUTPUTS
  [hashtable] with well-known keys:
    - Timing: PollIntervalMs, VideoProbeTimeoutSeconds,
              SnapshotFallbackTimeoutSeconds, SnapshotDurationGraceSeconds,
              SnapshotDurationSlackFactor, SnapshotMinimumTimeoutSeconds,
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
        # computes a generous safety-net cap from duration, slack, floor, and grace.
        # Typical range: 60–600 s depending on expected clip durations.
        SnapshotFallbackTimeoutSeconds  = 300

        # Multiplier applied to probed video duration when computing the VLC
        # snapshot safety-net cap. This makes --play-and-exit the normal completion
        # signal while absorbing slow decode and under-reported metadata.
        # Typical range: 1.5–3.0.
        SnapshotDurationSlackFactor     = 2.0

        # Minimum safety-net cap (seconds) for duration-probed VLC snapshot runs.
        # The floor does not delay healthy short clips because polling exits when
        # VLC self-exits; it only bounds genuinely stuck sessions.
        # Typical range: 60–300 s.
        SnapshotMinimumTimeoutSeconds   = 120

        # Grace margin (seconds) added after the duration-derived slack/floor cap.
        # Accounts for VLC startup, buffering, and slow-flush at end of playback.
        # Typical range: 15–120 s.
        SnapshotDurationGraceSeconds    = 60

        # Extra seconds Stop-Vlc waits after requesting normal process termination
        # of a still-running dummy-interface snapshot session, giving VLC's scene
        # filter time to flush/close before the force-kill backstop.
        # Typical range: 2–10 s.
        SnapshotTerminationExtraSeconds = 5

        # Seconds without a new frame before Wait-ForSnapshotFrames abandons a stalled
        # VLC session (idle-frame stall detection). Only triggers after the warm-up window
        # elapses. Set to 0 to disable. Typical range: 30–180 s.
        SnapshotIdleTimeoutSeconds      = 60

        # Seconds at the start of a snapshot session during which idle detection is
        # suppressed, to allow slow-starting sources (e.g., cold network shares) to
        # produce their first frame before the idle timer starts counting.
        # Typical range: 15–120 s.
        SnapshotIdleWarmUpSeconds       = 30

        # Legacy Stop-Vlc wait in milliseconds, retained as a fallback for callers
        # without SnapshotTerminationExtraSeconds. New config should tune
        # SnapshotTerminationExtraSeconds instead.
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
        # VLC process logging
        # =========================

        Vlc                             = @{
            # VLC writes its own diagnostics to a sidecar file instead of this
            # module redirecting stdout/stderr pipes. Keep the default modest to
            # avoid large logs during batch runs. Valid range: 0-2 (0 also adds
            # --quiet; 1 is VLC's normal warning/info balance; 2 is verbose).
            LogVerbosity = 1

            Scene        = @{
                Format   = 'png'
                BaseArgs = @('--intf', 'dummy', '--video-filter=scene')
            }

            Gdi          = @{
                Args = @('--qt-minimal-view')
            }
        }

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
