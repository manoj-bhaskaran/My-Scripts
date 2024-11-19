import os
import sys
import logging
import requests

# Set up logging
def setup_logging(debug=False):
    if debug:
        logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
    else:
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Function to retrieve and validate the API key
def authenticate():
    logging.debug("Attempting to retrieve CloudConvert API key from environment variables.")
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        logging.error("CloudConvert API key not found in environment variables.")
        raise ValueError("CloudConvert API key not found in environment variables.")
    logging.debug(f"API key successfully retrieved: {api_key[:4]}...")  # Log only the first few characters for security
    return api_key

# Function to upload a file to CloudConvert
def upload_file(file_name):
    logging.debug(f"Starting file upload process for file: {file_name}")
    
    try:
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

        logging.debug("Making API request to create an upload task.")
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()  # Will raise an error for HTTP error responses

        logging.debug(f"Received response for upload task creation: {response.status_code}")
        
        # Extract the upload URL
        upload_task = response.json()["data"]["tasks"]["upload_task"]
        upload_url = upload_task["result"]["form"]["url"]
        logging.debug(f"Upload URL received: {upload_url}")

        # Step 2: Upload the file
        logging.debug(f"Attempting to upload file: {file_name}")
        with open(file_name, "rb") as file:
            files = {"file": file}
            upload_response = requests.post(upload_url, files=files)
            upload_response.raise_for_status()  # Will raise an error for HTTP error responses

        logging.info(f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}")
        return f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"

    except requests.exceptions.RequestException as e:
        logging.error(f"Error during file upload: {e}")
        raise Exception(f"Error during file upload: {e}")

# Main logic to handle the command line arguments
if __name__ == "__main__":
    debug_mode = '--debug' in sys.argv
    setup_logging(debug=debug_mode)

    # The file path argument is passed from the PowerShell script
    if len(sys.argv) > 2:
        file_name = sys.argv[2]
        upload_file(file_name)
    else:
        logging.error("File path is required.")
        sys.exit(1)
