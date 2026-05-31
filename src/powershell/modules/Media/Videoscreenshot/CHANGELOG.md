# Videoscreenshot Module – Changelog

All notable changes to the **PowerShell Videoscreenshot module** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [Unreleased]

## [3.2.1] - 2026-05-31
### Fixed
- **VLC stdout/stderr pipe-buffer deadlock**: long-running VLC sessions no longer redirect stdout/stderr pipes. VLC now writes diagnostics to a `.vlc_log_<RunGuid>.txt` sidecar under `SaveFolder`, with startup-failure errors reading from that logfile instead of unread stderr.

### Added
- **`Vlc.LogVerbosity`** (default `1`) in `Get-DefaultConfig` to tune VLC sidecar logging verbosity (`0`-`2`, where `0` also passes `--quiet`).

## [3.2.0] - 2026-05-29
### Added
- **Opt-in video pre-flight skip**: `Start-VideoBatch -VerifyVideos` (aliases `-PreflightProbe`, `-SkipUnplayable`) now runs `Test-VideoPlayable` before launching the main VLC capture session. Videos that fail the probe are logged as `Skipped`/`NotPlayable` in the processed log so resume runs do not retry them.
- **`VideoProbeTimeoutSeconds`** (default `5`) in `Get-DefaultConfig`, plus a `Start-VideoBatch -VideoProbeTimeoutSeconds` override for the pre-flight probe deadline.
- **Pester coverage** for `Test-VideoPlayable` success, non-zero exit, and hung-probe force-kill behavior, plus the batch-loop skip path.

### Fixed
- **Bounded playability probe**: `Test-VideoPlayable` now uses `WaitForExit(timeout)` and force-kills VLC on timeout, treating the video as unplayable instead of hanging indefinitely.
- **VLC executable fallback quoting**: replaced smart quotes around the default `vlc` executable name with straight quotes so the helper parses and executes reliably.

## [3.1.0] - 2026-05-28
### Added
- **Duration-aware per-video snapshot cap**: `Start-VideoBatch -UseVlcSnapshots` now probes each video's duration (via `Get-VideoDuration`) and computes `cap = duration + SnapshotDurationGraceSeconds` instead of the previous flat `SnapshotFallbackTimeoutSeconds = 300` constant. Short clips no longer incur a 300 s worst-case wait; long videos are no longer cut off early.
- **`Get-VideoDuration` helper** (`Private/Video.Fps.ps1`): reuses the ffprobe/Windows-Shell strategy pattern from `Get-VideoFps`; queries `format=duration` via ffprobe and falls back to the localized "Length"/"Duration" Shell column. Returns `0.0` on failure so callers can fall back safely.
- **`SnapshotDurationGraceSeconds`** (default `30`) in `Get-DefaultConfig` (`Private/Config.ps1`): configurable grace margin added to the probed duration to absorb VLC startup, buffering, and slow end-of-stream flush.

### Changed
- **`SnapshotFallbackTimeoutSeconds`** is now a last-resort backstop used only when duration detection fails (rather than the primary cap for every video). Behavior for undetectable durations is unchanged.

## [3.0.9] - 2026-05-27
### Fixed
- **VLC snapshot hang on undecodable videos**: `Wait-ForSnapshotFrames` previously waited the full `SnapshotFallbackTimeoutSeconds` (~300 s) when VLC stalled on a corrupt or unsupported video. Undecodable files are now abandoned within `SnapshotIdleTimeoutSeconds` (~20 s by default).

### Added
- **Idle-frame stall detection** in `Wait-ForSnapshotFrames` (`Private/Snapshot.Monitor.ps1`): tracks the timestamp of the last frame-count increase and breaks out early when no new frame appears for `IdleTimeoutSeconds` while the VLC process is still alive. A `Warn`-level message is emitted when the idle break fires.
- **`WarmUpSeconds` parameter** on `Wait-ForSnapshotFrames`: suppresses idle detection for an initial window so slow-starting sources (cold network shares, large files) are not killed before their first frame arrives.
- **`SnapshotIdleTimeoutSeconds`** (default `20`) and **`SnapshotIdleWarmUpSeconds`** (default `10`) in `Get-DefaultConfig` (`Private/Config.ps1`).
- **Pester tests** for `Wait-ForSnapshotFrames` (`tests/powershell/modules/Media/Videoscreenshot/Snapshot.Monitor.Tests.ps1`) covering: idle-break fires on stalled process, idle detection disabled when `IdleTimeoutSeconds=0`, warm-up suppresses premature break, idle fires after warm-up, normal completion via process exit, correct `FramesDelta` return.

