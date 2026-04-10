"""Core image-processing operations for crop_colours.

This module contains the pure image-processing functions extracted from
``crop_colours.py``.  These have no dependency on CLI arguments, file
tracking, or orchestration logic and can therefore be imported, unit-tested,
and reused independently by other scripts in the media package.

Public API
----------
VALID_EXTS
    Set of supported image file extensions.

list_images(folder, recurse)
    Return sorted absolute image paths with valid extensions.

load_image(path, preserve_alpha)
    Load an image with optional alpha channel preservation.

detect_content_bbox(img, ...)
    Compute a bounding box around non-border content.

imwrite_retry(path, img, attempts)
    Write image with limited retries (linear back-off). Returns True/False.

ensure_output_path(...)
    Decide the output path for an input image.

crop_image(img, ...)
    Return cropped image if a bbox is found; otherwise return original.

ProcessingConfig
    Configuration object to reduce parameter count in process_one.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Optional

# --- Logging setup -----------------------------------------------------------

try:
    import python_logging_framework as plog  # type: ignore

    logger = plog.get_logger("crop_colours._image_ops")
    _using_plog = True
except Exception:
    import logging

    logger = logging.getLogger("crop_colours._image_ops")
    _handler = logging.StreamHandler()
    _handler.setFormatter(logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s"))
    logger.addHandler(_handler)
    logger.setLevel(logging.INFO)
    _using_plog = False

# --- cv2 / numpy import guard ------------------------------------------------

try:
    import cv2
    import numpy as np
except Exception as _e:
    logger.error("Failed to import OpenCV (cv2) / numpy: %s", _e)
    sys.exit(2)

# --- Image & crop helpers ----------------------------------------------------

VALID_EXTS = {".png", ".jpg", ".jpeg"}


def list_images(folder: str, recurse: bool = False) -> list[str]:
    """Return sorted absolute image paths with valid extensions. Optionally recurse."""
    root = Path(folder)
    it = root.rglob("*") if recurse else root.iterdir()

    def should_include(path: Path) -> bool:
        """Check if path should be included (exclude Cropped folder)."""
        if not path.is_file() or path.suffix.lower() not in VALID_EXTS:
            return False
        # Exclude any files that are inside a "Cropped" folder
        if "Cropped" in path.parts:
            return False
        return True

    return sorted(str(p.resolve()) for p in it if should_include(p))


def load_image(path: str, preserve_alpha: bool = False) -> "np.ndarray":
    """
    Load an image with optional alpha channel preservation.

    Args:
        path: Path to image file
        preserve_alpha: If True, load with alpha channel intact for transparency detection

    Returns:
        Loaded image as numpy array

    Raises:
        ValueError: If image is corrupt/unsupported
    """
    flags = cv2.IMREAD_UNCHANGED if preserve_alpha else cv2.IMREAD_COLOR
    img = cv2.imread(path, flags)
    if img is None:
        raise ValueError(f"Failed to load image (corrupt/unsupported): {path}")
    return img


def detect_content_bbox(
    img: "np.ndarray",
    low_threshold: int = 5,
    high_threshold: int = 250,
    min_area: int = 256,
    padding: int = 2,
    preserve_alpha: bool = False,
    alpha_threshold: int = 0,
) -> Optional[tuple[int, int, int, int]]:
    """
    Compute a bounding box around non-border content.

    Heuristic:
      - For alpha-enabled images: use alpha channel for transparency detection
      - Otherwise: convert to grayscale and use threshold-based detection
      - Mark as 'content' pixels based on the selected detection method
      - If any content exists and area >= min_area, return bbox with optional padding.
      - Otherwise, return None (no crop).

    Args:
        alpha_threshold: Minimum alpha value to treat as content (0-255). Higher values ignore semi-transparent edges.


    Returns bbox as (y0, y1, x0, x1) in image coordinates, or None.
    """
    # Check for alpha channel support: need 3+ dimensions and 4 channels
    if preserve_alpha and img.ndim >= 3 and img.shape[2] == 4:
        # Use alpha channel for transparency detection
        alpha = img[:, :, 3]
        # Content is where alpha > threshold (configurable transparency cutoff)
        content_mask = alpha > alpha_threshold
    else:
        # Traditional grayscale threshold detection
        if img.ndim == 2:
            # Already grayscale
            gray = img
        elif img.ndim >= 3 and img.shape[2] == 4:
            # Convert BGRA to BGR for grayscale conversion
            img_bgr = cv2.cvtColor(img, cv2.COLOR_BGRA2BGR)
            gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        elif img.ndim >= 3:
            # Standard BGR to grayscale
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            # Fallback for unexpected image formats
            gray = img.astype(np.uint8) if img.dtype != np.uint8 else img

        content_mask = (gray > low_threshold) & (gray < high_threshold)

    if not np.any(content_mask):
        return None

    ys, xs = np.nonzero(content_mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    if (y1 - y0 + 1) * (x1 - x0 + 1) < int(min_area):
        return None

    h, w = img.shape[:2]
    y0 = max(0, y0 - padding)
    x0 = max(0, x0 - padding)
    y1 = min(h - 1, y1 + padding)
    x1 = min(w - 1, x1 + padding)
    return (y0, y1, x0, x1)


def imwrite_retry(path: str, img: "np.ndarray", attempts: int = 3) -> bool:
    """Write image with limited retries (linear backoff). Returns True/False."""
    for i in range(1, max(1, attempts) + 1):
        if cv2.imwrite(path, img):
            return True
        if i < attempts:
            time.sleep(0.2 * i)
    return False


def _dedupe_path(path: str) -> str:
    """
    If 'path' exists, append _1, _2, ... before the extension until unique.
    """
    p = Path(path)
    stem, suffix = p.stem, p.suffix
    parent = p.parent
    cand = p
    counter = 1
    while cand.exists():
        cand = parent / f"{stem}_{counter}{suffix}"
        counter += 1
    return str(cand)


def ensure_output_path(
    input_path: str,
    output_dir: Optional[str],
    root: Optional[str],
    *,
    suffix: str,
    no_suffix: bool,
    in_place: bool,
) -> str:
    """
    Decide the output path for an input image.
      - in_place=True: overwrite (same path)
      - else: under output_dir (preserving structure relative to root), append suffix
              unless no_suffix=True; never clobber (auto-dedupe if needed).
    """
    if in_place:
        return input_path

    if not output_dir:
        raise ValueError("ensure_output_path requires output_dir when not in-place.")
    if not root:
        raise ValueError("ensure_output_path requires 'root' when not in-place.")

    rel_dir = os.path.relpath(os.path.dirname(input_path), root)
    out_dir = os.path.join(output_dir, rel_dir) if rel_dir != os.curdir else output_dir
    os.makedirs(out_dir, exist_ok=True)

    base = os.path.basename(input_path)
    stem, ext = os.path.splitext(base)
    out_name = f"{stem}{'' if no_suffix else suffix}{ext}"
    out_path = os.path.join(out_dir, out_name)

    # Never clobber in non in-place mode
    if os.path.exists(out_path):
        out_path = _dedupe_path(out_path)
    return out_path


def crop_image(
    img: "np.ndarray",
    low_threshold: int,
    high_threshold: int,
    min_area: int,
    padding: int,
    preserve_alpha: bool = False,
    alpha_threshold: int = 0,
) -> "np.ndarray":
    """Return cropped image if a bbox is found; otherwise return original."""
    bbox = detect_content_bbox(
        img, low_threshold, high_threshold, min_area, padding, preserve_alpha, alpha_threshold
    )
    if bbox is None:
        return img
    y0, y1, x0, x1 = bbox
    return img[y0 : y1 + 1, x0 : x1 + 1]


class ProcessingConfig:
    """Configuration object to reduce parameter count in process_one function."""

    def __init__(self, args, root: str, folder: str):
        self.retry_writes = args.retry_writes
        self.low_threshold = args.low_threshold
        self.high_threshold = args.high_threshold
        self.min_area = args.min_area
        self.padding = args.padding
        self.preserve_alpha = args.preserve_alpha
        self.alpha_threshold = args.alpha_threshold
        self.suffix = args.suffix
        self.no_suffix = args.no_suffix
        self.in_place = args.in_place
        self.root = root
        self.folder = folder
