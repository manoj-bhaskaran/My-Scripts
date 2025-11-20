# RandomName PowerShell Module

## Overview
Generates random, Windows-compatible filenames for safe file operations using a conservative allow-list approach.

## Version
Current version: **2.1.0**

## Installation

**Module import:**
```powershell
Import-Module RandomName
```

**Manual import with path:**
```powershell
Import-Module .\src\powershell\modules\Utilities\RandomName\RandomName.psd1
```

**Using deployment script:**
```powershell
.\scripts\Deploy-Modules.ps1
```

## Functions

### Get-RandomFileName

Generates a random filename that is safe for Windows filesystems.

**Syntax:**
```powershell
Get-RandomFileName [[-MinimumLength] <int>] [[-MaximumLength] <int>] [[-MaxAttempts] <int>]
```

**Parameters:**

- **MinimumLength** (int, optional)
  - Minimum length of generated filename
  - Default: 4
  - Range: 1-255
  - Alias: `min`

- **MaximumLength** (int, optional)
  - Maximum length of generated filename
  - Default: 32
  - Range: 1-255
  - Alias: `max`

- **MaxAttempts** (int, optional)
  - Maximum attempts to avoid reserved device names
  - Default: 100
  - Range: 1-100000

**Examples:**

```powershell
# Generate random filename with default settings (4-32 characters)
Get-RandomFileName
# Output: a7f3k2m9

# Generate with specific length range
Get-RandomFileName -MinimumLength 8 -MaximumLength 16
# Output: x5y1a7f3k2m9

# Using aliases for brevity
Get-RandomFileName -min 5 -max 15
# Output: b4n8x2q9w

# Longer filename for more uniqueness
Get-RandomFileName -MinimumLength 20 -MaximumLength 30
# Output: a7f3k2m9x5y1b4n8q6w2r
```

**Notes:**

- Generated filenames use only safe characters:
  - First character: alphanumeric (`a-z`, `A-Z`, `0-9`)
  - Subsequent characters: alphanumeric plus `_`, `-`, `~`
- Avoids Windows invalid filename characters: `< > : " / \ | ? *`
- Validates against Windows reserved device names:
  - `CON`, `PRN`, `AUX`, `NUL`
  - `COM1` through `COM9`
  - `LPT1` through `LPT9`
- Uses `Get-Random` (not cryptographically secure)
- Cross-platform compatible (Windows, Linux, macOS)

## Use Cases

### File Distribution with Conflict Resolution
```powershell
Import-Module RandomName

# Generate unique filename when conflict occurs
$randomName = Get-RandomFileName
$targetPath = Join-Path $targetDir "$randomName.txt"
Copy-Item $sourcePath $targetPath
```

Used by `FileDistributor.ps1` for handling file naming conflicts during distribution operations.

## Dependencies

- PowerShell 5.1 or later
- No external dependencies

## Technical Details

**Module GUID:** `6b2a2d3e-0e1f-4a4b-9f5b-9c7a2f9d2c4a`

**Tags:** random, filename, windows-safe, utilities

**Author:** Manoj Bhaskaran

## Used By

- `src/powershell/file-management/FileDistributor.ps1` - File distribution with conflict resolution
- Various scripts requiring safe temporary filenames

## License

MIT License

---

For module history, see [CHANGELOG.md](./CHANGELOG.md).
