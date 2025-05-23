import json
import re
import argparse
import psycopg2
from datetime import datetime
from psycopg2.extras import execute_values

# Database connection configuration
DB_PARAMS = {
    'host': 'localhost',
    'port': 5432,
    'dbname': 'timeline_data',
    'user': 'timeline_writer',
    # Password is read from .pgpass; do not include it here
}

def count_optional_fields(rec):
    return sum(
        rec.get(field) is not None
        for field in ["accuracy", "elevation", "activity_type", "confidence"]
    )

def extract_lat_lon(point_str):
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

def datetime_from_iso(ts):
    try:
        return datetime.fromisoformat(ts)
    except (ValueError, TypeError):
        return None

def insert_records_into_postgres(records):
    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                for rec in records:
                    if not rec.get("datetime") or rec.get("latitude") is None or rec.get("longitude") is None:
                        continue
                    cur.execute("""
                        SELECT accuracy, elevation, activity_type, confidence
                        FROM timeline.locations
                        WHERE timestamp = %s
                    """, (rec["datetime"],))
                    existing = cur.fetchone()
                    if existing:
                        existing_dict = {
                            "accuracy": existing[0],
                            "elevation": existing[1],
                            "activity_type": existing[2],
                            "confidence": existing[3]
                        }
                        if count_optional_fields(rec) <= count_optional_fields(existing_dict):
                            continue
                        else:
                            cur.execute("DELETE FROM timeline.locations WHERE timestamp = %s", (rec["datetime"],))
                    cur.execute("""
                        INSERT INTO timeline.locations (
                            timestamp, latitude, longitude,
                            elevation, accuracy, activity_type, confidence,
                            location
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s,
                            ST_SetSRID(ST_MakePoint(%s, %s), 4326)
                        )
                    """, (
                        rec["datetime"], rec["latitude"], rec["longitude"],
                        rec.get("elevation"),
                        rec.get("accuracy"),
                        rec.get("activity_type"),
                        rec.get("confidence"),
                        rec["longitude"], rec["latitude"]
                    ))
            conn.commit()
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed: {e}")

def main(input_file):
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if "semanticSegments" not in data:
            print("⚠️ Warning: 'semanticSegments' key missing.")
        if "rawSignals" not in data:
            print("⚠️ Warning: 'rawSignals' key missing.")
    except FileNotFoundError:
        print(f"❌ File not found: {input_file}")
        return
    except json.JSONDecodeError as e:
        print(f"❌ JSON parsing error: {e}")
        return

    records = []
    activity_ranges = []

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

    for segment in data.get("semanticSegments", []):
        for entry in segment.get("timelinePath", []):
            time = entry.get("time")
            point = entry.get("point")
            lat, lon = extract_lat_lon(point)
            dt = datetime_from_iso(time)
            if dt and lat is not None and lon is not None:
                records.append({"datetime": dt, "latitude": lat, "longitude": lon})

    for signal in data.get("rawSignals", []):
        if "position" in signal:
            position = signal["position"]
            time = position.get("timestamp")
            lat, lon = extract_lat_lon(position.get("LatLng", ""))
            dt = datetime_from_iso(time)
            if dt and lat is not None and lon is not None:
                records.append({
                    "datetime": dt,
                    "latitude": lat,
                    "longitude": lon,
                    "accuracy": position.get("accuracyMeters"),
                    "elevation": position.get("altitudeMeters")
                })

    for segment in data.get("semanticSegments", []):
        visit = segment.get("visit")
        if visit:
            for key in ("startTime", "endTime"):
                time = segment.get(key)
                location = visit.get("topCandidate", {}).get("placeLocation", {})
                point = location.get("latLng")
                lat, lon = extract_lat_lon(point)
                dt = datetime_from_iso(time)
                if dt and lat is not None and lon is not None:
                    confidence = int(visit.get("topCandidate", {}).get("probability", 0.0) * 100)
                    records.append({
                        "datetime": dt,
                        "latitude": lat,
                        "longitude": lon,
                        "accuracy": None,
                        "elevation": None,
                        "activity_type": "PLACE_VISIT",
                        "confidence": confidence
                    })

    for rec in records:
        if rec.get("activity_type"):
            continue
        ts = rec["datetime"]
        for act in activity_ranges:
            if act["start_time"] <= ts <= act["end_time"]:
                rec["activity_type"] = act["activity_type"]
                rec["confidence"] = act["confidence"]
                break

    insert_records_into_postgres(records)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract and enrich Google Maps Timeline data.")
    parser.add_argument("--input_file", required=True, help="Path to the JSON timeline file")
    args = parser.parse_args()
    main(args.input_file)
