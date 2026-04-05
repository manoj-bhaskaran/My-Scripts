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

## Troubleshooting crop_colours.py

- **"No valid images found"**:
  Ensure `--input` has `.png`/`.jpg`/`.jpeg` files. Use `--recurse` to include subfolders.
  Use `--allow-empty` to treat empty input as success.

- **"Already processed / already cropped"**:
  By default, images that were successfully processed before are skipped on rerun.
  Use `--reprocess-cropped` to force reprocessing; by default, this deletes any existing
  crops before regenerating them. To keep existing crops and add new de-duplicated outputs
  alongside, add `--keep-existing-crops`.

- **"Failed to load image"**:
  The file may be corrupt/unsupported. Use `--skip-bad-images` to continue.

- **"Transparent images not cropping properly"**:
  Use `--preserve-alpha` to detect transparent borders instead of treating them as solid
  colors. Requires images with alpha channels. For anti-aliased transparent edges, tune
  `--alpha-threshold` to ignore semi-transparent pixels (e.g. `--alpha-threshold 10` to
  ignore alpha values ≤ 10).

- **"Saves failing on network drive"**:
  Increase `--retry-writes`, reduce `--max-workers`, and check disk permissions/space.

- **"Too slow or too CPU-heavy"**:
  Tune `--max-workers` (I/O-bound default is 2×CPU, capped at 64). Try smaller values.

## FAQs for crop_colours.py

**Q: Where are outputs written?**
By default, images are written to `<input>/Cropped/`, preserving subfolders when `--recurse`
is used, with a filename suffix (e.g., `_cropped`).

**Q: What if the crop finds nothing to trim?**
The original image is written as-is (no-op crop).

**Q: How does reprocessing protection work?**
Successfully processed files are recorded in `<input>/.processed_images` (absolute paths).
Existing crops are also detected when determining whether work is needed.
Delete `.processed_images` to reset tracking or pass `--reprocess-cropped` to redo work.

**Q: How do I handle images with transparent backgrounds?**
Use `--preserve-alpha` to detect borders based on alpha transparency.

**Q: Can I resume after a partial run?**
Yes. Pass `--resume-file <an existing image filename>`. Processing starts after that file.
