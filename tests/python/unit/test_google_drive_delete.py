"""Tests for Google Drive root deletion helpers."""

import pytest

from google_drive_root_files_delete import delete_file, get_root_files
from googleapiclient.errors import HttpError


@pytest.fixture
def mock_drive_service(mocker):
    """Provide a mocked Drive service with nested resources."""

    service = mocker.Mock()
    files_resource = mocker.Mock()
    service.files.return_value = files_resource
    return service


def test_get_root_files_excludes_folders(mock_drive_service):
    """Folders should not be yielded even if the API returns them."""

    files_resource = mock_drive_service.files.return_value
    files_resource.list.return_value.execute.return_value = {
        "files": [
            {"id": "1", "name": "file.txt", "mimeType": "text/plain"},
            {
                "id": "2",
                "name": "folder",
                "mimeType": "application/vnd.google-apps.folder",
            },
            {"id": "3", "name": "doc.pdf", "mimeType": "application/pdf"},
        ],
        "nextPageToken": None,
    }

    files = list(get_root_files(mock_drive_service))

    assert len(files) == 2
    assert all(file["mimeType"] != "application/vnd.google-apps.folder" for file in files)


def test_delete_file_handles_api_errors(mock_drive_service, mocker):
    """API errors should be swallowed and reported as False."""

    error = HttpError(resp=mocker.Mock(status=404), content=b"File not found")

    files_resource = mock_drive_service.files.return_value
    files_resource.delete.return_value.execute.side_effect = error

    result = delete_file(mock_drive_service, "file_id", "file.txt")

    assert result is False


def test_delete_file_success(mock_drive_service):
    """Successful deletions should return True and call the API once."""

    files_resource = mock_drive_service.files.return_value
    files_resource.delete.return_value.execute.return_value = None

    result = delete_file(mock_drive_service, "file_id", "file.txt")

    assert result is True
    files_resource.delete.assert_called_once_with(fileId="file_id")


def test_pagination_handles_multiple_pages(mock_drive_service):
    """Pagination should iterate through every page token."""

    files_resource = mock_drive_service.files.return_value
    files_resource.list.return_value.execute.side_effect = [
        {"files": [{"id": "1", "name": "file1.txt"}], "nextPageToken": "token1"},
        {"files": [{"id": "2", "name": "file2.txt"}], "nextPageToken": "token2"},
        {"files": [{"id": "3", "name": "file3.txt"}], "nextPageToken": None},
    ]

    files = list(get_root_files(mock_drive_service))

    assert len(files) == 3
    assert files_resource.list.return_value.execute.call_count == 3
