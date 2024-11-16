"""
This script processes images in a given folder by cropping black and white blocks 
from the left and right sides. It saves the cropped images in a subfolder 
named 'Cropped Images'. If an image has already been cropped and saved in the 
'Cropped Images' folder, it will be skipped. 

The script now utilizes parallel processing to improve performance on multi-core systems.

Usage:
    python crop_colours.py <folder_path> [croppingProgressInterval]

Arguments:
    folder_path: The path to the folder containing the images to be processed.
    croppingProgressInterval: Optional. Specifies how often to print progress messages. Default is 10.

Functionality:
    - Skips images that have already been cropped and saved in the 'Cropped Images' folder.
    - Uses vectorized image processing for better performance.
    - Processes images in parallel using ThreadPoolExecutor for faster execution.
"""

import os
import sys
import cv2
import numpy as np
from concurrent.futures import ThreadPoolExecutor, as_completed

# Constants for thresholds
BLACK_THRESHOLD = 50
WHITE_THRESHOLD = 205  # New threshold for white color

# Get the folder path from the command line argument
folder_path = sys.argv[1]
croppingProgressInterval = int(sys.argv[2]) if len(sys.argv) > 2 else 10  # Default interval: 10

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

def get_non_black_white_mask(gray_image):
    """
    Get a binary mask for pixels that are neither black nor white.

    Args:
        gray_image (np.ndarray): Grayscale image array.

    Returns:
        np.ndarray: Binary mask where 1 indicates non-black-and-white pixels.
    """
    _, black_mask = cv2.threshold(gray_image, BLACK_THRESHOLD, 255, cv2.THRESH_BINARY_INV)
    _, white_mask = cv2.threshold(gray_image, WHITE_THRESHOLD, 255, cv2.THRESH_BINARY)
    non_black_white_mask = cv2.bitwise_or(black_mask, white_mask)  # Combine black and white masks
    return non_black_white_mask

def get_cropping_bounds(mask):
    """
    Get the cropping bounds from the binary mask.

    Args:
        mask (np.ndarray): Binary mask where 1 indicates non-black-and-white pixels.

    Returns:
        tuple: Left and right cropping bounds (left, right).
    """
    column_sums = np.any(mask == 0, axis=0)  # Check if any row in a column contains 0
    left_bound = np.argmax(column_sums)  # First non-zero column
    right_bound = mask.shape[1] - np.argmax(column_sums[::-1])  # Last non-zero column
    return left_bound, right_bound

def crop_and_save_image(image_path, cropped_file_path):
    """
    Crop the image based on bounds and save the result.

    Args:
        image_path (str): Path to the image file.
        cropped_file_path (str): Path to save the cropped image.
    """
    # Load and process the image
    gray, original = load_image(image_path)
    non_black_white_mask = get_non_black_white_mask(gray)
    bounds = get_cropping_bounds(non_black_white_mask)
    
    left, right = bounds
    cropped_image = original[:, left:right]  # Crop width-wise
    cv2.imwrite(cropped_file_path, cropped_image)
    
    return cropped_file_path

# List all images in the folder
image_files = [f for f in os.listdir(folder_path) if f.endswith('.png') or f.endswith('.jpg')]

# Track progress
total_files = len(image_files)
cropped_count = 0
considered_count = 0

# Process images in parallel using ThreadPoolExecutor
with ThreadPoolExecutor() as executor:
    future_to_image = {
        executor.submit(crop_and_save_image, os.path.join(folder_path, filename), os.path.join(cropped_folder, filename)): filename 
        for filename in image_files 
        if not os.path.exists(os.path.join(cropped_folder, filename))
    }

    for future in as_completed(future_to_image):
        filename = future_to_image[future]
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