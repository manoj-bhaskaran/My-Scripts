"""
CSV to GPX Converter Script with Elevation

This script converts a CSV file containing GPS coordinates into a GPX file with elevation.
The CSV file must have the following columns:
- lat: Latitude of the point
- lng: Longitude of the point
- time: Timestamp in ISO 8601 format (e.g., "2025-05-06T12:34:56Z")

Elevation data is retrieved from locally clipped SRTM tiles using the `elevation` and `rasterio` packages.

Usage:
    python csv-to-gpx.py --input_file <input_csv> --output_file <output_gpx> [--input_folder <input_folder>] [--output_folder <output_folder>]

Arguments:
    --input_file      Name of the input CSV file (required)
    --output_file     Name of the output GPX file (required)
    --input_folder    Path to the input folder (default: current folder)
    --output_folder   Path to the output folder (default: current folder)
"""

import csv
import elevation
import rasterio
from rasterio.warp import transform
from xml.etree.ElementTree import Element, SubElement, ElementTree
from datetime import datetime
import argparse
import os

def is_coverage_sufficient(tif_path, bounds_needed):
    """Check if the existing SRTM TIFF covers the bounding box."""
    from rasterio.coords import BoundingBox

    with rasterio.open(tif_path) as dataset:
        bbox = dataset.bounds  # BoundingBox(left, bottom, right, top)
        return (
            bbox.left <= bounds_needed[0] and
            bbox.bottom <= bounds_needed[1] and
            bbox.right >= bounds_needed[2] and
            bbox.top >= bounds_needed[3]
        )

def calculate_bounding_box(csv_path):
    """Compute the bounding box from CSV."""
    min_lat, max_lat = float('inf'), float('-inf')
    min_lng, max_lng = float('inf'), float('-inf')

    with open(csv_path, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            lat = float(row['lat'])
            lng = float(row['lng'])
            min_lat = min(min_lat, lat)
            max_lat = max(max_lat, lat)
            min_lng = min(min_lng, lng)
            max_lng = max(max_lng, lng)

    return (min_lng, min_lat, max_lng, max_lat)

def get_elevation(lat, lon, tif_path='srtm.tif'):
    """Get elevation from clipped raster file."""
    with rasterio.open(tif_path) as dataset:
        lon_t, lat_t = transform('EPSG:4326', dataset.crs, [lon], [lat])
        row, col = dataset.index(lon_t[0], lat_t[0])
        return float(dataset.read(1)[row, col])

def csv_to_gpx(input_csv, output_gpx, tif_path):
    """Convert CSV to GPX using local SRTM data for elevation."""
    gpx = Element('gpx', version="1.1", creator="CSV to GPX converter with elevation", xmlns="http://www.topografix.com/GPX/1/1")

    with open(input_csv, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        trk = SubElement(gpx, 'trk')
        name = SubElement(trk, 'name')
        name.text = 'Route with Elevation'
        trkseg = SubElement(trk, 'trkseg')

        for row in reader:
            lat = float(row['lat'])
            lon = float(row['lng'])
            time = row['time']
            elevation = get_elevation(lat, lon, tif_path)

            trkpt = SubElement(trkseg, 'trkpt', lat=str(lat), lon=str(lon))
            ele = SubElement(trkpt, 'ele')
            ele.text = f"{elevation:.2f}"

            dt = datetime.fromisoformat(time.replace("Z", "").split("+")[0])
            time_elem = SubElement(trkpt, 'time')
            time_elem.text = dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    tree = ElementTree(gpx)
    tree.write(output_gpx, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a CSV file to a GPX file with elevation.")
    parser.add_argument("--input_file", help="Name of the input CSV file", required=True)
    parser.add_argument("--output_file", help="Name of the output GPX file", required=True)
    parser.add_argument("--input_folder", default=".", help="Path to the input folder (default: current folder)")
    parser.add_argument("--output_folder", default=".", help="Path to the output folder (default: current folder)")
    args = parser.parse_args()

    input_csv = os.path.join(args.input_folder, args.input_file)
    output_gpx = os.path.join(args.output_folder, args.output_file)
    srtm_tif = os.path.join(args.output_folder, "srtm.tif")

    # Compute bounding box and clip only required area
    bounds = calculate_bounding_box(input_csv)
    if not os.path.exists(srtm_tif) or not is_coverage_sufficient(srtm_tif, bounds):
        print(f"Clipping fresh SRTM data for bounds: {bounds}")
        elevation.use('eio')
        elevation.clip(bounds=bounds, output=srtm_tif)
    else:
        print(f"Existing SRTM file covers the bounding box: {srtm_tif}")

    csv_to_gpx(input_csv, output_gpx, tif_path=srtm_tif)
    print(f"GPX file written: {output_gpx}")
