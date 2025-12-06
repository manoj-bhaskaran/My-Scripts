"""Tests for Google Drive recovery helpers."""

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
