# File Management Scripts

Scripts for file operations, distribution, copying, and archiving.

## Scripts

- **FileDistributor.ps1** - Distributes files across directories based on rules
- **Copy-AndroidFiles.ps1** - Copies files from Android devices to local storage
  - Version history: `src/powershell/file-management/CHANGELOG.md` (see **Copy-AndroidFiles** section).
- **Expand-ZipsAndClean.ps1** - Extracts ZIP archives and performs cleanup
- **SyncRepoToTarget.ps1** - Synchronizes repository contents to target locations
- **Get-FileHandle.ps1** - Inspects and displays file handles for troubleshooting locked files
- **Restore-FileExtension.ps1** - Restores or fixes file extensions based on content analysis
- **Remove-FilenameString.ps1** - Removes specified strings from filenames in bulk

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Tools
- PowerShell 5.1 or later
- Windows API access for file handle operations

## Common Use Cases

1. **File Distribution**: Use FileDistributor.ps1 to organize files into structured directories
2. **Android Integration**: Copy-AndroidFiles.ps1 for backing up mobile device content
3. **Archive Management**: Expand-ZipsAndClean.ps1 for batch processing of compressed files
4. **Repository Sync**: SyncRepoToTarget.ps1 for deploying code to multiple locations

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.
## Recent Updates

- **Documentation (2026-04-10)**
  - Normalized `src/powershell/file-management/CHANGELOG.md` structure across **Copy-AndroidFiles** and **FileDistributor** sections.
  - Added a short changelog table of contents for faster navigation.
  - Standardized FileDistributor release/category heading hierarchy and category naming for consistency.
  - Standardized horizontal-rule usage to a single section separator between the two script sections.
- **Copy-AndroidFiles.ps1 v2.3.1** (2026-04-10)
  - Script header `.NOTES` now keeps only the current version and points to `CHANGELOG.md` for full version history.
  - Historical entries previously kept in the script header are now consolidated in `CHANGELOG.md` (including `1.2.x` through `2.x` milestones).
- **Copy-AndroidFiles.ps1 v2.3.0** (2026-04-10)
  - Implemented PowerShell parameter sets `Pull` and `Tar`. Mode-specific parameters are now
    restricted to their respective sets: `-Resume` and `-ProgressIntervalSeconds` are `Pull`-only;
    `-StreamTar` and `-MaxRetries` are `Tar`-only. PowerShell rejects invalid combinations at
    binding time. Default parameter set is `Tar`.
  - Retired the `-Mode` parameter. The transfer mode is now selected implicitly by the parameter
    set. Pass pull-only parameters to use pull mode; pass tar-only parameters (or none) for tar mode.
  - Made `-PhonePath` and `-Dest` mandatory; personal hard-coded default values removed.
- **FileDistributor.ps1 v4.8.0** (module v1.2.0)
  - Consolidated module/script loading boundaries: private helpers are now loaded once in module scope, redundant Core module imports were removed, and orchestration helpers were promoted to module `Public/` exports.
  - Replaced remaining private-module `LogMessage` calls with framework-native `Write-Log*` functions to avoid module-scope `CommandNotFoundException`.
  - Removed dead script-local duplication (`Write-DistributionSummary`) and aligned helper placement (`Test-EndOfScriptCondition`) with module-scope orchestration.
- **FileDistributor.ps1 v4.7.x rollup** (v4.7.0–v4.7.13; module v1.1.0→v1.1.13)
  - Hardened moduleized distribution/post-processing flows by fixing script-scope coupling (`LogMessage` migration, explicit state/retry parameters, warning/error counter propagation, and restart/checkpoint wiring).
  - Landed stability fixes across redistribution and rebalance logic (`-Files` parameter typing, random-selection race clamp, divide-by-zero logging guards, unused `-TotalFiles` removal, and unreachable normalized-subfolder guard removal).
- **FileDistributor.ps1 v4.6.x module-extraction sprint (v4.6.0–v4.6.17)**
  - Broke monolithic orchestration into reusable phase helpers and extracted shared move/subfolder/checkpoint helpers to reduce duplicated algorithm logic.
  - Introduced and expanded the internal `FileManagement/FileDistributor` module by moving path/serialization/folder operation helpers out of script scope.
  - Delegated startup log cleanup to `PurgeLogs` (`Clear-LogFile`) and tightened checkpoint/state parameter flow by passing runtime values explicitly.
  - Shipped safety fixes during the extraction series: target-root containment/fallback handling, single-item checkpoint payload support, EndOfScript queue failure signaling, and restored post-run count-integrity warnings.
  - See `src/powershell/file-management/CHANGELOG.md` for the full 4.6.x sprint rollup.
