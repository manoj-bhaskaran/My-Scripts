# CHANGELOG — Core/Zip

All notable changes to this module are documented here.

## [1.0.0] — 2026-05-17

### Added

- Initial release. Archive primitives extracted from `Expand-ZipsAndClean.ps1` (issue #976).

- **Public functions** (`Public/`):
  - `Get-ZipFileStats` — collects file count, uncompressed total, and compressed bytes from a zip
    without extracting it, using a single `ZipFile.OpenRead` pass.
  - `Expand-ZipToSubfolder` — extracts one archive into a safe, unique subfolder (PerArchiveSubfolder
    mode) via `Expand-Archive`; returns `ExpectedFileCount` directly to avoid a post-extraction
    `Get-ChildItem` walk.
  - `Expand-ZipFlat` — streams entries directly into the destination root (Flat mode) via
    `ZipArchive`; applies per-file collision policy (Skip / Overwrite / Rename) and enforces
    Zip Slip protection on every entry.
  - `Expand-ZipSmart` — mode dispatcher: derives a safe subfolder name and fully-qualified
    destination root, then routes to `Expand-ZipToSubfolder` or `Expand-ZipFlat`.

- **Private helpers** (`Private/`):
  - `Test-IsEncryptedZipError` — walks the full exception chain looking for encryption / password
    keywords; accepts an `ErrorRecord`, an `Exception`, or a plain string.
  - `Resolve-ExtractionError` — normalizes extraction errors, surfacing a clear user-facing message
    when encryption is detected.
  - `Resolve-ZipEntryDestinationPath` — validates archive entry paths and blocks path traversal
    (Zip Slip): rejects rooted paths, `..` segments, and entries whose resolved path escapes the
    destination root.

- Module loader (`Zip.psm1`) and manifest (`Zip.psd1`) following the `Core/FileSystem` conventions:
  dot-sources `Private/` before `Public/`, exports only public function names.

- `using namespace System.IO.Compression` in the loader and in each `.ps1` file that references
  `ZipFile` or `ZipFileExtensions`, reducing fully-qualified type clutter.

- No-op `Write-LogDebug` fallback in the module loader: defined only when the logging framework
  has not already been imported, so the module works standalone in tests without requiring the
  logging framework as a hard dependency.
