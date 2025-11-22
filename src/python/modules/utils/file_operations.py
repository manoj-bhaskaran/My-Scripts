"""File operations with retry logic and utilities.

This module provides file operation functions with built-in retry logic
to handle transient failures like file locks or network issues.
"""

import shutil
import time
from pathlib import Path
from typing import Optional, Union, Callable
import logging

logger = logging.getLogger(__name__)


def copy_with_retry(
    source: Union[str, Path],
    destination: Union[str, Path],
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
) -> bool:
    """Copy file with automatic retry on failure using exponential backoff.

    Args:
        source: Source file path (must exist).
        destination: Destination file path.
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 2.0).
        max_backoff: Maximum backoff delay in seconds (default: 60.0).

    Returns:
        True if copy succeeded.

    Raises:
        FileNotFoundError: If source file doesn't exist.
        IOError: If copy fails after all retries.

    Example:
        >>> copy_with_retry("source.txt", "dest.txt")
        True

        >>> copy_with_retry(Path("data.csv"), Path("backup/data.csv"), max_retries=5)
        True
    """
    source_path = Path(source)
    dest_path = Path(destination)

    if not source_path.exists():
        raise FileNotFoundError(f"Source file not found: {source}")

    for attempt in range(max_retries):
        try:
            # Ensure destination directory exists
            dest_path.parent.mkdir(parents=True, exist_ok=True)

            # Copy the file
            shutil.copy2(source_path, dest_path)

            if attempt > 0:
                logger.info(
                    f"Succeeded copying '{source}' to '{destination}' "
                    f"after {attempt} retry attempt(s)"
                )

            return True

        except Exception as e:
            if attempt >= max_retries - 1:
                logger.error(
                    f"Failed to copy '{source}' to '{destination}' "
                    f"after {attempt + 1} attempt(s): {e}"
                )
                raise IOError(f"Failed to copy file after {max_retries} attempts: {e}") from e

            # Calculate exponential backoff delay
            delay = min(retry_delay * (2**attempt), max_backoff)

            logger.warning(
                f"Attempt {attempt + 1} failed to copy '{source}': {e}. "
                f"Retrying in {delay:.1f} second(s)..."
            )

            time.sleep(delay)

    return False


def move_with_retry(
    source: Union[str, Path],
    destination: Union[str, Path],
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
) -> bool:
    """Move file with automatic retry on failure using exponential backoff.

    Args:
        source: Source file path (must exist).
        destination: Destination file path.
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 2.0).
        max_backoff: Maximum backoff delay in seconds (default: 60.0).

    Returns:
        True if move succeeded.

    Raises:
        FileNotFoundError: If source file doesn't exist.
        IOError: If move fails after all retries.

    Example:
        >>> move_with_retry("temp.txt", "archive/temp.txt")
        True
    """
    source_path = Path(source)
    dest_path = Path(destination)

    if not source_path.exists():
        raise FileNotFoundError(f"Source file not found: {source}")

    for attempt in range(max_retries):
        try:
            # Ensure destination directory exists
            dest_path.parent.mkdir(parents=True, exist_ok=True)

            # Move the file
            shutil.move(str(source_path), str(dest_path))

            if attempt > 0:
                logger.info(
                    f"Succeeded moving '{source}' to '{destination}' "
                    f"after {attempt} retry attempt(s)"
                )

            return True

        except Exception as e:
            if attempt >= max_retries - 1:
                logger.error(
                    f"Failed to move '{source}' to '{destination}' "
                    f"after {attempt + 1} attempt(s): {e}"
                )
                raise IOError(f"Failed to move file after {max_retries} attempts: {e}") from e

            delay = min(retry_delay * (2**attempt), max_backoff)

            logger.warning(
                f"Attempt {attempt + 1} failed to move '{source}': {e}. "
                f"Retrying in {delay:.1f} second(s)..."
            )

            time.sleep(delay)

    return False


def remove_with_retry(
    path: Union[str, Path],
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
) -> bool:
    """Remove file with automatic retry on failure.

    Args:
        path: Path to the file to remove.
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 2.0).
        max_backoff: Maximum backoff delay in seconds (default: 60.0).

    Returns:
        True if removal succeeded.

    Raises:
        IOError: If removal fails after all retries.

    Example:
        >>> remove_with_retry("temp.txt")
        True
    """
    file_path = Path(path)

    if not file_path.exists():
        logger.debug(f"Path does not exist: {path}")
        return True

    for attempt in range(max_retries):
        try:
            file_path.unlink()

            if attempt > 0:
                logger.info(f"Succeeded removing '{path}' after {attempt} retry attempt(s)")

            return True

        except Exception as e:
            if attempt >= max_retries - 1:
                logger.error(f"Failed to remove '{path}' after {attempt + 1} attempt(s): {e}")
                raise IOError(f"Failed to remove file after {max_retries} attempts: {e}") from e

            delay = min(retry_delay * (2**attempt), max_backoff)

            logger.warning(
                f"Attempt {attempt + 1} failed to remove '{path}': {e}. "
                f"Retrying in {delay:.1f} second(s)..."
            )

            time.sleep(delay)

    return False


