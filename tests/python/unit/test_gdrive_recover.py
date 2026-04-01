"""Tests for Google Drive recovery helpers."""

from unittest.mock import MagicMock
from gdrive_recover import get_recoverable_files


def test_identify_recoverable_files(mocker):
    """Only trashed files should be identified for recovery."""

    service = mocker.Mock()
    files_resource = mocker.Mock()
    service.files.return_value = files_resource

    files_resource.list.return_value.execute.return_value = {
        "files": [
            {"id": "1", "name": "deleted.txt", "trashed": True},
            {"id": "2", "name": "normal.txt", "trashed": False},
        ],
        "nextPageToken": None,
    }

    recoverable = get_recoverable_files(service)

    assert len(recoverable) == 1
    assert recoverable[0]["name"] == "deleted.txt"


def _build_dummy_args(tmp_path):
    class Args:
        pass

    args = Args()
    args.verbose = 0
    args.log_file = str(tmp_path / "test.log")
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
    assert tool._is_valid_file_id_format("1a2b3c4d5e6f7g8h9i0j1k2l3") is True
    assert tool._is_valid_file_id_format("short") is False


def test_build_query_with_extensions(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.extensions = ["jpg", ".tar.gz", "UNKNOWN"]
    tool = DriveTrashRecoveryTool(args)

    q = tool._build_query()
    assert "trashed=true" in q
    assert "mimeType" in q


def test_matches_extension_filter_and_time_filter(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.extensions = ["txt"]
    args.after_date = "2020-01-01T00:00:00Z"
    tool = DriveTrashRecoveryTool(args)

    assert tool._matches_extension_filter("document.txt") is True
    assert tool._matches_extension_filter("document.pdf") is False

    item = {"modifiedTime": "2021-01-01T00:00:00Z"}
    assert tool._matches_time_filter(item) is True
    item_bad = {"modifiedTime": "not-a-date"}
    assert tool._matches_time_filter(item_bad) is True


def test_generate_target_path(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.download_dir = str(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    class DummyItem:
        id = "abc"
        name = "my*file?.txt"

    p1 = tool._generate_target_path(DummyItem)
    assert str(tmp_path) in p1

    (tmp_path / "myfile.txt").write_text("x")
    item2 = MagicMock(id="abc", name="myfile.txt")
    p2 = tool._generate_target_path(item2)
    assert p2 != str(tmp_path / "myfile.txt")


def test_report_validation_outcome(monkeypatch, tmp_path):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    buckets = {"ok": ["1"], "invalid": [], "not_found": [], "no_access": []}
    assert tool._report_validation_outcome(buckets, 0, []) is True

    buckets2 = {"ok": [], "invalid": ["bad"], "not_found": [], "no_access": []}
    assert tool._report_validation_outcome(buckets2, 1, ["1"]) is False


def test_get_recoverable_files_pagination():
    from gdrive_recover import get_recoverable_files

    service = MagicMock()
    files_resource = MagicMock()
    service.files.return_value = files_resource
    files_resource.list.return_value.execute.side_effect = [
        {"files": [{"id": "1", "name": "deleted1", "trashed": True}], "nextPageToken": "t1"},
        {"files": [{"id": "2", "name": "deleted2", "trashed": True}], "nextPageToken": None},
    ]

    recoverable = get_recoverable_files(service)
    assert len(recoverable) == 2


def test_handle_prefetch_error_retry_and_terminal(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))

    class FakeHttpError(Exception):
        pass

    fake_error = FakeHttpError("oops")
    fake_error.resp = MagicMock(status=429)

    monkeypatch.setattr("gdrive_recover.HttpError", FakeHttpError)

    buckets = {"ok": [], "invalid": [], "not_found": [], "no_access": []}
    transient_errors = [0]
    transient_ids = []
    err_count = [0]

    # first attempt should request retry
    should_retry = tool._handle_prefetch_error(
        "fid", 429, fake_error, 0, buckets, transient_errors, transient_ids, err_count
    )
    assert should_retry is False

    # terminal not-found
    fake_error2 = FakeHttpError("no")
    fake_error2.resp = MagicMock(status=404)
    assert (
        tool._handle_prefetch_error(
            "fid", 404, fake_error2, 0, buckets, transient_errors, transient_ids, err_count
        )
        is True
    )
    assert "fid" in buckets["not_found"]


def test_fetch_file_metadata_error_path(tmp_path, monkeypatch):
    from gdrive_recover import DriveTrashRecoveryTool

    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    tool = DriveTrashRecoveryTool(_build_dummy_args(tmp_path))

    class FakeHttpError(Exception):
        pass

    monkeypatch.setattr("gdrive_recover.HttpError", FakeHttpError)

    class FakeRequest:
        def execute(self):
            raise FakeHttpError("bad request")

    service = MagicMock()
    service.files.return_value.get.return_value = FakeRequest()

    data, non_trashed, err = tool._fetch_file_metadata(service, "fid", "id")
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
    tool._fetch_files_page = MagicMock(side_effect=[first_page, second_page])

    items = tool._discover_via_query("trashed=true")
    assert len(items) == 1


def test_rate_limit_and_rl_diag(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    args.max_rps = 1
    args.burst = 1
    args.rl_diagnostics = True
    args.verbose = 2
    tool = DriveTrashRecoveryTool(args)

    # Force token bucket mode path.
    tool._rl_diag_enabled = True
    # first call initializes bucket and consumes token
    tool._rate_limit()
    assert tool._tb_initialized is True

    # test legacy pacing path with burst disabled
    args.burst = 0
    tool._rate_limit()

    # explicit rl_diag_tick call for formatting
    tool._rl_diag_tick(1.0, 0.5, 1.0)


def test_error_formatting_and_status_extract(tmp_path, monkeypatch):
    monkeypatch.setattr("gdrive_recover.DriveAuthManager", MagicMock())
    from gdrive_recover import DriveTrashRecoveryTool

    args = _build_dummy_args(tmp_path)
    tool = DriveTrashRecoveryTool(args)

    class FakeHttpError:
        def __init__(self):
            self.resp = MagicMock(status=502)
            self.content = b"bad"

    monkeypatch.setattr("gdrive_recover.HttpError", FakeHttpError)

    e = FakeHttpError()
    # Ensure resp path is used for status extraction
    assert tool._extract_status_from_http_error(e) == 502
    assert tool._extract_status_from_http_error(ValueError("x")) is None

    assert (
        tool._format_fetch_metadata_error_with_context(ValueError("bad"), None, "f1")
        == "files.get(fileId=f1) failed: bad"
    )
    assert "HTTP 503" in tool._format_fetch_metadata_error_with_context(
        ValueError("bad"), 503, "f1"
    )


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

    # monkeypatch _get_file_info to return our fake_file when called
    tool._get_file_info = MagicMock(return_value=fake_file)
    status = tool._check_untrash_privilege("fid")
    assert status["status"] == "pass"

    status = tool._check_download_privilege("fid")
    assert status["status"] == "fail"

    trash_status, delete_status = tool._check_trash_delete_privileges("fid", "pass")
    assert trash_status["status"] == "pass"
    assert delete_status["status"] == "fail"

    # ensure _test_operation_privileges handles empty input quietly
    assert tool._test_operation_privileges([])["untrash"]["status"] == "unknown"
