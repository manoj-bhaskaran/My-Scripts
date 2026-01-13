import argparse
import json
import re
import sys
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import (
    Any,
    Dict,
    Generator,
    Iterable,
    Iterator,
    List,
    Mapping,
    MutableMapping,
    Optional,
    Sequence,
    Tuple,
    cast,
)

# Add module paths to sys.path for imports
script_dir = Path(__file__).resolve().parent
repo_root = script_dir.parent.parent.parent
modules_logging = repo_root / "src" / "python" / "modules" / "logging"
modules_auth = repo_root / "src" / "python" / "modules" / "auth"

sys.path.insert(0, str(modules_logging))
sys.path.insert(0, str(modules_auth))

import psycopg2
from psycopg2.extensions import connection as PgConnection, cursor as PgCursor
from psycopg2.extras import execute_values

from elevation import get_elevation
import python_logging_framework as plog

# Initialize logger for this module
logger = plog.initialise_logger(__name__)

# Database connection configuration
DB_PARAMS = {
    "host": "localhost",
    "port": 5432,
    "dbname": "timeline_data",
    "user": "timeline_writer",
    # Password is read from .pgpass; do not include it here
}

# Time window for near-duplicate records
# This is used to filter out records that are too close in time
NEAR_DUPLICATE_WINDOW_SECONDS = 30

TimelineRecord = Dict[str, Any]
ActivityRange = Dict[str, Any]
StatsDict = Dict[str, int]
ElevationRecord = Tuple[int, datetime, float, float]


@contextmanager
def get_db_cursor() -> Iterator[Tuple[PgConnection, PgCursor]]:
    """Yield a PostgreSQL connection and cursor with automatic cleanup.

    Returns:
        An iterator that provides ``(connection, cursor)`` for use within a context manager.

    Raises:
        psycopg2.OperationalError: If the database connection cannot be established.
        Exception: Propagates any unexpected error after rolling back the transaction.
    """
    conn: Optional[PgConnection] = None
    cur: Optional[PgCursor] = None
    try:
        conn = psycopg2.connect(**DB_PARAMS)
        cur = conn.cursor()
        yield conn, cur
        conn.commit()  # ✅ Commit only if everything went fine
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed: {e}")
        raise
    except Exception:
        if conn:
            conn.rollback()  # 🔁 Roll back on any unexpected error
        raise
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def count_optional_fields(rec: Mapping[str, Any]) -> int:
    """
    Counts the number of non-null optional fields (accuracy, elevation, activity_type, confidence) in a record.

    Args:
        rec: A record dictionary.

    Returns:
        Number of optional fields that are not ``None``.
    """
    # Count how many of the optional metadata fields are populated in a record.
    # Used to determine whether a new record is "richer" than an existing one.
    return sum(
        rec.get(field) is not None
        for field in ["accuracy", "elevation", "activity_type", "confidence"]
    )


