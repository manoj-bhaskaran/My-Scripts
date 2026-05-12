from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

import gdrive_state
import pytest


def _build_state_manager(tmp_path):
    args = SimpleNamespace(state_file=str(Path(tmp_path) / "state.json"))
    return gdrive_state.RecoveryStateManager(args, MagicMock())


@pytest.mark.parametrize(
    ("side_effect", "expected"),
    [
        (None, True),
        (PermissionError(), True),
        (ProcessLookupError(), False),
        (OSError(), False),
    ],
)
def test_pid_is_alive_uses_posix_kill(monkeypatch, tmp_path, side_effect, expected):
    manager = _build_state_manager(tmp_path)
    calls = []

    def fake_kill(pid, sig):
        calls.append((pid, sig))
        if side_effect is not None:
            raise side_effect

    monkeypatch.setattr(gdrive_state.os, "name", "posix", raising=False)
    monkeypatch.setattr(gdrive_state.os, "kill", fake_kill)

    assert manager._pid_is_alive(1234) is expected
    assert calls == [(1234, 0)]


def test_save_state_creates_missing_parent_directory(tmp_path):
    nested = tmp_path / "nested" / "subdir"
    args = SimpleNamespace(state_file=str(nested / "state.json"))
    manager = gdrive_state.RecoveryStateManager(args, MagicMock())

    assert not nested.exists()
    manager._save_state()
    assert (nested / "state.json").exists()


def test_save_state_succeeds_when_directory_already_exists(tmp_path):
    manager = _build_state_manager(tmp_path)

    manager._save_state()
    assert (tmp_path / "state.json").exists()


def test_clear_processed_items_removes_all_and_returns_count(tmp_path):
    manager = _build_state_manager(tmp_path)
    manager.state.processed_items = ["a", "b", "c"]

    count = manager._clear_processed_items()

    assert count == 3
    assert manager.state.processed_items == []


def test_clear_processed_items_on_empty_state_returns_zero(tmp_path):
    manager = _build_state_manager(tmp_path)

    count = manager._clear_processed_items()

    assert count == 0
    assert manager.state.processed_items == []


def test_clear_processed_items_tolerates_null_from_json(tmp_path):
    manager = _build_state_manager(tmp_path)
    # Simulate _assign_recovery_state_fields loading "processed_items": null
    manager.state.processed_items = None  # type: ignore[assignment]

    count = manager._clear_processed_items()

    assert count == 0
    assert manager.state.processed_items == []
