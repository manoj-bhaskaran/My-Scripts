"""Unit tests for file_operations module."""

import pytest
import tempfile
import time
from pathlib import Path
from src.python.modules.utils.file_operations import (
    copy_with_retry,
    move_with_retry,
    remove_with_retry,
    is_writable,
    ensure_directory,
    get_file_size,
    safe_write_text,
    safe_append_text,
)


class TestCopyWithRetry:
    """Tests for copy_with_retry function."""

    def test_copy_file_success(self, tmp_path):
        """Test successful file copy."""
        source = tmp_path / "source.txt"
        dest = tmp_path / "dest.txt"

        source.write_text("test content")

        result = copy_with_retry(source, dest)

        assert result is True
        assert dest.exists()
        assert dest.read_text() == "test content"

    def test_copy_nonexistent_file(self, tmp_path):
        """Test copying nonexistent file raises FileNotFoundError."""
        source = tmp_path / "nonexistent.txt"
        dest = tmp_path / "dest.txt"

        with pytest.raises(FileNotFoundError):
            copy_with_retry(source, dest)

    def test_copy_creates_destination_directory(self, tmp_path):
        """Test copy creates destination directory if needed."""
        source = tmp_path / "source.txt"
        dest = tmp_path / "subdir" / "dest.txt"

        source.write_text("test content")

        result = copy_with_retry(source, dest)

        assert result is True
        assert dest.exists()
        assert dest.read_text() == "test content"

    def test_copy_with_path_objects(self, tmp_path):
        """Test copy with Path objects."""
        source = Path(tmp_path) / "source.txt"
        dest = Path(tmp_path) / "dest.txt"

        source.write_text("test content")

        result = copy_with_retry(source, dest)

        assert result is True
        assert dest.exists()


class TestMoveWithRetry:
    """Tests for move_with_retry function."""

    def test_move_file_success(self, tmp_path):
        """Test successful file move."""
        source = tmp_path / "source.txt"
        dest = tmp_path / "dest.txt"

        source.write_text("test content")

        result = move_with_retry(source, dest)

        assert result is True
        assert dest.exists()
        assert not source.exists()
        assert dest.read_text() == "test content"

    def test_move_nonexistent_file(self, tmp_path):
        """Test moving nonexistent file raises FileNotFoundError."""
        source = tmp_path / "nonexistent.txt"
        dest = tmp_path / "dest.txt"

        with pytest.raises(FileNotFoundError):
            move_with_retry(source, dest)

    def test_move_creates_destination_directory(self, tmp_path):
        """Test move creates destination directory if needed."""
        source = tmp_path / "source.txt"
        dest = tmp_path / "subdir" / "dest.txt"

        source.write_text("test content")

        result = move_with_retry(source, dest)

        assert result is True
        assert dest.exists()
        assert not source.exists()


class TestRemoveWithRetry:
    """Tests for remove_with_retry function."""

    def test_remove_file_success(self, tmp_path):
        """Test successful file removal."""
        file_path = tmp_path / "test.txt"
        file_path.write_text("test content")

        result = remove_with_retry(file_path)

        assert result is True
        assert not file_path.exists()

    def test_remove_nonexistent_file(self, tmp_path):
        """Test removing nonexistent file returns True."""
        file_path = tmp_path / "nonexistent.txt"

        result = remove_with_retry(file_path)

        assert result is True


class TestIsWritable:
    """Tests for is_writable function."""

    def test_writable_directory(self, tmp_path):
        """Test writable directory returns True."""
        result = is_writable(tmp_path)
        assert result is True

    def test_creates_directory_if_missing(self, tmp_path):
        """Test creates directory if it doesn't exist."""
        new_dir = tmp_path / "newdir"

        result = is_writable(new_dir)

        assert result is True
        assert new_dir.exists()


class TestEnsureDirectory:
    """Tests for ensure_directory function."""

    def test_create_directory(self, tmp_path):
        """Test creates directory."""
        new_dir = tmp_path / "newdir"

        result = ensure_directory(new_dir)

        assert result == new_dir
        assert new_dir.exists()
        assert new_dir.is_dir()

    def test_create_nested_directory(self, tmp_path):
        """Test creates nested directories."""
        nested_dir = tmp_path / "a" / "b" / "c"

        result = ensure_directory(nested_dir)

        assert result == nested_dir
        assert nested_dir.exists()

    def test_existing_directory(self, tmp_path):
        """Test with existing directory."""
        result = ensure_directory(tmp_path)

        assert result == tmp_path
        assert tmp_path.exists()


class TestGetFileSize:
    """Tests for get_file_size function."""

    def test_get_size_of_existing_file(self, tmp_path):
        """Test gets size of existing file."""
        file_path = tmp_path / "test.txt"
        content = "test content"
        file_path.write_text(content)

        size = get_file_size(file_path)

        assert size == len(content.encode("utf-8"))

    def test_get_size_of_nonexistent_file(self, tmp_path):
        """Test nonexistent file returns 0."""
        file_path = tmp_path / "nonexistent.txt"

        size = get_file_size(file_path)

        assert size == 0


class TestSafeWriteText:
    """Tests for safe_write_text function."""

    def test_write_text_success(self, tmp_path):
        """Test successful text write."""
        file_path = tmp_path / "test.txt"
        content = "test content"

        result = safe_write_text(file_path, content)

        assert result is True
        assert file_path.exists()
        assert file_path.read_text() == content

    def test_write_text_creates_directory(self, tmp_path):
        """Test creates parent directory if needed."""
        file_path = tmp_path / "subdir" / "test.txt"
        content = "test content"

        result = safe_write_text(file_path, content)

        assert result is True
        assert file_path.exists()

    def test_write_text_atomic(self, tmp_path):
        """Test atomic write."""
        file_path = tmp_path / "test.txt"
        content = "test content"

        result = safe_write_text(file_path, content, atomic=True)

        assert result is True
        assert file_path.exists()
        assert file_path.read_text() == content

    def test_write_text_non_atomic(self, tmp_path):
        """Test non-atomic write."""
        file_path = tmp_path / "test.txt"
        content = "test content"

        result = safe_write_text(file_path, content, atomic=False)

        assert result is True
        assert file_path.exists()


class TestSafeAppendText:
    """Tests for safe_append_text function."""

    def test_append_to_new_file(self, tmp_path):
        """Test appending to new file."""
        file_path = tmp_path / "test.txt"
        content = "line 1\n"

        result = safe_append_text(file_path, content)

        assert result is True
        assert file_path.exists()
        assert file_path.read_text() == content

    def test_append_to_existing_file(self, tmp_path):
        """Test appending to existing file."""
        file_path = tmp_path / "test.txt"
        file_path.write_text("line 1\n")

        result = safe_append_text(file_path, "line 2\n")

        assert result is True
        assert file_path.read_text() == "line 1\nline 2\n"

    def test_append_multiple_times(self, tmp_path):
        """Test multiple appends."""
        file_path = tmp_path / "test.txt"

        safe_append_text(file_path, "line 1\n")
        safe_append_text(file_path, "line 2\n")
        safe_append_text(file_path, "line 3\n")

        assert file_path.read_text() == "line 1\nline 2\nline 3\n"
