#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Frame cropper for image folders.

Version: 3.0.0
Author: Manoj Bhaskaran

DESCRIPTION
    Batch-crops images in a folder, trimming uniform borders (e.g., black/white)
    and writing the results back. Designed to be invoked by a wrapper
    (e.g., videoscreenshot.ps1) but usable standalone.

    Safe defaults:
      - Writes to <input>/Cropped by default (non-destructive)
      - Appends a filename suffix (default: "_cropped")
      - Preserves subfolder structure with --recurse
      - Never overwrites outputs (auto de-duplicates if needed)

    Opt-in overwrite:
      - Use --in-place to overwrite originals in-place (atomic temp->replace)

    Features:
      - Parallel processing via ThreadPoolExecutor (configurable --max-workers)
      - Strict validation & clear exit codes
      - Resume-from-image support (--resume-file)
      - Save retries for transient I/O issues (--retry-writes)
      - Optionally skip corrupt images instead of failing the run (--skip-bad-images)
      - Optional recursion into subfolders (--recurse)

EXIT CODES
    0  Success
    1  Runtime error (processing failed after starting work)
    2  Usage/validation error (empty input without --allow-empty, invalid resume file, etc.)

DEPENDENCIES
    - OpenCV:      pip install opencv-python
    - NumPy:       pip install numpy
    - (Optional) python-logging-framework (plog): pip install python-logging-framework
      If not installed, the script automatically falls back to Python’s built-in logging.

USAGE
    # Safe default (non-destructive): Cropped/ + suffix
    python cropper.py --input /path/to/images [--output /path/to/out]
                      [--suffix _cropped] [--no-suffix]
                      [--max-workers N] [--retry-writes 3]
                      [--resume-file img_000123.png]
                      [--skip-bad-images]
                      [--allow-empty]
                      [--recurse]
                      [--debug]

    # Overwrite originals (opt-in)
    python cropper.py --input /path/to/images --in-place

TROUBLESHOOTING
    - "No valid images found":
        Ensure --input has .png/.jpg/.jpeg files. Use --recurse to include subfolders.
        Use --allow-empty to treat empty input as success.
    - "Failed to load image":
        The file may be corrupt/unsupported. Use --skip-bad-images to continue.
    - "Saves failing on network drive":
        Increase --retry-writes, reduce --max-workers, and check disk permissions/space.
    - "Too slow or too CPU-heavy":
        Tune --max-workers (I/O-bound default is 2×CPU, capped at 64). Try smaller values.

FAQS
    Q: Where are outputs written?
       A: By default, images are written to <input>/Cropped/, preserving subfolders
          when --recurse is used, with a filename suffix (e.g., _cropped).

    Q: What if the crop finds nothing to trim?
       A: The original image is written as-is (no-op crop).

    Q: Can I resume after a partial run?
       A: Yes. Pass --resume-file <an existing image filename>. Processing starts after that file.

CHANGELOG
    3.0.0
      Breaking (default behavior changed from 2.x):
        - Default no longer overwrites inputs. Outputs go to <input>/Cropped with suffix "_cropped".
        - Non-destructive mode guarantees no clobbering (auto de-duplicates if needed).
      Add:
        - --in-place to overwrite originals (atomic replace)
        - --suffix (default "_cropped") and --no-suffix for naming control in non in-place mode
      Keep:
        - 2.x features: --recurse, --max-workers, retries, strict validation, etc.

    2.1.0
      Add:
        - --recurse for recursive image discovery (os.walk)
        - Preserve relative subfolder structure in --output
      Docs:
        - Clarify python-logging-framework is optional (fallback to stdlib logging)
      Style:
        - Use np.nonzero over np.where(condition)

    2.0.0
      Breaking:
        - Empty folder exits 2 unless --allow-empty.
        - --resume-file must exist and be a valid image; otherwise exit 2.
        - Corrupt images fail the run by default; use --skip-bad-images to continue.
      Add:
        - --max-workers, --retry-writes, --skip-bad-images, --allow-empty.
        - Docstring with Version/Author, Troubleshooting, FAQs, and dependencies.
      Fix:
        - Explicit None-check on cv2.imread with clear error messages.

