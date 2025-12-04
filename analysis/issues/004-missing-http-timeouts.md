# Issue #004: Missing HTTP Timeouts in Python Requests

## Severity
**Medium-High** - Can cause scripts to hang indefinitely

## Category
Security / Reliability / Availability

## Description
Multiple Python scripts using the `requests` library do not specify timeout parameters. This can cause scripts to hang indefinitely if:
- Remote server is unresponsive
- Network connectivity issues occur
- DNS resolution fails
- Server accepts connection but never responds

According to the repository's own security configuration in `pyproject.toml`, this is a known issue:
```toml
# B113: requests without timeout (should add timeouts but not blocking)
skips = ["B113"]
```

The Bandit security scanner (B113) is currently configured to skip this check, but the comment acknowledges it "should add timeouts."

## Locations
Found in 6 locations:

### 1. **src/python/cloud/cloudconvert_utils.py**
Multiple requests without timeouts:

```python
# Line 66 - POST request
response = requests.post(url, json=payload, headers=headers)

# Line 104 - POST request with file upload
upload_response = requests.post(upload_url, data=local_parameters, files=files)

# Line 176 - POST request
response = requests.post(url, json=payload, headers=headers)

# Line 205 - GET request
response = requests.get(url, headers=headers)
```

**Context**: CloudConvert API integration for file conversions
**Impact**: Script can hang indefinitely waiting for CloudConvert API response

### 2. **src/python/modules/utils/error_handling.py**
Example code in documentation:

```python
# Line 94 - Example in docstring
return requests.get(url).json()

# Line 173 - Example in docstring
lambda: requests.get(url).json()
```

**Context**: Documentation examples for retry decorator
**Impact**: Examples may be copied by developers, propagating the issue

## Impact

### Security Implications
- **Denial of Service (DoS)**: Hung processes consume system resources
- **Resource Exhaustion**: Multiple hung requests can exhaust file descriptors, memory
- **Cascade Failures**: Hung scripts may block scheduled task execution
- **Unresponsive System**: Windows Task Scheduler may queue up tasks indefinitely

### Operational Impact
- CloudConvert API operations may hang for hours/days
- Scheduled backups or file processing may never complete
- No mechanism to detect or recover from hung requests
- Manual intervention required to kill hung processes

### Business Impact
- **Critical**: Backup scripts that depend on cloud operations may fail silently
- **High**: File conversion workflows become unreliable
- **Medium**: Monitoring cannot detect hung vs. long-running operations

## Root Cause
1. **Default Behavior**: Python `requests` library has no default timeout
2. **Security Tool Override**: Bandit B113 check is explicitly skipped
3. **Documentation Gap**: Examples in error_handling.py don't show timeout usage
4. **Incomplete Migration**: Issue recognized but not addressed

## Recommended Solution

### Solution 1: Add Timeouts to All Requests (Preferred)
Use appropriate timeout values based on operation type:

```python
# For API calls (most common)
TIMEOUT = (5, 30)  # (connect timeout, read timeout) in seconds

# Short timeouts for health checks
response = requests.get(url, headers=headers, timeout=5)

# Longer timeouts for file uploads
response = requests.post(
    upload_url,
    data=parameters,
    files=files,
    timeout=(10, 300)  # 10s connect, 5min read
)

# API operations
response = requests.post(
    url,
    json=payload,
    headers=headers,
    timeout=(5, 30)  # 5s connect, 30s read
)
```

### Solution 2: Create a Wrapped Requests Session
Centralize timeout configuration:

```python
# In utils/http_client.py
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

DEFAULT_TIMEOUT = (5, 30)  # (connect, read) in seconds

class TimeoutHTTPAdapter(HTTPAdapter):
    def __init__(self, *args, timeout=DEFAULT_TIMEOUT, **kwargs):
        self.timeout = timeout
        super().__init__(*args, **kwargs)

    def send(self, request, **kwargs):
        kwargs['timeout'] = kwargs.get('timeout') or self.timeout
        return super().send(request, **kwargs)

def create_session(timeout=DEFAULT_TIMEOUT, retries=3):
    """Create a requests session with default timeout and retry logic."""
    session = requests.Session()
    retry = Retry(total=retries, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    adapter = TimeoutHTTPAdapter(timeout=timeout, max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session

# Usage:
session = create_session(timeout=(10, 60))
response = session.post(url, json=payload, headers=headers)
```

### Solution 3: Use Environment Variable for Timeout
Allow configuration without code changes:

```python
import os

DEFAULT_TIMEOUT = int(os.getenv('HTTP_TIMEOUT', '30'))
CONNECT_TIMEOUT = int(os.getenv('HTTP_CONNECT_TIMEOUT', '5'))

response = requests.get(
    url,
    headers=headers,
    timeout=(CONNECT_TIMEOUT, DEFAULT_TIMEOUT)
)
```

## Implementation Steps

### Phase 1: Critical Paths (Immediate)
1. Add timeouts to `cloudconvert_utils.py`:
   - Line 66: `timeout=(5, 30)` - API job creation
   - Line 104: `timeout=(10, 300)` - File upload (can be large)
   - Line 176: `timeout=(5, 30)` - API conversion task
   - Line 205: `timeout=(5, 30)` - API status check

