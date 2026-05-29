# CHANGELOG — automation

## Update-ScheduledTaskScriptPaths.ps1

### 3.0.1 - 2026-05-29

#### Fixed
- Consistent pipeline stage indentation: each cmdlet (`Get-ScheduledTask`, `Where-Object`,
  `ForEach-Object`) starts on its own line with the pipe operator at the end of the preceding
  line, making all three stages visually uniform.

### 3.0.0 - 2025-11-28

#### Changed
- Removed hardcoded paths, added configurable parameters (Issue #513)
- Added environment variable support for all paths
- Default output directory now uses repository structure

### 2.0.0 - 2025-11-16

#### Changed
- Migrated to PowerShellLoggingFramework.psm1 for standardized logging
- Replaced `Write-Host` calls with `Write-LogInfo`
- Replaced `Write-Warning` calls with `Write-LogWarning`

### 1.0.0 - Previous

- Uses `Export-ScheduledTask` for exporting
- Parses XML using XPath with NamespaceManager for full Exec node visibility
- Handles regex path matching with subfolder tolerance and optional quotes
- Ensures UTF-8 export using StreamWriter and proper Dispose (without BOM)
- Explicitly updates the XML declaration's `encoding` attribute to `utf-8`
- Validates presence of nodes before accessing them
