# FileSystem Module – Changelog

All notable changes to this module are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

---

## [1.2.0] – 2026-05-17

### Added
- **`Test-DirectoryWritable`** – Creates a uniquely named probe subdirectory inside
  the target path and removes it inside `try/finally`, guaranteeing no probe leaks.
  Accepts optional `-ThrowOnFailure` to raise a terminating error when the directory
  is not writable. Works cross-platform.
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
