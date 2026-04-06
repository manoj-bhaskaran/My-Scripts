"""
Processed-file tracking subsystem for crop_colours.

This module owns the platform-specific file locking, the `.processed_images`
tracking file, and the two public functions used to query and update the set
of already-processed images.  It has no dependency on image-processing logic
or CLI argument handling and can therefore be unit-tested in isolation.

Public API
----------
get_processed_set(folder)
    Load the set of absolute paths that were successfully processed in a
    previous run.

mark_processed(folder, path)
    Append a successfully processed absolute path to the tracking file.
"""

from __future__ import annotations

import os
import threading

# --- Logging setup -----------------------------------------------------------

try:
    import python_logging_framework as plog  # type: ignore

    logger = plog.get_logger("crop_colours._tracking")
    _using_plog = True
except Exception:
    import logging

    logger = logging.getLogger("crop_colours._tracking")
    _handler = logging.StreamHandler()
    _formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s")
    _handler.setFormatter(_formatter)
    logger.addHandler(_handler)
    logger.setLevel(logging.INFO)
    _using_plog = False

# --- Platform-specific file locking -----------------------------------------

try:
    import fcntl

    _has_unix_locking = True
except ImportError:
    _has_unix_locking = False

try:
    import msvcrt

    _has_windows_locking = True
except ImportError:
    _has_windows_locking = False

# --- Threading lock ----------------------------------------------------------

# Coarse-grained in-process lock that serialises all reads and writes to the
# .processed_images tracking file.  Platform-level file locking (fcntl /
# msvcrt) provides additional protection against concurrent *processes*.
_processed_file_lock = threading.Lock()


# --- Public functions --------------------------------------------------------


def get_processed_set(folder: str) -> set[str]:
    """
    Load set of already-processed files from .processed_images tracking file.

    Returns absolute paths of files that were successfully processed in previous runs.
    Creates the tracking file if it doesn't exist. Handles read errors gracefully.
    """
    processed_file = os.path.join(folder, ".processed_images")
    processed: set[str] = set()

    with _processed_file_lock:
        if not os.path.exists(processed_file):
            # Create empty tracking file
            try:
                with open(processed_file, "w", encoding="utf-8"):
                    pass  # Create empty file for tracking processed images
            except Exception as e:
                logger.debug("Could not create processed tracking file: %s", e)
                return processed

        try:
            with open(processed_file, "r", encoding="utf-8") as f:
                for line in f:
                    path = line.strip()
                    if path and os.path.exists(path):
                        processed.add(path)
            logger.debug(
                "Loaded %d previously processed images from %s", len(processed), processed_file
            )
        except Exception as e:
            logger.warning("Could not read processed tracking file %s: %s", processed_file, e)
    return processed


def mark_processed(folder: str, path: str) -> None:
    """
    Append a successfully processed file path to .processed_images tracking file.

    Thread-safe implementation using file locking to prevent corruption from
    concurrent worker threads. Used to prevent reprocessing the same files
    in subsequent runs.
    """
    processed_file = os.path.join(folder, ".processed_images")

    with _processed_file_lock:
        try:
            with open(processed_file, "a", encoding="utf-8") as f:
                # Platform-specific file locking for additional safety
                if _has_unix_locking:
                    try:
                        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                    except (OSError, AttributeError):
                        pass  # Fallback to thread lock only
                elif _has_windows_locking:
                    try:
                        msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
                    except (OSError, AttributeError):
                        pass  # Fallback to thread lock only

                f.write(f"{path}\n")
                f.flush()  # Ensure immediate write
        except Exception as e:
            logger.debug("Could not update processed tracking file: %s", e)
