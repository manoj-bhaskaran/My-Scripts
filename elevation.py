"""
elevation.py

Provides a reusable function to retrieve elevation data for given latitude and longitude
coordinates using the SRTM dataset.

Functions:
    get_elevation(lat, lon): Returns the elevation in meters for the specified coordinates,
    or None if unavailable.
"""

import srtm

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
    return elevation if elevation is not None and elevation > -1000 else None