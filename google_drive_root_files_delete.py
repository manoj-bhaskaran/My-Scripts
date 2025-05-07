"""
Google Drive Root Files Deletion Script

This script deletes all non-folder files in the root directory of a Google Drive account.
"""

from __future__ import print_function
from googleapiclient.errors import HttpError
from google_drive_auth import authenticate_and_get_drive_service  # Import the reusable authentication function

def main():
    """
    Deletes all non-folder files in the root of Google Drive.
    """
    try:
        service = authenticate_and_get_drive_service()

        query = "'root' in parents and mimeType != 'application/vnd.google-apps.folder'"
        page_token = None
        deleted = 0

        while True:
            response = service.files().list(
                q=query,
                spaces='drive',
                fields="nextPageToken, files(id, name)",
                pageToken=page_token
            ).execute()

            for file in response.get('files', []):
                try:
                    service.files().delete(fileId=file['id']).execute()
                    deleted += 1
                    if deleted % 100 == 0:
                        print(f"Deleted {deleted} files...")
                except HttpError as error:
                    print(f"Failed to delete {file['name']}: {error}")

            page_token = response.get('nextPageToken', None)
            if page_token is None:
                break

        print(f"Finished. Deleted {deleted} files from root.")

    except HttpError as error:
        print(f"An error occurred: {error}")

if __name__ == '__main__':
    main()
