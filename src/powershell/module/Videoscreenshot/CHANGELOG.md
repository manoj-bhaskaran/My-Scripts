# Videoscreenshot Module – Changelog

All notable changes to the **PowerShell Videoscreenshot module** are documented here.  
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.1.3] – 2025-09-09
### Changed
- Cropper is now invoked over the **SourceFolder** with flags:
  `--skip-bad-images --allow-empty --ignore-processed --recurse --preserve-alpha`.
  If `Start-VideoBatch` is run with `-Debug`, `--debug` is propagated to the Python script.
### Fixed
- Avoid repeated per-video cropper runs; run once post-capture to reduce overhead.

## [2.1.2] – 2025-09-09
### Fixed
- Cropper timing now uses wall-clock measurement via `Stopwatch` instead of CPU time, improving accuracy for I/O-bound operations (image writes, process startup). This affects the `ElapsedSeconds` value returned by `Invoke-Cropper`.

## [2.1.1] – 2025-09-09

### PowerShell
- Videoscreenshot
  - Implement Python cropper invocation (`Invoke-Cropper`) using `System.Diagnostics.Process` with `ArgumentList`, redirected stdout/stderr, and fail-fast errors.
  - Python resolution order: custom `-PythonExe`, then `py` (Windows launcher), then `python`. Adds `-3` automatically when using `py`.
  - Clearer failure messages when the cropper exits non-zero, including captured STDERR/STDOUT for easier diagnosis.

### Docs
- Videoscreenshot README: add “Cropper integration” usage and environment notes (Python resolution, working directory assumptions).

## [2.1.0] – 2025-09-07

### Added
- **Resume & processed logging:**
  - `Read-ProcessedSet` (Private) to load processed entries and optional resume list.
  - `Get-ProcessedLogPath` (Private) to resolve default/override log location.
  - `Append-Processed` (Private) to record successful completions (atomic append).
  - `Resolve-VideoPath` (Private) to normalize paths for stable comparisons.

- **Advanced timing controls:**
  - `Start-VideoBatch` accepts `-MaxPerVideoSeconds` and `-StartupGraceSeconds`.
  - Effective limit is forwarded to VLC via `-StopAtSeconds`; snapshot waits include startup grace.

### Changed
- `Start-VideoBatch` now skips videos present in processed/resume sets, maintains attempted/processed counts, and emits concise run summaries.

### Notes
- No breaking changes; defaults match previous behavior when new parameters are omitted.

**SemVer:** Minor.

## [2.0.0] – 2025-09-07

### PowerShell
- **Videoscreenshot**
  - **Breaking:** Require PowerShell 7+ (pwsh). The module manifest and loader now target PSEdition Core only and version 7.0+. Import and runtime guards error out on older hosts with clear guidance.
  - Wrapper `videoscreenshot.ps1` detects legacy Windows PowerShell (5.1/`Desktop`) and exits with instructions to run under `pwsh` and suggested install commands.
- **Other scripts**
  - No changes in this release.

### Docs
- Update `src/powershell/module/Videoscreenshot/README.md` to document the PowerShell 7+ requirement and migration notes.

### Notes
- Rationale: standardize on a modern runtime (pwsh) to simplify code paths and ensure consistent behavior across platforms.

---

## [1.3.6] – 2025-09-07

### Changed
- Robust module loader: handle absent `Public/` or `Private/` directories gracefully and dot-source scripts in deterministic (sorted) order to avoid load-order flakiness.

### Notes
- Backwards compatible; no public API changes.

---

## [1.3.5] – 2025-09-07

### PowerShell
- **Videoscreenshot**
  - Wrapper parameter parity: detect legacy/unsupported parameters passed to `videoscreenshot.ps1`, translate known legacy names (e.g., `-CropOnly` → `-RunCropper`), and emit a single consolidated deprecation/ignore warning. Improves clarity without breaking existing usage.
  - No runtime behavior change to the module entrypoint; this is a UX/compat improvement only.
- **Other scripts**
  - No changes in this release.

### Docs / CI
- Updated changelogs for 1.3.5.

---

## [1.3.4] – 2025-09-07

### PowerShell
- **Videoscreenshot**
  - State isolation: replaced module-scoped `$script:*` variables with a per-run **context object** `New-VideoRunContext`) that is passed through private functions.
  - Updated private APIs: `Start-Vlc`, `Stop-Vlc`, `Start-VlcProcess`, and PID registry helpers now accept `-Context` and read settings from `Context.Config`.
  - Config defaults are now exposed via `Get-DefaultConfig`; no mutable module-wide state remains.
  - SemVer: patch bump (internal refactor; no public API changes).

## [1.3.3] – 2025-09-07

### PowerShell
- **Videoscreenshot**
  - Post-capture reporting: consume `snapStats`/`gdiStats` to compute frames delta and achieved FPS; fall back to disk counts if stats are unavailable.
  - Cleanup: eliminate “assigned but never used” warnings by using stats objects in reporting.
  - SemVer: patch bump (no breaking changes).

## [1.3.2] – 2025-09-07

### Fixed
- Enforce “helpers throw; orchestrator handles” policy across I/O and process helpers.
- Replace mixed return conventions (bool/null) with clear success-or-throw behavior.
- Ensure file handles are always disposed via try/finally in `Add-ContentWithRetry`.
- When VLC fails to start, `Start-VlcProcess` now throws with stderr included for diagnosis.

### Notes
- Patch release: behavior is more robust and consistent without breaking the public API.

---

## [1.3.1] – 2025-09-06

### Fixed
- **I/O:** `Add-ContentWithRetry` now reliably disposes the file handle via `finally` and returns `$false`
  on final failure instead of silently continuing. This prevents lingering locks and improves caller feedback.
- **VLC args:** Removed stray leading comma in function returns and ensured argument arrays are returned
  correctly from `Get-VlcArgs*` helpers; avoids “Missing expression after unary operator ','” and
  quoting issues in snapshot paths.

### Changed
- **Manifest:** `ModuleVersion` bumped to **1.3.1** to capture the above fixes.

---

## [1.3.0] – 2025-09-06

### Added
- **Modularization (PR-1):** Initial extraction of the monolithic script into a module located at
  `src/powershell/module/Videoscreenshot/`.
- Public entrypoint: `Start-VideoBatch` (thin orchestrator for now).
- Legacy wrapper `src/powershell/videoscreenshot.ps1` retained for back-compat (emits deprecation notice).

### Notes
- Several components (GDI capture, snapshot monitor, Python cropper integration, metadata helpers) remain
  to be migrated in subsequent PRs.

---

## [1.2.41] – 2025-09-06 (condensed)

### Changed
- Centralized configuration, clearer outcome logic, incremental validation improvements.

---

## [1.2.40] – 2025-09-06 (condensed)

### Fixed
- Error-handling consistency, parameter validation, and locale coverage for FPS detection.

---

## [1.2.1 – 1.2.39] – 2024–2025 (condensed highlights)

- Python cropper integration with live log forwarding; interpreter resolution & preflight.
- Safer processed-log I/O; duration/FPS detection via Shell/`ffprobe`.
- Snapshot mode guardrails; GDI+ capture improvements; PID registry + Ctrl+C/exit cleanup.
- Structured logging and end-of-run summaries.

[Unreleased]: #
[1.3.1]: #
[1.3.0]: #
[1.2.41]: #
[1.2.40]: #