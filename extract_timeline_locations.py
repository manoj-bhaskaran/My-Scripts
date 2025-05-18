"""
extract_timeline_locations.py

This script parses a Google Timeline JSON file containing semanticSegments
with timelinePath and rawSignals data. It extracts timestamp, latitude, 
longitude, and additional metadata like elevation, accuracy, activity type, 
and confidence (if available), and prints the extracted values in a readable format.

Intended for further use such as insertion into a PostgreSQL table or export.
"""

import json
import re

def extract_lat_lon(point_str):
    """
    Extracts latitude and longitude as floats from a string formatted like:
    "12.9041725°, 77.6034251°"

    Args:
        point_str (str): The coordinate string from JSON.

    Returns:
        tuple: (latitude, longitude) as floats if parsing is successful, otherwise (None, None).
    """
    match = re.match(r"(-?\d+(?:\.\d+)?)°,\s*(-?\d+(?:\.\d+)?)°", point_str)
    if match:
        return float(match.group(1)), float(match.group(2))
    return None, None

def parse_timeline_json(filepath):
    """
    Parses the Google Timeline JSON file and extracts structured location data
    from both timelinePath and rawSignals entries within each semanticSegment.

    Args:
        filepath (str): Path to the input JSON file.

    Returns:
        list[dict]: A list of dictionaries, each representing one location record with keys:
                    timestamp, latitude, longitude, elevation, accuracy, activity_type, confidence, source
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    rows = []
    for segment in data.get("semanticSegments", []):
        # Extract from timelinePath
        for entry in segment.get("timelinePath", []):
            time = entry.get("time")
            point = entry.get("point")
            lat, lon = extract_lat_lon(point) if point else (None, None)
            if time and lat is not None and lon is not None:
                rows.append({
                    "timestamp": time,
                    "latitude": lat,
                    "longitude": lon,
                    "elevation": None,
                    "accuracy": None,
                    "activity_type": None,
                    "confidence": None,
                    "source": "timelinePath"
                })

        # Extract from rawSignals
        for signal in segment.get("rawSignals", []):
            row = {
                "timestamp": None,
                "latitude": None,
                "longitude": None,
                "elevation": None,
                "accuracy": None,
                "activity_type": None,
                "confidence": None,
                "source": "rawSignals"
            }

            pos = signal.get("position")
            if pos:
                row["timestamp"] = pos.get("timestamp")
                lat, lon = extract_lat_lon(pos.get("LatLng", ""))
                row["latitude"] = lat
                row["longitude"] = lon
                row["elevation"] = pos.get("altitudeMeters")
                row["accuracy"] = pos.get("accuracyMeters")

            activity = signal.get("activityRecord", {}).get("probableActivities", [])
            if activity:
                row["activity_type"] = activity[0].get("type")
                conf = activity[0].get("confidence")
                if conf is not None:
                    row["confidence"] = int(conf * 100)

            if row["timestamp"] and row["latitude"] is not None and row["longitude"] is not None:
                rows.append(row)

    return rows

def main():
    """
    Main entry point of the script.
    Loads and parses the JSON file, and prints out available location records
    in a human-readable format.
    """
    input_file = "E:\My Drive\Google Maps Timeline\Timeline.json"  # Replace with your actual file path
    records = parse_timeline_json(input_file)

    for r in records:
        print(f"[{r['source']}] {r['timestamp']}")
        print(f"  Latitude:     {r['latitude']}")
        print(f"  Longitude:    {r['longitude']}")
        if r['elevation'] is not None:
            print(f"  Elevation:    {r['elevation']} meters")
        if r['accuracy'] is not None:
            print(f"  Accuracy:     {r['accuracy']} meters")
        if r['activity_type'] is not None:
            print(f"  Activity:     {r['activity_type']}")
        if r['confidence'] is not None:
            print(f"  Confidence:   {r['confidence']}%")
        print()

if __name__ == "__main__":
    main()
