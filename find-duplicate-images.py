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

FILE_UNIT = " file(s)"

def load_checkpoint(path):
    """
    Loads the checkpoint file if it exists and returns the stored state information.

    Args:
        path (str): Path to the checkpoint JSON file.

    Returns:
        dict: Checkpoint metadata if available, otherwise an empty dictionary.
    """

    if not os.path.exists(path):
        return {}
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def save_checkpoint(path, stage_name, args):
    """
    Saves the current pipeline state to a checkpoint file in JSON format.

    Args:
        path (str): Destination path for the checkpoint file.
        stage_name (str): The current completed stage name (e.g., "stage1", "stage2").
        args (argparse.Namespace): Command-line arguments containing folder paths and file locations.

    Notes:
        The following keys are saved:
        - completed_stage: The last successfully completed stage
        - folder: The folder being scanned
        - output: The final output file for duplicates
        - temp: The temporary file for raw file list
        - sorted: The sorted file list path
    """

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
    """
    Ensures that the target path is within the given base directory to prevent directory traversal.

    Args:
        base (str): The base directory path.
        target (str): The path to validate.

    Returns:
        bool: True if the target path is safely contained within the base directory; False otherwise.
    """

    base = os.path.abspath(base)
    target = os.path.abspath(target)
    return os.path.commonpath([base]) == os.path.commonpath([base, target])

def log_event(message):
    """
    Logs an informational message using the configured logging system.

    Args:
        message (str): The message to be logged.
    """

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
    """
    Recursively scans the given folder and yields file paths.

    Args:
        folder (str): The root folder to scan.

    Yields:
        str: Absolute path to each regular file found, excluding symlinks and inaccessible directories.
    """

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
    Lists all regular files in the given folder and writes their sizes and paths to a CSV file.

    Args:
        folder (str): The folder to scan for files.
        out_csv (str): Path to the output CSV file.

    Output Format:
        The CSV will contain two columns (no header):
            - size (in bytes)
            - absolute file path
        One row per file.

    Notes:
        Uses parallel threads to speed up size computation.
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
            with tqdm(total=len(futures), desc="Processing files", unit=FILE_UNIT, dynamic_ncols=True) as pbar:
                for future in as_completed(futures):
                    result = future.result()
                    if result:
                        writer.writerow(result)
                    pbar.update(1)

    log_event(f"Completed Stage 1: File list written to {out_csv}")

def stage2_sort_csv(input_csv, sorted_csv):
    """
    Sorts a CSV file of file sizes and paths in ascending order by file size.

    Args:
        input_csv (str): Path to the input CSV file from Stage 1.
        sorted_csv (str): Path to the output CSV file containing sorted entries.

    Input Format:
        CSV with two columns (no header):
            - size (int)
            - absolute file path

    Output Format:
        CSV with the same structure, sorted in ascending order of file size.
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
    Counts the total number of files that need to be hashed based on grouped file size duplicates.

    Args:
        grouped_rows (List[Tuple[int, List[Tuple[int, str]]]]):
            A list of groups where each group is a tuple of:
            - file size (int)
            - list of (size, file path) tuples with the same size

    Returns:
        int: Count of files to be hashed across all duplicate candidate groups.
    """

    return sum(len(group_list) for _, group_list in grouped_rows)

