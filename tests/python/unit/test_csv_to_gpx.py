"""
Unit tests for src/python/data/csv_to_gpx.py.

Tests data transformation logic for converting CSV location data to GPX format.
Uses mocking for external dependencies like elevation service and file I/O.
"""

import csv
import sys
import tempfile
from pathlib import Path

import pytest

# Add src paths to allow imports
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "src" / "python" / "data"))
sys.path.insert(
    0, str(Path(__file__).resolve().parents[3] / "src" / "python" / "modules" / "logging")
)
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "src" / "python" / "modules" / "auth"))

from csv_to_gpx import csv_to_gpx


class TestCsvToGpxModule:
    """Tests for csv_to_gpx module."""

    def setup_method(self):
        """Set up test fixtures."""
        self.sample_csv_data = [
            {"lat": "40.7128", "lng": "-74.0060", "time": "2024-01-01T12:00:00Z"},
            {"lat": "40.7580", "lng": "-73.9855", "time": "2024-01-01T13:00:00Z"},
            {"lat": "40.7489", "lng": "-73.9680", "time": "2024-01-01T14:00:00Z"},
        ]

    def test_csv_file_structure(self):
        """Test that we can create a proper CSV structure for testing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            csv_file = Path(tmpdir) / "test.csv"
            with open(csv_file, "w", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=["lat", "lng", "time"])
                writer.writeheader()
                writer.writerows(self.sample_csv_data)

            # Verify CSV file was created and has correct structure
            assert csv_file.exists()

            with open(csv_file, "r") as f:
                reader = csv.DictReader(f)
                rows = list(reader)
                assert len(rows) == 3
                assert "lat" in rows[0]
                assert "lng" in rows[0]
                assert "time" in rows[0]


def test_csv_to_gpx_conversion(tmp_path):
    """Test basic CSV to GPX conversion."""

    csv_file = tmp_path / "test.csv"
    csv_file.write_text(
        """lat,lng,time
37.7749,-122.4194,2024-01-01T12:00:00Z
37.7750,-122.4195,2024-01-01T12:01:00Z
"""
    )

    gpx_file = tmp_path / "output.gpx"

    # Convert
    csv_to_gpx(str(csv_file), str(gpx_file))

    # Verify GPX structure
    assert gpx_file.exists()
    content = gpx_file.read_text()
    assert "<gpx" in content
    assert '<trkpt lat="37.7749" lon="-122.4194">' in content


def test_csv_to_gpx_with_elevation(tmp_path, mocker):
    """Test elevation data is included."""

    mocker.patch("csv_to_gpx.get_elevation", return_value=100.5)

    csv_file = tmp_path / "test.csv"
    csv_file.write_text("lat,lng,time\n37.7749,-122.4194,2024-01-01T12:00:00Z")
    gpx_file = tmp_path / "output.gpx"

    csv_to_gpx(str(csv_file), str(gpx_file))

    content = gpx_file.read_text()
    assert "<ele>100.50</ele>" in content


def test_csv_to_gpx_handles_invalid_csv(tmp_path):
    """Test error handling for invalid CSV."""

    csv_file = tmp_path / "invalid.csv"
    csv_file.write_text("not,valid,csv\ndata")
    gpx_file = tmp_path / "output.gpx"

    with pytest.raises(KeyError):  # Missing required columns
        csv_to_gpx(str(csv_file), str(gpx_file))


def test_csv_to_gpx_with_empty_rows(tmp_path, mocker):
    """Ensure empty CSV rows do not break conversion."""

    mocker.patch("elevation.get_elevation", return_value=None)
    csv_file = tmp_path / "empty.csv"
    csv_file.write_text("lat,lng,time\n")
    gpx_file = tmp_path / "output.gpx"

    csv_to_gpx(str(csv_file), str(gpx_file))

    content = gpx_file.read_text()
    # GPX still created with basic structure
    assert "<gpx" in content
