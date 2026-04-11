# CHANGELOG — Copy-AndroidFiles

## 2.3.2 — 2026-04-11

### Changed

- **Extracted reusable ADB helpers into a new `Android/AdbHelpers` PowerShell module.**
  `Copy-AndroidFiles.ps1` now imports `src/powershell/modules/Android/AdbHelpers/AdbHelpers.psd1`
  and consumes the shared `Test-Adb`, `Confirm-Device`, `Test-HostTar`, `Test-PhoneTar`,
  `Invoke-AdbSh`, `Get-RemoteSize`, and `Get-RemoteFileCount` functions instead of defining them
  inline.
- **Made ADB helper state explicit at call sites.** `Invoke-AdbSh`, `Test-PhoneTar`,
  `Get-RemoteSize`, and `Get-RemoteFileCount` now accept debug log inputs as parameters, and tar
  prechecks accept the active transfer mode explicitly instead of relying on script scope.

## 2.3.1 — 2026-04-10

### Changed

- **Consolidated `Copy-AndroidFiles.ps1` version history into this changelog.** Removed the long inline multi-version `CHANGELOG` block from the script's comment-based help `.NOTES` section and replaced it with a concise version stamp plus a pointer to `CHANGELOG.md`, while preserving the existing `PREREQUISITES` and `TROUBLESHOOTING` help content unchanged.

## 2.3.0 — 2026-04-10

### Changed

- **Implemented PowerShell parameter sets `Pull` and `Tar`.** Mode-specific parameters are now
  restricted to their respective parameter sets: `-Resume` and `-ProgressIntervalSeconds` belong
  to the `Pull` set; `-StreamTar` and `-MaxRetries` belong to the `Tar` set. PowerShell now
  rejects invalid combinations at binding time (e.g., `-Resume` with `-StreamTar`). The default
  parameter set is `Tar`, preserving existing default behaviour.

- **Retired the `-Mode` parameter.** The active transfer mode is now determined implicitly by
  `$PSCmdlet.ParameterSetName`. All internal `$Mode -eq 'tar'` / `$Mode -eq 'pull'` checks
  have been replaced with `$PSCmdlet.ParameterSetName -eq 'Tar'` / `'Pull'` comparisons. This
  eliminates the possibility of conflicting mode signals (e.g., `-Mode tar -Resume`).

- **Made `-PhonePath` and `-Dest` mandatory.** Personal hard-coded default values for both
  parameters have been removed. Both paths must be supplied explicitly on every invocation.

## 2.2.0 — 2026-04-10

### Changed

- **Extracted `Invoke-ProgressWhileProcess` helper function** from `Copy-AndroidFiles.ps1`.
  The progress-polling loop (`while (-not $proc.HasExited) { ... Write-Progress ... }`) was
  duplicated across the pull-mode `$ShowProgress` block (lines 731–743) and the tar-to-file
  `$ShowProgress` block (lines 857–868). A single parameterised helper now handles both call
  sites: it accepts `Process`, `Activity`, `GetCurrentBytes` (scriptblock), `TotalBytes`, and
  `IntervalSeconds`, covers both the known-size (percentage) and unknown-size (MB-only) display
  branches, and calls `Write-Progress -Completed` before returning. The hard-coded `Start-Sleep 1`
  in tar mode is replaced by the explicit `-IntervalSeconds 1` argument, making the interval
  visible and documentable.

## 2.1.0 — 2026-04-07

### Changed

- **Extracted `Write-VerifySummary` helper function** from `Copy-AndroidFiles.ps1`. The
  post-transfer verification output block was copy-pasted across all four transfer modes
  (resume pull, pull, stream-tar, tar-to-file), totalling ~95 redundant lines. A single
  parameterised helper now handles all modes: it accepts `LocalRoot`, `FilesBefore`,
  `BytesBefore`, `RemoteParent`, `RemoteLeaf`, `TotalBytes`, and `WarnMessage`, calculates
  post-transfer local counts/sizes, retrieves the remote file count, renders the comparison
  table, and emits any warning via `Write-LogWarning`.

### Fixed

- **`Write-Warning` logging bug in TAR-to-file mode.** The verify path for tar-to-file
  called `Write-Warning` (built-in) instead of `Write-LogWarning` (framework). Warnings
  were displayed on-screen but not written to log files. The extracted `Write-VerifySummary`
  helper always uses `Write-LogWarning`, fixing the bug for all modes.

## 2.0.0 — 2025-11-16

### Changed

- Refactored to use `PowerShellLoggingFramework.psm1` for standardized logging.
- Replaced `Write-Host` with `Write-LogInfo` for informational messages.
- Replaced `Write-Warning` with `Write-LogWarning` for warnings.
- Replaced `Write-Verbose` with `Write-LogDebug` for debug messages.
- Retained ADB-specific `DebugMode` for low-level adb diagnostics.
- All log messages are now written to standardized log files.

## 1.x (rollup) — 2025-08-27

### Added

- Introduced disk-space precheck, resumable pull flow, TAR retries/cleanup, and `-StreamTar`.
- Added `-Verify` and local/remote summary reporting after pull and TAR-based transfers.
- Introduced `DebugMode` for transfer troubleshooting with adb command/stdout/stderr capture.

### Changed

- Documented TAR mode as non-resumable; recommended pull with `-Resume` for resumable transfers.
- Replaced awk-dependent remote size parsing with awk-free `du`/`stat`/`find` shell arithmetic.
- Reworked `Invoke-AdbSh` to remove `sh -lc`/`$0` argument tricks and use placeholder replacement.
- Hardened `Invoke-AdbSh` behavior for toybox/busybox-driven phone shells.
- Updated `Test-PhoneTar` to prefer `command -v tar` with `tar --help` fallback while retaining toybox/busybox fallback.
- Verify summary now shows `Local before → after (+Δ)` with mode-aware baseline selection.

### Fixed

- Corrected `Start-Process` handling so `-RedirectStandardError` and `-RedirectStandardOutput` are only splatted when `DebugMode` is enabled, preventing null redirection validation errors.
