# CHANGELOG — Expand-ZipsAndClean

## 2.6.19 — 2026-05-31 *(patch — test refactor; no behaviour change)*

### Tests

- Added shared `Expand-ZipsAndClean.TestHelpers.ps1` Pester setup helpers for loading the
  `ZipWorkflow` and `ZipExtraction` test dependencies.
- Load the shared helper during Pester's run phase so its helper functions are available
  to `BeforeAll` blocks.
- Replaced repeated `Expand-ZipsAndClean.Tests.ps1` `BeforeAll` module-loading boilerplate
  with calls into the shared setup helpers while preserving the existing test coverage.

## 2.6.18 — 2026-05-30 *(patch — import guard test fix)*

### Fixed

- Used a platform-appropriate path comparer for `ZipWorkflow` dependency path checks
  (case-insensitive on Windows, case-sensitive elsewhere) before deciding whether an
  already-loaded same-name module is the repository-local dependency.

### Tests

- Corrected the path-aware import-guard regression tests to verify behavior through
  `ZipWorkflow` commands instead of expecting nested dependency imports to appear in
  the caller's global module table.

## 2.6.17 — 2026-05-30 *(patch — path-aware import guard)*

### Fixed

- Matched `ZipWorkflow`'s already-loaded dependency guard by resolved module path, not just
  module name. Same-name modules loaded from other locations no longer cause repository-local
  `FileSystem`, `ProgressReporter`, or `FileOperations` dependencies to be skipped.

### Tests

- Added regression coverage for same-name external `FileSystem` modules so `ZipWorkflow`
  still loads the repository-local dependency.

## 2.6.16 — 2026-05-30 *(patch — ZipWorkflow import guard)*

### Fixed

- Guarded `ZipWorkflow` dependency imports so already-loaded core modules are reused instead
  of being force-unloaded and reimported. This preserves `ProgressReporter` through the full
  `Expand-ZipsAndClean.ps1` startup load sequence and prevents the summary-step
  `ProgressReporter\Write-ExtractionSummary` module-load failure.

### Tests

- Added regression coverage for the full startup import sequence, the module-qualified
  summary call, and standalone `ZipWorkflow` loading when `ProgressReporter` is not preloaded.

## 2.6.15 — 2026-05-30 *(patch — startup robustness)*

### Fixed

- Added `-ErrorAction Stop` to all seven startup `Import-Module` calls so a missing or
  broken module fails immediately, instead of surfacing later as a
  `ProgressReporter\Write-ExtractionSummary` load error at the summary step. Also hardened
  the `ProgressReporter` and `ZipWorkflow` loaders to fail fast on their own dependency
  imports; kept the existing `ZipExtraction` command-source guard as a consistency check.

### Tests

- Added script-structure coverage requiring terminating imports on every top-level module dependency.

## 2.6.14 — 2026-05-29 *(patch — bug fix)*

### Fixed

- Suppressed the boolean success output from `Move-FileWithRetry` inside
  `ZipWorkflow\Move-ZipFilesToParent`, restoring the function's single summary-object output
  contract. Callers/tests previously saw an extra pipeline object and read `$result.Count`
  as the array length (`2`) instead of the moved-zip count (`1`).

## 2.6.13 — 2026-05-29 *(patch — refactor; no behaviour change)*

### Changed

- Moved `Write-ExtractionSummary` to `Core/Progress` (`ProgressReporter.psm1`) and
  `Move-ZipFilesToParent` to `FileManagement/ZipWorkflow`; summary output, host detection,
  width/`PassThru`/compression-ratio formatting unchanged. `Expand-ZipsAndClean.ps1` is now
  a thin orchestrator (parameter binding, imports, logger/throttle setup, main workflow,
  summary call) with no script-local function definitions.

### Tests

- Relocated `Write-ExtractionSummary` coverage to
  `tests/powershell/modules/Core/Progress/ProgressReporter.Tests.ps1`; added an assertion
  that the script contains no `FunctionDefinitionAst` nodes.

## 2.6.12 — 2026-05-29 *(patch — refactor; no behaviour change)*

### Changed

