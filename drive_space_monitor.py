import os
import logging
import argparse
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Define the directory and filename for the log file
log_directory = 'C:/users/manoj/Documents/Scripts'
log_filename = 'drive_monitor.log'
TOKEN_FILE = os.path.join(log_directory, 'drive_token.json')  # File to store OAuth tokens
CREDENTIALS_FILE = 'C:/Users/manoj/Documents/Scripts/Google Drive JSON/client_secret_616159019059-09mhd30aim0ug4fvim49kjfvjtk3i0dd.json'

# Ensure the directory exists
if not os.path.exists(log_directory):
    os.makedirs(log_directory)

# Function to set up logging
def setup_logging(debug):
    log_file_path = os.path.join(log_directory, log_filename)
    logging_level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(filename=log_file_path, level=logging_level,
                        format='%(asctime)s - %(levelname)s - %(message)s')
    # Add a console handler to see logs on the console as well
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging_level)
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logging.getLogger().addHandler(console_handler)

# Define the scope for Drive API access
SCOPES = ['https://www.googleapis.com/auth/drive.metadata.readonly']

def authenticate_and_get_drive_service():
    creds = None

    # Check if token already exists
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    # If no valid credentials, perform the OAuth flow
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
            # Save the credentials for future use
            with open(TOKEN_FILE, 'w') as token:
                token.write(creds.to_json())

    # Build the Drive API service
    return build('drive', 'v3', credentials=creds)

def format_size(bytes_size):
    # Define size units
    units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
    size = bytes_size
    unit_index = 0

    # Loop to find the correct unit
    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1

    return f"{size:.2f} {units[unit_index]}"

def get_storage_usage(service):
    try:
        about = service.about().get(fields="storageQuota").execute()
        logging.debug(f"Storage quota data: {about}")  # Log the entire storage quota data for debugging

        # Access different fields to get storage data
        usage_in_drive = int(about['storageQuota'].get('usageInDrive', 0))
        usage_in_drive_trash = int(about['storageQuota'].get('usageInDriveTrash', 0))
        total_usage = usage_in_drive + usage_in_drive_trash
        limit = int(about['storageQuota']['limit'])

        usage_percentage = (total_usage / limit) * 100

        # Convert sizes to human-readable format
        readable_total_usage = format_size(total_usage)
        readable_limit = format_size(limit)

        # Log storage usage in human-readable format
        logging.info(f"Current storage usage: {readable_total_usage} / {readable_limit} ({usage_percentage:.2f}%)")
        return usage_percentage, total_usage, limit
    except HttpError as error:
        logging.error(f"An error occurred: {error}")
        return None, None, None

def clear_trash(service):
    try:
        service.files().emptyTrash().execute()
        logging.info("Trash cleared successfully.")
    except HttpError as error:
        logging.error(f"An error occurred: {error}")

def main(debug):
    setup_logging(debug)
    service = authenticate_and_get_drive_service()
    usage_percentage, usage, limit = get_storage_usage(service)
    if usage_percentage is not None and usage_percentage > 90:
        logging.info(f"Storage usage exceeds 90%: {usage_percentage:.2f}% ({usage} of {limit} bytes). Clearing trash.")
        clear_trash(service)
    else:
        logging.info(f"Storage usage is within limits: {usage_percentage:.2f}% ({usage} of {limit} bytes).")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Google Drive Storage Monitor')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    args = parser.parse_args()
    main(args.debug)