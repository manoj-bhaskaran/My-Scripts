# File Management Scripts

Scripts for file operations, distribution, copying, and archiving.

## Scripts

- **FileDistributor.ps1** - Distributes files across directories based on rules
- **Copy-AndroidFiles.ps1** - Copies files from Android devices to local storage
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

- **FileDistributor.ps1 v4.6.6**
  - Extracted `New-CheckpointPayload` so distribution and post-processing checkpoints reuse one shared payload builder (including optional `sourceFiles` and `FilesToDelete`) instead of repeated near-identical hashtables.
- **FileDistributor.ps1 v4.6.5**
  - Hardened shared subfolder helper safety: candidate destinations must stay under the target root, and fresh-scan failures now fall back to provided candidates (with emergency-folder fallback preserved).
- **FileDistributor.ps1 v4.6.4**
  - Extracted shared `Get-SubfolderFileCounts` helper so distribution/rebalance algorithms reuse the same subfolder normalization, file-counting, and empty-candidate guard logic.
- **FileDistributor.ps1 v4.6.3**
  - Preserved EndOfScript queue-failure signaling: pending-deletion messages now appear only when queue insertion succeeds; queue failures are surfaced as warnings for easier troubleshooting.
