"""
elevation.py

Provides a reusable function to retrieve elevation data for given latitude and longitude
coordinates using the SRTM dataset. Uses the standard cross-platform logging framework
to trace elevation fallback decisions.

Functions:
    get_elevation(lat, lon): Returns the elevation in meters for the specified coordinates,
    or None if unavailable.
"""

import srtm
import python_logging_framework as plog

# Initialise logger once (assumes caller sets log_file_path)
plog.initialise_logger(log_file_path="auto", level="INFO")

# Initialize elevation data provider once
_elevation_data = srtm.get_data()

def get_elevation(lat, lon):
    """
    Get elevation for the given latitude and longitude.

    Args:
        lat (float): Latitude in decimal degrees.
        lon (float): Longitude in decimal degrees.

    Returns:
        float or None: Elevation in meters, or None if unavailable.
    """
    elevation = _elevation_data.get_elevation(lat, lon)
    if elevation is None or elevation <= -1000:
        plog.log_debug(f"Elevation unavailable or invalid at lat={lat}, lon={lon}, value={elevation}")
        return None
    return elevation
