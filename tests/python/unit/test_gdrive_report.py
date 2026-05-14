"""Unit tests for RecoveryReporter covering new code paths."""

import sys
import time
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

cloud_dir = Path(__file__).parent.parent.parent / "src" / "python" / "cloud"
if str(cloud_dir) not in sys.path:
    sys.path.insert(0, str(cloud_dir))

from gdrive_constants import DEFAULT_BURST, DEFAULT_LOG_FILE, DEFAULT_MAX_RPS, DEFAULT_STATE_FILE
from gdrive_models import RecoveryState
from gdrive_report import ProgressBar, RecoveryReporter


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


# ---------------------------------------------------------------------------
# _print_summary — mode-aware success rate
# ---------------------------------------------------------------------------


def _make_stats(**overrides):
    base = dict(
        found=100,
        recovered=0,
        downloaded=0,
        errors=0,
        skipped=0,
        skipped_existing=0,
        post_restore_retained=0,
        post_restore_trashed=0,
        post_restore_deleted=0,
    )
    base.update(overrides)
    return base


def test_summary_recover_and_download_uses_downloaded_count(capsys):
    """recover-and-download (including --folder-id) must report downloaded/found."""
    stats = _make_stats(found=2131, recovered=0, downloaded=2131)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(609.5, RecoveryState())
    out = capsys.readouterr().out
    assert "Download success rate: 100.0%" in out
    assert "Recovery success rate" not in out


def test_summary_recover_only_uses_recovered_count(capsys):
    """recover-only must report recovered/found."""
    stats = _make_stats(found=50, recovered=45, downloaded=0, errors=5)
    r = _reporter(mode="recover_only")
    r.stats = stats
    r._print_summary(30.0, RecoveryState())
    out = capsys.readouterr().out
    assert "Recovery success rate: 90.0%" in out
    assert "Download success rate" not in out


def test_summary_zero_found_yields_zero_rate(capsys):
    """When found=0 the rate must be 0.0% and not raise ZeroDivisionError."""
    stats = _make_stats(found=0, downloaded=0)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "0.0%" in out


def test_summary_prints_skipped_existing_line_when_nonzero(capsys):
    """--skip-existing outcomes appear in the summary when stat > 0."""
    stats = _make_stats(found=10, downloaded=7, skipped_existing=3)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "Files skipped (already on disk, --skip-existing): 3" in out


def test_summary_skipped_existing_line_omitted_when_zero(capsys):
    """Summary stays clean when skipped_existing is zero."""
    stats = _make_stats(found=10, downloaded=10, skipped_existing=0)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "already on disk" not in out


def test_summary_success_rate_includes_skipped_existing(capsys):
    """Skipped-existing items are logical successes and feed the success-rate numerator."""
    # 4 downloaded + 6 skipped-existing of 10 found = 100% success.
    stats = _make_stats(found=10, downloaded=4, skipped_existing=6)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "Download success rate: 100.0%" in out


def test_summary_recover_only_ignores_skipped_existing(capsys):
    """recover_only uses recovered/found and is not affected by skipped_existing."""
    stats = _make_stats(found=10, recovered=5, downloaded=0, skipped_existing=5)
    r = _reporter(mode="recover_only")
    r.stats = stats
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "Recovery success rate: 50.0%" in out


# ---------------------------------------------------------------------------
# ProgressBar — _fill_bar
# ---------------------------------------------------------------------------


def _pb(no_emoji=True, total=None):
    args = SimpleNamespace(no_emoji=no_emoji)
    return ProgressBar(args, total=total)


def test_fill_bar_ascii_full():
    bar = _pb(no_emoji=True, total=10)
    rendered = bar._fill_bar(10, 10)
    assert rendered == "[" + "#" * 20 + "]"


def test_fill_bar_ascii_half():
    bar = _pb(no_emoji=True, total=10)
    rendered = bar._fill_bar(5, 10)
    assert rendered == "[" + "#" * 10 + "-" * 10 + "]"


