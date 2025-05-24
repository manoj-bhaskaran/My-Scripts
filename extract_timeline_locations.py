import json
import re
import argparse
import psycopg2
from datetime import datetime
from psycopg2.extras import execute_values
from elevation import get_elevation

# Database connection configuration
DB_PARAMS = {
    'host': 'localhost',
    'port': 5432,
    'dbname': 'timeline_data',
    'user': 'timeline_writer',
    # Password is read from .pgpass; do not include it here
}

# Time window for near-duplicate records
# This is used to filter out records that are too close in time
NEAR_DUPLICATE_WINDOW_SECONDS = 30

def count_optional_fields(rec):
    """
    Counts the number of non-null optional fields (accuracy, elevation, activity_type, confidence) in a record.

    Args:
        rec (dict): A record dictionary.

    Returns:
        int: Number of optional fields that are not None.
    """
    return sum(
        rec.get(field) is not None
        for field in ["accuracy", "elevation", "activity_type", "confidence"]
    )

def extract_lat_lon(point_str):
    """
    Extracts latitude and longitude from a string of the form '12.34°, 56.78°'.

    Args:
        point_str (str): A string representing latitude and longitude with degree symbols.

    Returns:
        tuple[float, float] or (None, None): Parsed (latitude, longitude) if successful.
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

def datetime_from_iso(ts):
    """
    Safely parses an ISO 8601 timestamp string into a datetime object.

    Returns:
        datetime or None: Parsed datetime if valid, otherwise None.
    """
    try:
        return datetime.fromisoformat(ts)
    except (ValueError, TypeError):
        return None

def get_last_processed_timestamp():
    """
    Fetches the last processed timestamp from the control table in PostgreSQL.

    Returns:
        datetime or None: The last processed timestamp if available, otherwise None.
    """
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
    """
    Updates or inserts the last processed timestamp in the control table.

    Args:
        ts (datetime): The new timestamp to store.
    """
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
    """
    Inserts timeline records into the PostgreSQL database.
    If a record with the same timestamp exists, it is replaced only if the new record has more complete data.

    Args:
        records (list[dict]): Timeline records to insert.
        stats (dict): Dictionary to collect stats about inserted, replaced, or skipped records.
    """
    stats["records_inserted"] = 0
    stats["records_replaced"] = 0
    stats["records_skipped_due_to_existing_richer"] = 0
    stats["records_skipped_near_duplicate"] = 0
    stats["records_replaced_near_duplicate"] = 0

    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                for rec in records:
                    if not rec.get("datetime") or rec.get("latitude") is None or rec.get("longitude") is None:
                        continue
                    # Check for near-duplicate (same lat/lon within configured time window)
                    cur.execute(f"""
                        SELECT location_id, accuracy, elevation, activity_type, confidence
                        FROM timeline.locations
                        WHERE latitude = %s AND longitude = %s
                        AND timestamp BETWEEN %s - INTERVAL '{NEAR_DUPLICATE_WINDOW_SECONDS}'
                                        AND %s + INTERVAL '{NEAR_DUPLICATE_WINDOW_SECONDS}'
                        LIMIT 1;
                    """, (rec["latitude"], rec["longitude"], rec["datetime"], rec["datetime"]))

                    near_dup = cur.fetchone()
                    if near_dup:
                        existing_dict = {
                            "accuracy": near_dup[1],
                            "elevation": near_dup[2],
                            "activity_type": near_dup[3],
                            "confidence": near_dup[4]
                        }
                        if count_optional_fields(rec) > count_optional_fields(existing_dict):
                            # Replace near-duplicate with richer record
                            cur.execute("DELETE FROM timeline.locations WHERE location_id = %s", (near_dup[0],))
                            stats["records_replaced_near_duplicate"] += 1
                            # fall through to insert below
                        else:
                            stats["records_skipped_near_duplicate"] += 1
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

def get_last_elevation_timestamp():
    """
        Fetches the last processed timestamp for elevation updates from the control table.

        Returns:
            datetime or None: The most recent timestamp recorded for elevation, or None if not set.
    """
    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT last_processed_timestamp
                    FROM timeline.control
                    WHERE control_key = 'elevation_main'
                """)
                row = cur.fetchone()
                return row[0] if row else None
    except psycopg2.OperationalError as e:
        print(f"❌ Failed to read elevation control timestamp: {e}")
        return None

