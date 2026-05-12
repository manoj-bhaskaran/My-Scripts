# CHANGELOG — Expand-ZipsAndClean

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
