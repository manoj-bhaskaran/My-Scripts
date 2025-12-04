# Issue #004b: Update Documentation with Timeout Guidelines

**Parent Issue**: [#004: Missing HTTP Timeouts](./004-missing-http-timeouts.md)
**Effort**: 2-3 hours

## Description
Update documentation and examples to include timeout best practices. Ensure developers add timeouts to new code.

## Scope
- `src/python/modules/utils/error_handling.py` - Fix example code
- `CONTRIBUTING.md` - Add timeout guidelines
- `docs/guides/` - Create HTTP client guide

## Implementation

### Update error_handling.py Examples
```python
# Fix lines 94, 173 in error_handling.py

# Before (line 94)
return requests.get(url).json()

# After
return requests.get(url, timeout=(5, 30)).json()

# Before (line 173)
lambda: requests.get(url).json()

# After
lambda: requests.get(url, timeout=(5, 30)).json()
```

### Add to CONTRIBUTING.md
```markdown
## HTTP Request Guidelines

### Always Specify Timeouts
Never make HTTP requests without a timeout parameter:

\`\`\`python
# ❌ BAD - Can hang indefinitely
response = requests.get(url)

# ✅ GOOD - Will timeout after 30 seconds
response = requests.get(url, timeout=(5, 30))  # (connect, read)
\`\`\`

### Recommended Timeout Values
- **Quick API calls**: `(3, 10)` - Status checks, metadata
- **Standard API calls**: `(5, 30)` - Most operations
- **File uploads**: `(10, 120)` - Small to medium files
- **Large operations**: `(10, 600)` - Large file uploads/downloads

### Handle Timeout Exceptions
\`\`\`python
from requests.exceptions import Timeout

try:
    response = requests.get(url, timeout=(5, 30))
except Timeout:
    logger.error(f"Request to {url} timed out")
    # Handle timeout appropriately
\`\`\`
```

### Create HTTP Client Guide
```markdown
# docs/guides/http-requests.md

# HTTP Request Best Practices

## Timeout Configuration

All HTTP requests must include timeout parameters to prevent indefinite hangs.

### Timeout Tuple Format
\`\`\`python
timeout = (connect_timeout, read_timeout)
\`\`\`

- **connect_timeout**: Maximum time to establish connection (seconds)
- **read_timeout**: Maximum time to wait for response (seconds)

### Guidelines by Operation Type

#### API Endpoints
- GET /status: `(3, 10)` - Quick status checks
- POST /api/resource: `(5, 30)` - Standard CRUD operations
- GET /api/large-data: `(5, 60)` - Large data retrieval

#### File Operations
- Upload < 10MB: `(5, 60)`
- Upload 10-100MB: `(10, 300)`
- Upload > 100MB: `(10, 600)` or calculate dynamically
- Downloads: Same as uploads

#### Third-Party APIs
- CloudConvert: `(10, 300)` for conversions
- Google Drive: `(5, 60)` for API calls
- Generic: `(5, 30)` as default

### Dynamic Timeout Calculation
For file uploads/downloads, calculate based on size:

\`\`\`python
def calculate_timeout(file_size_mb: int) -> Tuple[int, int]:
    """Calculate timeout based on file size."""
    connect_timeout = 10
    # Assume 1 MB/s minimum transfer rate
    read_timeout = max(60, file_size_mb * 2)
    return (connect_timeout, read_timeout)

# Usage
file_size = os.path.getsize(file_path) / (1024 * 1024)  # MB
timeout = calculate_timeout(file_size)
requests.post(upload_url, files=files, timeout=timeout)
\`\`\`

### Error Handling
\`\`\`python
from requests.exceptions import Timeout, RequestException

try:
    response = requests.get(url, timeout=(5, 30))
    response.raise_for_status()
except Timeout as e:
    logger.error(f"Request timed out: {e}")
    # Retry or fail gracefully
except RequestException as e:
    logger.error(f"Request failed: {e}")
    raise
\`\`\`

### Testing Timeout Behavior
\`\`\`python
def test_request_timeout(mocker):
    """Test that timeouts are handled gracefully."""
    mock = mocker.patch('requests.get')
    mock.side_effect = Timeout("Connection timed out")

    with pytest.raises(Timeout):
        my_api_call()

    # Verify timeout was specified
    assert mock.call_args[1]['timeout'] is not None
\`\`\`
```

## Acceptance Criteria
- [ ] error_handling.py examples fixed
- [ ] CONTRIBUTING.md includes timeout section
- [ ] HTTP request guide created
- [ ] Code review checklist updated
- [ ] Pre-commit hook documentation mentions timeouts

## Benefits
- Developers know timeout requirements
- Examples show correct usage
- Review process catches missing timeouts
- Consistent timeout values across codebase

## Effort
2-3 hours

## Related
- Issue #004a (CloudConvert timeouts)
- Issue #004c (re-enable Bandit check)
