# Crops black and white blocks on the left and right from an image - image file name is provided as an argument

import sys
from PIL import Image
import os

# Get the folder path from the command line argument
folder_path = sys.argv[1]

BLACK_THRESHOLD = 50
WHITE_THRESHOLD = 205  # New threshold for white color

def is_black(pixel):
    return all(channel < BLACK_THRESHOLD for channel in pixel[:3])

def is_white(pixel):
    return all(channel > WHITE_THRESHOLD for channel in pixel[:3])  # New function to check for white pixels

def crop_black_and_white_sides(image):
    width, height = image.size
    left_crop = 0
    for x in range(width):
        if any(not is_black(image.getpixel((x, y))) and not is_white(image.getpixel((x, y))) for y in range(height)):
            left_crop = x
            break
    right_crop = width
    for x in range(width - 1, -1, -1):
        if any(not is_black(image.getpixel((x, y))) and not is_white(image.getpixel((x, y))) for y in range(height)):
            right_crop = x + 1
            break
    cropped_image = image.crop((left_crop, 0, right_crop, height))
    return cropped_image

for filename in os.listdir(folder_path):
    if filename.endswith('.png') or filename.endswith('.jpg'):  # Updated to include .jpg files
        image_path = os.path.join(folder_path, filename)
        image = Image.open(image_path)
        cropped_image = crop_black_and_white_sides(image)  # Updated function call
        cropped_image.save(os.path.join(folder_path, f"cropped_{filename}"))
        print(f"Cropped {filename}")

print("Cropping complete!")
