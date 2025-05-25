import os
import sys
import logging
import requests
import urllib.parse
import argparse
import time
from typing import Dict, Any, Tuple

# Constants for retry logic
max_retries = 60  # Total 5 minutes if delay is 5 seconds
retry_delay = 5   # Seconds

# Constants for task names
IMPORT_TASK = "import-my-file"
CONVERT_TASK = "convert-my-file"
EXPORT_TASK = "export-my-file"

# Base URL for CloudConvert API
CLOUDCONVERT_API_BASE = "https://api.cloudconvert.com/v2"

# Set up logging
def setup_logging(debug: bool = False) -> None:
    level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(level=level, format='%(asctime)s - %(levelname)s - %(message)s')

# Function to retrieve and validate the API key
def authenticate() -> str:
    logging.debug("Attempting to retrieve CloudConvert API key from environment variables.")
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        logging.error("CloudConvert API key not found in environment variables.")
        raise ValueError("CloudConvert API key not found in environment variables.")
    logging.debug("API key successfully retrieved.")
    return api_key

# Function to create an upload task
def create_upload_task(api_key: str) -> Dict[str, Any]:
    url = f"{CLOUDCONVERT_API_BASE}/jobs"
    payload = {
        "tasks": {
            "upload_task": {
                "operation": "import/upload"
            }
        }
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    logging.debug("Making API request to create an upload task.")
    response = requests.post(url, json=payload, headers=headers)

    if response.status_code != 201:
        logging.error(f"Error creating upload task: {response.status_code} - {response.text}")
        response.raise_for_status()

    return response.json()["data"]["tasks"][0]

# Function to handle file upload
def handle_file_upload(file_name: str, upload_url: str, parameters: Dict[str, str]) -> requests.Response:
    encoded_file_name = urllib.parse.quote(file_name)
    # use local_parameters in requests.post
    local_parameters = parameters.copy()
    # Replace placeholder in 'key' with actual file name, as expected by CloudConvert API
    local_parameters["key"] = local_parameters["key"].replace("${filename}", encoded_file_name)

    logging.debug(f"Upload URL: {upload_url}")
    logging.debug(f"Upload parameters: {parameters}")

    logging.debug(f"Attempting to upload file: {file_name}")
    with open(file_name, "rb") as file:
        files = {"file": file}
        upload_response = requests.post(upload_url, data=parameters, files=files)

        upload_response.raise_for_status()

    logging.info(f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}")
    return upload_response

# Function to upload a file
def upload_file(file_name: str) -> None:
    """
    Uploads a file to CloudConvert using a standalone upload-only job.
    Useful for testing or when only uploading without conversion.
    """
    logging.debug(f"Starting file upload process for file: {file_name}")
    
    try:
        api_key = authenticate()
        upload_task = create_upload_task(api_key)

        upload_url = upload_task["result"]["form"]["url"]
        parameters = upload_task["result"]["form"]["parameters"]
        upload_response = handle_file_upload(file_name, upload_url, parameters)

        result_message = f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
        logging.info(result_message)
        print(result_message)  # Print the result for PowerShell to capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        logging.error(f"Error during file upload: {e}")
        raise RuntimeError(f"Error during file upload: {e}") from e

# Function to create a conversion task
def create_conversion_task(api_key: str, output_format: str) -> Dict[str, Any]:
    url = "https://api.cloudconvert.com/v2/jobs"
    payload = {
        "tasks": {
            IMPORT_TASK: {
                "operation": "import/upload"
            },
            CONVERT_TASK: {
                "operation": "convert",
                "input": IMPORT_TASK,
                "output_format": output_format
            },
            EXPORT_TASK: {
                "operation": "export/url",
                "input": CONVERT_TASK
            }
        }
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    logging.debug("Making API request to create a conversion task.")
    response = requests.post(url, json=payload, headers=headers)

    if response.status_code != 201:
        logging.error(f"Error creating conversion task: {response.status_code} - {response.text}")
        response.raise_for_status()

    return response.json()["data"]

# Function to check the status of a task
def check_task_status(api_key: str, task_id: str) -> Dict[str, Any]:
    url = f"{CLOUDCONVERT_API_BASE}/tasks/{task_id}"
    headers = {
        "Authorization": f"Bearer {api_key}"
    }

    logging.debug(f"Checking status of task: {task_id}")
    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        logging.error(f"Error checking task status: {response.status_code} - {response.text}")
        response.raise_for_status()

    return response.json()["data"]

# Function to handle conversion
def convert_file(file_name: str, output_format: str) -> None:
    logging.debug(f"Starting conversion process for file: {file_name} to format: {output_format}")

    try:
        api_key = authenticate()
        conversion_task = create_conversion_task(api_key, output_format)
        logging.debug(f"Conversion task response: {conversion_task}")

        tasks = conversion_task["tasks"]
        if not isinstance(tasks, list):
            logging.error("Unexpected type for conversion_task['tasks']")
            raise ValueError("Expected list but found different type in conversion_task['tasks']")

        # Find and execute upload
        upload_task = next((task for task in tasks if task.get("name") == IMPORT_TASK), None)
        if not upload_task:
            raise ValueError(f"Task '{IMPORT_TASK}' not found in conversion_task['tasks']")
        handle_file_upload(file_name, upload_task["result"]["form"]["url"], upload_task["result"]["form"]["parameters"])

        # Poll for convert task
        convert_task = next((task for task in tasks if task.get("name") == CONVERT_TASK), None)
        if not convert_task:
            raise ValueError(f"Task '{CONVERT_TASK}' not found in conversion_task['tasks']")
        convert_task_id = convert_task["id"]

        try:
            for i in range(max_retries):
                status = check_task_status(api_key, convert_task_id)
                logging.info(f"Conversion status: {status['status']} (attempt {i+1}/{max_retries})")
                if status["status"] == "finished":
                    break
                elif status["status"] == "error":
                    logging.error(f"Conversion failed: {status.get('message', 'No error message provided.')}")
                    raise RuntimeError(f"CloudConvert conversion task failed: {status.get('message', 'No error message provided.')}")
                time.sleep(retry_delay)
            else:
                raise RuntimeError(f"CloudConvert conversion task timed out after {max_retries * retry_delay} seconds.")
        except (requests.exceptions.RequestException, KeyError, IndexError) as e:
            logging.error(f"Error while polling conversion task: {e}")
            raise RuntimeError("Polling for conversion task failed.") from e

        # Poll for export task
        export_task = next((task for task in tasks if task.get("name") == EXPORT_TASK), None)
        if not export_task:
            raise ValueError(f"Task '{EXPORT_TASK}' not found in conversion_task['tasks']")
        export_task_id = export_task["id"]

        try:
            for i in range(max_retries):
                export_status = check_task_status(api_key, export_task_id)
                logging.info(f"Export status: {export_status['status']} (attempt {i+1}/{max_retries})")
                if export_status["status"] == "finished":
                    break
                elif export_status["status"] == "error":
                    logging.error(f"Export failed: {export_status.get('message', 'No error message provided.')}")
                    raise RuntimeError(f"CloudConvert export task failed: {status.get('message', 'No error message provided.')}")
                time.sleep(retry_delay)
            else:
                raise RuntimeError(f"Export task timed out after {max_retries * retry_delay} seconds.")
        except (requests.exceptions.RequestException, KeyError, IndexError) as e:
            logging.error(f"Error while polling export task: {e}")
            raise RuntimeError("Polling for export task failed.") from e

        # Retrieve file
        files = export_status["result"].get("files", [])
        if not files:
            raise RuntimeError("No files found in export task result.")

        download_url = files[0]["url"]
        logging.info(f"File converted successfully. Download URL: {download_url}")
        print(f"File converted successfully. Download URL: {download_url}")  # For PowerShell capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError, RuntimeError) as e:
        logging.error(f"Error during file conversion: {e}")
        raise RuntimeError(f"Error during file conversion: {e}") from e

# Function to parse command-line arguments
def parse_arguments() -> Tuple[bool, str, str]:
    logging.debug(f"Raw sys.argv: {sys.argv}")
    parser = argparse.ArgumentParser(description='Upload and convert a file using CloudConvert.')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging.')
    parser.add_argument('file_name', type=str, help='The name of the file to be uploaded and converted.')
    parser.add_argument('output_format', type=str, help='The desired output format (e.g., jpg, pdf).')
    args = parser.parse_args()

    print(f"Parsed Arguments -> Debug: {args.debug}, File: {args.file_name}, Format: {args.output_format}")
    return args.debug, args.file_name, args.output_format

# Main function to be called
def main() -> None:
    debug, file_name, output_format = parse_arguments()
    setup_logging(debug)
    try:
        convert_file(file_name, output_format)
        sys.exit(0)  # Success
    except RuntimeError as e:
        logging.error(f"Runtime error: {e}")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
