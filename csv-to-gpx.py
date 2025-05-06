"""
CSV to GPX Converter Script with Elevation (Windows-friendly using srtm.py)

This script converts a CSV file containing GPS coordinates into a GPX file with elevation.
The CSV file must have the following columns:
- lat: Latitude of the point
- lng: Longitude of the point
- time: Timestamp in ISO 8601 format (e.g., "2025-05-06T12:34:56Z")

This version uses `srtm.py` for elevation lookup and works natively on Windows.

Usage:
    python csv-to-gpx.py --input_file <input_csv> --output_file <output_gpx> [--input_folder <input_folder>] [--output_folder <output_folder>]

Arguments:
    --input_file      Name of the input CSV file (required)
    --output_file     Name of the output GPX file (required)
    --input_folder    Path to the input folder (default: current folder)
    --output_folder   Path to the output folder (default: current folder)
"""

import csv
import srtm
from xml.etree.ElementTree import Element, SubElement, ElementTree
from datetime import datetime
import argparse
import os

# Load SRTM elevation data
elevation_data = srtm.get_data()

def get_elevation(lat, lon):
    """Fetch elevation or fallback if unavailable."""
    elevation = elevation_data.get_elevation(lat, lon)
    return elevation if elevation is not None else -9999

def csv_to_gpx(input_csv, output_gpx):
    """Convert CSV to GPX file with elevation."""
    gpx = Element('gpx', version="1.1", creator="CSV to GPX converter with srtm.py", xmlns="http://www.topografix.com/GPX/1/1")

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

            ele_val = get_elevation(lat, lon)

            trkpt = SubElement(trkseg, 'trkpt', lat=str(lat), lon=str(lon))
            ele = SubElement(trkpt, 'ele')
            ele.text = f"{ele_val:.2f}"

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

    csv_to_gpx(input_csv, output_gpx)
    print(f"GPX file with elevation written: {output_gpx}")