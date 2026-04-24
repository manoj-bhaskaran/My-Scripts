# File Management Scripts

Scripts for file operations, distribution, copying, and archiving.

## Scripts

- **FileDistributor.ps1** - Distributes files across directories based on rules
- **Copy-AndroidFiles.ps1** - Copies files from Android devices to local storage
  - Version history: [Copy-AndroidFiles.CHANGELOG.md](Copy-AndroidFiles.CHANGELOG.md)
- **Expand-ZipsAndClean.ps1** - Extracts ZIP archives and performs cleanup
- **SyncRepoToTarget.ps1** - Synchronizes repository contents to target locations
- **Get-FileHandle.ps1** - Inspects and displays file handles for troubleshooting locked files
- **Restore-FileExtension.ps1** - Restores or fixes file extensions based on content analysis
- **Remove-FilenameString.ps1** - Removes specified strings from filenames in bulk

## Dependencies

### PowerShell Modules

- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging
- **AdbHelpers** (`src/powershell/modules/Android/AdbHelpers/`) - Shared ADB/device helpers used by `Copy-AndroidFiles.ps1`

### External Tools

- PowerShell 7+ (required by `Expand-ZipsAndClean.ps1`; other scripts may work on 5.1)
- Windows API access for file handle operations

## Common Use Cases

1. **File Distribution**: Use FileDistributor.ps1 to organize files into structured directories
2. **Android Integration**: Copy-AndroidFiles.ps1 for backing up mobile device content
3. **Archive Management**: Expand-ZipsAndClean.ps1 for batch processing of compressed files
4. **Repository Sync**: SyncRepoToTarget.ps1 for deploying code to multiple locations

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.

## FileDistributor Versioning

- `FileDistributor.ps1` uses `$script:Version` as the script runtime/versioning source of truth.
- `src/powershell/modules/FileManagement/FileDistributor/FileDistributor.psd1` `ModuleVersion` versions
  the support module API and implementation.
- These versions are intentionally independent and may advance separately under SemVer.

## Recent Updates

- **Expand-ZipsAndClean.ps1 v2.1.4** (2026-04-24)
  - Updated `Remove-SourceDirectory` cleanup error handling so per-item `-CleanNonZips` removals are best-effort (debug-log only) and do not mark the run as failed.
  - `ErrorList` now reports only final source-directory deletion failures, matching end-state behavior.
  - Version bump: `2.1.4` (patch — correctness fix, no feature change).
- **Expand-ZipsAndClean.ps1 v2.1.3** (2026-04-24)
  - Fixed `Remove-SourceDirectory` false-positive cleanup failures by recording removal errors only when the target path still exists after a caught `Remove-Item` exception.
  - Applied the same existence guard to the final source-directory deletion retry path.
  - Version bump: `2.1.3` (patch — correctness fix, no feature change).
- **Expand-ZipsAndClean.ps1 v2.1.2** (2026-04-24)
  - Fixed nested `-CleanNonZips` cleanup reliability in `Remove-SourceDirectory`: directories are now removed with `-Recurse` to prevent intermittent `directory not empty` cleanup errors.
  - Added deterministic same-depth tie-breaking (`FullName` descending) in deepest-first cleanup ordering.
  - Version bump: `2.1.2` (patch — bug fix, no feature change).
- **Expand-ZipsAndClean.ps1 v2.1.0** (2026-04-13)
  - Added `#requires -Version 7.0` to enforce the PowerShell 7+ runtime at parse time (script already used the ternary operator which is PS 7-only).
  - Added `using namespace System.Collections.Generic` and `using namespace System.IO.Compression` declarations; shortened `List[string]`, `ZipFile`, and `ZipFileExtensions` type references accordingly.
  - Replaced `New-Object System.Collections.Generic.List[string]` with `[List[string]]::new()`.
  - Updated `.NOTES` `Requires` line and `Setup/Module check` section to remove the PowerShell 5.1 compatibility note.
  - Version bump: `2.1.0` (minor — supported-runtime contract change).
- **Expand-ZipsAndClean.ps1 test-suite follow-up** (2026-04-13)
  - Updated the dispatcher routing Pester test to mock `Expand-ZipFlat` explicitly in the `PerArchiveSubfolder` path assertion, fixing CI `Should -Invoke ... -Times 0` mock-resolution failures.
- **Expand-ZipsAndClean.ps1 v2.0.4** (2026-04-13)
  - Refactored extraction internals by splitting `Expand-ZipSmart` into mode-specific helpers: `Expand-ZipToSubfolder` and `Expand-ZipFlat`.
  - Kept `Expand-ZipSmart` as the compatibility dispatcher with unchanged parameters and mode behavior.
  - Added Pester coverage for dispatcher routing, `Flat` skip-collision behavior, and Zip Slip traversal rejection.
- **Expand-ZipsAndClean.ps1 v2.0.3** (2026-04-13)
  - Review follow-up: added comment-based help blocks for extracted phase functions to keep inline script documentation consistent.
