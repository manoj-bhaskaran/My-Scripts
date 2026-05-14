"""
State persistence and lock management for the Google Drive Trash Recovery Tool.

Thread safety
-------------
``_state_lock`` (a ``threading.Lock``) protects all accesses to
``state.processed_items`` that could race with concurrent worker threads:

* ``_mark_step`` holds the lock while inserting or updating a record.
* ``_save_state`` holds the lock only for the ``asdict(self.state)`` snapshot,
  releasing it before any file I/O.  This prevents a ``RuntimeError: dictionary
  changed size during iteration`` when a worker calls ``_mark_step`` while the
  main thread is checkpointing.

Callers that hold their own lock (e.g. ``stats_lock`` in ``DriveOperations``)
must *not* call ``_mark_step`` while holding it, to avoid deadlock.
``_process_item`` is structured so that ``_mark_step`` is invoked after any
``stats_lock``-protected block has already been released.
"""

import hashlib
import json
import os
from dataclasses import asdict, fields
from datetime import datetime, timezone
from threading import Lock
from typing import Any, Dict, Callable, Optional

from gdrive_models import ProcessedRecord, RecoveryState, RecoveryStateScope

CURRENT_SCHEMA_VERSION = 3


class StateScopeMismatchError(Exception):
    """Raised when a saved scope does not match the current invocation's scope.

    Carries both scopes so the CLI can render a clear remediation message.
    """

    def __init__(self, saved_scope: RecoveryStateScope, current_scope: RecoveryStateScope):
        self.saved_scope = saved_scope
        self.current_scope = current_scope
        super().__init__(
            f"State file scope mismatch: saved={saved_scope!r}, current={current_scope!r}"
        )


