"""
State persistence and lock management for the Google Drive Trash Recovery Tool.
"""

import hashlib
import json
import os
from dataclasses import asdict, fields
from datetime import datetime, timezone
from typing import Any, Dict, Callable, Optional

from gdrive_models import RecoveryState, RecoveryStateScope

CURRENT_SCHEMA_VERSION = 2


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

    @staticmethod
    def _parse_schema_version(data: Dict[str, Any]) -> int:
        """Extract schema_version from loaded state data, defaulting to 0."""
        try:
            return int(data.get("schema_version", 0) or 0)
        except Exception:
            return 0

    def _assign_recovery_state_fields(self, data: Dict[str, Any]) -> RecoveryState:
        """Assign only known fields from data to a RecoveryState instance.

        Unknown keys present in the JSON (e.g. the retired ``owner_pid`` field
        in v1 files) are silently dropped.
        """
        new_state = RecoveryState()
        rs_fields = {f.name for f in fields(RecoveryState)}
        for k in rs_fields:
            if k not in data:
                continue
            value = data[k]
            if k == "scope" and isinstance(value, dict):
                try:
                    value = RecoveryStateScope(
                        source=str(value.get("source", "")),
                        command=str(value.get("command", "")),
                        key=str(value.get("key", "")),
                    )
                except Exception:
                    value = None
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
        """Compare a loaded v2 scope against the current invocation."""
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

    def _apply_loaded_schema(self, raw_version: int) -> None:
        """Reconcile the loaded state with the current schema version.

        Splits the v0/v1 migration path, the v2 scope-check path, and the
        forward-compatible "newer schema" path out of `_load_state` so the
        latter stays under the cognitive-complexity budget.
        """
        if raw_version < CURRENT_SCHEMA_VERSION:
            # v0/v1: synthesize a scope from current args; promote to v2 on next save.
            self._print_migration_notice()
            self.state.scope = self._derive_scope_from_args()
            self.state.schema_version = CURRENT_SCHEMA_VERSION
        elif raw_version == CURRENT_SCHEMA_VERSION:
            if self.state.scope is None:
                # v2 file without a scope block (corrupted/truncated); rebuild from args.
                self.state.scope = self._derive_scope_from_args()
            else:
                self._check_scope_or_raise(self.state.scope)
        else:
            self._log_newer_schema(raw_version)
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
                f"{len(self.state.processed_items)} items successfully processed (will be skipped)"
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
            with open(tmp_path, "w") as f:
                self.state.schema_version = CURRENT_SCHEMA_VERSION
                if self.state.scope is None:
                    self.state.scope = self._derive_scope_from_args()
                json.dump(asdict(self.state), f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_path, self.args.state_file)
        except Exception as e:
            self.logger.error(f"Failed to save state: {e}")

    def _reset_state(self) -> int:
        """Reset in-memory state to a brand-new `RecoveryState`, preserving only
        the schema version.

        After calling this the caller is expected to run
        `_initialize_recovery_state` so that a new `run_id` and `start_time`
        are generated for the current process (the "if not X" guards there
        naturally take the fresh path because every identity field has been
        wiped here). The scope block is repopulated from current args.

        Returns the count of previously processed items so callers can log it.
        """
        prev_count = len(self.state.processed_items or [])
        prev_schema = getattr(self.state, "schema_version", CURRENT_SCHEMA_VERSION)
        self.state = RecoveryState()
        try:
            self.state.schema_version = int(prev_schema or CURRENT_SCHEMA_VERSION)
        except Exception:
            self.state.schema_version = CURRENT_SCHEMA_VERSION
        return prev_count

    def _is_processed(self, item_id: str) -> bool:
        return item_id in self.state.processed_items

    def _mark_processed(self, item_id: str):
        if item_id not in self.state.processed_items:
            self.state.processed_items.append(item_id)
            self.state.last_checkpoint = datetime.now(timezone.utc).isoformat()

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
