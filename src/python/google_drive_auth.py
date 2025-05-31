"""
Google Drive Authentication Module

This module provides a reusable function to authenticate with the Google Drive API
and return an authenticated service instance.
"""

import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

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
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
            with open(TOKEN_FILE, 'w') as token:
                token.write(creds.to_json())

    return build('drive', 'v3', credentials=creds)