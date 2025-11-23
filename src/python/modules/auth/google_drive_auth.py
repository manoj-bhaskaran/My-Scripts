"""
Google Drive Authentication Module

This module provides a reusable function to authenticate with the Google Drive API
and return an authenticated service instance. Uses the standard logging framework
to trace authentication progress.
"""

import os
from pathlib import Path
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
import python_logging_framework as plog

# Define the scope for Drive API access
SCOPES = ["https://www.googleapis.com/auth/drive"]


def _get_token_file():
    """
    Get token file path from environment or default location.

    Returns:
        str: Path to the token file.
    """
    if "GDRIVE_TOKEN_PATH" in os.environ:
        return os.environ["GDRIVE_TOKEN_PATH"]

    # Default to user's Documents/Scripts directory
    default_path = Path.home() / "Documents" / "Scripts" / "drive_token.json"
    return str(default_path)


def _get_credentials_file():
    """
    Get credentials file path from environment or default location.

    Returns:
        str: Path to the credentials file.
    """
    if "GDRIVE_CREDENTIALS_PATH" in os.environ:
        return os.environ["GDRIVE_CREDENTIALS_PATH"]

    # Default to user's Documents/Scripts directory
    default_path = Path.home() / "Documents" / "Scripts" / "credentials.json"
    return str(default_path)


# Define constants for token and credentials file
TOKEN_FILE = _get_token_file()
CREDENTIALS_FILE = _get_credentials_file()


def validate_credentials():
    """
    Validate that credential files exist and are accessible.

    Raises:
        FileNotFoundError: If the credentials file does not exist.

    Returns:
        bool: True if validation passes.
    """
    if not Path(CREDENTIALS_FILE).exists():
        raise FileNotFoundError(
            f"Google Drive credentials file not found: {CREDENTIALS_FILE}\n"
            f"Please set GDRIVE_CREDENTIALS_PATH environment variable or "
            f"place credentials.json in {Path.home() / 'Documents' / 'Scripts'}"
        )

    # TOKEN_FILE is created during OAuth flow, so it's OK if it doesn't exist initially
    return True


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
                with open(TOKEN_FILE, "w") as token:
                    token.write(creds.to_json())
                plog.log_info("✅ New token saved after OAuth flow.")
            except Exception as e:
                plog.log_error(f"❌ OAuth flow failed: {e}")
                raise

    plog.log_info("🚀 Google Drive service authenticated successfully.")
    return build("drive", "v3", credentials=creds)
