# CHANGELOG — Expand-ZipsAndClean

## 2.3.0 — 2026-05-17

### Changed

- Extracted archive primitives into the new `Core/Zip` module (issue #976):
  - `Get-ZipFileStats`, `Expand-ZipToSubfolder`, `Expand-ZipFlat`, `Expand-ZipSmart` moved to
    `src/powershell/modules/Core/Zip/Public/`.
  - `Test-IsEncryptedZipError`, `Resolve-ExtractionError`, `Resolve-ZipEntryDestinationPath`
    moved to `src/powershell/modules/Core/Zip/Private/`.
- Added `Import-Module Core/Zip/Zip.psm1` after the `FileSystem` import.
- Removed `using namespace System.IO.Compression` from the script (no longer needed in the
  script body after the zip helpers moved to the module).

### Tests

- Updated `Describe 'Expand-ZipsAndClean helper extraction refactor'` → renamed to
  `'Core/Zip module — public extraction functions'`.
- `BeforeAll` now imports `Core/Zip/Zip.psm1` directly instead of extracting the
  `#region Helpers` block from the script source.
- Module-internal function mocks (`Expand-ZipToSubfolder`, `Expand-ZipFlat`, `Expand-Archive`)
  updated to use `-ModuleName Zip`.
- Tests for private module functions (`Resolve-ZipEntryDestinationPath`,
  `Test-IsEncryptedZipError`, `Resolve-ExtractionError`) now run inside `InModuleScope Zip`.
- The three remaining `Describe` blocks (`Remove-SourceDirectory`, `Move-ZipFilesToParent`,
  `Write-PhaseProgress`) each import `Core/Zip/Zip.psm1` in their `BeforeAll` so
  `Invoke-ZipExtractions` (which calls the module functions) resolves correctly if exercised.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.3.0` (minor — import contract changes).

## 2.2.3 — 2026-05-17

### Added

- `Write-PhaseProgress` private helper that accepts `Activity`, `Status`, `Current`, `Total`,
  `QuietMode`, optional `CurrentOperation`, and a `Completed` switch. It centralizes percentage
  math (`[int]($Current / [math]::Max(1, $Total) * 100)`) and `-Quiet` suppression so neither
  caller has to hand-roll those two concerns.

### Changed

- `Invoke-ZipExtractions`: replaced two inline `Write-Progress` / `if (-not $QuietMode)` blocks
  with `Write-PhaseProgress` calls.
- `Move-ZipFilesToParent`: replaced inline `Write-Progress` / `if (-not $QuietMode)` blocks with
  `Write-PhaseProgress` calls. The `CurrentOperation` caption now reads
  `"Moving: X of Y bytes"` (was `"Moved X of Y"`), and the byte total shown for the current file
  is `$bytes + $zf.Length` rather than `$bytes`. This fixes the off-by-one display where the
  caption previously showed only the cumulative bytes from already-completed files, omitting the
  file currently being moved.

### Tests

- Added `Describe 'Write-PhaseProgress'` with eight It blocks covering:
  - QuietMode suppression (both normal and Completed paths).
  - Correct `PercentComplete` computation (50 % at midpoint, 100 % at end).
  - `CurrentOperation` included when supplied, omitted when not.
  - `Completed` switch invokes `Write-Progress -Completed`.
  - Zero `Total` guard (no division-by-zero error).

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.2.3`.

## 2.2.2 — 2026-05-12

### Changed

- Consolidated `Add-Type -AssemblyName System.IO.Compression.FileSystem` to a single call at script start. The call was previously repeated inside `Get-ZipFileStats` and `Expand-ZipFlat` on every invocation; it is now issued once during script initialisation and removed from both helper bodies.
- Dropped the caller-side `$stats.CompressedBytes = [int64]$zip.Length` overwrite in `Invoke-ZipExtractions`. `Get-ZipFileStats` already populates `CompressedBytes` from `$zipItem.Length` (the same value); the redundant reassignment was a refactoring residue and is now removed.
- Refactored `Expand-ZipToSubfolder` to accept a new mandatory `[int]$ExpectedFileCount` parameter (pre-computed by `Get-ZipFileStats`) and return it directly. The previous implementation re-walked the destination folder with `Get-ChildItem -Recurse -File | Measure-Object` after extraction, which was both redundant and incorrect when the resolved subfolder pre-existed with files. `Expand-ZipSmart` threads the value through from `Invoke-ZipExtractions`.

### Tests

- Added `PerArchiveSubfolder: file count returned matches archive entry count` — creates a 3-file zip, calls `Get-ZipFileStats` and `Expand-ZipToSubfolder`, and asserts the returned count equals the archive manifest count.
- Added `Flat: file count returned matches archive entry count` — creates a 2-file zip, calls `Get-ZipFileStats` and `Expand-ZipFlat`, and asserts the returned count equals the archive manifest count.
- Updated `dispatches PerArchiveSubfolder mode to Expand-ZipToSubfolder` to pass and assert the new `ExpectedFileCount` parameter.
- All three `Describe` `BeforeAll` blocks now explicitly call `Add-Type -AssemblyName System.IO.Compression.FileSystem` so the assembly is available when helpers are dot-sourced (previously the assembly was loaded lazily inside `Get-ZipFileStats` which is outside the extracted helpers block).

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.2.2`.
