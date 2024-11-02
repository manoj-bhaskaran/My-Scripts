import sys
from PIL import Image
import os

# Get the folder path from the command line argument
folder_path = sys.argv[1]

BLACK_THRESHOLD = 50

def is_black(pixel):
    return all(channel < BLACK_THRESHOLD for channel in pixel[:3])

def crop_black_sides(image):
    width, height = image.size
    left_crop = 0
    for x in range(width):
        if any(not is_black(image.getpixel((x, y))) for y in range(height)):
            left_crop = x
            break
    right_crop = width
    for x in range(width - 1, -1, -1):
        if any(not is_black(image.getpixel((x, y))) for y in range(height)):
            right_crop = x + 1
            break
    cropped_image = image.crop((left_crop, 0, right_crop, height))
    return cropped_image

for filename in os.listdir(folder_path):
    if filename.endswith('.png'):
        image_path = os.path.join(folder_path, filename)
        image = Image.open(image_path)
        cropped_image = crop_black_sides(image)
        cropped_image.save(os.path.join(folder_path, f"cropped_{filename}"))
        print(f"Cropped {filename}")

print("Cropping complete!")