def update_last_elevation_timestamp(ts):
    """
        Updates the control table with the latest timestamp processed for elevation data.

        Args:
            ts (datetime): The timestamp to store as last processed for elevation.
    """
    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO timeline.control (control_key, last_processed_timestamp)
                    VALUES ('elevation_main', %s)
                    ON CONFLICT (control_key)
                    DO UPDATE SET last_processed_timestamp = EXCLUDED.last_processed_timestamp
                """, (ts,))
            conn.commit()
    except psycopg2.OperationalError as e:
        print(f"❌ Failed to update elevation control timestamp: {e}")

def fetch_records_missing_elevation(last_ts=None):
    """
        Fetches timeline records that have no elevation data.
        If a last processed timestamp is provided, only records after that timestamp are returned.

        Args:
            last_ts (datetime or None): Lower bound timestamp filter. If None, all missing elevation records are returned.

        Returns:
            list of tuples: Each tuple contains (location_id, timestamp, latitude, longitude).
    """
    query = """
        SELECT location_id, timestamp, latitude, longitude
        FROM timeline.locations
        WHERE elevation IS NULL
    """
    # Build query to fetch records missing elevation (optionally filter by timestamp)
    params = []
    if last_ts:
        query += " AND timestamp >= %s"
        params.append(last_ts)

    query += " ORDER BY timestamp"

    with psycopg2.connect(**DB_PARAMS) as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()

def update_elevations(records, elevation_stats):
    """
    Updates elevation values in the database for the given timeline records using SRTM elevation data.

    Args:
        records (list of tuples): Timeline records missing elevation (location_id, timestamp, latitude, longitude).
        elevation_stats (dict): Dictionary to accumulate statistics about the elevation update process.

    Returns:
        datetime or None: The latest timestamp successfully updated, or None if no updates were made.
    """
    latest_ts = None

    if not records:
        return None  # nothing to do

    try:
        with psycopg2.connect(**DB_PARAMS) as conn:
            with conn.cursor() as cur:
                for location_id, ts, lat, lon in records:
                    elevation_stats["records_considered"] += 1

                    elevation = get_elevation(lat, lon)

                    if elevation is None:
                        elevation_stats["records_skipped_due_to_null_elevation"] += 1
                        continue

                    cur.execute("""
                        UPDATE timeline.locations
                        SET elevation = %s
                        WHERE location_id = %s
                    """, (elevation, location_id))

                    elevation_stats["records_updated"] += 1

                    if latest_ts is None or ts > latest_ts:
                        latest_ts = ts

            conn.commit()
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed during elevation update: {e}")
        return None

    return latest_ts

def main(input_file, reprocess, reprocess_elevation):
    """
        Main logic to process Google Maps timeline data and update elevation in the database.

        This includes:
        - Reading and parsing the input JSON file.
        - Filtering records based on last processed timestamp (unless --reprocess is used).
        - Extracting timelinePath, rawSignals, and placeVisit entries.
        - Enriching location records with activity type based on activity segments.
        - Inserting new or improved location records into the timeline.locations table.
        - Optionally updating elevation for records missing elevation (based on --reprocess-elevation flag and control timestamp).

        Args:
            input_file (str): Path to the JSON timeline export file.
            reprocess (bool): If True, processes all timeline data regardless of control timestamp.
            reprocess_elevation (bool): If True, processes all missing elevation data regardless of elevation control timestamp.
    """
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

    # List of extracted location records (to be inserted later)
    # Each record contains datetime, lat/lon, and optionally accuracy, elevation, etc.
    records = []
    activity_ranges = []

    # Step 1: Extract activity time ranges for later enrichment
    # These are used to tag location points with inferred activity type
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
                    "activity_type": act_type,
                    "confidence": int(confidence * 100) if confidence is not None else None
                }
                activity_ranges.append(activity_record)
                stats["activity_ranges_total"] += 1

    # Step 2: Extract GPS points from timelinePath entries
    for segment in data.get("semanticSegments", []):
        for entry in segment.get("timelinePath", []):
            stats["timelinePath_read"] += 1
            time = entry.get("time")
            point = entry.get("point")
            lat, lon = extract_lat_lon(point)
            dt = datetime_from_iso(time)
            # Skip invalid or outdated entries
            # Append valid entries with lat/lon/timestamp
            if dt and lat is not None and lon is not None:
                if not last_processed or dt >= last_processed:
                    stats["timelinePath_processed"] += 1
                    records.append({"datetime": dt, "latitude": lat, "longitude": lon})
                else:
                    stats["timelinePath_skipped"] += 1
            else:
                stats["records_invalid_format"] += 1

    # Step 3: Extract raw signal locations (usually from WiFi/GPS sources)
    for signal in data.get("rawSignals", []):
        if "position" in signal:
            stats["rawSignals_read"] += 1
            position = signal["position"]
            time = position.get("timestamp")
            lat, lon = extract_lat_lon(position.get("LatLng", ""))
            dt = datetime_from_iso(time)
            # Only process valid raw signal points with usable lat/lon and timestamp
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

    # Step 4: Extract place visit records with approximate start/end points
    # Each visit produces 2 records (start and end)
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

    # Step 5: Enrich records without activity_type using activity_ranges
    # Match each point's timestamp to a known activity window if possible
    for rec in records:
        if rec.get("activity_type"):
            continue
        ts = rec["datetime"]
        matched = False
        # Use the first matching activity range to annotate the point
        # If no match is found, record this in stats
        for act in activity_ranges:
            if act["start_time"] <= ts <= act["end_time"]:
                rec["activity_type"] = act["activity_type"]
                rec["confidence"] = act["confidence"]
                stats["records_enriched"] += 1
                matched = True
                break
        if not matched:
            stats["records_not_enriched_due_to_no_match"] += 1

    # Step 6: Insert final records into PostgreSQL
    # Skip duplicates unless the new record has more complete metadata
    insert_records_into_postgres(records, stats)

    elevation_stats = {
        "records_considered": 0,
        "records_skipped_due_to_null_elevation": 0,
        "records_updated": 0
    }

    # Step 7: Elevation enrichment phase
    # Fetch records with missing elevation, optionally skipping previously processed ones
    if reprocess_elevation:
        last_ts = None
        print("🔁 Reprocessing all elevation records")
    else:
        last_ts = get_last_elevation_timestamp()
        if last_ts:
            print(f"▶️ Processing elevation updates from {last_ts.isoformat()}")
        else:
            print("▶️ No previous elevation timestamp, processing all missing elevations")

    records = fetch_records_missing_elevation(last_ts)
    elevation_records_to_process = fetch_records_missing_elevation(last_ts) # Renamed variable for clarity
    latest_ts = update_elevations(elevation_records_to_process, elevation_stats)

    if latest_ts:
        update_last_elevation_timestamp(latest_ts)
        print(f"🕒 Elevation last processed timestamp updated to {latest_ts.isoformat()}")

    print("\n📊 Summary:")
    for k, v in stats.items():
        print(f"{k}: {v}")
    print(f"Total records processed for DB insert: {len(records)}")

    # Print elevation update statistics
    print("\n📊 Elevation Processing Summary:")
    for k, v in elevation_stats.items():
        print(f"{k}: {v}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract and enrich Google Maps Timeline data.")
    parser.add_argument(
        "--input_file",
        default="G:\\My Drive\\Google Maps Timeline\\Timeline.json",
        help="Path to the JSON timeline file (default: G:\\My Drive\\Google Maps Timeline\\Timeline.json)"
    )
    parser.add_argument(
        "--reprocess", 
        action="store_true", 
        help="Reprocess all records regardless of last processed timestamp"
    )
    parser.add_argument(
        "--reprocess-elevation",
        action="store_true",
        help="Force reprocessing of all elevation values regardless of control timestamp"
    )
    args = parser.parse_args()
    main(args.input_file, args.reprocess, args.reprocess_elevation)
