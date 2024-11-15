"""
This script processes images in a given folder by cropping black and white blocks 
from the left and right sides. It saves the cropped images in a subfolder 
named 'Cropped Images'.

Usage:
    python crop_colours.py <folder_path>

Arguments:
    folder_path: The path to the folder containing the images to be processed.
"""

import sys
import os
from PIL import Image

# Get the folder path from the command line argument
folder_path = sys.argv[1]

BLACK_THRESHOLD = 50
WHITE_THRESHOLD = 205  # New threshold for white color

def is_black(pixel):
    """
    Checks if a given pixel is considered black based on the defined threshold.

    Args:
        pixel (tuple): A tuple containing RGB values of the pixel.

    Returns:
        bool: True if the pixel is black, False otherwise.
    """
    return all(channel < BLACK_THRESHOLD for channel in pixel[:3])

def is_white(pixel):
    """
    Checks if a given pixel is considered white based on the defined threshold.

    Args:
        pixel (tuple): A tuple containing RGB values of the pixel.

    Returns:
        bool: True if the pixel is white, False otherwise.
    """
    return all(channel > WHITE_THRESHOLD for channel in pixel[:3])

def crop_black_and_white_sides(image):
    """
    Crops black and white blocks from the left and right sides of an image.

    Args:
        image (PIL.Image.Image): The image to be processed.

    Returns:
        PIL.Image.Image: The cropped image.
    """
    width, height = image.size
    left_crop = 0
    for x in range(width):
        if any(
            not is_black(image.getpixel((x, y))) and not is_white(image.getpixel((x, y)))
            for y in range(height)
       ):
            left_crop = x
            break
    right_crop = width
    for x in range(width - 1, -1, -1):
        if any(
            not is_black(image.getpixel((x, y))) and not is_white(image.getpixel((x, y)))
            for y in range(height)):
            right_crop = x + 1
            break
    cropped_image = image.crop((left_crop, 0, right_crop, height))
    return cropped_image

# Define the cropped images folder
cropped_folder = os.path.join(folder_path, "Cropped Images")
os.makedirs(cropped_folder, exist_ok=True)

for filename in os.listdir(folder_path):
    if filename.endswith('.png') or filename.endswith('.jpg'):  # Updated to include .jpg files
        image_path = os.path.join(folder_path, filename)
        input_image = Image.open(image_path)
        cropped = crop_black_and_white_sides(input_image)
        cropped.save(os.path.join(cropped_folder, f"{filename}"))
        print(f"Cropped and saved {filename} in 'Cropped Images' folder")

print("Cropping complete!")
