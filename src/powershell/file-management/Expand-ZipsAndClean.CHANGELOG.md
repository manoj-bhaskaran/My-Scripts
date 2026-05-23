# CHANGELOG — Expand-ZipsAndClean

## Unreleased

## 2.6.0 — 2026-05-23

### Changed

- Extracted ZIP extraction orchestration helpers (`Invoke-ParallelZipExtractions`, `Invoke-SerialZipExtractions`, `Invoke-ZipExtractions`, and aggregation helper logic) into a new `FileManagement/ZipExtraction` module.
- `Expand-ZipsAndClean.ps1` now imports `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` and delegates ZIP extraction orchestration to that module.

### Fixed

- Prevented wrapper recursion/call-depth overflow in helper-load fallback by resolving only non-wrapper extraction commands (prefer `Source=ZipExtraction` or commands defined under the ZipExtraction module path) instead of re-selecting script-local wrapper functions.
- Added a helper-region fallback in `Get-ZipExtractionCommand` that dot-sources `FileManagement/ZipExtraction` `Private/*.ps1` and `Public/*.ps1` directly when module-name discovery/import cannot resolve `ZipExtraction` in test harness contexts.
- Strengthened `Get-ZipExtractionCommand` with upward directory probing from `$PSScriptRoot`, current directory, and loaded `FileSystem` module path to locate `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` across helper-only test execution contexts where previous direct candidates could still miss.
- Added a final fallback module locator in `Get-ZipExtractionCommand` that searches from loaded-module/cwd roots for `ZipExtraction.psm1` when direct candidates are unavailable, preventing remaining helper-load `ZipExtraction` resolution failures in parallel extraction tests.
- Improved `Get-ZipExtractionCommand` module discovery to derive a `ZipExtraction.psm1` candidate from the already-loaded `FileSystem` module path, ensuring helper-region test loads can resolve module commands when neither `$PSScriptRoot` nor working-directory relative candidates are valid.
- Hardened `Get-ZipExtractionCommand` candidate-path construction to avoid passing empty base paths to `Join-Path` in helper-only test loads, fixing `Cannot bind argument to parameter 'Path' because it is an empty string.` failures in parallel extraction tests.
- Restored named-parameter wrapper signatures in `Expand-ZipsAndClean.ps1` for `Invoke-ZipExtractions`, `Invoke-SerialZipExtractions`, and `Invoke-ParallelZipExtractions` so existing call sites continue to bind correctly when delegating to the `ZipExtraction` module.
- Added resilient wrapper command resolution (`Get-ZipExtractionCommand`) that imports the `ZipExtraction` module by path when necessary (including helper-region test loads) before dispatching module functions.
- Moved `Expand-ZipInRunspace` into `FileManagement/ZipExtraction` module private scope so parallel extraction (`-ThrottleLimit > 1`) no longer depends on script-scope helper discovery.

### Versioning

- Bumped version to `2.6.0` (minor — internal module-boundary refactor/import contract expansion; no intentional behavior change).

## 2.5.4 — 2026-05-22

### Tests

- Removed four duplicate/low-value `It` blocks from `Expand-ZipsAndClean.Tests.ps1`; no script logic changed:
  - `Flat: file count returned matches archive entry count` — redundant with `Flat Overwrite` and `Flat Rename`, which already exercise `Expand-ZipFlat` write-count paths; `Get-ZipFileStats` is already covered by `PerArchiveSubfolder: file count returned matches archive entry count` and the `Expand-ZipSmart` fallback test.
  - `delegates per-item non-zip removal to Remove-FileWithRetry` — overlaps with `deletes nested non-zip files deepest-first …`, which drives the same per-item removal path over a richer tree; `Remove-FileWithRetry` is a test stub so the delegation assertion verifies harness wiring only.
  - `delegates move operation to Move-FileWithRetry` — identical single-zip, no-collision scenario to `moves zip files from source to parent directory`; `Move-FileWithRetry` is likewise a test stub, so the `Should -Invoke` assertion verifies harness wiring rather than script logic.
  - `omits CurrentOperation when not provided` — redundant with `calls Write-Progress with computed percentage when QuietMode is false`, which already invokes the function with no `-CurrentOperation`, exercising the same branch.
