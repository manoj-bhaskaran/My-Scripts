"""
Unit tests for Google Drive authentication path configuration.

Tests the path resolution logic for token and credentials files,
ensuring they can be configured via environment variables or use
sensible defaults.
"""

import os
import sys
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src" / "python"))


class TestPathConfiguration:
    """Test credential path configuration."""

    def test_token_path_from_environment(self):
        """Test token path is read from environment variable."""
        with patch.dict(os.environ, {"GDRIVE_TOKEN_PATH": "/custom/token.json"}, clear=False):
            # Reload module to pick up new environment
            import importlib
            from modules.auth import google_drive_auth

            importlib.reload(google_drive_auth)
            assert google_drive_auth.TOKEN_FILE == "/custom/token.json"

    def test_token_path_default(self):
        """Test token path defaults to user's Documents/Scripts."""
        # Remove the environment variable if it exists
        env_copy = os.environ.copy()
        env_copy.pop("GDRIVE_TOKEN_PATH", None)
        env_copy.pop("GDRIVE_CREDENTIALS_PATH", None)

        with patch.dict(os.environ, env_copy, clear=True):
            import importlib
            from modules.auth import google_drive_auth

            importlib.reload(google_drive_auth)
            expected = str(Path.home() / "Documents" / "Scripts" / "drive_token.json")
            assert google_drive_auth.TOKEN_FILE == expected

    def test_credentials_path_from_environment(self):
        """Test credentials path is read from environment variable."""
        with patch.dict(os.environ, {"GDRIVE_CREDENTIALS_PATH": "/custom/creds.json"}, clear=False):
            import importlib
            from modules.auth import google_drive_auth

            importlib.reload(google_drive_auth)
            assert google_drive_auth.CREDENTIALS_FILE == "/custom/creds.json"

    def test_credentials_path_default(self):
        """Test credentials path defaults to user's Documents/Scripts."""
        # Remove the environment variable if it exists
        env_copy = os.environ.copy()
        env_copy.pop("GDRIVE_TOKEN_PATH", None)
        env_copy.pop("GDRIVE_CREDENTIALS_PATH", None)

        with patch.dict(os.environ, env_copy, clear=True):
            import importlib
            from modules.auth import google_drive_auth

            importlib.reload(google_drive_auth)
            expected = str(Path.home() / "Documents" / "Scripts" / "credentials.json")
            assert google_drive_auth.CREDENTIALS_FILE == expected

    def test_validate_credentials_missing_file(self):
        """Test validation fails when credentials file is missing."""
        from modules.auth import google_drive_auth

        with patch.dict(
            os.environ, {"GDRIVE_CREDENTIALS_PATH": "/nonexistent/creds.json"}, clear=False
        ):
            import importlib

            importlib.reload(google_drive_auth)

            with pytest.raises(FileNotFoundError) as exc_info:
                google_drive_auth.validate_credentials()
            assert "credentials file not found" in str(exc_info.value).lower()
            assert "/nonexistent/creds.json" in str(exc_info.value)

    def test_validate_credentials_success(self, tmp_path):
        """Test validation succeeds when credentials file exists."""
        from modules.auth import google_drive_auth

        # Create temporary credentials file
        creds_file = tmp_path / "credentials.json"
        creds_file.write_text('{"test": "data"}')

        with patch.dict(os.environ, {"GDRIVE_CREDENTIALS_PATH": str(creds_file)}, clear=False):
            import importlib

            importlib.reload(google_drive_auth)
            assert google_drive_auth.validate_credentials() is True

    def test_helper_functions_return_strings(self):
        """Test that helper functions return string paths, not Path objects."""
        from modules.auth import google_drive_auth

        # Test with environment variables
        with patch.dict(
            os.environ,
            {
                "GDRIVE_TOKEN_PATH": "/test/token.json",
                "GDRIVE_CREDENTIALS_PATH": "/test/creds.json",
            },
            clear=False,
        ):
            import importlib

            importlib.reload(google_drive_auth)

            assert isinstance(google_drive_auth._get_token_file(), str)
            assert isinstance(google_drive_auth._get_credentials_file(), str)

        # Test with defaults (which use Path.home())
        env_copy = os.environ.copy()
        env_copy.pop("GDRIVE_TOKEN_PATH", None)
        env_copy.pop("GDRIVE_CREDENTIALS_PATH", None)

        with patch.dict(os.environ, env_copy, clear=True):
            importlib.reload(google_drive_auth)

            assert isinstance(google_drive_auth._get_token_file(), str)
            assert isinstance(google_drive_auth._get_credentials_file(), str)

    def test_credentials_file_contains_helpful_error_message(self):
        """Test that error message contains helpful information."""
        from modules.auth import google_drive_auth

        with patch.dict(os.environ, {"GDRIVE_CREDENTIALS_PATH": "/missing/file.json"}, clear=False):
            import importlib

            importlib.reload(google_drive_auth)

            with pytest.raises(FileNotFoundError) as exc_info:
                google_drive_auth.validate_credentials()

            error_msg = str(exc_info.value)
            # Should mention the actual path that was checked
            assert "/missing/file.json" in error_msg
            # Should mention the environment variable
            assert "GDRIVE_CREDENTIALS_PATH" in error_msg
            # Should mention the default location
            assert str(Path.home() / "Documents" / "Scripts") in error_msg
