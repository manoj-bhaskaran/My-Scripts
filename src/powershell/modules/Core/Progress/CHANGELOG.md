# CHANGELOG — Core/Progress (ProgressReporter)

## 1.1.0 — Unreleased

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