- Suite now contains 33 tests (was 37).

### Versioning

- Bumped version to `2.5.4` (patch — test-suite maintenance only; no script behaviour change).

## 2.5.3 — 2026-05-21

### Changed

- `Move-ZipFilesToParent` now delegates the file-move operation to `Move-FileWithRetry` (from `Core/FileOperations`) instead of calling `Move-Item` directly. The `Overwrite` collision branch maps to `-Force:$true`; all other branches use `-Force:$false`. Adds transient-lock resilience (AV scanner / network handle) to zip moves.
- Per-item non-zip cleanup in `Remove-SourceDirectory` now calls `Remove-FileWithRetry` instead of bare `Remove-Item`. Items are still processed deepest-first, so directories are empty before deletion and no `-Recurse` flag is needed.
- `Core/FileOperations/FileOperations.psm1` is now imported in the script header alongside the existing Core module imports.
- Slimmed the script header `.NOTES` block in `Expand-ZipsAndClean.ps1` by removing the duplicated inline multi-version history.
- Kept only current script metadata, key parallel extraction operational notes, and a direct pointer to this changelog for full release history.

### Fixed

- Prevented wrapper recursion/call-depth overflow in helper-load fallback by resolving only non-wrapper extraction commands (prefer `Source=ZipExtraction` or commands defined under the ZipExtraction module path) instead of re-selecting script-local wrapper functions.
- Added a helper-region fallback in `Get-ZipExtractionCommand` that dot-sources `FileManagement/ZipExtraction` `Private/*.ps1` and `Public/*.ps1` directly when module-name discovery/import cannot resolve `ZipExtraction` in test harness contexts.
- Strengthened `Get-ZipExtractionCommand` with upward directory probing from `$PSScriptRoot`, current directory, and loaded `FileSystem` module path to locate `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` across helper-only test execution contexts where previous direct candidates could still miss.
- Added a final fallback module locator in `Get-ZipExtractionCommand` that searches from loaded-module/cwd roots for `ZipExtraction.psm1` when direct candidates are unavailable, preventing remaining helper-load `ZipExtraction` resolution failures in parallel extraction tests.
- Improved `Get-ZipExtractionCommand` module discovery to derive a `ZipExtraction.psm1` candidate from the already-loaded `FileSystem` module path, ensuring helper-region test loads can resolve module commands when neither `$PSScriptRoot` nor working-directory relative candidates are valid.
- Hardened `Get-ZipExtractionCommand` candidate-path construction to avoid passing empty base paths to `Join-Path` in helper-only test loads, fixing `Cannot bind argument to parameter 'Path' because it is an empty string.` failures in parallel extraction tests.
- `Show-ProgressPhase` now gracefully falls back to native `Write-Progress` when `Show-Progress` is not present in session scope (for helper-only test dot-sourcing and other partial-load scenarios). This restores test/runtime compatibility without changing script behavior when `Core/Progress` is imported.
- Final `[System.IO.Directory]::Delete` / `Remove-Item` fallback sequence for root-directory deletion is unchanged (Linux/CI PowerShell #8211 workaround preserved).
- `Move-FileWithRetry` and `Remove-FileWithRetry` in `Core/FileOperations` now use `-LiteralPath` for all `Test-Path`, `Move-Item`, and `Remove-Item` calls, preserving literal-path semantics for filenames that contain wildcard characters (`[`, `]`, `*`, `?`).

### Tests

- Removed six duplicate `It` blocks from the test suite (no script logic changed; no version bump required):
  - `exports public extraction functions from the Zip module` — redundant smoke check; every other
    test in the same `Describe` block exercises the exported commands and would fail with
    `CommandNotFoundException` if an export were missing.
  - `rejects rooted entry names while allowing valid relative names` — narrow subset of the
    Zip Slip containment guard already exercised end-to-end by `blocks Zip Slip traversal entries
    in Flat mode` (test 5).
  - `handles non-existent parent gracefully` (in `Move-ZipFilesToParent`) — identical mock
    (`Get-Item` returns `Parent = $null`) and identical assertion to `throws clear error for drive
    root source directory`; the two tests execute the same code path.
  - `suppresses Completed call when QuietMode is true` — the `QuietMode` early-return fires before
    the `-Completed` branch is reached; the guard is already proven by `suppresses Write-Progress
    when QuietMode is true`.
  - `clamps percentage to 100 when Current equals Total` — pure arithmetic on the same expression
    already covered by `calls Write-Progress with computed percentage when QuietMode is false`;
    no distinct branch.
  - `emits error notes when interactive and error list is non-empty` — the error-notes block is
    not gated by interactivity; `emits error notes even when host is non-interactive` already
    proves it fires unconditionally.
- `Remove-SourceDirectory` and `Move-ZipFilesToParent` test `BeforeAll` blocks define inline stubs for `Remove-FileWithRetry` and `Move-FileWithRetry` (using `-LiteralPath` internally) instead of importing the `FileOperations` module directly, avoiding a transitive `ErrorHandling` path resolution failure on CI.
- Added `delegates move operation to Move-FileWithRetry` test to verify the retry helper is wired up in `Move-ZipFilesToParent`.
- Added `delegates per-item non-zip removal to Remove-FileWithRetry` test to verify retry helper delegation in `Remove-SourceDirectory`.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.5.3` (patch — internal robustness refactor; no behavior change for callers).

## 2.5.2 — 2026-05-21

### Changed

- Replaced script-local `Write-PhaseProgress` usage with `Show-Progress` from `Core/Progress` via a thin `Show-ProgressPhase` adapter that keeps existing call-site arguments (`Current`/`Total`/`QuietMode`) while delegating progress rendering to the shared utility.
- `Expand-ZipsAndClean.ps1` now imports `Core/Progress/ProgressReporter.psm1` alongside existing shared modules.

### Enhanced

- Added `-Suppress` switch to `Core/Progress` `Show-Progress` so callers can centrally suppress progress output without bespoke quiet-mode wrappers around `Write-Progress`.

### Tests

- Updated `Expand-ZipsAndClean` helper tests from `Write-PhaseProgress` to `Show-ProgressPhase` with equivalent coverage for quiet suppression, percentage math, completion behavior, and optional current-operation forwarding.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.5.2` (patch — internal progress abstraction refactor with backward-compatible behavior).

## 2.5.1 — 2026-05-19

### Fixed

- Prevented wrapper recursion/call-depth overflow in helper-load fallback by resolving only non-wrapper extraction commands (prefer `Source=ZipExtraction` or commands defined under the ZipExtraction module path) instead of re-selecting script-local wrapper functions.
- Added a helper-region fallback in `Get-ZipExtractionCommand` that dot-sources `FileManagement/ZipExtraction` `Private/*.ps1` and `Public/*.ps1` directly when module-name discovery/import cannot resolve `ZipExtraction` in test harness contexts.
- Strengthened `Get-ZipExtractionCommand` with upward directory probing from `$PSScriptRoot`, current directory, and loaded `FileSystem` module path to locate `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` across helper-only test execution contexts where previous direct candidates could still miss.
- Added a final fallback module locator in `Get-ZipExtractionCommand` that searches from loaded-module/cwd roots for `ZipExtraction.psm1` when direct candidates are unavailable, preventing remaining helper-load `ZipExtraction` resolution failures in parallel extraction tests.
- Improved `Get-ZipExtractionCommand` module discovery to derive a `ZipExtraction.psm1` candidate from the already-loaded `FileSystem` module path, ensuring helper-region test loads can resolve module commands when neither `$PSScriptRoot` nor working-directory relative candidates are valid.
- Hardened `Get-ZipExtractionCommand` candidate-path construction to avoid passing empty base paths to `Join-Path` in helper-only test loads, fixing `Cannot bind argument to parameter 'Path' because it is an empty string.` failures in parallel extraction tests.
- `SourceDirectory` and `DestinationDirectory` param defaults now use the PS7 ternary
  (`$env:VAR ? $env:VAR : fallback`) instead of `??`. The `??` operator only coalesces
  `$null`; when `.env.example` is sourced as-is, both variables are exported as `""` (empty
  string), which `??` passes through — causing `[ValidateNotNullOrEmpty()]` to abort the
  run before the profile-relative fallback could be used. The ternary treats empty string as
  falsy and correctly falls back to the `$HOME`-relative path.
- Updated `.PARAMETER` help for both parameters to state that blank or whitespace-only values
  are treated as unset.

### Tests

- Updated the four existing env-var expression tests to mirror the ternary now used in the
  param defaults (previously they tested `??` expressions).
- Added `SourceDirectory default falls back to $HOME/Downloads/picconvert when env var is blank`
  — sets `EXPAND_ZIPS_SOURCE_DIR=''` and asserts the fallback is used.
- Added `DestinationDirectory default falls back to $HOME/Desktop/New folder when env var is blank`
  — same pattern for the destination env var.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.5.1` (patch — bug fix for blank-env-var case).

## 2.5.0 — 2026-05-19

### Changed

- `SourceDirectory` parameter default no longer hard-codes a personal path. It now resolves from
  `$env:EXPAND_ZIPS_SOURCE_DIR` (when set and non-null) and falls back to
  `Join-Path $HOME 'Downloads/picconvert'` via PS 7 null-coalescing (`??`).
- `DestinationDirectory` parameter default no longer hard-codes a personal path. It now resolves
  from `$env:EXPAND_ZIPS_DEST_DIR` (when set and non-null) and falls back to
  `Join-Path $HOME 'Desktop/New folder'`.
- `.PARAMETER SourceDirectory` and `.PARAMETER DestinationDirectory` help updated to document the
  env-var → profile-relative fallback precedence chain.
- `.DESCRIPTION` Typical workflow paths updated to use `$HOME`-relative examples instead of a
  specific user's profile paths.
- `.NOTES` version history entry added for 2.5.0.

### Docs

- `docs/ENVIRONMENT.md`: added `EXPAND_ZIPS_SOURCE_DIR` and `EXPAND_ZIPS_DEST_DIR` entries to the
  Optional Variables section and to the Optional Variables Summary table.
- `.env.example`: added `EXPAND_ZIPS_SOURCE_DIR` and `EXPAND_ZIPS_DEST_DIR` entries under a new
  `Expand-ZipsAndClean Script` section.

### Tests

- Added `Describe 'Default path resolution from environment variables'` with six `It` blocks:
  - `SourceDirectory default uses EXPAND_ZIPS_SOURCE_DIR when set` — sets the env var and asserts
    the null-coalescing expression resolves to it.
  - `SourceDirectory default falls back to $HOME/Downloads/picconvert when env var is absent` —
    clears the env var and asserts the fallback path is used.
  - `DestinationDirectory default uses EXPAND_ZIPS_DEST_DIR when set` — equivalent for the
    destination env var.
  - `DestinationDirectory default falls back to $HOME/Desktop/New folder when env var is absent`.
  - `param block defaults in the script match env-var resolution when vars are set` — creates real
    directories under `$TestDrive`, sets both env vars to those paths, invokes the script with
    `-WhatIf`, and asserts no `ValidateNotNullOrEmpty` error is raised.
  - `param block defaults in the script use profile-relative fallback when vars are absent` — parses
    the script AST, extracts the default expressions for both parameters, and asserts they reference
    the env-var names and contain no hard-coded personal path (`manoj`).

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.5.0` (minor — default semantics change;
  back-compat preserved for users who pass parameters explicitly or set the env vars).

## 2.3.3 — 2026-05-17

### Tests

- Added `Flat Overwrite: incoming file replaces existing file` — creates a zip with one
  entry whose name collides with an existing file, calls `Expand-ZipFlat` with
  `CollisionPolicy Overwrite`, and asserts the existing file is replaced with the
  incoming content.
- Added `Flat Rename: existing file untouched and incoming written under a unique name` —
  same collision setup but with `CollisionPolicy Rename`; asserts the original file is
  untouched, two `.txt` files exist in the root, and the renamed file holds the
  incoming content.
- Added `Describe 'Test-ScriptPreconditions'` with three `It` blocks:
  - `throws when source and destination are the same path`.
  - `throws when destination is inside the source directory`.
  - `throws when source is inside the destination directory`.
  Each test dot-sources the `#region Helpers` block directly from the script, creates
  real temporary directories under `$TestDrive`, and asserts that `Test-ScriptPreconditions`
  throws with the expected message pattern.
- Added `Describe 'Smoke — Expand-ZipsAndClean.ps1 parse check'` with two `It` blocks:
  - `parses without error under pwsh 7.x` — uses the PowerShell AST parser
    (`[System.Management.Automation.Language.Parser]::ParseFile`) to assert zero
    parse errors.
  - `contains #requires -Version 7.0 directive` — reads the first line of the script
    and asserts it matches the directive exactly.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.3.3` (patch — test coverage only,
  no production behavior change).

## 2.3.2 — 2026-05-17

### Added

- `Write-ExtractionSummary` private helper that accepts all run-state parameters and writes
  the formatted summary to the host. Encapsulates:
  - Compression-ratio computation.
  - Console-width detection (`try/catch` + `?? 120` default via PS 7 null-coalescing).
  - `Format-Table -AutoSize` (wide) / `Format-List` (narrow) branching.
  - Split interactive/non-interactive behavior: the formatted table and header are shown
    only for `ConsoleHost` / `Visual Studio Code Host`; the `Notes / Errors:` block is
    always written when errors exist, so failures are never silent in scheduled tasks or
    automation pipelines.
  - `$HostName` parameter (default `$Host.Name`) for test injection without a real host.

### Changed

- Main script body: replaced the 45-line inline summary block with a single
  `Write-ExtractionSummary` call. `Main` is now focused on orchestration only.
- `Write-ExtractionSummary`: replaced `Write-Host` with `Write-Output` throughout so
  summary text is pipeline-capturable (SonarCloud S2228).
- `Write-ExtractionSummary`: converted two nested `if/else` branches (compression-ratio
  and effective-width selection) to PS7 ternary `?:`, and restructured the `Notes / Errors:`
  header to eliminate an `else` branch — reduces Cognitive Complexity from 18 to ≤15
  (SonarCloud S3776).

### Tests

- Added `Describe 'Write-ExtractionSummary'` with five `It` blocks:
  - `emits summary header when host is interactive (ConsoleHost)`.
  - `suppresses summary table and header when non-interactive and no errors` — passes
    `HostName 'DefaultHost'` with an empty error list; asserts output is empty and
    `Format-Table` / `Format-List` are each called zero times.
  - `emits error notes even when host is non-interactive` — passes `HostName 'DefaultHost'`
    with a non-empty error list; asserts the table is suppressed but errors appear in output.
  - `emits error notes when interactive and error list is non-empty`.
  - `summary view contains expected fields` — uses `-PassThru` switch and filters pipeline
    output by type to extract the `PSCustomObject`; asserts `SrcDir`, `DestDir`, `ZipsFound`,
    `ZipsDone`, `Files`, `Ratio`, and `Duration`.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.3.2` (patch — internal refactor, no
  behaviour change for interactive runs).

## 2.3.0 — 2026-05-17

### Changed

- Extracted archive primitives into the new `Core/Zip` module (issue #976):
  - `Get-ZipFileStats`, `Expand-ZipToSubfolder`, `Expand-ZipFlat`, `Expand-ZipSmart` moved to
    `src/powershell/modules/Core/Zip/Public/`.
  - `Test-IsEncryptedZipError`, `Resolve-ExtractionError`, `Resolve-ZipEntryDestinationPath`
    moved to `src/powershell/modules/Core/Zip/Private/`.
- Added `Import-Module Core/Zip/Zip.psm1` after the `FileSystem` import.
- Removed `using namespace System.IO.Compression` from the script (no longer needed in the
  script body after the zip helpers moved to the module).

### Tests

- Updated `Describe 'Expand-ZipsAndClean helper extraction refactor'` → renamed to
  `'Core/Zip module — public extraction functions'`.
- `BeforeAll` now imports `Core/Zip/Zip.psm1` directly instead of extracting the
  `#region Helpers` block from the script source.
- Module-internal function mocks (`Expand-ZipToSubfolder`, `Expand-ZipFlat`, `Expand-Archive`)
  updated to use `-ModuleName Zip`.
- Tests for private module functions (`Resolve-ZipEntryDestinationPath`,
  `Test-IsEncryptedZipError`, `Resolve-ExtractionError`) now run inside `InModuleScope Zip`.
- The three remaining `Describe` blocks (`Remove-SourceDirectory`, `Move-ZipFilesToParent`,
  `Write-PhaseProgress`) each import `Core/Zip/Zip.psm1` in their `BeforeAll` so
  `Invoke-ZipExtractions` (which calls the module functions) resolves correctly if exercised.

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.3.0` (minor — import contract changes).

## 2.2.3 — 2026-05-17

### Added

- `Write-PhaseProgress` private helper that accepts `Activity`, `Status`, `Current`, `Total`,
  `QuietMode`, optional `CurrentOperation`, and a `Completed` switch. It centralizes percentage
  math (`[int]($Current / [math]::Max(1, $Total) * 100)`) and `-Quiet` suppression so neither
  caller has to hand-roll those two concerns.

### Changed

- `Invoke-ZipExtractions`: replaced two inline `Write-Progress` / `if (-not $QuietMode)` blocks
  with `Write-PhaseProgress` calls.
- `Move-ZipFilesToParent`: replaced inline `Write-Progress` / `if (-not $QuietMode)` blocks with
  `Write-PhaseProgress` calls. The `CurrentOperation` caption now reads
  `"Moving: X of Y bytes"` (was `"Moved X of Y"`), and the byte total shown for the current file
  is `$bytes + $zf.Length` rather than `$bytes`. This fixes the off-by-one display where the
  caption previously showed only the cumulative bytes from already-completed files, omitting the
  file currently being moved.

### Tests

- Added `Describe 'Write-PhaseProgress'` with eight It blocks covering:
  - QuietMode suppression (both normal and Completed paths).
  - Correct `PercentComplete` computation (50 % at midpoint, 100 % at end).
  - `CurrentOperation` included when supplied, omitted when not.
  - `Completed` switch invokes `Write-Progress -Completed`.
  - Zero `Total` guard (no division-by-zero error).

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.2.3`.

## 2.2.2 — 2026-05-12

### Changed

- Consolidated `Add-Type -AssemblyName System.IO.Compression.FileSystem` to a single call at script start. The call was previously repeated inside `Get-ZipFileStats` and `Expand-ZipFlat` on every invocation; it is now issued once during script initialisation and removed from both helper bodies.
- Dropped the caller-side `$stats.CompressedBytes = [int64]$zip.Length` overwrite in `Invoke-ZipExtractions`. `Get-ZipFileStats` already populates `CompressedBytes` from `$zipItem.Length` (the same value); the redundant reassignment was a refactoring residue and is now removed.
- Refactored `Expand-ZipToSubfolder` to accept a new mandatory `[int]$ExpectedFileCount` parameter (pre-computed by `Get-ZipFileStats`) and return it directly. The previous implementation re-walked the destination folder with `Get-ChildItem -Recurse -File | Measure-Object` after extraction, which was both redundant and incorrect when the resolved subfolder pre-existed with files. `Expand-ZipSmart` threads the value through from `Invoke-ZipExtractions`.

### Tests

- Added `PerArchiveSubfolder: file count returned matches archive entry count` — creates a 3-file zip, calls `Get-ZipFileStats` and `Expand-ZipToSubfolder`, and asserts the returned count equals the archive manifest count.
- Added `Flat: file count returned matches archive entry count` — creates a 2-file zip, calls `Get-ZipFileStats` and `Expand-ZipFlat`, and asserts the returned count equals the archive manifest count.
- Updated `dispatches PerArchiveSubfolder mode to Expand-ZipToSubfolder` to pass and assert the new `ExpectedFileCount` parameter.
- All three `Describe` `BeforeAll` blocks now explicitly call `Add-Type -AssemblyName System.IO.Compression.FileSystem` so the assembly is available when helpers are dot-sourced (previously the assembly was loaded lazily inside `Get-ZipFileStats` which is outside the extracted helpers block).

### Versioning

- Bumped `Expand-ZipsAndClean.ps1` version to `2.2.2`.
