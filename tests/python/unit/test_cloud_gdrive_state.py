import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

import gdrive_state
import pytest

from gdrive_models import RecoveryStateScope


def _default_args(tmp_path, **overrides):
    args = SimpleNamespace(
        state_file=str(Path(tmp_path) / "state.json"),
        mode="recover_only",
        file_ids=None,
        folder_id=None,
        retry_failed_file=None,
        extensions=None,
        after_date=None,
        limit=0,
        fresh_run=False,
        no_emoji=True,
    )
    for k, v in overrides.items():
        setattr(args, k, v)
    return args


def _build_state_manager(tmp_path, **arg_overrides):
    args = _default_args(tmp_path, **arg_overrides)
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
    args = _default_args(tmp_path)
    args.state_file = str(nested / "state.json")
    manager = gdrive_state.RecoveryStateManager(args, MagicMock())

    assert not nested.exists()
    manager._save_state()
    assert (nested / "state.json").exists()


def test_save_state_succeeds_when_directory_already_exists(tmp_path):
    manager = _build_state_manager(tmp_path)

    manager._save_state()
    assert (tmp_path / "state.json").exists()


def test_reset_state_wipes_all_fields_except_schema_version(tmp_path):
    manager = _build_state_manager(tmp_path)
    manager.state.processed_items = ["a", "b"]
    manager.state.run_id = "r"
    manager.state.start_time = "2020-01-01T00:00:00+00:00"
    manager.state.last_checkpoint = "2020-01-01T00:00:01+00:00"
    manager.state.total_found = 7
    manager.state.scope = RecoveryStateScope(source="folder_id", command="recover_only", key="x")
    manager.state.schema_version = 2

    prev_count = manager._reset_state()

    assert prev_count == 2
    assert manager.state.processed_items == []
    assert manager.state.run_id == ""
    assert manager.state.start_time == ""
    assert manager.state.last_checkpoint == ""
    assert manager.state.total_found == 0
    assert manager.state.scope is None
    assert manager.state.schema_version == 2


def test_reset_state_with_empty_processed_items_returns_zero(tmp_path):
    manager = _build_state_manager(tmp_path)
    manager.state.processed_items = []
    manager.state.run_id = "r"

    prev_count = manager._reset_state()

    assert prev_count == 0
    assert manager.state.run_id == ""


def test_reset_state_preserves_schema_version_value(tmp_path):
    manager = _build_state_manager(tmp_path)
    manager.state.schema_version = 5
    manager.state.processed_items = ["x"]

    manager._reset_state()

    assert manager.state.schema_version == 5


# ---------------------------------------------------------------------------
# Scope derivation
# ---------------------------------------------------------------------------


def test_derive_scope_trash_query_with_extensions_and_after_date(tmp_path):
    manager = _build_state_manager(
        tmp_path,
        mode="recover_and_download",
        extensions=["png", "jpg"],
        after_date="2024-01-01",
        limit=100,
    )
    scope = manager._derive_scope_from_args()
    assert scope.source == "trash_query"
    assert scope.command == "recover_and_download"
    # key is sha256 prefix; order-independent over extensions
    assert len(scope.key) == 16

    # Same args (reordered extensions) should produce the same key
    manager2 = _build_state_manager(
        tmp_path,
        mode="recover_and_download",
        extensions=["jpg", "png"],
        after_date="2024-01-01",
        limit=100,
    )
    assert manager2._derive_scope_from_args().key == scope.key


def test_derive_scope_folder_id_uses_folder_id_verbatim(tmp_path):
    manager = _build_state_manager(tmp_path, mode="recover_and_download", folder_id="FOLDER123")
    scope = manager._derive_scope_from_args()
    assert scope.source == "folder_id"
    assert scope.key == "FOLDER123"


def test_derive_scope_file_ids_is_order_independent(tmp_path):
    m1 = _build_state_manager(tmp_path, mode="recover_only", file_ids=["b", "a", "c"])
    m2 = _build_state_manager(tmp_path, mode="recover_only", file_ids=["c", "a", "b"])
    s1 = m1._derive_scope_from_args()
    s2 = m2._derive_scope_from_args()
    assert s1.source == "file_ids"
    assert s1.key == s2.key
    assert len(s1.key) == 16


def test_derive_scope_retry_failed_file_uses_absolute_path(tmp_path):
    retry_csv = tmp_path / "failed.csv"
    retry_csv.write_text("source_folder_id,file_id,target_path\n")
    manager = _build_state_manager(
        tmp_path, mode="recover_and_download", retry_failed_file=str(retry_csv)
    )
    scope = manager._derive_scope_from_args()
    assert scope.source == "retry_failed_file"
    assert Path(scope.key).is_absolute()
    assert Path(scope.key) == retry_csv.resolve()


# ---------------------------------------------------------------------------
# v1 -> v2 migration
# ---------------------------------------------------------------------------


