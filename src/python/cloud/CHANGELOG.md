# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.26.2] - 2026-05-23

### Removed

- **Dead discovery helpers removed from `gdrive_discovery.py`:** Six private methods that were never reached in production have been deleted: `_extract_status_from_http_error`, `_log_terminal_id_validation_error`, `_handle_prefetch_error`, `_log_fetch_metadata_retry`, `_format_fetch_metadata_error_with_context`, and `_fetch_file_metadata`. All were leftovers from the migration to the shared `with_retries` helper; error classification and metadata fetching are handled entirely by `_fetch_and_handle_metadata` via `with_retries`. `_handle_discover_id_result` is also removed — it had no caller anywhere.
- **Unused `_last_discover_progress_ts` attribute removed from `gdrive_recover.py`:** The attribute was declared in `DriveTrashRecoveryTool.__init__` but never read or written after discovery was extracted to `DriveTrashDiscovery` (which owns its own copy). No behavioural change.
- **`HttpError` and `MAX_RETRIES` imports dropped from `gdrive_discovery.py`:** Both imports became unused once the dead helpers above were removed.
- **Unit tests for the removed helpers deleted:** `test_handle_prefetch_error_retry_and_terminal`, `test_fetch_file_metadata_error_path`, and `test_error_formatting_and_status_extract` in `test_gdrive_recover.py` existed solely to exercise the deleted methods. Error-classification behaviour is already covered by `test_gdrive_discovery_retry_classification.py` via `_fetch_and_handle_metadata`.

## [1.26.1] - 2026-05-23

### Fixed

- **Streaming ID path now skips prefetch-cached errors and non-trashed IDs:** `_stream_stream_ids` previously ignored `_id_prefetch_errors` and `_id_prefetch_non_trashed`, causing IDs already known to be 404/403 to be re-fetched (wasted API calls, duplicated error logging) and non-trashed IDs to potentially leak through. The streaming path now mirrors the batch path (`_discover_via_ids`) by consulting both caches before attempting a live fetch.
- **Streaming ID failures now surface `ok=False`:** `_stream_stream_ids` always returned `True` even when `_handle_streaming_id_fetch` recorded errors. The method now returns `False` whenever a prefetch-cached error is replayed or a live fetch fails, consistent with `_stream_stream_query` and `_stream_stream_folder`.
- **`_discover_via_query` retains partial results on pagination error:** An exception during query pagination previously discarded all items collected from earlier pages (`return []`). The method now returns whatever items were gathered before the failure, matching the folder traversal path's behaviour.
- **Size parsing hardened against `null` values:** `_process_file_data` used `int(file_data.get("size", 0))`, which raises `TypeError` if the API returns `"size": null` (possible for Google-native files). Changed to `int(file_data.get("size") or 0)`.
- **Parity metrics file written with explicit UTF-8 encoding:** `_emit_parity_metrics` now passes `encoding="utf-8"` to `open()` to avoid platform-dependent encoding on Windows.
- **Time filter exception handling narrowed:** `_matches_time_filter` caught bare `Exception`, masking programmer errors. Narrowed to `(ValueError, TypeError, OverflowError)` — the only exceptions that `dateutil.parser.parse` and timezone arithmetic can legitimately raise. Fail-open behaviour (include the file) is preserved.

## [1.26.0] - 2026-05-17

### Added

- **`--timestamped-output` flag:** Inserts a per-run timestamp (`YYYYMMDD_HHMMSS_ffffff`, local time, microsecond precision) before the final extension of both `--log-file` and `--failed-file` paths, giving each run its own files without requiring explicit unique names.
  - Accepted by `dry-run`, `recover-only`, and `recover-and-download`.
  - Path transformation: `run.log` → `run_20260517_142530_123456.log`; `logs/failed.csv` → `logs/failed_20260517_142530_123456.csv`; extension-less names have the suffix appended; disabled (empty) paths are left untouched.
  - Microsecond precision prevents collisions between rapid sequential or parallel runs sharing the same base paths.
  - Applied once in `gdrive_cli.main` via the new `_apply_timestamped_output` helper, before failed-file validation and before `DriveTrashRecoveryTool` construction, so every downstream consumer sees the final path; log file and failed-file share the same timestamp for easy correlation.
  - Independent of `--fresh-run`: `--timestamped-output` routes each run to a *new* file; `--fresh-run` truncates the *configured* file in place.

