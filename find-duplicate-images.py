import os
import csv
import hashlib
import argparse
import logging
import json
import random
import shutil
import queue
from concurrent.futures import ThreadPoolExecutor, as_completed
from itertools import groupby
from tqdm import tqdm  # Import tqdm for the progress bar
from collections import defaultdict
from logging.handlers import QueueHandler, QueueListener
from threading import Lock

def load_checkpoint(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def save_checkpoint(path, stage_name, args):
    data = {
        "completed_stage": stage_name,
        "folder": args.folder,
        "output": args.output,
        "temp": args.temp,
        "sorted": args.sorted
    }
    try:
        tmp_path = path + ".tmp"
        with open(tmp_path, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, path)
    except Exception as e:
        logging.warning(f"Failed to save checkpoint: {e}")

def is_safe_path(base, target):
    base = os.path.abspath(base)
    target = os.path.abspath(target)
    return os.path.commonpath([base]) == os.path.commonpath([base, target])

def log_event(message):
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

def fast_walk(folder):
    for entry in os.scandir(folder):
        try:
            if entry.is_dir(follow_symlinks=False):
                yield from fast_walk(entry.path)
            elif entry.is_file(follow_symlinks=False):
                yield entry.path
        except Exception as e:
            logging.warning(f"Error accessing {entry.path}: {e}")

def stage1_list_files(folder, out_csv):
    """
    Lists all files in a folder and writes their sizes and paths to a CSV file using parallel threads.

    Args:
        folder (str): The folder to scan for files.
        out_csv (str): The path to the output CSV file.
    """
    log_event("Starting Stage 1: File listing")

    paths = list(fast_walk(folder))

    def get_size_safe(path):
        if not is_safe_path(folder, path):
            logging.warning(f"Skipping unsafe path: {path}")
            return None
        try:
            size = os.path.getsize(path)
            return (size, path)
        except Exception as e:
            logging.warning(f"Skipping file {path}: {e}")
            return None

    with open(out_csv, "w", newline='', encoding='utf-8') as f_out:
        writer = csv.writer(f_out)

        with ThreadPoolExecutor() as executor:
            futures = {executor.submit(get_size_safe, path): path for path in paths}
            with tqdm(total=len(futures), desc="Processing files", unit=" file(s)", dynamic_ncols=True) as pbar:
                for future in as_completed(futures):
                    result = future.result()
                    if result:
                        writer.writerow(result)
                    pbar.update(1)

    log_event(f"Completed Stage 1: File list written to {out_csv}")

def stage2_sort_csv(input_csv, sorted_csv):
    """
    Sorts a CSV file by file size using native Python.

    Args:
        input_csv (str): The path to the input CSV file.
        sorted_csv (str): The path to the output sorted CSV file.
    """
    log_event("Starting Stage 2: Sorting by file size (Python)")

    try:
        with open(input_csv, newline='', encoding='utf-8') as f_in:
            reader = csv.reader(f_in)
            rows = []
            for row in reader:
                if len(row) < 2:
                    logging.warning(f"Skipping malformed row in input: {row}")
                    continue
                try:
                    size = int(row[0])
                    path = row[1]
                    rows.append((size, path))
                except ValueError as ve:
                    logging.warning(f"Skipping row with invalid size: {row} ({ve})")

        rows.sort()  # Sorts by size (first element of tuple)

        with open(sorted_csv, "w", newline='', encoding='utf-8') as f_out:
            writer = csv.writer(f_out)
            writer.writerows(rows)

        log_event(f"Completed Stage 2: Sorted list written to {sorted_csv}")

    except Exception as e:
        logging.error(f"Python sort failed: {e}")
        raise

def _read_sorted_csv(sorted_csv):
    """
    Reads the sorted CSV and returns a list of duplicate candidate groups.

    Each group is a tuple of:
        (size, group_list), where:
            - size (int): The file size
            - group_list (List[Tuple[int, str]]): List of (size, file_path) tuples

    Only sizes with more than one file are included.
    """

    with open(sorted_csv, newline='', encoding='utf-8') as f_in:
        reader = csv.reader(f_in)
        rows = [(int(size), path) for size, path in reader if size and path.strip()]

    grouped_rows = []
    for size, group in groupby(rows, key=lambda r: r[0]):
        group_list = list(group)
        if len(group_list) > 1:
            grouped_rows.append((size, group_list))
    return grouped_rows

def _count_hashable_files(grouped_rows):
    """
    Counts total number of files that need to be hashed.
    """
    return sum(len(group_list) for _, group_list in grouped_rows)

def _hash_and_write_duplicates(grouped_rows, output_file, total_files):
    """
    Computes hashes for grouped files and writes duplicates to output.
    """
    def compute_md5_safe(path):
        try:
            return compute_md5(path)
        except Exception as e:
            logging.warning(f"Hashing failed for {path}: {e}")
            return None

    with open(output_file, "w", newline='', encoding='utf-8') as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["group_id", "size", "md5_hash", "file_path"])

        duplicate_sets = 0
        with tqdm(total=total_files, desc="Hashing files", unit=" file(s)", dynamic_ncols=True) as pbar:
            for size, group_list in grouped_rows:
                paths = [path for _, path in group_list]
                md5_list = list(ThreadPoolExecutor().map(compute_md5_safe, paths))

                hash_groups = defaultdict(list)
                for path, md5 in zip(paths, md5_list):
                    if md5:
                        hash_groups[md5].append(path)
                    pbar.update(1)

                for md5, dup_paths in hash_groups.items():
                    if len(dup_paths) > 1:
                        duplicate_sets += 1
                        for path in dup_paths:
                            writer.writerow([duplicate_sets, size, md5, path])

        log_event(f"Completed Stage 3: {duplicate_sets} duplicate groups found")

