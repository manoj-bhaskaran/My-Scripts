"""
State persistence and lock management for the Google Drive Trash Recovery Tool.
"""

import json
import os
from dataclasses import asdict, fields
from datetime import datetime, timezone
from typing import Any, Dict, Callable, Optional

from gdrive_models import RecoveryState


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
        """Assign only known fields from data to a RecoveryState instance."""
        new_state = RecoveryState()
        rs_fields = {f.name for f in fields(RecoveryState)}
        for k in rs_fields:
            if k in data:
                try:
                    setattr(new_state, k, data[k])
                except Exception:
                    pass
        return new_state

    def _handle_legacy_state_upgrade(self):
        """Handle legacy (v0) state upgrade and logging."""
        self.state.schema_version = 1
        msg = (
            "Loaded legacy state (schema v0). This will be upgraded to schema v1 "
            "on next save for better compatibility."
        )
        prefix = "ℹ️" if not getattr(self.args, "no_emoji", False) else "INFO"
        print(f"{prefix} {msg}")
        try:
            self.logger.warning("State schema v0 detected; promoting to v1 on next save.")
        except Exception:
            pass

    def _handle_schema_version_mismatch(self, raw_version):
        """Handle state file with a different schema version."""
        try:
            self.logger.info(
                "Loaded state with schema v%d; proceeding with tolerant parsing.", raw_version
            )
        except Exception:
            pass
        self.state.schema_version = 1

    def _load_state(self) -> bool:
        if not os.path.exists(self.args.state_file):
            return False
        try:
            with open(self.args.state_file, "r") as f:
                data = json.load(f)

            raw_version = self._parse_schema_version(data)
            self.state = self._assign_recovery_state_fields(data)

            if raw_version == 0:
                self._handle_legacy_state_upgrade()
            elif raw_version != self.state.schema_version:
                self._handle_schema_version_mismatch(raw_version)

            prefix = "📂" if not getattr(self.args, "no_emoji", False) else "STATE"
            print(
                f"{prefix} Loaded previous state: {len(self.state.processed_items)} items already processed"
            )
            return True
        except Exception:
            self.logger.exception(
                f"Unexpected error while loading state file '{self.args.state_file}'"
            )
            if self.on_state_load_error:
                try:
                    self.on_state_load_error()
                except Exception:
                    pass
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
                try:
                    self.state.schema_version = int(getattr(self.state, "schema_version", 0) or 1)
                except Exception:
                    self.state.schema_version = 1
                json.dump(asdict(self.state), f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_path, self.args.state_file)
        except Exception as e:
            self.logger.error(f"Failed to save state: {e}")

    def _clear_processed_items(self) -> int:
        """Clear all processed IDs from state; returns the count removed."""
        count = len(self.state.processed_items)
        self.state.processed_items.clear()
        return count

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
