# Changelog

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
