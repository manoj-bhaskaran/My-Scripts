# CHANGELOG — Remove-FilenameString

## 2.0.1 — 2026-05-29

### Fixed

- Placed `$null` on the left-hand side of the null-check for `$files` (`$null -ne $files` instead of `$files -ne $null`), eliminating the PSScriptAnalyzer `PSPossibleIncorrectComparisonWithNull` warning. PowerShell coerces the right-hand operand to match the left-hand type, so a collection on the left can suppress the comparison; placing `$null` on the left avoids this. No behavior change.

### Versioning

- Bumped `Remove-FilenameString.ps1` script version to `2.0.1`.

## 2.0.0 — (prior)

### Changed

- Refactored to use PowerShellLoggingFramework for standardized logging.

## 1.0.0 — (prior)

### Added

- Initial release with `Add-Content` logging.
