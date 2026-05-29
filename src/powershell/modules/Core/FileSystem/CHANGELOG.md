# FileSystem Module – Changelog

All notable changes to this module are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

---

## [1.3.0] – 2026-05-29

### Changed

- **`PowerShellVersion` raised from `5.1` to `7.0`** in the module manifest.
  The new `Remove-SourceDirectory` helpers use the ternary operator (`? :`) which
  is PS7-only syntax; the manifest now accurately reflects the minimum runtime
  required. All pre-existing public functions remain compatible with PS7.
- **`Remove-SourceDirectory`** now correctly honours `-WhatIf` / `-Confirm`.
  A `$PSCmdlet.ShouldProcess($SourceDir, 'Delete source directory')` guard wraps
  both the non-zip cleanup and the directory deletion, so a dry-run invocation
  never touches the filesystem.

### Added

- **`Remove-SourceDirectory`** (public) — thin orchestrator exported from the module.
  Resolves the provider path, delegates to the four private helpers below, and appends
  human-readable entries to an `ErrorList` rather than throwing, so callers continue
  uninterrupted on partial failures.
- **`Get-SourceDirectoryItems`** (private) — scans a directory recursively with
  `-ErrorAction SilentlyContinue` and surfaces enumeration errors as `Write-Warning`
  messages so the caller is never silently left without diagnostics.
- **`Test-HasBlockingZips`** (private) — checks whether leftover `.zip` files in the
  source directory would be destroyed by deletion (because they were not moved due to a
  Skip collision policy) and records the block-reason error message.
- **`Get-NonZipDeletionBlockReason`** (private) — returns a human-readable block reason
  when non-zip items prevent deletion (distinguishing "non-zip files remain" from "only
  empty subdirectories remain"), or `$null` when it is safe to proceed.
- **`Remove-NonZipItems`** (private) — removes non-zip items depth-first (deepest path
  first) to avoid "directory not empty" errors on nested trees. Uses `@(...)` guards on
  the split/filter expression to preserve correct `.Count` behaviour under
  `Set-StrictMode -Version Latest`.
- **`Remove-DirectoryRobust`** (private) — deletes a directory using
  `[System.IO.Directory]::Delete` (the synchronous .NET primitive) with
  `Remove-Item -Recurse -Force` as a fallback. Works around PowerShell issue #8211
  where `Remove-Item` can leave the root directory behind on some Linux CI filesystems
  (GitHub Actions runners). Records a single failure entry to `ErrorList` if the
  directory still exists after both attempts.

### Changed

- Module description updated to mention robust source-directory deletion.

### Notes

- No README exists for this module; no documentation changes required.
- All behaviour, error messages, and delete semantics are identical to the
  script-local implementation previously in `Expand-ZipsAndClean.ps1`.

---

## [1.2.1] – 2026-05-25

### Fixed

- `Get-FullPath`: guard Unix absolute paths (starting with `/`) from the `'/' → '\'` slash substitution. Previously, a path such as `/tmp/dest` was converted to `\tmp\dest` before being passed to `[System.IO.Path]::GetFullPath()`, which on Linux treats `\` as a regular character and resolves the path relative to CWD, producing a mangled result. The function now calls `GetFullPath` directly (without slash substitution) when the input starts with `/`.

---

## [1.2.0] – 2026-05-17

### Added
- **`Test-DirectoryWritable`** – Creates a uniquely named probe file inside the
  target path and removes it inside `try/finally`, guaranteeing no probe leaks. A file
  probe is used so the check validates the "Create files / write data" ACE, which is
  the permission actually required for file-write operations such as `Move-Item`.
  Accepts optional `-ThrowOnFailure` to raise a terminating error when the directory
  is not writable. Works cross-platform via PowerShell cmdlets.
- **`Add-TrailingSeparator`** – Appends `[IO.Path]::DirectorySeparatorChar` to a path
  string if no trailing separator is present. Idempotent (no double separator added).
  Accepts pipeline input. Works cross-platform.
- **`Test-PathContainment`** – Returns `$true` when a candidate path is located inside
  a container directory. Uses `Add-TrailingSeparator` internally to prevent false
  positives from shared path prefixes (e.g. `C:\Foo` does not contain `C:\FooBar`).
  Case-insensitive ordinal comparison.

### Changed
- Module description updated to mention directory writability testing and
  cross-platform path-separator helpers.
- `CrossPlatform` tag added to module manifest.

---

## [1.1.0]

### Added
- `Get-FullPath` – Normalises paths to absolute form; converts forward slashes to
  backslashes on Windows.
- `Format-Bytes` – Formats a byte count as a human-readable string (B / KB / MB / GB / TB).
- `Resolve-UniquePath` – Generates a unique file path by appending a timestamp suffix
  on collision.
- `Resolve-UniqueDirectoryPath` – Directory counterpart to `Resolve-UniquePath`.
- `Get-SafeName` – Sanitises filenames by replacing invalid characters.
- `Test-LongPathsEnabled` – Queries the Windows registry to check whether long-path
  support is enabled.

---

## [1.0.0]

### Added
- `New-DirectoryIfMissing` – Creates a directory if it does not exist.
- `Test-FileAccessible` – Tests whether a file can be opened for read/write access.
- `Test-PathValid` – Validates path syntax; optional wildcard allowance.
- `Test-FileLocked` – Detects whether a file is locked by another process.
