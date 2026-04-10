"""Media processing utilities.

This package contains Python scripts for image and media file processing:
- crop_colours: Crops colored borders from images
- _image_ops: Core image-processing functions for crop_colours (independently importable)
- _tracking: Processed-file tracking subsystem for crop_colours
- find_duplicate_images: Identifies duplicate images using perceptual hashing
- recover_extensions: Recovers or fixes file extensions based on content analysis
"""

__version__ = "4.2.0"
