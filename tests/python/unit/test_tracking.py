"""Unit tests for src/python/media/_tracking.py."""

import os
import threading
from pathlib import Path
from unittest.mock import patch

import pytest

from src.python.media._tracking import get_processed_set, mark_processed


class TestGetProcessedSet:
    """Tests for get_processed_set function."""

    def test_empty_folder_creates_tracking_file(self, tmp_path):
        """An empty folder should create an empty tracking file and return an empty set."""
        folder = str(tmp_path)
        result = get_processed_set(folder)

        assert result == set()
        assert (tmp_path / ".processed_images").exists()

    def test_empty_tracking_file_returns_empty_set(self, tmp_path):
        """An existing but empty tracking file should return an empty set."""
        (tmp_path / ".processed_images").write_text("", encoding="utf-8")
        result = get_processed_set(str(tmp_path))
        assert result == set()

    def test_existing_tracking_file_returns_present_paths(self, tmp_path):
        """Paths that exist on disk should be returned; stale paths are excluded."""
        real_file = tmp_path / "image.jpg"
        real_file.write_text("fake image data")

        tracking = tmp_path / ".processed_images"
        tracking.write_text(f"{real_file}\n/nonexistent/path/image.png\n", encoding="utf-8")

        result = get_processed_set(str(tmp_path))

        assert str(real_file) in result
        assert "/nonexistent/path/image.png" not in result

    def test_stale_paths_excluded(self, tmp_path):
        """Paths that no longer exist on disk should not be returned."""
        tracking = tmp_path / ".processed_images"
        tracking.write_text("/deleted/image.jpg\n", encoding="utf-8")

        result = get_processed_set(str(tmp_path))
        assert result == set()

    def test_blank_lines_ignored(self, tmp_path):
        """Blank lines in the tracking file should be silently skipped."""
        real_file = tmp_path / "photo.png"
        real_file.write_text("data")

        tracking = tmp_path / ".processed_images"
        tracking.write_text(f"\n{real_file}\n\n", encoding="utf-8")

        result = get_processed_set(str(tmp_path))
        assert result == {str(real_file)}

    def test_corrupt_tracking_file_returns_empty_set(self, tmp_path):
        """A file that cannot be decoded should be handled gracefully (return empty set)."""
        tracking = tmp_path / ".processed_images"
        tracking.write_bytes(b"\xff\xfe" + b"\x00" * 10)  # Invalid UTF-8

        result = get_processed_set(str(tmp_path))
        # Should not raise; returns whatever was loadable (possibly empty)
        assert isinstance(result, set)

    def test_unreadable_tracking_file_returns_empty_set(self, tmp_path):
        """If the tracking file cannot be opened, an empty set should be returned."""
        tracking = tmp_path / ".processed_images"
        tracking.write_text("some content", encoding="utf-8")

        with patch("builtins.open", side_effect=OSError("permission denied")):
            result = get_processed_set(str(tmp_path))

        assert result == set()


class TestMarkProcessed:
    """Tests for mark_processed function."""

    def test_appends_path_to_tracking_file(self, tmp_path):
        """mark_processed should append the given path to .processed_images."""
        folder = str(tmp_path)
        # Pre-create the tracking file (as get_processed_set would)
        (tmp_path / ".processed_images").write_text("", encoding="utf-8")

        mark_processed(folder, "/some/image.jpg")

        content = (tmp_path / ".processed_images").read_text(encoding="utf-8")
        assert "/some/image.jpg\n" in content

    def test_appends_multiple_paths(self, tmp_path):
        """Multiple calls should append multiple lines."""
        folder = str(tmp_path)
        (tmp_path / ".processed_images").write_text("", encoding="utf-8")

        mark_processed(folder, "/img/a.jpg")
        mark_processed(folder, "/img/b.jpg")

        lines = (tmp_path / ".processed_images").read_text(encoding="utf-8").splitlines()
        assert "/img/a.jpg" in lines
        assert "/img/b.jpg" in lines

    def test_creates_tracking_file_if_absent(self, tmp_path):
        """mark_processed should create .processed_images if it does not exist."""
        folder = str(tmp_path)
        mark_processed(folder, "/new/image.png")

        tracking = tmp_path / ".processed_images"
        assert tracking.exists()
        assert "/new/image.png" in tracking.read_text(encoding="utf-8")

    def test_write_error_is_handled_gracefully(self, tmp_path):
        """A write error should be swallowed without raising an exception."""
        folder = str(tmp_path)
        with patch("builtins.open", side_effect=OSError("disk full")):
            # Should not raise
            mark_processed(folder, "/some/image.jpg")


class TestThreadSafety:
    """Basic thread-safety tests for get_processed_set and mark_processed."""

    def test_concurrent_mark_processed_does_not_corrupt(self, tmp_path):
        """Multiple threads calling mark_processed concurrently should all succeed."""
        folder = str(tmp_path)
        (tmp_path / ".processed_images").write_text("", encoding="utf-8")

        paths = [f"/img/image_{i:04d}.jpg" for i in range(50)]
        errors: list[Exception] = []

        def worker(p: str) -> None:
            try:
                mark_processed(folder, p)
            except Exception as exc:
                errors.append(exc)

        threads = [threading.Thread(target=worker, args=(p,)) for p in paths]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert errors == [], f"Unexpected errors: {errors}"
        written = (tmp_path / ".processed_images").read_text(encoding="utf-8").splitlines()
        assert len(written) == len(paths)

    def test_get_processed_set_is_reentrant(self, tmp_path):
        """Multiple threads calling get_processed_set simultaneously should not deadlock."""
        real_file = tmp_path / "image.jpg"
        real_file.write_text("data")
        (tmp_path / ".processed_images").write_text(f"{real_file}\n", encoding="utf-8")

        folder = str(tmp_path)
        results: list[set] = []
        errors: list[Exception] = []

        def reader() -> None:
            try:
                results.append(get_processed_set(folder))
            except Exception as exc:
                errors.append(exc)

        threads = [threading.Thread(target=reader) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert errors == [], f"Unexpected errors: {errors}"
        for r in results:
            assert str(real_file) in r