class RecoveryStateManager:
    """Owns state load/save, schema handling, and lock file lifecycle."""

    def __init__(self, args, logger, on_state_load_error: Optional[Callable[[], None]] = None):
        self.args = args
        self.logger = logger
        self.on_state_load_error = on_state_load_error
        self.state = RecoveryState()
        self._state_lock_path = f"{self.args.state_file}.lock"
        self._state_lock_fh = None
        self._state_lock = Lock()  # serialises _mark_step dict mutations

    @staticmethod
    def _parse_schema_version(data: Dict[str, Any]) -> int:
        """Extract schema_version from loaded state data, defaulting to 0."""
        try:
            return int(data.get("schema_version", 0) or 0)
        except Exception:
            return 0

    @staticmethod
    def _parse_scope_value(value: dict) -> Optional[RecoveryStateScope]:
        """Coerce a raw JSON dict into a RecoveryStateScope, or None on error."""
        try:
            return RecoveryStateScope(
                source=str(value.get("source", "")),
                command=str(value.get("command", "")),
                key=str(value.get("key", "")),
            )
        except Exception:
            return None

    @staticmethod
    def _make_processed_record(rec: dict) -> ProcessedRecord:
        """Coerce a raw JSON dict into a ProcessedRecord.

        Falls back to a fully-flagged record on any conversion error so that
        a corrupt entry does not cause an item to be reprocessed.
        """
        try:
            return ProcessedRecord(
                recovered=bool(rec.get("recovered", False)),
                downloaded=bool(rec.get("downloaded", False)),
                post_restored=bool(rec.get("post_restored", False)),
                last_attempt_iso=str(rec.get("last_attempt_iso", "")),
            )
        except Exception:
            return ProcessedRecord(recovered=True, downloaded=True, post_restored=True)

    @staticmethod
    def _parse_processed_items(value: dict) -> Dict[str, ProcessedRecord]:
        """Convert a v3 wire-format dict to ``Dict[str, ProcessedRecord]``."""
        converted: Dict[str, ProcessedRecord] = {}
        for id_, rec in value.items():
            if isinstance(rec, dict):
                converted[str(id_)] = RecoveryStateManager._make_processed_record(rec)
            elif isinstance(rec, ProcessedRecord):
                converted[str(id_)] = rec
        return converted

    def _assign_recovery_state_fields(self, data: Dict[str, Any]) -> RecoveryState:
        """Assign only known fields from data to a RecoveryState instance.

        Unknown keys (e.g. the retired ``owner_pid`` field in v1 files) are
        silently dropped.  ``processed_items`` may arrive as a list (v2 wire
        format) or a dict (v3 wire format) — both are accepted; a list is left
        as-is so ``_migrate_v2_to_v3`` can convert it in a single pass.
        """
        new_state = RecoveryState()
        rs_fields = {f.name for f in fields(RecoveryState)}
        for k in rs_fields:
            if k not in data:
                continue
            value = data[k]
            if k == "scope" and isinstance(value, dict):
                value = self._parse_scope_value(value)
            elif k == "processed_items" and isinstance(value, dict):
                value = self._parse_processed_items(value)
            # Lists (v2 wire format) are kept as-is; _migrate_v2_to_v3 converts later.
            try:
                setattr(new_state, k, value)
            except Exception:
                pass
        return new_state

    def _derive_scope_from_args(self) -> RecoveryStateScope:
        """Compute the scope block for the current invocation.

        Discriminating ``key`` per source:
          - retry_failed_file: absolute path of the retry CSV
          - file_ids:           sha256("|".join(sorted(file_ids)))[:16]
          - folder_id:          the folder ID itself
          - trash_query:        sha256(extensions_sorted + "|" + after_date + "|" + str(limit))[:16]
        """
        args = self.args
        retry_path = getattr(args, "retry_failed_file", None) or ""
        if retry_path:
            source = "retry_failed_file"
            key = os.path.abspath(retry_path)
        elif getattr(args, "file_ids", None):
            source = "file_ids"
            joined = "|".join(sorted(args.file_ids))
            key = hashlib.sha256(joined.encode("utf-8")).hexdigest()[:16]
        elif getattr(args, "folder_id", None):
            source = "folder_id"
            key = str(args.folder_id)
        else:
            source = "trash_query"
            exts = sorted(getattr(args, "extensions", None) or [])
            after_date = getattr(args, "after_date", "") or ""
            limit = getattr(args, "limit", 0) or 0
            raw = "|".join(exts) + "|" + str(after_date) + "|" + str(limit)
            key = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]

        mode = getattr(args, "mode", "") or ""
        if mode == "recover_and_download":
            command = "recover_and_download"
        elif mode == "recover_only":
            command = "recover_only"
        else:
            # dry_run never persists state; default to the recover-only label so
            # the dataclass round-trips cleanly if a test exercises this path.
            command = mode or "recover_only"

        return RecoveryStateScope(source=source, command=command, key=key)

    def _check_scope_or_raise(self, saved_scope: RecoveryStateScope) -> None:
        """Compare a loaded scope against the current invocation."""
        if getattr(self.args, "fresh_run", False):
            return
        current_scope = self._derive_scope_from_args()
        if (
            saved_scope.source != current_scope.source
            or saved_scope.command != current_scope.command
            or saved_scope.key != current_scope.key
        ):
            raise StateScopeMismatchError(saved_scope, current_scope)

    def _print_migration_notice(self) -> None:
        prefix = "ℹ️" if not getattr(self.args, "no_emoji", False) else "INFO"
        print(
            f"{prefix} Migrating state file from schema v1 to v2 "
            "(scope inferred from current invocation)."
        )
        try:
            self.logger.info(
                "State file schema upgrade: v1 -> v2; scope synthesized from current args."
            )
        except Exception:
            pass

    def _migrate_v2_to_v3(self) -> None:
        """Convert a v2 ``List[str]`` ``processed_items`` to a v3 ``Dict[str, ProcessedRecord]``.

        All existing IDs are mapped to fully-flagged records so no item is
        reprocessed.  If ``processed_items`` is already a dict (i.e. the file
        is v3 or was already migrated) this is a no-op.
        """
        items = self.state.processed_items
        if not isinstance(items, list):
            return  # Already v3 format.
        count = len(items)
        now = datetime.now(timezone.utc).isoformat()
        self.state.processed_items = {
            item_id: ProcessedRecord(
                recovered=True, downloaded=True, post_restored=True, last_attempt_iso=now
            )
            for item_id in items
        }
        msg = (
            f"Migrating state file from schema v2 to v3 "
            f"({count} items converted to per-step records)."
        )
        prefix = "ℹ️" if not getattr(self.args, "no_emoji", False) else "INFO"
        print(f"{prefix} {msg}")
        try:
            self.logger.info(msg)
        except Exception:
            pass

    def _apply_loaded_schema(self, raw_version: int) -> None:
        """Reconcile the loaded state with the current schema version.

        Migration chain:
          v0/v1 → v2: synthesise scope from current args
          v2    → v3: convert ``List[str]`` processed_items to ``Dict[str, ProcessedRecord]``
          v3        : scope-check only
          v3+       : tolerate, downgrade in-memory schema_version
        """
        if raw_version < 2:
            # v0/v1 → v2 → v3 in one pass.
            self._print_migration_notice()
            self.state.scope = self._derive_scope_from_args()
            self._migrate_v2_to_v3()
            self.state.schema_version = CURRENT_SCHEMA_VERSION
        elif raw_version == 2:
            # v2 → v3: scope already present; migrate processed_items list → dict.
            if self.state.scope is None:
                self.state.scope = self._derive_scope_from_args()
            else:
                self._check_scope_or_raise(self.state.scope)
            self._migrate_v2_to_v3()
            self.state.schema_version = CURRENT_SCHEMA_VERSION
        elif raw_version == CURRENT_SCHEMA_VERSION:
            if self.state.scope is None:
                self.state.scope = self._derive_scope_from_args()
            else:
                self._check_scope_or_raise(self.state.scope)
        else:
            self._log_newer_schema(raw_version)
            # Safety net: normalise any legacy list format that may appear in
            # a file written by a future version that reverted the schema.
            self._migrate_v2_to_v3()
            self.state.schema_version = CURRENT_SCHEMA_VERSION

    def _log_newer_schema(self, raw_version: int) -> None:
        try:
            self.logger.info(
                "Loaded state with schema v%d (newer than v%d); "
                "proceeding with tolerant parsing.",
                raw_version,
                CURRENT_SCHEMA_VERSION,
            )
        except Exception:
            pass

    def _handle_load_failure(self) -> None:
        self.logger.exception(f"Unexpected error while loading state file '{self.args.state_file}'")
        if self.on_state_load_error:
            try:
                self.on_state_load_error()
            except Exception:
                pass

    def _load_state(self) -> bool:
        if not os.path.exists(self.args.state_file):
            return False
        try:
            with open(self.args.state_file, "r") as f:
                data = json.load(f)
            raw_version = self._parse_schema_version(data)
            self.state = self._assign_recovery_state_fields(data)
            self._apply_loaded_schema(raw_version)
            prefix = "📂" if not getattr(self.args, "no_emoji", False) else "STATE"
            print(
                f"{prefix} Loaded previous state: "
                f"{len(self.state.processed_items)} item record(s) (will be skipped if complete)"
            )
            return True
        except StateScopeMismatchError:
            raise
        except Exception:
            self._handle_load_failure()
        return False

    def _acquire_state_lock(self) -> bool:
        """
        Cross-platform advisory lock on <state>.lock.
        Returns True on success; False if already locked by another process.
        """
        self._state_lock_path = f"{self.args.state_file}.lock"
        self._state_lock_fh = open(self._state_lock_path, "a+")
        try:
            if os.name == "nt":
                import msvcrt

                try:
                    msvcrt.locking(self._state_lock_fh.fileno(), msvcrt.LK_NBLCK, 1)
                except OSError:
                    return False
            else:
                import fcntl

                try:
                    fcntl.flock(self._state_lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                except OSError:
                    return False
            try:
                self._state_lock_fh.seek(0)
                self._state_lock_fh.truncate(0)
                rid = getattr(self.state, "run_id", "") or ""
                pid = os.getpid()
                self._state_lock_fh.write(f"pid={pid}\nrun_id={rid}\n")
                self._state_lock_fh.flush()
                try:
                    os.fsync(self._state_lock_fh.fileno())
                except Exception:
                    pass
                try:
                    self._state_lock_fh.seek(0)
                    content = self._state_lock_fh.read()
                except Exception:
                    content = ""
                expected_pid = f"pid={pid}"
                expected_rid = f"run_id={rid}"
                if (expected_pid not in content) or (expected_rid not in content):
                    self.logger.error(
                        "Lock verification failed: expected pid/run_id not present in lock file content."
                    )
                    return False
            except Exception:
                self.logger.error("Failed to write/verify lock metadata; refusing to proceed.")
                return False
            return True
        except Exception as e:
            try:
                self.logger.error(f"State lock error: {e}")
            except Exception:
                pass
            return False

    def _release_state_lock(self) -> None:
        try:
            if self._state_lock_fh is None:
                return
            if os.name == "nt":
                import msvcrt

                try:
                    msvcrt.locking(self._state_lock_fh.fileno(), msvcrt.LK_UNLCK, 1)
                except Exception:
                    pass
            else:
                import fcntl

                try:
                    fcntl.flock(self._state_lock_fh.fileno(), fcntl.LOCK_UN)
                except Exception:
                    pass
            self._state_lock_fh.close()
            self._state_lock_fh = None
        except Exception:
            pass

    def _save_state(self):
        try:
            tmp_path = f"{self.args.state_file}.tmp"
            os.makedirs(os.path.dirname(os.path.abspath(tmp_path)), exist_ok=True)
            # Snapshot the state dict under _state_lock so that worker threads
            # calling _mark_step cannot mutate processed_items while asdict()
            # iterates it, which would raise RuntimeError on dict size change.
            # File I/O happens outside the lock to avoid blocking workers.
            with self._state_lock:
                self.state.schema_version = CURRENT_SCHEMA_VERSION
                if self.state.scope is None:
                    self.state.scope = self._derive_scope_from_args()
                state_snapshot = asdict(self.state)
            with open(tmp_path, "w") as f:
                json.dump(state_snapshot, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_path, self.args.state_file)
        except Exception as e:
            self.logger.error(f"Failed to save state: {e}")

    def _reset_state(self) -> int:
        """Reset in-memory state to a brand-new ``RecoveryState``, preserving only
        the schema version.

        Returns the count of previously recorded item records so callers can log it.
        """
        prev_count = len(self.state.processed_items or {})
        prev_schema = getattr(self.state, "schema_version", CURRENT_SCHEMA_VERSION)
        self.state = RecoveryState()
        try:
            self.state.schema_version = int(prev_schema or CURRENT_SCHEMA_VERSION)
        except Exception:
            self.state.schema_version = CURRENT_SCHEMA_VERSION
        return prev_count

    # ---------------------------------------------------------------------------
    # Per-step query / mutation API (v3)
    # ---------------------------------------------------------------------------

    def _required_steps(self, item) -> set:
        """Return the set of step names that must be True for item to be complete.

        Steps are determined by the item's ``will_recover`` and ``will_download``
        flags:
          - ``recovered``    — if ``will_recover=True``
          - ``downloaded``   — if ``will_download=True``
          - ``post_restored``— if ``will_download=True``
        """
        steps: set = set()
        if getattr(item, "will_recover", True):
            steps.add("recovered")
        if getattr(item, "will_download", False):
            steps.add("downloaded")
            steps.add("post_restored")
        return steps

    def _step_is_done(self, item_id: str, step: str) -> bool:
        """Return True if ``step`` is recorded as complete for ``item_id``."""
        record = self.state.processed_items.get(item_id)
        if record is None:
            return False
        return bool(getattr(record, step, False))

    def _is_processed(self, item) -> bool:
        """Return True iff all required steps for item are recorded as done.

        ``item`` must be a ``RecoveryItem`` so that ``_required_steps`` can
        compute which steps apply to this particular pipeline invocation.
        """
        record = self.state.processed_items.get(item.id)
        if record is None:
            return False
        return all(getattr(record, step, False) for step in self._required_steps(item))

    def _mark_step(self, item_id: str, step: str) -> None:
        """Record that ``step`` succeeded for ``item_id``.

        Thread-safe: acquires ``_state_lock`` before mutating the dict.
        The record is created if it does not yet exist.
        """
        with self._state_lock:
            record = self.state.processed_items.get(item_id)
            if record is None:
                record = ProcessedRecord()
                self.state.processed_items[item_id] = record
            setattr(record, step, True)
            now = datetime.now(timezone.utc).isoformat()
            record.last_attempt_iso = now
            self.state.last_checkpoint = now

    def _mark_processed(self, item_id: str) -> None:
        """Backward-compat wrapper: marks all three steps as done for ``item_id``.

        New code should call ``_mark_step`` for each completed step individually.
        """
        for step in ("recovered", "downloaded", "post_restored"):
            self._mark_step(item_id, step)

    def _pid_is_alive(self, pid: int) -> bool:
        """
        Best-effort liveness check for a PID on the current platform.
        Returns True if the process exists or access is denied. Returns False otherwise.
        """
        try:
            if pid is None or int(pid) <= 0:
                return False
            if os.name == "nt":
                import ctypes

                PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
                handle = ctypes.windll.kernel32.OpenProcess(
                    PROCESS_QUERY_LIMITED_INFORMATION, False, int(pid)
                )
                if handle:
                    ctypes.windll.kernel32.CloseHandle(handle)
                    return True
                return False
            try:
                # Signal 0 is a POSIX existence probe; it does not deliver a signal.
                os.kill(int(pid), 0)  # NOSONAR(S4818)
                return True
            except ProcessLookupError:
                return False
            except PermissionError:
                return True
            except OSError:
                return False
        except Exception:
            return False
