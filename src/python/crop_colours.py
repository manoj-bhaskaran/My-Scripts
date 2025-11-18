"""
Frame cropper for image folders.

Version: 4.0.0
Author: Manoj Bhaskaran

DESCRIPTION
    Batch-crops images in a folder, trimming uniform borders (e.g., black/white)
    and writing the results back. Designed to be invoked by the Videoscreenshot
    module (formerly videoscreenshot.ps1) but usable standalone.

    Safe defaults:
      - Writes to <input>/Cropped by default (non-destructive)
      - Appends a filename suffix (default: "_cropped")
      - Preserves subfolder structure with --recurse
      - Never overwrites outputs (auto de-duplicates if needed)
      - Tracks processed files to avoid reprocessing on reruns (via .processed_images using absolute paths)
        Note: Moving input directories invalidates tracking (absolute paths); remove .processed_images to reset.

    Opt-in overwrite:
      - Use --in-place to overwrite originals in-place (atomic temp->replace)

    Features:
      - Parallel processing via ThreadPoolExecutor (configurable --max-workers)
      - Periodic progress logs (--progress-interval, default 100 images)
      - Real-time progress with ETA estimates and processing rate
      - Strict validation & clear exit codes
      - Resume-from-image support (--resume-file)
      - Save retries for transient I/O issues (--retry-writes)
      - Optionally skip corrupt images instead of failing the run (--skip-bad-images)
      - Optional recursion into subfolders (--recurse)
      - Automatic reprocessing protection via .processed_images tracking and existing output detection
      - Comprehensive summary statistics with timing and success rates
      - Thread-safe processed file tracking with cross-process coordination
      - Alpha channel support for transparent border detection
      - Strict resume file validation with image readability checks

EXIT CODES
    0  Success
    1  Runtime error (some or all images failed to process after starting work)
    2  Usage/validation error (empty input without --allow-empty, invalid resume file, etc.)

    Exit code policy: Partial success (some images processed, some failed) returns 1 to alert automation.
     
DEPENDENCIES
    - OpenCV:      pip install opencv-python
    - NumPy:       pip install numpy
    - (Optional) python-logging-framework (plog): pip install python-logging-framework
      If not installed, the script automatically falls back to Python’s built-in logging.

USAGE
    # Safe default (non-destructive): Cropped/ + suffix
    python crop_colours.py --input /path/to/images [--output /path/to/out]
                      [--suffix _cropped] [--no-suffix]
                      [--max-workers N] [--retry-writes 3]
                      [--progress-interval 100]
                      [--resume-file img_000123.png]
                      [--skip-bad-images]
                      [--allow-empty]
                      [--reprocess-cropped [--keep-existing-crops]]
                      [--recurse]
                      [--preserve-alpha]
                      [--alpha-threshold N]
                      [--debug]

    # Overwrite originals (opt-in)
    python crop_colours.py --input /path/to/images --in-place

TROUBLESHOOTING
    - "No valid images found":
        Ensure --input has .png/.jpg/.jpeg files. Use --recurse to include subfolders.
        Use --allow-empty to treat empty input as success.
    - "Already processed / already cropped":
        By default, images that were successfully processed before are skipped on rerun.
        Use --reprocess-cropped to force reprocessing; by default, this deletes any existing
        crops before regenerating them. To keep existing crops and add new de-duplicated
        outputs alongside, add --keep-existing-crops.
    - "Failed to load image":
        The file may be corrupt/unsupported. Use --skip-bad-images to continue.
    - "Transparent images not cropping properly":
        Use --preserve-alpha to detect transparent borders instead of treating
        them as solid colors. Requires images with alpha channels.
        For images with anti-aliased transparent edges, also tune --alpha-threshold
        to ignore semi-transparent pixels (e.g. --alpha-threshold 10 to ignore
        alpha values <= 10).
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

    Q: How does reprocessing protection work?
       A: Successfully processed files are recorded in <input>/.processed_images (absolute paths).
          Existing crops are also detected when determining whether work is needed.
          Delete .processed_images to reset tracking or pass --reprocess-cropped to redo work.
          
    Q: How do I handle images with transparent backgrounds?
       A: Use --preserve-alpha to detect borders based on alpha transparency.

    Q: Can I resume after a partial run?
       A: Yes. Pass --resume-file <an existing image filename>. Processing starts after that file.

CHANGELOG
    ## 4.0.0
    **Breaking**
    - Remove `--ignore-processed`. Default behavior now explicitly skips previously cropped images using `.processed_images` tracking and/or existing output detection.
    **Add**
    - `--reprocess-cropped` to force a full re-crop.
    - `--keep-existing-crops` to retain existing crops when reprocessing (new outputs are de-duplicated alongside).
    **Improve**
    - Documentation and help text updated to reflect reprocessing semantics and defaults.
    **Refactor**
    - Split monolithic `main()` into focused helpers (`_resolve_work_items`, `_maybe_handle_reprocessing`, `_emit_summary`) to reduce cognitive complexity and improve readability/testability without changing behavior.

    ## 3.x
    **Breaking / Behavior**
    - Default is now **non-destructive**: outputs are written to `<input>/Cropped` with suffix `_cropped` (no overwrite).  
    - Exit semantics refined: when all images are already processed, return **0** (success) instead of **2**.  
    - Stricter parameter validation across thresholds, padding, min-area, etc.

    **Add**
    - `--in-place` to overwrite originals atomically (temp→replace).
    - Naming controls: `--suffix` (default `_cropped`) and `--no-suffix`.
    - Progress controls: `--progress-interval` (default 100) with ETA/rate; end-of-run summary stats.
    - Reprocessing protection via `.processed_images` tracking to avoid redundant work.
    - `--ignore-processed` to override tracking when needed.
    - Transparency handling: `--preserve-alpha` plus `--alpha-threshold` for tuning semi-transparent edges.
    - Consistent logger naming and compatibility with both stdlib logging and `python-logging-framework`.

    **Fix**
    - Robust file tracking: add thread-safe/cross-process coordination to prevent `.processed_images` corruption.
    - Windows compatibility: make `fcntl` import conditional; fall back to Windows locking.
    - Resume robustness: validate that `--resume-file` is a real, readable image; use case-insensitive path matching on Windows; clearer errors when not found.
    - Exit codes: ensure **1** is returned when any image processing failures occur.
    - Eliminate duplicate `start_time` initialization in `_process_batch`.
    - Alpha crash fix: guard dimensions when using `--preserve-alpha` on grayscale images.
    - Return type/flow bugs addressed to avoid unintended `sys.exit()` errors.
    - Diagnostics: include target output path in save-failure messages.

    **Improve**
    - Cognitive complexity reduced by decomposing large routines into focused helpers (image collection, progress gating, stats, resume resolution).
    - Parameter bounds checks with clearer, actionable error messages.
    - Progress visibility: richer periodic logs with rate and ETA; more actionable end-of-run summary (success/failure/skip counts, success rate).
    - Documentation: clarify file locking as “cross-process coordination”; document absolute-path behavior in reprocessing protection and Windows path matching.
    - Type annotations modernized (built-in `tuple`, `list`); style improvements (use `np.nonzero`).
    - Debug logging made consistent across stdlib and third-party logging backends; debug builds emit environment/version diagnostics (Python/OpenCV/NumPy).

    **Keep**
    - Core 2.x capabilities: `--recurse`, `--max-workers`, retries, strict validation, non-clobbering writes with auto de-duplication when needed.

    ## 2.x
    **Breaking**
    - Empty folder exits with code **2** unless `--allow-empty`.
    - `--resume-file` must exist and be a valid, readable image; otherwise exit **2**.
    - Corrupt images fail the run by default; use `--skip-bad-images` to continue.

    **Add**
    - `--recurse` for recursive image discovery (`os.walk`).
    - Preserve relative subfolder structure under `--output`.
    - `--max-workers`, `--retry-writes`, `--skip-bad-images`, `--allow-empty`.
    - Expanded docstring with Version/Author, Troubleshooting, FAQs, and dependencies.

    **Fix**
    - Explicit `None`-check on `cv2.imread` with clearer error messages.

    **Docs**
    - Clarify that `python-logging-framework` is optional (falls back to stdlib logging).

    **Style**
    - Use `np.nonzero` over `np.where(condition)`.

"""

