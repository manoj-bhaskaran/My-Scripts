# Core/Zip Module

Reusable PowerShell module providing ZIP archive primitives: stats collection, two extraction
modes (per-archive subfolder and flat streaming), collision handling, and Zip Slip protection.

## Requirements

- PowerShell 7.0+
- `System.IO.Compression.FileSystem` assembly (loaded automatically by the module loader)
- `Core/FileSystem` module — provides `Get-FullPath`, `Get-SafeName`, `New-DirectoryIfMissing`,
  `Resolve-UniquePath`, and `Resolve-UniqueDirectoryPath` used by the public functions
- `Write-LogDebug` from `Core/Logging/PowerShellLoggingFramework` — a no-op stub is defined
  automatically when the logging framework is not loaded

## Module Layout

```
Core/Zip/
├── Zip.psm1                              # Module loader (dot-sources Private then Public)
├── Zip.psd1                              # Module manifest (v1.0.0)
├── Public/
│   ├── Get-ZipFileStats.ps1              # Entry count + byte totals without extraction
│   ├── Expand-ZipToSubfolder.ps1         # PerArchiveSubfolder extraction mode
│   ├── Expand-ZipFlat.ps1                # Flat streaming extraction mode
│   └── Expand-ZipSmart.ps1               # Mode dispatcher
└── Private/
    ├── Test-IsEncryptedZipError.ps1      # Exception-chain encryption detector
    ├── Resolve-ExtractionError.ps1       # Normalizes extraction errors
    └── Resolve-ZipEntryDestinationPath.ps1  # Zip Slip path validator
```

## Public API

### `Get-ZipFileStats`

Returns file count, total uncompressed bytes, and compressed bytes for a ZIP without extracting it.

```powershell
$stats = Get-ZipFileStats -ZipPath 'C:\archives\data.zip'
$stats.FileCount          # number of file entries in the archive
$stats.UncompressedBytes  # sum of uncompressed entry sizes
$stats.CompressedBytes    # size of the zip file on disk
```

### `Expand-ZipToSubfolder`

Extracts one ZIP into a safe, unique subfolder under the destination root (PerArchiveSubfolder mode).
Uses `Expand-Archive` internally. Returns `ExpectedFileCount` directly — no post-extraction
directory walk is needed.

```powershell
$count = Expand-ZipToSubfolder -ZipPath 'C:\archives\data.zip' `
    -DestinationRoot 'C:\output' `
    -SafeSubfolderName 'data' `
    -ExpectedFileCount 5
```

### `Expand-ZipFlat`

Streams every entry from a ZIP directly into the destination root (Flat mode) using `ZipArchive`.
Applies per-file collision policy before writing and enforces Zip Slip protection on every entry.

```powershell
$written = Expand-ZipFlat -ZipPath 'C:\archives\data.zip' `
    -DestinationRoot 'C:\output' `
    -DestinationRootFull 'C:\output' `
    -CollisionPolicy Rename
```

**CollisionPolicy values**: `Skip` | `Overwrite` | `Rename` (default)

### `Expand-ZipSmart`

Mode dispatcher: derives a safe subfolder name and the fully-qualified destination root, then
routes to `Expand-ZipToSubfolder` or `Expand-ZipFlat` based on `-ExtractMode`.

```powershell
$count = Expand-ZipSmart -ZipPath 'C:\archives\data.zip' `
    -DestinationRoot 'C:\output' `
    -ExtractMode PerArchiveSubfolder `
    -CollisionPolicy Rename `
    -SafeNameMaxLen 200 `
    -ExpectedFileCount 5
```

**ExtractMode values**: `PerArchiveSubfolder` (default) | `Flat`

## Private Helpers

| Function | Purpose |
|---|---|
| `Test-IsEncryptedZipError` | Walks the full exception chain detecting encrypted-archive keywords |
| `Resolve-ExtractionError` | Re-throws with a friendly message when encryption is detected |
| `Resolve-ZipEntryDestinationPath` | Validates entry paths and blocks path traversal (Zip Slip) |

## Security: Zip Slip Protection

Flat mode validates every archive entry through `Resolve-ZipEntryDestinationPath` before writing:

1. **Rooted-path rejection** — entries starting with `/`, `\`, a drive letter, or UNC prefix are blocked.
2. **Traversal rejection** — any segment equal to `..` causes the entry to be skipped.
3. **Destination containment** — the fully-qualified candidate path must start with the destination
   root (using OS-appropriate case comparison: case-insensitive on Windows, case-sensitive elsewhere).

Suspicious entries are skipped and logged at `Write-LogDebug` level; extraction continues for
remaining entries.

## Typical Usage

```powershell
Import-Module "$PSScriptRoot\..\modules\Core\FileSystem\FileSystem.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Core\Zip\Zip.psm1" -Force

# Collect stats without extracting
$stats = Get-ZipFileStats -ZipPath 'C:\archives\data.zip'

# Extract each archive into its own subfolder
$count = Expand-ZipSmart -ZipPath 'C:\archives\data.zip' `
    -DestinationRoot 'C:\output' `
    -ExtractMode PerArchiveSubfolder `
    -ExpectedFileCount $stats.FileCount
```
