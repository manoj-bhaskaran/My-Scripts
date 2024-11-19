import os
import sys
import logging
import requests
import urllib.parse 

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

def upload_file(file_name):
    logging.debug(f"Starting file upload process for file: {file_name}")
    
    try:
        api_key = authenticate()

        encoded_file_name = urllib.parse.quote(file_name)

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
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

        logging.debug("Making API request to create an upload task.")
        response = requests.post(url, json=payload, headers=headers)

        if response.status_code != 201:
            logging.error(f"Error creating upload task: {response.status_code} - {response.text}")
            response.raise_for_status()

        logging.debug(f"API response: {response.status_code} - {response.text}")

        # Extract the upload URL and parameters
        try:
            upload_task = response.json()["data"]["tasks"][0]  # Access the first task in the list
            upload_url = upload_task["result"]["form"]["url"]
            parameters = upload_task["result"]["form"]["parameters"]

            # Replace the ${filename} placeholder in the URL with the actual file name
            parameters["key"] = parameters["key"].replace("${filename}", encoded_file_name)

            logging.debug(f"Upload URL: {upload_url}")
            logging.debug(f"Upload parameters: {parameters}")

        except KeyError as e:
            logging.error(f"KeyError: Unable to find expected keys in the API response. Missing key: {e}")
            logging.error(f"Full response: {response.json()}")
            raise
        except IndexError as e:
            logging.error(f"IndexError: Unable to access the first task in the tasks list. Response: {response.json()}")
            raise

        # Step 2: Upload the file
        logging.debug(f"Attempting to upload file: {file_name}")
        with open(file_name, "rb") as file:
            files = {"file": file}
            # Modify the URL and pass parameters as a POST form
            upload_response = requests.post(upload_url, data=parameters, files=files)

            upload_response.raise_for_status()  # Will raise an error for HTTP error responses

        logging.info(f"File '{encoded_file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}")
        return f"File '{encoded_file_name}' uploaded successfully. HTTP Status: {upload_response.status_code}"

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