def _hash_and_write_duplicates(grouped_rows, output_file, total_files, skip_sizes=None, starting_group_id=1):
    """
    Hashes files in each size-based group and appends new duplicate entries to the output CSV.

    This function supports resumability by allowing selective skipping of already-processed file sizes
    and continuing from a specified group ID.

    Args:
        grouped_rows (List[Tuple[int, List[Tuple[int, str]]]]):
            List of groups of files with the same size. Each group is a tuple:
            - file size (int)
            - list of (size, file_path) tuples

        output_file (str): Path to the CSV file where detected duplicate records will be written.
        total_files (int): Total number of files considered for hashing (used for progress bar).
        skip_sizes (Set[int], optional): Set of file sizes to skip (already processed). Defaults to empty set.
        starting_group_id (int, optional): Group ID to begin from when writing new duplicate groups. Defaults to 1.

    Behavior:
        - Skips groups with sizes in `skip_sizes`.
        - Appends to `output_file` if it already exists, writing only new entries.
        - Each output row includes: group_id, size, md5_hash, file_path.
    """

    if skip_sizes is None:
        skip_sizes = set()

    def compute_md5_safe(path):
        """
        Safely computes the MD5 hash of a file, suppressing and logging any exceptions.

        Args:
            path (str): Path to the file to hash.

        Returns:
            str or None: MD5 hash of the file, or None if an error occurred during hashing.
        """

        try:
            return compute_md5(path)
        except Exception as e:
            logging.warning(f"Hashing failed for {path}: {e}")
            return None

    open_mode = "a" if os.path.exists(output_file) else "w"
    with open(output_file, open_mode, newline='', encoding='utf-8') as f_out:
        writer = csv.writer(f_out)
        if open_mode == "w":
            writer.writerow(["group_id", "size", "md5_hash", "file_path"])

        duplicate_sets = starting_group_id - 1
        with tqdm(total=total_files, desc="Hashing files", unit=FILE_UNIT, dynamic_ncols=True) as pbar:
            for size, group_list in grouped_rows:
                if size in skip_sizes:
                    pbar.update(len(group_list))
                    continue

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

        log_event(f"Completed Stage 3: {duplicate_sets - starting_group_id + 1} new duplicate groups found")

def stage3_find_duplicates(sorted_csv, output_file, is_restart=False):
    """
    Identifies duplicate files by hashing and writes the results to a CSV file.

    If is_restart is True, previously processed hashes in the output file are skipped.

    Args:
        sorted_csv (str): Path to the sorted file list CSV.
        output_file (str): Path to the output CSV file for duplicates.
        is_restart (bool): Whether the script is resuming from a checkpoint.
    """
    log_event("Starting Stage 3: Hashing and duplicate detection")

    grouped_rows = _read_sorted_csv(sorted_csv)
    total_files_to_hash = _count_hashable_files(grouped_rows)

    if is_restart and os.path.exists(output_file):
        starting_group_id, skip_sizes = _load_completed_hashes(output_file)
    else:
        starting_group_id, skip_sizes = 1, set()
        
    _hash_and_write_duplicates(grouped_rows, output_file, total_files_to_hash, skip_sizes, starting_group_id)

    log_event(f"Completed Stage 3: Duplicate list updated in {output_file}")

def read_csv_groups(dup_csv):
    """
    Reads duplicate file information from a CSV and groups files by their group ID.

    Args:
        dup_csv (str): Path to CSV file containing duplicate file information.

    Returns:
        dict: A dictionary where keys are group IDs and values are lists of file paths.
    """

    grouped = defaultdict(list)
    with open(dup_csv, newline='', encoding='utf-8') as f_in:
        reader = csv.DictReader(f_in)
        for row in reader:
            grouped[row["group_id"]].append(row["file_path"])
    return grouped

def process_duplicates(grouped, dryrun, backup_folder, total_files):
    """
    Processes duplicate files by either deleting or moving them.

    Args:
        grouped (dict): Dictionary of duplicate file groups.
        dryrun (bool): If True, performs a preview without actual deletions.
        backup_folder (str, optional): Destination folder to move duplicate files instead of deleting.
        total_files (int): Total number of duplicate files to process.

    Returns:
        int: Count of deleted or moved files.
    """

    deleted_count = 0

    with tqdm(total=total_files, desc="Deleting duplicates", unit=FILE_UNIT, dynamic_ncols=True) as pbar, \
         ThreadPoolExecutor() as executor:

        futures = []
        for files in grouped.values():
            if len(files) <= 1:
                continue
            
            retained = random.choice(files)
            futures += [executor.submit(delete_or_move_file, f, retained, dryrun, backup_folder) for f in files]

        for future in as_completed(futures):
            deleted_count += future.result()
            pbar.update(1)

    return deleted_count

