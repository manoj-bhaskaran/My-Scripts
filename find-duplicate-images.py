import os
import csv
import hashlib
import argparse
import logging
from collections import defaultdict
from itertools import groupby
from operator import itemgetter
from datetime import datetime

def is_safe_path(base, target):
    base = os.path.abspath(base)
    target = os.path.abspath(target)
    return os.path.commonprefix([base, target]) == base

def log_event(message):
    """
    Logs an event with a timestamp.

    Args:
        message (str): The message to log.
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    full_message = f"[{timestamp}] {message}"
    print(full_message)
    logging.info(message)

def compute_md5(file_path):
    """
    Computes the MD5 hash of a file.

    Args:
        file_path (str): The path to the file.

    Returns:
        str: The MD5 hash of the file, or None if an error occurs.
    """
    hash_md5 = hashlib.md5()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception as e:
        logging.warning(f"Error hashing {file_path}: {e}")
        return None

def stage1_list_files(folder, out_csv):
    """
    Lists all files in a folder and writes their sizes and paths to a CSV file.

    Args:
        folder (str): The folder to scan for files.
        out_csv (str): The path to the output CSV file.
    """
    log_event("Starting Stage 1: File listing")
    with open(out_csv, "w", newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        for root, _, files in os.walk(folder):
            for file in files:
                path = os.path.join(root, file)
                if not is_safe_path(folder, path):
                    logging.warning(f"Skipping unsafe path: {path}")
                    continue 
                try:
                    size = os.path.getsize(path)
                    writer.writerow([size, path])
                except Exception as e:
                    logging.warning(f"Skipping file {path}: {e}")
    log_event(f"Completed Stage 1: File list written to {out_csv}")

def stage2_sort_csv(input_csv, sorted_csv):
    """
    Sorts a CSV file by file size using PowerShell.

    Args:
        input_csv (str): The path to the input CSV file.
        sorted_csv (str): The path to the output sorted CSV file.
    """
    log_event("Starting Stage 2: Sorting by file size")

    ps_script = f"""
    Import-Csv -Path '{input_csv}' -Header size,path |
        Sort-Object {{ [int]$_.size }} |
        ForEach-Object {{ "$($_.size),$($_.path)" }} |
        Set-Content -Path '{sorted_csv}'
    """

    try:
        subprocess.run(["powershell", "-Command", ps_script], check=True)
        log_event(f"Completed Stage 2: Sorted list written to {sorted_csv}")
    except subprocess.CalledProcessError as e:
        logging.error(f"PowerShell sort failed: {e}")
        raise

def stage3_find_duplicates(sorted_csv, log_file, output_file):
    """
    Identifies duplicate files by hashing and writes the results to a CSV file.

    Args:
        sorted_csv (str): The path to the sorted CSV file.
        log_file (str): The path to the log file.
        output_file (str): The path to the output CSV file for duplicate files.
    """
    log_event("Starting Stage 3: Hashing and duplicate detection")
    with open(sorted_csv, newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        sorted_rows = list(reader)

    duplicate_sets = 0

    with open(output_file, "w", newline='', encoding="utf-8") as out_csv:
        writer = csv.writer(out_csv)

        for size, group in groupby(sorted_rows, key=itemgetter(0)):
            group = list(group)
            if len(group) <= 1:
                continue

            hash_groups = defaultdict(list)
            for _, path in group:
                md5 = compute_md5(path)
                if md5:
                    hash_groups[md5].append(path)

            for h, paths in hash_groups.items():
                if len(paths) > 1:
                    duplicate_sets += 1
                    logging.info(f"Duplicate group {duplicate_sets}: {len(paths)} files")
                    for p in paths:
                        logging.info(f"  {p}")
                        writer.writerow([duplicate_sets, p])

    log_event(f"Completed Stage 3: {duplicate_sets} duplicate groups found")
    log_event(f"Duplicate list saved to {output_file}")

def main():
    """
    Main function to execute the duplicate file detection script.

    This script performs a staged method to efficiently detect duplicate files in a specified folder.
    It generates intermediate and final outputs, including a temporary file list, a sorted file list,
    and a CSV file containing duplicate file information.

    Command-line Arguments:
        --folder : str (required)
            The folder to scan for duplicate files.
        --log : str (optional, default="duplicate-staged.log")
            The path to the log file where events and errors will be appended.
        --output : str (optional, default="duplicate-files.csv")
            The path to the output CSV file that will contain the list of duplicate files.
        --temp : str (optional, default="filelist.csv")
            The path to the temporary file where the raw file list will be stored.
        --sorted : str (optional, default="filelist_sorted.csv")
            The path to the sorted file list generated during the process.
    """
    parser = argparse.ArgumentParser(description="Efficient duplicate file detector (staged method).")
    parser.add_argument("--folder", type=str, required=True, help="Folder to scan")
    parser.add_argument("--log", type=str, default="duplicate-staged.log", help="Log file path (appends)")
    parser.add_argument("--output", type=str, default="duplicate-files.csv", help="Output CSV (overwritten)")
    parser.add_argument("--temp", type=str, default="filelist.csv", help="Temp file for raw file list")
    parser.add_argument("--sorted", type=str, default="filelist_sorted.csv", help="Sorted file list path")
    args = parser.parse_args()

    args.folder = os.path.abspath(args.folder)
        
    logging.basicConfig(
        filename=args.log,
        level=logging.INFO,
        filemode='a',
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

    log_event("Duplicate detection script started")

    stage1_list_files(args.folder, args.temp)
    stage2_sort_csv(args.temp, args.sorted)
    stage3_find_duplicates(args.sorted, args.log, args.output)

    log_event("Duplicate detection script completed")

if __name__ == "__main__":
    main()
