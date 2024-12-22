import os
import logging
import argparse
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Define the directory and filename for the log file
log_directory = 'C:/users/manoj/Documents/Scripts'
log_filename = 'drive_monitor.log'

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

# Define the scope and authenticate using service account
SCOPES = ['https://www.googleapis.com/auth/drive']
SERVICE_ACCOUNT_FILE = 'C:/Users/manoj/Documents/Scripts/Google Drive JSON/ethereal-entity-443310-i4-96248e85f607.json'

credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES)

def get_drive_service():
    return build('drive', 'v3', credentials=credentials)

def get_storage_usage(service):
    try:
        about = service.about().get(fields="storageQuota").execute()
        logging.debug(f"Storage quota data: {about}")  # Log the entire storage quota data for debugging

        # Access different fields to get more accurate usage data
        usage_in_drive = int(about['storageQuota'].get('usageInDrive', 0))
        usage_in_drive_trash = int(about['storageQuota'].get('usageInDriveTrash', 0))
        total_usage = usage_in_drive + usage_in_drive_trash
        limit = int(about['storageQuota']['limit'])

        usage_percentage = (total_usage / limit) * 100
        logging.info(f"Current storage usage: {total_usage} bytes, Total limit: {limit} bytes, Usage: {usage_percentage:.2f}%")
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
    service = get_drive_service()
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