def extract_lat_lon(point_str: str | None) -> Tuple[Optional[float], Optional[float]]:
    """
    Extracts latitude and longitude from a string of the form '12.34°, 56.78°'.

    Args:
        point_str: A string representing latitude and longitude with degree symbols.

    Returns:
        Parsed ``(latitude, longitude)`` tuple if successful; otherwise ``(None, None)``.
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


def datetime_from_iso(ts: str | None) -> Optional[datetime]:
    """
    Safely parses an ISO 8601 timestamp string into a datetime object.

    Returns:
        Parsed datetime if valid, otherwise ``None``.
    """
    if not isinstance(ts, str):
        return None
    try:
        return datetime.fromisoformat(ts)
    except (ValueError, TypeError):
        return None


def get_last_processed_timestamp() -> Optional[datetime]:
    """
    Fetches the last processed timestamp from the control table in PostgreSQL.

    Returns:
        The last processed timestamp if available; otherwise ``None``.
    """
    with get_db_cursor() as (_, cur):
        cur.execute(
            """
            SELECT last_processed_timestamp
            FROM timeline.control
            WHERE control_key = 'timeline_main'
        """
        )
        row = cur.fetchone()
        return row[0] if row else None


def update_last_processed_timestamp(ts: datetime) -> None:
    """
    Updates or inserts the last processed timestamp in the control table.

    Args:
        ts: The new timestamp to store.
    """
    with get_db_cursor() as (_, cur):
        cur.execute(
            """
            INSERT INTO timeline.control (control_key, last_processed_timestamp)
            VALUES ('timeline_main', %s)
            ON CONFLICT (control_key)
            DO UPDATE SET last_processed_timestamp = EXCLUDED.last_processed_timestamp
        """,
            (ts,),
        )


def insert_records_into_postgres(records: Sequence[TimelineRecord], stats: StatsDict) -> None:
    """
    Inserts timeline records into the PostgreSQL database.

    Each record is evaluated in two steps:

    1. Near-Duplicate Check:
    - If a record with the same latitude and longitude is found within ±N seconds of the new record's timestamp,
      it is considered a near-duplicate.
    - If the new record has more non-null optional fields (accuracy, elevation, activity_type, confidence),
      the near-duplicate is deleted and replaced.
    - Otherwise, the new record is skipped.

    2. Exact Timestamp Check:
    - If no near-duplicate was found, the function checks if a record exists with the same timestamp.
    - If found and the new record is richer, it replaces the old one.
    - If found but not richer, it is skipped.
    - If no match is found, the new record is inserted.

    Args:
        records: Timeline records to insert.
        stats: Dictionary to accumulate statistics on inserted, replaced, skipped, and duplicate records.
    """
    stats.update(
        {
            "records_inserted": 0,
            "records_replaced": 0,
            "records_skipped_due_to_existing_richer": 0,
            "records_skipped_near_duplicate": 0,
            "records_replaced_near_duplicate": 0,
        }
    )

    interval_str = f"{NEAR_DUPLICATE_WINDOW_SECONDS} seconds"
    if not records:
        return

    with get_db_cursor() as (_, cur):
        for rec in records:
            if (
                not rec.get("datetime")
                or rec.get("latitude") is None
                or rec.get("longitude") is None
            ):
                continue

            if check_near_duplicate(rec, cur, interval_str, stats):
                continue
            if check_exact_timestamp_duplicate(rec, cur, stats):
                continue

            perform_insert(rec, cur)
            stats["records_inserted"] += 1

    latest = max(r["datetime"] for r in records)
    update_last_processed_timestamp(latest)
    plog.log_info(logger, f"🕒 Last processed timestamp updated to: {latest.isoformat()}")


def check_near_duplicate(
    rec: Mapping[str, Any], cur: PgCursor, interval_str: str, stats: StatsDict
) -> bool:
    """
    Checks if a near-duplicate record exists in the database and decides whether to replace it.

    A near-duplicate is defined as a record with the same latitude and longitude within ±N seconds
    of the current record's timestamp.

    - If a near-duplicate exists and the new record is richer (has more non-null optional fields),
        the existing record is deleted.
    - If the near-duplicate exists but the new record is not richer, it is skipped.

    Args:
        rec: The timeline record to evaluate.
        cur: Active database cursor.
        interval_str: SQL interval string for the time window.
        stats: Dictionary to update counts for skipped and replaced near-duplicates.

    Returns:
        bool: True if the record should be skipped due to a non-richer near-duplicate.
                False if no near-duplicate or the new record is richer.
    """
    cur.execute(
        """
        SELECT location_id, accuracy, elevation, activity_type, confidence
        FROM timeline.locations
        WHERE latitude = %s AND longitude = %s
        AND timestamp BETWEEN %s - INTERVAL %s
                        AND %s + INTERVAL %s
        LIMIT 1
    """,
        (
            rec["latitude"],
            rec["longitude"],
            rec["datetime"],
            interval_str,
            rec["datetime"],
            interval_str,
        ),
    )

    near_dup = cur.fetchone()
    if near_dup:
        existing = {
            "accuracy": near_dup[1],
            "elevation": near_dup[2],
            "activity_type": near_dup[3],
            "confidence": near_dup[4],
        }
        if count_optional_fields(rec) > count_optional_fields(existing):
            cur.execute("DELETE FROM timeline.locations WHERE location_id = %s", (near_dup[0],))
            stats["records_replaced_near_duplicate"] += 1
            return False
        else:
            stats["records_skipped_near_duplicate"] += 1
            return True
    return False


def check_exact_timestamp_duplicate(
    rec: Mapping[str, Any], cur: PgCursor, stats: StatsDict
) -> bool:
    """
    Checks if a record already exists in the database with the exact same timestamp.

    - If such a record exists and has more or equal non-null optional fields than the new record,
      the new record is skipped.
    - If the new record is richer, the existing one is deleted.

    Args:
        rec: The timeline record to evaluate.
        cur: Active database cursor.
        stats: Dictionary to update counts for skipped and replaced timestamp duplicates.

    Returns:
        bool: True if the record should be skipped due to a non-richer timestamp match.
              False if the record is unique or should replace the existing one.
    """
    cur.execute(
        """
        SELECT accuracy, elevation, activity_type, confidence
        FROM timeline.locations
        WHERE timestamp = %s
    """,
        (rec["datetime"],),
    )
    existing = cur.fetchone()
    if existing:
        existing_dict = {
            "accuracy": existing[0],
            "elevation": existing[1],
            "activity_type": existing[2],
            "confidence": existing[3],
        }
        if count_optional_fields(rec) > count_optional_fields(existing_dict):
            cur.execute("DELETE FROM timeline.locations WHERE timestamp = %s", (rec["datetime"],))
            stats["records_replaced"] += 1
            return False
        else:
            stats["records_skipped_due_to_existing_richer"] += 1
            return True
    return False


def perform_insert(rec: Mapping[str, Any], cur: PgCursor) -> None:
    """
    Inserts the given timeline record into the database.

    This function assumes that the record has already passed all duplicate and richness checks.

    Args:
        rec: The timeline record to insert.
        cur: Active database cursor.
    """
    cur.execute(
        """
        INSERT INTO timeline.locations (
            timestamp, latitude, longitude,
            elevation, accuracy, activity_type, confidence,
            location
        ) VALUES (%s, %s, %s, %s, %s, %s, %s,
            ST_SetSRID(ST_MakePoint(%s, %s), 4326)
        )
    """,
        (
            rec["datetime"],
            rec["latitude"],
            rec["longitude"],
            rec.get("elevation"),
            rec.get("accuracy"),
            rec.get("activity_type"),
            rec.get("confidence"),
            rec["longitude"],
            rec["latitude"],
        ),
    )


def get_last_elevation_timestamp() -> Optional[datetime]:
    """
    Fetches the last processed timestamp for elevation updates from the control table.

    Returns:
        The most recent timestamp recorded for elevation, or ``None`` if not set.
    """
    with get_db_cursor() as (_, cur):
        cur.execute(
            """
            SELECT last_processed_timestamp
            FROM timeline.control
            WHERE control_key = 'elevation_main'
        """
        )
        row = cur.fetchone()
        return row[0] if row else None


def update_last_elevation_timestamp(ts: datetime) -> None:
    """
    Updates the control table with the latest timestamp processed for elevation data.

    Args:
        ts: The timestamp to store as last processed for elevation.
    """
    with get_db_cursor() as (conn, cur):
        cur.execute(
            """
            INSERT INTO timeline.control (control_key, last_processed_timestamp)
            VALUES ('elevation_main', %s)
            ON CONFLICT (control_key)
            DO UPDATE SET last_processed_timestamp = EXCLUDED.last_processed_timestamp
        """,
            (ts,),
        )


def fetch_records_missing_elevation(
    last_ts: Optional[datetime] = None,
) -> List[ElevationRecord]:
    """
    Fetches timeline records that have no elevation data.
    If a last processed timestamp is provided, only records after that timestamp are returned.

    Args:
        last_ts: Lower bound timestamp filter. If ``None``, all missing elevation records are returned.

    Returns:
        List of tuples containing ``(location_id, timestamp, latitude, longitude)``.
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

    with get_db_cursor() as (_, cur):
        cur.execute(query, params)
        rows = cur.fetchall()
        return [
            (int(location_id), ts, float(lat), float(lon)) for location_id, ts, lat, lon in rows
        ]


