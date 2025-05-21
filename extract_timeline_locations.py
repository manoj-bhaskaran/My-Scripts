import json
import re

# 🔧 Output limits
LIMIT_OUTPUT = True
MAX_TIMELINE_PATH = 100
MAX_RAWSIGNALS = 100

def extract_lat_lon(point_str):
    """
    Extract latitude and longitude from strings like '12.9041725°, 77.6034251°'.
    Returns (lat, lon) as floats, or (None, None) if parsing fails.
    """
    if not isinstance(point_str, str):
        return None, None

    point_str = point_str.replace("\u00b0", "°").strip()

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

    timeline_path_count = 0
    rawsignals_count = 0

    for segment in data.get("semanticSegments", []):
        # --- timelinePath ---
        for entry in segment.get("timelinePath", []):
            if LIMIT_OUTPUT and timeline_path_count >= MAX_TIMELINE_PATH:
                break

            time = entry.get("time")
            point = entry.get("point")
            lat, lon = extract_lat_lon(point)

            if lat is not None and lon is not None:
                print(f"[timelinePath] time: {time}, lat: {lat}, lon: {lon}")
                timeline_path_count += 1

        # --- rawSignals ---
        for signal in segment.get("rawSignals", []):
            if LIMIT_OUTPUT and rawsignals_count >= MAX_RAWSIGNALS:
                break

            if "position" in signal:
                position = signal["position"]
                time = position.get("timestamp")
                lat, lon = extract_lat_lon(position.get("LatLng", ""))
                if lat is not None and lon is not None:
                    print(f"[rawSignals]  time: {time}, lat: {lat}, lon: {lon}")
                    rawsignals_count += 1

    # ✅ Optional: show limit notice
    if LIMIT_OUTPUT:
        print(f"\n✅ Printed {timeline_path_count} timelinePath entries and {rawsignals_count} rawSignals entries (LIMIT_OUTPUT = True)")

if __name__ == "__main__":
    main()
