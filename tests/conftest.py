"""
Pytest configuration file for My-Scripts test suite.

This file contains shared fixtures and configuration for all tests.
"""

import pytest
import os
import sys
from pathlib import Path

# Add the project root to the Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


@pytest.fixture
def project_root_dir():
    """Return the project root directory path."""
    return Path(__file__).parent.parent


@pytest.fixture
def test_data_dir():
    """Return the test fixtures directory path."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def temp_test_dir(tmp_path):
    """Provide a temporary directory for test operations."""
    return tmp_path