- **Expand-ZipsAndClean.ps1 v2.0.2** (2026-04-13)
  - Refactored the top-level execution flow into named phase functions (`Test-ScriptPreconditions`, `Initialize-Destination`, `Invoke-ZipExtractions`, `Move-ZipFilesToParent`, `Remove-SourceDirectory`) so the main orchestration is easier to follow.
  - Renamed `Move-Zips-ToParent` to `Move-ZipFilesToParent` for PowerShell naming convention compliance.
  - Removed duplicate historical entries from the script `.NOTES` version history block.
- **FileDistributor.ps1 v4.8.8** (module v1.2.5) (2026-04-12)
  - Hardened parameter contracts using `ValidateRange`/`ValidateSet` attributes for core limit/retry/delete-mode inputs in the script and module public functions.
  - Removed redundant dead defensive checks in `Invoke-ParameterValidation` that are now enforced by parameter binding.
  - Applied small style cleanups in validation code (`-not` consistency and formatting).
- **FileDistributor.ps1 v4.8.7** (module v1.2.4) (2026-04-12)
  - Fixed `Invoke-EndOfScriptDeletion` queue handling so denied `ShouldProcess` (`-WhatIf` or declined `-Confirm`) does not consume pending deletion entries.
  - The function now peeks first and dequeues only when deletion is approved/attempted, preserving queue state for a later confirmed run.
- **FileDistributor.ps1 v4.8.6** (module v1.2.3) (2026-04-12)
  - Extended `SupportsShouldProcess` coverage to post-processing/end-of-script-deletion phases in the support module (`Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`).
  - Added `ShouldProcess` guards for consolidation empty-subfolder deletion and end-of-script source-file deletion so `-WhatIf`/`-Confirm` protects those actions.
- **FileDistributor.ps1 v4.8.5** (module v1.2.2) (2026-04-12)
  - Added `SupportsShouldProcess` to the entry script so `-WhatIf`/`-Confirm` flow is available at invocation time.
  - Added `ShouldProcess` guards to copy and redistribution execution paths (including folder creation and source post-copy handling) in the `FileDistributor` support module.
- **FileDistributor.ps1 v4.8.4** (2026-04-12)
  - Removed the script-local `LogMessage` wrapper and migrated script-level logging calls to direct `Write-Log*` framework APIs.
  - Aligned warning/error accounting with framework counter APIs for end-of-script gating and summary output.
- **Documentation (2026-04-11)**
  - Condensed FileDistributor changelog history for the `v3.3.0–v3.5.0` and `v4.1.0–v4.5.0` feature/checkpoint eras into rollup entries.
  - Preserved the checkpoint progression summary (`CP4`/`CP5`/`CP6`/`CP7`/`CP8`) and mode-level behavior without repeating long per-version prose.
- **Copy-AndroidFiles.ps1 v2.3.2** (2026-04-11)
  - Extracted shared ADB helpers into the reusable `Android/AdbHelpers` module and updated `Copy-AndroidFiles.ps1` to import that module instead of carrying inline ADB helper definitions.
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
- **FileDistributor.ps1 v4.7.2** (module v1.1.2)
  - Fixed race handling in `Invoke-FileMove`: missing source files are now warning-and-skip instead of aborting distribution.
- **FileDistributor.ps1 v4.7.1** (module v1.1.1)
  - Switched retry/file-operation flows to shared Core modules (`Core/ErrorHandling`, `Core/FileOperations`) and removed direct script loading of `Private/RetryOps.ps1`.
- **FileDistributor.ps1 v4.7.x rollup** (v4.7.0–v4.7.13; module v1.1.0→v1.1.13)
  - Hardened moduleized distribution/post-processing flows by fixing script-scope coupling (`LogMessage` migration, explicit state/retry parameters, warning/error counter propagation, and restart/checkpoint wiring).
  - Landed stability fixes across redistribution and rebalance logic (`-Files` parameter typing, random-selection race clamp, divide-by-zero logging guards, unused `-TotalFiles` removal, and unreachable normalized-subfolder guard removal).
- **FileDistributor.ps1 v4.6.x module-extraction sprint (v4.6.0–v4.6.17)**
  - Broke monolithic orchestration into reusable phase helpers and extracted shared move/subfolder/checkpoint helpers to reduce duplicated algorithm logic.
  - Introduced and expanded the internal `FileManagement/FileDistributor` module by moving path/serialization/folder operation helpers out of script scope.
  - Delegated startup log cleanup to `PurgeLogs` (`Clear-LogFile`) and tightened checkpoint/state parameter flow by passing runtime values explicitly.
  - Shipped safety fixes during the extraction series: target-root containment/fallback handling, single-item checkpoint payload support, EndOfScript queue failure signaling, and restored post-run count-integrity warnings.
  - See `src/powershell/file-management/FileDistributor.CHANGELOG.md` for the full 4.6.x sprint rollup.