from __future__ import annotations

import argparse
import concurrent.futures as fut
import os
import sys
import threading
import time
from pathlib import Path
from typing import Optional, Sequence

# --- Logging setup -----------------------------------------------------------

try:
    # Optional third-party logger (if available)
    import python_logging_framework as plog  # type: ignore

    logger = plog.get_logger("crop_colours")
    _using_plog = True
except Exception:
    # Fallback to stdlib logging
    import logging

    logger = logging.getLogger("crop_colours")
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    _using_plog = False

# --- parse_args recursion guard ---------------------------------------------
# Some tools or wrappers can accidentally re-enter parse_args (e.g., by calling
# code paths that themselves parse CLI again). To avoid infinite recursion, we
# keep a very small re-entrancy budget and abort with a clear message if exceeded.
_PARSE_ARGS_DEPTH = 0
_PARSE_ARGS_MAX_DEPTH = 1

# Platform-specific file locking imports
try:
    import fcntl
    _has_unix_locking = True
except ImportError:
    _has_unix_locking = False

# Windows file locking fallback
try:
    import msvcrt
    _has_windows_locking = True
except ImportError:
    _has_windows_locking = False

try:
    import cv2
    import numpy as np
except Exception as e:
    logger.error("Failed to import OpenCV (cv2) / numpy: %s", e)
    sys.exit(2)

