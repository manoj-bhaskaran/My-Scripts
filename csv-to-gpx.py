"""
CSV to GPX Converter Script

This script converts a CSV file containing GPS coordinates into a GPX file.
The CSV file must have the following columns:
- lat: Latitude of the point
- lng: Longitude of the point
- time: Timestamp in ISO 8601 format (e.g., "2025-05-06T12:34:56Z")

The script supports parameterized input and output file paths, as well as input and output folders.
If no folder is specified, the current folder is used by default.

Usage:
    python csv-to-gpx.py --input_file <input_csv> --output_file <output_gpx> [--input_folder <input_folder>] [--output_folder <output_folder>]

Arguments:
    --input_file      Name of the input CSV file (required)
    --output_file     Name of the output GPX file (required)
    --input_folder    Path to the input folder (default: current folder)
    --output_folder   Path to the output folder (default: current folder)
"""

import csv
from xml.etree.ElementTree import Element, SubElement, ElementTree
from datetime import datetime
import argparse
import os

def csv_to_gpx(input_csv, output_gpx):
    """
    Converts a CSV file to a GPX file.

    Args:
        input_csv (str): Path to the input CSV file.
        output_gpx (str): Path to the output GPX file.

    The CSV file must contain the following columns:
    - lat: Latitude of the point
    - lng: Longitude of the point
    - time: Timestamp in ISO 8601 format
    """
    gpx = Element('gpx', version="1.1", creator="CSV to GPX converter", xmlns="http://www.topografix.com/GPX/1/1")

    with open(input_csv, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        trk = SubElement(gpx, 'trk')
        name = SubElement(trk, 'name')
        name.text = 'Route from CSV'
        trkseg = SubElement(trk, 'trkseg')

        for row in reader:
            lat = row['lat']
            lon = row['lng']
            time = row['time']

            trkpt = SubElement(trkseg, 'trkpt', lat=lat, lon=lon)
            time_elem = SubElement(trkpt, 'time')

            # Ensure correct ISO format without timezone offset
            dt = datetime.fromisoformat(time.replace("Z", "").split("+")[0])
            time_elem.text = dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    tree = ElementTree(gpx)
    tree.write(output_gpx, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a CSV file to a GPX file.")
    parser.add_argument("--input_file", help="Name of the input CSV file", required=True)
    parser.add_argument("--output_file", help="Name of the output GPX file", required=True)
    parser.add_argument("--input_folder", default=".", help="Path to the input folder (default: current folder)")
    parser.add_argument("--output_folder", default=".", help="Path to the output folder (default: current folder)")
    args = parser.parse_args()

    # Resolve full paths for input and output files
    input_csv = os.path.join(args.input_folder, args.input_file)
    output_gpx = os.path.join(args.output_folder, args.output_file)

    csv_to_gpx(input_csv, output_gpx)
