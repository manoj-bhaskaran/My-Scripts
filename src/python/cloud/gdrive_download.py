r"""
Google Drive file download subsystem.

Houses DriveDownloader - responsible for streaming chunked download,
atomic file placement, Windows/OneDrive retry, partial-file cleanup,
and download progress tracking.

Extracted from DriveTrashRecoveryTool (gdrive_recover.py) as part of
the ongoing modularisation effort (issue #853).
"""

import os
import sys
import time
import logging
from pathlib import Path
from threading import Lock

from gdrive_constants import DOWNLOAD_CHUNK_BYTES
from gdrive_models import RecoveryItem

try:
    from googleapiclient.http import MediaIoBaseDownload
    from googleapiclient.errors import HttpError
except ImportError:
    print("ERROR: Required Google API libraries not installed.")
    print(
        "Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib"
    )
    sys.exit(1)


class DriveDownloader:
    """Manages file download from Google Drive.

    Owns the full download lifecycle for DriveTrashRecoveryTool:
    - Streaming chunked download via MediaIoBaseDownload
    - Atomic file placement (temp → final path)
    - Windows/OneDrive-safe replace with retries
    - Partial-file cleanup on failure
    - Download progress tracking
    """

    def __init__(
        self,
        args,
        logger: logging.Logger,
        rate_limiter,
        auth,
        stats: dict,
        stats_lock: Lock,
    ):
        self.args = args
        self.logger = logger
        self.rate_limiter = rate_limiter
        self.auth = auth
        self.stats = stats
        self.stats_lock = stats_lock

    def download(self, item: RecoveryItem) -> bool:
        """Download item to item.target_path. Returns True on success.

        When ``--skip-existing`` is set and the target path already resolves
        to a regular file, no bytes are written: the item is marked as
        successfully downloaded so that per-step state advances and the
        post-restore step still runs, and ``stats["skipped_existing"]`` is
        incremented for the run summary.

        The check uses ``Path.is_file()`` rather than ``Path.exists()`` so a
        directory or other non-file entry at the same path does not trigger
        a silent skip — that would otherwise mark the item complete and let
        the post-restore policy (notably ``delete``) act on the Drive file
        without any local copy ever existing. Non-file collisions fall
        through to the normal download path so the error surfaces.
        """
        if getattr(self.args, "skip_existing", False):
            target = Path(item.target_path)
            if target.is_file():
                item.status = "downloaded"
                with self.stats_lock:
                    self.stats["skipped_existing"] += 1
                self.logger.info("Skipped existing file (--skip-existing): %s", item.target_path)
                return True
        return self._download_file(item)

    def _atomic_replace_with_retry(
        self, src: Path, dst: Path, attempts: int = 60, sleep_s: float = 0.5
    ) -> bool:
        """
        Windows/OneDrive-safe replace with retries.
        Retries when the destination (or source) is temporarily locked by another process.
        """
        last_err = None
        for _ in range(max(1, attempts)):
            try:
                # Best-effort: if dst exists, try to remove it first (it may be a 0-byte OneDrive stub)
                if dst.exists():
                    try:
                        dst.unlink()
                    except Exception:
                        pass
                os.replace(src, dst)  # atomic on same volume
                return True
            except PermissionError as e:
                # Windows/OneDrive often yields WinError 32 here; back off and retry
                last_err = e
            except OSError as e:
                # Treat sharing violations the same way
                if getattr(e, "winerror", None) == 32:
                    last_err = e
                else:
                    raise
            time.sleep(sleep_s)
        if last_err:
            self.logger.error(f"Atomic replace failed after retries: {last_err}")
        return False

    def _download_with_downloader(self, downloader, item, show_progress=True):
        """Download using MediaIoBaseDownload, with optional progress printing."""
        done = False
        last_print = 0.0
        while not done:
            self.rate_limiter.wait()
            status, done = downloader.next_chunk()
            now = time.time()
            if (
                show_progress
                and status
                and (self.args.verbose > 0)
                and (now - last_print > 1.0 or done)
            ):
                pct = int(status.progress() * 100)
                print(f"  ↳ downloading {item.name[:40]} … {pct}%")
                last_print = now

    def _handle_download_success(self, item):
        item.status = "downloaded"
        with self.stats_lock:
            self.stats["downloaded"] += 1

    def _handle_download_failure(self, item, msg):
        item.status = "failed"
        item.error_message = msg
        with self.stats_lock:
            self.stats["errors"] += 1
        self.logger.error(msg)

    def _cleanup_partial_file(self, partial):
        try:
            if partial.exists():
                partial.unlink()
        except Exception:
            pass

    def _download_direct(self, item: RecoveryItem, request, target: Path) -> bool:
        try:
            with open(target, "wb") as fh:
                downloader = MediaIoBaseDownload(fh, request, chunksize=DOWNLOAD_CHUNK_BYTES)
                self._download_with_downloader(downloader, item)
            self._handle_download_success(item)
            return True
        except Exception as e:
            self._handle_download_failure(item, f"Download error: {e}")
            return False

    def _download_via_partial(self, item: RecoveryItem, request, target: Path) -> bool:
        partial = Path(str(target) + ".partial")
        try:
            with open(partial, "wb") as fh:
                downloader = MediaIoBaseDownload(fh, request, chunksize=DOWNLOAD_CHUNK_BYTES)
                self._download_with_downloader(downloader, item)
        except Exception as e:
            self._handle_download_failure(item, f"Download error: {e}")
            return False
        # File handle is closed; safe to rename on Windows
        try:
            if not self._atomic_replace_with_retry(partial, target):
                raise PermissionError(
                    f"Could not move '{partial}' to '{target}' "
                    f"(destination locked by another process)"
                )
            self._handle_download_success(item)
            return True
        except Exception as e:
            self._handle_download_failure(item, f"Download error: {e}")
            return False

    def _download_file(self, item: RecoveryItem) -> bool:
        success = False
        try:
            service = self.auth._get_service()
            request = service.files().get_media(fileId=item.id)
            target = Path(item.target_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            if getattr(self.args, "direct_download", False):
                success = self._download_direct(item, request, target)
            else:
                success = self._download_via_partial(item, request, target)
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            detail = getattr(e, "content", b"")
            detail = detail.decode(errors="ignore") if hasattr(detail, "decode") else str(e)
            self._handle_download_failure(
                item, f"files.get_media(fileId={item.id}) failed: HTTP {status}: {detail}"
            )
        except Exception as e:
            self._handle_download_failure(item, f"Download error: {e}")
        finally:
            if not getattr(self.args, "direct_download", False):
                partial = Path(str(Path(item.target_path)) + ".partial")
                if not success:
                    self._cleanup_partial_file(partial)
        return success
