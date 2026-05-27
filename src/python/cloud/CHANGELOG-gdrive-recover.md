# CHANGELOG — Google Drive Trash Recovery Tool

All notable changes to the **Google Drive Trash Recovery tool** (`gdrive_*` module family) are
documented in this file. The authoritative version is defined in `gdrive_constants.py`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **SemVer note (historical):** A small subset of pre-2.0 releases documented breaking behavior under a minor-version bump. Under SemVer 2.0 this is only expected before `1.0.0`; for `1.x` lines, breaking changes should increment the major version. Known historical exceptions retained as-published are `1.20.0` (default `--log-file` behavior changed), `1.21.0` (`--failed-file` format changed plain text → CSV), and one-way state-schema migrations in `1.23.0` (v1→v2) and `1.24.0` (v2→v3).

> **Out of scope:** `cloudconvert_utils.py`, `drive_space_monitor.py`, and
> `google_drive_root_files_delete.py` are sibling scripts in this directory that are currently
> unversioned and not covered by this changelog.

## [1.26.13] - 2026-05-27

### Changed

- `gdrive_discovery.py`: unified duplicated folder BFS traversal into a shared `_bfs_traverse_folders` helper used by both batch discovery (`_discover_folder_recursively`) and streaming discovery (`_stream_stream_folder`), keeping queue/prefix semantics aligned across paths.

### Tests

- Re-ran folder discovery unit coverage to validate both batch and streaming folder traversal flows after BFS unification.

## [1.26.12] - 2026-05-27

### Fixed

- `gdrive_query_filters.py`: restored full-suffix client-side extension matching for multi-segment tokens (e.g., `tar.gz`) so `--extensions tar.gz` no longer matches unrelated `*.gz` files.
- `gdrive_query_filters.py`: split extension normalization responsibilities into a full-token normalizer for filename filtering and a last-segment normalizer for server-side MIME query narrowing.

### Tests

- Expanded `tests/python/unit/test_gdrive_query_filters.py` with explicit multi-segment suffix assertions (`archive.tar.gz` matches `tar.gz`; `archive.gz` does not).

## [1.26.11] - 2026-05-27

### Changed

- `gdrive_discovery.py`: extracted query and filter composition into a dedicated `gdrive_query_filters.py` module so discovery orchestration stays focused on paging and item processing.
- `gdrive_query_filters.py`: added focused helpers for extension normalization, MIME predicate generation, query assembly, and extension/time-match checks; list-comprehension based MIME condition building reduces intermediate mutation overhead in hot-path query construction.

### Tests

- Added `tests/python/unit/test_gdrive_query_filters.py` to cover query assembly and filter helper behavior.

## [1.26.10] - 2026-05-24

### Changed

- `gdrive_constants.py`: extracted the argparse help epilog (~66 lines of static example/usage text) from `create_parser()` into a new module-level constant `HELP_EPILOG`; `create_parser()` now references it via `epilog=HELP_EPILOG`. `%(prog)s` substitution is unaffected. `--help` output is byte-for-byte identical to before.
- `gdrive_cli.py`: `_validate_concurrency_arg` now routes its invalid-value error and its concurrency-cap warning to stderr (`file=sys.stderr`), consistent with every other validator in the module.
- `gdrive_cli.py`: collapsed duplicate "nothing to retry" messaging — `_load_retry_failed_file` no longer emits a warning when the retry CSV has no actionable rows; the single authoritative error message is now only in `_apply_retry_failed_file`, which also owns the non-zero exit code for that condition.
- `gdrive_cli.py`: `_acquire_or_bypass_lock` now uses the idiomatic `remaining.is_integer()` instead of `int(remaining) == remaining` to decide between whole-second and fractional lock-wait countdown formatting.

## [1.26.9] - 2026-05-24

### Changed

