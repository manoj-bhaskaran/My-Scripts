# CHANGELOG — Core/Progress (ProgressReporter)

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
