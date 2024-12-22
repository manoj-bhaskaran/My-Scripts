import os
import logging
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Setup logging
logging.basicConfig(filename='drive_monitor.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Define the scope and authenticate using service account
SCOPES = ['https://www.googleapis.com/auth/drive']
SERVICE_ACCOUNT_FILE = 'C:/Users/manoj/Documents/Scripts/Google Drive JSON/client_secret_616159019059-8hm47qh9eoph2k9rhtvhpph3qjam4msh.json'

credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES)

def get_drive_service():
    return build('drive', 'v3', credentials=credentials)

def get_storage_usage(service):
    try:
        about = service.about().get(fields="storageQuota").execute()
        usage = int(about['storageQuota']['usage'])
        limit = int(about['storageQuota']['limit'])
        usage_percentage = (usage / limit) * 100
        logging.info(f"Current storage usage: {usage_percentage:.2f}%")
        return usage_percentage
    except HttpError as error:
        logging.error(f"An error occurred: {error}")
        return None

def clear_trash(service):
    try:
        service.files().emptyTrash().execute()
        logging.info("Trash cleared successfully.")
    except HttpError as error:
        logging.error(f"An error occurred: {error}")

def main():
    service = get_drive_service()
    usage_percentage = get_storage_usage(service)
    if usage_percentage and usage_percentage > 90:
        logging.info(f"Storage usage exceeds 90%: {usage_percentage:.2f}%. Clearing trash.")
        clear_trash(service)
    else:
        logging.info(f"Storage usage is within limits: {usage_percentage:.2f}%.")


if __name__ == '__main__':
    main()