## [3.0.5] - 2026-01-03
### Fixed
- **Processed videos tracking**: Fixed bug where some videos, despite being processed and having screenshots taken, were not being written to the `.processed_videos` file, causing unnecessary reprocessing on restart. Changes include:
  - Modified exception handling to capture errors instead of re-throwing, allowing processing status to be logged even when errors occur
  - Added GDI mode fallback to count files on disk when stats are null (matching VLC snapshot mode behavior)
  - Added final file count verification that overrides stats if actual files were saved
  - All videos are now **always** logged with appropriate status: `'Failed'` (with error details), `'Processed'` with `'NoFrames'` reason, or `'Processed'` on success
  - Ensures reliable resume functionality across restarts by guaranteeing every attempted video is tracked

## [3.0.4] - 2026-01-03
### Fixed
- **Python module import robustness**: Enhanced `Invoke-Cropper` to prevent "No module named crop_colours" errors:
  - Added pre-flight check to verify `media.crop_colours` module is importable before execution
  - Explicitly initialize ProcessStartInfo.Environment collection to ensure proper environment variable inheritance
  - Added file existence verification for crop_colours.py before attempting module invocation
  - Improved error messages with PYTHONPATH details and specific import diagnostics
  - Added debug logging to display exact Python command and PYTHONPATH value

## [3.0.3] - 2026-01-03
### Fixed
- **Python module import failure**: Fixed "No module named crop_colours" error when using `-RunCropper` without specifying `-PythonScriptPath`. The module now automatically configures PYTHONPATH to include `src/python` and uses the correct module path `media.crop_colours` instead of `crop_colours`.

### Added
- **Python package structure**: Added `__init__.py` to `src/python/media/` to make it a proper Python package, enabling module-based invocation with `python -m media.crop_colours`.

