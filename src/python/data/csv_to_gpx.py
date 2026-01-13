"""
CSV to GPX Converter Script with Elevation (Windows + GPX Studio compatible)

- Uses `srtm.py` for elevation data (downloaded on demand)
- Pretty-prints the final GPX output for better compatibility with visual tools

Usage:
    python csv-to-gpx.py --input_file <input_csv> --output_file <output_gpx>
                         [--input_folder <input_folder>] [--output_folder <output_folder>]
"""

import argparse
import csv
import os
import sys
import xml.dom.minidom
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple
from xml.etree.ElementTree import Element, SubElement, tostring

# Add module paths to sys.path for imports
script_dir = Path(__file__).resolve().parent
repo_root = script_dir.parent.parent.parent
modules_logging = repo_root / "src" / "python" / "modules" / "logging"
modules_auth = repo_root / "src" / "python" / "modules" / "auth"

sys.path.insert(0, str(modules_logging))
sys.path.insert(0, str(modules_auth))

from elevation import get_elevation
import python_logging_framework as plog

# Initialize logger for this module
# Use __file__ instead of __name__ to ensure correct log file naming and path resolution
logger = plog.initialise_logger(__file__, log_dir=repo_root / "logs")


def csv_to_gpx(input_csv: str | Path, output_gpx: str | Path) -> None:
    """Convert CSV to GPX file with elevation and pretty print.

    Args:
        input_csv: Path to the input CSV file containing ``lat``, ``lng``, and ``time`` columns.
        output_gpx: Path to the GPX file that will be created.
    """
    input_path = Path(input_csv)
    output_path = Path(output_gpx)
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

    with open(input_path, newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            lat, lon, time = parse_csv_row(row)

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
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(pretty_xml)

    plog.log_info(
        logger,
        f"GPX file with elevation written: {output_path}",
        metadata={"output_file": str(output_path)},
    )


def parse_csv_row(row: Dict[str, str]) -> Tuple[float, float, str]:
    """Parse a CSV row into latitude, longitude, and timestamp values.

    Args:
        row: A mapping produced by :class:`csv.DictReader` with ``lat``, ``lng``, and ``time`` keys.

    Returns:
        A tuple ``(lat, lon, time)`` where ``lat`` and ``lon`` are floats and ``time`` is the raw timestamp string.

    Raises:
        KeyError: If any of the expected keys are missing from ``row``.
        ValueError: If the latitude or longitude values cannot be converted to ``float``.
    """
    lat = float(row["lat"])
    lon = float(row["lng"])
    time = row["time"]
    return lat, lon, time


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