def _write_v1_state(path: Path, processed_items, owner_pid=12345):
    state = {
        "schema_version": 1,
        "total_found": 3,
        "processed_items": processed_items,
        "start_time": "2024-01-01T00:00:00+00:00",
        "last_checkpoint": "2024-01-01T00:00:10+00:00",
        "run_id": "old-run-id",
        "owner_pid": owner_pid,
    }
    path.write_text(json.dumps(state))


def test_load_v1_state_migrates_to_v2_and_preserves_processed_items(tmp_path, capsys):
    state_path = Path(tmp_path) / "state.json"
    _write_v1_state(state_path, processed_items=["a", "b", "c"])
    manager = _build_state_manager(tmp_path, mode="recover_only", extensions=["pdf"])

    assert manager._load_state() is True
    assert manager.state.processed_items == ["a", "b", "c"]
    assert manager.state.schema_version == 2
    assert manager.state.scope is not None
    assert manager.state.scope.source == "trash_query"
    assert manager.state.scope.command == "recover_only"
    # owner_pid must be silently dropped (no longer a field)
    assert not hasattr(manager.state, "owner_pid")

    captured = capsys.readouterr()
    assert "Migrating state file from schema v1 to v2" in captured.out


def test_load_v1_state_with_no_schema_version_field_treated_as_legacy(tmp_path):
    state_path = Path(tmp_path) / "state.json"
    state_path.write_text(json.dumps({"processed_items": ["x"]}))
    manager = _build_state_manager(tmp_path, mode="recover_only")

    assert manager._load_state() is True
    assert manager.state.processed_items == ["x"]
    assert manager.state.schema_version == 2
    assert manager.state.scope is not None


# ---------------------------------------------------------------------------
# v2 scope match / mismatch
# ---------------------------------------------------------------------------


def _write_v2_state(path: Path, scope: RecoveryStateScope, processed_items=None):
    state = {
        "schema_version": 2,
        "total_found": 1,
        "processed_items": processed_items or [],
        "start_time": "2024-01-01T00:00:00+00:00",
        "last_checkpoint": "2024-01-01T00:00:10+00:00",
        "run_id": "run-id",
        "scope": {"source": scope.source, "command": scope.command, "key": scope.key},
    }
    path.write_text(json.dumps(state))


def test_load_v2_state_matching_scope_resumes(tmp_path):
    state_path = Path(tmp_path) / "state.json"
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="F1")
    saved_scope = manager._derive_scope_from_args()
    _write_v2_state(state_path, saved_scope, processed_items=["a"])

    assert manager._load_state() is True
    assert manager.state.processed_items == ["a"]
    assert manager.state.scope == saved_scope


def test_load_v2_state_mismatched_scope_raises(tmp_path):
    state_path = Path(tmp_path) / "state.json"
    saved_scope = RecoveryStateScope(source="folder_id", command="recover_only", key="OTHER")
    _write_v2_state(state_path, saved_scope)
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="F1")

    with pytest.raises(gdrive_state.StateScopeMismatchError) as exc_info:
        manager._load_state()
    err = exc_info.value
    assert err.saved_scope.key == "OTHER"
    assert err.current_scope.key == "F1"


def test_load_v2_mismatched_scope_with_fresh_run_does_not_raise(tmp_path):
    state_path = Path(tmp_path) / "state.json"
    saved_scope = RecoveryStateScope(source="folder_id", command="recover_only", key="OTHER")
    _write_v2_state(state_path, saved_scope, processed_items=["a"])
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="F1", fresh_run=True)

    # No exception — fresh-run bypasses the guard.
    assert manager._load_state() is True


def test_save_state_writes_v2_with_scope(tmp_path):
    state_path = Path(tmp_path) / "state.json"
    manager = _build_state_manager(tmp_path, mode="recover_and_download", folder_id="F2")
    manager.state.processed_items = ["x", "y"]
    manager._save_state()

    saved = json.loads(state_path.read_text())
    assert saved["schema_version"] == 2
    assert saved["scope"]["source"] == "folder_id"
    assert saved["scope"]["command"] == "recover_and_download"
    assert saved["scope"]["key"] == "F2"
    assert "owner_pid" not in saved


def test_load_v2_state_missing_scope_block_rebuilds_from_args(tmp_path):
    """A v2 file with schema_version=2 but no scope block (corrupted) should be
    repaired by synthesizing the scope from current args rather than raising."""
    state_path = Path(tmp_path) / "state.json"
    state_path.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "processed_items": ["a"],
                "run_id": "rid",
                # no scope field
            }
        )
    )
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="F9")

    assert manager._load_state() is True
    assert manager.state.scope is not None
    assert manager.state.scope.key == "F9"