def test_fill_bar_ascii_empty():
    bar = _pb(no_emoji=True, total=10)
    rendered = bar._fill_bar(0, 10)
    assert rendered == "[" + "-" * 20 + "]"


def test_fill_bar_emoji_uses_block_chars():
    bar = _pb(no_emoji=False, total=4)
    rendered = bar._fill_bar(4, 4)
    assert "█" in rendered
    assert "░" not in rendered


# ---------------------------------------------------------------------------
# ProgressBar — _format_line with known total
# ---------------------------------------------------------------------------


def test_format_line_known_total_contains_count_and_pct():
    bar = _pb(no_emoji=True, total=100)
    start = time.time() - 10  # 10 s elapsed → rate = 40/s
    line = bar._format_line(40, start, 0)
    assert "40/100" in line
    assert "40.0%" in line
    assert "/sec" in line
    assert "ETA:" in line


def test_format_line_known_total_uses_pipe_separator_no_emoji():
    bar = _pb(no_emoji=True, total=10)
    line = bar._format_line(5, time.time() - 1, 0)
    assert "|" in line
    assert "│" not in line


def test_format_line_known_total_uses_box_separator_emoji():
    bar = _pb(no_emoji=False, total=10)
    line = bar._format_line(5, time.time() - 1, 0)
    assert "│" in line


# ---------------------------------------------------------------------------
# ProgressBar — _format_line streaming (no total)
# ---------------------------------------------------------------------------


def test_format_line_streaming_shows_processed():
    bar = _pb(no_emoji=True, total=None)
    line = bar._format_line(42, time.time() - 1, 0)
    assert "processed=42" in line


def test_format_line_streaming_shows_discovered_when_larger():
    bar = _pb(no_emoji=True, total=None)
    line = bar._format_line(10, time.time() - 1, 50)
    assert "discovered=50" in line


def test_format_line_streaming_no_discovered_when_not_larger():
    bar = _pb(no_emoji=True, total=None)
    line = bar._format_line(10, time.time() - 1, 5)
    assert "discovered" not in line


# ---------------------------------------------------------------------------
# ProgressBar — update throttling
# ---------------------------------------------------------------------------


def test_update_skips_render_within_interval(capsys):
    bar = _pb(no_emoji=True, total=10)
    bar._last_render = time.time()  # just rendered
    bar.update(5, time.time() - 1)
    assert capsys.readouterr().out == ""


def test_update_renders_when_interval_elapsed(capsys, monkeypatch):
    bar = _pb(no_emoji=True, total=10)
    bar._is_tty = False
    bar._last_render = 0.0  # never rendered
    bar.update(5, time.time() - 5)
    assert capsys.readouterr().out != ""


def test_update_tty_uses_carriage_return(capsys, monkeypatch):
    bar = _pb(no_emoji=True, total=10)
    bar._is_tty = True
    bar._last_render = 0.0
    bar.update(5, time.time() - 5)
    out = capsys.readouterr().out
    assert out.startswith("\r")
    assert not out.endswith("\n")


def test_update_force_bypasses_throttle(capsys):
    """force=True must emit a render even when the throttle interval has not elapsed."""
    bar = _pb(no_emoji=True, total=None)  # streaming mode (no fixed total)
    bar._is_tty = False
    bar._last_render = time.time()  # would normally be throttled
    bar.update(57513, time.time() - 1, discovered=57513, force=True)
    out = capsys.readouterr().out
    assert "processed=57513" in out


def test_reporter_print_stream_progress_force_passes_through(capsys):
    """RecoveryReporter._print_stream_progress(force=True) must propagate to ProgressBar.update."""
    r = _reporter(mode="recover_and_download")
    r._start_progress(total=None)
    r._progress_bar._is_tty = False
    r._progress_bar._last_render = time.time()  # throttled
    r._print_stream_progress(57513, time.time() - 1, 57513, file_ids=None, force=True)
    out = capsys.readouterr().out
    assert "processed=57513" in out
    assert "discovered=57513" not in out  # equal counts → no "discovered=" suffix


