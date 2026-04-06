"""Tests for the DriveDownloader class in gdrive_download.py."""

import sys
from pathlib import Path
from threading import Lock
from types import SimpleNamespace
from unittest.mock import MagicMock, patch, call

import pytest

# Ensure the cloud module path is importable
cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

import gdrive_download
from gdrive_download import DriveDownloader
from gdrive_models import RecoveryItem


def _make_downloader(direct_download=False, verbose=0):
    """Build a DriveDownloader with lightweight mock dependencies."""
    args = SimpleNamespace(verbose=verbose, direct_download=direct_download)
    logger = MagicMock()
    rate_limiter = MagicMock()
    auth = MagicMock()
    stats = {"downloaded": 0, "errors": 0}
    stats_lock = Lock()
    return DriveDownloader(args, logger, rate_limiter, auth, stats, stats_lock)


def _make_item(tmp_path, name="file.txt"):
    """Return a RecoveryItem with target_path inside tmp_path."""
    target = str(tmp_path / name)
    return RecoveryItem(
        id="file-id-1",
        name=name,
        size=1024,
        mime_type="text/plain",
        created_time="",
        will_recover=False,
        will_download=True,
        target_path=target,
    )


# ---------------------------------------------------------------------------
# Success path (default: partial → atomic replace)
# ---------------------------------------------------------------------------

def test_download_success_path(tmp_path, monkeypatch):
    """download() returns True and sets status='downloaded' on success."""
    downloader = _make_downloader()
    item = _make_item(tmp_path)

    # Stub MediaIoBaseDownload to complete in one chunk
    fake_dl = MagicMock()
    fake_dl.next_chunk.return_value = (MagicMock(progress=lambda: 1.0), True)
    monkeypatch.setattr(gdrive_download, "MediaIoBaseDownload", lambda fh, req, chunksize: fake_dl)

    # auth returns a fake service
    fake_service = MagicMock()
    fake_service.files.return_value.get_media.return_value = MagicMock()
    downloader.auth._get_service.return_value = fake_service

    result = downloader.download(item)

    assert result is True
    assert item.status == "downloaded"
    assert downloader.stats["downloaded"] == 1
    assert downloader.stats["errors"] == 0
    # partial file should have been moved (not left behind)
    partial = Path(str(tmp_path / "file.txt") + ".partial")
    assert not partial.exists()


# ---------------------------------------------------------------------------
# direct_download flag
# ---------------------------------------------------------------------------

def test_download_direct_download_flag(tmp_path, monkeypatch):
    """With direct_download=True the file is written directly (no .partial)."""
    downloader = _make_downloader(direct_download=True)
    item = _make_item(tmp_path)

    fake_dl = MagicMock()
    fake_dl.next_chunk.return_value = (None, True)
    monkeypatch.setattr(gdrive_download, "MediaIoBaseDownload", lambda fh, req, chunksize: fake_dl)

    fake_service = MagicMock()
    fake_service.files.return_value.get_media.return_value = MagicMock()
    downloader.auth._get_service.return_value = fake_service

    result = downloader.download(item)

    assert result is True
    assert item.status == "downloaded"
    # No partial file should ever appear
    partial = Path(str(tmp_path / "file.txt") + ".partial")
    assert not partial.exists()


# ---------------------------------------------------------------------------
# Partial cleanup on failure
# ---------------------------------------------------------------------------

def test_partial_cleanup_on_failure(tmp_path, monkeypatch):
    """On download failure the .partial file is removed."""
    downloader = _make_downloader()
    item = _make_item(tmp_path)

    def exploding_downloader(fh, req, chunksize):
        raise RuntimeError("network error")

    monkeypatch.setattr(gdrive_download, "MediaIoBaseDownload", exploding_downloader)

    fake_service = MagicMock()
    fake_service.files.return_value.get_media.return_value = MagicMock()
    downloader.auth._get_service.return_value = fake_service

    result = downloader.download(item)

    assert result is False
    assert item.status == "failed"
    assert downloader.stats["errors"] == 1
    # partial must be cleaned up
    partial = Path(str(tmp_path / "file.txt") + ".partial")
    assert not partial.exists()


# ---------------------------------------------------------------------------
# HttpError during download
# ---------------------------------------------------------------------------

def test_http_error_during_download(tmp_path, monkeypatch):
    """HttpError raised by get_media is caught and treated as failure."""
    from googleapiclient.errors import HttpError

    downloader = _make_downloader()
    item = _make_item(tmp_path)

    fake_resp = MagicMock()
    fake_resp.status = 403
    http_err = HttpError(fake_resp, b"forbidden")

    fake_service = MagicMock()
    fake_service.files.return_value.get_media.side_effect = http_err
    downloader.auth._get_service.return_value = fake_service

    result = downloader.download(item)

    assert result is False
    assert item.status == "failed"
    assert "HTTP 403" in item.error_message
    assert downloader.stats["errors"] == 1


# ---------------------------------------------------------------------------
# Atomic replace with retry
# ---------------------------------------------------------------------------

def test_atomic_replace_with_retry_success(tmp_path):
    """_atomic_replace_with_retry returns True when os.replace succeeds."""
    downloader = _make_downloader()
    src = tmp_path / "src.partial"
    dst = tmp_path / "dst.txt"
    src.write_bytes(b"hello")

    result = downloader._atomic_replace_with_retry(src, dst, attempts=1)

    assert result is True
    assert dst.read_bytes() == b"hello"
    assert not src.exists()


def test_atomic_replace_with_retry_permission_error(tmp_path, monkeypatch):
    """_atomic_replace_with_retry retries on PermissionError and returns False after exhausting."""
    downloader = _make_downloader()
    src = tmp_path / "src.partial"
    dst = tmp_path / "dst.txt"
    src.write_bytes(b"x")

    monkeypatch.setattr(gdrive_download.os, "replace", MagicMock(side_effect=PermissionError("locked")))
    monkeypatch.setattr(gdrive_download.time, "sleep", MagicMock())

    result = downloader._atomic_replace_with_retry(src, dst, attempts=3, sleep_s=0)

    assert result is False
    assert gdrive_download.time.sleep.call_count == 3


def test_atomic_replace_with_retry_existing_dst_removed(tmp_path):
    """_atomic_replace_with_retry removes an existing dst before replacing."""
    downloader = _make_downloader()
    src = tmp_path / "src.partial"
    dst = tmp_path / "dst.txt"
    src.write_bytes(b"new")
    dst.write_bytes(b"old")

    result = downloader._atomic_replace_with_retry(src, dst, attempts=1)

    assert result is True
    assert dst.read_bytes() == b"new"


# ---------------------------------------------------------------------------
# DriveDownloader is independently importable
# ---------------------------------------------------------------------------

def test_drive_downloader_independent_import(tmp_path):
    """DriveDownloader can be constructed without DriveTrashRecoveryTool."""
    d = _make_downloader()
    assert isinstance(d, DriveDownloader)
    assert hasattr(d, "download")
    assert callable(d.download)
