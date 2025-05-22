import json
import re
import argparse
from datetime import datetime

# Constants
DEFAULT_INPUT_FILE = r"G:\My Drive\Google Maps Timeline\timeline.json"
LIMIT_OUTPUT = True
MAX_OUTPUT_RECORDS = 200

# --- Helper functions ---
def datetime_from_iso(ts):
    """Convert ISO timestamp to datetime object."""
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def extract_lat_lon(point_str):
    """Extract (lat, lon) from strings like '12.9041°, 77.6034°'."""
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

# --- Argument parsing ---
parser = argparse.ArgumentParser(description="Extract and enrich Google Maps Timeline data.")
parser.add_argument("--input_file", default=DEFAULT_INPUT_FILE, help="Path to the JSON timeline file")
args = parser.parse_args()

# --- Load and validate input JSON ---
try:
    with open(args.input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"❌ File not found: {args.input_file}")
    exit(1)
except json.JSONDecodeError as e:
    print(f"❌ JSON parsing error: {e}")
    exit(1)

if "semanticSegments" not in data:
    print("⚠️ Warning: 'semanticSegments' key missing.")
if "rawSignals" not in data:
    print("⚠️ Warning: 'rawSignals' key missing.")

records = []
activity_ranges = []

# --- Step 1: Extract time-based activity segments ---
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

# --- Step 2: Extract timelinePath points ---
for segment in data.get("semanticSegments", []):
    for entry in segment.get("timelinePath", []):
        time_str = entry.get("time")
        dt = datetime_from_iso(time_str)
        lat, lon = extract_lat_lon(entry.get("point", ""))
        if dt and lat is not None and lon is not None:
            records.append({
                "datetime": dt,
                "latitude": lat,
                "longitude": lon,
                "elevation": None,
                "accuracy": None,
                "activity_type": None,
                "confidence": None,
                "source": "timelinePath"
            })

# --- Step 3: Extract rawSignals > position points ---
for signal in data.get("rawSignals", []):
    pos = signal.get("position")
    if pos:
        time_str = pos.get("timestamp")
        dt = datetime_from_iso(time_str)
        lat, lon = extract_lat_lon(pos.get("LatLng", ""))
        if dt and lat is not None and lon is not None:
            records.append({
                "datetime": dt,
                "latitude": lat,
                "longitude": lon,
                "elevation": pos.get("altitudeMeters"),
                "accuracy": pos.get("accuracyMeters"),
                "activity_type": None,
                "confidence": None,
                "source": "rawSignals"
            })

# --- Step 4: Extract place visit segments ---
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
                    "datetime": dt,
                    "latitude": lat,
                    "longitude": lon,
                    "elevation": None,
                    "accuracy": None,
                    "activity_type": "PLACE_VISIT",
                    "confidence": conf_pct,
                    "source": "placeVisit"
                })

# --- Step 5: Enrich records with activity type based on timestamp ---
for rec in records:
    if rec["activity_type"] is not None:
        continue
    ts = rec["datetime"]
    for act in activity_ranges:
        if act["start_time"] <= ts <= act["end_time"]:
            rec["activity_type"] = act["activity_type"]
            rec["confidence"] = act["confidence"]
            break

# --- Step 6: Print output, ensuring minimum counts for some sources ---
count = 0
raw_signals_printed = 0
place_visits_printed = 0

for rec in records:
    source = rec.get("source", "unknown")

    if LIMIT_OUTPUT:
        if count >= MAX_OUTPUT_RECORDS and raw_signals_printed >= 10 and place_visits_printed >= 5:
            break

    if source == "rawSignals":
        raw_signals_printed += 1
    elif source == "placeVisit":
        place_visits_printed += 1

    prefix = f"[{source}]"
    ts = rec["datetime"].isoformat()
    print(f"{prefix} time: {ts}, lat: {rec['latitude']}, lon: {rec['longitude']}", end="")

    if rec["accuracy"] is not None:
        print(f", accuracy: {rec['accuracy']}m", end="")
    if rec["elevation"] is not None:
        print(f", elevation: {rec['elevation']}m", end="")
    if rec["activity_type"]:
        print(f", activity: {rec['activity_type']} ({rec['confidence']}%)", end="")
    print()

    count += 1