2. Update retry loop in `cloudconvert_utils.py` to account for timeout exceptions:
   ```python
   from requests.exceptions import Timeout, RequestException

   try:
       response = requests.get(url, headers=headers, timeout=(5, 30))
   except Timeout as e:
       logger.warning(f"Request timed out: {e}")
       # Retry logic here
   except RequestException as e:
       logger.error(f"Request failed: {e}")
       raise
   ```

### Phase 2: Documentation (Week 1)
1. Update `error_handling.py` examples to include timeouts
2. Add timeout guidelines to `CONTRIBUTING.md`
3. Document recommended timeout values for different operation types

### Phase 3: Centralized Solution (Week 2)
1. Create `utils/http_client.py` with wrapped session
2. Migrate `cloudconvert_utils.py` to use wrapped session
3. Update other scripts to use centralized HTTP client

### Phase 4: Re-enable Bandit Check (Week 3)
1. Remove `B113` from skipped checks in `pyproject.toml`
2. Verify CI passes with timeout requirements
3. Update pre-commit hooks to enforce timeout usage

## Recommended Timeout Values

### Operation Type Guidelines
```python
# Quick API calls (status checks, metadata)
TIMEOUT_QUICK = (3, 10)  # 3s connect, 10s read

# Standard API calls (most operations)
TIMEOUT_STANDARD = (5, 30)  # 5s connect, 30s read

# File uploads (small to medium files)
TIMEOUT_UPLOAD = (10, 120)  # 10s connect, 2min read

# Large file operations or conversions
TIMEOUT_LARGE = (10, 600)  # 10s connect, 10min read

# Downloads
TIMEOUT_DOWNLOAD = (10, 300)  # 10s connect, 5min read
```

### CloudConvert-Specific Recommendations
```python
# Job creation
CREATE_JOB_TIMEOUT = (5, 30)

# File upload (depends on file size, add dynamic calculation)
UPLOAD_TIMEOUT = (10, max(300, file_size_mb * 2))

# Conversion task
CONVERT_TASK_TIMEOUT = (5, 30)

# Status polling
STATUS_POLL_TIMEOUT = (5, 15)
```

## Acceptance Criteria
- [ ] All `requests.get/post/put/delete` calls include timeout parameter
- [ ] Timeout exceptions are caught and logged appropriately
- [ ] Documentation examples include timeout usage
- [ ] Contributing guide specifies timeout requirements
- [ ] Bandit B113 check re-enabled and passing
- [ ] CI/CD fails if new code lacks timeouts
- [ ] Timeout values documented for different operation types

## Testing Strategy
```python
# Test timeout behavior
def test_request_with_timeout(mock_requests):
    """Verify requests include timeout parameter."""
    mock_requests.post.side_effect = Timeout("Connection timed out")

    with pytest.raises(Timeout):
        cloudconvert_utils.create_upload_task("fake_key")

    # Verify timeout was specified
    mock_requests.post.assert_called_once()
    call_kwargs = mock_requests.post.call_args[1]
    assert 'timeout' in call_kwargs
    assert call_kwargs['timeout'] == (5, 30)

# Test retry logic handles timeouts
def test_retry_on_timeout(mock_requests):
    """Verify retry logic handles timeout exceptions."""
    mock_requests.get.side_effect = [
        Timeout("Timed out"),
        Timeout("Timed out"),
        Mock(status_code=200, json=lambda: {"status": "finished"})
    ]

    result = poll_task_status(task_id="test", api_key="fake")
    assert result["status"] == "finished"
    assert mock_requests.get.call_count == 3
```

## Related Security Issues
- Connects to issue #003 (test coverage) - needs tests for timeout handling
- Related to error handling module - should demonstrate proper timeout usage
- May expose other reliability issues in cloud integrations

## References
- [Requests Timeouts Documentation](https://requests.readthedocs.io/en/latest/user/advanced/#timeouts)
- [OWASP - Denial of Service](https://owasp.org/www-community/attacks/Denial_of_Service)
- [Bandit B113](https://bandit.readthedocs.io/en/latest/plugins/b113_request_without_timeout.html)
- Repository: `pyproject.toml` (line 27) - Acknowledges this issue

## Priority
**Medium-High** - Should be addressed in next sprint. While not a critical security vulnerability, it can cause operational issues and resource exhaustion. The fix is straightforward and low-risk.

## Effort Estimate
- Phase 1 (Critical paths): 2-4 hours
- Phase 2 (Documentation): 2 hours
- Phase 3 (Centralized solution): 4-6 hours
- Phase 4 (Re-enable checks): 1-2 hours

**Total**: ~10-14 hours (1.5-2 days)

## Notes
- This is a good candidate for pairing with test coverage improvements (Issue #003)
- Consider adding integration tests that verify timeout behavior
- May want to add timeout monitoring/metrics in production
- CloudConvert operations should have configurable timeouts based on expected file sizes
