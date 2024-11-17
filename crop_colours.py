"""
This script processes images in a given folder by cropping black and white blocks 
from the left and right sides. It saves the cropped images in a subfolder 
named 'Cropped Images'. If an image has already been cropped and saved in the 
'Cropped Images' folder, it will be skipped.

The script now utilizes parallel processing to improve performance on multi-core systems, 
includes optimized thresholding to minimize unnecessary pixel checks, and implements 
improved memory management techniques.

Usage:
    python crop_colours.py --folder_path <folder_path> [--resume_file <resume_file>] [--cropping_progress <cropping_progress>]

Arguments:
    folder_path: The path to the folder containing the images to be processed.
    resume_file: Optional. Specifies the file name to resume cropping from. Default is None.
    cropping_progress: Optional. Specifies how often to print progress messages. Default is 10.

Functionality:
    - Skips images that have already been cropped and saved in the 'Cropped Images' folder.
    - Uses vectorized image processing and optimised column-level checks for better performance.
    - Processes images in parallel using ThreadPoolExecutor for faster execution.
    - Only cropped images are counted towards progress; skipped images (completely black or white) are ignored.
    - Implements explicit garbage collection to free memory, ensuring efficient memory usage.
    - Processes images within a context manager to enhance memory management and release resources promptly.
"""

import os
import builtins
import cv2
import argparse
import numpy as np
from concurrent.futures import ThreadPoolExecutor, as_completed
import gc

# Constants for thresholds
BLACK_THRESHOLD = 50
WHITE_THRESHOLD = 205  # New threshold for white color

# Override the default print function
original_print = builtins.print
def print(*args, **kwargs):
    kwargs.setdefault('flush', True)  # Set flush=True by default
    original_print(*args, **kwargs)

# Set up argument parser
parser = argparse.ArgumentParser(description='Process and crop images.')
parser.add_argument('--folder_path', type=str, required=True, help='Path to the folder containing the images to be processed.')
parser.add_argument('--resume_file', type=str, default=None, help='Optional. File name to resume cropping from. Default is None.')
parser.add_argument('--cropping_progress', type=int, default=10, help='Optional. Specifies how often to print progress messages. Default is 10.')

args = parser.parse_args()

# Get arguments
folder_path = args.folder_path
resume_file = args.resume_file
croppingProgressInterval = args.cropping_progress

# Define the cropped images folder
cropped_folder = os.path.join(folder_path, "Cropped Images")
os.makedirs(cropped_folder, exist_ok=True)

def load_image(image_path):
    """
    Load the image and convert it to grayscale.

    Args:
        image_path (str): Path to the image file.

    Returns:
        tuple: Grayscale image and the original image (both as NumPy arrays).
    """
    image = cv2.imread(image_path, cv2.IMREAD_COLOR)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return gray, image  # Return both grayscale and original

def get_cropping_bounds(gray_image):
    """
    Get the cropping bounds using optimised column-level reduction.

    Args:
        gray_image (np.ndarray): Grayscale image array.

    Returns:
        tuple: Left and right cropping bounds (left, right).
    """
    # Identify columns that contain pixels not within the black or white threshold
    valid_columns = np.any(
        (gray_image > BLACK_THRESHOLD) & (gray_image < WHITE_THRESHOLD),
        axis=0  # Reduce across rows for each column
    )

    # Find the first and last valid column
    if not np.any(valid_columns):  # Early exit if all columns are black/white
        return 0, gray_image.shape[1]  # No cropping needed
    left_bound = np.argmax(valid_columns)
    right_bound = gray_image.shape[1] - np.argmax(valid_columns[::-1])
    
    return left_bound, right_bound

def crop_and_save_image(image_path, cropped_file_path):
    """
    Crop the image based on bounds and save the result.

    Args:
        image_path (str): Path to the image file.
        cropped_file_path (str): Path to save the cropped image.
    """
    try:
        # Load and process the image in a context manager to ensure memory is freed
        with open(image_path, 'rb') as f:
            gray, original = load_image(f.name)

        # Get cropping bounds using the optimised method
        left, right = get_cropping_bounds(gray)
        
        # Check if the image is entirely black or white (no cropping needed)
        if left == 0 and right == gray.shape[1]:
            print(f"Skipped {os.path.basename(image_path)}: Entirely black or white")
            return  # Skip saving for this image
        
        cropped_image = original[:, left:right]  # Crop width-wise
        cv2.imwrite(cropped_file_path, cropped_image)
        
        return cropped_file_path
    finally:
        # Explicitly delete variables to free memory
        del gray, original, cropped_image
        gc.collect()

# List all images in the folder
image_files = [f for f in os.listdir(folder_path) if f.endswith('.png') or f.endswith('.jpg')]

# Initialize flag to skip files until resume_file is found
resume = True if resume_file else False

# Track progress
total_files = len(image_files)
cropped_count = 0

# Process images in parallel using ThreadPoolExecutor
with ThreadPoolExecutor() as executor:
    future_to_image = {
        executor.submit(crop_and_save_image, os.path.join(folder_path, filename), os.path.join(cropped_folder, filename)): filename 
        for filename in image_files 
        if not os.path.exists(os.path.join(cropped_folder, filename))
    }

    for future in as_completed(future_to_image):
        filename = future_to_image[future]

        # Skip files until resume_file is found
        if resume:
            if filename == resume_file:
                resume = False  # Resume processing after this file
            else:
                continue  # Skip this file

        try:
            cropped_file_path = future.result()
            cropped_count += 1
            print(f"Cropped and saved {filename} in 'Cropped Images' folder")
            
            # Print progress message after every `croppingProgressInterval` images
            if cropped_count % croppingProgressInterval == 0:
                print(f"Cropped {cropped_count} images so far")
        except Exception as exc:
            print(f"{filename} generated an exception: {exc}")

# Final completion message
print(f"Cropping complete! Processed {cropped_count} images in total.")