def delete_or_move_file(file_path, retained, dryrun, backup_folder):
    """
    Deletes or moves a duplicate file unless it is the retained file.

    Args:
        file_path (str): Path of the file to delete or move.
        retained (str): Path of the file chosen to be kept.
        dryrun (bool): If True, performs a preview without actual deletions.
        backup_folder (str, optional): Destination folder to move duplicate files instead of deleting.

    Returns:
        int: 1 if file was deleted/moved, 0 otherwise.
    """

    if file_path == retained:
        return 0

    if dryrun:
        log_event(f"[DRYRUN] Would delete: {file_path}")
    else:
        try:
            if backup_folder:
                os.makedirs(backup_folder, exist_ok=True)
                shutil.move(file_path, os.path.join(backup_folder, os.path.basename(file_path)))
                log_event(f"Moved: {file_path} → {backup_folder}")
            else:
                os.remove(file_path)
                log_event(f"Deleted: {file_path}")
            return 1
        except Exception as e:
            logging.warning(f"Failed to delete/move {file_path}: {e}")
            return 0

def log_final_summary(total_groups, deleted_count, dryrun):
    """
    Logs the final summary of the duplicate cleanup process.

    Args:
        total_groups (int): Number of duplicate groups processed.
        deleted_count (int): Total number of deleted or moved files.
        dryrun (bool): If True, logs a preview of what would have been deleted.

    Returns:
        None
    """

    action = "would be deleted" if dryrun else "Deleted/Moved"
    log_event("Duplicate cleanup completed. Retained one file per group.")
    log_event(f"[{action}] {deleted_count} files from {total_groups} duplicate groups.")

def delete_duplicates(dup_csv, dryrun=False, backup_folder=None):
    """
    Deletes or moves duplicate files while retaining one file per group.

    Args:
        dup_csv (str): Path to CSV file containing duplicate file information.
        dryrun (bool): If True, performs a preview without actual deletions.
        backup_folder (str, optional): Destination folder to move duplicate files instead of deleting.

    Returns:
        None
    """

    if not os.path.exists(dup_csv):
        raise FileNotFoundError(f"Cannot perform deletion — stage3 output not found: {dup_csv}")

    grouped = read_csv_groups(dup_csv)
    total_files = sum(len(files) - 1 for files in grouped.values() if len(files) > 1)

    deleted_count = process_duplicates(grouped, dryrun, backup_folder, total_files)

    log_final_summary(len(grouped), deleted_count, dryrun)

