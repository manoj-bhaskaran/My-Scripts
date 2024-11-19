import os
import requests

# Function to retrieve and validate the API key
def authenticate():
    """
    Retrieves and validates the CloudConvert API key from the environment variable.

    Returns:
        str: The API key.
    Raises:
        ValueError: If the API key is not set or invalid.
    """
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        raise ValueError("CloudConvert API key not found in environment variables.")
    return api_key

# Function to upload a file to CloudConvert
def upload_file(file_name):
    """
    Uploads a file to CloudConvert.

    Args:
        file_name (str): The path to the file to upload.
    
    Returns:
        str: A success message indicating the upload result.
    Raises:
        Exception: If the file upload fails.
    """
    api_key = authenticate()

    # Step 1: Create an upload task
    url = "https://api.cloudconvert.com/v2/jobs"
    payload = {
        "tasks": {
            "upload_task": {
                "operation": "import/upload"
            }
        }
    }
    headers = {
        "Authorization": f"Bearer {api_key}",  # Bearer token for authentication
        "Content-Type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()

    # Extract the upload URL
    upload_task = response.json()["data"]["tasks"]["upload_task"]
    upload_url = upload_task["result"]["form"]["url"]

    # Step 2: Upload the file
    with open(file_name, "rb") as file:
        files = {"file": file}
        upload_response = requests.post(upload_url, files=files)
        upload_response.raise_for_status()

    return f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
