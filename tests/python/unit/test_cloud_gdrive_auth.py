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


def test_build_http_prints_fallback_once_per_manager(monkeypatch, capsys):
    class FailingSession:
        def __init__(self, creds):
            raise RuntimeError("boom")

    _patch_google_auth_transport_requests(monkeypatch, FailingSession)

    manager_one = gdrive_auth.DriveAuthManager(
        DummyArgs(), logger=MagicMock(), execute_fn=lambda x: x
    )
    manager_one._http_transport = "requests"

    manager_two = gdrive_auth.DriveAuthManager(
        DummyArgs(), logger=MagicMock(), execute_fn=lambda x: x
    )
    manager_two._http_transport = "requests"

    assert manager_one._build_http(creds=MagicMock()) is None
    assert manager_one._build_http(creds=MagicMock()) is None
    assert manager_two._build_http(creds=MagicMock()) is None

    output = capsys.readouterr().out
    assert output.count("Requests transport could not be enabled") == 2


def test_build_and_test_service_uses_single_list_call(monkeypatch):
    class FakeRequest:
        def __init__(self, payload):
            self._payload = payload

        def execute(self):
            return self._payload

    class FakeFilesResource:
        def __init__(self):
            self.list_calls = 0
            self.media_calls = 0

        def list(self, **kwargs):
            self.list_calls += 1
            return FakeRequest({"files": [{"id": "file-1", "size": "1", "mimeType": "text/plain"}]})

        def get_media(self, fileId):
            self.media_calls += 1
            return types.SimpleNamespace(uri=f"https://example.invalid/{fileId}")

    class FakeAboutResource:
        @staticmethod
        def get(**kwargs):
            return FakeRequest({"user": {"emailAddress": "user@example.com"}})

    class FakeHttp:
        def __init__(self):
            self.calls = []
            self.timeout = 5

        def request(self, uri, method="GET", headers=None, timeout=None, **kwargs):
            self.calls.append(
                {
                    "uri": uri,
                    "method": method,
                    "headers": headers,
                    "timeout": timeout,
                }
            )
            return {}, b""

    class FakeService:
        def __init__(self, http):
            self._http = http
            self._files = FakeFilesResource()

        def about(self):
            return FakeAboutResource()

        def files(self):
            return self._files

    fake_http = FakeHttp()
    fake_service = FakeService(fake_http)
    manager = gdrive_auth.DriveAuthManager(
        DummyArgs(), logger=MagicMock(), execute_fn=lambda request: request.execute()
    )

    monkeypatch.setattr(gdrive_auth, "build", lambda *args, **kwargs: fake_service)
    monkeypatch.setattr(manager, "_build_http", lambda creds: fake_http)

    assert manager._build_and_test_service(creds=MagicMock()) is True
    assert fake_service._files.list_calls == 1
    assert fake_service._files.media_calls == 1
    assert len(fake_http.calls) == 1
