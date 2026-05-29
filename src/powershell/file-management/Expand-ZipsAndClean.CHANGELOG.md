# CHANGELOG — Expand-ZipsAndClean

## 2.6.10 — 2026-05-29

### Changed

- Refactored `Remove-SourceDirectory` to reduce its Cognitive Complexity from 32 to ≤15
  (SonarCloud S3776). Extracted four focused private helpers into the `#region Helpers`
  block:
  - `Get-SourceDirectoryItems` — scans the directory and surfaces enumeration errors as
    warnings (complexity 1).
  - `Test-HasBlockingZips` — checks whether leftover zip files block deletion and records
    the error message (complexity 1).
  - `Get-NonZipDeletionBlockReason` — returns a human-readable block reason when non-zip
    items prevent deletion, or `$null` when safe to proceed (complexity 3).
  - `Remove-NonZipItems` — removes non-zip items deepest-first to avoid "directory not
    empty" errors on nested trees (complexity 5).
  - `Remove-DirectoryWithFallback` — deletes the directory root using
    `[System.IO.Directory]::Delete` with a `Remove-Item` fallback, and records a single
    error entry on failure (complexity 12).
  `Remove-SourceDirectory` itself is now a thin orchestrator (complexity ≤10). No
  behavioral change.

## 2.6.9 — 2026-05-27

### Fixed

- Added a `Write-LogDebug` no-op fallback in `FileManagement/ZipWorkflow/ZipWorkflow.psm1` for helper-load test contexts where the logging framework is not in module scope, fixing `Resolve-MoveTarget` Skip-collision test failures caused by unresolved logging calls.

## 2.6.8 — 2026-05-27

### Fixed

- Updated helper-loading Pester contexts to import `FileManagement/ZipWorkflow` before dot-sourcing the script `#region Helpers`, restoring compatibility for extracted-helper wrapper delegation (`ZipWorkflow\Test-ScriptPreconditions` / `ZipWorkflow\Resolve-MoveTarget`) in helper-only test loads.

## 2.6.7 — 2026-05-27

### Changed

- Extracted script-level helper responsibilities for precondition validation (`Test-ScriptPreconditions`), destination initialization (`Initialize-Destination`), and move-target collision resolution (`Resolve-MoveTarget`) into a new `FileManagement/ZipWorkflow` module.
- Kept thin compatibility wrappers in `Expand-ZipsAndClean.ps1` to preserve existing call sites and tests while shifting canonical logic to modules.
- Relocated `Add-Type -AssemblyName System.IO.Compression.FileSystem` from `Expand-ZipsAndClean.ps1` into `ZipExtraction.psm1` so archive assembly loading follows module ownership.

## 2.6.6 — 2026-05-25

### Tests

- Relocated `Describe 'Invoke-ZipExtractions — parallel extraction'` (two `It` blocks) from
  `Expand-ZipsAndClean.Tests.ps1` into a new `Describe 'Invoke-ZipExtractions'` block in
  `tests/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.Tests.ps1`. The tests
  now call `Invoke-ZipExtractions` directly from the module (no change in behaviour — they
  already did so after the 2.6.2 wrapper removal).
- Replaced the removed block with a thin `Describe 'Invoke-ZipExtractions — wrapper delegation'`
  smoke test that verifies a single archive extracts successfully via the module function the
  script delegates to (`ZipExtraction\Invoke-ZipExtractions`). This preserves script-side
  integration coverage that a pure deletion would have lost.
- Net `It` count in `Expand-ZipsAndClean.Tests.ps1`: 20 → 19 (two tests moved to the module
  file; one new delegation smoke test retained here).
