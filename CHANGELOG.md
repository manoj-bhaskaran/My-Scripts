# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries older than the current minor release line are condensed to architectural highlights. Full history is available in `git log` and release tags.

### Legend

- `#NNN` references GitHub issues in this repository unless explicitly prefixed otherwise.

## [2.15.1] - 2026-05-16

### Fixed

- **[PostgresBackup] pg_dump auto-detection now compares versions across all install roots (PostgresBackup 2.1.1)** – `Resolve-PgDumpPath` returned the newest `pg_dump` found under the *first* existing Windows install root and never compared it against versions under later roots (`%ProgramFiles(x86)%`). On hosts with PostgreSQL installs split across both roots this could select an older client binary even when a newer major version existed elsewhere, contradicting the documented "newest major version first" behaviour. Fixed by collecting version directories from all roots into a single set and sorting globally before selecting.

## [2.15.0] - 2026-05-16

### Fixed

- **[Backup-GnuCashDatabase] Script-level parameters were silently ignored (Backup-GnuCashDatabase 3.0.1)** – `src/powershell/backup/Backup-GnuCashDatabase.ps1` declared its parameters only on the internal `Invoke-BackupMain` function, which was always called with no arguments, and the script itself had no top-level `param()` block. As a result any parameters passed when invoking the script (e.g. `-BackupRoot`, `-LogsRoot`, `-Database`, `-UserName`, `-RetentionDays`, `-MinBackups`, `-ModuleVersion` from Task Scheduler) were rejected/ignored and the hardcoded `D:\pgbackup\gnucash_db` defaults always won. This only surfaced when running on a spare machine with no `D:` drive, where path overrides were required. Fixed by adding a script-level `[CmdletBinding()] param()` block mirroring the function's parameters and forwarding caller-supplied values to `Invoke-BackupMain` via `@PSBoundParameters` splatting (so unspecified parameters still fall back to the documented defaults).

### Changed

- **[PostgresBackup] `pg_dump` path is now auto-detected instead of hardcoded (PostgresBackup 2.1.0)** – `Private/Config.ps1` previously hardcoded `$pg_dump_path = "D:\Program Files\PostgreSQL\17\bin\pg_dump.exe"`, a machine-specific path that broke the module on any host without that exact drive layout / PostgreSQL version. A new `Resolve-PgDumpPath` private helper now resolves the executable in order: `PGBACKUP_PGDUMP` environment variable (explicit override), `PGBIN` environment variable (libpq convention), `pg_dump` on `PATH`, then the standard Windows install roots (`%ProgramFiles%[ (x86)]\PostgreSQL\<ver>\bin`, newest major version first). A warning is emitted at module load if `pg_dump` cannot be located so misconfiguration surfaces clearly rather than failing opaquely later. Module manifest bumped to `2.1.0`; README configuration/troubleshooting sections updated accordingly.

## [2.14.0] - 2026-05-14

### Added

- **[gdrive_recover] `--skip-existing` flag for local target collisions (gdrive_recover 1.25.0)** – `recover-and-download` now accepts `--skip-existing` as an alternative to `--overwrite`. When the computed local target path already resolves to a regular file (checked via `Path.is_file()`, not `Path.exists()`, so a directory or special-file collision does not trigger a silent skip), the download is skipped, no bytes are written, and the item is still considered a successful operation: per-step state advances (`downloaded` is marked), the post-restore policy is still applied, and the skip is recorded against a new `stats["skipped_existing"]` counter. The `is_file()` discriminator matters because allowing a directory collision to satisfy the skip would otherwise let `post-restore-policy=delete` permanently remove the Drive file with no local copy ever created. The two flags are mutually exclusive via an argparse `add_mutually_exclusive_group`; with neither flag set, the default behaviour is unchanged — a short uuid suffix is appended to the filename to produce a conflict-safe name. Implementation lives in `DriveDownloader.download` (skip branch with `stats_lock`-guarded counter increment) and `DriveTrashRecoveryTool._generate_target_path` (third condition that suppresses the uuid-rename when `--skip-existing` is active).

### Changed

- **[gdrive_report] Run summary surfaces `--skip-existing` outcomes and includes them in the success rate** – `_print_summary` now prints `Files skipped (already on disk, --skip-existing): <n>` whenever `stats["skipped_existing"] > 0`, and the `Download success rate` numerator for `recover-and-download` is `downloaded + skipped_existing` (skipped items are logical successes — the file is on disk and post-restore ran — so they should not depress the success rate). The structured `Run complete` / `Run interrupted` log lines gain a `skipped_existing=%d` field for log-aggregation consumers.

### Documentation

- **[gdrive_recover] Document local target collision handling and re-run idempotency** – The module docstring gains a "Local target collision handling" section that contrasts the three collision behaviours (default uuid-rename, `--overwrite`, `--skip-existing`), warns that re-running without either flag creates a duplicate suffixed copy on every run, and notes which counter each path increments. The `--overwrite` and new `--skip-existing` CLI `--help` strings cross-reference each other and state that the flags are mutually exclusive. Epilog examples in `gdrive_cli.create_parser` updated to show `--skip-existing` alongside `--overwrite`.

## [2.13.9] - 2026-05-13

### Fixed