# Thread-safe file locking for processed tracking
_processed_file_lock = threading.Lock()
# --- CLI & defaults ----------------------------------------------------------

def default_workers() -> int:
    """Heuristic for I/O-bound workloads: ~2×CPU, floor 4, cap 64."""
    try:
        return min(64, max(4, (os.cpu_count() or 4) * 2))
    except Exception:
        return 8

def _validate_parameters(args) -> None:
    """
    Validate command-line parameters with meaningful error messages.
    Extracted to reduce cognitive complexity of parse_args.
    """
    import argparse
    
    # Create a dummy parser for error reporting
    p = argparse.ArgumentParser()
    
    if args.low_threshold < 0 or args.low_threshold > 255:
        p.error("--low-threshold must be between 0-255")
    if args.high_threshold < 0 or args.high_threshold > 255:
        p.error("--high-threshold must be between 0-255")
    if args.low_threshold >= args.high_threshold:
        p.error("--low-threshold must be less than --high-threshold")
    if args.min_area <= 0:
        p.error("--min-area must be positive")
    if args.padding < 0:
        p.error("--padding cannot be negative")
    if args.alpha_threshold < 0 or args.alpha_threshold > 255:
        p.error("--alpha-threshold must be between 0-255")
    if args.max_workers <= 0:
        p.error("--max-workers must be positive")
    if args.retry_writes <= 0:
        p.error("--retry-writes must be positive")
    if args.progress_interval < 0:
        p.error("--progress-interval cannot be negative")
# Global flag to track if we've shown save failure guidance this run
_save_failure_guidance_shown = False

