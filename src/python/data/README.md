# Data Processing Scripts

Python scripts for data processing, transformation, and validation.

## Scripts

- **extract_timeline_locations.py** - Extracts location data from timeline databases
- **csv_to_gpx.py** - Converts CSV files to GPX (GPS Exchange Format)
- **validators.py** - Data validation utilities and functions
- **seat_assignment.py** - Seat assignment algorithm and utilities

## Dependencies

### Python Modules
- **python_logging_framework** (`src/python/modules/logging/`) - Standardized logging
- Standard Python libraries (csv, json, xml, etc.)

### External Packages
Check individual scripts for specific requirements. Common dependencies include:
- pandas (data manipulation)
- numpy (numerical operations)

## Use Cases

### Timeline Data Extraction
Extract and process location data from timeline tracking databases for analysis or export.

### GPS Data Conversion
Convert CSV-formatted GPS/location data to GPX format for use with GPS devices and mapping software.

### Data Validation
Utilities for validating and sanitizing data inputs across various scripts.

## Installation

```bash
# Install common dependencies
pip install pandas numpy

# Install from requirements file if available
pip install -r requirements.txt
```

## Logging

All scripts use the Python Logging Framework located in `src/python/modules/logging/`.
