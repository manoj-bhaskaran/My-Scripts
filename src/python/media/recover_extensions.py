"""
Script Name: recover_extensions.py

This Python script recovers file extensions for files that have lost their extensions. It scans a specified folder, determines the file type based on the file's signature (first few bytes), and appends the appropriate extension to the file name. The script logs all actions for future reference.

.DESCRIPTION
The script iterates through each file in the specified folder and checks if the file already has an extension. If the file does not have an extension, it reads the first few bytes to determine the file type and appends the appropriate extension. The script supports common file signatures for PNG, JPEG, and other file types. It logs each action taken, including files skipped, renamed, and those with unknown extensions.

.PARAMETERS
- --folder: Folder containing files to process (default: ./input)
- --log: Path to the log file (default: ./recover-extensions.log)
- --unknowns: Folder to move unrecognized files (default: ./unknowns)
- --dryrun: If specified, does not rename or move files
- --move-unknowns: If specified, moves unrecognized files
- --debug: Enables debug logging

.EXAMPLES
python recover_extensions.py --folder "/path/to/files" --dryrun
python recover_extensions.py --move-unknowns --debug
"""

import re
import sys
import time
import argparse
from pathlib import Path

# Add module paths to sys.path for imports
script_dir = Path(__file__).resolve().parent
repo_root = script_dir.parent.parent.parent
modules_logging = repo_root / "src" / "python" / "modules" / "logging"

sys.path.insert(0, str(modules_logging))

import python_logging_framework as plog
from collections import defaultdict
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

# Initialize logger for this module
# Use Path(__file__).name to get just the filename for proper log file naming
logger = plog.initialise_logger(Path(__file__).name, log_dir=repo_root / "logs")

# Dictionary mapping compiled regex patterns of file signatures (magic numbers) to file extensions.
SIGNATURES = {
    re.compile(r"^89504E47"): ".png",
    re.compile(r"^FFD8FF"): ".jpg",
    re.compile(r"^49492A00"): ".tiff",
    re.compile(r"^4D4D002[ABab]"): ".tiff",
    re.compile(r"^6674797068656963"): ".heic",
    re.compile(r"^6674797061766966"): ".avif",
    re.compile(r"^474946383761"): ".gif",
    re.compile(r"^474946383961"): ".gif",
    re.compile(r"^424D"): ".bmp",
}
# Pattern for WEBP files, which require more than 8 bytes to identify.
WEBP_PATTERN = re.compile(r"^52494646.{8}57454250")


def get_file_extension(filepath):
    """
    Determines the file extension based on the file's signature (magic number).

    Args:
        filepath (Path): Path to the file to check.

    Returns:
        tuple: (extension (str or None), hex signature (str or None))
            - extension: The determined file extension (e.g., '.png'), or None if unknown.
            - hex signature: The hexadecimal string of the file's header bytes.
    """
    try:
        with open(filepath, "rb") as f:
            initial = f.read(8)
            header = initial.hex().upper()

            for pattern, ext in SIGNATURES.items():
                if pattern.match(header):
                    return ext, header

            # Special handling for WEBP files, which require more than 8 bytes.
            if header.startswith("52494646"):
                additional = f.read(4)
                header += additional.hex().upper()
                if WEBP_PATTERN.match(header):
                    return ".webp", header

        return None, header
    except Exception as e:
        plog.log_info(logger, f"Error reading file {filepath}: {e}")
        return None, None


