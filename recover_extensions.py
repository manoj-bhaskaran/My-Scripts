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
- --log-interval: Log write interval in seconds (default: 5)

.EXAMPLES
python recover_extensions.py --folder "/path/to/files" --dryrun
python recover_extensions.py --move-unknowns --debug
"""

import re
import time
import argparse
import logging
from pathlib import Path
from threading import Lock
from collections import defaultdict
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

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
WEBP_PATTERN = re.compile(r"^52494646.{8}57454250")

log_lock = Lock()
log_buffer = []
last_log_time = time.time()


def setup_logging(logfile):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(message)s", handlers=[logging.FileHandler(logfile), logging.StreamHandler()])


def write_log(message, debug=False):
    global last_log_time
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"{timestamp} - {'DEBUG: ' if debug else ''}{message}"
    with log_lock:
        log_buffer.append(line)
        if time.time() - last_log_time >= args.log_interval:
            flush_log()


def flush_log():
    global log_buffer, last_log_time
    with log_lock:
        if log_buffer:
            with open(args.log, "a", encoding="utf-8") as f:
                f.write("\n".join(log_buffer) + "\n")
            log_buffer.clear()
            last_log_time = time.time()


def get_file_extension(filepath):
    try:
        with open(filepath, "rb") as f:
            initial = f.read(8)
            header = initial.hex().upper()

            for pattern, ext in SIGNATURES.items():
                if pattern.match(header):
                    return ext, header

            if header.startswith("52494646"):
                additional = f.read(4)
                header += additional.hex().upper()
                if WEBP_PATTERN.match(header):
                    return ".webp", header

        return None, header
    except Exception as e:
        write_log(f"Error reading file {filepath}: {e}")
        return None, None


def process_file(file_path):
    local_stats = {
        'skipped': 0,
        'renamed': 0,
        'unknown': 0,
        'identified': defaultdict(int),
        'extensions': defaultdict(int),
        'hex': defaultdict(int),
    }
    write_log(f"Processing file: {file_path}", debug=args.debug)

    if file_path.suffix:
        write_log(f"Skipping {file_path.name}, already has extension.")
        local_stats['skipped'] += 1
        local_stats['extensions'][file_path.suffix.lower()] += 1
        return local_stats

    ext, hex_sig = get_file_extension(file_path)

    if ext:
        local_stats['identified'][ext] += 1
        if not args.dryrun:
            new_path = file_path.with_name(file_path.stem + ext)
            try:
                file_path.rename(new_path)
                write_log(f"Renamed {file_path.name} to {new_path.name}")
                local_stats['renamed'] += 1
            except Exception as e:
                write_log(f"Failed to rename {file_path}: {e}")
    else:
        local_stats['unknown'] += 1
        local_stats['hex'][hex_sig] += 1
        write_log(f"Unknown extension for {file_path.name}. Hex: {hex_sig}")

        if args.move_unknowns and not args.dryrun:
            dest = Path(args.unknowns) / file_path.name
            try:
                dest.parent.mkdir(parents=True, exist_ok=True)
                file_path.rename(dest)
                write_log(f"Moved {file_path.name} to {dest}")
            except Exception as e:
                write_log(f"Failed to move {file_path.name}: {e}")

    return local_stats


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Recover file extensions based on file signature")
    parser.add_argument("--folder", default="C:/Users/manoj/OneDrive/Desktop/New folder")
    parser.add_argument("--log", default="C:/Users/manoj/Documents/Scripts/recover-extensions-log.txt")
    parser.add_argument("--unknowns", default="C:/Users/manoj/OneDrive/Desktop/UnidentifiedFiles")
    parser.add_argument("--dryrun", action="store_true")
    parser.add_argument("--move-unknowns", action="store_true")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--log-interval", type=int, default=5)
    args = parser.parse_args()

    setup_logging(args.log)
    all_files = list(Path(args.folder).rglob("*"))
    files = [f for f in all_files if f.is_file()]

    write_log(f"Starting scan of {len(files)} file(s) in {args.folder}", debug=args.debug)
    combined_stats = {
        'skipped': 0,
        'renamed': 0,
        'unknown': 0,
        'identified': defaultdict(int),
        'extensions': defaultdict(int),
        'hex': defaultdict(int),
    }

    with ThreadPoolExecutor() as executor:
        futures = {executor.submit(process_file, f): f for f in files}
        for future in tqdm(as_completed(futures), total=len(futures), desc="Processing files", unit="file"):
            result = future.result()
            if result:
                for k in ['skipped', 'renamed', 'unknown']:
                    combined_stats[k] += result[k]
                for k in ['identified', 'extensions', 'hex']:
                    for key, val in result[k].items():
                        combined_stats[k][key] += val

    flush_log()

    total = combined_stats['skipped'] + combined_stats['renamed'] + combined_stats['unknown']
    summary = f"Processed {total} file(s). Skipped: {combined_stats['skipped']}, Renamed: {combined_stats['renamed']}, Unknown: {combined_stats['unknown']}"
    print(summary)
    write_log(summary)

    if args.debug:
        write_log(f"Identified extensions: {dict(combined_stats['identified'])}")
        write_log(f"Unknown hex signatures: {dict(combined_stats['hex'])}")
        write_log(f"Existing extensions: {dict(combined_stats['extensions'])}")
