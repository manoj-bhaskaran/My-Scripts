from __future__ import print_function
from googleapiclient.errors import HttpError
from google_drive_auth import authenticate_and_get_drive_service
from tqdm import tqdm
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
import time

MAX_THREADS = 4

log_lock = threading.Lock()

def log_with_timestamp(message):
    with log_lock:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] {message}")

def get_root_files(service):
    query = "'root' in parents and mimeType != 'application/vnd.google-apps.folder'"
    page_token = None

    while True:
        response = service.files().list(
            q=query,
            spaces='drive',
            fields="nextPageToken, files(id, name)",
            pageToken=page_token,
            pageSize=1000
        ).execute()

        yield from response.get('files', [])
        page_token = response.get('nextPageToken', None)
        if not page_token:
            break

def delete_file(service, file, retries=3):
    for attempt in range(retries):
        try:
            service.files().delete(fileId=file['id']).execute()
            return True
        except HttpError as error:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                log_with_timestamp(f"Failed to delete {file['name']}: {error}")
                return False

def main():
    log_with_timestamp("Authenticating and starting process...")
    service = authenticate_and_get_drive_service()

    log_with_timestamp("Fetching file list...")
    files_to_delete = list(get_root_files(service))
    total_files = len(files_to_delete)
    log_with_timestamp(f"Found {total_files} non-folder files in root.")

    deleted_count = 0
    with tqdm(total=total_files, desc="Deleting files", unit="file") as pbar:
        with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
            futures = {executor.submit(delete_file, service, file): file for file in files_to_delete}
            for future in as_completed(futures):
                if future.result():
                    deleted_count += 1
                pbar.update(1)

    log_with_timestamp(f"Finished. Deleted {deleted_count} files from root.")

if __name__ == '__main__':
    main()
