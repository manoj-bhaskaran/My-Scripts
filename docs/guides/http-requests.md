# HTTP Request Best Practices

## Timeout Configuration

All HTTP requests must include timeout parameters to prevent indefinite hangs.

### Timeout Tuple Format

```python
timeout = (connect_timeout, read_timeout)
```

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

```python
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
```

### Error Handling

```python
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
```

### Testing Timeout Behavior

```python
def test_request_timeout(mocker):
    """Test that timeouts are handled gracefully."""
    mock = mocker.patch('requests.get')
    mock.side_effect = Timeout("Connection timed out")

    with pytest.raises(Timeout):
        my_api_call()

    # Verify timeout was specified
    assert mock.call_args[1]['timeout'] is not None
```

---

## Best Practices

1. **Always use timeout tuples** - Separate connect and read timeouts for better control
2. **Set reasonable defaults** - Use `(5, 30)` for most operations
3. **Calculate dynamically for large files** - Base timeout on file size
4. **Handle timeout exceptions** - Don't let timeouts crash your application
5. **Log timeout events** - Track when timeouts occur for monitoring
6. **Test timeout handling** - Verify your code handles timeouts gracefully
7. **Document timeout values** - Explain why specific timeout values were chosen

---

## Common Patterns

### Simple GET Request

```python
import requests
from requests.exceptions import Timeout, RequestException

def fetch_data(url: str) -> dict:
    """Fetch JSON data from API with timeout."""
    try:
        response = requests.get(url, timeout=(5, 30))
        response.raise_for_status()
        return response.json()
    except Timeout:
        logger.error(f"Timeout fetching data from {url}")
        raise
    except RequestException as e:
        logger.error(f"Error fetching data from {url}: {e}")
        raise
```

### File Upload with Dynamic Timeout

```python
import os
import requests
from typing import Tuple

def upload_file(file_path: str, upload_url: str) -> dict:
    """Upload file with size-based timeout."""
    # Calculate timeout based on file size
    file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
    connect_timeout = 10
    read_timeout = max(60, int(file_size_mb * 2))
    timeout = (connect_timeout, read_timeout)
    
    logger.info(f"Uploading {file_path} ({file_size_mb:.2f} MB) with timeout {timeout}")
    
    try:
        with open(file_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(upload_url, files=files, timeout=timeout)
            response.raise_for_status()
            return response.json()
    except Timeout:
        logger.error(f"Upload timed out after {timeout[1]} seconds")
        raise
    except RequestException as e:
        logger.error(f"Upload failed: {e}")
        raise
```

### Retry with Timeout

```python
from src.python.modules.utils.error_handling import with_retry
from requests.exceptions import Timeout

@with_retry(max_retries=3, retry_delay=2.0, exceptions=(Timeout, RequestException))
def fetch_with_retry(url: str) -> dict:
    """Fetch data with automatic retry on timeout."""
    response = requests.get(url, timeout=(5, 30))
    response.raise_for_status()
    return response.json()
```

---

## References

- [Requests Documentation - Timeouts](https://requests.readthedocs.io/en/latest/user/advanced/#timeouts)
- [Error Handling Module](../../src/python/modules/utils/error_handling.py)
- [CONTRIBUTING.md - HTTP Request Guidelines](../../CONTRIBUTING.md#http-request-guidelines)
