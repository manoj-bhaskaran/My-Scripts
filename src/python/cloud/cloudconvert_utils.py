import os
import sys
import requests
import urllib.parse
import argparse
import time
import logging
from typing import Dict, Any, Tuple
from requests.exceptions import Timeout, RequestException
import python_logging_framework as plog

# Initialize logger for this module
logger = plog.initialise_logger(__name__)

# Constants for retry logic
max_retries = 60  # Total 5 minutes if delay is 5 seconds
retry_delay = 5  # Seconds

# Timeout constants (connect_timeout, read_timeout) in seconds
TIMEOUT_QUICK: Tuple[int, int] = (5, 15)  # Status checks
TIMEOUT_STANDARD: Tuple[int, int] = (5, 30)  # API calls
TIMEOUT_UPLOAD: Tuple[int, int] = (10, 300)  # File uploads (5 minutes)
TIMEOUT_DOWNLOAD: Tuple[int, int] = (10, 300)  # File downloads

# Constants for task names
IMPORT_TASK = "import-my-file"
CONVERT_TASK = "convert-my-file"
EXPORT_TASK = "export-my-file"

# Base URL for CloudConvert API
CLOUDCONVERT_API_BASE = "https://api.cloudconvert.com/v2"


def authenticate() -> str:
    """
    Retrieve the CloudConvert API key from environment variables.

    Returns:
        str: The CloudConvert API key.

    Raises:
        ValueError: If the API key is not found in environment variables.
    """
    plog.log_debug(
        logger, "Attempting to retrieve CloudConvert API key from environment variables."
    )
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        plog.log_error(logger, "CloudConvert API key not found in environment variables.")
        raise ValueError("CloudConvert API key not found in environment variables.")
    plog.log_debug(logger, "API key successfully retrieved.")
    return api_key