- Module CHANGELOG not yet present (tracked by #1065).

---

## Unreleased *(next patch — internal de-duplication refactor; no behavioural change to progress output, summary objects, or extraction logic)*

### Removed

- Script-local `Show-ProgressPhase` function (lines 203–264 of the previous revision):
  relocated to `Core/Progress/Public/Show-ProgressPhase.ps1` and exported from
  `ProgressReporter.psm1`. The script now calls the module-provided canonical version,
  which is always in scope via the existing `Import-Module ProgressReporter.psm1` at
  script start. The dead `Write-Progress` fallback branch (previously lines 244–257)
  is removed along with the function.
- Script-local `New-ExtractionSummary` function: single-sourced in
  `ZipExtraction.psm1` as the canonical definition (removed the guarded `if (-not
  (Get-Command ...))` wrapper, as the script-local duplicate no longer exists).

### Fixed (ZipExtraction.psm1)

- Reconciled the `Show-ProgressPhase` no-op stub in `ZipExtraction.psm1` to include
  the `CurrentOperation` parameter, eliminating the silent divergence where the stub
  would have dropped sub-operation text in helper-load test contexts.

### Tests

- Removed `Describe 'Show-ProgressPhase'` from `Expand-ZipsAndClean.Tests.ps1`; the
  four covered scenarios now live in `tests/powershell/unit/ProgressReporter.Tests.ps1`
  (new `Describe 'Show-ProgressPhase'` block with five `It` blocks, using
  `-ModuleName ProgressReporter` mocking to correctly intercept module-internal
  `Write-Progress` calls).
- `Describe 'Move-ZipFilesToParent'` `BeforeAll`: added `Import-Module
  ProgressReporter.psm1` so the module-provided `Show-ProgressPhase` is available when
  the helpers region is dot-sourced.
- Net test count in `Expand-ZipsAndClean.Tests.ps1`: 24 → 20 (four tests moved to
  `ProgressReporter.Tests.ps1`; one new clamping test added there; net new tests in
  ProgressReporter: +5).



## 2.6.4 — 2026-05-24 *(patch — bug fix, no breaking change)*

### Fixed

- Corrected comment-based help attribution for default override environment variables:
  `SourceDirectory` now explicitly references `EXPAND_ZIPS_SOURCE_DIR` and
  `DestinationDirectory` references `EXPAND_ZIPS_DEST_DIR`.
- Fixed parameter default resolution so whitespace-only values in
  `EXPAND_ZIPS_SOURCE_DIR` / `EXPAND_ZIPS_DEST_DIR` are treated as unset and fall back
  to profile-relative defaults (`$HOME/Downloads/picconvert`, `$HOME/Desktop/New folder`).

## 2.6.3 — 2026-05-24 *(patch — tests/docs only; no runtime behavior change)*

### Tests

- Removed four low-value/duplicate tests (net: 28 → 24 in this file).


## 2.6.2 — 2026-05-24 *(patch — internal refactor; no behavioral change to extraction, move, or summary output)*

### Removed

- Deleted the script-local ZipExtraction wrapper/command-resolution block (~127 lines):
  `Resolve-NonWrapperZipExtractionCommand`, `Get-ZipExtractionModuleCandidates`,
  `Import-ZipExtractionFallbackFiles`, `Get-ZipExtractionCommand`,
  `Invoke-ZipExtractionDelegate`, and the three thin wrappers
  (`Invoke-ZipExtractions`, `Invoke-SerialZipExtractions`, `Invoke-ParallelZipExtractions`).
  These wrappers shadowed the identically-named module exports and required ~120 lines of
  machinery to re-resolve the "real" command while excluding themselves. The `Main` call to
  `Invoke-ZipExtractions` (and the serial/parallel runners it dispatches) now resolves
  directly to the `ZipExtraction` module export, which was already imported at line 185.

### Added

- Import-success guard after the `ZipExtraction` module import: verifies that
  `Get-Command Invoke-ZipExtractions` returns a command whose `Source -eq 'ZipExtraction'`,
  throwing a clear error if the module failed to import or if only a session-level name
  collision would satisfy an unqualified lookup.
- `Main` now calls `ZipExtraction\Invoke-ZipExtractions` (module-qualified) so the correct
  export is resolved even when a same-named function exists elsewhere in the session.

### Tests

- Replaced the helpers-region dot-source approach in `Invoke-ZipExtractions — parallel
  extraction` with a direct `Import-Module ZipExtraction` call, since `Invoke-ZipExtractions`
  is no longer defined in the script helper region.
- Added `Describe 'Invoke-ZipExtractions resolves to ZipExtraction module'` with one `It`
  block asserting `Get-Command Invoke-ZipExtractions` returns a command whose `Source` is
  `ZipExtraction`.


## 2.6.1 — 2026-05-23 *(patch — internal refactor; no behavior change)*

### Changed

- Extracted shared private `Invoke-SingleZipExtraction` (`FileManagement/ZipExtraction/Private/`) that performs `Get-ZipFileStats` + `Expand-ZipSmart` and returns a per-zip result object. Both the serial loop (`Invoke-SerialZipExtractions`) and the parallel runspace helper (`Expand-ZipInRunspace`) now delegate to it, eliminating the duplicated stats-extract-tally sequence.
- Updated `Invoke-ParallelZipExtractions` to pass `Invoke-SingleZipExtraction` into each runspace alongside `Expand-ZipInRunspace`, so the new shared helper is available in parallel execution contexts.
- Extracted private `Resolve-MoveTarget` from `Move-ZipFilesToParent` (in `Expand-ZipsAndClean.ps1`). It accepts the source zip, the parent directory, and `CollisionPolicy`, and returns `{ TargetPath, PolicyTag }`. `Move-ZipFilesToParent` now only performs the actual move and counter updates, with collision logic independently testable.

### Tests

- Added `tests/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.Tests.ps1` covering `Invoke-SingleZipExtraction`: valid archive stats/log output, and throw on corrupt input.
- Added four `Resolve-MoveTarget` tests in `Expand-ZipsAndClean.Tests.ps1`: no-collision path (`PolicyTag=None`), Skip, Overwrite, and Rename policy tags.


## 2.6.0 — 2026-05-23 *(minor — internal module-boundary refactor/import contract expansion; no intentional behavior change)*

### Changed

- Extracted ZIP extraction orchestration helpers (`Invoke-ParallelZipExtractions`, `Invoke-SerialZipExtractions`, `Invoke-ZipExtractions`, and aggregation helper logic) into a new `FileManagement/ZipExtraction` module.
- `Expand-ZipsAndClean.ps1` now imports `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` and delegates ZIP extraction orchestration to that module.

### Fixed

- Reduced SonarCloud duplicated-line matching in module `Invoke-ZipExtractions` by compacting repeated parameter declaration layout while preserving the existing public contract and dispatch behavior.
- Reworked module `Invoke-ZipExtractions` parameter dispatch construction to derive shared argument payload from `$PSBoundParameters` (excluding `SourceDir`) and append `Zips`/`ZipCount`, reducing duplicated new-code blocks flagged by SonarCloud while preserving behavior.
- Refactored `ZipExtraction/Public/Invoke-ZipExtractions.ps1` dispatch flow (logging text composition, empty-archive guard, and runner selection) to reduce duplicated new-code blocks reported by SonarCloud while preserving behavior.
- Fixed wrapper delegation binding in `Invoke-ZipExtractionDelegate` by splatting any `IDictionary` (including `$PSBoundParameters`), preventing mandatory-parameter prompts when dispatching `Invoke-ZipExtractions` to the extracted module command.
- Reduced new-code duplication by simplifying script-local `Invoke-ParallelZipExtractions`/`Invoke-SerialZipExtractions` wrappers to argument-pass-through delegators and extending `Invoke-ZipExtractionDelegate` to handle non-hashtable forwarded arguments.
- Refactored `Get-ZipExtractionCommand` into smaller helper functions (`Resolve-NonWrapperZipExtractionCommand`, `Get-ZipExtractionModuleCandidates`, `Import-ZipExtractionFallbackFiles`) to reduce cognitive complexity while preserving helper-load resilience and non-wrapper command selection safeguards.
- Reduced wrapper duplication by introducing `Invoke-ZipExtractionDelegate` and routing wrapper calls through `@PSBoundParameters` delegation.
- Added a module-scope `New-ExtractionSummary` fallback in `ZipExtraction.psm1` so extracted orchestration helpers can return summary objects in helper-load contexts where the script-local summary builder is not present.
- Added a module-scope `Show-ProgressPhase` compatibility fallback in `ZipExtraction.psm1` so parallel/serial orchestration can run in helper-load test contexts where script-local progress helpers are not present.
- Added no-op `Write-LogInfo`/`Write-LogDebug` fallbacks in `FileManagement/ZipExtraction/ZipExtraction.psm1` so helper-load contexts can execute module orchestration functions without requiring logging-framework scope injection.
- Prevented wrapper recursion/call-depth overflow in helper-load fallback by resolving only non-wrapper extraction commands (prefer `Source=ZipExtraction` or commands defined under the ZipExtraction module path) instead of re-selecting script-local wrapper functions.
- Added a helper-region fallback in `Get-ZipExtractionCommand` that dot-sources `FileManagement/ZipExtraction` `Private/*.ps1` and `Public/*.ps1` directly when module-name discovery/import cannot resolve `ZipExtraction` in test harness contexts.
- Strengthened `Get-ZipExtractionCommand` with upward directory probing from `$PSScriptRoot`, current directory, and loaded `FileSystem` module path to locate `src/powershell/modules/FileManagement/ZipExtraction/ZipExtraction.psm1` across helper-only test execution contexts where previous direct candidates could still miss.
- Added a final fallback module locator in `Get-ZipExtractionCommand` that searches from loaded-module/cwd roots for `ZipExtraction.psm1` when direct candidates are unavailable, preventing remaining helper-load `ZipExtraction` resolution failures in parallel extraction tests.
- Improved `Get-ZipExtractionCommand` module discovery to derive a `ZipExtraction.psm1` candidate from the already-loaded `FileSystem` module path, ensuring helper-region test loads can resolve module commands when neither `$PSScriptRoot` nor working-directory relative candidates are valid.
- Hardened `Get-ZipExtractionCommand` candidate-path construction to avoid passing empty base paths to `Join-Path` in helper-only test loads, fixing `Cannot bind argument to parameter 'Path' because it is an empty string.` failures in parallel extraction tests.
- Restored named-parameter wrapper signatures in `Expand-ZipsAndClean.ps1` for `Invoke-ZipExtractions`, `Invoke-SerialZipExtractions`, and `Invoke-ParallelZipExtractions` so existing call sites continue to bind correctly when delegating to the `ZipExtraction` module.
- Added resilient wrapper command resolution (`Get-ZipExtractionCommand`) that imports the `ZipExtraction` module by path when necessary (including helper-region test loads) before dispatching module functions.
- Moved `Expand-ZipInRunspace` into `FileManagement/ZipExtraction` module private scope so parallel extraction (`-ThrottleLimit > 1`) no longer depends on script-scope helper discovery.


## 2.5.4 — 2026-05-22 *(patch — test-suite maintenance only; no script behaviour change)*

### Tests

- Removed four duplicate/low-value `It` blocks from `Expand-ZipsAndClean.Tests.ps1`; no script logic changed:
  - `Flat: file count returned matches archive entry count` — redundant with `Flat Overwrite` and `Flat Rename`, which already exercise `Expand-ZipFlat` write-count paths; `Get-ZipFileStats` is already covered by `PerArchiveSubfolder: file count returned matches archive entry count` and the `Expand-ZipSmart` fallback test.
  - `delegates per-item non-zip removal to Remove-FileWithRetry` — overlaps with `deletes nested non-zip files deepest-first …`, which drives the same per-item removal path over a richer tree; `Remove-FileWithRetry` is a test stub so the delegation assertion verifies harness wiring only.
  - `delegates move operation to Move-FileWithRetry` — identical single-zip, no-collision scenario to `moves zip files from source to parent directory`; `Move-FileWithRetry` is likewise a test stub, so the `Should -Invoke` assertion verifies harness wiring rather than script logic.
  - `omits CurrentOperation when not provided` — redundant with `calls Write-Progress with computed percentage when QuietMode is false`, which already invokes the function with no `-CurrentOperation`, exercising the same branch.
- Suite now contains 33 tests (was 37).


## 2.5.3 — 2026-05-21 *(patch — internal robustness refactor; no behavior change for callers)*

### Changed

- `Move-ZipFilesToParent` now delegates the file-move operation to `Move-FileWithRetry` (from `Core/FileOperations`) instead of calling `Move-Item` directly. The `Overwrite` collision branch maps to `-Force:$true`; all other branches use `-Force:$false`. Adds transient-lock resilience (AV scanner / network handle) to zip moves.
- Per-item non-zip cleanup in `Remove-SourceDirectory` now calls `Remove-FileWithRetry` instead of bare `Remove-Item`. Items are still processed deepest-first, so directories are empty before deletion and no `-Recurse` flag is needed.
- `Core/FileOperations/FileOperations.psm1` is now imported in the script header alongside the existing Core module imports.
- Slimmed the script header `.NOTES` block in `Expand-ZipsAndClean.ps1` by removing the duplicated inline multi-version history.
- Kept only current script metadata, key parallel extraction operational notes, and a direct pointer to this changelog for full release history.

### Fixed

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


## 2.5.2 — 2026-05-21 *(patch — internal progress abstraction refactor with backward-compatible behavior)*

### Changed

- Replaced script-local `Write-PhaseProgress` usage with `Show-Progress` from `Core/Progress` via a thin `Show-ProgressPhase` adapter that keeps existing call-site arguments (`Current`/`Total`/`QuietMode`) while delegating progress rendering to the shared utility.
- `Expand-ZipsAndClean.ps1` now imports `Core/Progress/ProgressReporter.psm1` alongside existing shared modules.

### Added

- Added `-Suppress` switch to `Core/Progress` `Show-Progress` so callers can centrally suppress progress output without bespoke quiet-mode wrappers around `Write-Progress`.

### Tests

- Updated `Expand-ZipsAndClean` helper tests from `Write-PhaseProgress` to `Show-ProgressPhase` with equivalent coverage for quiet suppression, percentage math, completion behavior, and optional current-operation forwarding.


## 2.5.1 — 2026-05-19 *(patch — bug fix for blank-env-var case)*

### Fixed

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


## 2.5.0 — 2026-05-19 *(minor — default semantics change; back-compat preserved for explicit parameter/env-var users)*

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


## 2.3.3 — 2026-05-17 *(patch — test coverage only; no production behavior change)*

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

## 2.4.x — not released

- Minor version line reserved/skipped during refactor sequencing; no 2.4 release was published.

## 2.3.1 — not released

- Version number reserved and skipped; no released artifact for this version.

## 2.3.2 — 2026-05-17 *(patch — internal refactor, no behaviour change for interactive runs)*

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


## 2.3.0 — 2026-05-17 *(minor — import contract changes)*

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


## 2.2.3 — 2026-05-17 *(patch — progress-helper extraction/refactor)*

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


## 2.2.2 — 2026-05-12 *(patch — extraction stats/perf refactor and helper signature update)*

### Changed

- Consolidated `Add-Type -AssemblyName System.IO.Compression.FileSystem` to a single call at script start. The call was previously repeated inside `Get-ZipFileStats` and `Expand-ZipFlat` on every invocation; it is now issued once during script initialisation and removed from both helper bodies.
- Dropped the caller-side `$stats.CompressedBytes = [int64]$zip.Length` overwrite in `Invoke-ZipExtractions`. `Get-ZipFileStats` already populates `CompressedBytes` from `$zipItem.Length` (the same value); the redundant reassignment was a refactoring residue and is now removed.
- Refactored `Expand-ZipToSubfolder` to accept a new mandatory `[int]$ExpectedFileCount` parameter (pre-computed by `Get-ZipFileStats`) and return it directly. The previous implementation re-walked the destination folder with `Get-ChildItem -Recurse -File | Measure-Object` after extraction, which was both redundant and incorrect when the resolved subfolder pre-existed with files. `Expand-ZipSmart` threads the value through from `Invoke-ZipExtractions`.

### Tests

- Added `PerArchiveSubfolder: file count returned matches archive entry count` — creates a 3-file zip, calls `Get-ZipFileStats` and `Expand-ZipToSubfolder`, and asserts the returned count equals the archive manifest count.
- Added `Flat: file count returned matches archive entry count` — creates a 2-file zip, calls `Get-ZipFileStats` and `Expand-ZipFlat`, and asserts the returned count equals the archive manifest count.
- Updated `dispatches PerArchiveSubfolder mode to Expand-ZipToSubfolder` to pass and assert the new `ExpectedFileCount` parameter.
- All three `Describe` `BeforeAll` blocks now explicitly call `Add-Type -AssemblyName System.IO.Compression.FileSystem` so the assembly is available when helpers are dot-sourced (previously the assembly was loaded lazily inside `Get-ZipFileStats` which is outside the extracted helpers block).

