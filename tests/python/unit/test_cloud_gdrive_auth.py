import sys
import types
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# Ensure the cloud module path is importable
cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

import gdrive_auth


class DummyArgs:
    pass


def _patch_google_auth_transport_requests(monkeypatch, authorized_session_cls):
    """Helper to patch google.auth.transport.requests.AuthorizedSession."""
    google_mod = types.ModuleType("google")
    auth_mod = types.ModuleType("google.auth")
    transport_mod = types.ModuleType("google.auth.transport")
    req_mod = types.ModuleType("google.auth.transport.requests")
    req_mod.AuthorizedSession = authorized_session_cls

    for name, module in (
        ("google", google_mod),
        ("google.auth", auth_mod),
        ("google.auth.transport", transport_mod),
        ("google.auth.transport.requests", req_mod),
    ):
        monkeypatch.setitem(sys.modules, name, module)


def test_build_http_mounts_https_only(monkeypatch):
    manager = gdrive_auth.DriveAuthManager(DummyArgs(), logger=MagicMock(), execute_fn=lambda x: x)
    manager._http_transport = "requests"
    manager._http_pool_maxsize = 5

    mounted = {}

    class FakeSession:
        def __init__(self, creds):
            self.creds = creds

        def mount(self, prefix, adapter):
            mounted[prefix] = adapter

        def request(self, method, uri, data=None, headers=None, timeout=None, **kwargs):
            response = MagicMock()
            response.status_code = 200
            response.headers = {"content-type": "application/json"}
            response.reason = "OK"
            response.content = b"test"
            return response

    class FakeAdapter:
        pass

    _patch_google_auth_transport_requests(monkeypatch, FakeSession)

    monkeypatch.setattr(
        "requests.adapters.HTTPAdapter", lambda pool_connections, pool_maxsize: FakeAdapter()
    )

    http_adapter = manager._build_http(creds=MagicMock())

    assert isinstance(http_adapter, gdrive_auth.DriveAuthManager._RequestsHttpAdapter)
    assert "https://" in mounted
    assert "http://" not in mounted


def test_requests_http_adapter_request_returns_formatted_response():
    class FakeSession:
        def request(self, method, uri, data=None, headers=None, timeout=None, **kwargs):
            resp = MagicMock()
            resp.status_code = 200
            resp.headers = {"a": "b"}
            resp.reason = "OK"
            resp.content = b"payload"
            return resp

    adapter = gdrive_auth.DriveAuthManager._RequestsHttpAdapter(FakeSession())
    resp, content = adapter.request(
        "https://example.com", method="GET", body=b"", headers={"X": "1"}, timeout=30
    )

    assert resp.status == 200
    assert "a" in resp
    assert content == b"payload"


def test_get_service_builds_service_with_http_when_configured(monkeypatch):
    manager = gdrive_auth.DriveAuthManager(DummyArgs(), logger=MagicMock(), execute_fn=lambda x: x)
    manager._authenticated = True
    manager._client_per_thread = True
    manager._creds = MagicMock()

    def fake_build(service_name, version, credentials=None, http=None):
        return {
            "service_name": service_name,
            "version": version,
            "credentials": credentials,
            "http": http,
        }

    monkeypatch.setattr(gdrive_auth, "build", fake_build)
    monkeypatch.setattr(manager, "_build_http", lambda creds: "dummy_http")

    svc = manager._get_service()

    assert svc["service_name"] == "drive"
    assert svc["version"] == "v3"
    assert svc["credentials"] is None
    assert svc["http"] == "dummy_http"
    assert manager._thread_local.service == svc
