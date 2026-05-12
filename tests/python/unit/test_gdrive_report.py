"""Unit tests for RecoveryReporter covering new code paths."""

import sys
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_constants import DEFAULT_BURST, DEFAULT_LOG_FILE, DEFAULT_MAX_RPS, DEFAULT_STATE_FILE
from gdrive_report import RecoveryReporter


def _reporter(**overrides):
    defaults = dict(
        mode="dry_run",
        download_dir=None,
        folder_id=None,
        file_ids=None,
        after_date=None,
        extensions=None,
        post_restore_policy="trash",
        concurrency=8,
        max_rps=DEFAULT_MAX_RPS,
        burst=DEFAULT_BURST,
        limit=0,
        yes=False,
        no_emoji=True,
        verbose=0,
        log_file=DEFAULT_LOG_FILE,
        state_file=DEFAULT_STATE_FILE,
    )
    defaults.update(overrides)
    return RecoveryReporter(SimpleNamespace(**defaults), MagicMock(), {})


# ---------------------------------------------------------------------------
# _print_local_directory_status — dry-run informational path
# ---------------------------------------------------------------------------


def test_local_dir_status_dry_run_prints_informational(capsys):
    r = _reporter(mode="dry_run", download_dir="/some/path")
    r._print_local_directory_status({"local_writable": False, "local_error": None, "disk_space": 0})
    out = capsys.readouterr().out
    assert "/some/path" in out
    assert "informational" in out
    assert "PASS" not in out
    assert "FAIL" not in out


def test_local_dir_status_omitted_when_no_download_dir(capsys):
    r = _reporter(mode="dry_run", download_dir=None)
    r._print_local_directory_status({})
    assert capsys.readouterr().out == ""


# ---------------------------------------------------------------------------
# _add_file_arguments — --folder-id included in generated command
# ---------------------------------------------------------------------------


def test_add_file_arguments_includes_folder_id():
    r = _reporter(
        folder_id="FOLDER123",
        after_date=None,
        file_ids=None,
        log_file=DEFAULT_LOG_FILE,
        state_file=DEFAULT_STATE_FILE,
    )
    parts = []
    r._add_file_arguments(parts)
    assert "--folder-id" in parts
    assert "FOLDER123" in parts


def test_add_file_arguments_omits_folder_id_when_absent():
    r = _reporter(
        folder_id=None,
        after_date=None,
        file_ids=None,
        log_file=DEFAULT_LOG_FILE,
        state_file=DEFAULT_STATE_FILE,
    )
    parts = []
    r._add_file_arguments(parts)
    assert "--folder-id" not in parts


# ---------------------------------------------------------------------------
# _add_mode_arguments — dry-run with folder_id but no download_dir
# ---------------------------------------------------------------------------


def test_add_mode_arguments_dry_run_with_folder_id_no_download_dir():
    r = _reporter(mode="dry_run", download_dir=None, folder_id="FOLDER123")
    parts = []
    r._add_mode_arguments(parts)
    assert "recover-and-download" in parts
    assert "--download-dir" in parts
    assert "<DOWNLOAD_DIR>" in parts


def test_add_mode_arguments_dry_run_with_download_dir():
    r = _reporter(mode="dry_run", download_dir="./out", folder_id=None)
    parts = []
    r._add_mode_arguments(parts)
    assert "recover-and-download" in parts
    assert "./out" in parts
    assert "<DOWNLOAD_DIR>" not in parts


def test_add_mode_arguments_dry_run_no_folder_id_no_download_dir():
    r = _reporter(mode="dry_run", download_dir=None, folder_id=None)
    parts = []
    r._add_mode_arguments(parts)
    assert "recover-only" in parts


# ---------------------------------------------------------------------------
# _generate_execution_command — placeholder warning emitted
# ---------------------------------------------------------------------------


def test_generate_execution_command_emits_placeholder_warning(capsys):
    r = _reporter(mode="dry_run", download_dir=None, folder_id="FOLDER123")
    r._generate_execution_command()
    captured = capsys.readouterr()
    assert "<DOWNLOAD_DIR>" in captured.out
    assert "Replace" in captured.err


def test_generate_execution_command_no_warning_when_no_placeholder(capsys):
    r = _reporter(mode="dry_run", download_dir="./out", folder_id=None)
    r._generate_execution_command()
    captured = capsys.readouterr()
    assert "Replace" not in captured.out
    assert "Replace" not in captured.err
