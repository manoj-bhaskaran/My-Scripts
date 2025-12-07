"""
Unit tests for src/python/data/extract_timeline_locations.py.

Focuses on pure data parsing and enrichment helpers to validate transformation logic
without relying on a live PostgreSQL instance.
"""

import json
import sys
from pathlib import Path

import pytest

# Add src paths to allow imports
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "src" / "python" / "data"))
sys.path.insert(
    0, str(Path(__file__).resolve().parents[3] / "src" / "python" / "modules" / "logging")
)

from extract_timeline_locations import (
    count_optional_fields,
    datetime_from_iso,
    extract_activity_ranges,
    extract_lat_lon,
    extract_place_visits,
    extract_raw_signals,
    extract_timeline_path,
    enrich_with_activities,
    initialize_stats,
    load_json,
)


def test_extract_lat_lon_parses_values():
    """Latitude/longitude parser handles valid and invalid inputs."""

    assert extract_lat_lon("12.34°, 56.78°") == (12.34, 56.78)
    assert extract_lat_lon("invalid") == (None, None)
    assert extract_lat_lon(None) == (None, None)


def test_datetime_from_iso_handles_invalid():
    """Timestamp parser returns None on invalid input."""

    assert datetime_from_iso("2024-01-01T12:00:00") is not None
    assert datetime_from_iso("not-a-date") is None
    assert datetime_from_iso(None) is None


def test_extract_activity_ranges_filters_and_counts():
    """Activity ranges are filtered by last_processed and counted."""

    stats = initialize_stats()
    last_processed = datetime_from_iso("2024-01-01T12:00:00")
    data = {
        "semanticSegments": [
            {
                "startTime": "2024-01-01T12:05:00",
                "endTime": "2024-01-01T12:06:00",
                "activity": {"topCandidate": {"type": "WALKING", "probability": 0.9}},
            },
            {
                "startTime": "2023-12-31T23:59:00",
                "endTime": "2023-12-31T23:59:30",
                "activity": {"topCandidate": {"type": "RUNNING", "probability": 0.5}},
            },
        ]
    }

    ranges = extract_activity_ranges(data, last_processed, stats)

    assert len(ranges) == 1
    assert ranges[0]["activity_type"] == "WALKING"
    assert stats["activity_ranges_total"] == 1


def test_extract_timeline_path_counts_and_validates():
    """Timeline path extraction updates stats for processed, skipped, and invalid entries."""

    stats = initialize_stats()
    last_processed = datetime_from_iso("2024-01-01T12:10:00")
    data = {
        "semanticSegments": [
            {
                "timelinePath": [
                    {"time": "2024-01-01T12:15:00", "point": "12.0°, 34.0°"},
                    {"time": "2024-01-01T12:00:00", "point": "bad"},
                ]
            }
        ]
    }

    records = extract_timeline_path(data, last_processed, stats)

    assert len(records) == 1
    assert stats["timelinePath_read"] == 2
    assert stats["timelinePath_processed"] == 1
    assert stats["timelinePath_skipped"] == 0
    assert stats["records_invalid_format"] == 1


def test_extract_raw_signals_handles_formats():
    """Raw signal extraction validates structure and timestamps."""

    stats = initialize_stats()
    last_processed = datetime_from_iso("2024-01-01T12:10:00")
    data = {
        "rawSignals": [
            {
                "position": {
                    "timestamp": "2024-01-01T12:15:00",
                    "LatLng": "10.0°, 20.0°",
                    "accuracyMeters": 5,
                }
            },
            {"position": {"timestamp": "bad", "LatLng": ""}},
        ]
    }

    records = extract_raw_signals(data, last_processed, stats)

    assert len(records) == 1
    assert stats["rawSignals_read"] == 2
    assert stats["rawSignals_processed"] == 1
    assert stats["records_invalid_format"] == 1


def test_extract_place_visits_tracks_processed_and_skipped():
    """Place visit extraction creates start/end records and counts invalid entries."""

    stats = initialize_stats()
    last_processed = datetime_from_iso("2024-01-01T12:00:00")
    data = {
        "semanticSegments": [
            {
                "startTime": "2024-01-01T12:10:00",
                "endTime": "2024-01-01T12:20:00",
                "visit": {
                    "topCandidate": {
                        "placeLocation": {"latLng": "50.0°, 8.0°"},
                        "probability": 0.75,
                    }
                },
            },
            {
                "startTime": "2023-12-31T23:00:00",
                "endTime": "2023-12-31T23:05:00",
                "visit": {"topCandidate": {"placeLocation": {"latLng": "49.0°, 8.5°"}}},
            },
            {
                "startTime": "2024-01-01T12:30:00",
                "endTime": "2024-01-01T12:35:00",
                "visit": {"topCandidate": {"placeLocation": {"latLng": "invalid"}}},
            },
        ]
    }

    visits = extract_place_visits(data, last_processed, stats)

    # First segment yields two processed visits; second is skipped due to timestamp; third invalid location
    assert len(visits) == 2
    assert stats["placeVisit_read"] == 6  # start and end for each segment
    assert stats["placeVisit_processed"] == 2
    assert stats["placeVisit_skipped"] == 2
    assert stats["records_invalid_format"] >= 1


def test_enrich_with_activities_matches_ranges():
    """Activity enrichment applies first matching window and counts misses."""

    stats = initialize_stats()
    records = [
        {"datetime": datetime_from_iso("2024-01-01T12:10:00"), "latitude": 1, "longitude": 1},
        {"datetime": datetime_from_iso("2024-01-01T13:00:00"), "latitude": 1, "longitude": 1},
    ]
    activity_ranges = [
        {
            "start_time": datetime_from_iso("2024-01-01T12:00:00"),
            "end_time": datetime_from_iso("2024-01-01T12:30:00"),
            "activity_type": "WALKING",
            "confidence": 80,
        }
    ]

    enrich_with_activities(records, activity_ranges, stats)

    assert records[0]["activity_type"] == "WALKING"
    assert records[0]["confidence"] == 80
    assert "activity_type" not in records[1]
    assert stats["records_enriched"] == 1
    assert stats["records_not_enriched_due_to_no_match"] == 1


def test_count_optional_fields_supports_partial_data():
    """Optional field counter only counts populated metadata."""

    rec = {"accuracy": 5, "elevation": None, "activity_type": "RUN", "confidence": None}
    assert count_optional_fields(rec) == 2


def test_load_json_success_and_failure(tmp_path, monkeypatch):
    """load_json returns data on success and None on file/parse errors."""

    # Successful load with missing keys triggers warnings
    mock_warns = []
    mock_errors = []
    monkeypatch.setattr(
        "extract_timeline_locations.plog.log_warning",
        lambda *args, **kwargs: mock_warns.append(args),
    )
    monkeypatch.setattr(
        "extract_timeline_locations.plog.log_error",
        lambda *args, **kwargs: mock_errors.append(args),
    )

    payload = {"semanticSegments": []}
    json_file = tmp_path / "timeline.json"
    json_file.write_text(json.dumps(payload))

    loaded = load_json(str(json_file))
    assert loaded == payload
    assert mock_warns  # 'rawSignals' missing

    # Invalid JSON path triggers error handling
    invalid_file = tmp_path / "missing.json"
    assert load_json(str(invalid_file)) is None
    assert mock_errors

    # Malformed JSON triggers decode error path
    bad_json = tmp_path / "bad.json"
    bad_json.write_text("{")
    assert load_json(str(bad_json)) is None
    assert len(mock_errors) >= 2