## [1.25.0] - 2026-05-14

### Added

- **`--skip-existing` flag for `recover-and-download`:** Skips the download when the computed local target path already resolves to a regular file.
  - The item is still treated as a logical success: per-step state advances, post-restore policy still applied, and the skip is counted in a new `stats["skipped_existing"]` counter.
  - Uses `Path.is_file()` rather than `exists()` so a directory collision does not silently satisfy the skip and allow `post-restore-policy=delete` to remove the Drive file without a local copy.
  - Mutually exclusive with `--overwrite`; default collision behaviour (uuid-rename suffix) is unchanged when neither flag is set.
  - Run summary and structured log line include `skipped_existing` when non-zero.

## [1.24.1] - 2026-05-14

### Removed

- **`--download-dir` removed from `recover-only`:** The argument was accepted by the parser but had no effect, silently discarding any supplied path instead of warning the user.
  - `will_download` is set to `True` only for `recover-and-download` (or `dry-run` with `--download-dir`), never for `recover-only`.
  - The argument is now rejected by the `recover-only` subparser; it remains optional on `dry-run` and required on `recover-and-download`.

## [1.24.0] - 2026-05-14

### Added

- **Per-item step records with v2 → v3 schema migration (#1030):** `processed_items` promoted from `List[str]` (O(n) membership) to `Dict[str, ProcessedRecord]` (O(1) membership), where each record tracks three boolean steps and a timestamp.
  - `_process_item` calls `_mark_step(item_id, step)` after each individual pipeline step succeeds; an interrupted run that completed untrash but not download will skip the untrash API call on resume and retry only the download.
  - `_recover_file` checks `_step_is_done(item_id, "recovered")` and skips the `files.update(trashed=False)` call when the untrash step is already recorded, preventing redundant API calls.
  - `_is_processed(item)` now takes the full `RecoveryItem` to determine which steps are required (e.g. `recovered` only for recover-only; `recovered + downloaded + post_restored` for recover-and-download; `downloaded + post_restored` for folder-id / retry-failed-file items where `will_recover=False`).
  - New `_required_steps(item)` helper encapsulates step-requirement logic; `_step_is_done(item_id, step)` exposes individual step checks.
  - `_mark_step` serialises mutations with an internal `_state_lock`; callers must not hold `stats_lock` when calling it (see `gdrive_state.py` module docstring).
- **New `ProcessedRecord` dataclass** in `gdrive_models.py`: fields `recovered`, `downloaded`, `post_restored` (bool, default `False`) and `last_attempt_iso` (str).

### Changed

- **`RecoveryState.schema_version` default is now 3.** New state files are written at v3 immediately.
- **`RecoveryState.processed_items` type changed** from `Optional[List[str]]` to `Optional[Dict[str, ProcessedRecord]]`; `__post_init__` initialises to `{}`.
- **`_mark_processed(item_id)` is now a backward-compat wrapper** that marks all three steps as done; new code uses `_mark_step` per step.

### Migration

- **v2 → v3 is automatic and non-destructive.** On first load of a v2 state file, every ID in `processed_items` is converted to `ProcessedRecord(recovered=True, downloaded=True, post_restored=True)` — all steps treated as fully complete, so no item is reprocessed.
- **v0/v1 → v3 chained migration** works in a single load: the v1 → v2 scope-synthesis step runs first, then the v2 → v3 list-to-dict conversion.
- **Migration is one-way.** Keep a copy of your state file before running v1.24.0 for the first time if rollback is needed. To retry previously-failed items use `--retry-failed-file <csv>` or `--fresh-run`.

## [1.23.3] - 2026-05-14

### Fixed

- **Final streaming progress line no longer reports a stale `processed=` count.** `ProgressBar.update` throttles redraws by time interval and `close()` only emitted a newline, so the last visible progress line could be off by up to one batch from the true totals.
  - `DriveTrashRecoveryTool._process_streaming` now calls a new `_print_final_stream_progress` helper just before `_print_summary` (and before `print_interrupted_state_saved` on Ctrl-C).
  - The helper calls `ProgressBar.update(..., force=True)` to bypass the throttle and render the true final counts.

## [1.23.2] - 2026-05-14

### Added

- **End-of-run summary written to the log file as a structured INFO line.** `RecoveryReporter._print_summary` previously used bare `print()` calls, leaving the log file without a record of how the run concluded.
  - Emits a single grep-friendly `Run complete: mode=… found=… recovered=… downloaded=… skipped=… errors=… elapsed=…s success_rate=…%` line at INFO level alongside the stdout summary box.
  - `print_interrupted_state_saved` mirrors this with a `Run interrupted: …` line so interrupted runs are also unambiguously recorded.
  - Logger errors are swallowed so a misbehaving handler cannot break the user-facing summary.

## [1.23.1] - 2026-05-14

### Fixed

- **Resume-mode summary no longer reports zero skipped items.** `DriveOperations._process_item` short-circuited via `_is_processed` without bumping `stats["skipped"]`; in folder-id mode and `--retry-failed-file` mode (`will_recover=False`), `_recover_file` is never invoked, so a full-resume run produced `Files downloaded: 0`, `Files skipped: 0`, and `Errors encountered: 0` despite processing tens of thousands of items.
  - The short-circuit now bumps `stats["skipped"]` under `stats_lock` so the summary truthfully reflects how many items were already in the state file.
  - Trash-recover mode was unaffected because a redundant `_is_processed` check inside `_recover_file` happened to increment the counter; the missing increment was in `_process_item`.

## [1.23.0] - 2026-05-14

### Added

- **Scope-aware state file with v1→v2 schema migration (#1029):** State files now record a `scope` block (`source`, `command`, `key`) capturing what the run was doing.
  - `source` is one of `trash_query | folder_id | file_ids | retry_failed_file`; `command` is `recover_only | recover_and_download`; `key` is a discriminating fingerprint — the raw folder ID for `folder_id`, the absolute CSV path for `retry_failed_file`, or a 16-char sha256 prefix over the file IDs / trash-query parameters for `file_ids` / `trash_query`.
  - On load, scope is compared to the current invocation; a mismatch causes the tool to exit with code 2 unless `--fresh-run` is passed — closing the silent failure where a `recover-only` state file was reused by `recover-and-download` and caused the same IDs to be skipped without being downloaded.
  - CLI renders a clear remediation message on mismatch: saved scope, current scope, and a suggestion to pass `--fresh-run` or `--state-file <path>`.
  - New `RecoveryStateScope` dataclass in `gdrive_models.py`; new `StateScopeMismatchError` exception in `gdrive_state.py`; new `RecoveryStateManager._derive_scope_from_args` helper.

### Changed

- **`RecoveryState.schema_version` default is now 2.** v0/v1 state files synthesize a scope from the current invocation and are rewritten as v2 on next save; `processed_items` preserved verbatim.
- **`RecoveryState.owner_pid` removed.** The lock file remains the source of truth for the live PID; the stale field is retired. v1 files containing `owner_pid` load fine — the unknown field is silently dropped.
- **`state.total_found` updated from `_seen_total` in streaming mode** at each periodic save and on completion/interruption.
- **`--overwrite` deprecation shim removed (per v1.22.0 timing).** `--overwrite` is now strictly a local-file collision policy: it no longer clears `processed_items`, truncates the failed-file CSV, or emits a deprecation warning. Use `--fresh-run` for fresh-run effects.
- `RecoveryStateManager._clear_processed_items` removed; `_reset_state` is the canonical fresh-run primitive.
- `--fresh-run` help text updated: scope reset mentioned, `owner_pid` no longer referenced.
- Module docstring (`gdrive_recover.py`) and README updated with scope semantics and v1 → v2 migration behaviour.

### Migration

- **v1 → v2 is automatic and non-destructive.** Existing v1 state files load on first run after the upgrade; the synthesized scope reflects the current invocation. A subsequent run with the same scope resumes normally; a different scope is rejected with a clear message instead of silently skipping work.

## [1.22.0] - 2026-05-14

### Added

- **`--fresh-run` flag (#1028):** Ignores prior progress in the state file, regenerates run identity (`run_id`, `start_time`, `owner_pid`), and (if `--failed-file` is set) truncates the failed-file CSV before the run starts.
  - Available on both `recover-only` and `recover-and-download`.
  - Mutually exclusive with `--retry-failed-file`: fresh-run starts from nothing; retry resumes a specific list.
  - Implemented via `RecoveryStateManager._reset_state`, which replaces the in-memory state with a fresh `RecoveryState` (preserving only `schema_version`); every "if not X" guard in `_initialize_recovery_state` naturally regenerates identity fields.

### Changed

- **`--overwrite` narrowed to local-file collision policy only.** State reset and failed-file truncation are now `--fresh-run`'s responsibility.
  - For this release, the old combined behaviour is preserved as a **deprecation shim**: `--overwrite` alone still clears `processed_items` and truncates the failed-file CSV, but prints a deprecation warning to stderr naming v1.23.0 as the removal target.
  - `--overwrite --fresh-run` combination: both effects apply; no deprecation warning is printed.
  - `DriveOperations._recover_file` and `_process_item` no longer reference `args.overwrite` for the `_is_processed` short-circuit; the shim achieves the same effect via `_clear_processed_items`.
  - CLI epilog, `--failed-file` help text, and `--overwrite` help text updated to describe the new split.

### Deprecated

- **Combined "clear state + truncate failed-file" behaviour of `--overwrite`.** Continues to work in this release with a stderr warning. Migrate to `--fresh-run` (alone or combined with `--overwrite`) before v1.23.0.

## [1.21.2] - 2026-05-14

### Fixed

- **Failed items are no longer marked as processed in the state file (#1027).** `DriveOperations._process_item` previously called `_mark_processed(item.id)` unconditionally; failed items ended up in both `--failed-file` and `state.processed_items`, causing them to be silently skipped on rerun and defeating resume.
  - The mark-processed call is now made only on full success.
  - Failed items continue to be appended to `--failed-file` and are reattempted on the next rerun against the same state file.
  - Module docstring (`gdrive_recover.py`) and README updated to describe the corrected resume semantics; `processed_items` is now documented as the count of **successfully** processed items.
  - Entries written under the old semantics may include IDs of previously-failed items that will still be skipped on rerun. To retry them use `--retry-failed-file` (if the failed-file CSV is available) or trim the state file manually.

## [1.21.1] - 2026-05-14

### Fixed

- **`--retry-failed-file` now sets `will_recover=False` for all retried items:** Files in the failed-file CSV are already live in Drive; previously they inherited `will_recover=True` and triggered a redundant `files.update(trashed=False)` call. A new `_retry_mode` flag on `args` tells `_process_file_data` to skip the recover step.
- **`--retry-failed-file` no longer falls back to a full trash query when the CSV has no actionable rows:** `main()` now exits with code 1 and a clear message instead of continuing with an empty `args.file_ids` list and discovering all trashed files.
- **Trash-prefetch validation skipped in retry mode:** `_validate_file_ids_if_present` is a no-op when `_retry_mode` is set, preventing "skipped_non_trashed" misclassification of already-live files.
- **`--failed-file` and `--retry-failed-file` cannot point to the same path:** A new check in `_validate_retry_failed_file_arg` rejects this combination with an informative error message.
- **Removed unused `import io`** from `gdrive_operations.py`.

## [1.21.0] - 2026-05-14

> **Breaking change for `--failed-file` consumers:** The output is now CSV, not plain text. Update any scripts that read it line-by-line to use a CSV reader; the `target_path` column contains the same value as the previous plain-text entry.

### Added

- **CSV failed-file output (`--failed-file`):** The file written by `--failed-file` is now a proper CSV. Each row contains three columns: `source_folder_id` (Drive ID of the parent folder), `file_id` (stable Drive file ID, suitable for retry), and `target_path` (full local path where the file was or would be saved).
  - A header row is written automatically on the first entry of each run; when `--overwrite` truncates the file the header is written immediately so the file is always a valid CSV.
  - `source_folder_id` is populated from the `parents` field returned by the Drive API for all discovery modes (trash query, `--file-ids`, and `--folder-id` BFS traversal).

- **`--retry-failed-file <csv>` for `recover-and-download`:** Accepts a CSV produced by `--failed-file` and retries only the file IDs it contains, restoring each to its original target path.
  - Mutually exclusive with `--file-ids` and `--folder-id`; validation rejects missing files, directories, and conflicting flags.
  - Sets `will_recover=False`; issues download-only requests. If a file was moved back to trash between the original run and the retry, the download will fail with HTTP 403/404 and be recorded in the (new) `--failed-file` if one is supplied.

- **`source_folder_id` field on `RecoveryItem`:** Populated at discovery time with the first element of the Drive `parents` array.

- **`parents` requested from Drive API in all discovery modes:** `_id_discovery_fields()` now unconditionally includes `parents`.

### Changed

- `DriveOperations._write_failed_file` rewritten to use `csv.writer`; writes a header row when the destination file is new or empty.
- `DriveOperations._clear_failed_files` writes the CSV header row (instead of an empty file) so the cleared file remains a valid CSV.
- `DriveTrashRecoveryTool._generate_target_path` checks `args._target_path_overrides` (populated from the retry CSV) before computing a new path, ensuring retried files land exactly where the original run intended.
- Module docstring and CLI epilog updated with retry examples and CSV file extension.

## [1.20.2] - 2026-05-12

### Changed

- **Increased new-code coverage to ≥ 80 %** (74.2 % → ≥ 80 %): added targeted tests to close gaps identified by SonarCloud.
  - `test_gdrive_operations.py`: 9 new tests covering `_do_post_restore_action` (`deleted` action and unknown-action fallback), `_log_post_restore_success` (`deleted` branch), `_handle_post_restore_retry`, `_extract_http_error_detail` (no-separator path), `_log_post_restore_final_error`, `_apply_post_restore_policy` non-terminal-error path (HTTP 5xx), and `_process_item` download-failure path.
  - `test_gdrive_cli_folder_id.py`: 7 new tests covering empty input, valid path with parent-dir creation, existing file, directory-rejection, and `--failed-file` argument acceptance on all three subcommands.

## [1.20.1] - 2026-05-12

### Fixed

- **Post-restore failures now propagate into item failure state.** `_process_item` discarded the return value of `_apply_post_restore_policy`, so a failed trash or delete API call left `success = True`.
  - Items whose post-restore action failed were not written to `--failed-file` and not counted as errors, making retry lists incomplete.
  - The return value is now folded into `success`; a post-restore failure marks the item as failed and triggers `_write_failed_file`.

## [1.20.0] - 2026-05-12

### Added

- **Optional log file (`--log-file`):** Attaches a `FileHandler` at `DEBUG` level when supplied, capturing every per-operation message regardless of console verbosity (`-v` / `-vv`).
  - Previously a log file was always written to `gdrive_recovery.log` at the same level as the console; now the default is no file logging.
  - The file and any missing parent directories are created automatically.

- **Failed-file log (`--failed-file`):** Appends the full local path (or Drive file name for recover-only operations) of every failed item to a file as soon as the failure is detected.
  - Accepted by all three subcommands (`dry-run`, `recover-only`, `recover-and-download`).
  - The file and any missing parent directories are created automatically.
  - When `--overwrite` is active the file is truncated to zero bytes before processing begins.

- **`DEFAULT_FAILED_FILE = ""`** constant added to `gdrive_constants.py`.

### Changed

- `DEFAULT_LOG_FILE` in `gdrive_constants.py` changed from `"gdrive_recovery.log"` to `""` (disabled by default). Existing workflows that relied on automatic log-file creation must now pass `--log-file gdrive_recovery.log` explicitly.
- `DriveTrashRecoveryTool._setup_logging` rewritten to use explicit handler objects, allowing the console and file handlers to carry independent log levels; file handler (when enabled) is always `DEBUG`.
- `DriveOperations.__init__` acquires `failed_file` from `args` and stores a dedicated `threading.Lock` for thread-safe writes.
- `--failed-file` path is appended to on every non-overwrite run; pass `--overwrite` to start fresh on each run.

## [1.19.0] - 2026-05-12

### Added

- **Progress bar for recovery and download operations:** New `ProgressBar` class in `gdrive_report.py` renders an animated in-place progress bar during streaming execution and batch processing.
  - **TTY (interactive terminal):** Overwrites the current line via carriage-return, updating every 0.5 s.
    - Known total (e.g. `--file-ids`): `[████████░░░░░░░░░░░░] 400/1000 (40.0%) │ 5.2/sec │ ETA: 115s`
    - Streaming (unknown total): `▶ processed=800 discovered=1234 │ 5.2/sec`
  - **Non-TTY (CI / log files):** Plain text line written at most every 10 s when `--verbose` (`-v`) is active, preserving the previous behaviour and keeping log files tidy.
  - **`--no-emoji` compatibility:** Unicode block characters (`█░▶│`) replaced with ASCII equivalents (`#->`).
  - `RecoveryReporter` gains `_start_progress(total)`, `_close_progress()`, and `_should_show_progress()` helpers; the bar is started in `print_streaming_start` / `print_processing_start` and finalised in `_print_summary` and `print_interrupted_state_saved`.
  - The `verbose >= 1` guard in `_handle_item_result_stream` and `_handle_item_result` is replaced with `reporter._should_show_progress()` so the bar appears on TTY without requiring `-v`.

## [1.18.x] - 2026-05-12/13 (Consolidated)

### Added

- **Folder-scoped download (`--folder-id`):** New argument for all three subcommands. Scopes discovery to a specific Google Drive folder via BFS traversal; targets non-trashed, live files (`will_recover=False`); reconstructs the full subfolder hierarchy under `--download-dir`. Added `_fetch_folder_page`, `_discover_folder_recursively`, and `_stream_stream_folder` to `DriveTrashDiscovery`; `relative_path` field on `RecoveryItem`; `FOLDER_MIME_TYPE` constant in `gdrive_constants.py`. Prints a warning when combined with the default `trash` post-restore policy. Recommended usage: `recover-and-download --folder-id <id> --download-dir <path> --post-restore-policy retain`.
- **Comprehensive usage examples:** `gdrive_recover.py` docstring, `gdrive_cli.py` epilog, and `README.md` expanded with full scenario coverage (dry-run, recover-only, recover-and-download, folder-scoped, extension filtering, performance presets, locking, automation).
- **`--overwrite` flag (`recover-and-download`):** Replaces existing local files instead of appending a `_<hex6>` suffix. *(Superseded by the `--fresh-run` redesign in [1.22.0]–[1.23.0]; retained here for history only.)*

### Fixed

- **`gdrive_validators.py` extracted:** Resolved `ModuleNotFoundError` caused by `gdrive_cli.py` importing from a bare `validators` module in a sibling directory; gdrive-specific validators now live in `gdrive_validators.py` co-located in `cloud/`.
- **Dry-run correctness:** `--download-dir` now accepted by `dry-run` and `recover-only`; dry-run no longer writes to disk when `--download-dir` is passed; execution-command generation corrected to emit the actual subcommand (`recover-and-download` or `recover-only`) instead of always `dry-run`; `--folder-id` now included in generated commands.
- **WinError 32 on `.partial` → final rename:** `_atomic_replace_with_retry` moved to after the `with open(partial, "wb")` block so no open handle blocks the rename on Windows.
- **Download refactor + tests:** `_download_file` split into `_download_direct` / `_download_via_partial`; four unit-test cases added covering failure paths and OSError branches.
- **State-save robustness:** `os.makedirs(..., exist_ok=True)` added before `open()` in `_save_state` so missing state-file parent directories are created automatically.
- **Mode-aware success rate:** `recover-and-download` now reports **Download success rate** (`downloaded / found`) so `--folder-id` runs no longer show 0 % despite successful downloads.
- **Windows token/permission hardening (2026-05-12/13):** Token writes now use `tempfile.mkstemp` + `os.replace()` (`MoveFileExW`) to avoid `ERROR_ACCESS_DENIED` on hidden `token.json`; distinct `PermissionError` log messages emitted for read vs. write failures; `PermissionError` re-raised from `_load_creds_from_token` instead of silently swallowed.
- **`--overwrite` skip behaviour:** `_process_item` and `_recover_file` honour `--overwrite` when skipping already-processed items; `_prepare_recovery` calls `_clear_processed_items()` on startup. *(Superseded by [1.22.0]–[1.23.0]; retained here for history only.)*

## [1.9.0] – [1.17.0] - 2026-03-29 → 2026-04-11 (Consolidated)

### Module extraction refactor (Issues #789–#856)

The primary extraction releases are structural refactors with no intended
behaviour changes; follow-up patches (listed below) include targeted runtime fixes.

- **Constants/models extracted** — `gdrive_constants.py`, `gdrive_models.py` (`[1.9.0]`, `[1.10.0]`).
- **CLI layer extracted** — `gdrive_cli.py` with `create_parser()`/`main()`; `gdrive_recover.py` reduced to a shim (`[1.11.0]`).
- **State + locking extracted** — `gdrive_state.py` / `RecoveryStateManager` (`[1.11.1]`).
- **Auth extracted** — `gdrive_auth.py` / `DriveAuthManager` (`[1.12.0]`).
- **Rate limiting extracted** — `gdrive_rate_limiter.py` / `RateLimiter` (`[1.12.1]`).
- **Discovery extracted** — `gdrive_discovery.py` / `DriveTrashDiscovery`; `__getattr__` coupling eliminated (`[1.12.3]`, `[1.13.0]`).
- **Download extracted** — `gdrive_download.py` / `DriveDownloader` (`[1.14.0]`).
- **Operations + shared retry extracted** — `gdrive_operations.py` / `DriveOperations`, `gdrive_retry.py` / `with_retries(...)` (`[1.15.0]`).
- **Reporting + privilege checks extracted** — `gdrive_report.py` / `RecoveryReporter`, `gdrive_privileges.py` / `DrivePrivilegeChecker`; `--no-emoji` completed (`[1.16.0]`, `[1.17.0]`).
- Plus follow-up patches restoring back-compat shims, error-accounting fixes, retry/error-classification hardening, cognitive-complexity reductions, and Black/CI formatting fixes (`[1.11.2]`, `[1.12.2]`, `[1.12.4]`, `[1.12.5]`, `[1.12.6]`, `[1.12.7]`, `[1.15.1]`, `[1.15.2]`, `[1.15.3]`, `[1.15.4]`).

See #789–#856 for issue-by-issue detail.

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