def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """
    Parse command-line options for the cropper.

    Recursion/rewrapping guard:
      This function defends against accidental recursion/re-entrancy by
      aborting if called more than once concurrently or recursively.
    """
    # ---- recursion guard: break out of accidental re-entrancy --------------
    global _PARSE_ARGS_DEPTH
    if _PARSE_ARGS_DEPTH >= _PARSE_ARGS_MAX_DEPTH:
        # Logger is already initialized above; emit a clear, actionable error.
        logger.error("Recursive parse_args() invocation detected; aborting to prevent infinite recursion.")
        raise SystemExit(2)
    _PARSE_ARGS_DEPTH += 1
    try:
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
        p.add_argument("--preserve-alpha", action="store_true",
                       help="Detect transparent borders using alpha channel (for PNG with transparency).")
        p.add_argument("--alpha-threshold", type=int, default=0,
                       help="Minimum alpha value to treat as content (default: 0). Increase to ignore semi-transparent edges.")
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
        p.add_argument("--reprocess-cropped", dest="reprocess_cropped", action="store_true",
                       help="Reprocess even if images were cropped previously.")
        p.add_argument("--keep-existing-crops", dest="keep_existing_crops", action="store_true",
                       help="When used with --reprocess-cropped (non in-place), do not delete existing crops; add new outputs alongside.")
        p.add_argument("--progress-interval", type=int, default=100,
                       help="Log progress every N completed images (default: 100).")
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

        # Validate parsed values and set logger level
        _validate_parameters(args)
        if _using_plog:
            if args.debug:
                try:
                    logger.setLevel("DEBUG")  # plog string-based levels
                except Exception:
                    pass  # Ignore if plog doesn't support setLevel
        else:
            logger.setLevel(logging.DEBUG if args.debug else logging.INFO)

        # Debug-mode environment/version diagnostics
        # Helps confirm Python and library versions at runtime when investigating issues.
        if getattr(args, "debug", False):
            try:
                import platform
                py_ver = platform.python_version()
                cv2_ver = getattr(cv2, "__version__", "?")
                np_ver  = getattr(np, "__version__", "?")
                logger.debug("Runtime versions: Python=%s; OpenCV(cv2)=%s; NumPy=%s", py_ver, cv2_ver, np_ver)
            except Exception as e:
                logger.debug("Failed to emit runtime version info: %s", e)

        return args
    finally:
        # Always decrement the recursion counter to avoid false positives on next call.
        _PARSE_ARGS_DEPTH = max(0, _PARSE_ARGS_DEPTH - 1)

# --- Image & crop helpers ----------------------------------------------------

VALID_EXTS = {".png", ".jpg", ".jpeg"}


def list_images(folder: str, recurse: bool = False) -> list[str]:
    """Return sorted absolute image paths with valid extensions. Optionally recurse."""
    root = Path(folder)
    it = root.rglob("*") if recurse else root.iterdir()
    return sorted(
        str(p.resolve())
        for p in it
        if p.is_file() and p.suffix.lower() in VALID_EXTS
    )

def get_processed_set(folder: str) -> set[str]:
    """
    Load set of already-processed files from .processed_images tracking file.
    
    Returns absolute paths of files that were successfully processed in previous runs.
    Creates the tracking file if it doesn't exist. Handles read errors gracefully.
    """
    processed_file = os.path.join(folder, ".processed_images")
    processed = set()
    
    with _processed_file_lock:
        if not os.path.exists(processed_file):
            # Create empty tracking file
            try:
                with open(processed_file, 'w', encoding='utf-8'):
                    pass  # Create empty file for tracking processed images
            except Exception as e:
                logger.debug("Could not create processed tracking file: %s", e)
                return processed
   
        try:
            with open(processed_file, 'r', encoding='utf-8') as f:
                for line in f:
                    path = line.strip()
                    if path and os.path.exists(path):
                        processed.add(path)
            logger.debug("Loaded %d previously processed images from %s", len(processed), processed_file)
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
            with open(processed_file, 'a', encoding='utf-8') as f:
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

def validate_resume_file(folder: str, resume: str) -> str:
    """
    Validate --resume-file: must exist, have valid extension, and be readable as an image.
    
    Returns absolute path (resolves relative names under folder). Performs strict
    validation including attempting to load the image to ensure it's not corrupted.
    """
    path = Path(resume)
    if not path.is_absolute():
        path = Path(folder) / resume
    # Check existence and extension first
    if not path.exists() or path.suffix.lower() not in VALID_EXTS:
        logger.error("Invalid --resume-file: %s (must exist and have .png/.jpg/.jpeg extension). "
                    "Check path/extension or pass a file under --input; try --recurse if it's in a subfolder.", str(path))
        raise SystemExit(2)
    
    # Verify the file is actually a readable image
    try:
        test_img = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if test_img is None:
            raise ValueError("Not a valid image file")
    except Exception as e:
        logger.error("Resume file is not a readable image: %s - %s", str(path), e)
        raise SystemExit(2)
  
    return str(path.resolve())

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
    bbox = detect_content_bbox(img, low_threshold, high_threshold, min_area, padding, preserve_alpha, alpha_threshold)
    if bbox is None:
        return img
    y0, y1, x0, x1 = bbox
    return img[y0:y1 + 1, x0:x1 + 1]

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