def stage3_find_duplicates(sorted_csv, output_file):
    """
    Identifies duplicate files by hashing and writes the results to a CSV file.
    Output format: group_id, size, md5_hash, file_path
    """
    log_event("Starting Stage 3: Hashing and duplicate detection")

    grouped_rows = _read_sorted_csv(sorted_csv)
    total_files_to_hash = _count_hashable_files(grouped_rows)
    _hash_and_write_duplicates(grouped_rows, output_file, total_files_to_hash)

    log_event(f"Completed Stage 3: Duplicate list saved to {output_file}")

def delete_duplicates(dup_csv, dryrun=False, backup_folder=None):
    """
    Deletes or moves duplicate files, retaining one file per group.

    Args:
        dup_csv (str): Path to CSV file with duplicate information.
        dryrun (bool): If True, only preview deletions.
        backup_folder (str): If set, move files there instead of deleting.
    """

    lock = Lock()
    deleted_count = 0

    log_event("Starting duplicate cleanup")

    if not os.path.exists(dup_csv):
        raise FileNotFoundError(f"Cannot perform deletion — stage3 output not found: {dup_csv}")

    with open(dup_csv, newline='', encoding='utf-8') as f_in:
        reader = csv.DictReader(f_in)
        grouped = defaultdict(list)

        for row in reader:
            grouped[row["group_id"]].append(row["file_path"])

    deleted_count = 0
    skipped_groups = 0

    total_files = sum(len(files) - 1 for files in grouped.values() if len(files) > 1)

    def delete_or_move_file(file_path, retained):
        nonlocal deleted_count
        if file_path == retained:
            return
        if dryrun:
            log_event(f"[DRYRUN] Would delete: {file_path}")
        else:
            try:
                if backup_folder:
                    os.makedirs(backup_folder, exist_ok=True)
                    dest = os.path.join(backup_folder, os.path.basename(file_path))
                    shutil.move(file_path, dest)
                    log_event(f"Moved: {file_path} → {dest}")
                else:
                    os.remove(file_path)
                    log_event(f"Deleted: {file_path}")
                with lock:
                    deleted_count += 1
            except Exception as e:
                logging.warning(f"Failed to delete/move {file_path}: {e}")

    with tqdm(total=total_files, desc="Deleting duplicates", unit=" file(s)", dynamic_ncols=True) as pbar:
        with ThreadPoolExecutor() as executor:
            futures = []
            for group_id, files in grouped.items():
                if len(files) <= 1:
                    skipped_groups += 1
                    continue

                retained = random.choice(files)
                for f in files:
                    futures.append(executor.submit(delete_or_move_file, f, retained))

            for future in as_completed(futures):
                pbar.update(1)

    log_event(f"Duplicate cleanup completed. Retained one file per group.")
    if dryrun:
        log_event(f"[DRYRUN] Total groups: {len(grouped)}, Skipped (1 file only): {skipped_groups}, Files that would be deleted: {deleted_count}")
    else:
        log_event(f"Deleted/Moved {deleted_count} files from {len(grouped)} duplicate groups")

