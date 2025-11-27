"""
CSV to GPX Converter Script with Elevation (Windows + GPX Studio compatible)

- Uses `srtm.py` for elevation data (downloaded on demand)
- Pretty-prints the final GPX output for better compatibility with visual tools

Usage:
    python csv-to-gpx.py --input_file <input_csv> --output_file <output_gpx>
                         [--input_folder <input_folder>] [--output_folder <output_folder>]
"""

import csv
import argparse
import os
from xml.etree.ElementTree import Element, SubElement, tostring
from datetime import datetime
import xml.dom.minidom
from elevation import get_elevation
import python_logging_framework as plog

# Initialize logger for this module
logger = plog.initialise_logger(__name__)


def csv_to_gpx(input_csv, output_gpx):
    """Convert CSV to GPX file with elevation and pretty print."""
    gpx = Element(
        "gpx",
        version="1.1",
        creator="CSV to GPX converter with srtm.py",
        xmlns="http://www.topografix.com/GPX/1/1",
    )

    trk = SubElement(gpx, "trk")
    name = SubElement(trk, "name")
    name.text = "Route with Elevation"
    trkseg = SubElement(trk, "trkseg")

    with open(input_csv, newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            lat = float(row["lat"])
            lon = float(row["lng"])
            time = row["time"]

            trkpt = SubElement(trkseg, "trkpt", lat=str(lat), lon=str(lon))

            ele_val = get_elevation(lat, lon)
            if ele_val is not None:
                ele = SubElement(trkpt, "ele")
                ele.text = f"{ele_val:.2f}"

            dt = datetime.fromisoformat(time.replace("Z", "").split("+")[0])
            time_elem = SubElement(trkpt, "time")
            time_elem.text = dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    # Pretty-print XML
    rough_string = tostring(gpx, encoding="utf-8")
    reparsed = xml.dom.minidom.parseString(rough_string)
    pretty_xml = reparsed.toprettyxml(indent="  ")

    # Write to file
    with open(output_gpx, "w", encoding="utf-8") as f:
        f.write(pretty_xml)

    plog.log_info(
        logger,
        f"GPX file with elevation written: {output_gpx}",
        metadata={"output_file": output_gpx},
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert CSV to GPX with elevation (Windows-compatible)."
    )
    parser.add_argument("--input_file", required=True, help="Name of the input CSV file")
    parser.add_argument("--output_file", required=True, help="Name of the output GPX file")
    parser.add_argument("--input_folder", default=".", help="Input folder (default: current)")
    parser.add_argument("--output_folder", default=".", help="Output folder (default: current)")
    args = parser.parse_args()

    input_csv = os.path.join(args.input_folder, args.input_file)
    output_gpx = os.path.join(args.output_folder, args.output_file)

    # Logger already initialized at module level
    csv_to_gpx(input_csv, output_gpx)
    plog.log_info(logger, "CSV to GPX conversion completed successfully.")
