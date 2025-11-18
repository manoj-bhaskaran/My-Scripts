"""
Google Drive Authentication Module

This module provides a reusable function to authenticate with the Google Drive API
and return an authenticated service instance. Uses the standard logging framework
to trace authentication progress.
"""

import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
import python_logging_framework as plog

# Define constants for token and credentials file
TOKEN_FILE = 'C:/users/manoj/Documents/Scripts/drive_token.json'
CREDENTIALS_FILE = 'C:/Users/manoj/Documents/Scripts/Google Drive JSON/client_secret_616159019059-09mhd30aim0ug4fvim49kjfvjtk3i0dd.json'

# Define the scope for Drive API access
SCOPES = ['https://www.googleapis.com/auth/drive']

def authenticate_and_get_drive_service():
    """
    Authenticates with the Google Drive API and returns a service instance.

    Returns:
        googleapiclient.discovery.Resource: Authenticated Google Drive API service instance.
    """
    creds = None

    if os.path.exists(TOKEN_FILE):
        try:
            creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
            plog.log_info("✅ Loaded existing token file for authentication.")
        except Exception as e:
            plog.log_warning(f"⚠️ Failed to load token file: {e}")

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
                plog.log_info("🔄 Refreshed expired credentials.")
            except Exception as e:
                plog.log_error(f"❌ Failed to refresh credentials: {e}")
                raise
        else:
            try:
                plog.log_info("🌐 Initiating OAuth flow.")
                flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
                with open(TOKEN_FILE, 'w') as token:
                    token.write(creds.to_json())
                plog.log_info("✅ New token saved after OAuth flow.")
            except Exception as e:
                plog.log_error(f"❌ OAuth flow failed: {e}")
                raise

    plog.log_info("🚀 Google Drive service authenticated successfully.")
    return build('drive', 'v3', credentials=creds)