- `gdrive_cli.py`: deleted the three module-level symbol helpers `_sym_fail`, `_sym_warn`, `_sym_info` (and `_use_emoji`) in favour of `ConsoleHelper` from `gdrive_console.py`; all former call sites now construct `ConsoleHelper(args)` locally.
- `gdrive_cli.py`: fixed four locations that were printing hard-coded `"ERROR"` / `"WARN"` ASCII strings regardless of `--no-emoji`: the concurrency-cap warning in `_validate_concurrency_arg`, the lockfile-contention error and `--force` warnings in `_print_lockfile_messages`, and the empty-retry-CSV warning in `_load_retry_failed_file`. All messages now route through `ConsoleHelper` and honour `--no-emoji`.
- `gdrive_cli.py`: moved the `--folder-id` + `trash` post-restore-policy warning from `main()` into `_validate_folder_id_args`, co-locating all folder-ID constraint checks in one function and removing the last direct console-symbol logic from `main()`.
- `gdrive_cli.py`: `_load_retry_failed_file` now accepts an `args` parameter so it can construct `ConsoleHelper` for symbol-consistent output; call site in `_apply_retry_failed_file` updated accordingly.

## [1.26.8] - 2026-05-24

### Fixed

- Restored default execution-path import compatibility for `gdrive_cli.py` when run via `python gdrive_recover.py ...` from `src/python/cloud` by adding `src/python` to `sys.path` before importing `modules.utils.file_operations`; this prevents `ModuleNotFoundError` during module import in the documented workflow.

### Tests

- Expanded unit coverage for CLI path validation by adding focused tests for `_validate_download_dir_arg` (happy path, non-directory rejection, non-writable rejection, and utility-failure handling) plus an error-path test for `_validate_failed_file_arg`.

## [1.26.7] - 2026-05-24

### Changed

- `gdrive_cli.py` now uses shared file/path utilities from `modules.utils.file_operations` for path validation setup (`ensure_directory`, `is_writable`) instead of maintaining ad-hoc inline write-probe logic for CLI path arguments.

## [1.26.6] - 2026-05-24

### Changed

- Standardised consolidated/range release headings to a single convention (`[a.b.c–x.y.z]` for ranges, `(consolidated)` suffix for rollups) for consistency across the gdrive changelog.
- Moved the long in-module usage examples out of `gdrive_recover.py` into `docs/gdrive-recover-usage.md`; the module docstring now links to the dedicated docs page.

### Fixed

- **Stale-lock detection branches now reachable:** `_check_pid_alive` previously set `pid_alive_note` to a string containing `"may not be running"` rather than `"(not running)"`, so the substring check in `_print_lockfile_messages` was always `False`. The note is now `" (not running)"`, making both the stale-lock hint (no `--force`) and the stale-lock takeover warning (`--force`) reachable for the first time.
- **`_run_and_release_lock` now dispatches all commands through `_run_tool`:** The previous if/else called `_run_tool` only for `dry-run` and called `tool.execute_recovery()` directly for all other commands, duplicating dispatch logic. Replaced with a single unconditional `ran_ok = _run_tool(tool, args)` call so future dispatch changes only need to be made in one place.
- **Removed overbroad `except Exception: pass` in `_acquire_or_bypass_lock`:** The entire lock-acquisition body was silently swallowing all exceptions (e.g. filesystem errors on the state-file path), causing the tool to proceed as if it held the lock. The outer try/except has been removed so real errors surface rather than being hidden.

## [1.26.2–1.26.5] - 2026-05-24 (consolidated)

### Changed

- Refactor churn across 1.26.2–1.26.5 is now documented as one consolidated maintenance band: unreachable helpers removed, ID prefetch internals extracted into `IdMetadataPrefetcher`, and console symbol/print helpers deduplicated into shared `ConsoleHelper` (`gdrive_console.py`); no intended user-visible behaviour change.
- Standardized `gdrive_discovery`/`gdrive_id_prefetch` compatibility accessors and delegation seams after the prefetch extraction so discovery and streaming `--file-ids` paths continue to share cached metadata/error/non-trashed decisions.