"""

from __future__ import annotations

import argparse
import concurrent.futures as fut
import os
import sys
import time
from pathlib import Path
from typing import Optional, Sequence, Tuple, List

# --- Logging setup -----------------------------------------------------------

try:
    # Optional third-party logger (if available)
    import python_logging_framework as plog  # type: ignore

    logger = plog.get_logger("cropper")  # pragma: no cover
    _using_plog = True
except Exception:
    # Fallback to stdlib logging
    import logging

    logger = logging.getLogger("cropper")
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    _using_plog = False

try:
    import cv2
    import numpy as np
except Exception as e:
    logger.error("Failed to import OpenCV (cv2) / numpy: %s", e)
    sys.exit(2)


# --- CLI & defaults ----------------------------------------------------------

def default_workers() -> int:
    """Heuristic for I/O-bound workloads: ~2×CPU, floor 4, cap 64."""
    try:
        return min(64, max(4, (os.cpu_count() or 4) * 2))
    except Exception:
        return 8


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Crop uniform borders from images in a folder.")

    p.add_argument("--input", required=True, help="Input folder containing images.")
    p.add_argument("--output", default=None,
                   help="Output folder (default: <input>/Cropped). Ignored with --in-place.")
    p.add_argument("--in-place", action="store_true",
                   help="Overwrite originals in-place (atomic replace).")

    # Accept both kebab and underscore to match callers
    p.add_argument("--resume-file", dest="resume_file", default=None,
                   help="Resume after this image (filename or absolute path).")
    p.add_argument("--resume_file", dest="resume_file", default=None,
                   help=argparse.SUPPRESS)

    p.add_argument("--suffix", default="_cropped",
                   help="Filename suffix in non in-place mode (default: _cropped).")
    p.add_argument("--no-suffix", action="store_true",
                   help="Do not append a suffix in non in-place mode (still non-clobbering).")

    p.add_argument("--max-workers", type=int, default=default_workers(),
                   help="Thread pool size (I/O-bound default: 2×CPU, capped 64).")
    p.add_argument("--retry-writes", type=int, default=3,
                   help="Retries for image writes (cv2.imwrite).")
    p.add_argument("--skip-bad-images", action="store_true",
                   help="Skip corrupt/unsupported images instead of failing the run.")
    p.add_argument("--allow-empty", action="store_true",
                   help="Treat empty input folder as success (exit 0).")
    p.add_argument("--recurse", action="store_true",
                   help="Search subfolders recursively for images.")
    p.add_argument("--debug", action="store_true", help="Enable debug logging.")

    # Crop tuning (optional, sensible defaults)
    p.add_argument("--low-threshold", type=int, default=5,
                   help="Pixel values <= low-threshold treated as 'black' border.")
    p.add_argument("--high-threshold", type=int, default=250,
                   help="Pixel values >= high-threshold treated as 'white' border.")
    p.add_argument("--min-area", type=int, default=256,
                   help="Minimum content area (pixels) required to accept a crop bbox.")
    p.add_argument("--padding", type=int, default=2,
                   help="Extra pixels to include around detected content (clamped).")

    args = p.parse_args(argv)

    # Logging level
    if not _using_plog:
        logger.setLevel(logging.DEBUG if args.debug else logging.INFO)

    return args


# --- Image & crop helpers ----------------------------------------------------

VALID_EXTS = {".png", ".jpg", ".jpeg"}


def list_images(folder: str, recurse: bool = False) -> List[str]:
    """Return sorted absolute image paths with valid extensions. Optionally recurse."""
    root = Path(folder)
    it = root.rglob("*") if recurse else root.iterdir()
    return sorted(
        str(p.resolve())
        for p in it
        if p.is_file() and p.suffix.lower() in VALID_EXTS
    )

def validate_resume_file(folder: str, resume: str) -> str:
    """
    Validate --resume-file: must exist and be a valid image.
    Returns absolute path (resolves relative names under folder).
    """
    path = Path(resume)
    if not path.is_absolute():
        path = Path(folder) / resume
    if path.suffix.lower() not in VALID_EXTS or not path.exists():
        logger.error("Invalid --resume-file: %s (must exist and be .png/.jpg/.jpeg)", str(path))
        raise SystemExit(2)
    return str(path.resolve())


def load_image(path: str) -> "np.ndarray":
    """Load an image (BGR). Raises ValueError if corrupt/unsupported."""
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"Failed to load image (corrupt/unsupported): {path}")
    return img


def detect_content_bbox(
    img: "np.ndarray",
    low_threshold: int = 5,
    high_threshold: int = 250,
    min_area: int = 256,
    padding: int = 2,
) -> Optional[Tuple[int, int, int, int]]:
    """
    Compute a bounding box around non-border content.

    Heuristic:
      - Convert to grayscale.
      - Mark as 'content' pixels that are strictly between low/high thresholds.
      - If any content exists and area >= min_area, return bbox with optional padding.
      - Otherwise, return None (no crop).

    Returns bbox as (y0, y1, x0, x1) in image coordinates, or None.
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    content_mask = (gray > low_threshold) & (gray < high_threshold)
    if not np.any(content_mask):
        return None

    ys, xs = np.nonzero(content_mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    if (y1 - y0 + 1) * (x1 - x0 + 1) < int(min_area):
        return None

    h, w = gray.shape[:2]
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
) -> "np.ndarray":
    """Return cropped image if a bbox is found; otherwise return original."""
    bbox = detect_content_bbox(img, low_threshold, high_threshold, min_area, padding)
    if bbox is None:
        return img
    y0, y1, x0, x1 = bbox
    return img[y0:y1 + 1, x0:x1 + 1]