def create_upload_task(api_key: str) -> Dict[str, Any]:
    """
    Create an upload task on CloudConvert.

    Args:
        api_key (str): The CloudConvert API key.

    Returns:
        Dict[str, Any]: The upload task information.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
    url = f"{CLOUDCONVERT_API_BASE}/jobs"
    payload = {"tasks": {"upload_task": {"operation": "import/upload"}}}
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    plog.log_debug(logger, "Making API request to create an upload task.")
    try:
        response = requests.post(
            url, json=payload, headers=headers, timeout=TIMEOUT_STANDARD
        )
    except Timeout as e:
        plog.log_error(
            logger, f"Request timed out after {TIMEOUT_STANDARD} seconds: {e}"
        )
        raise
    except RequestException as e:
        plog.log_error(logger, f"Request failed: {e}")
        raise

    if response.status_code != 201:
        plog.log_error(
            logger, f"Error creating upload task: {response.status_code} - {response.text}"
        )
        response.raise_for_status()

    return response.json()["data"]["tasks"][0]


def handle_file_upload(
    file_name: str, upload_url: str, parameters: Dict[str, str]
) -> requests.Response:
    """
    Upload a file to CloudConvert using the provided upload URL and parameters.

    Args:
        file_name (str): The local file name to upload.
        upload_url (str): The URL to which the file should be uploaded.
        parameters (Dict[str, str]): Additional parameters required for the upload.

    Returns:
        requests.Response: The response from the upload request.

    Raises:
        RuntimeError: If the upload fails.
    """
    encoded_file_name = urllib.parse.quote(file_name)
    local_parameters = parameters.copy()
    local_parameters["key"] = local_parameters["key"].replace("${filename}", encoded_file_name)

    plog.log_debug(logger, f"Upload URL: {upload_url}")
    plog.log_debug(logger, f"Upload parameters: {parameters}")
    plog.log_debug(logger, f"Attempting to upload file: {file_name}")
    with open(file_name, "rb") as file:
        files = {"file": file}
        try:
            upload_response = requests.post(
                upload_url,
                data=local_parameters,
                files=files,
                timeout=TIMEOUT_UPLOAD,
            )
            upload_response.raise_for_status()
        except requests.exceptions.RequestException as e:
            plog.log_error(logger, f"Error during file upload request: {e}")
            raise RuntimeError(f"Failed to upload file '{file_name}' to CloudConvert.") from e

    plog.log_info(
        logger,
        f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}",
    )
    return upload_response


def upload_file(file_name: str) -> None:
    """
    Upload a file to CloudConvert.

    Args:
        file_name (str): The local file name to upload.

    Raises:
        RuntimeError: If any error occurs during the upload process.
    """
    plog.log_debug(logger, f"Starting file upload process for file: {file_name}")
    try:
        api_key = authenticate()
        upload_task = create_upload_task(api_key)

        upload_url = upload_task["result"]["form"]["url"]
        parameters = upload_task["result"]["form"]["parameters"]
        upload_response = handle_file_upload(file_name, upload_url, parameters)

        result_message = (
            f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
        )
        plog.log_info(logger, result_message)
        print(result_message)  # For PowerShell capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        plog.log_error(logger, f"Error during file upload: {e}")
        raise RuntimeError(f"Error during file upload: {e}") from e


def create_conversion_task(api_key: str, output_format: str) -> Dict[str, Any]:
    """
    Create a conversion job on CloudConvert.

    Args:
        api_key (str): The CloudConvert API key.
        output_format (str): The desired output file format.

    Returns:
        Dict[str, Any]: The conversion job information.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
    url = f"{CLOUDCONVERT_API_BASE}/jobs"
    payload = {
        "tasks": {
            IMPORT_TASK: {"operation": "import/upload"},
            CONVERT_TASK: {
                "operation": "convert",
                "input": IMPORT_TASK,
                "output_format": output_format,
            },
            EXPORT_TASK: {"operation": "export/url", "input": CONVERT_TASK},
        }
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    plog.log_debug(logger, "Making API request to create a conversion task.")
    try:
        response = requests.post(
            url, json=payload, headers=headers, timeout=TIMEOUT_STANDARD
        )
    except Timeout as e:
        plog.log_error(
            logger, f"Request timed out after {TIMEOUT_STANDARD} seconds: {e}"
        )
        raise
    except RequestException as e:
        plog.log_error(logger, f"Request failed: {e}")
        raise

    if response.status_code != 201:
        plog.log_error(
            logger, f"Error creating conversion task: {response.status_code} - {response.text}"
        )
        response.raise_for_status()

    return response.json()["data"]


def check_task_status(api_key: str, task_id: str) -> Dict[str, Any]:
    """
    Check the status of a CloudConvert task.

    Args:
        api_key (str): The CloudConvert API key.
        task_id (str): The ID of the task to check.

    Returns:
        Dict[str, Any]: The task status information.

    Raises:
        requests.exceptions.RequestException: If the API request fails.
    """
    url = f"{CLOUDCONVERT_API_BASE}/tasks/{task_id}"
    headers = {"Authorization": f"Bearer {api_key}"}

    plog.log_debug(logger, f"Checking status of task: {task_id}")
    try:
        response = requests.get(url, headers=headers, timeout=TIMEOUT_QUICK)
    except Timeout as e:
        plog.log_error(
            logger, f"Request timed out after {TIMEOUT_QUICK} seconds: {e}"
        )
        raise
    except RequestException as e:
        plog.log_error(logger, f"Request failed: {e}")
        raise

    if response.status_code != 200:
        plog.log_error(
            logger, f"Error checking task status: {response.status_code} - {response.text}"
        )
        response.raise_for_status()

    return response.json()["data"]


def wait_for_task_completion(api_key: str, task_id: str, task_name: str) -> Dict[str, Any]:
    """
    Poll a CloudConvert task until it completes or fails.

    Args:
        api_key (str): The CloudConvert API key.
        task_id (str): The ID of the task to monitor.
        task_name (str): The name of the task (for logging).

    Returns:
        Dict[str, Any]: The final task status information.

    Raises:
        RuntimeError: If the task fails or times out.
    """
    for attempt in range(max_retries):
        status = check_task_status(api_key, task_id)
        plog.log_info(
            logger, f"{task_name} status: {status['status']} (attempt {attempt+1}/{max_retries})"
        )

        if status["status"] == "finished":
            return status

        if status["status"] == "error":
            error_msg = status.get("message", "No error message provided.")
            plog.log_error(logger, f"{task_name} failed: {error_msg}")
            raise RuntimeError(f"CloudConvert {task_name} failed: {error_msg}")

        time.sleep(retry_delay)

    raise RuntimeError(f"{task_name} timed out after {max_retries * retry_delay} seconds.")


def convert_file(file_name: str, output_format: str) -> None:
    """
    Convert a file to a specified format using CloudConvert.

    Args:
        file_name (str): The local file name to convert.
        output_format (str): The desired output file format.

    Raises:
        RuntimeError: If any error occurs during the conversion process.
    """
    plog.log_debug(
        logger, f"Starting conversion process for file: {file_name} to format: {output_format}"
    )
    try:
        api_key = authenticate()
        conversion_task = create_conversion_task(api_key, output_format)
        plog.log_debug(logger, f"Conversion task response: {conversion_task}")

        tasks = conversion_task["tasks"]
        if not isinstance(tasks, list):
            plog.log_error(logger, "Unexpected type for conversion_task['tasks']")
            raise ValueError("Expected list but found different type in conversion_task['tasks']")

        upload_task = next((task for task in tasks if task.get("name") == IMPORT_TASK), None)
        if not upload_task:
            raise ValueError(f"Task '{IMPORT_TASK}' not found in conversion_task['tasks']")
        handle_file_upload(
            file_name,
            upload_task["result"]["form"]["url"],
            upload_task["result"]["form"]["parameters"],
        )

        convert_task = next((task for task in tasks if task.get("name") == CONVERT_TASK), None)
        if not convert_task:
            raise ValueError(f"Task '{CONVERT_TASK}' not found in conversion_task['tasks']")
        wait_for_task_completion(api_key, convert_task["id"], "Conversion")

        export_task = next((task for task in tasks if task.get("name") == EXPORT_TASK), None)
        if not export_task:
            raise ValueError(f"Task '{EXPORT_TASK}' not found in conversion_task['tasks']")
        export_status = wait_for_task_completion(api_key, export_task["id"], "Export")

        files = export_status["result"].get("files", [])
        if not files:
            raise RuntimeError("No files found in export task result.")

        download_url = files[0]["url"]
        plog.log_info(logger, f"File converted successfully. Download URL: {download_url}")
        print(f"File converted successfully. Download URL: {download_url}")

    except RuntimeError as e:
        plog.log_error(logger, f"Error during file conversion: {e}")
        raise

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        plog.log_error(logger, f"Error during file conversion: {e}")
        raise RuntimeError(f"Error during file conversion: {e}") from e


def parse_arguments() -> Tuple[bool, str, str]:
    """
    Parse command-line arguments for the script.

    Returns:
        Tuple[bool, str, str]: A tuple containing the debug flag, file name, and output format.
    """
    plog.log_debug(logger, f"Raw sys.argv: {sys.argv}")
    parser = argparse.ArgumentParser(description="Upload and convert a file using CloudConvert.")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging.")
    parser.add_argument(
        "file_name", type=str, help="The name of the file to be uploaded and converted."
    )
    parser.add_argument(
        "output_format", type=str, help="The desired output format (e.g., jpg, pdf)."
    )
    args = parser.parse_args()

    print(
        f"Parsed Arguments -> Debug: {args.debug}, File: {args.file_name}, Format: {args.output_format}"
    )
    return args.debug, args.file_name, args.output_format


def main() -> None:
    """
    Main entry point for the script. Parses arguments, initializes logging, and starts the conversion process.

    Exits:
        0: On successful completion.
        1: On error.
    """
    debug, file_name, output_format = parse_arguments()
    # Logger already initialized at module level, just update level if needed
    if debug:
        logger.setLevel(logging.DEBUG)
    try:
        convert_file(file_name, output_format)
        sys.exit(0)
    except RuntimeError as e:
        plog.log_error(logger, f"Runtime error: {e}")
        sys.exit(1)
    except Exception as e:
        plog.log_error(logger, f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    """
    If this script is run as the main module, execute the main function.
    """
    main()