def update_elevations(
    records: Sequence[ElevationRecord], elevation_stats: StatsDict
) -> Optional[datetime]:
    """
    Updates elevation values in the database for the given timeline records using SRTM elevation data.

    Args:
        records: Timeline records missing elevation ``(location_id, timestamp, latitude, longitude)``.
        elevation_stats: Dictionary to accumulate statistics about the elevation update process.

    Returns:
        The latest timestamp successfully updated, or ``None`` if no updates were made.
    """
    latest_ts = None
    if not records:
        return None  # nothing to do

    with get_db_cursor() as (_, cur):
        for location_id, ts, lat, lon in records:
            elevation_stats["records_considered"] += 1

            elevation = get_elevation(lat, lon)

            # Skip updating if elevation could not be determined from SRTM data.
            if elevation is None:
                elevation_stats["records_skipped_due_to_null_elevation"] += 1
                continue

            cur.execute(
                """
                UPDATE timeline.locations
                SET elevation = %s
                WHERE location_id = %s
            """,
                (elevation, location_id),
            )

            elevation_stats["records_updated"] += 1

            if latest_ts is None or ts > latest_ts:
                latest_ts = ts

    return latest_ts


def initialize_stats() -> StatsDict:
    """
    Initializes and returns a dictionary to track statistics for timeline data processing.

    Returns:
        A dictionary with counters for various processing statistics.
    """
    return {
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
        "records_invalid_format": 0,
    }