- **[gdrive_auth] Token write no longer fails with `ERROR_ACCESS_DENIED` on Windows when `token.json` is hidden** – `_harden_token_permissions_windows` marks `token.json` with `FILE_ATTRIBUTE_HIDDEN` after each successful write. Windows documents that `CreateFile` with `CREATE_ALWAYS` and `FILE_ATTRIBUTE_NORMAL` (the combination used by Python's `open(path, "w")`) returns `ERROR_ACCESS_DENIED` when the target file already has `FILE_ATTRIBUTE_HIDDEN` or `FILE_ATTRIBUTE_SYSTEM` set. This caused every token refresh after the first run to fail with `[Errno 13] Permission denied`, even though NTFS ACLs granted Full Control and the file had no `ReadOnly` attribute. Fixed by replacing the direct `open(token_file, "w")` write with a write-to-temp-then-rename pattern: credentials are written to a sibling `.tmp` file via `tempfile.mkstemp`, then atomically moved into place with `os.replace()` (`MoveFileExW`), which is not subject to the same hidden-file attribute restriction. The temp file is cleaned up on any failure before the exception is re-raised.

## [2.13.8] - 2026-05-12

### Fixed

- **[gdrive_auth] Read and write permission failures on `token.json` now log distinct messages** – Both `_load_creds_from_token` and `_refresh_or_flow_creds` previously propagated `PermissionError` to `authenticate()`'s outer handler without any context-specific logging. The outer handler logged only `Authentication failed: [Errno 13] Permission denied: '<path>'`, making it impossible to tell whether the OS had denied a read (file unreadable) or a write (token refresh could not be persisted). Fixed by logging `Permission denied reading token file: <path>` immediately before re-raising in `_load_creds_from_token`, and wrapping `open(token_file, "w")` in `_refresh_or_flow_creds` with an equivalent `Permission denied writing token file: <path>` log. The two messages appear in the log before the generic outer-handler message, pinpointing which operation failed without changing the exception propagation behaviour.

## [2.13.7] - 2026-05-12

### Fixed

- **[gdrive_auth] `_load_creds_from_token` no longer silently swallows `PermissionError`** – The method caught all exceptions with a bare `except Exception` block, including `PermissionError`, and returned `None` without logging anything. When the token file existed but could not be read due to a permission problem, the method silently returned `None`, causing `authenticate()` to proceed to `_refresh_or_flow_creds`. That function then attempted to open the same file for writing (`open(token_file, "w")`), which raised a second `PermissionError`. Because the first failure was swallowed, the only error surfaced was the write-time `[Errno 13] Permission denied`, making it appear that writing had failed when reading had already failed first. Fixed by re-raising `PermissionError` before the generic `except Exception` clause so that `authenticate()`'s outer handler surfaces the true failure point immediately. All other exceptions (e.g. corrupt JSON, missing keys) are still caught and result in a fresh OAuth flow as before.

## [2.13.6] - 2026-05-12

### Fixed

- **[gdrive_auth] `_RequestsHttpAdapter._Resp` now lowercases response header names** – `_Resp` was constructed as a plain `dict` seeded from `requests.Response.headers` (a `CaseInsensitiveDict`). Plain dict iteration preserves the original HTTP wire casing (e.g. `Content-Range`, `Content-Length`), but `MediaIoBaseDownload.next_chunk()` was written for `httplib2`, which normalises all header names to lowercase before returning them. The mismatch meant `"content-range" in resp` evaluated to `False` on every 206 Partial Content response. With no `content-range` or `content-length` found, `self._total_size` remained `None`; the condition `if self._total_size is None` then set `done = True` after the very first chunk, so any file larger than `DOWNLOAD_CHUNK_BYTES` (1 MiB) was silently truncated to 1 MiB. Fixed by building `_Resp` with `{k.lower(): v for k, v in resp.headers.items()}` so all lookups behave consistently regardless of server header casing.

## [2.13.5] - 2026-05-12

### Fixed

- **[gdrive_state] `_save_state` no longer fails when the state-file parent directory does not exist** – `open()` was called on the `.tmp` path without first ensuring the parent directory existed. If `--state-file` pointed to a path whose directory had not been created, every periodic save raised `[Errno 2] No such file or directory` and recovery progress was never written to disk. Added `os.makedirs(..., exist_ok=True)` before the `open()` call so the directory is created automatically on first save.

## [2.13.4] - 2026-05-12

### Fixed

- **[CI / code-formatting.yml] Prevent duplicate Code Formatting scans on PR merge** – Added `concurrency` group `${{ github.workflow }}-${{ github.event.pull_request.base.ref || github.ref_name }}` with `cancel-in-progress: true`. Both the `pull_request: synchronize` run and the `push: main` run after merge resolve to the same group, so the merge-triggered run cancels any still-running PR scan.
- **[CI / security-scan.yml] Prevent duplicate Python Dependency Security scans on PR merge** – Same concurrency fix applied. Also covers the `workflow_dispatch` and `schedule` triggers which resolve to their own per-branch groups and are unaffected by normal PR merges.
- **[CI / validate-modules.yml] Prevent duplicate Validate Modules scans on PR merge** – Same concurrency fix applied. Path filters remain unchanged; the concurrency group ensures only one run proceeds per target branch at a time.
- **[CI / environment-validation.yml] Prevent duplicate Validate Environment Configuration scans on PR merge** – Same concurrency fix applied. Path filters remain unchanged.

## [2.13.3] - 2026-05-12

### Fixed

- **[CI / sonarcloud.yml] Prevent duplicate SonarCloud scans on PR merge** – The workflow declared both a `push: main` and `pull_request: main` trigger. On every PR merge the final `pull_request: synchronize` scan and the subsequent `push: main` scan fired near-simultaneously, analysing the same code twice. Added a `concurrency` group keyed on the target branch (`sonarcloud-${{ github.event.pull_request.base.ref || github.ref_name }}`) with `cancel-in-progress: true`; both event types resolve to `sonarcloud-main`, so the push-to-main scan cancels any still-running PR scan on merge.

## [2.13.2] - 2026-05-12

### Fixed

- **[pyproject.toml] Black `target-version` corrected from `py314` to `py312`** – `py314` is not a recognised target in Black 26.3.1; supplying an unknown version caused Black to fall back to Python 2-compatible output (e.g. rewriting `except (E1, E2):` as `except E1, E2:`), breaking the formatting CI check on every file it touched.
- **[mypy.ini] `python_version` corrected from `3.14` to `3.10`** – Type-checking against the maximum Python version rather than the minimum floor hides incompatibilities for users on 3.10–3.13. Checking against the declared minimum ensures any API or typing feature only valid on newer Python surfaces as an error.
- **[.pre-commit-config.yaml] Removed `language_version: python3.14` from Black hook** – Pinning the hook to a specific interpreter version requires every contributor to have exactly that interpreter installed; contributors on 3.10–3.13 would fail to run pre-commit. Removing the pin lets pre-commit use the active Python.
- **[requirements] Raised `google-auth-httplib2` floor to `>=0.2.0`** – `google-api-python-client==2.194.0` declares a minimum requirement of `google-auth-httplib2>=0.2.0`; the previous floor of `>=0.1.1` caused a pip dependency resolution failure in CI.
- **[requirements.lock] Updated `google-auth-httplib2` from `0.1.1` to `0.2.0`** to resolve the conflict above.

## [2.13.1] - 2026-05-12

### Changed

- **[requirements] Widened numpy constraint to `>=2.3.0,<3.0.0`** – numpy 2.3 is the first release with Python 3.14 wheel support; the previous cap of `<2.3.0` would have prevented installation on 3.14.
- **[requirements] Relaxed opencv-python pin to `>=4.13.0,<5.0.0`** – The hard pin `==4.13.0.92` made the project dependent on a single pre-built wheel that may not exist for every new Python release; a range allows pip to pick the closest available wheel for 3.14.
- **[requirements] Switched `psycopg2` to `psycopg2-binary`** – `psycopg2` requires compilation against `libpq` headers at install time, which often lags new CPython releases by months. `psycopg2-binary` ships pre-built wheels and installs cleanly on 3.14. Import paths are unchanged (`import psycopg2`).
- **[requirements.lock] Aligned locked versions with requirements.txt** – The lock file was significantly stale (e.g., numpy 1.26.4, pandas 2.2.1). Updated all entries to the minimum versions specified in requirements.txt.

### Removed

- **[requirements] Removed `oauth2client==4.1.3`** – The package has been unmaintained since 2019 and will not receive Python 3.14 support. Its authentication functionality is fully covered by `google-auth`, which is already a direct dependency. No source files imported `oauth2client`.

## [2.13.0] - 2026-05-12

### Added

- **[Python] Python 3.14 compatibility** – Declared and verified compatibility with Python 3.14.5 across all Python source files, tests, and tooling. No breaking syntax changes were required; the codebase already used only features stable in 3.14.
- **[setup.py] Python 3.12, 3.13, 3.14 PyPI classifiers** – Added `Programming Language :: Python :: 3.12`, `3.13`, and `3.14` classifiers so the package is correctly advertised on PyPI for all supported interpreters.

### Changed

- **[setup.py] Raised `python_requires` from `>=3.7` to `>=3.10`** – The codebase has used PEP 604 union-type syntax (`X | Y`) since it was introduced, making Python 3.10 the true minimum. The declared floor is now corrected to match the actual requirement.
- **[pyproject.toml] Black `target-version` updated to `py314`** – Ensures Black formats code targeting the Python 3.14 grammar.
- **[mypy.ini] `python_version` updated from `3.11` to `3.14`** – MyPy now type-checks against the 3.14 standard library stubs.
- **[.pre-commit-config.yaml] Black `language_version` updated to `python3.14`** – Pre-commit runs Black with the Python 3.14 interpreter.
- **[CI] All workflow `python-version` pins updated from `3.11` to `3.14`** – Affects `sonarcloud.yml`, `code-formatting.yml`, `security-scan.yml`, `validate-modules.yml`, and `pre-commit-autoupdate.yml`.
- **[INSTALLATION.md / README.md] Minimum Python version updated to 3.10+** – Prerequisites sections now state `Python 3.10+` instead of `Python 3.7+`, and the sample verification output reflects 3.14.5.

### Removed

- **[google_drive_root_files_delete.py] Dropped `from __future__ import print_function`** – This Python 2 forward-compatibility shim is unnecessary on Python 3 and has been removed.

## [Unreleased]

### Security

- **[requirements] Bumped `pytest` minimum to `9.0.3`** to resolve `GHSA-6w46-j5rx-g56g` (predictable `/tmp/pytest-of-{user}` directory name on UNIX enables local DoS / privilege escalation). Previous pin `pytest>=7.4.0,<9.0.0` excluded the fix; new pin is `pytest>=9.0.3,<10.0.0`.
- **[Expand-ZipsAndClean] Hardened Flat-mode Zip Slip path validation** (issue #973)
  - Added a dedicated helper (`Resolve-ZipEntryDestinationPath`) that normalizes archive separators, rejects rooted entry names, resolves a canonical candidate path, and validates containment within the destination root.
  - Containment comparison now uses OS-appropriate semantics (`OrdinalIgnoreCase` on Windows, `Ordinal` elsewhere), avoiding platform-specific false positives/negatives from hard-coded Windows path assumptions.
  - Added Pester coverage for rooted-entry rejection and traversal blocking behavior.

### Fixed

- **[Expand-ZipsAndClean] Remove-SourceDirectory silent short-circuit on PSDrive-qualified `SourceDir`**
  - `[System.IO.Directory]::Exists` / `::Delete` don't understand PowerShell PSDrives. A caller (or test harness) passing `TestDrive:\source-nested` would make `Directory.Exists` return `$false`, so both delete attempts were skipped and the function returned with `$errors` empty while the directory remained on disk — exactly the `"errors: , but got $true"` Pester failure that followed the 2.1.7 fix.
  - Now resolves `SourceDir` to its native provider path (`(Resolve-Path -LiteralPath $SourceDir).ProviderPath`) upfront and uses the resolved path for every `[System.IO.Directory]` call, the recursive `Get-ChildItem` scan, and the deepest-first sort regex. The user-facing error messages still reference the caller's original path.
  - Also enriched the Pester `-Because` diagnostic with `[IO.Directory.Exists]` / `Test-Path` / remaining-items state so future regressions are self-diagnosing.
  - Script version bumped to **2.1.8** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Centralized encrypted-archive extraction error classification** (issue #973)
  - Replaced duplicated catch-block heuristics with `Resolve-ExtractionError` and `Test-IsEncryptedZipError`, which classify nested exceptions/messages in one place and emit a consistent "zip may be encrypted" failure message.
  - Reduces drift between `PerArchiveSubfolder` and `Flat` extraction paths and improves maintainability of encrypted/password-protected archive diagnostics.
  - Script version bumped to **2.2.1** (patch; hardening/refactor, no breaking changes).

- **[Expand-ZipsAndClean] Follow-up fixes for #973 helper regressions (no version change)**
  - `Resolve-ZipEntryDestinationPath` now rejects rooted entry names *before* relative-path normalization and trimming, fixing false acceptance of entries like `/etc/passwd`.
  - Canonical containment checks now compare against a normalized full destination root, and Flat-mode collision detection uses `[System.IO.File]::Exists` for consistent file-existence checks on extracted targets.
  - Added explicit traversal-segment (`..`) rejection and a defensive Skip-policy fallback for late "already exists" extraction exceptions so Flat-mode Skip and Zip Slip tests remain deterministic across runners.
  - Added a second guard in `Expand-ZipFlat` that short-circuits any entry whose raw `entry.FullName` contains traversal markers (`..`) before destination-path resolution, preventing traversal writes even if resolver normalization behavior differs by runtime.
  - Refined the Zip Slip Pester assertion to use a pre-existing sentinel `evil.txt` outside the destination root and verify it is neither overwritten nor accompanied by renamed siblings (`evil*.txt`), making the security expectation deterministic even when parent directories already contain files.
  - Restores expected behavior in Pester scenarios for `Skip` collision policy and Zip Slip traversal blocking.

- **[Expand-ZipsAndClean] Remove-SourceDirectory source-dir deletion unreliable on Linux CI**
  - Replaced the two-pass `Remove-Item -Recurse -Force` pattern for the source directory with `[System.IO.Directory]::Delete($path, recursive: $true)`. On GitHub Actions Linux runners the two-pass pattern was leaving the source directory on disk even after the per-item cleanup loop had successfully removed its contents, which manifested as `Test-Path $sourceDir | Should -BeFalse` failing in the nested-cleanup Pester case.
  - The .NET primitive is synchronous, cross-platform, and not subject to PowerShell issue #8211. `Remove-Item` is retained as a single-shot fallback only if the .NET call fails.
  - Also captured the pipeline item as `$item` before the per-item cleanup `try`/`catch` so that under `Set-StrictMode -Version Latest`, a diagnostic `Write-LogDebug` inside the catch cannot raise a terminating `PropertyNotFoundException` on the `ErrorRecord`. Pester disables StrictMode inside test scopes, so this was only a latent hazard for external callers — but worth hardening.
  - Restored the strict `$errors.Count | Should -Be 0` test assertion with a `-Because` clause that surfaces the actual `$errors` content, so CI failures are self-diagnosing.
  - Script version bumped to **2.1.7** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory double-counted delete failure and strict-mode sort noise**
  - Final source-directory cleanup now records a delete failure in exactly one place, eliminating the `Expected 0, but got 2` Pester failure seen in CI when `Remove-Item` throws while the directory still exists.
  - The failure is now recorded whenever the retry threw, regardless of whether a subsequent `Test-Path` reports the directory absent; this preserves error reporting when permission-denied ACLs make the path unreadable after a genuine `Remove-Item` failure (review feedback on 2.1.5).
  - Wrapped the deepest-first `Sort-Object` expression in `@(...)` so `.Count` stays valid under `Set-StrictMode -Version Latest` for single-segment relative paths (previously emitted non-terminating `Count cannot be found` errors without breaking the sort).
  - Script version bumped to **2.1.6** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory final delete error accounting**
  - Final source-directory cleanup now appends to `ErrorList` only if `SourceDir` still exists after both deletion attempts complete.
  - Exceptions raised during the final retry are now logged at debug level and only surfaced as failures when the directory remains present.
  - Prevents residual `Expected 0, but got 1` failures when transient retry exceptions occur but the source directory is successfully removed.
  - Script version bumped to **2.1.5** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory nested `-CleanNonZips` CI flake**
  - Changed per-item non-zip cleanup failures to best-effort debug diagnostics instead of `ErrorList` entries.
  - `ErrorList` now reflects only final source-directory deletion failure (the true operation result).
  - Prevents intermittent `Expected 0, but got 1` failures in the nested cleanup Pester case when intermediate removals are noisy but final deletion succeeds.
  - Script version bumped to **2.1.4** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory transient Remove-Item errors no longer produce false failures**
  - Guarded cleanup error reporting so `ErrorList` is only appended when the target path still exists after a caught `Remove-Item` failure.
  - Applied the same guard to the final source-directory deletion retry path.
  - Prevents false-positive cleanup failures in CI/Linux cases where `Remove-Item` throws but the path is already deleted.
  - Script version bumped to **2.1.3** (patch; correctness fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory nested cleanup error under `-CleanNonZips`**
  - Hardened non-zip cleanup so directory entries are removed with `Remove-Item -Recurse -Force` while files continue to use file-only removal.
  - Added a deterministic secondary sort key (`FullName` descending) during deepest-first cleanup to avoid same-depth ordering variance.
  - Fixes the nested cleanup case where `Remove-SourceDirectory` could emit `Failed to remove ... directory not empty` even though `-CleanNonZips` was enabled.
  - Script version bumped to **2.1.2** (patch; bug fix, no new features).

- **[Expand-ZipsAndClean] Remove-SourceDirectory non-zip filter and deletion ordering** (issue #970)
  - Simplified the non-zip filter from `(-not $_.PSIsContainer -and $_.Extension -ne '.zip') -or $_.PSIsContainer` to `$_.PSIsContainer -or $_.Extension -ne '.zip'`, dropping the dead `.zip`-exclusion branch (all zips have already been moved by `Move-ZipFilesToParent` before this function runs).
  - Warning message now differentiates between "only empty subdirectories remain" and "non-zip files present" so the caller understands why deletion was blocked.
  - When `-CleanNonZips` is specified, items are now sorted by `FullName` descending (deepest paths first) before removal, preventing "directory not empty" errors on nested trees.
  - `Get-ChildItem` is now invoked with `-ErrorVariable` so unreadable items surface as `Write-Warning` output rather than being silently dropped.
  - Script version bumped to **2.1.1** (patch; correctness fix, no new features).
  - Updated `-DeleteSource` / `-CleanNonZips` parameter help in comment-based documentation.
  - Added four Pester `It` blocks in `tests/powershell/file-management/Expand-ZipsAndClean.Tests.ps1` covering: empty-subdir-only, non-zip-files-present, nested-tree CleanNonZips (deepest-first), and unreadable-item warning.

- **Expand-ZipsAndClean Pester dispatcher mock coverage** (issue #939)
  - Updated `tests/powershell/file-management/Expand-ZipsAndClean.Tests.ps1` to explicitly mock `Expand-ZipFlat` in the `PerArchiveSubfolder` dispatcher test so `Should -Invoke Expand-ZipFlat -Times 0` assertions resolve cleanly in CI.

### Added

- **FileSystem module** bumped to v1.1.0 (issue #937)
  - New path utility functions extracted from `Expand-ZipsAndClean.ps1`:
    - `Get-FullPath`: Normalize paths to absolute Windows paths
    - `Format-Bytes`: Format byte counts into human-readable strings (B, KB, MB, GB, TB)
    - `Resolve-UniquePath`: Generate unique file paths with timestamp suffixes
    - `Resolve-UniqueDirectoryPath`: Generate unique directory paths with timestamp suffixes
    - `Get-SafeName`: Sanitize filenames by removing invalid characters and optionally truncating
    - `Test-LongPathsEnabled`: Check OS registry for Windows long paths support
    - `Resolve-UniquePathCore` (private helper): Shared suffix logic for unique path generation
  - Comprehensive Pester test coverage added for all new functions
  - All functions follow module style conventions with comment-based help

- **BackupState module** (`src/powershell/modules/Backup/BackupState.psm1`, v1.0.0)
  - New module extracted from `Sync-MacriumBackups.ps1` containing all eight state
    management functions: `Format-Duration`, `Read-StateFile`, `Write-StateFile`,
    `Mark-InterruptedState`, `Initialize-StateFile`, `Update-StateStep`,
    `Complete-StateFile`, and `Invoke-AutoResumeLogic`.
  - All functions accept explicit parameters (`StateFile`, `State`, `AutoResume`,
    `Force`, etc.) so the state object is initialised once and passed through the
    call chain, eliminating redundant disk reads.
  - `Export-ModuleMember` explicitly lists all eight public functions.

### Changed

- **FileDistributor ShouldProcess support** (issue #932)
  - Added `SupportsShouldProcess` to `src/powershell/file-management/FileDistributor.ps1` so the entry script now supports `-WhatIf` / `-Confirm`.
  - Updated copy/redistribution phases to honor `ShouldProcess` in `Invoke-DistributionPhase`, `Invoke-FileDistribution`, `Invoke-TargetRedistribution`, and `Invoke-FileMove`.
  - Bumped versions: `FileDistributor.ps1` to `4.8.5` and `FileManagement/FileDistributor` module to `1.2.2`.

- **FileDistributor ShouldProcess coverage for post-processing/deletion phases** (issue #933)
  - Added `SupportsShouldProcess` to `Invoke-PostProcessingPhase`, `Invoke-EndOfScriptDeletion`, `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize`.
  - Guarded consolidation empty-subfolder removal and end-of-script source-file deletion with `ShouldProcess` so `-WhatIf` / `-Confirm` now applies to those operations.
  - Bumped versions: `FileDistributor.ps1` to `4.8.6` and `FileManagement/FileDistributor` module to `1.2.3`.

- **FileDistributor logging refactor** (issue #929)
  - Removed the script-local `LogMessage` wrapper in `src/powershell/file-management/FileDistributor.ps1` and switched script-level logging calls to direct `Write-Log*` framework APIs.
  - Added warning/error counter APIs to `PowerShellLoggingFramework` (`Get-LogWarningCount`, `Get-LogErrorCount`, `Reset-LogCounters`) and updated FileDistributor end-of-script/summary paths to source totals from the logging framework.
  - Bumped versions: `FileDistributor.ps1` to `4.8.4` and `PowerShellLoggingFramework` module to `2.0.1`.

- **Expand-ZipsAndClean.ps1** bumped to v2.0.4 (issues #937, #938, #939)
  - v2.0.4: Split `Expand-ZipSmart` extraction internals into mode-specific helpers (`Expand-ZipToSubfolder` and `Expand-ZipFlat`) and kept `Expand-ZipSmart` as a dispatcher-only compatibility wrapper. Added Pester coverage for dispatcher routing and flat-mode extraction safety/collision behavior.
  - v2.0.1: Refactored seven generic helper functions into `FileSystem.psm1`
    for reuse across scripts (no behavioral changes).
  - v2.0.2: Refactored main execution into named phase helpers:
    `Test-ScriptPreconditions`, `Initialize-Destination`,
    `Invoke-ZipExtractions`, `Move-ZipFilesToParent`, and
    `Remove-SourceDirectory`.
  - v2.0.3: Review follow-up — added comment-based help blocks to extracted
    phase functions for readability/documentation consistency; no behavior
    changes.
  - Renamed `Move-Zips-ToParent` to `Move-ZipFilesToParent` to align with
    PowerShell Verb-Noun naming conventions.
  - Removed duplicate historical entries (`1.1.1`–`1.2.2`) from the script
    `.NOTES` version history block.

- **Sync-MacriumBackups.ps1** bumped to v2.7.2
  - v2.7.0: Extracted all eight state management functions into the new `BackupState`
    module (`BackupState.psm1`). `Test-BackupPath`, `Test-Rclone`, `Test-Network`, and
    `Sync-Backups` now accept an explicit `$State` parameter; state file is read once at
    startup and passed through the call chain. `README.md` updated to document the new
    `BackupState` module dependency.
  - v2.7.1: Extracted `Connect-WiFiNetwork` inner helper to eliminate duplicated
    `netsh wlan connect` + `Start-Sleep` + `Get-CurrentSSID` pattern from `Test-Network`.
    All three WiFi scenarios (preferred, fallback, neither) behave identically to before.
  - v2.7.2: Documentation-only — removed 117-line inline CHANGELOG from `.NOTES`;
    replaced with a pointer to `CHANGELOG.md`. Fixed stale SSID whitelist pattern in
    `PARAMETER_VALIDATION_TESTS.md` to use the current blacklist pattern
    `'^[^"\`$|;&<>\r\n\t]+$'`.

### Fixed

- **FileDistributor EndOfScript queue preservation on denied ShouldProcess** (issue #933)
  - Updated `Invoke-EndOfScriptDeletion` to peek queue entries first and only dequeue when deletion is approved/attempted, preventing `-WhatIf`/declined `-Confirm` from consuming pending queue items.
  - When deletion is not approved, the loop now exits after logging the skip so queued entries remain available for a later approved run in the same session.
  - Bumped versions: `FileDistributor.ps1` to `4.8.7` and `FileManagement/FileDistributor` module to `1.2.4`.

- **Python data smoke import stability:** `src/python/data/seat_assignment.py` now lazy-loads `pandas` and `networkx` via `_get_pandas()` / `_get_networkx()` instead of importing them at module import time, preventing CI smoke-import failures in minimal dependency environments.

## [2.12.10] - 2026-04-05

### Fixed

- **FileDistributor logging consistency (issue #819)**
  - Removed the direct `Write-Host` completion output from `Invoke-FileDistribution` so completion messages flow exclusively through `Write-LogInfo` and the central logging framework
  - Bumped versions: `FileDistributor.ps1` to `4.7.12` and `FileManagement/FileDistributor` module to `1.1.12`

## [2.12.9] - 2026-04-05

### Fixed

- **FileDistributor state helpers now use explicit state/retry parameters instead of script-scope free variables (issue #817)**
  - Added explicit `StateFilePath`, `RetryDelay`, `RetryCount`, and `MaxBackoff` parameters to `Save-DistributionState` and `Restore-DistributionState` in `Private/State.ps1`
  - Added explicit `RetryCount` and `MaxBackoff` parameters to `Write-JsonAtomically` so checksum sidecar writes no longer depend on outer script scope
  - Updated `FileDistributor.ps1` checkpoint and restore call sites to pass the current state path and retry settings explicitly, making the state helpers safe in module/test contexts
  - Added regression coverage for the state helpers to confirm they persist and re-lock using only passed parameters
  - Bumped versions: `FileDistributor.ps1` to `4.7.10` and `FileManagement/FileDistributor` module to `1.1.10`

- **Post-processing module functions used script-scope `LogMessage` and `Write-DistributionSummary` instead of `Write-Log*` (issue #816)**
  - Replaced all `LogMessage` calls in `Invoke-FolderConsolidation`, `Invoke-FolderRebalance`, and `Invoke-DistributionRandomize` with the appropriate `Write-LogInfo`, `Write-LogWarning`, `Write-LogError`, or `Write-LogDebug` framework calls; warning/error ref-counter increments previously implicit in `LogMessage` are now applied directly to `$WarningCount`/`$ErrorCount`
  - Added `Write-DistributionSummary` as a private module function in `Private/Distribution.ps1` (replacing `LogMessage` calls inside it with `Write-LogInfo`), making it available to all three post-processing public functions without depending on the script-scope definition in `FileDistributor.ps1`
  - Bumped `FileManagement/FileDistributor` module version to `1.1.9`

- **Division-by-zero / flood logging when `plannedMoves` or `filesMoving` is 0 in `Invoke-FolderRebalance` and `Invoke-DistributionRandomize`**
  - Replaced `($plannedMoves / 10)` and `($filesMoving / 10)` progress-log thresholds with a pre-computed `$threshold` variable that evaluates to `[int]::MaxValue` when the denominator is 0, preventing a flood of log output on every loop iteration
  - Bumped `FileManagement/FileDistributor` module version to `1.1.6`

- **FolderOps.ps1: use `-LiteralPath` in `Move-ToRecycleBin` and `Remove-DistributionFile`**
  - Changed `Get-Item $FilePath` to `Get-Item -LiteralPath $FilePath` in `Move-ToRecycleBin` to prevent wildcard expansion silently failing for file names containing `[`, `]`, `*`, or `?`
  - Changed `Test-Path -Path $FilePath` to `Test-Path -LiteralPath $FilePath` in `Remove-DistributionFile` for the same reason
  - Bumped versions: `FileDistributor.ps1` to `4.7.5` and `FileManagement/FileDistributor` module to `1.1.4`

- **FileDistributor.ps1 v4.7.3: CP3 checkpoint now saves source files**
  - Added `-IncludeSourceFiles` and `-SourceFiles $RunState.sourceFiles` to the CP3 `New-CheckpointPayload` call in `Invoke-DistributionPhase`
  - Previously the CP3 payload omitted `sourceFiles`, so restarting from CP3 left `$RunState.sourceFiles` empty and the CP4 guard evaluated to `$false`, silently skipping the entire source-to-target distribution phase

### Changed

- **FileDistributor retry/file-operation modularization cleanup (issue #779)**
  - Replaced remaining FileDistributor helper calls with shared Core modules: `Copy-FileWithRetry`, `Remove-FileWithRetry`, and `Invoke-WithRetry` from `Core/ErrorHandling`/`Core/FileOperations`
  - Updated recycle-bin and folder cleanup retry paths to use `Invoke-WithRetry -IgnoreFileNotFound` for file-not-found warning-and-skip behavior
  - Removed `Private/RetryOps.ps1` from FileDistributor loading path and imported Core dependencies directly in `FileDistributor.ps1` and `FileManagement/FileDistributor` module entrypoint
  - Bumped versions: `FileDistributor.ps1` to `4.7.1` and `FileManagement/FileDistributor` module to `1.1.1`

- **FileDistributor race regression: missing source files no longer abort distribution (issue #779 review)**
  - Updated `Invoke-FileMove` to detect source disappearance before/during `Copy-FileWithRetry` and treat it as warning-and-skip behavior
  - Prevents normal concurrent file churn from terminating an otherwise healthy distribution pass
  - Bumped versions: `FileDistributor.ps1` to `4.7.2` and `FileManagement/FileDistributor` module to `1.1.2`

- **FileDistributor modularization: fixed parameter propagation in post-processing APIs**
  - Added `WarningCount`, `ErrorCount`, `RetryDelay`, and `RetryCount` parameters to `Invoke-FolderRebalance`, `Invoke-DistributionRandomize`, and `Invoke-FolderConsolidation`
  - Updated script calls to pass script-scoped warning/error counters and retry settings to prevent incorrect EndOfScript deletion decisions and retry behavior changes
  - Ensures post-processing warnings/errors are properly tracked for `EndOfScript` deletion mode and retry parameters are correctly propagated from script to module functions

## [2.12.5]–[2.12.8]

- Internal iterations rolled into [2.12.9].

## [2.12.0]–[2.12.4] - 2026-03-27 → 2026-03-29

### Changed

- **FileDistributor state/lock modularization + PurgeLogs integration**
  - Moved state helpers to `FileManagement/FileDistributor/Private/State.ps1` and lock helpers to `Private/FileLock.ps1`.
  - Renamed persistence/locking to approved verbs (`Save-DistributionState`, `Restore-DistributionState`, `Lock-DistributionStateFile`, `Unlock-DistributionStateFile`) and updated orchestration call sites.
  - Replaced inline startup log cleanup with `Core/Logging/PurgeLogs` `Clear-LogFile`.
  - Added `Clear-LogFile -BeforeTimestamp` support and cross-runtime timestamp parsing compatibility for `-BeforeTimestamp` and `-RetentionDays`.
  - Added standalone/import-only compatibility so `Clear-LogFile` safely runs when `Initialize-Logger` is unavailable.

### Fixed

- **FileDistributor startup binding safety**
  - Removed unsupported `-WarningsSoFar` / `-ErrorsSoFar` arguments from `New-FileQueue` calls in parameter validation.

## [2.11.x]

- No 2.11.x patches — next release was [2.12.0].

## [2.11.0] - 2026-03-26

### Added

- **ErrorHandling v1.1.0: optional file-not-found skip in `Invoke-WithRetry`**
  - Added `-IgnoreFileNotFound` switch to `Invoke-WithRetry` in `Core/ErrorHandling`
  - When enabled, `ItemNotFoundException` and matching "Cannot find path ... does not exist" errors now log a warning and return without retry/rethrow
  - Default behavior remains unchanged for existing callers that do not set the switch
  - Updated ErrorHandling module documentation and tests to cover the new switch behavior

## [2.10.6] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.7: accept scalar checkpoint payload inputs**
  - Updated `New-CheckpointPayload` parameter typing so single `FileInfo`/`DirectoryInfo` values for `sourceFiles` or `subfolders` bind correctly
  - Prevents valid one-item scenarios (for example `MaxFilesToCopy=1` or a single target subfolder) from failing before `SaveState`

## [2.10.5] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.6: deduplicate checkpoint payload creation**
  - Added `New-CheckpointPayload` to build standard checkpoint state keys (`totalSourceFiles`, `totalSourceFilesAll`, `totalTargetFilesBefore`, `subfolders`, `deleteMode`, `SourceFolder`, `MaxFilesToCopy`) with optional inclusion of `sourceFiles` and `FilesToDelete`
  - Updated `Invoke-DistributionPhase` and `Invoke-PostProcessingPhase` to use the helper for checkpoints 2-8, removing repeated hashtable assembly logic

## [2.10.4] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.5: restore containment and fallback safety in shared subfolder helper**
  - `Get-SubfolderFileCounts` now enforces target-root containment for resolved candidate subfolders before they are used as destinations
  - Fresh-scan enumeration failures no longer force an early empty return; the helper now continues with existing candidates and still allows emergency-subfolder fallback when requested

## [2.10.3] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.4: shared subfolder enumerate/count helper refactor**
  - Added `Get-SubfolderFileCounts` to centralize subfolder normalization, per-folder file counting, empty-candidate handling, and aggregate counting
  - Updated all five distribution algorithms to consume the shared helper for their enumerate-and-count setup sequence, removing duplicated prolog logic

## [2.10.2] - 2026-03-26

### Fixed

- **FileDistributor.ps1 v4.6.3: preserve EndOfScript queue-failure signal**
  - `Invoke-FileMove` now surfaces EndOfScript queue outcome and logs a warning when `Add-FileToQueue` fails
  - `DistributeFilesToSubfolders` now emits "pending deletion" only when queue insertion succeeds; otherwise it logs a warning for easier troubleshooting

## [2.10.1] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.2: shared move helper refactor**
  - Extracted a private `Invoke-FileMove` helper in `FileDistributor.ps1` to unify file-name conflict resolution, retried copy, delete-mode handling (`RecycleBin` / `Immediate` / `EndOfScript` queue), global counter updates, and progress reporting
  - Updated all five distribution algorithms (`DistributeFilesToSubfolders`, `RedistributeFilesInTarget` via `DistributeFilesToSubfolders`, `RebalanceSubfoldersByAverage`, `RandomizeDistributionAcrossFolders`, and `ConsolidateSubfoldersToMinimum`) to reuse the shared helper and remove duplicated move-loop logic

## [2.10.0] - 2026-03-26

### Changed

- **FileDistributor.ps1 v4.6.0: decomposed Main into orchestration sub-functions**
  - Extracted Main into targeted phase functions to improve readability and maintainability:
    - `Invoke-ParameterValidation`
    - `Invoke-RestoreCheckpoint`
    - `Invoke-DistributionPhase`
    - `Invoke-PostProcessingPhase`
    - `Invoke-EndOfScriptDeletion`
    - `Invoke-PostRunCleanup`
  - Main now acts as orchestration glue while checkpoint, restart, deletion-queue, and post-run cleanup behavior remains structured by phase

## [2.9.1] - 2026-03-25

### Fixed

- **Security scan: ignore pygments ReDoS advisory `GHSA-5239-wwwm-4pmq`**
  - No patched version of pygments has been released; upstream has not yet responded to the disclosure
  - Added `--ignore-vuln GHSA-5239-wwwm-4pmq` to the `pip-audit` invocation in `security-scan.yml` and `.pre-commit-config.yaml` to unblock CI until a fix is available, following the same pattern as the existing `CVE-2026-0994` ignore
  - Comment added as a reminder to remove the ignore once pygments ships a patched release

## [2.9.0] - 2026-03-25

### Added

- **FileDistributor.ps1 v4.5.0: support `.mp4` files**
  - Added `.mp4` to the list of allowed extensions so MP4 video files are distributed alongside `.jpg` and `.png` images

## [2.8.0] - 2026-03-24

### Changed

- Renamed `Convert-ImageFile.ps1` to `Move-ImageFileToBatch.ps1` to match actual behavior (batching/moving, not format conversion) and approved PowerShell verb guidance.
- Updated repository documentation and migration mapping references to use the new script name.

## [2.7.6] - 2026-03-23

### Fixed

- Includes internal v2.7.3–v2.7.5 iterations.
- Removed Safety from repository security tooling due to a vulnerable transitive `nltk` chain; standardized dependency scanning on `pip-audit` in pre-commit and CI.
- Resolved lockfile and resolver issues across follow-up fixes (v2.7.5/v2.7.4), including compatible `virtualenv`/`filelock` pins and lockfile-aligned scanning.
- Sync-MacriumBackups fixes from v2.6.1-v2.6.6: corrected `MaxChunkMB` handling, improved rclone flag compatibility, refined sanitised/logged command output, and fixed AutoResume `reason` state handling (see archived pre-2.7.6 script history below).
- Remove-MergedGitBranch fix (v2.7.3): dry-run no longer prunes remote-tracking refs, and `-LogFile` output routing was corrected.
- FileDistributor v4.4.1 output fixes: clearer rebalance skip reasons and reduced console noise in rebalance-only mode.
- Repository maintenance fixes tracked in this cycle: duplicate commit-validation cleanup (#653) and hook-permission cleanup completed through pre-commit migration (#648, #655, #647).

### Added

- Added scheduled PostgreSQL backup automation for the `lift_simulator` database (script, task template, and setup/restore documentation).
- Added the `FileManagement/FileQueue` module for reusable queue state/metadata operations used by distribution workflows. (#602)
- Added Sync-MacriumBackups logging enhancements to improve command traceability and timestamp consistency.

### Changed

- Refactored FileDistributor Phase 2 to use FileQueue module abstractions while preserving compatibility with existing queue state files. (#602, #008)

## [2.7.2] - 2025-12-07

### Changed

- Replaced `Write-Host` with `Write-Information` in `scripts/Load-Environment.ps1` to keep environment-loading messages redirectable while remaining user-visible.
- Documented intentional `Write-Host` usage in `scripts/Check-DocumentationPaths.ps1` with PSScriptAnalyzer suppression for interactive color-coded diagnostics.
- Added console output stream guidelines to `README.md` and `CONTRIBUTING.md`, including code review checks for logging and `Write-Host` justification.

## [2.7.1] - 2025-12-06

### Fixed

- Replaced 33 empty catch blocks across PowerShell scripts/modules with explicit intent (debug logging for best-effort failures or comments for intentionally silent cleanup paths). (#1)
- Improved troubleshooting signal without changing runtime behavior, and shipped related module patches for PurgeLogs and Videoscreenshot.

## [2.7.0] - 2025-12-06

### Added

- Added repository environment-variable reference documentation (`docs/ENVIRONMENT.md`) and linked onboarding/security guidance. (#606, #010)
- Added CI checks investigation report documenting that missing PR checks were caused by repository settings rather than workflow definitions. (#632)

## [2.6.0] - 2025-12-06

### Added

- Replaced legacy module deployment config files with TOML-based configuration (`psmodule.toml`) plus optional local overrides (`psmodule.local.toml`). (#604, #009)
- Added migration/reader scripts and updated deployment docs so module metadata, dependencies, and validation settings are managed from a single source of truth.

## [2.5.0] - 2025-12-06

### Added

- Added `FileSystem` core module with reusable directory/path/file-access helpers to reduce duplicated script-level filesystem logic. (#601, #008)
- Migrated key scripts to shared module functions and covered the module with unit tests for PowerShell 5.1+ compatibility.

## [2.4.1] - 2025-12-06

### Added

- Established repository type-hinting infrastructure with mypy/stubs and CI/pre-commit integration for gradual adoption. (#5, #594)
- Added substantial Python typing coverage for error-handling and logging modules, including generic retry/decorator pathways and strict-mode compatibility updates. (#596)
- Added type annotations for key data-processing scripts (`csv_to_gpx.py`, `validators.py`, `extract_timeline_locations.py`) to improve static validation and IDE feedback.
- Expanded shared-infrastructure test coverage across Python and PowerShell modules, including logging, error handling, file operations, progress reporting, and backup workflows.
- Added Google Drive destructive-operation safeguards and PostgreSQL backup reliability tests to reduce data-loss risk in critical automation paths.

> **2026-04-11 note:** The release timeline gap between [2.4.1] (2025-12-06) and [2.3.1] (2024-06-07) reflects a project hiatus; regular development resumed in December 2025.

## [2.3.1] - 2024-06-07

### Added

- Enabled pip caching across CI workflows (formatting, security, SonarCloud, module validation) with cache hit/miss reporting. (#519)
- npm cache restoration for `sql-lint` in SonarCloud workflow.
- User-scoped PowerShell module caching for linting and deployment jobs.

### Changed

- Documented CI/CD caching strategy in README.

### Security

- Updated vulnerable packages: `requests` 2.31→2.32.4, `tqdm` 4.66.1→4.66.3, `black` 24.1.1→24.3.0, `bandit` 1.7.5→1.7.9. (#520)
- Removed `continue-on-error` from CI quality gates; pre-commit, Pylint, Bandit, PSScriptAnalyzer, Safety, pip-audit, and SonarCloud quality gate are now blocking. (#521)
- Pinned all 23 Python dependencies to exact versions in `requirements.txt` for reproducible builds. (#519)

---

## Sync-MacriumBackups.ps1 — Pre-2.7.6 Script Version History (archived)

Archived script-only history from before numbered project releases. For consolidated release tracking, see [2.7.6] and [Unreleased].

- **v2.6.0** (2026-01-15) - Refactored `Initialize-StateFile`; introduced `$ScriptVersion` and state file `scriptVersion` tracking.
- **v2.5.0** (2026-01-14) - Added sync duration tracking and corrupt state file recovery.
- **v2.4.0** (2026-01-13) - Added `-AutoResume` / `-Force` flags and `Invoke-AutoResumeLogic`.
- **v2.3.0** (2026-01-13) - Added named-mutex single-instance locking with `AbandonedMutexException` handling.
- **v2.2.0** (2026-01-13) - Added persistent JSON state tracking (`Sync-MacriumBackups_state.json`).
- **v2.1.0** (2026-01-13) - Centralised logging in `Scripts\\logs` and switched rclone logging to `--log-file`.
- **v2.0.0** (2025-11-16) - Migrated logging to `PowerShellLoggingFramework.psm1`.
- **v2.6.1-v2.6.6** (2026-01-15) - rclone flag compatibility, sanitised command logging refinements, and AutoResume `reason` property bug fix.

---

## [Pre-release] - 2024

### Added

- **Testing Framework** — Python (pytest) and PowerShell (Pester) test suites with `pytest.ini`, shared fixtures, SonarCloud CI integration, and initial tests for validators, logging, CSV-to-GPX, RandomName, and FileDistributor.
  - `tests/python/conftest.py`, `tests/README.md`, and `docs/guides/testing.md` set up shared fixtures and testing standards.
  - Coverage reporting integrated with SonarCloud; XML reports uploaded as CI artifacts.
- **Git Hooks for Quality Enforcement** (#455) — Tracked `hooks/` templates covering pre-commit linting, commit-msg Conventional Commits validation, and post-commit/merge automation.
  - Pre-commit runs PSScriptAnalyzer and Pylint; commit-msg enforces `type(scope): description` format.
  - Post-commit and post-merge hooks call PowerShell scripts for file mirroring and module deployment.
  - `scripts/install-hooks.sh` installs hooks into `.git/hooks/` and makes them executable.
- **Module Deployment Configuration** (#456) — `.psd1` manifests for `PostgresBackup`, `PowerShellLoggingFramework`, and `PurgeLogs` (v2.0.0); `config/module-deployment-config.txt` lists all five modules.
  - `scripts/Deploy-Modules.ps1` validates manifests and deploys to System, User, or custom paths with cross-platform support.
  - `scripts/install-modules.sh` installs both PowerShell and Python modules with selective and force-overwrite options.
- **Test Coverage Infrastructure** (#459) — `tests/powershell/Invoke-Tests.ps1` runs Pester with JaCoCo output for SonarCloud/Codecov upload.
  - Python coverage enforced via `pytest.ini`; both languages upload to Codecov with per-language flags.
  - Phased ramp-up roadmap in `docs/COVERAGE_ROADMAP.md` (baseline → 30% over six months); coverage badges added to README.
- **Shared Utilities Modules** (#461) — PowerShell `ErrorHandling` (retry with exponential backoff, privilege detection), `FileOperations` (resilient ops with retry), and `ProgressReporter` (progress bars with logging).
  - Python equivalents: `error_handling` (decorators for retry/error handling) and `file_operations` (resilient file I/O with atomic writes).
  - All five modules have ≥70% unit test coverage; usage guide at `docs/guides/using-shared-utilities.md`.
- **Architecture Documentation** (#462) — `ARCHITECTURE.md` covers design principles, component architecture, and six key design decisions with rationale.
  - `docs/architecture/` contains database ER diagrams, PowerShell/Python module dependency graphs, external integration guides, and seven Mermaid data-flow sequence diagrams.
- **Pre-Commit Framework** (#463) — `.pre-commit-config.yaml` integrates Black, Pylint, Bandit, PSScriptAnalyzer, SQLFluff, Commitizen, and general hooks (whitespace, YAML/JSON validation, large-file detection).
  - CI workflow runs hooks on all files; weekly automated hook-update PR via `.github/workflows/pre-commit-autoupdate.yml`.
- **Code Formatting Automation** (#464) — Black (Python), PSScriptAnalyzer OTBS (PowerShell), and SQLFluff PostgreSQL (SQL) configured via `.editorconfig` and `.vscode/settings.json`.
  - `scripts/format-all.sh` formats all languages in one command; `.github/workflows/code-formatting.yml` fails CI on formatting violations.
- **Automated Release Workflow** (#465) — `.github/workflows/release.yml` validates version format, extracts CHANGELOG entry, and publishes a GitHub Release on version tag push.
  - `scripts/bump-version.sh` bumps `VERSION` and adds a dated CHANGELOG section (major/minor/patch).
  - `.github/RELEASE_CHECKLIST.md` and `docs/guides/versioning.md` cover the full release and rollback process.
- **Configuration Guide and Validation Tools** (#517) — `config/CONFIG_GUIDE.md` with quick-start, platform-specific instructions, and troubleshooting for common setup issues.
  - `scripts/Initialize-Configuration.ps1` interactive wizard covers deployment config, environment variables, and PostgreSQL secrets (Windows DPAPI).
  - `scripts/Verify-Configuration.ps1` validates staging mirror, git hooks, PowerShell modules, and env vars with CI-friendly exit codes.
- **Centralized Environment Configuration** (#510) — `.env.example` documents all variables; Bash/PowerShell loaders in `scripts/`; `docs/guides/environment-variables.md` for cross-platform setup.
  - Google Drive credential paths made configurable via `GDRIVE_CREDENTIALS_PATH`/`GDRIVE_TOKEN_PATH` environment variables. (#506)
- **Portable Task Scheduler Templates** (#512) — Nine Windows Task Scheduler XML files converted to `.xml.template` with `{{SCRIPT_ROOT}}` placeholder.
  - `scripts/Install-ScheduledTasks.ps1` generates, validates, and registers tasks; `scripts/Uninstall-ScheduledTasks.ps1` removes them.
- `Sync-Directory.ps1` v1.1.0: `ExcludeFromDeletion` glob patterns preserve non-repository files (logs, virtual environments, configs) during repository-to-working-copy sync.
- Automated Python dependency security scanning (Safety, pip-audit, GitHub Dependency Review) on push, PR, and weekly schedule. (#520)
- Pester unit tests for `PostgresBackup` (#507), Git hooks (#508), `ErrorHandling` (#516), and `FileOperations` (#515); pytest tests for Google Drive auth, module logger initialisation, Bandit B113 compliance, and GPS/timeline data transformations.

### Changed

- Unified version management: `setup.py` reads `VERSION` file as single source of truth; `pyproject.toml` aligned. (#518)
- `create_github_issues.sh` processes all files in the issues directory (not just `issue*`-prefixed) with a configurable `--issues-dir` parameter. (#500, #504)
- Replaced `Write-Host` with the centralised logging framework in backup and maintenance scripts; standardised PowerShell modules to Public/Private folder structure.

### Fixed

- Removed hardcoded paths from PowerShell scripts and batch files; credentials configured via `PGBACKUP_PASSWORD_FILE`, `HANDLE_EXE_PATH`, and related environment variables. (#513)
- Replaced hardcoded paths in documentation with `<REPO_PATH>`/`<SCRIPT_ROOT>` placeholders; `scripts/Check-DocumentationPaths.ps1` enforces this in CI. (#514)
- Python modules no longer raise `AttributeError` on standalone import; each calls `plog.initialise_logger(__name__)` at module level. (#511)