# ---------------------------------------------------------------------------
# ProgressBar — close
# ---------------------------------------------------------------------------


def test_close_prints_newline_on_tty_after_update(capsys):
    bar = _pb(no_emoji=True, total=10)
    bar._is_tty = True
    bar._last_render = time.time()  # simulate a previous render
    bar.close()
    assert capsys.readouterr().out == "\n"


def test_close_silent_when_no_render_yet(capsys):
    bar = _pb(no_emoji=True, total=10)
    bar._is_tty = True
    bar._last_render = 0.0
    bar.close()
    assert capsys.readouterr().out == ""


def test_close_silent_on_non_tty(capsys):
    bar = _pb(no_emoji=True, total=10)
    bar._is_tty = False
    bar._last_render = time.time()
    bar.close()
    assert capsys.readouterr().out == ""


# ---------------------------------------------------------------------------
# RecoveryReporter — _should_show_progress
# ---------------------------------------------------------------------------


def test_should_show_progress_non_tty_no_verbose(monkeypatch):
    monkeypatch.setattr(sys, "stdout", MagicMock(isatty=lambda: False))
    r = _reporter(verbose=0)
    assert r._should_show_progress() is False


def test_should_show_progress_non_tty_with_verbose(monkeypatch):
    monkeypatch.setattr(sys, "stdout", MagicMock(isatty=lambda: False))
    r = _reporter(verbose=1)
    assert r._should_show_progress() is True


def test_should_show_progress_tty_no_verbose(monkeypatch):
    monkeypatch.setattr(sys, "stdout", MagicMock(isatty=lambda: True))
    r = _reporter(verbose=0)
    assert r._should_show_progress() is True


# ---------------------------------------------------------------------------
# RecoveryReporter — _start_progress / _close_progress
# ---------------------------------------------------------------------------


def test_start_progress_creates_bar():
    r = _reporter()
    assert r._progress_bar is None
    r._start_progress(total=50)
    assert r._progress_bar is not None
    assert r._progress_bar.total == 50


def test_close_progress_removes_bar(capsys):
    r = _reporter()
    r._start_progress(total=10)
    r._progress_bar._last_render = 0.0  # no render yet — close should be silent
    r._close_progress()
    assert r._progress_bar is None
    assert capsys.readouterr().out == ""


def test_close_progress_is_idempotent(capsys):
    r = _reporter()
    r._close_progress()  # no bar — should not raise
    assert r._progress_bar is None


# ---------------------------------------------------------------------------
# RecoveryReporter — print_streaming_start initialises bar with file_ids total
# ---------------------------------------------------------------------------


def test_print_streaming_start_sets_total_from_file_ids(capsys):
    r = _reporter(file_ids=["id1", "id2", "id3"])
    r.print_streaming_start(batch_n=500, concurrency=8)
    assert r._progress_bar is not None
    assert r._progress_bar.total == 3
    capsys.readouterr()  # consume output


def test_print_streaming_start_total_none_when_no_file_ids(capsys):
    r = _reporter(file_ids=None)
    r.print_streaming_start(batch_n=500, concurrency=8)
    assert r._progress_bar is not None
    assert r._progress_bar.total is None
    capsys.readouterr()


# ---------------------------------------------------------------------------
# RecoveryReporter — _print_stream_progress delegates to bar
# ---------------------------------------------------------------------------


def test_print_stream_progress_delegates_to_bar(monkeypatch):
    r = _reporter()
    r._start_progress(total=None)
    called_with = []
    monkeypatch.setattr(
        r._progress_bar,
        "update",
        lambda c, st, d=0, force=False: called_with.append((c, d, force)),
    )
    r._print_stream_progress(42, time.time() - 1, 100, None)
    assert called_with == [(42, 100, False)]


def test_print_stream_progress_fallback_when_no_bar(capsys):
    r = _reporter(verbose=1)
    r._progress_bar = None
    r._print_stream_progress(10, time.time() - 1, 20, None)
    out = capsys.readouterr().out
    assert "10" in out