def parse_arguments():
    """
    Parses command-line arguments provided to the script.

    Returns:
        argparse.Namespace: Object containing parsed CLI arguments such as folder paths,
        logging configuration, and stage control options.
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

    return args

def prepare_environment(args):
    """
    Prepares the runtime environment by configuring the logging system and
    deleting any stale intermediate files if not resuming from a checkpoint.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.
    """

    # Queue-based logging setup
    log_queue = queue.Queue()
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler = logging.FileHandler(args.log)
    file_handler.setFormatter(formatter)

    listener = QueueListener(log_queue, file_handler)
    queue_handler = QueueHandler(log_queue)
    logging.getLogger().setLevel(logging.INFO)
    logging.getLogger().handlers = [queue_handler]
    listener.start()

    args._log_listener = listener  # attach to args for later stopping
    log_event("Logging system initialized with queue handler.")

    if not args.restart:
        for f in [args.temp, args.sorted, args.checkpoint]:
            if os.path.exists(f):
                os.remove(f)
                log_event(f"Deleted stale file at startup (no restart): {f}")

def handle_restart(args):
    """
    Handles restart logic by reading the checkpoint file, restoring relevant arguments,
    and determining the stage to resume from. Also prints resume status to the console.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.

    Returns:
        dict or None: Checkpoint dictionary if valid for resuming; None if resume is not possible.
    """

    checkpoint = load_checkpoint(args.checkpoint)

    if not checkpoint:
        log_event("Checkpoint file not found or invalid. Cannot resume.")
        print("No valid checkpoint found — cannot resume.")
        return None

    log_event("Restart requested by user.")
    args.folder = checkpoint.get("folder", args.folder)
    args.output = checkpoint.get("output", args.output)
    args.temp = checkpoint.get("temp", args.temp)
    args.sorted = checkpoint.get("sorted", args.sorted)

    stage_map = {
        None: "Stage 1",
        "stage1": "Stage 2",
        "stage2": "Stage 3",
        "stage3": "Deletion Stage" if args.delete else "Already completed — nothing to do",
        "delete": "Already completed — nothing to do"
    }

    resume_stage = checkpoint.get("completed_stage")
    log_event(f"Resuming from: {stage_map.get(resume_stage, 'Unknown stage')}")
    print(f"➡️  Restart requested — resuming from: {stage_map.get(resume_stage)}")

    if resume_stage == "stage3" and not args.delete:
        print("✅ All stages already completed — nothing to do.")
        return None
    elif resume_stage == "delete":
        print("✅ All stages including deletion already completed — nothing to do.")
        return None

    return checkpoint

def run_pipeline(args, checkpoint):
    """
    Executes the staged pipeline: file listing, sorting, duplicate detection, and optional deletion.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.
        checkpoint (dict): Checkpoint metadata indicating completed stage (or empty for fresh run).

    Returns:
        bool: Indicates whether the pipeline stages executed successfully (True) or failed (False).
    """

    success = False
    completed_stage = checkpoint.get("completed_stage") if args.restart else None

    try:
        if completed_stage is None:
            stage1_list_files(args.folder, args.temp)
            completed_stage = "stage1"
            save_checkpoint(args.checkpoint, "stage1", args)

        if completed_stage == "stage1":
            stage2_sort_csv(args.temp, args.sorted)
            completed_stage = "stage2"
            save_checkpoint(args.checkpoint, "stage2", args)

        if completed_stage == "stage2":
            stage3_find_duplicates(args.sorted, args.output, is_restart=args.restart)
            completed_stage = "stage3"
            save_checkpoint(args.checkpoint, "stage3", args)

        if args.delete and not os.path.exists(args.output):
            log_event(f"❌ Cannot perform deletion — stage3 output not found: {args.output}")
            print(f"❌ Cannot perform deletion — stage3 output not found: {args.output}")
            return False

            delete_duplicates(args.output, dryrun=args.dryrun, backup_folder=args.backup_folder)
            save_checkpoint(args.checkpoint, "delete", args)

        success = True
        return success

    except Exception as e:
        log_event(f"Pipeline execution failed: {e}")
        raise

def final_cleanup(success, args):
    """
    Performs final cleanup tasks after successful execution, including deletion of
    intermediate files (if not retained) and stopping the logging listener thread.

    Args:
        success (bool): Indicates whether the pipeline completed without errors.
        args (argparse.Namespace): Parsed command-line arguments.
    """

    if success and not args.keepfiles:
        for f in [args.temp, args.sorted, args.checkpoint]:
            if os.path.exists(f):
                os.remove(f)
                log_event(f"Deleted file after successful run: {f}")
    elif success and args.keepfiles:
        log_event("Intermediate files retained as per user request.")

    # Stop logging listener
    args._log_listener.stop()

def _load_completed_hashes(output_file):
    """
    Loads already processed duplicate groups from a previous Stage 3 output CSV.

    Args:
        output_file (str): Path to Stage 3 output file (if exists).

    Returns:
        Tuple[int, Set[int]]: The next group_id to use and set of already processed file sizes.
    """
    if not os.path.exists(output_file):
        return 1, set()  # fresh start

    completed_sizes = set()
    max_group_id = 0

    with open(output_file, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                completed_sizes.add(int(row["size"]))
                max_group_id = max(max_group_id, int(row["group_id"]))
            except Exception:
                continue  # skip malformed lines

    return max_group_id + 1, completed_sizes

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
    args = parse_arguments()
    prepare_environment(args)

    log_event("Duplicate detection script started")

    checkpoint = {}
    if args.restart:
        checkpoint = handle_restart(args)
        if checkpoint is None:
            return

    success = run_pipeline(args, checkpoint)
    final_cleanup(success, args)

    log_event("Duplicate detection script completed")

if __name__ == "__main__":
    main()
