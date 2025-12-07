from src.python.cloud.cloudconvert_utils import (
    TIMEOUT_STANDARD,
    TIMEOUT_UPLOAD,
    create_upload_task,
    handle_file_upload,
)


def test_create_upload_task_includes_timeout(mocker):
    """Verify timeout parameter is included."""
    mock_post = mocker.patch("requests.post")
    mock_post.return_value.status_code = 201
    mock_post.return_value.json.return_value = {"data": {"tasks": [{"id": "task_id"}]}}

    create_upload_task("fake_api_key")

    call_kwargs = mock_post.call_args[1]
    assert "timeout" in call_kwargs
    assert call_kwargs["timeout"] == TIMEOUT_STANDARD


def test_file_upload_uses_longer_timeout(mocker, tmp_path):
    """Verify file uploads use extended timeout."""
    mock_post = mocker.patch("requests.post")

    test_file = tmp_path / "test.txt"
    test_file.write_text("dummy content")

    handle_file_upload(str(test_file), "http://upload.url", {"key": "${filename}"})

    call_kwargs = mock_post.call_args[1]
    assert call_kwargs["timeout"] == TIMEOUT_UPLOAD
