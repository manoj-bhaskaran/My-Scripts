"""
google_drive_root_files_delete.py

Deletes all non-folder files in the root directory of a Google Drive account using the Google Drive API.
Utilizes multithreading to speed up the deletion process and logs progress and errors.

Dependencies:
    - googleapiclient
    - google_drive_auth (custom authentication module)
    - tqdm
    - python_logging_framework (custom logging module)
    - concurrent.futures
    - threading
    - datetime
    - time

Usage:
    python google_drive_root_files_delete.py

Notes:
    - Ensure that authentication credentials are set up via google_drive_auth.
    - The script will log progress and errors to a log file (auto-named).
    - All non-folder files in the root of the authenticated user's Google Drive will be deleted.
"""

from __future__ import print_function
import sys
from pathlib import Path

# Add module paths to sys.path for imports
script_dir = Path(__file__).resolve().parent
repo_root = script_dir.parent.parent.parent
modules_logging = repo_root / "src" / "python" / "modules" / "logging"
modules_auth = repo_root / "src" / "python" / "modules" / "auth"

sys.path.insert(0, str(modules_logging))
sys.path.insert(0, str(modules_auth))

from googleapiclient.errors import HttpError
from google_drive_auth import authenticate_and_get_drive_service
from google.auth.credentials import Credentials
from tqdm import tqdm
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
import time
import python_logging_framework as plog

# Initialize logger for this module
# Use __file__ instead of __name__ to ensure correct log file naming and path resolution
logger = plog.initialise_logger(__file__, log_dir=repo_root / "logs")

MAX_THREADS = 4  # Maximum number of threads for parallel deletion

log_lock = threading.Lock()


def get_root_files(service):
    """
    Generator that yields all non-folder files in the root directory of Google Drive.

    Args:
        service: Authorized Google Drive API service instance.

    Yields:
        dict: File metadata dictionary for each non-folder file in the root.
    """
    query = "'root' in parents and mimeType != 'application/vnd.google-apps.folder'"
    page_token = None

    while True:
        response = (
            service.files()
            .list(
                q=query,
                spaces="drive",
                fields="nextPageToken, files(id, name, mimeType)",
                pageToken=page_token,
                pageSize=1000,
            )
            .execute()
        )

        yield from (
            file
            for file in response.get("files", [])
            if file.get("mimeType") != "application/vnd.google-apps.folder"
        )
        page_token = response.get("nextPageToken", None)
        if not page_token:
            break


from googleapiclient.discovery import build


def _resolve_service(creds_or_service):
    """Return a Drive service from either credentials or an existing service."""

    if hasattr(creds_or_service, "files"):
        return creds_or_service

    return build("drive", "v3", credentials=creds_or_service)


def delete_file(creds_or_service, file_id, file_name, retries=3):
    """
    Deletes a file from Google Drive with retry logic.

    Args:
        creds_or_service: Google authentication credentials or Drive service instance.
        file_id (str): Identifier of the file to delete.
        file_name (str): Name of the file to report in logs.
        retries (int): Number of retry attempts on failure.

    Returns:
        bool: True if deletion was successful, False otherwise.
    """
    service = _resolve_service(creds_or_service)
    for attempt in range(retries):
        try:
            service.files().delete(fileId=file_id).execute()
            return True
        except HttpError as error:
            if attempt < retries - 1:
                time.sleep(2**attempt)
            else:
                plog.log_info(logger, f"Failed to delete {file_name}: {error}")
                return False


def main():
    """
    Main function to authenticate, fetch, and delete all non-folder files in the root of Google Drive.
    Logs progress and summary information.
    """
    # Logger already initialized at module level
    plog.log_info(logger, "Authenticating and starting process...")
    service = authenticate_and_get_drive_service()

    creds = service._http.credentials  # Extract the creds from the service

    plog.log_info(logger, "Fetching file list...")
    files_to_delete = list(get_root_files(service))
    total_files = len(files_to_delete)
    plog.log_info(logger, f"Found {total_files} non-folder files in root.")

    deleted_count = 0
    with tqdm(total=total_files, desc="Deleting files", unit="file") as pbar:
        with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
            futures = {
                executor.submit(delete_file, creds, file["id"], file["name"]): file
                for file in files_to_delete
            }
            for future in as_completed(futures):
                if future.result():
                    deleted_count += 1
                pbar.update(1)

    plog.log_info(logger, f"Finished. Deleted {deleted_count} files from root.")


if __name__ == "__main__":
    main()

# This script deletes all non-folder files in the root of a Google Drive account.
# It uses multithreading to speed up the deletion process.