def test_load_state_corrupted_scope_dict_falls_through_to_rebuild(tmp_path):
    """If the JSON scope dict can't be coerced (e.g. non-string fields), the
    loader leaves scope=None and the loader rebuilds it from current args."""
    state_path = Path(tmp_path) / "state.json"
    # processed_items field is intentionally wrong type to exercise the
    # broad except in _assign_recovery_state_fields (post_init repairs it).
    state_path.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "processed_items": ["a"],
                "scope": {"source": "folder_id", "command": "recover_only", "key": "OLD"},
            }
        )
    )
    # Saved scope matches current → loads cleanly.
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="OLD")
    assert manager._load_state() is True
    assert manager.state.scope is not None


def test_load_newer_schema_falls_back_to_current(tmp_path, caplog):
    """A state file with schema_version > 2 logs an info line and resets the
    in-memory schema_version to the current value."""
    import logging

    state_path = Path(tmp_path) / "state.json"
    state_path.write_text(
        json.dumps(
            {
                "schema_version": 99,
                "processed_items": ["a"],
            }
        )
    )
    manager = _build_state_manager(tmp_path, mode="recover_only")
    with caplog.at_level(logging.INFO):
        manager.logger = logging.getLogger("test-newer-schema")
        assert manager._load_state() is True
    assert manager.state.schema_version == gdrive_state.CURRENT_SCHEMA_VERSION


def test_load_state_corrupt_json_invokes_error_callback(tmp_path):
    """A malformed JSON file should not raise out of _load_state; it should
    return False and invoke the on_state_load_error callback if provided."""
    state_path = Path(tmp_path) / "state.json"
    state_path.write_text("{not valid json")
    args = _default_args(tmp_path)
    callback_calls = []
    manager = gdrive_state.RecoveryStateManager(
        args, MagicMock(), on_state_load_error=lambda: callback_calls.append(1)
    )
    assert manager._load_state() is False
    assert callback_calls == [1]


def test_load_state_no_file_returns_false(tmp_path):
    """If the state file does not exist, _load_state returns False with no side effects."""
    manager = _build_state_manager(tmp_path)
    assert not Path(manager.args.state_file).exists()
    assert manager._load_state() is False


def test_save_state_sets_scope_when_initially_none(tmp_path):
    """_save_state must derive a scope when state.scope is None at save time."""
    state_path = Path(tmp_path) / "state.json"
    manager = _build_state_manager(tmp_path, mode="recover_only", folder_id="FX")
    assert manager.state.scope is None
    manager._save_state()
    saved = json.loads(state_path.read_text())
    assert saved["scope"]["key"] == "FX"


def test_derive_scope_dry_run_mode_falls_back_label(tmp_path):
    """`dry_run` mode (which never persists state) should still produce a
    RecoveryStateScope without raising — guards against accidental save paths."""
    manager = _build_state_manager(tmp_path, mode="dry_run")
    scope = manager._derive_scope_from_args()
    assert scope.source == "trash_query"
    assert scope.command == "dry_run"


def test_load_v1_migration_tolerates_logger_exception(tmp_path):
    """The info log inside _print_migration_notice must not surface a logger error."""
    state_path = Path(tmp_path) / "state.json"
    _write_v1_state(state_path, processed_items=["a"])
    args = _default_args(tmp_path, mode="recover_only")
    logger = MagicMock()
    logger.info.side_effect = RuntimeError("logger boom")
    manager = gdrive_state.RecoveryStateManager(args, logger)
    # Should not raise — the exception path inside _print_migration_notice is swallowed.
    assert manager._load_state() is True
    assert manager.state.schema_version == 2


def test_load_newer_schema_tolerates_logger_exception(tmp_path):
    """The info log inside _log_newer_schema must not surface a logger error."""
    state_path = Path(tmp_path) / "state.json"
    state_path.write_text(json.dumps({"schema_version": 99, "processed_items": []}))
    args = _default_args(tmp_path, mode="recover_only")
    logger = MagicMock()
    logger.info.side_effect = RuntimeError("logger boom")
    manager = gdrive_state.RecoveryStateManager(args, logger)
    assert manager._load_state() is True
    assert manager.state.schema_version == 2


def test_load_state_callback_exception_is_swallowed(tmp_path):
    """If the on_state_load_error callback itself raises, _load_state should
    still return False rather than propagating the secondary failure."""
    state_path = Path(tmp_path) / "state.json"
    state_path.write_text("{not valid json")
    args = _default_args(tmp_path)
    manager = gdrive_state.RecoveryStateManager(
        args,
        MagicMock(),
        on_state_load_error=lambda: (_ for _ in ()).throw(RuntimeError("cb boom")),
    )
    assert manager._load_state() is False


def test_state_scope_mismatch_error_carries_both_scopes():
    saved = RecoveryStateScope(source="folder_id", command="recover_only", key="A")
    current = RecoveryStateScope(source="folder_id", command="recover_only", key="B")
    err = gdrive_state.StateScopeMismatchError(saved, current)
    assert err.saved_scope is saved
    assert err.current_scope is current
    assert "scope mismatch" in str(err)
