import json
import re

def extract_lat_lon(point_str):
    """
    Extracts latitude and longitude as floats from a string formatted like:
    "12.9041725°, 77.6034251°"
    """
    match = re.match(r"(-?\d+(?:\.\d+)?)°,\s*(-?\d+(?:\.\d+)?)°", point_str)
    if match:
        return float(match.group(1)), float(match.group(2))
    return None, None

def parse_timeline_json(filepath):
    """
    Parses Google Timeline JSON, extracting timelinePath and rawSignals data.
    Returns a list of structured dictionaries.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    rows = []
    for segment in data.get("semanticSegments", []):
        # Try direct list of points
        timeline_path = segment.get("timelinePath")
        if isinstance(timeline_path, list):
            for entry in timeline_path:
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
        # Handle rawSignals (position and activity)
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
    Main function to extract and print Google Timeline location data.
    """
    input_file = "E:\My Drive\Google Maps Timeline\Timeline.json"  # Update if needed
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
