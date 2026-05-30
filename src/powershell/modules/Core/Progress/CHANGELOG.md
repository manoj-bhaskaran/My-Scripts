# CHANGELOG — Core/Progress (ProgressReporter)

## 1.2.4 — Unreleased

### Fixed

- `ProgressReporter.psm1`: no longer performs an unconditional `Import-Module -Force` of
  `Core/FileSystem` from inside its own module session state. Because `-Force` first
  removes the already-loaded FileSystem module and then re-imports it privately into the
  caller module, the previous code stripped FileSystem's functions (`Get-FullPath`,
  `Get-SafeName`, etc.) from the global/caller scope and from every other module's view.
  This caused `Expand-ZipsAndClean.ps1` to fail every extraction with "The term
  'Get-FullPath' is not recognized" and to abort with the fatal "The module 'FileSystem'
  could not be loaded." The loader now skips the import when a FileSystem module from the
  same path is already loaded (mirroring the guard in `ZipWorkflow.psm1`), keeping
  FileSystem shared across the session.
- `ProgressReporter.psm1`: build the FileSystem dependency path from discrete `Join-Path`
  segments instead of an embedded-separator literal. `[System.IO.Path]::GetFullPath()` does
  not normalize `\` on Linux/macOS, so a `'..\FileSystem\FileSystem.psm1'` literal could
  resolve to a mangled path and make the already-loaded guard miss a matching module,
  falling back to the destructive `-Force` re-import the guard is meant to prevent.
- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.2.3` to `1.2.4` (PATCH —
  module-load robustness fix).

## 1.2.3 — Unreleased

### Fixed

- `ProgressReporter.psm1`: imports `Core/FileSystem` with `-ErrorAction Stop` so missing or broken dependency failures are terminating and surface at import time instead of allowing a partially loaded summary module.
- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.2.2` to `1.2.3` (PATCH — module-load robustness fix).

## 1.2.2 — Unreleased

### Changed

- Reduced duplicated new-code lines in `Write-ExtractionSummary.ps1` by deriving the
  internal summary state from `$PSBoundParameters` instead of repeating the full summary
  parameter list at the helper call site. Public behavior is unchanged.
- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.2.1` to `1.2.2` (PATCH —
  internal refactor/no behavioral change).

## 1.2.1 — Unreleased

### Changed

- Refactored `Write-ExtractionSummary` into focused helper functions for summary-object
  construction, console-width selection, formatted view output, and error-note output.
  Public behavior and the `Write-ExtractionSummary` export are unchanged; this only lowers
  the public function's Cognitive Complexity below the quality-gate limit.
- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.2.0` to `1.2.1` (PATCH —
  internal refactor/no behavioral change).

## 1.2.0 — Unreleased

### Added

- `Write-ExtractionSummary` (`Public/Write-ExtractionSummary.ps1`): public summary renderer
  relocated from `Expand-ZipsAndClean.ps1`. It preserves interactive host header and
  table/list rendering, non-interactive error-note emission, `ConsoleWidth`/`HostName`/
  `PassThru` test-injection parameters, the 120-column table threshold, and the existing
  compression-ratio formatting.

### Changed

- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.1.0` to `1.2.0` (MINOR —
  additive new export); `FunctionsToExport` updated to include `Write-ExtractionSummary`.
- `ProgressReporter.psm1`: imports `Core/FileSystem` so summary byte formatting uses the
  shared `Format-Bytes` implementation.
- `ProgressReporter.psd1`: `PowerShellVersion` raised from `5.1` to `7.0` because
  the module now imports the PS 7-only `Core/FileSystem` module for `Format-Bytes`.

## 1.1.0 — 2026-05-29

### Added

- `Show-ProgressPhase` (`Public/Show-ProgressPhase.ps1`): percentage-computing,
  quiet-mode-aware progress wrapper relocated from `Expand-ZipsAndClean.ps1`. Accepts
  `Activity`, `Status`, `Current`, `Total`, `QuietMode`, optional `CurrentOperation`,
  and a `Completed` switch. Computes `PercentComplete` from `Current`/`Total` (clamped
  to 100; guarded against division by zero) and delegates to `Show-Progress`. Exported
  from `ProgressReporter.psm1` as a public function.

### Changed

- `ProgressReporter.psd1`: `ModuleVersion` bumped from `1.0.1` to `1.1.0` (MINOR —
  additive new export); `FunctionsToExport` updated to include `Show-ProgressPhase`.

## 1.0.1 — 2026-05-19

### Changed

- Standardized module folder structure and loader (Private/Public layout).

## 1.0.0 — 2025-11-20

### Added

- Initial release: `Show-Progress`, `Write-ProgressLog`, `New-ProgressTracker`,
  `Update-ProgressTracker`, `Complete-ProgressTracker`, `Write-ProgressStatus`.