### Fixed

- Repaired post-refactor ID-prefetch cache reads in discovery/streaming `--file-ids` flows by removing invalid nested prefetch dereferences and restoring compatibility fields (`_id_prefetch`, `_id_prefetch_non_trashed`, `_id_prefetch_errors`), preventing `AttributeError` when replaying cached outcomes.
- Removed duplicated legacy method definitions accidentally retained in `gdrive_discovery.py` (`_fetch_and_handle_metadata`, `_prefetch_ids_metadata`), eliminating `function-redefined` lint failures and keeping a single delegated implementation path.
- Removed the unused `skipped_non_trashed` argument from the compatibility `_fetch_and_handle_metadata` wrapper to align the signature with actual call sites.

### Tests

- Expanded and reformatted targeted unit coverage for `gdrive_id_prefetch.py` and discovery parity/classification flows; focused coverage for the paired test run increased from 61% to 66% (+5 points).

## [1.26.1] - 2026-05-23

### Fixed

- **Streaming ID path now skips prefetch-cached errors and non-trashed IDs:** `_stream_stream_ids` previously ignored `_id_prefetch_errors` and `_id_prefetch_non_trashed`, causing IDs already known to be 404/403 to be re-fetched (wasted API calls, duplicated error logging) and non-trashed IDs to potentially leak through. The streaming path now mirrors the batch path (`_discover_via_ids`) by consulting both caches before attempting a live fetch.
- **Streaming ID failures now surface `ok=False`:** `_stream_stream_ids` always returned `True` even when `_handle_streaming_id_fetch` recorded errors. The method now returns `False` whenever a prefetch-cached error is replayed or a live fetch fails, consistent with `_stream_stream_query` and `_stream_stream_folder`.
- **`_discover_via_query` retains partial results on pagination error:** An exception during query pagination previously discarded all items collected from earlier pages (`return []`). The method now returns whatever items were gathered before the failure, matching the folder traversal path's behaviour.
- **Size parsing hardened against `null` values; parity metrics written with explicit UTF-8 encoding:** `int(file_data.get("size") or 0)` guards against `"size": null` from the API; `_emit_parity_metrics` now passes `encoding="utf-8"` to avoid platform-dependent encoding on Windows.

## [1.26.0] - 2026-05-17

### Added

- **`--timestamped-output` flag:** Inserts a per-run timestamp (`YYYYMMDD_HHMMSS_ffffff`, local time, microsecond precision) before the final extension of both `--log-file` and `--failed-file` paths, giving each run its own files without requiring explicit unique names.
  - Path transformation: `run.log` → `run_20260517_142530_123456.log`; `logs/failed.csv` → `logs/failed_20260517_142530_123456.csv`; extension-less names have the suffix appended; disabled (empty) paths are left untouched.
  - Independent of `--fresh-run`: `--timestamped-output` routes each run to a *new* file; `--fresh-run` truncates the *configured* file in place.

## [1.25.0] - 2026-05-14

### Added

- **`--skip-existing` flag for `recover-and-download`:** Skips the download when the computed local target path already resolves to a regular file.
  - Uses `Path.is_file()` rather than `exists()` so a directory collision does not silently satisfy the skip and allow `post-restore-policy=delete` to remove the Drive file without a local copy.

## [1.24.1] - 2026-05-14

### Removed

- `--download-dir` removed from `recover-only` subparser; it was silently accepted but had no effect.

## [1.24.0] - 2026-05-14

### Added

