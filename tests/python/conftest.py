"""
Pytest configuration and shared fixtures for Python tests.

This file provides common fixtures and configuration for all Python tests
in the My-Scripts repository.
"""

import pytest
import sys
from importlib import import_module
from pathlib import Path
from types import ModuleType, SimpleNamespace

# Add src directories to Python path for imports
repo_root = Path(__file__).resolve().parents[2]
src_python_data = repo_root / "src" / "python" / "data"
src_python_cloud = repo_root / "src" / "python" / "cloud"
src_python_media = repo_root / "src" / "python" / "media"
src_python_modules_logging = repo_root / "src" / "python" / "modules" / "logging"
src_python_modules_auth = repo_root / "src" / "python" / "modules" / "auth"

sys.path.insert(0, str(src_python_data))
sys.path.insert(0, str(src_python_cloud))
sys.path.insert(0, str(src_python_media))
sys.path.insert(0, str(src_python_modules_logging))
sys.path.insert(0, str(src_python_modules_auth))


def _ensure_dependency(name: str, fallback_factory) -> None:
    """Import a dependency or register a lightweight stub if unavailable."""

    if name in sys.modules:
        return

    try:
        import_module(name)
    except Exception:
        sys.modules[name] = fallback_factory()


_ensure_dependency(
    "srtm",
    lambda: type(
        "_SrtmStub",
        (),
        {
            "get_data": staticmethod(
                lambda: SimpleNamespace(
                    get_elevation=lambda *_args, **_kwargs: 0,
                )
            )
        },
    )(),
)

_ensure_dependency("cv2", lambda: ModuleType("cv2"))
_ensure_dependency("numpy", lambda: ModuleType("numpy"))
_ensure_dependency(
    "googleapiclient",
    lambda: (
        lambda:
        # Build a minimal stub hierarchy for googleapiclient and friends
        (
            lambda _root: (
                _root,
                sys.modules.update(
                    {
                        "googleapiclient.errors": _root.errors,
                        "googleapiclient.discovery": _root.discovery,
                        "googleapiclient.http": _root.http,
                    }
                ),
                sys.modules.setdefault("googleapiclient.errors", _root.errors),
                sys.modules.setdefault("googleapiclient.discovery", _root.discovery),
                sys.modules.setdefault("googleapiclient.http", _root.http),
            )[0]
        )(
            type(
                "_GoogleApiClientStub",
                (),
                {
                    "errors": (
                        lambda: (
                            lambda _module: (
                                setattr(
                                    _module,
                                    "HttpError",
                                    type(
                                        "HttpError",
                                        (Exception,),
                                        {
                                            "__init__": lambda self, resp=None, content=b"", *_, **__: (
                                                setattr(self, "resp", resp),
                                                setattr(self, "content", content),
                                                Exception.__init__(self, content),
                                            )
                                        },
                                    ),
                                ),
                                _module,
                            )[1]
                        )()(ModuleType("googleapiclient.errors"))
                    ),
                    "discovery": (
                        lambda: (
                            lambda _module: (
                                setattr(
                                    _module,
                                    "build",
                                    lambda *_args, **_kwargs: SimpleNamespace(files=lambda: SimpleNamespace()),
                                ),
                                _module,
                            )[1]
                        )()(ModuleType("googleapiclient.discovery"))
                    ),
                    "http": (
                        lambda: (
                            lambda _module: (
                                setattr(
                                    _module,
                                    "MediaIoBaseDownload",
                                    type(
                                        "MediaIoBaseDownload",
                                        (),
                                        {
                                            "__init__": lambda self, *_, **__: None,
                                            "next_chunk": lambda self: (None, True),
                                        },
                                    ),
                                ),
                                _module,
                            )[1]
                        )()(ModuleType("googleapiclient.http"))
                    ),
                },
            )()
        )
    )(),
)
_ensure_dependency(
    "google_auth_oauthlib.flow",
    lambda: (
        lambda _module: (
            setattr(
                _module,
                "InstalledAppFlow",
                type(
                    "InstalledAppFlow",
                    (),
                    {
                        "from_client_secrets_file": staticmethod(
                            lambda *_args, **_kwargs: SimpleNamespace(run_local_server=lambda **__kwargs: None)
                        )
                    },
                ),
            ),
            _module,
        )[1]
    )(ModuleType("google_auth_oauthlib.flow")),
)
_ensure_dependency(
    "google.auth.transport.requests",
    lambda: (
        lambda _module: (setattr(_module, "Request", type("Request", (), {})), _module)[1]
    )(ModuleType("google.auth.transport.requests")),
)
_ensure_dependency(
    "google.oauth2.credentials",
    lambda: (
        lambda _module: (setattr(_module, "Credentials", type("Credentials", (), {})), _module)[1]
    )(ModuleType("google.oauth2.credentials")),
)
_ensure_dependency(
    "google.auth.credentials",
    lambda: (
        lambda _module: (setattr(_module, "Credentials", type("Credentials", (), {})), _module)[1]
    )(ModuleType("google.auth.credentials")),
)


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
    config.addinivalue_line("markers", "unit: mark test as a unit test")
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")
    config.addinivalue_line("markers", "mock: mark test as using mocking")


def pytest_collection_modifyitems(config, items):
    """Modify test items during collection."""
    # Auto-mark all tests in unit/ directories as unit tests
    for item in items:
        if "unit" in str(item.fspath):
            item.add_marker(pytest.mark.unit)
