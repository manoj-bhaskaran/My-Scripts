# Videoscreenshot Module – Changelog

All notable changes to the **PowerShell Videoscreenshot module** are documented here.  
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.3.0] - 2025-09-13
### Added
- `Start-VideoBatch`: new `-CropOnly` mode to run the Python cropper over `-SaveFolder` **without** performing any screenshot capture.
- `Start-VideoBatch` warns and ignores capture-related parameters when `-CropOnly` is used.
- README: documented crop-only usage.

### Changed
- Legacy wrapper `videoscreenshot.ps1`: `-CropOnly` now maps to module `-CropOnly` (previously mapped to `-RunCropper`).
- Wrapper compatibility: when `-CropOnly` is used and `-SaveFolder` is not provided, `-SourceFolder` is treated as the cropper input folder (mapped to `-SaveFolder`) to mirror legacy behavior.

### Fixed
- Avoid confusion in wrapper hint: points users to `-CropOnly` for module parity instead of `-RunCropper`.

## [2.2.0–2.2.8] — 2025-09-13 (condensed roll-up)

### Added
- **Processed-log compatibility (2.2.0):** The module now accepts both legacy single-column logs (one absolute path per line) and TSV (`<Path>\t<Status>`), enabling seamless reuse of older files.
- **Robust resume index (2.2.0):** `Get-ResumeIndex` detects line format, normalizes paths via `Resolve-VideoPath`, ignores blanks/comments, and warns (doesn’t fail) on malformed rows.

### Fixed
- **Runspace crash on VLC startup (2.2.1+):** Removed background stdout/stderr event handlers in `Start-VlcProcess` to avoid “There is no Runspace available…”; replaced with a polling watchdog and synchronous `stderr` read on non-zero exit.
- **Stray `True` in pipeline (2.2.2–2.2.8):** Systematically sunk/redirected success-stream returns in `Start-VideoBatch` and `Vlc.Process`. Captured and nulled outputs from `Write-ProcessedLog`, `Stop-Vlc`, `Unregister-RunPid`, and the final `Write-Message`. Initially redirected `Register-RunPid *> $null`; later refactored `Register-RunPid` to be non-emitting while still appending auditable START lines via `Add-ContentWithRetry`.
- **Null-safe TRACE logs (2.2.7–2.2.8):** Replaced null-propagation with explicit `$null` checks to prevent `InvalidOperation` (“method on a null-valued expression”).
- **Argument arrays (2.2.2):** Removed leading commas in `Get-VlcArgs*` returns to prevent nested arrays.
- **Return shape (2.2.2):** Ensured `Start-Vlc` returns a single `[Diagnostics.Process]` object (no boolean concatenation that could break `Stop-Vlc -Process`).

### Changed
- **Debug behavior (2.2.1+):** `-Debug` no longer mirrors VLC per-line live output; errors still surface captured `stderr`. Inline comments expanded around startup/stream handling.
- **Entrypoint cleanliness (2.2.6–2.2.8):** Added/sustained TRACE sentinels and explicitly returned no pipeline output during normal runs.

### Diagnostics
- Precise TRACE around `p.Start()` and function exits in `Start-VlcProcess`/`Start-Vlc`.
- Granular TRACE around `Wait-ForSnapshotFrames` / `Invoke-GdiCapture` and teardown (`Stop-Vlc`, `Unregister-RunPid`) to pinpoint any future emitters.

### Documentation
- **README:** Documented both processed-log formats and how skipping works; added troubleshooting for the runspace crash and clarified the intentional `-Debug` change.

### Notes
- **SemVer:** 2.2.0 is **Minor** (backward-compatible capability). 2.2.1–2.2.8 are **Patch** releases (bug fixes, diagnostics).  
- **Affected:** `Private/Vlc.Process.ps1`, `Public/Start-VideoBatch.ps1`, processed-log helpers, `README.md`.  
- No breaking parameter changes; defaults remain compatible with previous workflows.

## [2.1.0–2.1.x] — 2025-09-07 → 2025-09-13 (condensed)
This series delivered cohesive improvements across the batch entrypoint, VLC orchestration, FPS detection, cropper integration, logging, and docs—without breaking existing workflows.

### Added
- **FPS detection:** `Get-VideoFps` helper (ffprobe → Windows Shell fallback) with robust parsing (`30000/1001`, `29.97`, `29,97`, optional `fps`), warnings on fallback, and 0.0 return so callers can default to 30.
- **Batch options:** `Start-VideoBatch` supports `-VerifyVideos` (if `Test-VideoPlayable` exists) and `-IncludeExtensions` to override discovery set.
- **Logging switches:** `Write-Message -Quiet` (suppress Info) and `-LogFile` (append to file).
- **Cropper preflight:** `Invoke-Cropper` auto-installs missing Python packages from `Config.Python.RequiredPackages` (disable via `-NoAutoInstall`).

### Changed
- **VLC orchestration (`Private/Vlc.Process.ps1`):**
  - `Start-Vlc` validates inputs (video path/file; save folder/dir) and assembles args in a documented order (media → mode → base → extras).
  - Config-aware defaults: built-in < `Context.Config.Vlc` (e.g., `BaseArgs`, `Scene.Format`) < explicit params.
  - `Get-VlcArgsSnapshot` enforces image format via `ValidateSet('png','jpg','jpeg')` and logs computed `--scene-ratio`.
  - `Start-VlcProcess` debugs fully quoted arguments; notes thread-safe buffering.
- **GDI capture:** Safer monitor selection (primary → first screen; clear error if none) and retry-on-save with linear backoff. Richer inline comments.
- **Video validation:** On non-zero VLC exit, capture and log `stderr`; documented 1-second probe choice.
- **I/O helpers:** `Test-FolderWritable -SkipCreate` option; `Add-ContentWithRetry` ensures disposal, retry, and clear errors.

### Fixed
- **Pid registry:** Replaced invalid `-LiteralPath` usage with `-Path`; header and START/STOP entries append correctly.
- **Resume/processed robustness:** Always construct a `HashSet[string]` for the processed set; convert enumerables; warn on unreadable logs; avoid null dereference at `.Contains()`.

### Documentation
- **README:** Added advanced examples for `-IncludeExtensions` / `-VerifyVideos`, clarified requirements (VLC 3.x+, Python 3.8+; GDI is Windows-only), explained cropper flags (e.g., `--preserve-alpha`), directory roles, troubleshooting (incl. GDI tips), and performance guidance. Documented processed/resume log support for both TSV and legacy single-column formats.
- **Private modules:** Expanded comment-based help and inline comments across Logging, IO, PID registry, Config, Cropper, VLC/GDI/Validate helpers.

### Notes
- Backwards compatible; focuses on diagnostics, safer defaults, and a better first-run experience.
- For fine-grained details omitted here, see commit messages between **2.1.1** and **2.1.7**.

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
