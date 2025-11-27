"""
Unit tests for verifying logger initialization in Python modules.

These tests verify that all modules using the python_logging_framework
properly initialize their logger at the module level, ensuring no
AttributeError occurs when modules are used standalone.

Related to Issue #511: Fix Logger Initialization in Python Modules
"""

import pytest
import logging
import sys
from pathlib import Path

# Add src path to allow imports
src_python = Path(__file__).resolve().parents[3] / "src" / "python"
if str(src_python) not in sys.path:
    sys.path.insert(0, str(src_python))

# Add modules path
modules_path = src_python / "modules"
if str(modules_path) not in sys.path:
    sys.path.insert(0, str(modules_path))


class TestModuleLoggerInitialization:
    """Tests to verify logger initialization in all Python modules."""

    def test_google_drive_auth_has_logger(self):
        """Verify google_drive_auth module initializes logger."""
        from modules.auth import google_drive_auth

        assert hasattr(google_drive_auth, 'logger'), "google_drive_auth module missing logger attribute"
        assert isinstance(google_drive_auth.logger, logging.Logger), "logger is not a Logger instance"
        assert google_drive_auth.logger.name == '__main__' or 'google_drive_auth' in google_drive_auth.logger.name

    def test_elevation_has_logger(self):
        """Verify elevation module initializes logger."""
        from modules.auth import elevation

        assert hasattr(elevation, 'logger'), "elevation module missing logger attribute"
        assert isinstance(elevation.logger, logging.Logger), "logger is not a Logger instance"
        assert elevation.logger.name == '__main__' or 'elevation' in elevation.logger.name

    def test_cloudconvert_utils_has_logger(self):
        """Verify cloudconvert_utils module initializes logger."""
        sys.path.insert(0, str(src_python / "cloud"))
        from cloud import cloudconvert_utils

        assert hasattr(cloudconvert_utils, 'logger'), "cloudconvert_utils module missing logger attribute"
        assert isinstance(cloudconvert_utils.logger, logging.Logger), "logger is not a Logger instance"
        assert cloudconvert_utils.logger.name == '__main__' or 'cloudconvert_utils' in cloudconvert_utils.logger.name

    def test_drive_space_monitor_has_logger(self):
        """Verify drive_space_monitor module initializes logger."""
        sys.path.insert(0, str(src_python / "cloud"))
        from cloud import drive_space_monitor

        assert hasattr(drive_space_monitor, 'logger'), "drive_space_monitor module missing logger attribute"
        assert isinstance(drive_space_monitor.logger, logging.Logger), "logger is not a Logger instance"
        assert drive_space_monitor.logger.name == '__main__' or 'drive_space_monitor' in drive_space_monitor.logger.name

    def test_google_drive_root_files_delete_has_logger(self):
        """Verify google_drive_root_files_delete module initializes logger."""
        sys.path.insert(0, str(src_python / "cloud"))
        from cloud import google_drive_root_files_delete

        assert hasattr(google_drive_root_files_delete, 'logger'), "google_drive_root_files_delete module missing logger attribute"
        assert isinstance(google_drive_root_files_delete.logger, logging.Logger), "logger is not a Logger instance"
        assert google_drive_root_files_delete.logger.name == '__main__' or 'google_drive_root_files_delete' in google_drive_root_files_delete.logger.name

    def test_csv_to_gpx_has_logger(self):
        """Verify csv_to_gpx module initializes logger."""
        sys.path.insert(0, str(src_python / "data"))
        from data import csv_to_gpx

        assert hasattr(csv_to_gpx, 'logger'), "csv_to_gpx module missing logger attribute"
        assert isinstance(csv_to_gpx.logger, logging.Logger), "logger is not a Logger instance"
        assert csv_to_gpx.logger.name == '__main__' or 'csv_to_gpx' in csv_to_gpx.logger.name

    def test_extract_timeline_locations_has_logger(self):
        """Verify extract_timeline_locations module initializes logger."""
        sys.path.insert(0, str(src_python / "data"))
        from data import extract_timeline_locations

        assert hasattr(extract_timeline_locations, 'logger'), "extract_timeline_locations module missing logger attribute"
        assert isinstance(extract_timeline_locations.logger, logging.Logger), "logger is not a Logger instance"
        assert extract_timeline_locations.logger.name == '__main__' or 'extract_timeline_locations' in extract_timeline_locations.logger.name

    def test_seat_assignment_has_logger(self):
        """Verify seat_assignment module initializes logger."""
        sys.path.insert(0, str(src_python / "data"))
        from data import seat_assignment

        assert hasattr(seat_assignment, 'logger'), "seat_assignment module missing logger attribute"
        assert isinstance(seat_assignment.logger, logging.Logger), "logger is not a Logger instance"
        assert seat_assignment.logger.name == '__main__' or 'seat_assignment' in seat_assignment.logger.name

    def test_find_duplicate_images_has_logger(self):
        """Verify find_duplicate_images module initializes logger."""
        sys.path.insert(0, str(src_python / "media"))
        from media import find_duplicate_images

        assert hasattr(find_duplicate_images, 'logger'), "find_duplicate_images module missing logger attribute"
        assert isinstance(find_duplicate_images.logger, logging.Logger), "logger is not a Logger instance"
        assert find_duplicate_images.logger.name == '__main__' or 'find_duplicate_images' in find_duplicate_images.logger.name

    def test_recover_extensions_has_logger(self):
        """Verify recover_extensions module initializes logger."""
        sys.path.insert(0, str(src_python / "media"))
        from media import recover_extensions

        assert hasattr(recover_extensions, 'logger'), "recover_extensions module missing logger attribute"
        assert isinstance(recover_extensions.logger, logging.Logger), "logger is not a Logger instance"
        assert recover_extensions.logger.name == '__main__' or 'recover_extensions' in recover_extensions.logger.name


class TestLoggerFunctionality:
    """Tests to verify that loggers work correctly without external initialization."""

    def test_module_can_log_without_external_init(self):
        """Verify modules can log without external initialization."""
        from modules.auth import google_drive_auth

        # This should not raise AttributeError
        try:
            assert google_drive_auth.logger is not None
            # Verify logger is callable (has logging methods)
            assert hasattr(google_drive_auth.logger, 'info')
            assert hasattr(google_drive_auth.logger, 'warning')
            assert hasattr(google_drive_auth.logger, 'error')
            assert hasattr(google_drive_auth.logger, 'debug')
        except AttributeError as e:
            pytest.fail(f"Module logger not properly initialized: {e}")

    def test_logger_has_handlers(self):
        """Verify that initialized loggers have handlers attached."""
        from modules.auth import google_drive_auth

        # Logger should have at least one handler
        assert len(google_drive_auth.logger.handlers) > 0, "Logger has no handlers"