# ---------------------------------------------------------------------------
# RecoveryReporter — print_progress_update delegates to bar
# ---------------------------------------------------------------------------


def test_print_progress_update_delegates_to_bar(monkeypatch):
    r = _reporter()
    r._start_progress(total=100)
    called_with = []
    monkeypatch.setattr(r._progress_bar, "update", lambda c, st, d=0: called_with.append(c))
    r.print_progress_update(40, 100, time.time() - 1)
    assert called_with == [40]


def test_print_progress_update_fallback_when_no_bar(capsys):
    r = _reporter(verbose=1)
    r._progress_bar = None
    r.print_progress_update(40, 100, time.time() - 1)
    out = capsys.readouterr().out
    assert "40/100" in out


# ---------------------------------------------------------------------------
# RecoveryReporter — _print_summary closes bar before printing
# ---------------------------------------------------------------------------


def test_print_summary_closes_bar(capsys):
    stats = _make_stats(found=10, recovered=10)
    r = _reporter(mode="recover_only")
    r.stats = stats
    r._start_progress(total=10)
    r._progress_bar._last_render = 0.0  # no render → close is silent
    r._print_summary(5.0, RecoveryState())
    assert r._progress_bar is None
    capsys.readouterr()


# ---------------------------------------------------------------------------
# RecoveryReporter — print_interrupted_state_saved closes bar
# ---------------------------------------------------------------------------


def test_interrupted_state_saved_closes_bar(capsys):
    r = _reporter()
    r._start_progress(total=10)
    r._progress_bar._last_render = 0.0
    r.print_interrupted_state_saved()
    assert r._progress_bar is None
    capsys.readouterr()


# ---------------------------------------------------------------------------
# RecoveryReporter — end-of-run summary is logged at INFO (for log files)
# ---------------------------------------------------------------------------


def test_print_summary_emits_structured_info_log(capsys):
    stats = _make_stats(found=57513, recovered=0, downloaded=12, skipped=57501, errors=0)
    r = _reporter(mode="recover_and_download")
    r.stats = stats
    r._print_summary(2432.8, RecoveryState())
    capsys.readouterr()
    # Find the structured "Run complete" log call.
    matches = [
        call
        for call in r.logger.info.call_args_list
        if call.args and "Run complete" in call.args[0]
    ]
    assert len(matches) == 1, "expected exactly one structured Run complete INFO log"
    fmt, *fmt_args = matches[0].args
    rendered = fmt % tuple(fmt_args)
    assert "mode=recover_and_download" in rendered
    assert "found=57513" in rendered
    assert "downloaded=12" in rendered
    assert "skipped=57501" in rendered
    assert "errors=0" in rendered
    assert "elapsed=2432.8s" in rendered


def test_print_summary_logger_failure_is_swallowed(capsys):
    """A misbehaving logger must not break the user-facing summary."""
    r = _reporter(mode="recover_only")
    r.stats = _make_stats(found=1, recovered=1)
    r.logger.info.side_effect = RuntimeError("logger down")
    # Must not raise; stdout summary still rendered.
    r._print_summary(1.0, RecoveryState())
    out = capsys.readouterr().out
    assert "Recovery success rate" in out


def test_print_interrupted_emits_structured_info_log(capsys):
    r = _reporter(mode="recover_and_download")
    r.stats = _make_stats(found=10, recovered=0, downloaded=3, skipped=2, errors=1)
    r.print_interrupted_state_saved()
    capsys.readouterr()
    matches = [
        call
        for call in r.logger.info.call_args_list
        if call.args and "Run interrupted" in call.args[0]
    ]
    assert len(matches) == 1
    fmt, *fmt_args = matches[0].args
    rendered = fmt % tuple(fmt_args)
    assert "mode=recover_and_download" in rendered
    assert "downloaded=3" in rendered
    assert "skipped=2" in rendered
    assert "errors=1" in rendered