- Moved `Remove-SourceDirectory` and its five private helpers (`Get-SourceDirectoryItems`,
  `Test-HasBlockingZips`, `Get-NonZipDeletionBlockReason`, `Remove-NonZipItems`,
  `Remove-DirectoryRobust`) to `Core/FileSystem` (module 1.3.0, which also gained
  `-WhatIf`/`-Confirm` support). The script imports and calls `Remove-SourceDirectory` from
  the module; delete semantics and the `Remove-Item` / `[IO.Directory]::Delete` fallback are
  identical.

## 2.6.11 — 2026-05-29 *(patch — bug fix)*

### Fixed

- Wrapped the `Get-SourceDirectoryItems` call in `@(...)` so `$remaining` is always an array
  when the source directory is empty. Previously PowerShell could unroll the pipeline output
  to `$null`, making the mandatory `[object[]]` parameter of `Test-HasBlockingZips` throw;
  the outer `catch` then recorded a spurious failure and left the empty directory behind on
  an otherwise successful `-DeleteSource` run.

### Tests

- Added coverage that an already-empty source directory is deleted without error.

## 2.6.10 — 2026-05-29 *(patch — refactor; no behaviour change)*

### Changed

- Reduced `Remove-SourceDirectory` cognitive complexity to ≤15 (SonarCloud S3776) by
  extracting five private helpers (`Get-SourceDirectoryItems`, `Test-HasBlockingZips`,
  `Get-NonZipDeletionBlockReason`, `Remove-NonZipItems`, `Remove-DirectoryRobust`); the
  function is now a thin orchestrator.

## 2.6.9 — 2026-05-27 *(patch — test-load fix)*

### Fixed

- Added a `Write-LogDebug` no-op fallback in `ZipWorkflow.psm1` for helper-load test
  contexts lacking logging scope, fixing `Resolve-MoveTarget` Skip-collision test failures.

## 2.6.8 — 2026-05-27 *(patch — test-load fix)*

### Fixed

- Helper-loading Pester contexts now import `FileManagement/ZipWorkflow` before dot-sourcing
  the script `#region Helpers`, restoring extracted-helper wrapper-delegation compatibility.

## 2.6.7 — 2026-05-27 *(patch — refactor)*

### Changed

- Extracted `Test-ScriptPreconditions`, `Initialize-Destination`, and `Resolve-MoveTarget`
  into a new `FileManagement/ZipWorkflow` module (thin compatibility wrappers kept in the
  script). Moved `Add-Type -AssemblyName System.IO.Compression.FileSystem` into
  `ZipExtraction.psm1`.

## 2.6.6 — 2026-05-25 *(patch — tests only)*

### Tests

- Relocated the `Invoke-ZipExtractions` parallel-extraction tests into
  `ZipExtraction.Tests.ps1` and left a delegation smoke test in the script tests (net `It`
  20 → 19). Module CHANGELOG tracked by #1065.

## 2.6.5 — 2026-05-24 *(patch — de-duplication refactor; no behaviour change)*

### Changed

- Relocated `Show-ProgressPhase` and `New-ExtractionSummary` to their canonical modules
  (`Core/Progress`, `ZipExtraction.psm1`), removing the script-local duplicates and the dead
  `Write-Progress` fallback. Reconciled the `ZipExtraction.psm1` `Show-ProgressPhase` stub to
  include `CurrentOperation`.

### Tests

- Moved `Show-ProgressPhase` coverage to the `ProgressReporter` tests.

## 2.6.4 — 2026-05-24 *(patch — bug fix)*

### Fixed

- Corrected comment-help attribution for `EXPAND_ZIPS_SOURCE_DIR` / `EXPAND_ZIPS_DEST_DIR`,
  and made whitespace-only env values fall back to profile-relative defaults
  (`$HOME/Downloads/picconvert`, `$HOME/Desktop/New folder`).

## 2.6.3 — 2026-05-24 *(patch — tests only)*

### Tests

- Removed four duplicate/low-value tests (28 → 24).

## 2.6.2 — 2026-05-24 *(patch — refactor; no behaviour change)*

### Changed

- Deleted the ~127-line script-local ZipExtraction wrapper/command-resolution block; `Main`
  now calls the module export directly (module-qualified `ZipExtraction\Invoke-ZipExtractions`),
  guarded by an import-success check that `Get-Command Invoke-ZipExtractions` resolves to
  `Source = ZipExtraction`.

## 2.6.1 — 2026-05-23 *(patch — refactor; no behaviour change)*

### Changed

