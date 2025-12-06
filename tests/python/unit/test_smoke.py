"""Smoke tests to ensure main scripts import without errors."""

from importlib import import_module
from pathlib import Path
import sys

import pytest

# Ensure repository root is on the import path for namespace package imports
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SCRIPTS = [
    "src.python.cloud.google_drive_root_files_delete",
    "src.python.cloud.cloudconvert_utils",
    "src.python.cloud.gdrive_recover",
    "src.python.cloud.drive_space_monitor",
    "src.python.data.csv_to_gpx",
    "src.python.data.validators",
    "src.python.data.extract_timeline_locations",
    "src.python.data.seat_assignment",
    "src.python.media.find_duplicate_images",
    "src.python.media.crop_colours",
    "src.python.media.recover_extensions",
]


@pytest.mark.parametrize("module_name", SCRIPTS)
def test_script_imports(module_name):
    """Verify script can be imported without errors."""
    try:
        import_module(module_name)
    except ImportError as exc:
        pytest.fail(f"Failed to import {module_name}: {exc}")
