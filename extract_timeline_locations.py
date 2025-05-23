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

def get_last_processed_timestamp():
    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT last_processed_timestamp
                    FROM timeline.control
                    WHERE control_key = 'timeline_main'
                """)
                row = cur.fetchone()
                return row[0] if row else None
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed while reading control: {e}")
        return None

def update_last_processed_timestamp(ts):
    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO timeline.control (control_key, last_processed_timestamp)
                    VALUES ('timeline_main', %s)
                    ON CONFLICT (control_key)
                    DO UPDATE SET last_processed_timestamp = EXCLUDED.last_processed_timestamp
                """, (ts,))
            conn.commit()
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed while updating control: {e}")

def insert_records_into_postgres(records, stats):
    stats["records_inserted"] = 0
    stats["records_replaced"] = 0
    stats["records_skipped_due_to_existing_richer"] = 0

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
                            stats["records_skipped_due_to_existing_richer"] += 1
                            continue
                        else:
                            cur.execute("DELETE FROM timeline.locations WHERE timestamp = %s", (rec["datetime"],))
                            stats["records_replaced"] += 1
                    else:
                        stats["records_inserted"] += 1
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
            if records:
                latest = max(r["datetime"] for r in records)
                update_last_processed_timestamp(latest)
                print(f"🕒 Last processed timestamp updated to: {latest.isoformat()}")

    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed: {e}")

def main(input_file, reprocess):
    stats = {
    "timelinePath_read": 0,
    "timelinePath_skipped": 0,
    "timelinePath_processed": 0,
    "rawSignals_read": 0,
    "rawSignals_skipped": 0,
    "rawSignals_processed": 0,
    "placeVisit_read": 0,
    "placeVisit_skipped": 0,
    "placeVisit_processed": 0,
    "activity_ranges_total": 0,
    "records_enriched": 0,
    "records_not_enriched_due_to_no_match": 0,
    "records_invalid_format": 0
}

    last_processed = get_last_processed_timestamp()
    if reprocess:
        last_processed = None
    if reprocess:
        print("🔁 Reprocessing all records (ignoring last processed timestamp)")
    elif last_processed:
        print(f"▶️ Starting processing from {last_processed.isoformat()}")
    else:
        print("▶️ Starting full processing (no prior timestamp found)")

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
            if start_time and end_time and act_type and (not last_processed or end_time >= last_processed):
                activity_record = {
                    "start_time": start_time,
                    "end_time": end_time,
                    "activity_type": act_type
                }
                if confidence is not None:
                    activity_record["confidence"] = int(confidence * 100)
                activity_ranges.append(activity_record)
                stats["activity_ranges_total"] += 1

    for segment in data.get("semanticSegments", []):
        for entry in segment.get("timelinePath", []):
            stats["timelinePath_read"] += 1
            time = entry.get("time")
            point = entry.get("point")
            lat, lon = extract_lat_lon(point)
            dt = datetime_from_iso(time)
            if dt and lat is not None and lon is not None:
                if not last_processed or dt >= last_processed:
                    stats["timelinePath_processed"] += 1
                    records.append({"datetime": dt, "latitude": lat, "longitude": lon})
                else:
                    stats["timelinePath_skipped"] += 1
            else:
                stats["records_invalid_format"] += 1

    for signal in data.get("rawSignals", []):
        if "position" in signal:
            stats["rawSignals_read"] += 1
            position = signal["position"]
            time = position.get("timestamp")
            lat, lon = extract_lat_lon(position.get("LatLng", ""))
            dt = datetime_from_iso(time)
            if dt and lat is not None and lon is not None:
                if not last_processed or dt >= last_processed:
                    stats["rawSignals_processed"] += 1
                    records.append({
                        "datetime": dt,
                        "latitude": lat,
                        "longitude": lon,
                        "accuracy": position.get("accuracyMeters"),
                    })
                else:
                    stats["rawSignals_skipped"] += 1
            else:
                stats["records_invalid_format"] += 1

    for segment in data.get("semanticSegments", []):
        visit = segment.get("visit")
        if visit:
            for key in ("startTime", "endTime"):
                stats["placeVisit_read"] += 1
                time = segment.get(key)
                location = visit.get("topCandidate", {}).get("placeLocation", {})
                point = location.get("latLng")
                lat, lon = extract_lat_lon(point)
                dt = datetime_from_iso(time)
                if dt and lat is not None and lon is not None:
                    if not last_processed or dt >= last_processed:
                        stats["placeVisit_processed"] += 1
                        prob = visit.get("topCandidate", {}).get("probability")
                        confidence = int(prob * 100) if prob is not None else None
                        records.append({
                            "datetime": dt,
                            "latitude": lat,
                            "longitude": lon,
                            "accuracy": None,
                            "elevation": None,
                            "activity_type": "PLACE_VISIT",
                            "confidence": confidence
                        })
                    else:
                        stats["placeVisit_skipped"] += 1
                else:
                    stats["records_invalid_format"] += 1

    for rec in records:
        if rec.get("activity_type"):
            continue
        ts = rec["datetime"]
        matched = False
        for act in activity_ranges:
            if act["start_time"] <= ts <= act["end_time"]:
                rec["activity_type"] = act["activity_type"]
                rec["confidence"] = act["confidence"]
                stats["records_enriched"] += 1
                matched = True
                break
        if not matched:
            stats["records_not_enriched_due_to_no_match"] += 1

    insert_records_into_postgres(records, stats)
    print("\n📊 Summary:")
    for k, v in stats.items():
        print(f"{k}: {v}")
    print(f"Total records processed for DB insert: {len(records)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract and enrich Google Maps Timeline data.")
    parser.add_argument("--input_file", required=True, help="Path to the JSON timeline file")
    parser.add_argument(
        "--reprocess", 
        action="store_true", 
        help="Reprocess all records regardless of last processed timestamp"
    )
    args = parser.parse_args()
    main(args.input_file, args.reprocess)
