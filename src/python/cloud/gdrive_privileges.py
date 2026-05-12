"""Privilege checking helpers for Google Drive trash recovery dry-run paths."""

import shutil
import logging
from pathlib import Path
from typing import Any, Dict, List, Tuple

from gdrive_constants import INFERRED_MODIFY_ERROR
from gdrive_models import FileMeta, RecoveryItem

try:
    from googleapiclient.errors import HttpError
except Exception:  # pragma: no cover - only used when google libs are unavailable

    class HttpError(Exception):
        """Fallback HttpError type for environments without googleapiclient."""


class DrivePrivilegeChecker:
    """Encapsulates Drive and local privilege checks used by dry-run."""

    def __init__(self, auth, execute_fn, logger: logging.Logger, items: List[RecoveryItem]):
        self.auth = auth
        self._execute = execute_fn
        self.logger = logger
        self.items = items

    def _get_file_info(self, file_id: str, fields: str) -> FileMeta:
        api_ctx = f"files.get(fileId={file_id}, fields={fields})"
        try:
            service = self.auth._get_service()
            return self._execute(service.files().get(fileId=file_id, fields=fields))
        except HttpError as e:  # type: ignore[misc]
            status = getattr(getattr(e, "resp", None), "status", None)
            payload = getattr(e, "content", b"")
            detail = payload.decode(errors="ignore") if hasattr(payload, "decode") else str(e)
            self.logger.error(f"{api_ctx} failed: HTTP {status}: {detail}")
            return {"error": f"HTTP {status}: {detail}"}
        except (OSError, IOError) as e:
            self.logger.error(f"{api_ctx} I/O error: {e}")
            return {"error": f"I/O error: {e}"}
        except Exception as e:
            self.logger.error(f"{api_ctx} unexpected error: {e}")
            return {"error": f"Unexpected error: {e}"}  # type: ignore[return-value]

    def _check_untrash_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {"status": "unknown", "error": None}
        file_info = self._get_file_info(file_id, "id,trashed,capabilities")
        if "error" in file_info:
            result["status"] = "fail"
            result["error"] = file_info["error"]
            return result
        if not file_info.get("trashed", False):
            result["status"] = "skip"
            result["error"] = "Test file is not trashed - cannot validate untrash permission"
            return result
        capabilities = file_info.get("capabilities", {})
        if "canUntrash" in capabilities:
            result["status"] = "pass" if capabilities["canUntrash"] else "fail"
            if not capabilities["canUntrash"]:
                result["error"] = "File capabilities indicate untrash not allowed"
        else:
            result["status"] = "pass"
        return result

    def _check_download_privilege(self, file_id: str) -> Dict[str, Any]:
        result = {"status": "unknown", "error": None}
        file_info = self._get_file_info(file_id, "id,size,mimeType,capabilities")
        if "error" in file_info:
            result["status"] = "fail"
            result["error"] = file_info["error"]
            return result
        if "size" not in file_info:
            result["status"] = "fail"
            result["error"] = "File is not downloadable (Google Docs format or no size)"
            return result
        capabilities = file_info.get("capabilities", {})
        if "canDownload" in capabilities:
            result["status"] = "pass" if capabilities["canDownload"] else "fail"
            if not capabilities["canDownload"]:
                result["error"] = "File capabilities indicate download not allowed"
        else:
            result["status"] = "pass"
        return result

    def _check_trash_delete_privileges(
        self, file_id: str, untrash_status: str
    ) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        trash_result = {
            "status": untrash_status,
            "error": INFERRED_MODIFY_ERROR if untrash_status == "fail" else None,
        }
        delete_result = {
            "status": untrash_status,
            "error": INFERRED_MODIFY_ERROR if untrash_status == "fail" else None,
        }
        file_info = self._get_file_info(file_id, "id,capabilities")
        if "error" in file_info:
            trash_result["status"] = "fail"
            trash_result["error"] = file_info["error"]
            delete_result["status"] = "fail"
            delete_result["error"] = file_info["error"]
            return trash_result, delete_result
        capabilities = file_info.get("capabilities", {})
        if "canTrash" in capabilities:
            trash_result["status"] = "pass" if capabilities["canTrash"] else "fail"
            trash_result["error"] = (
                None if capabilities["canTrash"] else "File capabilities indicate trash not allowed"
            )
        if "canDelete" in capabilities:
            delete_result["status"] = "pass" if capabilities["canDelete"] else "fail"
            delete_result["error"] = (
                None
                if capabilities["canDelete"]
                else "File capabilities indicate delete not allowed"
            )
        elif trash_result["status"] == "pass":
            delete_result["status"] = "pass"
            delete_result["error"] = None
        return trash_result, delete_result

    def _test_operation_privileges(self, test_items: List[RecoveryItem]) -> Dict[str, Any]:
        privileges = {
            "untrash": {"status": "unknown", "error": None},
            "download": {"status": "unknown", "error": None},
            "trash": {"status": "unknown", "error": None},
            "delete": {"status": "unknown", "error": None},
        }
        if not test_items:
            return privileges
        test_item = test_items[0]
        if test_item.will_recover:
            privileges["untrash"] = self._check_untrash_privilege(test_item.id)
            untrash_status = privileges["untrash"]["status"]
        else:
            del privileges["untrash"]
            untrash_status = "unknown"
        privileges["download"] = self._check_download_privilege(test_item.id)
        privileges["trash"], privileges["delete"] = self._check_trash_delete_privileges(
            test_item.id, untrash_status
        )
        return privileges

    def _check_privileges(self, args) -> Dict[str, Any]:
        checks = {
            "drive_access": False,
            "drive_error": None,
            "operation_privileges": {},
            "local_writable": False,
            "local_error": None,
            "disk_space": 0,
            "estimated_needed": 0,
        }
        try:
            service = self.auth._get_service()
            service.files().list(pageSize=1).execute()
            checks["drive_access"] = True
            sample_items = self.items[:1] if self.items else []
            checks["operation_privileges"] = self._test_operation_privileges(sample_items)
        except Exception as e:
            checks["drive_error"] = str(e)
        dl_dir = getattr(args, "download_dir", None)
        is_dry_run = getattr(args, "mode", None) == "dry_run"
        if dl_dir and not is_dry_run:
            try:
                download_path = Path(dl_dir)
                download_path.mkdir(parents=True, exist_ok=True)
                test_file = download_path / ".write_test"
                test_file.write_text("test")
                test_file.unlink()
                checks["local_writable"] = True
                if hasattr(shutil, "disk_usage"):
                    _, _, free_bytes = shutil.disk_usage(download_path)
                    checks["disk_space"] = free_bytes
                    total_size = sum(item.size for item in self.items if item.will_download)
                    checks["estimated_needed"] = total_size
            except Exception as e:
                checks["local_error"] = str(e)
        return checks
