"""Tests for Google Drive recovery helpers."""

from unittest.mock import MagicMock


def _build_dummy_args(tmp_path):
    class Args:
        pass

    args = Args()
    args.verbose = 0
    args.log_file = str(tmp_path / "test.log")
    args.failed_file = ""
    args.state_file = str(tmp_path / "state.json")
    args.file_ids = None
    args.extensions = None
    args.after_date = None
    args.limit = 0
    args.mode = "recover"
    args.post_restore_policy = "retain"
    args.download_dir = None
    args.max_rps = 0
    args.burst = 0
    args.rl_diagnostics = False
    args.debug_parity = False
    args.fail_on_parity_mismatch = False
    args.clear_id_cache = False
    args.parity_metrics_file = None
    return args


def test_is_valid_file_id_format(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))
    assert tool.discovery._is_valid_file_id_format("1a2b3c4d5e6f7g8h9i0j1k2l3") is True
    assert tool.discovery._is_valid_file_id_format("short") is False


def test_build_query_with_extensions(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.extensions = ["jpg", ".tar.gz", "UNKNOWN"]
    tool = DriveTrashRecoveryTool(args)

    q = tool.discovery._build_query()
    assert "trashed=true" in q
    assert "mimeType" in q


def test_matches_extension_filter_and_time_filter(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.extensions = ["txt"]
    args.after_date = "2020-01-01T00:00:00Z"
    tool = DriveTrashRecoveryTool(args)

    assert tool.discovery._matches_extension_filter("document.txt") is True
    assert tool.discovery._matches_extension_filter("document.pdf") is False

    item = {"modifiedTime": "2021-01-01T00:00:00Z"}
    assert tool.discovery._matches_time_filter(item) is True
    item_bad = {"modifiedTime": "not-a-date"}
    assert tool.discovery._matches_time_filter(item_bad) is True


def test_generate_target_path(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.download_dir = str(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    class DummyItem:
        id = "abc"
        name = "my*file?.txt"
        relative_path = ""

    p1 = tool._generate_target_path(DummyItem)
    assert str(tmp_path) in p1

    (tmp_path / "myfile.txt").write_text("x")
    item2 = MagicMock(id="abc", name="myfile.txt")
    p2 = tool._generate_target_path(item2)
    assert p2 != str(tmp_path / "myfile.txt")

    # relative_path is reconstructed as a subdirectory under download_dir
    # Use SimpleNamespace: MagicMock treats 'name' as its internal mock name, not an attribute.
    from types import SimpleNamespace

    item3 = SimpleNamespace(id="def", name="doc.pdf", relative_path="subdir/nested")
    p3 = tool._generate_target_path(item3)
    assert "subdir" in p3
    assert "nested" in p3
    assert p3.endswith("doc.pdf")


def test_report_validation_outcome(monkeypatch, tmp_path):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    buckets = {"ok": ["1"], "invalid": [], "not_found": [], "no_access": []}
    assert tool.discovery._report_validation_outcome(buckets, 0, []) is True

    buckets2 = {"ok": [], "invalid": ["bad"], "not_found": [], "no_access": []}
    assert tool.discovery._report_validation_outcome(buckets2, 1, ["1"]) is False


def test_handle_prefetch_error_retry_and_terminal(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))

    class FakeHttpError(Exception):
        pass

    fake_error = FakeHttpError("oops")
    fake_error.resp = MagicMock(status=429)

    buckets = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
    transient_errors = [0]
    transient_ids = []
    err_count = [0]

    # first attempt should request retry
    should_retry = tool.discovery._handle_prefetch_error(
        "fid", 429, fake_error, 0, buckets, transient_errors, transient_ids, err_count
    )
    assert should_retry is False

    # terminal not-found
    fake_error2 = FakeHttpError("no")
    fake_error2.resp = MagicMock(status=404)
    assert (
        tool.discovery._handle_prefetch_error(
            "fid", 404, fake_error2, 0, buckets, transient_errors, transient_ids, err_count
        )
        is True
    )
    assert "fid" in buckets["not_found"]


def test_fetch_file_metadata_error_path(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))

    class FakeRequest:
        def execute(self):
            raise Exception("bad request")

    service = MagicMock()
    service.files.return_value.get.return_value = FakeRequest()

    data, non_trashed, err = tool.discovery._fetch_file_metadata(service, "fid", "id")
    assert data is None
    assert non_trashed is False
    assert err and "files.get(fileId=fid) failed" in err


def test_discover_via_query_limit(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    args = _build_dummy_args(tmp_path)
    args.verbose = 1
    args.limit = 1
    tool = DriveTrashRecoveryTool(args)

    first_page = (
        [
            {
                "id": "1",
                "name": "a",
                "mimeType": "text/plain",
                "size": 1,
                "createdTime": "",
                "modifiedTime": "",
            }
        ],
        "t1",
    )
    second_page = (
        [
            {
                "id": "2",
                "name": "b",
                "mimeType": "text/plain",
                "size": 1,
                "createdTime": "",
                "modifiedTime": "",
            }
        ],
        None,
    )

    service = MagicMock()
    service.files.return_value.list.return_value.execute.side_effect = [
        {"files": first_page[0], "nextPageToken": first_page[1]},
        {"files": second_page[0], "nextPageToken": second_page[1]},
    ]
    tool.discovery.auth._get_service.return_value = service

    items = tool.discovery._discover_via_query("trashed=true")
    assert len(items) == 1


def test_error_formatting_and_status_extract(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    class FakeHttpError:
        def __init__(self):
            self.resp = MagicMock(status=502)
            self.content = b"bad"

    e = FakeHttpError()
    # Ensure resp path is used for status extraction
    assert tool.discovery._extract_status_from_http_error(e) == 502
    assert tool.discovery._extract_status_from_http_error(ValueError("x")) is None

    assert (
        tool.discovery._format_fetch_metadata_error_with_context(ValueError("bad"), None, "f1")
        == "files.get(fileId=f1) failed: bad"
    )
    assert "HTTP 503" in tool.discovery._format_fetch_metadata_error_with_context(
        ValueError("bad"), 503, "f1"
    )


def test_execute_uses_rate_limiter_wait(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))
    tool.rate_limiter = MagicMock()
    req = MagicMock()
    req.execute.return_value = {"ok": True}

    out = tool._execute(req)

    assert out == {"ok": True}
    tool.rate_limiter.wait.assert_called_once_with()
    req.execute.assert_called_once_with()


def test_discovery_owns_streaming_helpers(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))

    assert hasattr(type(tool.discovery), "_handle_streaming_file")
    assert hasattr(type(tool.discovery), "_should_stop_for_limit")
    assert hasattr(type(tool.discovery), "_process_streaming_batch")
    assert hasattr(type(tool.discovery), "_should_flush_streaming_batch")


def test_privilege_checks_and_file_info(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())

    args = _build_dummy_args(tmp_path)
    args.download_dir = str(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    # fake auth + service
    fake_service = MagicMock()
    fake_service.files.return_value.list.return_value.execute.return_value = {"files": []}
    tool.auth._get_service = MagicMock(return_value=fake_service)

    tool.items = []
    checks = tool._check_privileges()
    assert checks["drive_access"] is True
    assert checks["local_writable"] is True

    # test untrash/download/trash/delete privileges with fake file info
    fake_file = {
        "trashed": True,
        "capabilities": {
            "canUntrash": True,
            "canDownload": False,
            "canTrash": True,
            "canDelete": False,
        },
        "size": 1024,
    }

    # monkeypatch privilege checker fetch helper to return our fake_file when called
    tool.privileges._get_file_info = MagicMock(return_value=fake_file)
    status = tool._check_untrash_privilege("fid")
    assert status["status"] == "pass"

    status = tool._check_download_privilege("fid")
    assert status["status"] == "fail"

    trash_status, delete_status = tool._check_trash_delete_privileges("fid", "pass")
    assert trash_status["status"] == "pass"
    assert delete_status["status"] == "fail"

    # ensure _test_operation_privileges handles empty input quietly
    assert tool._test_operation_privileges([])["untrash"]["status"] == "unknown"


def test_check_privileges_samples_single_item(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    fake_service = MagicMock()
    fake_service.files.return_value.list.return_value.execute.return_value = {"files": []}
    tool.auth._get_service = MagicMock(return_value=fake_service)

    tool.items = [MagicMock(id="one"), MagicMock(id="two"), MagicMock(id="three")]
    captured = {}

    def fake_test_operation_privileges(items):
        captured["items"] = items
        return {}

    tool.privileges._test_operation_privileges = fake_test_operation_privileges

    checks = tool._check_privileges()

    assert checks["drive_access"] is True
    assert len(captured["items"]) == 1
    assert captured["items"][0].id == "one"


def test_validate_file_ids_delegates_to_discovery(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))
    tool.discovery._validate_file_ids = MagicMock(return_value=True)

    assert tool._validate_file_ids() is True
    tool.discovery._validate_file_ids.assert_called_once_with()


def test_prepare_recovery_overwrite_alone_does_not_clear_state(tmp_path, monkeypatch, capsys):
    """v1.23.0: --overwrite is now strictly a local-file collision policy.
    It must not clear processed_items, nor print a deprecation warning."""
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.overwrite = True
    args.no_emoji = True
    tool = DriveTrashRecoveryTool(args)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = ["id-1", "id-2", "id-3"]

    tool._prepare_recovery(streaming_mode=True)

    assert tool.state_manager.state.processed_items == ["id-1", "id-2", "id-3"]
    captured = capsys.readouterr()
    assert "no longer implies" not in captured.err
    assert "v1.23.0" not in captured.err


def test_prepare_recovery_does_not_clear_when_overwrite_not_set(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = ["id-1", "id-2"]

    tool._prepare_recovery(streaming_mode=True)

    assert tool.state_manager.state.processed_items == ["id-1", "id-2"]


def test_prepare_recovery_fresh_run_resets_state_and_regenerates_identity(
    tmp_path, monkeypatch, capsys
):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.fresh_run = True
    args.no_emoji = True
    tool = DriveTrashRecoveryTool(args)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = ["id-1", "id-2"]
    tool.state_manager.state.run_id = "old-run-id"
    tool.state_manager.state.start_time = "2020-01-01T00:00:00+00:00"
    tool.state_manager.state.total_found = 42
    tool.state_manager.state.last_checkpoint = "2020-01-01T00:00:01+00:00"

    tool._prepare_recovery(streaming_mode=True)

    # All identity fields wiped, processed_items cleared
    assert tool.state_manager.state.processed_items == []
    assert tool.state_manager.state.run_id == ""
    assert tool.state_manager.state.start_time == ""
    assert tool.state_manager.state.last_checkpoint == ""
    # schema_version preserved (now defaults to 2)
    assert tool.state_manager.state.schema_version == 2
    # owner_pid field has been retired
    assert not hasattr(tool.state_manager.state, "owner_pid")
    captured = capsys.readouterr()
    assert "no longer implies" not in captured.err


def test_prepare_recovery_fresh_run_clears_failed_file(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    failed_file = tmp_path / "failed.csv"
    failed_file.write_text("source_folder_id,file_id,target_path\nfid,abc,/p\n")

    args = _build_dummy_args(tmp_path)
    args.fresh_run = True
    args.no_emoji = True
    args.failed_file = str(failed_file)

    tool = DriveTrashRecoveryTool(args)
    tool.ops._failed_file_path = str(failed_file)
    tool.auth.authenticate = MagicMock(return_value=True)

    tool._prepare_recovery(streaming_mode=True)

    lines = failed_file.read_text(encoding="utf-8").splitlines()
    assert lines == ["source_folder_id,file_id,target_path"]


def test_prepare_recovery_fresh_run_initialize_regenerates_identity(tmp_path, monkeypatch):
    """After _reset_state + _initialize_recovery_state, the run gets a fresh run_id/start_time and a scope."""
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.fresh_run = True
    args.no_emoji = True
    tool = DriveTrashRecoveryTool(args)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = ["id-1"]
    tool.state_manager.state.run_id = "old-id"
    tool.state_manager.state.start_time = "2020-01-01T00:00:00+00:00"

    tool._prepare_recovery(streaming_mode=True)
    tool._initialize_recovery_state()

    assert tool.state_manager.state.run_id != "old-id"
    assert tool.state_manager.state.run_id  # not empty
    assert tool.state_manager.state.start_time != "2020-01-01T00:00:00+00:00"
    assert tool.state_manager.state.start_time  # not empty
    # scope is populated for fresh runs too
    assert tool.state_manager.state.scope is not None


def test_prepare_recovery_overwrite_with_fresh_run_still_resets_state(
    tmp_path, monkeypatch, capsys
):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.overwrite = True
    args.fresh_run = True
    args.no_emoji = True
    tool = DriveTrashRecoveryTool(args)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = ["id-1"]

    tool._prepare_recovery(streaming_mode=True)

    captured = capsys.readouterr()
    assert "no longer implies" not in captured.err
    # fresh-run path still resets state
    assert tool.state_manager.state.processed_items == []


# ---------------------------------------------------------------------------
# Logging setup tests
# ---------------------------------------------------------------------------


def test_log_file_created_with_parent_dirs(tmp_path, monkeypatch):
    """FileHandler is added and its parent directories are created when --log-file is set."""
    import logging

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    log_path = tmp_path / "nested" / "dir" / "run.log"
    args = _build_dummy_args(tmp_path)
    args.log_file = str(log_path)

    # Reset root handlers so _setup_logging takes effect
    root = logging.getLogger()
    original_handlers = root.handlers[:]
    root.handlers.clear()

    try:
        tool = DriveTrashRecoveryTool(args)
        assert log_path.parent.exists(), "parent directories should have been created"
        assert log_path.exists() or any(
            isinstance(h, logging.FileHandler) for h in logging.getLogger().handlers
        )
    finally:
        for h in list(root.handlers):
            if isinstance(h, logging.FileHandler):
                h.close()
            root.removeHandler(h)
        root.handlers.extend(original_handlers)


def test_no_log_file_when_not_specified(tmp_path, monkeypatch):
    """No FileHandler is added when --log-file is empty."""
    import logging

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.log_file = ""

    root = logging.getLogger()
    original_handlers = root.handlers[:]
    root.handlers.clear()

    try:
        DriveTrashRecoveryTool(args)
        file_handlers = [h for h in root.handlers if isinstance(h, logging.FileHandler)]
        assert file_handlers == [], "no FileHandler expected when log_file is empty"
    finally:
        for h in list(root.handlers):
            root.removeHandler(h)
        root.handlers.extend(original_handlers)


# ---------------------------------------------------------------------------
# --overwrite alone no longer clears the failed-file (v1.23.0)
# ---------------------------------------------------------------------------


def test_prepare_recovery_overwrite_alone_does_not_clear_failed_file(tmp_path, monkeypatch, capsys):
    """v1.23.0: --overwrite is strictly a local-file collision policy and no
    longer truncates the failed-file CSV. Use --fresh-run for that."""
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    failed_file = tmp_path / "failed.txt"
    failed_file.write_text("/some/previous/path.jpg\n")

    args = _build_dummy_args(tmp_path)
    args.overwrite = True
    args.no_emoji = True
    args.failed_file = str(failed_file)

    tool = DriveTrashRecoveryTool(args)
    tool.ops._failed_file_path = str(failed_file)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = []

    tool._prepare_recovery(streaming_mode=True)

    # File is left untouched on --overwrite alone.
    lines = failed_file.read_text(encoding="utf-8").splitlines()
    assert lines == ["/some/previous/path.jpg"]


def test_prepare_recovery_does_not_clear_failed_file_without_overwrite(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    failed_file = tmp_path / "failed.txt"
    existing = "/some/previous/path.jpg\n"
    failed_file.write_text(existing)

    args = _build_dummy_args(tmp_path)
    args.failed_file = str(failed_file)

    tool = DriveTrashRecoveryTool(args)
    tool.ops._failed_file_path = str(failed_file)
    tool.auth.authenticate = MagicMock(return_value=True)
    tool.state_manager.state.processed_items = []

    tool._prepare_recovery(streaming_mode=True)

    assert (
        failed_file.read_text() == existing
    ), "failed-file should not be touched without --overwrite"
