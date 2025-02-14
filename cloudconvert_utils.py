import os
import sys
import logging
import requests
import urllib.parse
import argparse

# Set up logging
def setup_logging(debug=False):
    level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(level=level, format='%(asctime)s - %(levelname)s - %(message)s')

# Function to retrieve and validate the API key
def authenticate():
    logging.debug("Attempting to retrieve CloudConvert API key from environment variables.")
    api_key = os.getenv("CLOUDCONVERT_PROD")
    if not api_key:
        logging.error("CloudConvert API key not found in environment variables.")
        raise ValueError("CloudConvert API key not found in environment variables.")
    logging.debug("API key successfully retrieved.")
    return api_key

# Function to create an upload task
def create_upload_task(api_key):
    url = "https://api.cloudconvert.com/v2/jobs"
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
def handle_file_upload(file_name, upload_url, parameters):
    encoded_file_name = urllib.parse.quote(file_name)
    parameters["key"] = parameters["key"].replace("${filename}", encoded_file_name)

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
def upload_file(file_name):
    logging.debug(f"Starting file upload process for file: {file_name}")
    
    try:
        api_key = authenticate()
        upload_task = create_upload_task(api_key)

        upload_url = upload_task["result"]["form"]["url"]
        parameters = upload_task["result"]["form"]["parameters"]
        upload_response = handle_file_upload(file_name, upload_url, parameters)

        result_message = f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
        result_message = f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
        logging.info(result_message)
        print(result_message)  # Print the result for PowerShell to capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        logging.error(f"Error during file upload: {e}")
        raise Exception(f"Error during file upload: {e}")

# Function to create a conversion task
def create_conversion_task(api_key, input_file, output_format):
    url = "https://api.cloudconvert.com/v2/jobs"
    payload = {
        "tasks": {
            "import-my-file": {
                "operation": "import/upload"
            },
            "convert-my-file": {
                "operation": "convert",
                "input": "import-my-file",
                "output_format": output_format
            },
            "export-my-file": {
                "operation": "export/url",
                "input": "convert-my-file"
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
def check_task_status(api_key, task_id):
    url = f"https://api.cloudconvert.com/v2/tasks/{task_id}"
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
def convert_file(file_name, output_format):
    logging.debug(f"Starting conversion process for file: {file_name} to format: {output_format}")
    
    try:
        api_key = authenticate()
        conversion_task = create_conversion_task(api_key, file_name, output_format)
        logging.debug(f"Conversion task response: {conversion_task}")

        tasks = conversion_task["tasks"]
        if not isinstance(tasks, list):
            logging.error("Unexpected type for conversion_task['tasks']")
            raise ValueError("Expected list but found different type in conversion_task['tasks']")

        # Find the required task in the list
        upload_task = next((task for task in tasks if task.get("name") == "import-my-file"), None)
        if not upload_task:
            raise ValueError("Task 'import-my-file' not found in conversion_task['tasks']")

        handle_file_upload(file_name, upload_task["result"]["form"]["url"], upload_task["result"]["form"]["parameters"])

        # Check conversion status
        convert_task = next((task for task in tasks if task.get("name") == "convert-my-file"), None)
        if not convert_task:
            raise ValueError("Task 'convert-my-file' not found in conversion_task['tasks']")
        convert_task_id = convert_task["id"]

        status = check_task_status(api_key, convert_task_id)
        logging.debug(f"Check task status response: {status}")
        if isinstance(status, list):
            logging.error("Unexpected list type found in status")
            raise ValueError("Expected dictionary but found list in status")
        logging.info(f"Conversion status: {status['status']}")

        if status["status"] == "finished":
            export_task = next((task for task in tasks if task.get("name") == "export-my-file"), None)
            if not export_task:
                raise ValueError("Task 'export-my-file' not found in conversion_task['tasks']")
            export_task_id = export_task["id"]

            export_status = check_task_status(api_key, export_task_id)
            logging.info(f"Export status: {export_status['status']}")
            if export_status["status"] == "finished":
                download_url = export_status["result"]["files"][0]["url"]
                logging.info(f"File converted successfully. Download URL: {download_url}")
                print(f"File converted successfully. Download URL: {download_url}")  # Print the result for PowerShell to capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        logging.error(f"Error during file conversion: {e}")
        raise Exception(f"Error during file conversion: {e}")

# Function to parse command-line arguments
def parse_arguments():

    print("Raw sys.argv:", sys.argv)  # Debug print

    parser = argparse.ArgumentParser(description='Upload and convert a file using CloudConvert.')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging.')
    parser.add_argument('file_name', type=str, help='The name of the file to be uploaded and converted.')
    parser.add_argument('output_format', type=str, help='The desired output format (e.g., jpg, pdf).')
    args = parser.parse_args()

    print(f"Parsed Arguments -> Debug: {args.debug}, File: {args.file_name}, Format: {args.output_format}")
    return args.debug, args.file_name, args.output_format

# Main function to be called
def main():
    debug, file_name, output_format = parse_arguments()
    setup_logging(debug)
    try:
        convert_file(file_name, output_format)
    except Exception as e:
        logging.error(f"Unhandled exception: {e}")

if __name__ == "__main__":
    main()