# --- Worker & orchestration --------------------------------------------------

def process_one(
    in_path: str,
    out_dir: Optional[str],
    config: ProcessingConfig,
) -> tuple[str, bool, Optional[str]]:
    """
    Process a single image: load, crop, save (with retries).
    Uses ProcessingConfig to reduce parameter count.
    Returns (path, success, error_message_or_None).
    """
    try:
        img = load_image(in_path, config.preserve_alpha)
        cropped = crop_image(
            img, 
            config.low_threshold, 
            config.high_threshold, 
            config.min_area, 
            config.padding, 
            config.preserve_alpha, 
            config.alpha_threshold
        )
        out_path = ensure_output_path(
            in_path, out_dir, config.root,
            suffix=config.suffix, no_suffix=config.no_suffix, in_place=config.in_place
        )

        if config.in_place:
            # Atomic replace via temp file to reduce partial write risk
            tmp = in_path + ".tmp_write"
            if not imwrite_retry(tmp, cropped, attempts=config.retry_writes):
                return (in_path, False, f"Failed to save image to '{tmp}' after {config.retry_writes} attempts.")
            try:
                os.replace(tmp, in_path)
            except Exception as e:
                try:
                    os.remove(tmp)
                except Exception:
                    pass
                return (in_path, False, f"Atomic replace failed: {e}")
        else:
            if not imwrite_retry(out_path, cropped, attempts=config.retry_writes):
                # Add actionable guidance for save failures (once per run)
                global _save_failure_guidance_shown
                guidance = ""
                if not _save_failure_guidance_shown:
                    guidance = " Check write permissions and free disk space."
                    _save_failure_guidance_shown = True
                return (in_path, False, f"Failed to save image to '{out_path}' after {config.retry_writes} attempts.{guidance}")

        # Mark as successfully processed for future run tracking
        mark_processed(config.folder, in_path)
     
        return (in_path, True, None)

    except Exception as e:
        return (in_path, False, str(e))


# --- Low-complexity helpers for main() --------------------------------------
def _filter_processed_images(
    images: list[str],
    processed_set: Optional[set[str]],
    reprocess_cropped: bool,
) -> list[str]:
    """
    Filter out already-processed images (those present in ``processed_set``)
    unless ``reprocess_cropped`` is True.
    """
    if reprocess_cropped or not processed_set:
        return images

    original_count = len(images)
    filtered_images = [img for img in images if img not in processed_set]
    filtered_count = original_count - len(filtered_images)
    if filtered_count > 0:
        logger.info(
            "Filtered out %d already-processed images (%d remaining)",
            filtered_count, len(filtered_images),
        )
    return filtered_images

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


def _collect_and_filter_images(
    folder: str,
    allow_empty: bool,
    recurse: bool,
    reprocess_cropped: bool,
) -> tuple[Optional[list[str]], Optional[int]]:
    """
    Collect images and filter out already-processed ones (unless reprocess_cropped=True).
    
    Returns (image_list, exit_code) where exit_code is None on success.
    On empty input after filtering:
      - return ([], 0) if allow_empty
      - return (None, 2) otherwise
    """
    # Collect all valid images
    images = list_images(folder, recurse=recurse)
    if not images:
        logger.error("No valid images found in %s (recurse=%s)", folder, recurse)
        if allow_empty:
            logger.info("--allow-empty set; exiting 0")
            return [], 0
        return None, 2
    
    # Apply processed file filtering using on-disk tracking file
    processed_set = get_processed_set(folder)
    filtered_images = _filter_processed_images(images, processed_set, reprocess_cropped)
    
    # Handle empty results after filtering
    if not filtered_images:
        if allow_empty:
            logger.info("No unprocessed images remaining; --allow-empty set; exiting 0")
            return [], 0
        logger.info("No unprocessed images remaining (all previously completed); treating as success")
        return [], 0

    return filtered_images, None

