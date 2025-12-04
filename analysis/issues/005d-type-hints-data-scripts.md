# Issue #005d: Add Type Hints to Data Processing Scripts

**Parent Issue**: [#005: Missing Python Type Hints](./005-missing-python-type-hints.md)
**Phase**: Phase 3 - Domain Scripts
**Effort**: 6-8 hours

## Description
Add type hints to data processing scripts that handle CSV, GPX, and location data. These handle critical user data and benefit from type safety.

## Scope
- `src/python/data/csv_to_gpx.py`
- `src/python/data/validators.py`
- `src/python/data/extract_timeline_locations.py`

## Implementation

### csv_to_gpx.py
```python
# csv_to_gpx.py
from pathlib import Path
from typing import Optional

def csv_to_gpx(
    input_csv: str | Path,
    output_gpx: str | Path
) -> None:
    """
    Convert CSV file to GPX format with elevation data.

    Args:
        input_csv: Path to input CSV file with lat, lng, time columns
        output_gpx: Path where GPX file will be written

    Raises:
        FileNotFoundError: If input CSV doesn't exist
        KeyError: If required columns missing from CSV
        ValueError: If coordinate values invalid
    """
    ...

def parse_csv_row(row: dict[str, str]) -> tuple[float, float, str]:
    """
    Parse a CSV row into lat, lon, timestamp.

    Args:
        row: Dictionary from csv.DictReader

    Returns:
        Tuple of (latitude, longitude, timestamp)

    Raises:
        KeyError: If required columns missing
        ValueError: If values cannot be parsed
    """
    lat = float(row["lat"])
    lon = float(row["lng"])
    time = row["time"]
    return (lat, lon, time)
```

### validators.py
```python
# validators.py
from typing import Union

def validate_latitude(lat: float) -> bool:
    """
    Validate latitude is within valid range.

    Args:
        lat: Latitude value

    Returns:
        True if valid, False otherwise
    """
    return -90.0 <= lat <= 90.0

def validate_longitude(lon: float) -> bool:
    """
    Validate longitude is within valid range.

    Args:
        lon: Longitude value

    Returns:
        True if valid, False otherwise
    """
    return -180.0 <= lon <= 180.0

def validate_coordinate(
    lat: float,
    lon: float,
    raise_on_invalid: bool = False
) -> bool:
    """
    Validate a coordinate pair.

    Args:
        lat: Latitude value
        lon: Longitude value
        raise_on_invalid: If True, raise ValueError on invalid coordinates

    Returns:
        True if valid coordinates

    Raises:
        ValueError: If coordinates invalid and raise_on_invalid is True
    """
    is_valid = validate_latitude(lat) and validate_longitude(lon)

    if not is_valid and raise_on_invalid:
        raise ValueError(f"Invalid coordinates: ({lat}, {lon})")

    return is_valid

def validate_timestamp(timestamp: str) -> bool:
    """
    Validate ISO 8601 timestamp format.

    Args:
        timestamp: Timestamp string to validate

    Returns:
        True if valid ISO 8601 format
    """
    from datetime import datetime
    try:
        datetime.fromisoformat(timestamp.replace("Z", ""))
        return True
    except ValueError:
        return False
```

### extract_timeline_locations.py
```python
# extract_timeline_locations.py
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime

LocationDict = Dict[str, Any]  # Type alias

def extract_locations(
    input_file: str | Path,
    output_file: Optional[str | Path] = None
) -> List[LocationDict]:
    """
    Extract location data from timeline JSON.

    Args:
        input_file: Path to timeline JSON file
        output_file: Optional path to write extracted locations

    Returns:
        List of location dictionaries with keys: lat, lon, timestamp, accuracy

    Raises:
        FileNotFoundError: If input file doesn't exist
        json.JSONDecodeError: If file is not valid JSON
    """
    ...

def parse_timeline_entry(
    entry: Dict[str, Any]
) -> Optional[LocationDict]:
    """
    Parse a single timeline entry into location data.

    Args:
        entry: Timeline entry dictionary

    Returns:
        Location dictionary if valid, None otherwise
    """
    try:
        return {
            "lat": float(entry["latitudeE7"]) / 1e7,
            "lon": float(entry["longitudeE7"]) / 1e7,
            "timestamp": parse_timestamp(entry["timestamp"]),
            "accuracy": int(entry.get("accuracy", 0))
        }
    except (KeyError, ValueError):
        return None

def parse_timestamp(timestamp_str: str) -> datetime:
    """
    Parse timeline timestamp string.

    Args:
        timestamp_str: Timestamp string from timeline

    Returns:
        Parsed datetime object

    Raises:
        ValueError: If timestamp format is invalid
    """
    ...
```

## Acceptance Criteria
- [ ] All functions in csv_to_gpx.py have type hints
- [ ] All functions in validators.py have type hints
- [ ] All functions in extract_timeline_locations.py have type hints
- [ ] Type aliases used for complex types (LocationDict)
- [ ] Union types (|) used for Path arguments
- [ ] mypy passes for all three files
- [ ] Docstrings updated to match types

## Benefits
- Catch coordinate validation errors at dev time
- Clear data structure documentation
- Better IDE support for data transformations
- Type-safe data pipelines

## Effort
6-8 hours

## Related
- Issue #003c (tests for these scripts)
- Issue #005e (cloud integration types)