def print_start_message(last_processed: Optional[datetime], reprocess: bool) -> None:
    """
    Prints a message indicating the start of processing, including whether reprocessing is enabled
    and the last processed timestamp if available.

    Args:
        last_processed: The last processed timestamp, or ``None`` if not set.
        reprocess: Whether all records will be reprocessed.
    """
    if reprocess:
        plog.log_info(logger, "🔁 Reprocessing all records (ignoring last processed timestamp)")
    elif last_processed:
        plog.log_info(logger, f"▶️ Starting processing from {last_processed.isoformat()}")
    else:
        plog.log_info(logger, "▶️ Starting full processing (no prior timestamp found)")


def load_json(input_file: str | Path) -> Optional[Dict[str, Any]]:
    """
    Loads and parses a JSON file containing Google Maps Timeline data.

    Args:
        input_file: Path to the JSON file.

    Returns:
        Parsed JSON data as a dictionary, or ``None`` if loading fails.
    """
    try:
        with open(input_file, "r", encoding="utf-8") as f:
            data = cast(Dict[str, Any], json.load(f))
        if "semanticSegments" not in data:
            plog.log_warning(logger, "⚠️ Warning: 'semanticSegments' key missing.")
        if "rawSignals" not in data:
            plog.log_warning(logger, "⚠️ Warning: 'rawSignals' key missing.")
        return data
    except FileNotFoundError:
        plog.log_error(logger, f"❌ File not found: {input_file}")
    except json.JSONDecodeError as e:
        plog.log_error(logger, f"❌ JSON parsing error: {e}")
    return None


def extract_activity_ranges(
    data: Mapping[str, Any], last_processed: Optional[datetime], stats: StatsDict
) -> List[ActivityRange]:
    """
    Extracts activity ranges from semantic segments in the timeline data.

    Args:
        data: Parsed timeline JSON data.
        last_processed: Lower bound timestamp filter.
        stats: Dictionary to accumulate statistics.

    Returns:
        List of activity range dictionaries with start/end times, type, and confidence.
    """
    ranges = []
    for segment in data.get("semanticSegments", []):
        activity = segment.get("activity")
        if activity:
            start_time = datetime_from_iso(segment.get("startTime"))
            end_time = datetime_from_iso(segment.get("endTime"))
            top = activity.get("topCandidate", {})
            act_type = top.get("type")
            confidence = top.get("probability")
            if (
                start_time
                and end_time
                and act_type
                and (not last_processed or end_time >= last_processed)
            ):
                ranges.append(
                    {
                        "start_time": start_time,
                        "end_time": end_time,
                        "activity_type": act_type,
                        "confidence": int(confidence * 100) if confidence is not None else None,
                    }
                )
                stats["activity_ranges_total"] += 1
    return ranges