# --- Worker & orchestration --------------------------------------------------

def process_one(
    in_path: str,
    out_dir: Optional[str],
    retry_writes: int,
    low_threshold: int,
    high_threshold: int,
    min_area: int,
    padding: int,
    root: Optional[str],
    *,
    suffix: str,
    no_suffix: bool,
    in_place: bool,
) -> Tuple[str, bool, Optional[str]]:
    """
    Process a single image: load, crop, save (with retries).
    Returns (path, success, error_message_or_None).
    """
    try:
        img = load_image(in_path)
        cropped = crop_image(img, low_threshold, high_threshold, min_area, padding)
        out_path = ensure_output_path(
            in_path, out_dir, root,
            suffix=suffix, no_suffix=no_suffix, in_place=in_place
        )

        if in_place:
            # Atomic replace via temp file to reduce partial write risk
            tmp = in_path + ".tmp_write"
            if not imwrite_retry(tmp, cropped, attempts=retry_writes):
                return (in_path, False, "Failed to save image after retries (tmp).")
            try:
                os.replace(tmp, in_path)
            except Exception as e:
                try:
                    os.remove(tmp)
                except Exception:
                    pass
                return (in_path, False, f"Atomic replace failed: {e}")
        else:
            if not imwrite_retry(out_path, cropped, attempts=retry_writes):
                return (in_path, False, "Failed to save image after retries.")

        return (in_path, True, None)

    except Exception as e:
        return (in_path, False, str(e))


# --- Low-complexity helpers for main() --------------------------------------

def _validate_paths(args) -> tuple[Optional[str], Optional[int]]:
    """Validate and normalize input/output paths & flags. Returns (folder, exit_code)."""
    folder = os.path.abspath(args.input)
    if not os.path.isdir(folder):
        logger.error("Input is not a folder: %s", folder)
        return None, 2

    if args.in_place and args.output:
        logger.error("Cannot combine --in-place with --output. Choose one.")
        return None, 2

    # Default safe output dir when not in-place and output not provided
    if not args.in_place and not args.output:
        args.output = os.path.join(folder, "Cropped")

    if args.output:
        args.output = os.path.abspath(args.output)
        if os.path.isfile(args.output):
            logger.error("Output path must be a directory: %s", args.output)
            return None, 2
        os.makedirs(args.output, exist_ok=True)

    return folder, None