- Extracted shared private `Invoke-SingleZipExtraction` (used by both serial and parallel
  runners) and `Resolve-MoveTarget` (collision logic split out of `Move-ZipFilesToParent`),
  eliminating the duplicated stats/extract/tally sequence.

## 2.6.0 — 2026-05-23 *(minor — module-boundary refactor; no intended behaviour change)*

### Changed

- Extracted ZIP-extraction orchestration (`Invoke-ZipExtractions` and the serial/parallel
  runners) into a new `FileManagement/ZipExtraction` module; the script now imports and
  delegates to it. A series of follow-on commits reduced SonarCloud new-code duplication and
  hardened helper-load/test command resolution and module discovery (since superseded by the
  2.6.2 wrapper removal).

## 2.5.4 — 2026-05-22 *(patch — tests only)*

### Tests

- Removed four duplicate/low-value `It` blocks (37 → 33).

## 2.5.3 — 2026-05-21 *(patch — robustness refactor; no behaviour change)*

### Changed

- `Move-ZipFilesToParent` and per-item non-zip cleanup now use `Move-FileWithRetry` /
  `Remove-FileWithRetry` (`Core/FileOperations`) for transient-lock resilience (AV/network
  handles); those helpers use `-LiteralPath` throughout. `Show-ProgressPhase` falls back to
  native `Write-Progress` when `Show-Progress` is absent (partial-load scenarios).

## 2.5.2 — 2026-05-21 *(patch — progress abstraction; no behaviour change)*

### Changed

- Routed progress through `Core/Progress` `Show-Progress` via a `Show-ProgressPhase` adapter;
  added a `-Suppress` switch to `Show-Progress`.

## 2.5.1 — 2026-05-19 *(patch — bug fix)*

### Fixed

- `SourceDirectory`/`DestinationDirectory` defaults use the PS7 ternary instead of `??`, so
  empty-string env values (e.g. when `.env.example` is sourced) correctly fall back to the
  profile-relative path instead of aborting on `[ValidateNotNullOrEmpty()]`.

## 2.5.0 — 2026-05-19 *(minor — default semantics change; back-compat preserved)*

### Changed

- `SourceDirectory`/`DestinationDirectory` defaults no longer hard-code a personal path; they
  resolve from `$env:EXPAND_ZIPS_SOURCE_DIR` / `$env:EXPAND_ZIPS_DEST_DIR`, falling back to
  `$HOME/Downloads/picconvert` and `$HOME/Desktop/New folder`. Documented in
  `docs/ENVIRONMENT.md` and `.env.example`.

## 2.3.3 — 2026-05-17 *(patch — tests only)*

### Tests

- Added `Flat` Overwrite/Rename collision tests for `Expand-ZipFlat`,
  `Test-ScriptPreconditions` guard tests, and a script parse-check smoke test.

## 2.3.2 — 2026-05-17 *(patch — refactor; no behaviour change)*

### Changed

- Added the `Write-ExtractionSummary` helper (compression ratio, console-width detection,
  table/list branching, always-printed error block) and replaced the 45-line inline summary;
  switched to `Write-Output` for pipeline capture (SonarCloud S2228).

## 2.3.0 — 2026-05-17 *(minor — import contract change)*

### Changed

- Extracted archive primitives (`Get-ZipFileStats`, `Expand-ZipToSubfolder`, `Expand-ZipFlat`,
  `Expand-ZipSmart`, plus private error/path helpers) into the new `Core/Zip` module (#976);
  removed `using namespace System.IO.Compression` from the script.

## 2.2.3 — 2026-05-17 *(patch — refactor + display fix)*

### Fixed

- Added the `Write-PhaseProgress` helper (centralised percentage math and `-Quiet`
  suppression). Fixed the move-progress off-by-one so the byte caption includes the file
  currently being moved (was showing only already-completed bytes).

## 2.2.2 — 2026-05-12 *(patch — perf/stats refactor)*

### Changed

- Single `Add-Type` for `System.IO.Compression` at startup (was repeated per call);
  `Expand-ZipToSubfolder` now takes a precomputed `ExpectedFileCount` instead of re-walking
  the destination after extraction (which was redundant and wrong when the subfolder
  pre-existed with files).

## Not released

- `2.4.x` and `2.3.1` — version numbers reserved/skipped during refactor sequencing; no
  released artifacts.
