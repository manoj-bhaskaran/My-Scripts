# Videoscreenshot Module – Changelog

All notable changes to the **PowerShell Videoscreenshot module** are documented here.  
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

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