# Media Processing Scripts

Python scripts for image and media file processing.

## Scripts

- **find_duplicate_images.py** - Identifies duplicate images using perceptual hashing
- **crop_colours.py** - Crops colored borders from images (removes black bars, etc.)
- **recover_extensions.py** - Recovers or fixes file extensions based on content analysis

## Dependencies

### Python Modules
- **python_logging_framework** (`src/python/modules/logging/`) - Standardized logging

### External Packages
```bash
# Image processing
pip install Pillow opencv-python

# Perceptual hashing for duplicate detection
pip install imagehash

# File type detection
pip install python-magic
```

## Use Cases

### Duplicate Detection
Find and remove duplicate images across large photo collections using perceptual hashing algorithms that can detect:
- Exact duplicates
- Resized versions
- Slightly modified copies

### Image Cropping
Automatically remove unwanted borders from images:
- Black bars from screenshots
- Colored borders from scanned documents
- Letterboxing from videos

### File Extension Recovery
Analyze file content to determine the correct file type and restore proper extensions for files with missing or incorrect extensions.

## Usage Examples

```bash
# Find duplicate images
python find_duplicate_images.py --path /path/to/images --threshold 5

# Crop colored borders
python crop_colours.py --input image.jpg --output cropped.jpg

# Recover file extensions
python recover_extensions.py --directory /path/to/files
```

## Performance Considerations

- Duplicate image detection can be CPU and memory intensive for large collections
- Processing high-resolution images may require significant memory
- Consider batch processing for large datasets

## Logging

All scripts use the Python Logging Framework located in `src/python/modules/logging/`.
