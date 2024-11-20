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

# Function to upload a file
def upload_file(file_name):
    logging.debug(f"Starting file upload process for file: {file_name}")
    
    try:
        api_key = authenticate()
        upload_task = create_upload_task(api_key)

        upload_url = upload_task["result"]["form"]["url"]
        parameters = upload_task["result"]["form"]["parameters"]
        encoded_file_name = urllib.parse.quote(file_name)
        parameters["key"] = parameters["key"].replace("${filename}", encoded_file_name)

        logging.debug(f"Upload URL: {upload_url}")
        logging.debug(f"Upload parameters: {parameters}")

        logging.debug(f"Attempting to upload file: {file_name}")
        with open(file_name, "rb") as file:
            files = {"file": file}
            upload_response = requests.post(upload_url, data=parameters, files=files)

            upload_response.raise_for_status()

        result_message = f"File '{file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"
        logging.info(result_message)
        print(result_message)  # Print the result for PowerShell to capture

    except (requests.exceptions.RequestException, KeyError, IndexError, ValueError) as e:
        logging.error(f"Error during file upload: {e}")
        raise Exception(f"Error during file upload: {e}")

# Function to parse command-line arguments
def parse_arguments():
    parser = argparse.ArgumentParser(description='Upload a file to CloudConvert.')
    parser.add_argument('file_name', type=str, help='The name of the file to be uploaded.')
    args = parser.parse_args()
    return args.file_name

# Main function to be called
def main():
    setup_logging(debug=True)
    try:
        file_name = parse_arguments()
        upload_file(file_name)
    except Exception as e:
        logging.error(f"Unhandled exception: {e}")

if __name__ == "__main__":
    main()