def is_writable(path: Union[str, Path]) -> bool:
    """Check if path is writable.

    Creates the directory if it doesn't exist and tests write permissions
    by attempting to create a temporary file.

    Args:
        path: Path to the directory to test.

    Returns:
        True if path is writable, False otherwise.

    Example:
        >>> is_writable("/tmp")
        True

        >>> is_writable("/root")  # Without sudo
        False
    """
    dir_path = Path(path)

    try:
        # Create directory if it doesn't exist
        dir_path.mkdir(parents=True, exist_ok=True)

        # Test write permissions with temporary file
        test_file = dir_path / f".write_test_{int(time.time() * 1000000)}"

        try:
            test_file.write_text("test")
            test_file.unlink()
            return True
        except Exception:
            return False

    except Exception:
        return False


def ensure_directory(path: Union[str, Path]) -> Path:
    """Ensure directory exists, creating it if necessary.

    Args:
        path: Path to the directory.

    Returns:
        Path object for the directory.

    Raises:
        IOError: If directory cannot be created.

    Example:
        >>> ensure_directory("logs/app")
        PosixPath('logs/app')
    """
    dir_path = Path(path)

    try:
        dir_path.mkdir(parents=True, exist_ok=True)
        return dir_path
    except Exception as e:
        raise IOError(f"Failed to create directory '{path}': {e}") from e


def get_file_size(path: Union[str, Path]) -> int:
    """Get file size in bytes.

    Args:
        path: Path to the file.

    Returns:
        File size in bytes, or 0 if file doesn't exist.

    Example:
        >>> size = get_file_size("data.txt")
        >>> print(f"Size: {size} bytes")
        Size: 1024 bytes
    """
    file_path = Path(path)

    if not file_path.exists():
        return 0

    try:
        return file_path.stat().st_size
    except Exception as e:
        logger.warning(f"Failed to get size of '{path}': {e}")
        return 0


def safe_write_text(
    path: str | Path, content: str, encoding: str = "utf-8", atomic: bool = True
) -> bool:
    """Write text to file safely with optional atomic write.

    Args:
        path: Path to the file.
        content: Text content to write.
        encoding: File encoding (default: "utf-8").
        atomic: Use atomic write (write to temp file, then rename) (default: True).

    Returns:
        True if write succeeded.

    Raises:
        IOError: If write fails.

    Example:
        >>> safe_write_text("config.txt", "key=value")
        True

        >>> safe_write_text("data.json", json_data, atomic=True)
        True
    """
    file_path = Path(path)

    try:
        # Ensure parent directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)

        if atomic:
            # Atomic write: write to temp file, then rename
            temp_path = file_path.with_suffix(file_path.suffix + ".tmp")
            temp_path.write_text(content, encoding=encoding)
            temp_path.replace(file_path)
        else:
            # Direct write
            file_path.write_text(content, encoding=encoding)

        return True

    except Exception as e:
        raise IOError(f"Failed to write to '{path}': {e}") from e


def safe_append_text(
    path: Union[str, Path],
    content: str,
    encoding: str = "utf-8",
    max_retries: int = 3,
    retry_delay: float = 1.0,
) -> bool:
    """Append text to file with retry logic.

    Args:
        path: Path to the file.
        content: Text content to append.
        encoding: File encoding (default: "utf-8").
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 1.0).

    Returns:
        True if append succeeded.

    Raises:
        IOError: If append fails after all retries.

    Example:
        >>> safe_append_text("app.log", "2025-11-20 INFO: Started\\n")
        True
    """
    file_path = Path(path)

    # Ensure parent directory exists
    file_path.parent.mkdir(parents=True, exist_ok=True)

    for attempt in range(max_retries):
        try:
            with open(file_path, "a", encoding=encoding) as f:
                f.write(content)

            if attempt > 0:
                logger.debug(f"Succeeded appending to '{path}' after {attempt} retry attempt(s)")

            return True

        except Exception as e:
            if attempt >= max_retries - 1:
                raise IOError(f"Failed to append to file after {max_retries} attempts: {e}") from e

            delay = retry_delay * (2**attempt)

            logger.debug(
                f"Attempt {attempt + 1} failed to append to '{path}': {e}. "
                f"Retrying in {delay:.1f} second(s)..."
            )

            time.sleep(delay)

    return False


__all__ = [
    "copy_with_retry",
    "move_with_retry",
    "remove_with_retry",
    "is_writable",
    "ensure_directory",
    "get_file_size",
    "safe_write_text",
    "safe_append_text",
]