def process_file(file_path):
    """
    Processes a single file: determines if it needs an extension, renames or moves it if necessary,
    and collects statistics about the operation.

    Args:
        file_path (Path): The file to process.

    Returns:
        dict: Statistics about the operation, including counts of skipped, renamed, unknown files,
              and dictionaries of identified extensions, existing extensions, and unknown hex signatures.
    """
    local_stats = {
        "skipped": 0,
        "renamed": 0,
        "unknown": 0,
        "identified": defaultdict(int),
        "extensions": defaultdict(int),
        "hex": defaultdict(int),
    }
    plog.log_debug(logger, f"Processing file: {file_path}")

    # Skip files that already have an extension.
    if file_path.suffix:
        plog.log_info(logger, f"Skipping {file_path.name}, already has extension.")
        local_stats["skipped"] += 1
        local_stats["extensions"][file_path.suffix.lower()] += 1
        return local_stats

    ext, hex_sig = get_file_extension(file_path)

    if ext:
        # Extension identified, attempt to rename.
        local_stats["identified"][ext] += 1
        if not args.dryrun:
            new_path = file_path.with_name(file_path.stem + ext)
            try:
                file_path.rename(new_path)
                plog.log_info(logger, f"Renamed {file_path.name} to {new_path.name}")
                local_stats["renamed"] += 1
            except Exception as e:
                plog.log_info(logger, f"Failed to rename {file_path}: {e}")
    else:
        # Unknown extension, optionally move to unknowns folder.
        local_stats["unknown"] += 1
        local_stats["hex"][hex_sig] += 1
        plog.log_info(logger, f"Unknown extension for {file_path.name}. Hex: {hex_sig}")

        if args.move_unknowns and not args.dryrun:
            dest = Path(args.unknowns) / file_path.name
            try:
                dest.parent.mkdir(parents=True, exist_ok=True)
                file_path.rename(dest)
                plog.log_info(logger, f"Moved {file_path.name} to {dest}")
            except Exception as e:
                plog.log_info(logger, f"Failed to move {file_path.name}: {e}")

    return local_stats


if __name__ == "__main__":
    """
    Main entry point for the script. Parses arguments, initializes logging, scans the target folder,
    processes files in parallel, and prints/logs a summary of the results.
    """
    parser = argparse.ArgumentParser(description="Recover file extensions based on file signature")
    parser.add_argument(
        "--folder",
        default="C:/Users/manoj/OneDrive/Desktop/New folder",
        help="Folder containing files to process (default: ./input)",
    )
    parser.add_argument(
        "--log",
        default="C:/Users/manoj/Documents/Scripts/recover-extensions-log.txt",
        help="Path to the log file (default: ./recover-extensions.log)",
    )
    parser.add_argument(
        "--unknowns",
        default="C:/Users/manoj/OneDrive/Desktop/UnidentifiedFiles",
        help="Folder to move unrecognized files (default: ./unknowns)",
    )
    parser.add_argument(
        "--dryrun", action="store_true", help="If specified, does not rename or move files"
    )
    parser.add_argument(
        "--move-unknowns", action="store_true", help="If specified, moves unrecognized files"
    )
    parser.add_argument("--debug", action="store_true", help="Enables debug logging")
    args = parser.parse_args()

    # Logger already initialized at module level, just update level if needed
    import logging

    if args.debug:
        logger.setLevel(logging.DEBUG)

    # Recursively collect all files in the specified folder.
    all_files = list(Path(args.folder).rglob("*"))
    files = [f for f in all_files if f.is_file()]

    plog.log_debug(logger, f"Starting scan of {len(files)} file(s) in {args.folder}")
    combined_stats = {
        "skipped": 0,
        "renamed": 0,
        "unknown": 0,
        "identified": defaultdict(int),
        "extensions": defaultdict(int),
        "hex": defaultdict(int),
    }

    # Process files in parallel using ThreadPoolExecutor.
    with ThreadPoolExecutor() as executor:
        futures = {executor.submit(process_file, f): f for f in files}
        for future in tqdm(
            as_completed(futures), total=len(futures), desc="Processing files", unit="file"
        ):
            result = future.result()
            if result:
                for k in ["skipped", "renamed", "unknown"]:
                    combined_stats[k] += result[k]
                for k in ["identified", "extensions", "hex"]:
                    for key, val in result[k].items():
                        combined_stats[k][key] += val

    # Print and log a summary of the results.
    total = combined_stats["skipped"] + combined_stats["renamed"] + combined_stats["unknown"]
    summary = f"Processed {total} file(s). Skipped: {combined_stats['skipped']}, Renamed: {combined_stats['renamed']}, Unknown: {combined_stats['unknown']}"
    print(summary)
    plog.log_info(summary)

    # If debug is enabled, log detailed statistics.
    if args.debug:
        plog.log_info(logger, f"Identified extensions: {dict(combined_stats['identified'])}")
        plog.log_info(logger, f"Unknown hex signatures: {dict(combined_stats['hex'])}")
        plog.log_info(logger, f"Existing extensions: {dict(combined_stats['extensions'])}")
