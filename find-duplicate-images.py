import os
import hashlib
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import argparse
import logging

def compute_md5(file_path):
    """
    Compute the MD5 hash of a file.

    Args:
        file_path (str): Path to the file.

    Returns:
        str: MD5 hash of the file, or None if an error occurs.
    """
    hash_md5 = hashlib.md5()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception as e:
        logging.error(f"Error hashing file {file_path}: {e}")
        return None

def find_duplicates(folder, log_file):
    """
    Identify duplicate images in a directory structure.

    Args:
        folder (str): Path to the directory to scan for duplicates.
        log_file (str): Path to the log file where results will be saved.

    Returns:
        None
    """
    logging.basicConfig(filename=log_file, level=logging.INFO, 
                        format='%(asctime)s - %(levelname)s - %(message)s')
    logging.info("Starting duplicate image detection.")

    # Step 1: Group files by size
    size_groups = defaultdict(list)
    all_files = []
    for root, _, files in os.walk(folder):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                file_size = os.path.getsize(file_path)
                size_groups[file_size].append(file_path)
                all_files.append(file_path)
            except Exception as e:
                logging.warning(f"Error accessing file {file_path}: {e}")

    # Step 2: Compute MD5 hashes for final confirmation
    duplicates = []
    with ThreadPoolExecutor() as executor:
        futures = {}
        for size, files in size_groups.items():
            if len(files) > 1:  # Only process groups with potential duplicates
                for file_path in files:
                    futures[executor.submit(compute_md5, file_path)] = file_path

        # Use tqdm to display progress
        with tqdm(total=len(futures), desc="Hashing files") as pbar:
            for future in as_completed(futures):
                file_path = futures[future]
                try:
                    file_hash = future.result()
                    if file_hash:
                        duplicates.append((file_hash, file_path))
                except Exception as e:
                    logging.warning(f"Error hashing file {file_path}: {e}")
                pbar.update(1)
            file_path = futures[future]
            try:
                file_hash = future.result()
                if file_hash:
                    duplicates.append((file_hash, file_path))
            except Exception as e:
                logging.warning(f"Error hashing file {file_path}: {e}")

    # Step 3: Group duplicates by hash
    hash_groups = defaultdict(list)
    for file_hash, file_path in duplicates:
        hash_groups[file_hash].append(file_path)

    # Step 4: Log duplicate groups
    logging.info("Duplicate groups found:")
    duplicate_count = 0
    for file_hash, files in hash_groups.items():
        # Only log actual duplicates (exclude single files or self-duplicates)
        unique_files = list(set(files))  # Remove self-duplicates
        if len(unique_files) > 1:
            duplicate_count += 1
            logging.info(f"Duplicate group {duplicate_count}:")
            for file in unique_files:
                logging.info(f"  {file}")

    # Print summary to console
    print(f"Duplicate detection complete. {duplicate_count} duplicate groups found.")
    print(f"Details logged to {log_file}.")

if __name__ == "__main__":
    """
    Main script entry point. Parses command-line arguments and initiates duplicate detection.

    Command-line Arguments:
        --folder (str): Input directory to scan for duplicates. Defaults to the specified directory.
        --log (str): Path to the log file where results will be saved. Defaults to 'duplicate-images-log.txt'.

    Returns:
        None
    """
    parser = argparse.ArgumentParser(description="Identify duplicate images in a directory.")
    parser.add_argument("--folder", type=str, default="D:\\users\\Manoj\\Documents\\FIFA 07\\elib", 
                        help="Input directory to scan.")
    parser.add_argument("--log", type=str, default="C:\\Users\\manoj\\Documents\\Scripts\\duplicate-images.log", 
                        help="Output log file path.")
    args = parser.parse_args()

    find_duplicates(args.folder, args.log)