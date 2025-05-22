import json
import re
from datetime import datetime

# 🔧 Output limits
LIMIT_OUTPUT = True
MAX_OUTPUT_RECORDS = 200

# Input file path
input_file = r"G:\My Drive\Google Maps Timeline\timeline.json"

# --- Helper Functions ---

def datetime_from_iso(ts):
    """Converts ISO timestamp to Python datetime."""
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def extract_lat_lon(point_str):
    """Extracts (latitude, longitude) from a string like '12.9041°, 77.6034°'."""
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

# --- Load JSON Data ---
with open(input_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

records = []
activity_ranges = []

# --- Step 1: Parse activity time ranges ---
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

# --- Step 2: Extract from semanticSegments > timelinePath ---
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
                "confidence": None
            })

# --- Step 3: Extract from top-level rawSignals > position ---
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
                "confidence": None
            })

# --- Step 4: Temporal enrichment using activity time windows ---
for rec in records:
    ts = rec["datetime"]
    for act in activity_ranges:
        if act["start_time"] <= ts <= act["end_time"]:
            rec["activity_type"] = act["activity_type"]
            rec["confidence"] = act["confidence"]
            break  # Only tag with the first matching range

# --- Step 5: Print output ---
count = 0
for rec in records:
    print(f"time: {rec['timestamp']}, lat: {rec['latitude']}, lon: {rec['longitude']}", end="")
    if rec["accuracy"] is not None:
        print(f", accuracy: {rec['accuracy']}m", end="")
    if rec["elevation"] is not None:
        print(f", elevation: {rec['elevation']}m", end="")
    if rec["activity_type"]:
        print(f", activity: {rec['activity_type']} ({rec['confidence']}%)", end="")
    print()
    count += 1
    if LIMIT_OUTPUT and count >= MAX_OUTPUT_RECORDS:
        break
