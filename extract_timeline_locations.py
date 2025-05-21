import json
import re

# 🔧 Switch: Set to True to print only first 100 records
LIMIT_OUTPUT = True
MAX_RECORDS = 100

def extract_lat_lon(point_str):
    """
    Extract latitude and longitude from strings like '12.9041725°, 77.6034251°'.
    Returns (lat, lon) as floats, or (None, None) if parsing fails.
    """
    if not isinstance(point_str, str):
        return None, None

    # Replace encoded degree symbol if needed (extra safe)
    point_str = point_str.replace("\u00b0", "°").strip()

    # Match "lat°, lon°" using Unicode degree symbol
    match = re.match(r"(-?\d+(?:\.\d+)?)°,\s*(-?\d+(?:\.\d+)?)°", point_str)
    if not match:
        return None, None

    try:
        return float(match.group(1)), float(match.group(2))
    except ValueError:
        return None, None

def main():
    input_file = r"G:\My Drive\Google Maps Timeline\timeline.json"

    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for segment in data.get("semanticSegments", []):
        for point_entry in segment.get("timelinePath", []):
            time = point_entry.get("time")
            point = point_entry.get("point")
            lat, lon = extract_lat_lon(point)
            if lat is not None and lon is not None:
                print(f"time: {time}, lat: {lat}, lon: {lon}")
            else:
                print(f"⚠️  Failed to parse point: {point}")


            count += 1
            if LIMIT_OUTPUT and count >= MAX_RECORDS:
                print(f"\n🔔 Stopped after {MAX_RECORDS} records (LIMIT_OUTPUT = True)")
                return

if __name__ == "__main__":
    main()
