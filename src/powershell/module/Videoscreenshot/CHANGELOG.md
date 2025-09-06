# Changelog

All notable changes to this repository are documented here.  
This repo contains multiple tools and scripts; entries are grouped by **area**.

The project follows [Semantic Versioning](https://semver.org) and the format is inspired by
[Keep a Changelog](https://keepachangelog.com).

> For detailed, module-specific history, see the changelog in that component’s folder
> (e.g., `src/powershell/module/Videoscreenshot/CHANGELOG.md`).

## [Unreleased]

### PowerShell
- **Videoscreenshot (module)** — see module changelog for pending items.
- **Other scripts** — (placeholder) Add notes here when changes land.

### Python
- (placeholder)

### Batch
- (placeholder)

### SQL
- (placeholder)

### Docs / CI
- (placeholder)

---

## [1.3.0] – 2025-09-06

### PowerShell
- **Videoscreenshot**
  - **Modularization:** Extracted the monolithic `videoscreenshot.ps1` into a module at
    `src/powershell/module/Videoscreenshot/` with `Start-VideoBatch` as the public entrypoint.
  - The legacy `src/powershell/videoscreenshot.ps1` remains as a thin wrapper that forwards to the module
    and prints a deprecation notice.
  - **Details:** See `src/powershell/module/Videoscreenshot/CHANGELOG.md`.
- **Other scripts**
  - No notable changes in this release.

### Docs / CI
- Added `src/powershell/README.md` for module usage and wrapper notes.
- Introduced module-scoped `CHANGELOG.md`.

---

## [1.2.41] – 2025-09-06

### PowerShell
- **Videoscreenshot**
  - Incremental refactors (“quick wins”): centralized configuration, clearer outcome handling, improved validation.
  - Documentation updates in preparation for modularization.
- **Other scripts**
  - No changes recorded.

---

## [1.2.40] – 2025-09-06

### PowerShell
- **Videoscreenshot**
  - Fixes around error handling consistency, parameter validation, and locale coverage for FPS detection.
- **Other scripts**
  - No changes recorded.

---

## [1.2.0 – 1.2.39] – 2024–2025 (condensed highlights)

### PowerShell
- **Videoscreenshot**
  - Python cropper integration with live log forwarding; interpreter resolution & module preflight.
  - `-PreserveAlpha` support; safer processed-log I/O; duration/FPS detection via Shell/`ffprobe`.
  - Snapshot mode guardrails; GDI+ capture improvements; PID registry + Ctrl+C/exit cleanup.
  - Structured logging and end-of-run summaries.
- **Other scripts**
  - (No consolidated record for this period; future changes will be tracked here.)

### Python / Batch / SQL
- (No consolidated record for this period; future changes will be tracked here.)

---

## Repository Areas

- **PowerShell**
  - `src/powershell/module/Videoscreenshot/` — Videoscreenshot module (see module changelog)
  - `src/powershell/*.ps1` — other independent scripts
- **Python** — `src/python/`
- **Batch** — `src/batch/`
- **SQL** — `src/sql/`
- **Docs** — `docs/`, plus per-area READMEs

[Unreleased]: #
[1.3.0]: #
[1.2.41]: #
[1.2.40]: #
