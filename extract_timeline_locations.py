import json
import re
from datetime import datetime

# Configuration
LIMIT_OUTPUT = True
MAX_OUTPUT_RECORDS = 200
input_file = r"G:\My Drive\Google Maps Timeline\timeline.json"

def datetime_from_iso(ts):
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def extract_lat_lon(point_str):
    if not isinstance(point_str, str):
        return None, None
    point_str = point_str.replace("\u00b0", "°").strip()
    match = re.match(r"(-?\d+(?:\.\d+)?)°,\s*(-?\d+(?:\.\d+)?)°", point_str)
    if match:
        try:
            return float(match.group(1)), float(match.group(2))
        except ValueError:
            return None, None
    return None, None

# Load JSON data
with open(input_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

records = []
activity_ranges = []

# Step 1: Extract movement-based activity time ranges
for segment in data.get("semanticSegments", []):
    activity = segment.get("activity")
    if activity:
        start_time = datetime_from_iso(segment.get("startTime"))
        end_time = datetime_from_iso(segment.get("endTime"))
        top = activity.get("topCandidate", {})
        act_type = top.get("type")
        confidence = top.get("probability")
        if start_time and end_time and act_type and confidence is not None:
            activity_ranges.append({
                "start_time": start_time,
                "end_time": end_time,
                "activity_type": act_type,
                "confidence": int(confidence * 100)
            })

# Step 2: Extract points from timelinePath
for segment in data.get("semanticSegments", []):
    for entry in segment.get("timelinePath", []):
        time_str = entry.get("time")
        dt = datetime_from_iso(time_str)
        lat, lon = extract_lat_lon(entry.get("point", ""))
        if dt and lat is not None and lon is not None:
            records.append({
                "timestamp": time_str,
                "datetime": dt,
                "latitude": lat,
                "longitude": lon,
                "elevation": None,
                "accuracy": None,
                "activity_type": None,
                "confidence": None,
                "source": "timelinePath"
            })

# Step 3: Extract rawSignals > position
for signal in data.get("rawSignals", []):
    pos = signal.get("position")
    if pos:
        time_str = pos.get("timestamp")
        dt = datetime_from_iso(time_str)
        lat, lon = extract_lat_lon(pos.get("LatLng", ""))
        if dt and lat is not None and lon is not None:
            records.append({
                "timestamp": time_str,
                "datetime": dt,
                "latitude": lat,
                "longitude": lon,
                "elevation": pos.get("altitudeMeters"),
                "accuracy": pos.get("accuracyMeters"),
                "activity_type": None,
                "confidence": None,
                "source": "rawSignals"
            })

# Step 4: Extract place visits (visit.topCandidate.placeLocation)
for segment in data.get("semanticSegments", []):
    visit = segment.get("visit")
    if visit:
        top = visit.get("topCandidate", {})
        loc_str = top.get("placeLocation", {}).get("latLng")
        lat, lon = extract_lat_lon(loc_str)
        confidence = top.get("probability")
        conf_pct = int(confidence * 100) if confidence is not None else None

        for time_key in ["startTime", "endTime"]:
            time_str = segment.get(time_key)
            dt = datetime_from_iso(time_str)
            if time_str and dt and lat is not None and lon is not None:
                records.append({
                    "timestamp": time_str,
                    "datetime": dt,
                    "latitude": lat,
                    "longitude": lon,
                    "elevation": None,
                    "accuracy": None,
                    "activity_type": "PLACE_VISIT",
                    "confidence": conf_pct,
                    "source": "placeVisit"
                })

# Step 5: Enrich records based on activity time windows
for rec in records:
    ts = rec["datetime"]
    if rec["activity_type"] is None:  # Skip if already tagged (e.g., PLACE_VISIT)
        for act in activity_ranges:
            if act["start_time"] <= ts <= act["end_time"]:
                rec["activity_type"] = act["activity_type"]
                rec["confidence"] = act["confidence"]
                break

# Step 6: Print results
count = 0
for rec in records:
    count = 0
raw_signals_printed = 0
place_visits_printed = 0

for rec in records:
    source = rec.get('source', 'unknown')

    # Check print limits
    if LIMIT_OUTPUT:
        if count >= MAX_OUTPUT_RECORDS and raw_signals_printed >= 10 and place_visits_printed >= 5:
            break

    # Update counters for rawSignals and placeVisit
    if source == "rawSignals":
        raw_signals_printed += 1
    elif source == "placeVisit":
        place_visits_printed += 1

    # Print the record
    prefix = f"[{source}]"
    print(f"{prefix} time: {rec['timestamp']}, lat: {rec['latitude']}, lon: {rec['longitude']}", end="")

    if rec["accuracy"] is not None:
        print(f", accuracy: {rec['accuracy']}m", end="")
    if rec["elevation"] is not None:
        print(f", elevation: {rec['elevation']}m", end="")
    if rec["activity_type"]:
        print(f", activity: {rec['activity_type']} ({rec['confidence']}%)", end="")
    print()

    count += 1

