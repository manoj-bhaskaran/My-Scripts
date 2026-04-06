from pathlib import Path
from unittest.mock import MagicMock

import pytest

import sys

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_retry import HttpError, with_retries


class _Resp(dict):
    def __init__(self, status: int):
        super().__init__()
        self.status = status
        self.reason = "reason"


def _http_error(status: int, content: bytes = b"boom"):
    return HttpError(_Resp(status), content)


def test_with_retries_success_no_retry():
    result, error = with_retries(lambda: "ok")
    assert result == "ok"
    assert error is None


def test_with_retries_retry_then_succeed(monkeypatch):
    calls = {"n": 0}

    def op():
        calls["n"] += 1
        if calls["n"] == 1:
            raise _http_error(429, b"rate")
        return "done"

    sleep_mock = MagicMock()
    monkeypatch.setattr("gdrive_retry.time.sleep", sleep_mock)

    result, error = with_retries(op)

    assert result == "done"
    assert error is None
    assert calls["n"] == 2
    sleep_mock.assert_called_once()


def test_with_retries_terminal_failure_no_retry(monkeypatch):
    sleep_mock = MagicMock()
    monkeypatch.setattr("gdrive_retry.time.sleep", sleep_mock)

    result, error = with_retries(
        lambda: (_ for _ in ()).throw(_http_error(404, b"not found")),
        terminal_statuses=(403, 404),
    )

    assert result is None
    assert "HTTP 404" in (error or "")
    sleep_mock.assert_not_called()


def test_with_retries_max_retries_exhausted(monkeypatch):
    sleep_mock = MagicMock()
    monkeypatch.setattr("gdrive_retry.time.sleep", sleep_mock)

    result, error = with_retries(
        lambda: (_ for _ in ()).throw(_http_error(500, b"server")),
        max_retries=3,
    )

    assert result is None
    assert "HTTP 500" in (error or "")
    assert sleep_mock.call_count == 2
