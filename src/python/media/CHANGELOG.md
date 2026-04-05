# crop_colours – Changelog

All notable changes to **crop_colours.py** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [Unreleased]

## [4.0.2] - 2026-04-05
### Changed
- Slimmed module docstring: migrated TROUBLESHOOTING and FAQ sections to `README.md`
  and version history to `CHANGELOG.md`. Docstring now references both external files.

## [4.0.1]
### Improved
- `_validate_parameters()` no longer creates a throwaway `ArgumentParser`; validation errors
  are reported via `logger.error` + `raise SystemExit(2)`.
- `import glob` and `import platform` promoted from function bodies to the top-level import block.
- `_save_failure_guidance_shown` global removed; save-failure guidance is now emitted once
  from `_process_batch()` after the worker loop completes, conditioned on `failures > 0`.

## [4.0.0]
### Breaking
- Remove `--ignore-processed`. Default behavior now explicitly skips previously cropped images
  using `.processed_images` tracking and/or existing output detection.

### Added
- `--reprocess-cropped` to force a full re-crop.
- `--keep-existing-crops` to retain existing crops when reprocessing (new outputs are
  de-duplicated alongside).

### Improved
- Documentation and help text updated to reflect reprocessing semantics and defaults.

### Refactored
- Split monolithic `main()` into focused helpers (`_resolve_work_items`,
  `_maybe_handle_reprocessing`, `_emit_summary`) to reduce cognitive complexity and improve
  readability/testability without changing behavior.

## [3.x]
### Breaking / Behavior
- Default is now **non-destructive**: outputs are written to `<input>/Cropped` with suffix
  `_cropped` (no overwrite).
- Exit semantics refined: when all images are already processed, return **0** (success)
  instead of **2**.
- Stricter parameter validation across thresholds, padding, min-area, etc.

### Added
- `--in-place` to overwrite originals atomically (temp→replace).
- Naming controls: `--suffix` (default `_cropped`) and `--no-suffix`.
- Progress controls: `--progress-interval` (default 100) with ETA/rate; end-of-run summary stats.
- Reprocessing protection via `.processed_images` tracking to avoid redundant work.
- `--ignore-processed` to override tracking when needed.
- Transparency handling: `--preserve-alpha` plus `--alpha-threshold` for tuning semi-transparent edges.
- Consistent logger naming and compatibility with both stdlib logging and `python-logging-framework`.

### Fixed
- Robust file tracking: thread-safe/cross-process coordination to prevent `.processed_images`
  corruption.
- Windows compatibility: make `fcntl` import conditional; fall back to Windows locking.
- Resume robustness: validate that `--resume-file` is a real, readable image; use
  case-insensitive path matching on Windows; clearer errors when not found.
- Exit codes: ensure **1** is returned when any image processing failures occur.
- Eliminate duplicate `start_time` initialization in `_process_batch`.
- Alpha crash fix: guard dimensions when using `--preserve-alpha` on grayscale images.
- Return type/flow bugs addressed to avoid unintended `sys.exit()` errors.
- Diagnostics: include target output path in save-failure messages.

### Improved
- Cognitive complexity reduced by decomposing large routines into focused helpers (image
  collection, progress gating, stats, resume resolution).
- Parameter bounds checks with clearer, actionable error messages.
- Progress visibility: richer periodic logs with rate and ETA; more actionable end-of-run
  summary (success/failure/skip counts, success rate).
- Documentation: clarify file locking as "cross-process coordination"; document absolute-path
  behavior in reprocessing protection and Windows path matching.
- Type annotations modernized (built-in `tuple`, `list`); style improvements (use `np.nonzero`).
- Debug logging made consistent across stdlib and third-party logging backends; debug builds
  emit environment/version diagnostics (Python/OpenCV/NumPy).

### Kept
- Core 2.x capabilities: `--recurse`, `--max-workers`, retries, strict validation,
  non-clobbering writes with auto de-duplication when needed.

## [2.x]
### Breaking
- Empty folder exits with code **2** unless `--allow-empty`.
- `--resume-file` must exist and be a valid, readable image; otherwise exit **2**.
- Corrupt images fail the run by default; use `--skip-bad-images` to continue.

### Added
- `--recurse` for recursive image discovery (`os.walk`).
- Preserve relative subfolder structure under `--output`.
- `--max-workers`, `--retry-writes`, `--skip-bad-images`, `--allow-empty`.
- Expanded docstring with Version/Author, Troubleshooting, FAQs, and dependencies.

### Fixed
- Explicit `None`-check on `cv2.imread` with clearer error messages.

### Docs
- Clarify that `python-logging-framework` is optional (falls back to stdlib logging).

### Style
- Use `np.nonzero` over `np.where(condition)`.