def main():
    """
    Main function to execute the duplicate file detection script.

    This script performs a staged method to efficiently detect duplicate files in a specified folder.
    It generates intermediate and final outputs, including a temporary file list, a sorted file list,
    and a CSV file containing duplicate file information.

    Command-line Arguments:
        --folder : str (optional, default="D:\\users\\Manoj\\Documents\\FIFA 07\\elib")
            The folder to scan for duplicate files.
        --log : str (optional, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-log.log")
            The path to the log file where events and errors will be appended.
        --output : str (optional, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-output.csv")
            The path to the output CSV file that will contain the list of duplicate files.
        --temp : str (optional, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-temp.csv")
            The path to the temporary file where the raw file list will be stored.
        --sorted : str (optional, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-sorted.csv")
            The path to the sorted file list generated during the process.
    """
    parser = argparse.ArgumentParser(description="Efficient duplicate file detector (staged method).")
    parser.add_argument("--folder", type=str, default="D:\\users\\Manoj\\Documents\\FIFA 07\\elib", help="Folder to scan")
    parser.add_argument("--log", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-log.log", help="Log file path (appends)")
    parser.add_argument("--output", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-output.csv", help="Output CSV (overwritten)")
    parser.add_argument("--temp", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-temp.csv", help="Temp file for raw file list")
    parser.add_argument("--sorted", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-sorted.csv", help="Sorted file list path")
    parser.add_argument("--checkpoint", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\find-duplicate-images-checkpoint.json", help="Checkpoint file to track completed stages")
    parser.add_argument("--restart", action="store_true", help="Force restart from Stage 1 and ignore checkpoint")
    parser.add_argument("--keepfiles", action="store_true", help="Retain intermediate and checkpoint files even after successful completion")
    parser.add_argument("--delete", action="store_true", help="Delete duplicates after Stage 3 (retains one per group)")
    parser.add_argument("--dryrun", action="store_true", help="Preview deletions without making changes")
    parser.add_argument("--backup-folder", type=str, help="Move duplicates here instead of deleting (optional)")


    args = parser.parse_args()

    args.folder = os.path.abspath(args.folder)
    args.temp = os.path.abspath(args.temp)
    args.sorted = os.path.abspath(args.sorted)
    args.output = os.path.abspath(args.output)
    args.checkpoint = os.path.abspath(args.checkpoint)
    if args.backup_folder:
        args.backup_folder = os.path.abspath(args.backup_folder)
        
    # --- Queue-based logging setup ---
    log_queue = queue.Queue()

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    file_handler = logging.FileHandler(args.log)
    file_handler.setFormatter(formatter)

    listener = QueueListener(log_queue, file_handler)

    queue_handler = QueueHandler(log_queue)
    logging.getLogger().setLevel(logging.INFO)
    logging.getLogger().handlers = [queue_handler]

    listener.start()
    log_event("Logging system initialized with queue handler.")

    log_event("Duplicate detection script started")

    success = False  # Track if all stages complete
    checkpoint = load_checkpoint(args.checkpoint) if args.restart else {}

    if args.restart:
        log_event("Restart requested by user.")

        if not checkpoint:
            log_event("Checkpoint file not found or invalid. Cannot resume.")
            print("No valid checkpoint found — cannot resume.")
            return

        # Override CLI args from checkpoint — EXCEPT log
        args.folder = checkpoint.get("folder", args.folder)
        args.output = checkpoint.get("output", args.output)
        args.temp = checkpoint.get("temp", args.temp)
        args.sorted = checkpoint.get("sorted", args.sorted)
        # args.log is left as-is to allow overriding

        stage_map = {
            None: "Stage 1",
            "stage1": "Stage 2",
            "stage2": "Stage 3",
            "stage3": "Deletion Stage" if args.delete else "Already completed — nothing to do",
            "delete": "Already completed — nothing to do"
        }     

        resume_stage = checkpoint.get("completed_stage")
        resume_text = stage_map.get(resume_stage, "Unknown stage")
        log_event(f"Resuming from: {resume_text}")
        print(f"➡️  Restart requested — resuming from: {resume_text}")

        if resume_stage == "stage3" and not args.delete:
            log_event("All stages already completed. Nothing to resume.")
            print("✅ All stages already completed — nothing to do.")
            return

        elif resume_stage == "delete":
            log_event("All stages including deletion already completed. Nothing to resume.")
            print("✅ All stages including deletion already completed — nothing to do.")
            return
   
    # If no restart requested, delete any stale intermediate files at startup
    if not args.restart:
        for f in [args.temp, args.sorted, args.checkpoint]:
            if os.path.exists(f):
                os.remove(f)
                log_event(f"Deleted stale file at startup (no restart): {f}")

    if args.restart and args.delete:
        if not os.path.exists(args.output):
            msg = f"❌ Cannot perform deletion on restart — stage3 output not found: {args.output}"
            log_event(msg)
            print(msg)
            return

    try:
        completed_stage = checkpoint.get("completed_stage") if args.restart else None

        if completed_stage is None:
            try:
                stage1_list_files(args.folder, args.temp)
                completed_stage = "stage1"
                save_checkpoint(args.checkpoint, "stage1", args)
            except Exception as e:
                log_event(f"Stage 1 failed: {e}")
                raise

        if completed_stage == "stage1":
            try:
                stage2_sort_csv(args.temp, args.sorted)
                completed_stage = "stage2"
                save_checkpoint(args.checkpoint, "stage2", args)
            except Exception as e:
                log_event(f"Stage 2 failed: {e}")
                raise

        if completed_stage == "stage2":
            try:
                stage3_find_duplicates(args.sorted, args.output)
                completed_stage = "stage3"
                save_checkpoint(args.checkpoint, "stage3", args)
            except Exception as e:
                log_event(f"Stage 3 failed: {e}")
                raise

        if args.delete:
            try:
                delete_duplicates(args.output, dryrun=args.dryrun, backup_folder=args.backup_folder)
                completed_stage = "delete"
                save_checkpoint(args.checkpoint, "delete", args)
            except FileNotFoundError as e:
                log_event(f"❌ {e}")
                return

        success = True

    finally:
        if success and not args.keepfiles:
            for f in [args.temp, args.sorted, args.checkpoint]:
                if os.path.exists(f):
                    os.remove(f)
                    log_event(f"Deleted file after successful run: {f}")
        elif success and args.keepfiles:
            log_event("Intermediate files retained as per user request.")

        # Stop the log listener thread
        listener.stop()

    log_event("Duplicate detection script completed")

if __name__ == "__main__":
    main()
