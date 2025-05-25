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

def setup_logging(debug: bool = False) -> None:
    """
    Configures the logging level and format.

    Args:
        debug (bool): If True, sets logging level to DEBUG. Defaults to INFO.
    """
    level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(level=level, format='%(asctime)s - %(levelname)s - %(message)s')

def authenticate() -> str:
    """
    Retrieves the CloudConvert API key from the environment.

    Returns:
        str: The API key.

    Raises:
        ValueError: If the environment variable is not set.
    """
    logging.debug("Attempting to retrieve CloudConvert API key from environment variables.")
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        logging.error("CloudConvert API key not found in environment variables.")
        raise ValueError("CloudConvert API key not found in environment variables.")
    logging.debug("API key successfully retrieved.")
    return api_key

def create_upload_task(api_key: str) -> Dict[str, Any]:
    """
    Creates a CloudConvert job with a single upload task.

    Args:
        api_key (str): The CloudConvert API key.

    Returns:
        Dict[str, Any]: The task dictionary containing upload instructions.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
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

def handle_file_upload(file_name: str, upload_url: str, parameters: Dict[str, str]) -> requests.Response:
    """
    Uploads a file to CloudConvert using the given upload URL and parameters.

    Args:
        file_name (str): The path to the file to upload.
        upload_url (str): The CloudConvert upload URL.
        parameters (Dict[str, str]): Parameters including the upload key.

    Returns:
        requests.Response: The HTTP response object.

    Raises:
        RuntimeError: If the upload request fails.
    """ 
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
        try:
            upload_response = requests.post(upload_url, data=local_parameters, files=files)
            upload_response.raise_for_status()
        except requests.exceptions.RequestException as e:
            logging.error(f"Error during file upload request: {e}")
            raise RuntimeError(f"Failed to upload file '{file_name}' to CloudConvert.") from e

    logging.info(f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}")
    return upload_response

def upload_file(file_name: str) -> None:
    """
    Performs a standalone upload of a file using a dedicated CloudConvert upload job.

    Args:
        file_name (str): The path to the file to upload.

    Raises:
        RuntimeError: If any step in the upload process fails.
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

def create_conversion_task(api_key: str, output_format: str) -> Dict[str, Any]:
    """
    Creates a CloudConvert job for uploading, converting, and exporting a file.

    Args:
        api_key (str): The CloudConvert API key.
        output_format (str): Desired output format (e.g., 'pdf', 'jpg').

    Returns:
        Dict[str, Any]: The job definition returned by the API.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
    url = f"{CLOUDCONVERT_API_BASE}/jobs"
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

def check_task_status(api_key: str, task_id: str) -> Dict[str, Any]:
    """
    Checks the status of a CloudConvert task.

    Args:
        api_key (str): The CloudConvert API key.
        task_id (str): The ID of the task to check.

    Returns:
        Dict[str, Any]: The task status response.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
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

def convert_file(file_name: str, output_format: str) -> None:
    """
    Converts a file using CloudConvert by uploading, polling conversion status,
    and retrieving the final export URL.

    Args:
        file_name (str): Path to the source file.
        output_format (str): Desired output format.

    Raises:
        RuntimeError: If any stage of the conversion process fails.
    """
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

    except RuntimeError as e:
        logging.error(f"Error during file conversion: {e}")
        raise  # Re-raise as-is

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        logging.error(f"Error during file conversion: {e}")
        raise RuntimeError(f"Error during file conversion: {e}") from e

def parse_arguments() -> Tuple[bool, str, str]:
    """
    Parses command-line arguments for the script.

    Returns:
        Tuple[bool, str, str]: A tuple containing:
            - debug (bool): Whether debug logging is enabled.
            - file_name (str): The input file to be uploaded.
            - output_format (str): The desired output format.
    """
    logging.debug(f"Raw sys.argv: {sys.argv}")
    parser = argparse.ArgumentParser(description='Upload and convert a file using CloudConvert.')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging.')
    parser.add_argument('file_name', type=str, help='The name of the file to be uploaded and converted.')
    parser.add_argument('output_format', type=str, help='The desired output format (e.g., jpg, pdf).')
    args = parser.parse_args()

    print(f"Parsed Arguments -> Debug: {args.debug}, File: {args.file_name}, Format: {args.output_format}")
    return args.debug, args.file_name, args.output_format

def main() -> None:
    """
    Main entry point for the script. Handles argument parsing, logging setup,
    and file conversion, with appropriate exit codes.
    """
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