def extract_timeline_path(
    data: Mapping[str, Any], last_processed: Optional[datetime], stats: StatsDict
) -> List[TimelineRecord]:
    """
    Extracts timeline path records from semantic segments in the timeline data.

    Args:
        data: Parsed timeline JSON data.
        last_processed: Lower bound timestamp filter.
        stats: Dictionary to accumulate statistics.

    Returns:
        List of timeline path records with datetime, latitude, and longitude.
    """
    records = []
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
    return records


def extract_raw_signals(
    data: Mapping[str, Any], last_processed: Optional[datetime], stats: StatsDict
) -> List[TimelineRecord]:
    """
    Extracts raw signal records from the timeline data.

    Args:
        data: Parsed timeline JSON data.
        last_processed: Lower bound timestamp filter.
        stats: Dictionary to accumulate statistics.

    Returns:
        List of raw signal records with datetime, latitude, longitude, and accuracy.
    """
    records = []
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
                    records.append(
                        {
                            "datetime": dt,
                            "latitude": lat,
                            "longitude": lon,
                            "accuracy": position.get("accuracyMeters"),
                        }
                    )
                else:
                    stats["rawSignals_skipped"] += 1
            else:
                stats["records_invalid_format"] += 1
    return records


def extract_place_visits(
    data: Mapping[str, Any], last_processed: Optional[datetime], stats: StatsDict
) -> List[TimelineRecord]:
    """
    Extracts place visit records from semantic segments in the timeline data.

    Args:
        data: Parsed timeline JSON data.
        last_processed: Lower bound timestamp filter.
        stats: Dictionary to accumulate statistics.

    Returns:
        List of place visit records with datetime, latitude, longitude, and other fields.
    """

    def parse_visit_segment(segment: Mapping[str, Any], key: str) -> Optional[TimelineRecord]:
        """
        Parses a single place visit segment from the timeline data for a given time key.

        Args:
            segment: A semantic segment containing visit information.
            key: The time key to extract, either "startTime" or "endTime".

        Returns:
            A dictionary representing a single place visit record if valid and within the processing window,
            otherwise ``None``.

        Side Effects:
            Updates the 'stats' dictionary with counts for read, skipped, processed, and invalid records.
        """
        stats["placeVisit_read"] += 1

        visit = segment.get("visit")
        if not visit:
            return None

        time = segment.get(key)
        dt = datetime_from_iso(time)
        location = visit.get("topCandidate", {}).get("placeLocation", {})
        lat, lon = extract_lat_lon(location.get("latLng"))

        if not (dt and lat is not None and lon is not None):
            stats["records_invalid_format"] += 1
            return None

        if last_processed and dt < last_processed:
            stats["placeVisit_skipped"] += 1
            return None

        stats["placeVisit_processed"] += 1
        prob = visit.get("topCandidate", {}).get("probability")
        confidence = int(prob * 100) if prob is not None else None

        return {
            "datetime": dt,
            "latitude": lat,
            "longitude": lon,
            "accuracy": None,
            "elevation": None,
            "activity_type": "PLACE_VISIT",
            "confidence": confidence,
        }

    records = []
    for segment in data.get("semanticSegments", []):
        start_record = parse_visit_segment(segment, "startTime")
        if start_record:
            records.append(start_record)
        end_record = parse_visit_segment(segment, "endTime")
        if end_record:
            records.append(end_record)

    return records


def enrich_with_activities(
    records: List[TimelineRecord],
    activity_ranges: Sequence[ActivityRange],
    stats: StatsDict,
) -> None:
    """
    Enriches timeline records with activity type and confidence based on activity ranges.

    Args:
        records: Timeline records to enrich.
        activity_ranges: List of activity ranges with start/end times and activity info.
        stats: Dictionary to accumulate statistics.
    """
    # Enrich records with inferred activity type by matching timestamp to known activity windows.
    # First match wins. If no match, activity remains None.
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