def _delete_existing_crops_for_image(in_path: str, output_dir: str, root: str, *, suffix: str, no_suffix: bool) -> int:
    """
    Delete the expected cropped output (and de-duplicated siblings) for an input image.
    Returns number of files deleted. No-op if paths can't be derived.
    """
    try:
        rel_dir = os.path.relpath(os.path.dirname(in_path), root)
        out_dir = os.path.join(output_dir, rel_dir) if rel_dir != os.curdir else output_dir
        os.makedirs(out_dir, exist_ok=True)
        stem, ext = os.path.splitext(os.path.basename(in_path))
        mid = "" if no_suffix else suffix
        # Primary and de-duplicated (_N) variants
        patterns = [
            os.path.join(out_dir, f"{stem}{mid}{ext}"),
            os.path.join(out_dir, f"{stem}{mid}_*{ext}"),
        ]
        deleted = 0
        import glob
        for pat in patterns:
            for fp in glob.glob(pat):
                try:
                    os.remove(fp)
                    deleted += 1
                except Exception:
                    pass
        return deleted
    except Exception:
        return 0

def _resolve_resume_index(folder: str, images: list[str], resume_file: Optional[str]) -> tuple[Optional[int], Optional[int]]:
    """
    Compute starting index based on --resume-file.
    Returns (start_index, exit_code) where exit_code is None on success.
    May raise SystemExit(2) on validation errors to stop the application.
    """
    if not resume_file:
        return 0, None

    resume_abs = validate_resume_file(folder, resume_file)  # may SystemExit(2)
    
    # Case-insensitive path comparison for Windows compatibility
    import platform
    is_case_insensitive = platform.system().lower() == 'windows'
    
    if is_case_insensitive:
        # Windows: case-insensitive path matching
        resume_normalized = os.path.normcase(os.path.normpath(resume_abs))
        for i, img_path in enumerate(images):
            if os.path.normcase(os.path.normpath(img_path)) == resume_normalized:
                return i + 1, None  # start AFTER this file
    else:
        # Unix: case-sensitive exact path matching
        try:
            return images.index(resume_abs) + 1, None
        except ValueError:
            # Fall through to common error handling
            pass
    
    # Common error handling for both platforms when file not found
    logger.error("--resume-file not found in input set: %s. Check path/extension or pass a file under --input; try --recurse if it's in a subfolder.", resume_abs)
    raise SystemExit(2)

