"""
Pytest configuration and shared fixtures for Python tests.

This file provides common fixtures and configuration for all Python tests
in the My-Scripts repository.
"""

import pytest
import sys
from pathlib import Path

# Add src directories to Python path for imports
src_python = Path(__file__).resolve().parents[2] / "src" / "python"
src_common = Path(__file__).resolve().parents[2] / "src" / "common"

sys.path.insert(0, str(src_python))
sys.path.insert(0, str(src_common))


@pytest.fixture
def sample_mime_map():
    """Provide a sample MIME type mapping for extension validation tests."""
    return {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "pdf": "application/pdf",
        "txt": "text/plain",
        "csv": "text/csv",
        "json": "application/json",
        "xml": "application/xml",
        "zip": "application/zip",
        "tar": "application/x-tar",
        "gz": "application/gzip",
    }


@pytest.fixture
def sample_policy_aliases():
    """Provide sample policy aliases for policy normalization tests."""
    return {
        "retain": "retain",
        "keep": "retain",
        "trash": "trash",
        "recycle": "trash",
        "delete": "delete",
        "remove": "delete",
    }


@pytest.fixture
def temp_csv_data():
    """Provide sample CSV data for GPX conversion tests."""
    return [
        {"lat": "40.7128", "lng": "-74.0060", "time": "2024-01-01T12:00:00Z"},
        {"lat": "40.7580", "lng": "-73.9855", "time": "2024-01-01T13:00:00Z"},
        {"lat": "40.7489", "lng": "-73.9680", "time": "2024-01-01T14:00:00Z"},
    ]


# Pytest hooks for custom behavior
def pytest_configure(config):
    """Configure pytest with custom settings."""
    config.addinivalue_line(
        "markers", "unit: mark test as a unit test"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as an integration test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers", "mock: mark test as using mocking"
    )


def pytest_collection_modifyitems(config, items):
    """Modify test items during collection."""
    # Auto-mark all tests in unit/ directories as unit tests
    for item in items:
        if "unit" in str(item.fspath):
            item.add_marker(pytest.mark.unit)
