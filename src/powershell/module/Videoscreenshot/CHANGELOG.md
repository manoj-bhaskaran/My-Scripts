# Videoscreenshot Module – Changelog

All notable changes to the **PowerShell Videoscreenshot module** are documented here.  
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.2.2] – 2025-09-13
### Fixed
- **Stop-Vlc bind error**: `Start-Vlc` no longer leaks the boolean result of `Register-RunPid`, which previously caused `$p` to become `System.Object[]` and broke `Stop-Vlc -Process`. Only a single `Process` object is returned now.
- **Nested argument arrays**: Removed leading commas from `Get-VlcArgsCommon`, `Get-VlcArgsGdi`, and `Get-VlcArgsSnapshot` returns to avoid wrapping arrays as single elements.
### Notes
- No public API changes; pure bug fixes. If you need per-line VLC output mirroring, see 2.2.1 notes on runspace-safe debugging.
**Affected**: `Private/Vlc.Process.ps1` (and optional defensive tweak in `Start-VideoBatch.ps1`).

## [2.2.1] – 2025-09-13
### Fixed
- **Runspace crash during VLC startup**: Eliminated background event handlers that emitted PowerShell `Write-Debug` from non-default threads, which caused:
  > *There is no Runspace available to run scripts in this thread...*
  `Start-VlcProcess` now avoids `add_OutputDataReceived`/`add_ErrorDataReceived` and `Begin*ReadLine` calls. Startup still uses a polling watchdog; on non-zero early exit, captured `stderr` is surfaced in the thrown error.

### Changed
- **Debug output behavior**: `-Debug` no longer mirrors VLC’s per-line live output. Errors continue to include captured `stderr`; info/warn/error logs remain unchanged. Inline comments expanded around startup/stream handling.

### Documentation
- **README (Troubleshooting)**: Added note about the runspace crash, the fix, and the intentional change to `-Debug` behavior.

**Affected**: `Private/Vlc.Process.ps1`, `README.md`  
**SemVer**: Patch (2.2.1) – bug fix without public API changes.

## [2.2.0] – 2025-09-13

### Added
- **Processed-log compatibility:** The module now recognizes **both** legacy single-column processed logs (one absolute path per line) and the newer **TSV** format (`<Path>\t<Status>`). This enables seamless reuse of older logs without manual conversion.

### Changed
- **Processed.Log helpers**
  - `Get-ResumeIndex`:
    - Detects format per line and accepts either legacy or TSV entries.
    - Uses `Resolve-VideoPath` normalization so comparisons are stable across path case/format differences.
    - Ignores blank/commented lines and emits warnings (not failures) for malformed rows.
  - `Write-ProcessedLog`: **No change** to file format (still TSV). Works alongside legacy input logs.
- **Start-VideoBatch**: No behavioral changes required for skipping; it consumes the normalized set produced by `Get-ResumeIndex`.

### Documentation
- **README.md**
  - Updated “Resume / processed logging” section to document both supported formats.
  - Added a migration snippet to convert a legacy single-column file to TSV (optional).
  - Clarified how skipping works and the default location (`<SaveFolder>\.processed_videos.txt`).

### Notes
- **SemVer**: Minor version bump because 2.2.0 adds backward-compatible capability (accepting legacy processed logs).

## [2.1.x] – 2025-09-07 → 2025-09-13 (condensed)

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
- **README:** Added advanced examples for `-IncludeExtensions`/`-VerifyVideos`, clarified requirements (VLC 3.x+, Python 3.8+; GDI is Windows-only), explained cropper flags (e.g., `--preserve-alpha`), directory roles, troubleshooting (incl. GDI tips), and performance guidance. Documented processed/resume log support for both TSV and legacy single-column formats.
- **Private modules:** Expanded comment-based help and inline comments across Logging, IO, PID registry, Config, Cropper, VLC/GDI/Validate helpers.

### Notes
- Backwards compatible; focuses on diagnostics, safer defaults, and a better first-run experience.  
- For fine-grained details omitted here, please refer to the respective git commit messages between **2.1.1** and **2.1.7**.

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