def _collect_images_or_exit(folder: str, allow_empty: bool, recurse: bool) -> tuple[Optional[list[str]], Optional[int]]:
    """
    List images. On empty input:
      - return ([], 0) if allow_empty
      - return (None, 2) otherwise
    """
    images = list_images(folder, recurse=recurse)
    if images:
        return images, None

    logger.error("No valid images found in %s (recurse=%s)", folder, recurse)
    if allow_empty:
        logger.info("--allow-empty set; exiting 0")
        return [], 0
    return None, 2


def _resolve_resume_index(folder: str, images: list[str], resume_file: Optional[str]) -> tuple[Optional[int], Optional[int]]:
    """
    Compute starting index based on --resume-file.
    Returns (start_index, exit_code) where exit_code is None on success.
    May raise SystemExit(2) on validation errors to stop the application.
    """
    if not resume_file:
        return 0, None

    resume_abs = validate_resume_file(folder, resume_file)  # may SystemExit(2)
    try:
        return images.index(resume_abs) + 1, None  # start AFTER this file
    except ValueError:
        logger.error("--resume-file not found in input set: %s", resume_abs)
        raise SystemExit(2)


def _classify_result(ok: bool, err: Optional[str], skip_bad_images: bool) -> str:
    """Return 'ok', 'skip', or 'fail' based on worker outcome and flags."""
    if ok:
        return "ok"
    if "Failed to load image" in (err or "") and skip_bad_images:
        return "skip"
    return "fail"


def _process_batch(to_process: list[str], args, root: str) -> tuple[int, int, int]:
    """Run the parallel crop/save over the list, returning (processed, skipped, failures)."""
    total = len(to_process)
    logger.info(
        "Starting crop: %d images (workers=%d, out=%s, recurse=%s, in_place=%s)",
        total, args.max_workers, (args.output or "in-place"), args.recurse, args.in_place
    )

    processed = skipped = failures = 0

    with fut.ThreadPoolExecutor(max_workers=args.max_workers) as ex:
        future_map = {
            ex.submit(
                process_one,
                path,
                args.output,
                args.retry_writes,
                args.low_threshold,
                args.high_threshold,
                args.min_area,
                args.padding,
                root,
                suffix=args.suffix,
                no_suffix=args.no_suffix,
                in_place=args.in_place,
            ): path
            for path in to_process
        }

        for i, f in enumerate(fut.as_completed(future_map), 1):
            path = future_map[f]
            name = os.path.basename(path)

            try:
                _, ok, err = f.result()
            except Exception as e:
                ok, err = False, f"Unhandled worker exception: {e}"

            status = _classify_result(ok, err, args.skip_bad_images)
            if status == "ok":
                processed += 1
                if args.debug:
                    logger.debug("[%d/%d] OK: %s", i, total, name)
            elif status == "skip":
                skipped += 1
                logger.warning("[%d/%d] Skipped (bad image): %s — %s", i, total, name, err)
            else:
                failures += 1
                logger.error("[%d/%d] FAIL: %s — %s", i, total, name, err)

    return processed, skipped, failures


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    # 1) Validate paths & flags
    folder, code = _validate_paths(args)
    if code is not None:
        return code

    # 2) Collect images (early-exit if empty and allowed)
    images, code = _collect_images_or_exit(folder, args.allow_empty, args.recurse)
    if code is not None:
        return code  # 0 or 2
    assert images is not None  # for type checkers

    # 3) Resolve resume offset
    start_index, code = _resolve_resume_index(folder, images, args.resume_file)
    if code is not None:
        return code
    assert start_index is not None

    # 4) Slice to resume; early-exit if nothing left
    to_process = images[start_index:]
    if not to_process:
        logger.info("Nothing to do (resume points to last file).")
        return 0

    # 5) Parallel processing
    processed, skipped, failures = _process_batch(to_process, args, root=folder)

    # 6) Summary & exit code
    logger.info("Done. processed=%d, skipped=%d, failed=%d", processed, skipped, failures)
    return 1 if failures > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