def handle_elevation_enrichment(reprocess_elevation: bool) -> None:
    """
    Handles the process of enriching timeline records with elevation data.

    Args:
        reprocess_elevation: If True, reprocesses all elevation data regardless of control timestamp.
    """
    elevation_stats = {
        "records_considered": 0,
        "records_skipped_due_to_null_elevation": 0,
        "records_updated": 0,
    }
    last_ts = None if reprocess_elevation else get_last_elevation_timestamp()
    records = fetch_records_missing_elevation(last_ts)
    latest_ts = update_elevations(records, elevation_stats)
    if latest_ts:
        update_last_elevation_timestamp(latest_ts)
        plog.log_info(
            logger, f"🕒 Elevation last processed timestamp updated to {latest_ts.isoformat()}"
        )

    print("\n📊 Elevation Processing Summary:")
    for k, v in elevation_stats.items():
        print(f"{k}: {v}")


def print_summary(stats: Mapping[str, int]) -> None:
    """
    Prints a summary of processing statistics.

    Args:
        stats: Dictionary containing statistics to print.
    """
    print("\n📊 Summary:")
    for k, v in stats.items():
        print(f"{k}: {v}")


def run_vacuum_analyze_if_supported() -> None:
    """
    Executes VACUUM ANALYZE on the timeline.locations table if the PostgreSQL version supports the MAINTAIN privilege.

    This function connects to the database with autocommit enabled to ensure VACUUM can run outside a transaction.

    Returns:
        None
    """
    try:
        conn = psycopg2.connect(**DB_PARAMS)
        conn.autocommit = True  # Must be set immediately
        with conn.cursor() as cur:
            cur.execute("SHOW server_version;")
            version_str = cur.fetchone()[0]
            major_version = int(version_str.split(".")[0])

            if major_version >= 15:
                plog.log_info(logger, "⚙️  Running VACUUM ANALYZE on timeline.locations...")
                cur.execute("VACUUM ANALYZE timeline.locations;")
            else:
                plog.log_warning(
                    f"⚠️  VACUUM ANALYZE skipped: PostgreSQL version {version_str} does not support MAINTAIN privilege."
                )
        conn.close()
    except Exception as e:
        plog.log_error(logger, f"❌ Could not run VACUUM ANALYZE: {e}")


def main(input_file: str, reprocess: bool, reprocess_elevation: bool) -> None:
    """
    Main entry point for processing Google Maps Timeline data.

    This function orchestrates the following:
    - Loads the input JSON file.
    - Applies last processed timestamp filtering unless overridden.
    - Extracts and parses GPS points, raw signals, and place visits.
    - Enriches records with activity type.
    - Inserts deduplicated and enriched records into the database.
    - Optionally enriches elevation data using SRTM.
    - Runs a VACUUM ANALYZE if supported by the PostgreSQL version.

    Args:
        input_file: Path to the Google Timeline JSON file.
        reprocess: If True, bypasses last processed timestamp filtering.
        reprocess_elevation: If True, reprocesses elevation data regardless of control timestamp.
    """
    # Logger already initialized at module level
    stats = initialize_stats()
    last_processed = None if reprocess else get_last_processed_timestamp()
    print_start_message(last_processed, reprocess)

    data = load_json(input_file)
    if data is None:
        return

    activity_ranges = extract_activity_ranges(data, last_processed, stats)

    # Merge all record types from the data
    records = (
        extract_timeline_path(data, last_processed, stats)
        + extract_raw_signals(data, last_processed, stats)
        + extract_place_visits(data, last_processed, stats)
    )

    enrich_with_activities(records, activity_ranges, stats)
    insert_records_into_postgres(records, stats)
    handle_elevation_enrichment(reprocess_elevation)
    run_vacuum_analyze_if_supported()
    print_summary(stats)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract and enrich Google Maps Timeline data.")
    parser.add_argument(
        "--input_file",
        default="G:\\My Drive\\Google Maps Timeline\\Timeline.json",
        help="Path to the JSON timeline file (default: G:\\My Drive\\Google Maps Timeline\\Timeline.json)",
    )
    parser.add_argument(
        "--reprocess",
        action="store_true",
        help="Reprocess all records regardless of last processed timestamp",
    )
    parser.add_argument(
        "--reprocess-elevation",
        action="store_true",
        help="Force reprocessing of all elevation values regardless of control timestamp",
    )
    args = parser.parse_args()
    main(args.input_file, args.reprocess, args.reprocess_elevation)
