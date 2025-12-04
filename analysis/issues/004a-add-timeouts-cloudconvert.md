# Issue #004a: Add HTTP Timeouts to CloudConvert Utils

**Parent Issue**: [#004: Missing HTTP Timeouts](./004-missing-http-timeouts.md)
**Effort**: 3-4 hours

## Description
Add timeout parameters to all HTTP requests in `cloudconvert_utils.py`. This is the highest priority as CloudConvert operations can involve large file uploads.

## Scope
- `src/python/cloud/cloudconvert_utils.py`
- 4 requests calls without timeouts (lines 66, 104, 176, 205)

## Implementation

### Add Timeout Constants
```python
# At top of cloudconvert_utils.py
from typing import Tuple

# Timeout constants (connect_timeout, read_timeout) in seconds
TIMEOUT_QUICK = (5, 15)      # Status checks
TIMEOUT_STANDARD = (5, 30)    # API calls
TIMEOUT_UPLOAD = (10, 300)    # File uploads (5 minutes)
TIMEOUT_DOWNLOAD = (10, 300)  # File downloads
```

### Update Request Calls

**Line 66 - Create Upload Task**:
```python
# Before
response = requests.post(url, json=payload, headers=headers)

# After
response = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT_STANDARD)
```

**Line 104 - File Upload**:
```python
# Before
upload_response = requests.post(upload_url, data=local_parameters, files=files)

# After
upload_response = requests.post(
    upload_url,
    data=local_parameters,
    files=files,
    timeout=TIMEOUT_UPLOAD  # Longer timeout for uploads
)
```

**Line 176 - Create Conversion Task**:
```python
# Before
response = requests.post(url, json=payload, headers=headers)

# After
response = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT_STANDARD)
```

**Line 205 - Get Job Status**:
```python
# Before
response = requests.get(url, headers=headers)

# After
response = requests.get(url, headers=headers, timeout=TIMEOUT_QUICK)
```

### Add Timeout Error Handling
```python
from requests.exceptions import Timeout, RequestException

try:
    response = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT_STANDARD)
except Timeout as e:
    plog.log_error(logger, f"Request timed out after {TIMEOUT_STANDARD} seconds: {e}")
    raise
except RequestException as e:
    plog.log_error(logger, f"Request failed: {e}")
    raise
```

## Testing
```python
# tests/python/unit/test_cloudconvert_timeouts.py
def test_create_upload_task_includes_timeout(mocker):
    """Verify timeout parameter is included."""
    mock_post = mocker.patch('requests.post')
    mock_post.return_value.status_code = 201
    mock_post.return_value.json.return_value = {
        'data': {'tasks': [{'id': 'task_id'}]}
    }

    create_upload_task('fake_api_key')

    # Verify timeout was specified
    call_kwargs = mock_post.call_args[1]
    assert 'timeout' in call_kwargs
    assert call_kwargs['timeout'] == TIMEOUT_STANDARD

def test_file_upload_uses_longer_timeout(mocker):
    """Verify file uploads use extended timeout."""
    mock_post = mocker.patch('requests.post')

    handle_file_upload('test.txt', 'http://upload.url', {})

    call_kwargs = mock_post.call_args[1]
    assert call_kwargs['timeout'] == TIMEOUT_UPLOAD
```

## Acceptance Criteria
- [ ] All 4 requests calls have timeout parameters
- [ ] Timeout constants defined at module level
- [ ] Error handling for Timeout exceptions
- [ ] Tests verify timeout parameters included
- [ ] Documentation updated with timeout values

## Benefits
- Prevents indefinite hangs
- Appropriate timeouts for operation type
- Clear error messages on timeout
- Easy to adjust timeouts if needed

## Effort
3-4 hours

## Related
- Issue #004b (timeout error handling documentation)
- Issue #003d (cloud operation tests)
