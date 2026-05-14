# Changelog

## [1.24.1] - 2026-05-14

### Removed

- **`--download-dir` removed from `recover-only`:** The argument was accepted by the parser but had no effect — `will_download` is only set to `True` for `recover_and_download` mode (or `dry-run` with `--download-dir`), never for `recover-only`. Keeping it was a footgun: a user could pass `--download-dir ./out` expecting files to appear there, see no error or warning, and not realise nothing was downloaded. The argument is now rejected by the `recover-only` subparser. It remains optional on `dry-run` (where it causes target paths to be shown in the plan) and required on `recover-and-download`.

## [1.24.0] - 2026-05-14

### Added

- **Per-item step records with v2 → v3 schema migration (#1030):** `processed_items` has been promoted from a flat `List[str]` (O(n) membership) to a `Dict[str, ProcessedRecord]` (O(1) membership) where each record carries three boolean flags — `recovered`, `downloaded`, `post_restored` — and a `last_attempt_iso` timestamp for diagnostics.
  - `_process_item` now calls `_mark_step(item_id, step)` after each individual pipeline step succeeds instead of marking the item as a whole only at the end. This means an interrupted run that completed the untrash step but not the download step will skip the untrash API call on the next run and retry only the download.
  - `_recover_file` checks `_step_is_done(item_id, "recovered")` and skips the `files.update(trashed=False)` call when the untrash step is already recorded, preventing redundant (and noisy) 4xx calls against live files.
  - `_is_processed(item)` now takes the full `RecoveryItem` so it can compute which steps are required for that item (e.g. `recovered` only for recover-only mode; `recovered + downloaded + post_restored` for recover-and-download; `downloaded + post_restored` for folder-id / retry-failed-file items where `will_recover=False`).
  - New `_required_steps(item)` helper encapsulates this logic; new `_step_is_done(item_id, step)` exposes individual step checks.
  - `_mark_step` serialises dict mutations with an internal `_state_lock` (`threading.Lock`); callers must not hold `stats_lock` when calling it to avoid deadlock (see module docstring in `gdrive_state.py`).
- **New `ProcessedRecord` dataclass** in `gdrive_models.py` with fields `recovered`, `downloaded`, `post_restored` (bool, default `False`) and `last_attempt_iso` (str).

### Changed

- **`RecoveryState.schema_version` default is now 3.** New state files are written at v3 immediately.
- **`RecoveryState.processed_items` type changed** from `Optional[List[str]]` to `Optional[Dict[str, ProcessedRecord]]`; `__post_init__` initialises it to `{}` instead of `[]`.
- **`_mark_processed(item_id)` is now a backward-compat wrapper** that marks all three steps as done. New code uses `_mark_step` per step.

### Migration

- **v2 → v3 is automatic and non-destructive.** On first load of a v2 state file, every ID in the `processed_items` list is converted to a `ProcessedRecord(recovered=True, downloaded=True, post_restored=True)` — all steps are treated as fully complete so no item is reprocessed.
- **v0/v1 → v3 chained migration** also works in a single load: the v1 → v2 scope-synthesis step runs first, then the v2 → v3 list-to-dict conversion.
- **Migration is one-way.** There is no v3 → v2 downgrade. Keep a copy of your state file before running v1.24.0 for the first time if you want to be able to roll back. If you need to retry previously-failed items use `--retry-failed-file <csv>` or `--fresh-run`.

## [1.23.3] - 2026-05-14

### Fixed

- **Final streaming progress line no longer reports a stale `processed=` count.** `ProgressBar.update` throttles redraws by time interval (TTY interval on a terminal, log interval otherwise) and `close()` only emitted a newline, so the last visible progress line could be off by up to one batch from the true totals. A run discovering 57,513 items would commonly end with `processed=57501 discovered=57513` even after every item was actually processed. `DriveTrashRecoveryTool._process_streaming` now invokes a new `_print_final_stream_progress` helper just before `_print_summary` (and before `print_interrupted_state_saved` on Ctrl-C); it calls `ProgressBar.update(..., force=True)` to bypass the throttle and render the true final counts.

## [1.23.2] - 2026-05-14

### Added

- **End-of-run summary is now written to the log file as a structured INFO line.** `RecoveryReporter._print_summary` previously used bare `print()` calls, so when `--log-file` was set the log ended abruptly with no record of how the run concluded. A single grep-friendly `Run complete: mode=… found=… recovered=… downloaded=… skipped=… errors=… elapsed=…s success_rate=…%` line is now emitted at INFO level alongside the stdout summary box. `print_interrupted_state_saved` mirrors this with a `Run interrupted: …` line so the log file unambiguously records the outcome of Ctrl-C'd runs as well. Logger errors are swallowed so a misbehaving handler can't break the user-facing summary.

## [1.23.1] - 2026-05-14

### Fixed

- **Resume-mode summary no longer reports zero skipped items:** `DriveOperations._process_item` short-circuited via `_is_processed` and returned without bumping `stats["skipped"]`. In folder-id mode (and any other mode where `will_recover=False`, e.g. `--retry-failed-file`), `_recover_file` — which does increment the counter — is never invoked, so a resume run where every discovered item was already processed produced a summary with `Files downloaded: 0`, `Files skipped: 0`, and `Errors encountered: 0` despite having processed tens of thousands of items. The short-circuit now bumps `stats["skipped"]` under `stats_lock` so the summary truthfully reflects how many items were skipped because they were already in the state file. Trash-recover mode was unaffected because the redundant `_is_processed` check inside `_recover_file` happened to bump the counter; the in-line check in `_process_item` was the missing one.

## [1.23.0] - 2026-05-14

### Added

- **Scope-aware state file with v1→v2 schema migration (#1029):** State files now record a `scope` block (`source`, `command`, `key`) that captures *what* the run was doing. `source` is one of `trash_query | folder_id | file_ids | retry_failed_file`; `command` is `recover_only | recover_and_download`; `key` is a discriminating fingerprint (folder ID, retry-CSV absolute path, or a 16-char sha256 prefix over the file IDs / trash-query parameters). On load, the scope is compared to the current invocation; on mismatch, the tool refuses to resume and exits with code 2 unless `--fresh-run` is passed. This closes the silent failure where a `recover-only` state file was reused by `recover-and-download` and caused the same IDs to be skipped without being downloaded.
- New `RecoveryStateScope` dataclass in `gdrive_models.py`; new `StateScopeMismatchError` exception in `gdrive_state.py`; new `RecoveryStateManager._derive_scope_from_args` helper.
- CLI now renders a clear remediation message on scope mismatch (saved scope, current scope, suggestion to pass `--fresh-run` or `--state-file <path>`).

### Changed

- **`RecoveryState.schema_version` default is now 2.** v0/v1 state files load successfully, synthesize a `scope` from the current invocation, and are rewritten as v2 on next save. `processed_items` is preserved verbatim — no items are reprocessed.
- **`RecoveryState.owner_pid` removed.** The lock file remains the source of truth for the live PID; the stale field has been retired. v1 files containing `owner_pid` load fine — the unknown field is silently dropped during migration.
- **`state.total_found` is updated from `_seen_total` in streaming mode** at each periodic save and on completion/interruption, so the persisted number reflects how many items have been discovered so far.
- **`--overwrite` deprecation shim removed (per v1.22.0 timing).** `--overwrite` is now strictly a local-file collision policy. It no longer clears `processed_items`, no longer truncates the failed-file CSV, and no longer emits a deprecation warning. Use `--fresh-run` (alone or combined with `--overwrite`) for the fresh-run effects.
- `RecoveryStateManager._clear_processed_items` was removed (only the now-deleted overwrite shim called it). `_reset_state` remains and is the canonical fresh-run primitive.
- `--fresh-run` help text updated: scope reset is mentioned, `owner_pid` is no longer referenced, and the flag is documented as bypassing the scope-mismatch guard.
- Module docstring (`gdrive_recover.py`) and README updated to describe scope semantics and v1 → v2 migration behavior.

### Notes

- **Migration is automatic and non-destructive.** Existing v1 state files load on first run after the upgrade; the synthesized scope reflects the current invocation. On a subsequent run with the same scope, resume proceeds normally. If a different scope is used, the new guard rejects it with a clear message instead of silently skipping work.

## [1.22.0] - 2026-05-14

### Added

- **`--fresh-run` flag (#1028):** New flag available on **both** `recover-only` and `recover-and-download`. When set, the recovery tool ignores prior progress in the state file, regenerates run identity (`run_id`, `start_time`, `owner_pid`), and (if `--failed-file` is set) truncates the failed-file CSV before the run starts. Use this when resuming would target the wrong scope or when you want to retry everything from scratch.
  - Mutually exclusive with `--retry-failed-file`: passing both is rejected with a clear error message (fresh-run starts from nothing; retry resumes a specific list).
  - Implemented via a new `RecoveryStateManager._reset_state` helper that replaces the in-memory state with a fresh `RecoveryState` (preserving only `schema_version`). The subsequent `_initialize_recovery_state` call naturally regenerates identity fields because every "if not X" guard now takes the fresh path.

### Changed

- **`--overwrite` is narrowed to its documented meaning (local-file collision policy).** It no longer logically owns state reset and failed-file truncation; those are now `--fresh-run`'s job. For one release the old combined behavior is preserved as a **deprecation shim**: `--overwrite` alone still clears `processed_items` and truncates the failed-file CSV, but prints a deprecation warning to stderr naming v1.23.0 as the removal target.
- `--overwrite --fresh-run` combination: both effects apply (local-file overwrite + state/failed-file reset); no deprecation warning is printed.
- `DriveOperations._recover_file` and `DriveOperations._process_item` no longer reference `args.overwrite` for the `_is_processed` short-circuit. The short-circuit is bypassed naturally on a fresh run because `_reset_state` empties `processed_items`. The deprecation shim achieves the same effect via `_clear_processed_items`.
- CLI epilog gains a `--fresh-run` example; `--failed-file` help text now refers to `--fresh-run` instead of `--overwrite`; `--overwrite` help text describes the deprecation.

### Deprecated

- The combined "clear state + truncate failed-file + bypass `_is_processed`" behavior of `--overwrite`. It continues to work in this release behind a stderr warning. Migrate to `--fresh-run` (alone or combined with `--overwrite`) before v1.23.0.

### Notes

- **No schema change.** Existing state files load and resume normally. Without `--fresh-run`, behavior is identical to before. With `--fresh-run`, the state file is rewritten on first save with a fresh `run_id`/`start_time` and an empty `processed_items` list, and the user's failed-file CSV (if `--failed-file` is set) is truncated.

## [1.21.2] - 2026-05-14

### Fixed

- **Failed items are no longer marked as processed in the state file (#1027):** `DriveOperations._process_item` previously called `state_manager._mark_processed(item.id)` unconditionally, regardless of whether the recover/download/post-restore steps succeeded. Failed items ended up in both the `--failed-file` CSV *and* `state.processed_items`; on a subsequent rerun they were silently skipped by `_is_processed`, defeating the stated purpose of resume ("rerun and concentrate on what is remaining"). The mark-processed call is now made only on full success. Failed items continue to be appended to `--failed-file` and are reattempted automatically on the next rerun against the same state file.
- Module docstring (`gdrive_recover.py`) and README updated to spell out the new resume semantics; the `_load_state` and summary output now reference `processed_items` as the count of **successfully** processed items.
- Added a clarifying comment on `_recover_file` documenting the invariant that only `_process_item` writes to state.

### Notes

- **No schema change.** Existing state files load and resume normally. Entries written under the old (buggy) semantics may include IDs of items that previously failed; those entries are still treated as "processed" and will be skipped on rerun — there is no way to distinguish them post-hoc. To retry items already marked processed under the old semantics, use `--retry-failed-file` (if the failed-file CSV is available) or trim the state file manually.

## [1.21.1] - 2026-05-14

### Fixed

- **`--retry-failed-file` now sets `will_recover=False` for all retried items:** Files written to the failed-file CSV are already live in Drive (the untrash step either succeeded or was not needed); previously they inherited `will_recover=True` and triggered a redundant — and in edge cases incorrect — `files.update(trashed=False)` call before download. A new `_retry_mode` flag (set on `args` by `main()`) tells `_process_file_data` to skip the recover step.
- **`--retry-failed-file` no longer falls back to a full trash query when the CSV has no actionable rows:** `main()` now exits with code 1 and a clear message instead of continuing with an empty `args.file_ids` list, which previously caused the tool to discover and process all trashed files.
- **Trash-prefetch validation skipped in retry mode:** `_validate_file_ids_if_present` is a no-op when `_retry_mode` is set; the prefetch classifies live files as "skipped_non_trashed" which would have caused confusing log output and potentially dropped all retry IDs from streaming.
- **`--failed-file` and `--retry-failed-file` cannot point to the same path:** Reading and writing the same CSV in one run would silently corrupt it. A new check in `_validate_retry_failed_file_arg` rejects this combination with an informative error message.
- **Removed unused `import io`** from `gdrive_operations.py` (leftover from draft implementation).

## [1.21.0] - 2026-05-14

### Added

- **CSV failed-file output (`--failed-file`):** The file written by `--failed-file` is now a proper CSV instead of a plain text list.  Each row contains three columns:
  - `source_folder_id` — Drive ID of the parent folder the file was discovered in
  - `file_id` — Drive file ID (stable identifier, suitable for retry)
  - `target_path` — full local path where the file was (or would be) saved

  A header row is written automatically on the first entry of each run.  When `--overwrite` truncates the file, the header is written immediately so the file is always a valid CSV.  The `source_folder_id` is populated from the `parents` field returned by the Drive API for every discovery mode (trash query, `--file-ids`, and `--folder-id` BFS traversal).

- **`--retry-failed-file <csv>` for `recover-and-download`:** New argument that accepts a CSV produced by `--failed-file` and retries only the file IDs it contains, restoring each file to its original target path.  The flag is mutually exclusive with `--file-ids` and `--folder-id`; validation rejects missing files, directories, and conflicting flags.

- **`source_folder_id` field on `RecoveryItem`:** Populated at discovery time with the first element of the Drive `parents` array; exposed for downstream consumers and used when writing the failed-file CSV.

- **`parents` requested from Drive API in all discovery modes:** `_id_discovery_fields()` now unconditionally includes `parents` so `source_folder_id` is available regardless of whether the run uses `--file-ids`, `--folder-id`, or a trash query.

### Changed

- `DriveOperations._write_failed_file` rewrites plain-text append logic to use `csv.writer`; writes a header row when the destination file is new or empty.
- `DriveOperations._clear_failed_files` writes the CSV header row (instead of an empty file) so the cleared file remains a valid CSV.
- `DriveTrashRecoveryTool._generate_target_path` checks `args._target_path_overrides` (populated from the retry CSV) before computing a new path, ensuring retried files land exactly where the original run intended.
- Module docstring updated with retry example; CLI epilog updated with retry examples and CSV file extension.

### Notes

- **Breaking change for `--failed-file` consumers:** The output file is now CSV, not plain text.  Update any scripts that read the failed-file line-by-line to use a CSV reader; the `target_path` column contains the same value as the previous plain-text entry.
- Retry mode (`--retry-failed-file`) sets `will_recover=False`; it issues download-only requests.  If a file was moved back to trash between the original run and the retry, the download will fail with HTTP 403/404 and be recorded in the (new) `--failed-file` if one is supplied.

## [1.20.2] - 2026-05-12

### Tests

- **Increased new-code coverage to ≥ 80 %:** Added targeted tests to close gaps identified by SonarCloud (74.2 % → ≥ 80 %):
  - `test_gdrive_operations.py`: added 9 tests covering previously-missed branches in `_do_post_restore_action` (`deleted` action and unknown-action fallback), `_log_post_restore_success` (`deleted` branch), `_handle_post_restore_retry`, `_extract_http_error_detail` (no-separator path), `_log_post_restore_final_error`, `_apply_post_restore_policy` non-terminal-error path (HTTP 5xx), and `_process_item` download-failure path.
  - `test_gdrive_cli_folder_id.py`: imported `_validate_failed_file_arg` alongside the existing stub pattern and added 7 tests covering empty input, valid path with parent-dir creation, existing file, directory-rejection, and `--failed-file` argument acceptance on all three subcommands.

## [1.20.1] - 2026-05-12

### Fixed

- **Post-restore failures now propagate into item failure state:** `_process_item` was discarding the return value of `_apply_post_restore_policy`, so a failed trash or delete API call left `success = True`. Items whose post-restore action failed were therefore not written to `--failed-file` and not counted as errors, making retry lists incomplete. The return value is now folded into `success`; a post-restore failure marks the item as failed and triggers `_write_failed_file`.

## [1.20.0] - 2026-05-12

### Added

- **Optional log file (`--log-file`):** When supplied, a `FileHandler` is attached to the root logger at `DEBUG` level so every per-operation message is captured in the file regardless of console verbosity (`-v` / `-vv`).  Previously a log file was always written to `gdrive_recovery.log` with the same level as the console.  Now the default is no file logging; pass `--log-file <path>` to enable it.  The file and any missing parent directories are created automatically.
- **Failed-file log (`--failed-file`):** New optional argument accepted by all three subcommands (`dry-run`, `recover-only`, `recover-and-download`).  When supplied, the full local path (or Drive file name for recover-only operations) of every failed item is appended to the file, one entry per line, as soon as the failure is detected.  The file and any missing parent directories are created automatically.  When `--overwrite` is active the file is truncated to zero bytes before processing begins, keeping it consistent with the fresh state of the run.
- **`DEFAULT_FAILED_FILE = ""`** constant added to `gdrive_constants.py`.

### Changed

- `DEFAULT_LOG_FILE` in `gdrive_constants.py` changed from `"gdrive_recovery.log"` to `""` (empty string = disabled by default).
- `DriveTrashRecoveryTool._setup_logging` rewritten to use explicit handler objects instead of `logging.basicConfig`, allowing the console handler and the file handler to carry independent log levels.  Console level continues to follow `-v` / `-vv`; the file handler (when enabled) is always `DEBUG`.
- `DriveOperations.__init__` acquires `failed_file` from `args` and stores a dedicated `threading.Lock` for thread-safe writes.

### Notes

- Existing workflows that relied on `gdrive_recovery.log` being written automatically must now pass `--log-file gdrive_recovery.log` explicitly.
- The `--failed-file` path is appended to on every non-overwrite run, so consecutive partial runs accumulate all failures.  Pass `--overwrite` to start fresh.

## [1.19.0] - 2026-05-12

### Added

- **Progress bar for recovery and download operations:** A new `ProgressBar` class (in `gdrive_report.py`) renders an animated in-place progress bar during streaming execution and batch processing.
  - **TTY (interactive terminal):** The bar overwrites the current line via carriage-return, updating every 0.5 s so the display animates smoothly without scrolling. Example rendering:
    - Known total (e.g. `--file-ids`): `[████████░░░░░░░░░░░░] 400/1000 (40.0%) │ 5.2/sec │ ETA: 115s`
    - Streaming (unknown total): `▶ processed=800 discovered=1234 │ 5.2/sec`
  - **Non-TTY (CI / log files):** A plain text line is written at most every 10 s when `--verbose` (`-v`) is active, preserving the previous behaviour and keeping log files tidy.
  - **`--no-emoji` compatibility:** Unicode block characters (`█░▶│`) are replaced with ASCII equivalents (`#->`).
  - `RecoveryReporter` gains `_start_progress(total)`, `_close_progress()`, and `_should_show_progress()` helpers. The bar is started in `print_streaming_start` / `print_processing_start` and finalised (cursor moved to a new line) in `_print_summary` and `print_interrupted_state_saved`.
  - The `verbose >= 1` guard in `_handle_item_result_stream` and `_handle_item_result` is replaced with `reporter._should_show_progress()` so the bar appears on TTY without requiring `-v`.

## [1.18.17] - 2026-05-12

### Changed

- **`--overwrite` now clears the state file's processed-items list before execution begins:** Previously, re-running with `--overwrite` would bypass the per-item skip check but leave all IDs in `processed_items`, so an interrupted overwrite run could not be resumed — without `--overwrite` every item would be skipped again, and with it the whole run restarted from scratch. Now `_prepare_recovery` calls `RecoveryStateManager._clear_processed_items()` immediately after loading state whenever `--overwrite` is set, and prints an `--overwrite: cleared N previously processed item(s) from state` notice. A resumed overwrite run will therefore only re-process items that were not yet completed.

## [1.18.16] - 2026-05-12

### Fixed

- **`--overwrite` now re-processes items that were previously recorded in the state file:** `_process_item` and `_recover_file` both checked `_is_processed` unconditionally and exited early, causing every file to be silently skipped when a state file existed — even when `--overwrite` was explicitly requested. Both checks now honour the flag: when `--overwrite` is set, state-file entries are ignored and items are recovered and downloaded again.

## [1.18.15] - 2026-05-13

### Fixed

- **Token write no longer fails with `ERROR_ACCESS_DENIED` on Windows when `token.json` is hidden** – `_harden_token_permissions_windows` marks the token file with `FILE_ATTRIBUTE_HIDDEN` after each write. Windows's `CreateFile(CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL)` — the call underlying Python's `open(path, "w")` — returns `ERROR_ACCESS_DENIED` when the target already has `FILE_ATTRIBUTE_HIDDEN` set. This caused every OAuth token refresh after the first run to fail with `[Errno 13] Permission denied`, regardless of NTFS ACLs. Fixed by writing credentials to a sibling temp file (`tempfile.mkstemp`) and atomically renaming it into place with `os.replace()` (`MoveFileExW`), which is not subject to the same attribute restriction. The temp file is unlinked on any failure before the exception propagates.

## [1.18.14] - 2026-05-12

### Fixed

- **`_load_creds_from_token` and `_refresh_or_flow_creds` now log distinct messages on `PermissionError`** – Previously both paths propagated the error to `authenticate()`'s outer handler, which logged only the generic `Authentication failed: [Errno 13] Permission denied` message. It was impossible to tell from the log whether the OS had denied a read (token file unreadable) or a write (refreshed token could not be persisted). Fixed by logging `Permission denied reading token file: <path>` before re-raising in `_load_creds_from_token`, and wrapping `open(token_file, "w")` in `_refresh_or_flow_creds` with an equivalent `Permission denied writing token file: <path>` log entry.

## [1.18.13] - 2026-05-12

### Fixed

- **`_load_creds_from_token` no longer silently swallows `PermissionError`** – See project CHANGELOG `[2.13.7]` for full details.

## [1.18.12] - 2026-05-12

### Fixed

- **Success rate no longer shows 0 % after a successful `--folder-id` download:** The final-line metric was computed as `recovered / found`. When `--folder-id` is used, all discovered files are already live (not trashed), so `recovered` stays 0 even when every download succeeds — producing a misleading "Success rate: 0.0 %". The metric is now mode-aware: `recover-and-download` reports **Download success rate** (`downloaded / found`), while `recover-only` continues to report **Recovery success rate** (`recovered / found`).

## [1.18.11] - 2026-05-12

### Fixed

- **`_save_state` no longer fails when the state-file directory does not exist:** `open()` was called on the `.tmp` path without first ensuring the parent directory exists. If `--state-file` pointed to a path whose parent had not been created (e.g. `C:\Users\...\scripts\log\gdrive_recover_state.json`), every periodic state save raised `[Errno 2] No such file or directory` and progress was never persisted. Added `os.makedirs(..., exist_ok=True)` before the `open()` call so the directory is created automatically on first save.

## [1.18.10] - 2026-05-12

### Tests

- **Improved `DriveDownloader` unit-test coverage:** Added four test cases to close the gaps introduced by the `_download_direct` / `_download_via_partial` refactor:
  - `test_download_direct_download_failure` — covers the `except` handler in `_download_direct` when streaming raises.
  - `test_rename_failure_marks_item_failed` — covers the path where `_atomic_replace_with_retry` returns `False`, triggering the `PermissionError` and its `except` handler in `_download_via_partial`.
  - `test_atomic_replace_with_retry_oserror_winerror_32` — covers the `OSError` branch that treats Windows sharing-violation (winerror 32) as retryable.
  - `test_atomic_replace_with_retry_oserror_non_32_reraises` — covers the `raise` path for non-sharing-violation `OSError`s.

## [1.18.9] - 2026-05-12

### Changed

- **`_download_file` refactored to reduce cognitive complexity:** The direct-download and partial-download branches have been extracted into `_download_direct` and `_download_via_partial` respectively, eliminating deeply nested try/except blocks. `_download_file` now delegates to one of these helpers and handles only HTTP-level errors and directory setup. No behaviour change.

## [1.18.8] - 2026-05-12

### Added

- **`--overwrite` flag for `recover-and-download`:** When set, existing local files at the computed target path are replaced instead of being renamed with a short unique suffix. Without the flag the existing conflict-safe behaviour (appending a `_<hex6>` suffix) is unchanged. Useful when re-downloading a Drive folder to refresh a local mirror.

## [1.18.7] - 2026-05-12

### Fixed

- **WinError 32 on `.partial` → final rename eliminated:** `_atomic_replace_with_retry` was called while the `.partial` file's write handle was still open (inside the `with open(partial, "wb")` block). On Windows, holding an open handle prevents renaming the file, causing every rename attempt to fail with `[WinError 32] The process cannot access the file because it is being used by another process`. The rename is now performed after the `with` block exits and the handle is fully closed.

## [1.18.6] - 2026-05-12

### Fixed

- **Dry-run execution command is now valid when `--folder-id` is used without `--download-dir`:** Previously the suggested command fell through to `recover-only`, which the CLI rejects when `--folder-id` is present. The command now emits `recover-and-download --download-dir <DOWNLOAD_DIR>` in that case, with a warning prompting the user to substitute the placeholder with their intended local path.

## [1.18.5] - 2026-05-12

### Fixed

- **Execution command in dry-run now reflects the actual subcommand to run:** `_generate_execution_command` was unconditionally emitting `dry-run` as the subcommand, so the suggested command would not execute the plan. It now emits `recover-and-download --download-dir <dir>` when `--download-dir` is set, or `recover-only` otherwise. `--folder-id` was also missing from the generated command entirely; it is now included whenever it was part of the dry-run invocation.
- **Untrash privilege check suppressed when no files will be recovered:** When `--folder-id` is used, all discovered items have `will_recover=False` (they are not in trash). `_test_operation_privileges` previously ran the untrash check unconditionally, producing a confusing "Test file is not trashed — cannot validate untrash permission" warning. The check is now skipped when the sample item has `will_recover=False`, and the "Untrash" row is omitted from the privilege-checks output.

## [1.18.4] - 2026-05-12

### Fixed

- **Dry-run no longer writes to disk when `--download-dir` is passed:** `_check_privileges()` previously created the target directory and wrote a probe file whenever `args.download_dir` was set, which violated the dry-run "no changes" contract. The write test is now skipped in dry-run mode; the privilege-checks output prints the target directory path as informational text instead of a pass/fail writability result.
- **Dry-run plan now shows per-item target paths when `--download-dir` is provided:** `will_download` and `target_path` were only populated for `recover_and_download` mode in `gdrive_discovery.py`, so passing `--download-dir` to `dry-run` had no visible effect on per-item plan output. Discovery now sets `will_download=True` and computes `target_path` for dry-run items when `--download-dir` is set, and also requests the `size` field from the Drive API in that case (previously only fetched for `recover_and_download`).

## [1.18.3] - 2026-05-12

### Fixed

- **`--download-dir` now accepted by `dry-run` and `recover-only` subcommands:** Previously the argument was registered only on `recover-and-download`, causing argparse to reject it with "unrecognized arguments" when passed to `dry-run` or `recover-only`. Both subcommands now accept `--download-dir` as an optional argument; when provided during a dry-run it is surfaced in plan output to show where files would be saved.

## [1.18.2] - 2026-05-12

### Added

- **Comprehensive usage examples** for all scenarios covering the full feature surface of `gdrive_recover.py`:
  - `gdrive_recover.py` module docstring now includes an `Examples` section with runnable commands for: dry-run (all variants), recover-only (all variants), recover-and-download (all variants), folder-scoped download (`--folder-id`) with dry-run preview, extension filtering, large-folder throughput presets, performance/rate-limiter presets, HTTP transport selection, locking/automation, and `--direct-download`.
  - `gdrive_cli.py` argparse epilog expanded with grouped, labeled examples for every subcommand and flag combination, including a policy reference table and a note on `--folder-id` constraints.
  - `README.md` examples section replaced the single "Folder Download" sub-section with a full `## Examples` section covering all eight scenario groups (dry-run, recover-only, recover-and-download, folder-scoped download, post-restore policy table, performance presets, locking, and automation).

## [1.18.1] - 2026-05-12

### Fixed

- **Import resolution for `validators`:** `gdrive_cli.py` was importing `validate_extensions` and `normalize_policy_token` from a bare `validators` module that only existed in the sibling `data/` directory, causing a `ModuleNotFoundError` at runtime. Extracted the gdrive-specific validators and all their private helpers into a new `gdrive_validators.py` co-located in `cloud/`, updated the import in `gdrive_cli.py`, and trimmed `data/validators.py` to its intended scope (geographic coordinate and timestamp validators).

## [1.18.0] - 2026-05-12

### Added

- **Folder-scoped download (`--folder-id`):** New argument accepted by all three subcommands (`dry-run`, `recover-only`, `recover-and-download`).
  - Scopes discovery to a specific Google Drive folder and all its subfolders via BFS traversal.
  - Targets **non-trashed, live files** — no untrash step is performed (`will_recover=False`).
  - Reconstructs the full subfolder hierarchy under `--download-dir` so each file lands at `<download-dir>/<relative/path/to/file>`.
  - Folder names are sanitized for local filesystems (keeps alphanumeric, space, hyphen, underscore, period; falls back to `unknown` for empty results).
  - Added `_fetch_folder_page`, `_discover_folder_recursively` (non-streaming / dry-run path), and `_stream_stream_folder` (streaming path) to `DriveTrashDiscovery`.
  - `_process_streaming` in `DriveTrashRecoveryTool` routes to `_stream_stream_folder` when `--folder-id` is set.
- **`relative_path` field on `RecoveryItem`:** Stores each file's subfolder path relative to the `--folder-id` root; used by `_generate_target_path` to place downloads in the correct subdirectory.
- **`FOLDER_MIME_TYPE` constant** (`application/vnd.google-apps.folder`) added to `gdrive_constants.py`.
- **Post-restore policy warning:** When `--folder-id` is combined with the default `trash` post-restore policy (which would move downloaded files to Drive Trash), the CLI now prints a prominent warning and suggests `--post-restore-policy retain`.

### Changed

- `_generate_target_path` now places files under `<download-dir>/<relative_path>/<filename>` when `item.relative_path` is set, otherwise falls back to the existing flat layout.
- `_process_file_data` accepts an optional `relative_path` parameter (default `""`) and sets `will_recover=False` when `--folder-id` is provided.
- `_sanitize_path_component` extracted as a static helper on `DriveTrashDiscovery` and reused by both the recursive and streaming folder traversal paths.

### Notes

- Existing trash-recovery workflows (`recover-only`, `recover-and-download` without `--folder-id`) are unchanged.
- Use `dry-run --folder-id <id>` to preview the file tree and target paths before downloading.
- Recommended usage: `recover-and-download --folder-id <id> --download-dir <path> --post-restore-policy retain`

## [1.17.0] - 2026-04-11

### Changed

- **Issue #856:** Extracted dry-run privilege checks from `gdrive_recover.py` into new `gdrive_privileges.py` with `DrivePrivilegeChecker`.
  - `DriveTrashRecoveryTool` now delegates `_check_privileges`, `_check_untrash_privilege`, `_check_download_privilege`, `_check_trash_delete_privileges`, and `_test_operation_privileges` through `self.privileges`.
- Added server-side `modifiedTime >` clause to Drive discovery query when `--after-date` is set, while keeping client-side filtering as a guard.
- Improved target download-path collision handling by switching from iterative `exists()` probing to a single collision fallback using a short UUID suffix.
- Aligned `DEFAULT_WORKERS` with documented guidance by setting it to `min(8, (os.cpu_count() or 1) * 2)`.
- `RecoveryItem.post_restore_action` now defaults via `PostRestorePolicy.TRASH`.

### Fixed

- Prevented unnecessary duplicate file-ID prefetch API calls by reusing existing prefetch caches when metadata has already been collected.
- Added explicit warning when `--clear-id-cache` is enabled to clarify that metadata will be re-fetched in discovery/streaming phases.

## [1.16.0] - 2026-04-11

### Changed

- **Issue #855:** Extracted reporting/presentation concerns into new `gdrive_report.py` with `RecoveryReporter`.
  - Moved dry-run presentation, privilege/scope plan output, execution command rendering, progress output, and execution summary rendering out of `gdrive_recover.py`.
  - `DriveTrashRecoveryTool` now constructs `self.reporter = RecoveryReporter(args, logger, stats)` and routes console presentation through it.
- Completed `--no-emoji` behavior across recovery-related console output:
  - Replaced hard-coded emoji output in `gdrive_recover.py`, `gdrive_discovery.py`, and `gdrive_cli.py` with symbol helpers that honor `--no-emoji`.
  - Updated `gdrive_state.py` and `gdrive_auth.py` informational console messages to respect `--no-emoji` as well.
- Trimmed `gdrive_cli.create_parser()` epilog to a short quick-reference section and moved detailed compatibility/performance guidance to `README.md`.

## [1.15.4] - 2026-04-06

### Fixed

- Refactored `gdrive_retry.with_retries(...)` into smaller helper steps (`_plan_http_error`, `_plan_generic_error`, and retry-log helpers) to reduce cognitive complexity for static analysis while preserving behavior.

## [1.15.3] - 2026-04-06

### Fixed

- Reduced cognitive complexity of `gdrive_retry.with_retries(...)` by extracting internal helper functions for retry gating, error parsing, and delay computation.
- Replaced duplicated `"HTTP 404"` / `"HTTP 403"` string literals in `gdrive_discovery.py` with module-level constants to satisfy static-analysis duplication checks.
- Expanded unit coverage for the retry/discovery changes:
  - Added additional `gdrive_retry` tests for non-HTTP failures and retry logging path.
  - Added additional discovery classification tests for explicit 404 and 403 routing.

## [1.15.2] - 2026-04-06

### Fixed

- Updated `gdrive_retry.with_retries(...)` to return HTTP status alongside result/error so callers can branch on status without parsing message text.
- Fixed ID prefetch error classification in `gdrive_discovery._fetch_and_handle_metadata()` to route on returned status code (`403`/`404`) instead of substring matching.
- Added regression test `tests/python/unit/test_gdrive_discovery_retry_classification.py` to ensure `HTTP 500` payload text containing `HTTP 404` is still classified as transient.

## [1.15.1] - 2026-04-06

### Fixed

- Fixed lint/runtime regression in `gdrive_discovery.py` by restoring the required `time` import used by progress and streaming timers.
- Applied formatting fixes (Black) for:
  - `src/python/cloud/gdrive_retry.py`
  - `src/python/cloud/gdrive_operations.py`
  - `tests/python/unit/test_gdrive_operations.py`

## [1.15.0] - 2026-04-06

### Changed

- **Refactor (Issue #854):** Extracted recovery operations into a new `gdrive_operations.py` module with a `DriveOperations` class.
  - Moved `_recover_file`, `_apply_post_restore_policy`, and post-restore helper methods out of `gdrive_recover.py`.
  - `DriveTrashRecoveryTool` now creates `self.ops = DriveOperations(...)` and delegates `_process_item()` plus operation helpers through this object.
- Added shared retry utility `gdrive_retry.py` with `with_retries(...)` and replaced duplicated retry loops in recovery/discovery call sites.
  - `gdrive_discovery.py` now uses `with_retries(...)` in `_fetch_file_metadata()` and `_fetch_and_handle_metadata()`.
- Added unit tests:
  - `tests/python/unit/test_gdrive_retry.py` for success, retry-then-succeed, terminal failure, and max-retries paths.
  - `tests/python/unit/test_gdrive_operations.py` for recovery and post-restore policy behaviors.

## [1.14.0] - 2026-04-06

### Changed

- **Refactor (Issue #853):** Extracted file download subsystem from `DriveTrashRecoveryTool` into a new `gdrive_download.py` module with a `DriveDownloader` class.
  - Moved `_download_file`, `_download_with_downloader`, `_atomic_replace_with_retry`, `_cleanup_partial_file`, `_handle_download_success`, and `_handle_download_failure` out of `gdrive_recover.py`.
  - `DriveDownloader.__init__` accepts `args`, `logger`, `rate_limiter` (a `RateLimiter`), `auth` (a `DriveAuthManager`), `stats`, and `stats_lock`.
  - `DriveTrashRecoveryTool.__init__` now constructs `self.downloader = DriveDownloader(...)` and delegates download calls via `self.downloader.download(item)`.
  - `MediaIoBaseDownload` and `DOWNLOAD_CHUNK_BYTES` are imported only in `gdrive_download.py`; removed from `gdrive_recover.py`.
  - `DriveDownloader` is independently importable with no dependency on `DriveTrashRecoveryTool`.
- Added unit tests in `tests/python/unit/test_gdrive_download.py` covering: success path, `direct_download` flag, partial cleanup on failure, `HttpError` during download, and atomic replace with retry.

## [1.13.0] - 2026-04-05

### Changed

- **Refactor (Issue #852):** Eliminated bidirectional `__getattr__` coupling between `DriveTrashRecoveryTool` and `DriveTrashDiscovery`.
  - `DriveTrashDiscovery.__init__` now accepts all tool-side dependencies explicitly: `stats`, `stats_lock`, `seen_total_ref`, `generate_target_path`, and `run_parallel_processing_for_batch`.
  - Added `_matches_extension_filter`, `_matches_time_filter`, and `_progress_interval` as direct methods on `DriveTrashDiscovery` (only use `self.args` / `self.logger`, no back-reference needed).
  - Removed `DriveTrashDiscovery.__getattr__` and `self.tool` from `DriveTrashDiscovery` entirely.
  - Removed `DriveTrashRecoveryTool.__getattr__`; `discover_trashed_files` remains an explicit delegation method; all other discovery internals are accessed via `self.discovery.*`.
  - `DriveTrashRecoveryTool._seen_total` is now backed by an injected `List[int]` reference (`_seen_total_ref`) shared with `DriveTrashDiscovery`, preserving atomic updates under `stats_lock`.
  - Added full type annotations to `DriveTrashDiscovery.__init__` parameters.
- Updated unit tests to invoke discovery-specific methods via `tool.discovery.*` rather than through the tool proxy.

## [1.12.7] - 2026-04-05

### Fixed

- **Issue #851 follow-up:** Restored required streaming helper methods in `DriveTrashDiscovery` (`_handle_streaming_file`, `_should_stop_for_limit`, `_process_streaming_batch`, `_should_flush_streaming_batch`) so streaming query/ID execution no longer relies on cross-class fallback lookups.
- Prevented runtime delegation recursion/missing-attribute failures in non-`dry_run` streaming modes by keeping helper ownership co-located with discovery streaming paths.
- Added unit coverage asserting `DriveTrashDiscovery` owns the required streaming helper methods.

## [1.12.6] - 2026-04-05

### Changed

- **Issue #851:** Removed stale duplicated streaming helper implementations from `DriveTrashRecoveryTool`; streaming discovery now lives only in `DriveTrashDiscovery`.
- Removed an unused module-level helper (`get_recoverable_files`) from `gdrive_recover.py`.
- Removed temporary back-compat rate-limiter shim members from `DriveTrashRecoveryTool` (`_rate_limit`, `_rl_diag_tick`, `_tb_initialized`, `_rl_diag_enabled`) so request pacing is accessed through `self.rate_limiter`.
- Updated unit tests to stop depending on removed shims/helpers and to assert that `DriveTrashRecoveryTool._execute()` delegates pacing to `RateLimiter.wait()`.

## [1.12.5] - 2026-04-05

### Fixed

- **Issue #850:** Collapsed `DriveAuthManager._build_and_test_service()` to a single Drive `files().list(pageSize=1)` smoke-test call and reused that response for the optional media probe, eliminating duplicate quota consumption during authentication.
- Replaced the module-level `_PRINTED_REQUESTS_FALLBACK` guard with an instance attribute on `DriveAuthManager`, removing shared mutable module state from `gdrive_constants.py`.
- Added POSIX PID liveness checks in `RecoveryStateManager._pid_is_alive()` using `os.kill(pid, 0)` while keeping the Windows `ctypes` implementation behind an `os.name == "nt"` guard.
- Aligned `DriveTrashRecoveryTool._check_privileges()` with actual behavior by sampling only the single item whose privileges are tested.

## [1.12.4] - 2026-04-05

### Fixed

- **Issue #849:** Added `DriveTrashDiscovery._fetch_files_page(query, page_token)` and wired query discovery/streaming paths to the real implementation so non-ID discovery no longer crashes with `AttributeError`.
- Corrected validation output for HTTP 404 file-ID checks from `"Invalid file ID format"` to `"File IDs not found"`.
- Guarded streaming `stats["found"]` updates with `stats_lock` in both streaming item handlers to keep stats mutation consistent and thread-safe.
- Eliminated version drift by moving the authoritative module version to `gdrive_constants.VERSION` and importing it from both `gdrive_recover.py` and `gdrive_cli.py`.
- Updated unit coverage to exercise the real `_fetch_files_page()` path instead of mocking the method directly.
- Applied Black formatting to `gdrive_recover.py` so Python formatting checks pass in CI.

## [1.12.3] - 2026-04-01

### Changed

- **Refactor (Issue #791):** Extracted discovery and file-ID validation from `gdrive_recover.py` into a new `gdrive_discovery.py` module with `DriveTrashDiscovery`.
- `DriveTrashRecoveryTool` now delegates discovery calls (`discover_trashed_files`, streaming query/ID paths) to `DriveTrashDiscovery`.
- Added helper delegation for method reuse and cleaner module responsibilities.

## [1.12.2] - 2026-04-01

### Fixed

- **Issue #790 follow-up:** Restored backwards-compatible rate-limiter hooks on `DriveTrashRecoveryTool` after extraction to `gdrive_rate_limiter.py`.
- Reintroduced shim methods/attributes (`_rate_limit()`, `_rl_diag_tick()`, `_tb_initialized`, `_rl_diag_enabled`) that delegate to `self.rate_limiter`, preserving existing tests and internal call patterns.
- No pacing behavior changes; this patch only restores compatibility with the previous `DriveTrashRecoveryTool` internal interface.

## [1.12.1] - 2026-04-01

### Changed

- **Refactor (Issue #790):** Extracted rate-limiting logic from `DriveTrashRecoveryTool` into a new `gdrive_rate_limiter.py` module with a `RateLimiter` class.
- Moved token-bucket and fixed-interval pacing internals (`_should_use_token_bucket`, `_init_token_bucket`, `_refill_token_bucket`, `_can_consume_token`, `_consume_token`, `_token_deficit`, `_legacy_pacing`, `_token_bucket_sleep`, `_legacy_pacing_sleep`, `_rl_diag_tick`) out of `gdrive_recover.py`.
- `DriveTrashRecoveryTool.__init__` now creates `self.rate_limiter = RateLimiter(args, logger)`, and request execution delegates pacing via `self.rate_limiter.wait()`.
- No logic changes; token refill/sleep behavior, legacy pacing behavior, and `--rl-diagnostics` output are unchanged.

## [1.12.0] - 2026-04-01

### Changed

- **Refactor (Issue #789):** Extracted authentication logic from `DriveTrashRecoveryTool` into a new `gdrive_auth.py` module with a `DriveAuthManager` class.
- Moved `authenticate()`, `_load_creds_from_token()`, `_refresh_or_flow_creds()`, `_build_and_test_service()`, `_get_service()`, `_build_http()`, `_RequestsHttpAdapter`, and `_harden_token_permissions_windows()` out of `DriveTrashRecoveryTool`.
- `DriveTrashRecoveryTool.__init__` now creates `self.auth = DriveAuthManager(args, logger, execute_fn)` and all auth call sites delegate to `self.auth`.
- Auth-related instance fields (`_service`, `_creds`, `_thread_local`, `_client_per_thread`, `_http_transport`, `_http_pool_maxsize`, `_authenticated`, `_credentials_file`, `_token_file`) moved to `DriveAuthManager`.
- No logic changes; OAuth flow, token caching, HTTP transport, and Windows token hardening behaviour are unchanged.

## [1.11.2] - 2026-04-01

### Fixed

- **Issue #788 follow-up:** Restored error accounting when recovery state loading fails (for example malformed/unreadable state file). `RecoveryStateManager._load_state()` now triggers the tool-level error counter callback so execution summaries continue to reflect state-load failures.

## [1.11.1] - 2026-04-01

### Changed

- **Refactor (Issue #788):** Extracted state persistence and locking logic from `gdrive_recover.py` into a new `gdrive_state.py` module with `RecoveryStateManager`.
- `DriveTrashRecoveryTool` now delegates state lifecycle operations (`load/save`, lock acquire/release, processed-item tracking) through `self.state_manager`.
- Updated CLI lock helpers in `gdrive_cli.py` to use `tool.state_manager` for lock and PID liveness checks.
- Retained existing state schema, lock metadata format (`pid` / `run_id`), and atomic write behavior (`flush` + `fsync` + `os.replace`) with no intended functional change.

## [1.11.0] - 2026-03-31

### Changed

- **Refactor:** Extracted the CLI layer from `gdrive_recover.py` into a new module `gdrive_cli.py` (`create_parser()`, argument validation helpers, lock orchestration helpers, and `main()`).
- **Entrypoint:** `gdrive_recover.py` now delegates script execution to `gdrive_cli.main()` via a thin `if __name__ == "__main__"` shim.
- **Behavior:** No logic changes intended; this is a structural refactor to isolate CLI concerns from `DriveTrashRecoveryTool`.

## [1.10.0] - 2026-03-31

### Changed

- **Refactor:** Extracted all data model types (`FileMeta`, `LockInfo`, `RecoveryItem`, `RecoveryState`, `PostRestorePolicy`) from `gdrive_recover.py` into a new dedicated module `gdrive_models.py`. `gdrive_recover.py` now imports these from `gdrive_models`. No logic changes; existing behaviour is unchanged.

## [1.9.0] - 2026-03-29

### Changed

- **Refactor:** Extracted all static configuration constants and the `EXTENSION_MIME_TYPES` lookup table from `gdrive_recover.py` into a new dedicated module `gdrive_constants.py`. `gdrive_recover.py` now imports these from `gdrive_constants`. No logic changes; existing behaviour is unchanged.

## [1.8.3] - 2026-03-26

### Changed

- Added pointer to `CHANGELOG.md` in the module docstring of `gdrive_recover.py`.

## [1.8.2] - 2026-03-26

### Changed

- Moved embedded `CHANGELOG` block out of `gdrive_recover.py` into this `CHANGELOG.md` file. No logic changes.

## [1.8.1] - 2025-09-23

### Fixed

- **Streaming "found" double-counting:** In `recover-only` and `recover-and-download` modes we were pre-discovering items in `_prepare_recovery()` and then counting them again during streaming discovery. This inflated `Total files found` (e.g., `--limit 1` could show 2 found) and skewed the success rate.
  - Introduced `streaming_mode` flow in `_prepare_recovery(streaming_mode: bool)` that **skips pre-discovery** when streaming and resets `stats['found']`, `_seen_total`, and `_processed_total` so streaming is the single source of truth.
  - Updated `execute_recovery()` to pass `streaming_mode = (args.mode != 'dry_run')`.

### Impact

- Accurate `Total files found`, `Files recovered/downloaded`, and **Success rate** in streaming modes.
- `--limit` now cleanly caps **streamed** discovery without preloaded items leaking into counts.

### Notes

- No CLI or API changes; backward-compatible patch.
- Dry-run behavior unchanged (it still performs one-shot discovery and reports counts once).

## [1.8.0] - 2025-09-23

### Added

- **`--direct-download`**: New opt-in flag to stream file bytes **directly to the final filename**
  (no `.partial` and no final rename). This avoids destination-lock races from thumbnailers/AV/OneDrive.
  Trade-off: an unexpected interruption may leave a partially written file at its final path.

## [1.7.0–1.7.5] — 2025-09-22

### Highlights

- **Configurable credentials path** via `GDRT_CREDENTIALS_FILE`. Falls back to `credentials.json` if unset; paths with spaces are supported. Clearer startup error when missing/unreadable.
- **Windows/OneDrive lock resilience:** Added `_atomic_replace_with_retry()` to handle transient `WinError 32` during final `*.partial → final` rename, including cleanup of zero-byte stubs.

### Fixes & Robustness

- **Dry-run auth flow:** `dry_run()` now authenticates before any Drive calls, eliminating "Service not initialized" crashes.
- **Dry-run on Windows/Linux:** Guarded `args.download_dir` access with `getattr(..., None)` so `dry-run` and `recover-only` don't raise `AttributeError`.
- **OAuth bootstrap:** Avoid `'NoneType' object has no attribute 'to_json'` when credentials are missing; guarded writes and provide a helpful exit.
- **Token cache hardening:** Treat unreadable/corrupt `token.json` as a cache miss and trigger a fresh OAuth flow instead of crashing.
- **Windows path literals:** Marked long docstrings/argparse `epilog` as raw strings to prevent `unicodeescape` errors from `\U` in examples.

### Developer Experience & Messaging

- Clearer auth errors including resolved credential path.
- Improved error reporting in dry-run when auth fails (user-facing messages instead of stack traces).

### Docs & UX

- Added examples for setting `GDRT_CREDENTIALS_FILE` in PowerShell, CMD, and Bash.

### Notes

- Backward compatible; no CLI or API changes to existing commands/flags.
- `recover-and-download` behavior is unchanged except for added resilience during the final rename on Windows.
- For immediate mitigation of destination-lock issues without updating, pause OneDrive sync or download to a non-synced folder.
- No changes to token caching semantics (`token.json` still created/updated after first OAuth consent).

## [1.6.0–1.6.8] - 2025-09-21 → 2025-09-22

### Highlights

- **HTTP transport & pooling (opt-in):** New `--http-transport {auto|httplib2|requests}` and `--http-pool-maxsize` enable per-thread pooled `AuthorizedSession` when `requests` is available; otherwise gracefully falls back to `httplib2`. Added a lightweight requests→httplib2 shim exposing common attrs (`timeout`, `ca_certs`, `disable_ssl_certificate_validation`) and best-effort smoke tests (tiny `files.list` + `Range: bytes=0-0` media fetch) to validate the adapter path. Help text explains the pool sizing heuristic; docs clarify that performance gains vary by workload and environment.
- **Concurrent-run guardrails & locking:** State now carries a `run_id` and `owner_pid`; a lockfile prevents overlapping runs. Locking was hardened to **fail closed**, verify persisted metadata, and print PID liveness hints. Added `--lock-timeout <sec>` to wait for a held lock with polling, plus clearer messages for stale vs active locks and an explicit `--force` takeover path. Safer file writes (`flush` + `fsync`) reduce truncation risk.
- **Observability & parity checks:** Validation/discovery parity moved behind `--debug-parity`, emitting structured JSON metrics and optional `--parity-metrics-file`. `--fail-on-parity-mismatch` can enforce CI failure on mismatch. Logs are quieter by default (DEBUG instead of INFO) and wording was tightened ("Parity check …").
- **State compatibility:** Introduced `schema_version: 1` with tolerant loading—unknown JSON fields are ignored and missing fields defaulted. Legacy states (v0) emit a one-time note and are upgraded on next save.
- **Policy & validation UX:** Unknown `--post-restore-policy` values get a "did you mean …?" suggestion (Levenshtein ≤2) and structured telemetry for tracking. Most error/warning prints now go to **stderr**; `--no-emoji` offers ASCII output. Extension validator helpers gained clearer docstrings and return types.
- **Type-system cleanup (phase 1):** Tightened function signatures to eliminate easy `# type: ignore`s, introduced small `TypedDict` for Drive file metadata across discovery paths, and added a local `mypy.ini` (`warn_unused_ignores = True`) with a couple of `reveal_type` checks.
- **Requirements & docs:** Explicit Python **3.10+** requirement (PEP 604 unions) called out in headers/CLI epilog, including notes that apply to `validators.py`. Docs include commands to install requests transport support: `pip install requests google-auth[requests]`.

### Notes

- Pooling and rate behavior are workload-dependent; treat any throughput gains as directional.
- Default behavior is unchanged unless new flags are used; existing workflows continue to work.

## [1.5.x] - 2025-09-19 → 2025-09-21 (Consolidated)

- **Performance & Scale (1.5.9):** added docs with proven presets for `--process-batch-size`,
  `--max-rps`, `--burst`, concurrency heuristics, and client lifecycle tips.
- **Policy UX (1.5.8/1.5.2):** clear unknown-policy warnings (stderr + WARNING), repeat once in
  EXECUTION COMMAND preview; strict mode via `--strict-policy` or `GDRT_STRICT_POLICY=1`. Unknown
  tokens fall back to `trash` unless strict.
- **Extensions & Validators (1.5.7):** multi-segment extensions allowed; server-side MIME narrowing
  uses the last segment; pure validator functions moved to `validators.py` with type hints.
- **Streaming & Memory (1.5.6):** rolling batches via `--process-batch-size` bound memory; stable
  RSS on large runs (e.g., 200k items at N=500).
- **Throughput & Safety (1.5.5):** limiter now monotonic-time based with short lock sections;
  diagnostics via `--rl-diagnostics` to validate observed RPS (±10%).
- **Safety & Hotfixes (1.5.4):** client-per-thread on by default, atomic state writes + advisory
  locks, partial downloads, better progress cadence.
- **Usability (1.5.3):** validation chain short-circuits, better no-command UX, quieter discovery.
- **Foundations (1.5.1/1.5.0):** baseline rate limiting, streaming downloads, `--limit` canaries;
  policy normalization (`retain|trash|delete`) with aliases and simplified service internals.
