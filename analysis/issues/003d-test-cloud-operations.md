# Issue #003d: Test Destructive Cloud Operations

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Phase 1 - Critical Paths
**Effort**: 6-8 hours

## Description
Add tests for Google Drive operations that delete or modify files. These are high-risk operations that require thorough testing to prevent accidental data loss.

## Scope
- `src/python/cloud/google_drive_root_files_delete.py` - Bulk file deletion
- `src/python/cloud/gdrive_recover.py` - File recovery
- File selection logic
- Deletion confirmation

## Implementation

### Mock Google Drive API
```python
# tests/python/unit/test_google_drive_delete.py

@pytest.fixture
def mock_drive_service(mocker):
    """Mock Google Drive API service."""
    service = mocker.Mock()
    return service

def test_get_root_files_excludes_folders(mock_drive_service):
    """Test that folders are not included in deletion list."""
    # Mock API response
    mock_drive_service.files().list().execute.return_value = {
        'files': [
            {'id': '1', 'name': 'file.txt', 'mimeType': 'text/plain'},
            {'id': '2', 'name': 'folder', 'mimeType': 'application/vnd.google-apps.folder'},
            {'id': '3', 'name': 'doc.pdf', 'mimeType': 'application/pdf'},
        ],
        'nextPageToken': None
    }

    files = list(get_root_files(mock_drive_service))

    # Only non-folder files returned
    assert len(files) == 2
    assert all(f['mimeType'] != 'application/vnd.google-apps.folder' for f in files)

def test_delete_file_handles_api_errors(mock_drive_service):
    """Test graceful handling of API errors during deletion."""
    from googleapiclient.errors import HttpError

    # Mock API to raise error
    error = HttpError(
        resp=mocker.Mock(status=404),
        content=b'File not found'
    )
    mock_drive_service.files().delete().execute.side_effect = error

    result = delete_file(mock_drive_service, 'file_id', 'file.txt')

    # Should return False, not crash
    assert result == False

def test_delete_file_success(mock_drive_service, caplog):
    """Test successful file deletion."""
    mock_drive_service.files().delete().execute.return_value = None

    result = delete_file(mock_drive_service, 'file_id', 'file.txt')

    assert result == True
    mock_drive_service.files().delete.assert_called_once_with(fileId='file_id')

def test_pagination_handles_multiple_pages(mock_drive_service):
    """Test that pagination correctly processes all pages."""
    # Mock multiple pages of results
    mock_drive_service.files().list().execute.side_effect = [
        {'files': [{'id': '1', 'name': 'file1.txt'}], 'nextPageToken': 'token1'},
        {'files': [{'id': '2', 'name': 'file2.txt'}], 'nextPageToken': 'token2'},
        {'files': [{'id': '3', 'name': 'file3.txt'}], 'nextPageToken': None},
    ]

    files = list(get_root_files(mock_drive_service))

    assert len(files) == 3
    assert mock_drive_service.files().list().execute.call_count == 3
```

### Test Recovery Logic
```python
# tests/python/unit/test_gdrive_recover.py

def test_identify_recoverable_files(mock_drive_service):
    """Test identification of files that can be recovered."""
    # Mock trashed files
    mock_drive_service.files().list().execute.return_value = {
        'files': [
            {'id': '1', 'name': 'deleted.txt', 'trashed': True},
            {'id': '2', 'name': 'normal.txt', 'trashed': False},
        ]
    }

    recoverable = get_recoverable_files(mock_drive_service)

    assert len(recoverable) == 1
    assert recoverable[0]['name'] == 'deleted.txt'
```

## Acceptance Criteria
- [ ] File selection logic tested
- [ ] Folder exclusion verified
- [ ] API error handling tested
- [ ] Pagination tested with multiple pages
- [ ] Recovery logic tested
- [ ] Coverage for cloud scripts > 40%
- [ ] No actual API calls in tests (all mocked)

## Benefits
- Prevents accidental bulk deletion
- Validates folder exclusion
- Tests error recovery
- Safe to run without API credentials

## Related
- Issue #003e (shared module tests)
- Issue #004 (HTTP timeouts needed for API calls)