- **Per-item step records with v2 → v3 schema migration (#1030):** `processed_items` promoted from `List[str]` to `Dict[str, ProcessedRecord]`; each record tracks steps `recovered`, `downloaded`, `post_restored`. `_mark_step` / `_required_steps` / `_step_is_done` helpers manage per-step completion; an interrupted run retries only the steps not yet recorded.

### Changed

- **`RecoveryState.processed_items` type changed** from `Optional[List[str]]` to `Optional[Dict[str, ProcessedRecord]]`; `_mark_processed(item_id)` retained as a backward-compat wrapper that marks all three steps done.

### Migration

- **v2 → v3 is automatic and non-destructive.** On first load of a v2 state file, every ID is converted to `ProcessedRecord(recovered=True, downloaded=True, post_restored=True)`.
- **v0/v1 → v3 chained migration** works in a single load.
- **Migration is one-way.** Keep a copy of your state file before upgrading; to retry previously-failed items use `--retry-failed-file <csv>` or `--fresh-run`.

## [1.23.1–1.23.3] - 2026-05-14 (consolidated)

### Added

- **Structured end-of-run summary + forced final progress line:** `RecoveryReporter._print_summary` emits a grep-friendly `Run complete: ...` log record; `_print_final_stream_progress` forces a true-final `ProgressBar` update before summary/interruption output so the last visible `processed=` line is not stale.

### Fixed

- **Resume-mode skipped counts are now accurate:** `_process_item` increments `stats["skipped"]` when `_is_processed` short-circuits, fixing zero-skipped summaries in folder-id and retry-failed-file paths where `will_recover=False`.

## [1.23.0] - 2026-05-14

### Added

- **Scope-aware state file with v1→v2 schema migration (#1029):** State files now record a `scope` block (`source`, `command`, `key`). A mismatch between the saved scope and the current invocation causes the tool to exit with code 2 (unless `--fresh-run` is passed); the CLI renders a clear remediation message showing saved scope, current scope, and suggested fix.

### Changed

- **`RecoveryState.schema_version` default is now 2.** v0/v1 state files synthesize a scope from the current invocation and are rewritten as v2 on next save.
- **`RecoveryState.owner_pid` removed.** The lock file remains the source of truth for the live PID; v1 files containing `owner_pid` load fine — the unknown field is silently dropped.
- **`--overwrite` deprecation shim removed (per v1.22.0 timing).** `--overwrite` is now strictly a local-file collision policy: it no longer clears `processed_items`, truncates the failed-file CSV, or emits a deprecation warning. Use `--fresh-run` for fresh-run effects.

### Migration

- **v1 → v2 is automatic and non-destructive.** Existing v1 state files load on first run; the synthesized scope reflects the current invocation. A different scope on a subsequent run is rejected with a clear message instead of silently skipping work.

## [1.22.0] - 2026-05-14

### Added

- **`--fresh-run` flag (#1028):** Ignores prior progress in the state file, regenerates run identity (`run_id`, `start_time`, `owner_pid`), and (if `--failed-file` is set) truncates the failed-file CSV before the run starts. Available on both `recover-only` and `recover-and-download`; mutually exclusive with `--retry-failed-file`. Implemented via `RecoveryStateManager._reset_state`.

### Changed

- **`--overwrite` narrowed to local-file collision policy only.** State reset and failed-file truncation are now `--fresh-run`'s responsibility.

### Deprecated

- **Combined "clear state + truncate failed-file" behaviour of `--overwrite`.** Continues to work in this release with a stderr warning. Migrate to `--fresh-run` (alone or combined with `--overwrite`) before v1.23.0.

## [1.21.1–1.21.2] - 2026-05-14 (consolidated)

### Fixed

- **Failed-item resume correctness and retry safety improvements (#1027):**
  - `--retry-failed-file` sets `will_recover=False` for retried items; exits with code 1 when the CSV has no actionable rows.
  - Failed items are no longer marked as processed in the state file; only fully successful items enter `processed_items`, allowing reruns to reattempt failures.
  - `--failed-file` and `--retry-failed-file` are validated as distinct paths.

## [1.21.0] - 2026-05-14

> **Breaking change for `--failed-file` consumers:** The output is now CSV, not plain text. Update any scripts that read it line-by-line to use a CSV reader; the `target_path` column contains the same value as the previous plain-text entry.

### Added

- **CSV failed-file output (`--failed-file`):** The file is now a proper CSV with columns `source_folder_id` (Drive ID of the parent folder), `file_id` (stable Drive file ID), and `target_path` (full local path). A header row is written automatically on the first entry of each run.

- **`--retry-failed-file <csv>` for `recover-and-download`:** Accepts a CSV produced by `--failed-file` and retries only the file IDs it contains, restoring each to its original target path. Mutually exclusive with `--file-ids` and `--folder-id`; download-only. Failures are recorded in the new `--failed-file` if one is supplied.

### Changed

- `DriveOperations._write_failed_file` rewritten to use `csv.writer`; writes a header row when the destination file is new or empty.

## [1.20.2] - 2026-05-12

Internal test coverage improvements only; no user-visible changes.

## [1.20.1] - 2026-05-12

### Fixed

- Post-restore failures (trash/delete API calls) now propagate into item failure state and trigger `--failed-file` output; the return value of `_apply_post_restore_policy` was previously discarded.

## [1.20.0] - 2026-05-12

### Added

- **Optional log file (`--log-file`):** Attaches a `FileHandler` at `DEBUG` level when supplied; the file and any missing parent directories are created automatically. Previously a log file was always written to `gdrive_recovery.log`; now the default is no file logging.

- **Failed-file log (`--failed-file`):** Appends the full local path (or Drive file name for recover-only) of every failed item to a file; the file and any missing parent directories are created automatically. Accepted by all three subcommands. When `--overwrite` is active the file is truncated before processing begins.

### Changed

- `DEFAULT_LOG_FILE` in `gdrive_constants.py` changed from `"gdrive_recovery.log"` to `""` (disabled by default). Existing workflows that relied on automatic log-file creation must now pass `--log-file gdrive_recovery.log` explicitly.

## [1.19.0] - 2026-05-12

### Added

- **Progress bar for recovery and download operations:** New `ProgressBar` class in `gdrive_report.py` renders an animated in-place progress bar during streaming execution and batch processing.
  - **TTY (interactive terminal):** `[████████░░░░░░░░░░░░] 400/1000 (40.0%) │ 5.2/sec │ ETA: 115s` (known total) or `▶ processed=800 discovered=1234 │ 5.2/sec` (streaming).
  - **Non-TTY (CI / log files):** Plain text line written at most every 10 s when `--verbose` (`-v`) is active.
  - **`--no-emoji` compatibility:** Unicode block characters (`█░▶│`) replaced with ASCII equivalents (`#->`).

## [1.18.x] - 2026-05-12 (consolidated)

### Added

- **Folder-scoped download (`--folder-id`):** Scopes discovery to a specific Google Drive folder via BFS traversal; targets non-trashed, live files (`will_recover=False`); reconstructs the full subfolder hierarchy under `--download-dir`. Prints a warning when combined with the default `trash` post-restore policy.
- **`--overwrite` flag (`recover-and-download`):** Replaces existing local files instead of appending a `_<hex6>` suffix. *(Superseded by the `--fresh-run` redesign in [1.22.0]–[1.23.0]; retained here for history only.)*

### Fixed

- **`gdrive_validators.py` extracted:** Resolved `ModuleNotFoundError` caused by `gdrive_cli.py` importing from a bare `validators` module; gdrive-specific validators now live in `gdrive_validators.py`.
- **Dry-run correctness:** `--download-dir` now accepted by `dry-run` and `recover-only`; dry-run no longer writes to disk when `--download-dir` is passed; execution-command generation corrected to emit the actual subcommand instead of always `dry-run`; `--folder-id` included in generated commands.

## [1.9.0–1.17.0] - 2026-03-29 → 2026-04-11 (consolidated)

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

## [1.8.1] - 2026-03-26

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

## [1.8.0] - 2026-03-26

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

## [1.5.x] - 2025-09-19 → 2025-09-21 (consolidated)

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