def _should_log_progress(i: int, total: int, args, current_time: float, last_progress_time: float) -> bool:
    """
    Determine if progress should be logged for current iteration.
    
    Extracted to reduce cognitive complexity of main processing loop.
    Logs on debug, explicit intervals, percentage milestones, or time thresholds.
    """
    return (
        args.debug or
        (args.progress_interval and args.progress_interval > 0 and i % args.progress_interval == 0) or
        (i % max(1, total // 20) == 0) or  # Every 5% for large batches
        (current_time - last_progress_time >= 5.0)  # Every 5 seconds minimum
    )


def _log_progress_stats(i: int, total: int, processed: int, skipped: int, failures: int, 
                       start_time: float, current_time: float) -> None:
    """Log formatted progress statistics with ETA calculation."""
    elapsed = current_time - start_time
    rate = i / elapsed if elapsed > 0 else 0
    eta = (total - i) / rate if rate > 0 else 0
    logger.info("[%d/%d] Progress: processed=%d, skipped=%d, failed=%d (%.1f img/sec, ETA: %.0fs)",
                i, total, processed, skipped, failures, rate, eta)


def _classify_result(ok: bool, err: Optional[str], skip_bad_images: bool) -> str:
    """Return 'ok', 'skip', or 'fail' based on worker outcome and flags."""
    if ok:
        return "ok"
    if "Failed to load image" in (err or "") and skip_bad_images:
        return "skip"
    return "fail"


def _process_batch(to_process: list[str], args, root: str) -> tuple[int, int, int, float]:
    """
    Execute parallel crop/save operations with enhanced progress reporting.
    
    Returns (processed, skipped, failures, elapsed_seconds) for summary statistics.
    Complexity reduced by extracting progress logging and statistics helpers.
    """
    total = len(to_process)
 
    logger.info(
        "Starting crop: %d images (workers=%d, out=%s, recurse=%s, in_place=%s)",
        total, args.max_workers, (args.output or "in-place"), args.recurse, args.in_place
    )

    start_time = time.time()
    last_progress_time = start_time
    processed = skipped = failures = 0

    config = ProcessingConfig(args, root, args.input)
  
    with fut.ThreadPoolExecutor(max_workers=args.max_workers) as ex:
        # Submit all tasks
        future_map = {
            ex.submit(
                process_one,
                path,
                args.output,
                config,
            ): path
            for path in to_process
        }

        # Process completed futures with enhanced progress reporting
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
            # Enhanced progress reporting (complexity reduced via helpers)
            current_time = time.time()
            should_log = _should_log_progress(i, total, args, current_time, last_progress_time)
            
            if should_log:
                _log_progress_stats(i, total, processed, skipped, failures, start_time, current_time)
                last_progress_time = current_time

    elapsed_total = time.time() - start_time
    return processed, skipped, failures, elapsed_total


def _resolve_work_items(args) -> tuple[Optional[str], Optional[list[str]], Optional[int]]:
    """
    Validate paths, collect/filter images, resolve resume, and return the worklist.
    Returns (folder, to_process, exit_code).  exit_code is None on success.
    """
    folder, code = _validate_paths(args)
    if code is not None:
        return None, None, code

    images, code = _collect_and_filter_images(
        folder,
        args.allow_empty,
        args.recurse,
        args.reprocess_cropped,
    )
    if code is not None:
        return folder, None, code  # 0 or 2
    assert images is not None

    start_index, code = _resolve_resume_index(folder, images, args.resume_file)
    if code is not None:
        return folder, None, code
    assert start_index is not None

    to_process = images[start_index:]
    if not to_process:
        logger.info("Nothing to do (resume points to last file).")
        return folder, [], 0

    return folder, to_process, None


def _maybe_handle_reprocessing(to_process: list[str], args, folder: str) -> None:
    """
    Handle reprocessing behavior (delete-or-keep existing crops) before regeneration.
    """
    if not args.reprocess_cropped or args.in_place:
        return
    if not args.keep_existing_crops:
        # Ensure output is set for non in-place mode (safety; _validate_paths should have set it)
        if args.output is None:
            args.output = os.path.join(folder, "Cropped")
        deleted_total = 0
        for pth in to_process:
            deleted_total += _delete_existing_crops_for_image(
                pth, args.output, folder, suffix=args.suffix, no_suffix=args.no_suffix
            )
        logger.info(
            "Reprocessing enabled: removed %d existing cropped file(s) before regeneration.",
            deleted_total,
        )
    else:
        logger.info(
            "Reprocessing enabled: keeping existing crops; new outputs will be added alongside."
        )


def _emit_summary(
    total: int, processed: int, skipped: int, failures: int, elapsed: float, *, output: Optional[str], in_place: bool
) -> None:
    """Emit a consistent end-of-run summary."""
    rate_overall = total / elapsed if elapsed > 0 else 0
    success_rate = (processed / total) * 100 if total else 0
    logger.info("=== CROP SUMMARY ===")
    logger.info("Total images processed: %d", total)
    logger.info("Successful crops: %d", processed)
    logger.info("Skipped (bad images): %d", skipped)
    logger.info("Failed: %d", failures)
    logger.info("Success rate: %.1f%%", success_rate)
    logger.info("Total time: %.1f seconds", elapsed)
    logger.info("Processing rate: %.1f images/second", rate_overall)
    if output and not in_place:
        logger.info("Output folder: %s", output)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    folder, to_process, code = _resolve_work_items(args)
    if code is not None:
        return code
    assert folder is not None and to_process is not None

    _maybe_handle_reprocessing(to_process, args, folder)

    processed, skipped, failures, elapsed_total = _process_batch(
        to_process, args, root=folder
    )

    _emit_summary(
        len(to_process),
        processed,
        skipped,
        failures,
        elapsed_total,
        output=args.output,
        in_place=args.in_place,
    )

    return 1 if failures > 0 else 0

if __name__ == "__main__":
    sys.exit(main())
