# Python Utils Module

## Overview

The `utils` package provides shared utilities for Python scripts in the My-Scripts repository. It includes modules for error handling, file operations with retry logic, and other common tasks.

## Modules

### error_handling

Provides error handling utilities including decorators, retry logic, and privilege checking.

#### Functions

**`with_error_handling(on_error, log_errors, error_message)`** - Decorator for standardized error handling

```python
from src.python.modules.utils.error_handling import with_error_handling

@with_error_handling(on_error="return_none")
def read_config(path):
    with open(path) as f:
        return f.read()
```

**`with_retry(max_retries, retry_delay, max_backoff, exceptions, log_errors)`** - Decorator for automatic retry

```python
from src.python.modules.utils.error_handling import with_retry

@with_retry(max_retries=5, retry_delay=1.0)
def fetch_data(url):
    return requests.get(url).json()
```

**`retry_operation(operation, description, ...)`** - Execute operation with retry

```python
from src.python.modules.utils.error_handling import retry_operation

retry_operation(
    lambda: shutil.copy("source.txt", "dest.txt"),
    "Copy file",
    max_retries=3
)
```

**`is_elevated()`** - Check if running with admin/root privileges

```python
from src.python.modules.utils.error_handling import is_elevated

if is_elevated():
    print("Running with admin privileges")
```

**`require_elevated(custom_message)`** - Require elevated privileges

```python
from src.python.modules.utils.error_handling import require_elevated

require_elevated("This operation requires administrator rights")
```

**`safe_execute(func, on_error, error_message, log_errors)`** - Execute function with error handling

```python
from src.python.modules.utils.error_handling import safe_execute

result = safe_execute(
    lambda: int("not_a_number"),
    on_error="return_none",
    error_message="Invalid number format"
)
```

**`ErrorContext`** - Context manager for error handling

```python
from src.python.modules.utils.error_handling import ErrorContext

with ErrorContext("Processing data", on_error="continue"):
    process_data()
```

### file_operations

Provides file operation utilities with built-in retry logic.

#### Functions

**`copy_with_retry(source, destination, max_retries, retry_delay, max_backoff)`**

```python
from src.python.modules.utils.file_operations import copy_with_retry

copy_with_retry("source.txt", "dest.txt", max_retries=5)
```

**`move_with_retry(source, destination, max_retries, retry_delay, max_backoff)`**

```python
from src.python.modules.utils.file_operations import move_with_retry

move_with_retry("temp.txt", "archive/temp.txt")
```

**`remove_with_retry(path, max_retries, retry_delay, max_backoff)`**

```python
from src.python.modules.utils.file_operations import remove_with_retry

remove_with_retry("temp.txt")
```

**`is_writable(path)`** - Check if directory is writable

```python
from src.python.modules.utils.file_operations import is_writable

if is_writable("/tmp"):
    print("Directory is writable")
```

**`ensure_directory(path)`** - Create directory if it doesn't exist

```python
from src.python.modules.utils.file_operations import ensure_directory

log_dir = ensure_directory("logs/app")
```

**`get_file_size(path)`** - Get file size in bytes

```python
from src.python.modules.utils.file_operations import get_file_size

size = get_file_size("data.txt")
print(f"Size: {size} bytes")
```

**`safe_write_text(path, content, encoding, atomic)`** - Write text safely

```python
from src.python.modules.utils.file_operations import safe_write_text

safe_write_text("config.txt", "key=value", atomic=True)
```

**`safe_append_text(path, content, encoding, max_retries, retry_delay)`** - Append text with retry

```python
from src.python.modules.utils.file_operations import safe_append_text

safe_append_text("app.log", "2025-11-20 INFO: Started\\n")
```

## Installation

The modules are part of the My-Scripts repository and can be imported directly:

```python
from src.python.modules.utils import error_handling, file_operations
```

Or import specific functions:

```python
from src.python.modules.utils.error_handling import with_retry, is_elevated
from src.python.modules.utils.file_operations import copy_with_retry, ensure_directory
```

## Migration Examples

### Before (Manual Error Handling)

```python
try:
    data = fetch_data(url)
except Exception as e:
    logging.error(f"Failed to fetch data: {e}")
    raise
```

### After (Using error_handling)

```python
from src.python.modules.utils.error_handling import with_error_handling

@with_error_handling(error_message="Failed to fetch data")
def fetch_data(url):
    return requests.get(url).json()
```

### Before (Manual Retry Logic)

```python
for attempt in range(3):
    try:
        shutil.copy(source, dest)
        break
    except Exception as e:
        if attempt >= 2:
            raise
        time.sleep(2)
```

### After (Using file_operations)

```python
from src.python.modules.utils.file_operations import copy_with_retry

copy_with_retry(source, dest, max_retries=3)
```

### Before (Manual Elevation Check)

```python
import os
import platform

if platform.system() == "Windows":
    import ctypes
    is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
else:
    is_admin = os.geteuid() == 0

if not is_admin:
    raise PermissionError("Requires admin privileges")
```

### After (Using error_handling)

```python
from src.python.modules.utils.error_handling import require_elevated

require_elevated()
```

## Retry Behavior

All retry functions use **exponential backoff**:

```
delay = min(retry_delay * 2^(attempt-1), max_backoff)
```

Example with `retry_delay=2.0` and `max_backoff=60.0`:
- Attempt 1: 2.0 seconds
- Attempt 2: 4.0 seconds
- Attempt 3: 8.0 seconds
- Attempt 4: 16.0 seconds
- Attempt 5: 32.0 seconds
- Attempt 6+: 60.0 seconds (capped)

## Logging

The modules use Python's standard `logging` module. Configure logging in your script:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

## Version History

### 1.0.0 (2025-11-20)
- Initial release
- `error_handling` module with decorators and retry logic
- `file_operations` module with file operation utilities
- Cross-platform support (Windows, Linux, macOS)
- Exponential backoff retry logic
- Integration with Python logging framework

## License

Apache License 2.0