## [3.0.2] - 2025-11-16
### Fixed
- **Duplicate screenshots (vlcScreenshot mode)**: Fixed issue #436 where the final frame of a video was captured repeatedly in some runs. `Wait-ForSnapshotFrames` now monitors the VLC process and exits early (with a 2-second grace period) after VLC terminates, preventing duplicate frames caused by continued polling after video completion.
- **vlcScreenshot mode performance**: Eliminated 5-second delay between videos by checking if VLC has already exited before waiting. VLC launched with `--play-and-exit` typically exits on its own, making transitions nearly instantaneous. Fixes extreme slowness when processing batches of short videos (issue #435).

## [3.0.1] - 2025-10-14
### Fixed
- **Ctrl+C handling compatibility**: Fixed `CancelKeyPress` error in PowerShell hosts where the Console.CancelKeyPress event is not available (VS Code integrated terminal, PowerShell ISE, remote sessions). The function now gracefully falls back when Ctrl+C handling is unavailable, allowing the cropper to run normally in all environments.

## [3.0.0] - 2025-09-14
### Breaking
- Decommission `src\powershell\videoscreenshot.ps1` (renamed to `Show-VideoscreenshotDeprecation.ps1`). Invoking it now prints guidance to use `Start-VideoBatch` and exits with a non-zero code.

### Docs
- Update README to remove “legacy wrapper (still supported)” examples and clearly direct users to import the module and call `Start-VideoBatch`.
- Directory layout updated to mark the wrapper as decommissioned.
---

## [2.x] — 2025-09-07 → 2025-09-14 (consolidated)

### Breaking
- **PowerShell 7+ required** (2.0.0). Module targets PSEdition Core (pwsh) and errors on Windows PowerShell 5.1 with clear migration guidance.

### Added
- **Re-cropping controls** (2.5.0): `-ReprocessCropped` and `-KeepExistingCrops` to force re-crop and optionally retain existing outputs.
- **Crop-only mode** (2.3.0): Run the Python cropper over `-SaveFolder` without taking screenshots.
- **Python module fallback** (2.4.0): If `-PythonScriptPath` is omitted, run `python -m crop_colours` (PYTHONPATH / installed package support).
- **Batch/validation options** (2.1.x): `-VerifyVideos` (when `Test-VideoPlayable` exists) and `-IncludeExtensions` to override discovery; logging switches (`Write-Message -Quiet`, `-LogFile`).
- **Processed-log compatibility** (2.2.0): Accept both legacy single-column and TSV (`<Path>\t<Status>[\t<Reason>]`) formats.

### Changed
- **Default reprocessing behavior** (2.5.0): Skip previously cropped images by default (no longer passes `--ignore-processed` to Python).
- **Crop-only requirements** (2.4.0): `-SaveFolder` is now mandatory; capture flags are ignored with a single warning.
- **Live output** (2.4.1–2.4.2): Cropper stdout/stderr stream directly to the console (no buffering). Result still returns `ExitCode`/`ElapsedSeconds`.

### Fixed
- **Ctrl+C / cancellation** (2.4.2–2.4.3): Forward console cancel to Python cropper; promptly return control to PowerShell. Handler is scoped and removed after use.
- **Runspace crash** (2.2.1+): Removed background per-line handlers around VLC startup to avoid “There is no Runspace available…”; replaced with a safer watchdog.
- **Misc. robustness** (2.2.x): Eliminate stray pipeline output (`True`), correct return shapes, prevent nested arg arrays, make TRACE null-safe, and normalize resume sets.

### Orchestration & I/O
- **VLC/GDI** (2.1.x–2.2.x): Validated inputs; ordered and logged VLC args; safer monitor selection; retry-on-save; clearer stderr capture on failure.
- **Resume & processed** (2.2.x): Robust index builder, absolute-path normalization, tolerant of malformed lines.
- **I/O helpers** (2.1.x): `Test-FolderWritable -SkipCreate`, `Add-ContentWithRetry` with retry/flush.

### Documentation
- README expanded for crop-only usage, processed-log formats, re-cropping semantics, Python module invocation, troubleshooting (incl. GDI tips), and performance guidance.

### Notes
- Cropper output always streams to the console; **Ctrl+C** cancels cleanly in both `-RunCropper` and `-CropOnly`.
- If you need more granular details per change, see the corresponding git commit messages between 2.0.0 and 2.5.0.
---

## [1.x] – 2024–2025 (condensed)

> Consolidated highlights for all **1.*** releases.
> **For omissions or more granular details, please refer to the corresponding git commit messages (tags `v1.x.y`) in the repository history.**

### Added
- **Modularization (1.3.0):** Split the monolithic script into a PowerShell module with `Public/` and `Private/` components; introduced `Start-VideoBatch` as the public entrypoint and kept the legacy wrapper for back-compat.
- **Per-run context:** `New-VideoRunContext` centralizes version, config, stats, and run GUID; helpers accept `-Context`.
- **Config defaults:** `Get-DefaultConfig` provides central, immutable defaults (timings, extensions).
- **PID registry:** Helpers to track VLC child processes across the run.
- **Structured logging:** Timestamped `Write-Message` with stream routing.
- **Snapshot + GDI paths:** VLC scene-snapshot mode and Windows GDI+ desktop capture.
- **Processed/resume support (early iterations):** Helpers to track processed items and resume runs.
- **Cropper integration (1.2.x):** First Python cropper wiring with live output forwarding; interpreter resolution and preflight.

### Changed
- **Deterministic loader (1.3.6):** Dot-sources `Public/` and `Private/` in sorted order; warns when folders are missing.
- **Argument handling & orchestration:** Fixed edge cases in VLC arg builders; clarified argument array returns; consistent success-or-throw contract across helpers.
- **Post-capture reporting (1.3.3):** Consumes `snapStats`/`gdiStats` for frame deltas and achieved FPS; falls back to disk counts when needed.
- **Outcome consistency (1.3.2+):** Unified error-handling patterns; eliminated mixed bool/null conventions; ensured process stderr is surfaced on startup failures.

### Fixed
- **File I/O reliability (1.3.1–1.3.2):** `Add-ContentWithRetry` disposes handles via `finally`; clearer final-failure behavior; avoids stale locks.
- **VLC arg array bugs (1.3.1):** Removed stray commas and ensured arrays are returned correctly to prevent parsing/quoting errors.
- **Stability & guards:** Snapshot-mode guardrails; safer GDI capture initialization; early checks for required tools.

### Documentation
- **README (1.x series):** Introduced module structure, migration notes, and usage examples; documented PowerShell 7+ requirement and basic troubleshooting.
- **Inline help/comments:** Incremental comment-based help across new module files; expanded inline comments in orchestrators and helpers.

### Notes
- **Compatibility:** 1.* focused on modularization, reliability, and clarity without breaking the legacy wrapper.
- **Scope:** Some later capabilities (e.g., richer FPS detection, config-aware VLC orchestration, auto-install cropper deps) arrived in 2.* and are not part of 1.*.
