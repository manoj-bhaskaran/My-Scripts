# ISSUE-006: Fix Logger Initialization in Python Modules

**Priority:** 🟠 HIGH
**Category:** Code Quality / Runtime Errors
**Estimated Effort:** 4 hours
**Skills Required:** Python, Logging

---

## Problem Statement

Python modules use the logging framework (`plog.log_info()`, `plog.log_warning()`) without initializing the logger first. This causes `AttributeError` when the module is used standalone or when the calling code doesn't initialize logging.

### Current Code

```python
# src/python/modules/auth/google_drive_auth.py
import python_logging_framework as plog

# Uses plog.log_info() without initialization
# Missing: logger = plog.initialise_logger(__name__)
```

### Impact

- 💥 **Runtime Errors:** Module crashes when logger not initialized
- 🔄 **Inconsistent Behavior:** Works only when caller initializes logging
- 📦 **Not Self-contained:** Module depends on external initialization
- 🐛 **Hard to Debug:** Cryptic AttributeError messages

---

## Acceptance Criteria

- [ ] Fix `src/python/modules/auth/google_drive_auth.py`
- [ ] Fix all other Python modules using logging framework
- [ ] Each module initializes its own logger
- [ ] Logger uses module's `__name__` for identification
- [ ] Update module documentation with logging usage
- [ ] Add tests verifying logger initialization
- [ ] All existing functionality continues to work
- [ ] No breaking changes to module API

---

## Implementation Plan

### Step 1: Fix google_drive_auth.py (1 hour)

```python
# src/python/modules/auth/google_drive_auth.py
import os
from pathlib import Path
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
import python_logging_framework as plog

# Initialize logger for this module
logger = plog.initialise_logger(__name__)

# Configuration (from ISSUE-001)
TOKEN_FILE = os.getenv('GDRIVE_TOKEN_PATH', 
    str(Path.home() / 'Documents' / 'Scripts' / 'drive_token.json'))
CREDENTIALS_FILE = os.getenv('GDRIVE_CREDENTIALS_PATH',
    str(Path.home() / 'Documents' / 'Scripts' / 'credentials.json'))

SCOPES = ['https://www.googleapis.com/auth/drive']

def get_credentials():
    """Get Google Drive API credentials."""
    creds = None
    
    if os.path.exists(TOKEN_FILE):
        plog.log_info(logger, f"Loading token from {TOKEN_FILE}")
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            plog.log_info(logger, "Refreshing expired token")
            creds.refresh(Request())
        else:
            plog.log_info(logger, "Starting OAuth flow")
            flow = InstalledAppFlow.from_client_secrets_file(
                CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials
        plog.log_info(logger, f"Saving token to {TOKEN_FILE}")
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    
    plog.log_info(logger, "Credentials obtained successfully")
    return creds
```

### Step 2: Find All Modules Using Logging (30 minutes)

```bash
# Search for Python files using plog without initialization
grep -r "plog\\.log_" src/python/modules/ --include="*.py" | \
    grep -v "initialise_logger" | \
    cut -d: -f1 | sort -u
```

Expected files to fix:
- `src/python/modules/auth/google_drive_auth.py`
- `src/python/modules/cloud/cloudconvert_utils.py`
- `src/python/recovery/gdrive_recover.py`

### Step 3: Fix All Identified Modules (1.5 hours)

Apply same pattern to each module:

```python
# Standard pattern for all modules
import python_logging_framework as plog

# Initialize logger (add at module level)
logger = plog.initialise_logger(__name__)

# Use logger in all function calls
def some_function():
    plog.log_info(logger, "Starting operation")
    # ... function code ...
    plog.log_error(logger, f"Error occurred: {error}")
```

### Step 4: Add Tests (1 hour)

```python
# tests/python/unit/test_logger_initialization.py
import pytest
import importlib
import logging

def test_google_drive_auth_has_logger():
    """Verify google_drive_auth initializes logger."""
    from src.python.modules.auth import google_drive_auth
    
    # Module should have a logger attribute
    assert hasattr(google_drive_auth, 'logger')
    assert isinstance(google_drive_auth.logger, logging.Logger)
    assert google_drive_auth.logger.name == 'src.python.modules.auth.google_drive_auth'

def test_module_can_log_without_external_init():
    """Verify module can log without external initialization."""
    from src.python.modules.auth import google_drive_auth
    
    # This should not raise AttributeError
    try:
        # Module's logger should work
        assert google_drive_auth.logger is not None
    except AttributeError:
        pytest.fail("Module logger not initialized")

def test_all_python_modules_have_logger():
    """Verify all modules using plog have initialized logger."""
    modules_to_check = [
        'src.python.modules.auth.google_drive_auth',
        # Add other modules here
    ]
    
    for module_name in modules_to_check:
        module = importlib.import_module(module_name)
        assert hasattr(module, 'logger'), f"{module_name} missing logger"
        assert isinstance(module.logger, logging.Logger)
```

### Step 5: Update Documentation (30 minutes)

Add to each module's docstring:

```python
"""
Google Drive Authentication Module

Handles OAuth2 authentication flow for Google Drive API.

Logging:
    This module initializes its own logger using the python_logging_framework.
    All operations are logged with appropriate severity levels.
    
    Example:
        >>> from src.python.modules.auth import google_drive_auth
        >>> creds = google_drive_auth.get_credentials()
        # Logs will appear in logs/google_drive_auth_YYYYMMDD.log

Configuration:
    Set environment variables:
    - GDRIVE_CREDENTIALS_PATH: Path to credentials.json
    - GDRIVE_TOKEN_PATH: Path to store token.json
"""
```

### Step 6: Verification (30 minutes)

```bash
# Test each module can be imported and used standalone
python -c "from src.python.modules.auth import google_drive_auth; print('OK')"

# Run all tests
pytest tests/python/unit/test_logger_initialization.py -v

# Verify logging works
python -c "
from src.python.modules.auth import google_drive_auth
import python_logging_framework as plog
# Module should log without errors
"
```

---

## Testing Strategy

### Unit Tests
- Verify each module has logger attribute
- Verify logger is properly initialized
- Verify logger has correct name
- Test standalone module import works

### Integration Tests
- Import and use module without pre-initialization
- Verify logs appear in correct file
- Verify log format is correct

### Manual Testing
- Import each module in Python REPL
- Call functions and verify no AttributeError
- Check log files created correctly

---

## Related Issues

- ISSUE-001: Fix Hardcoded Credentials Paths (same file)
- ISSUE-005: Create Environment Variable System

---

## References

- Python Logging Framework Spec: `docs/specifications/logging_specification.md`
- Python Logging Module Docs: https://docs.python.org/3/library/logging.html

---

## Success Metrics

- [ ] Zero AttributeError on logger access
- [ ] All modules have initialized logger
- [ ] Tests verify logger initialization
- [ ] Modules work standalone without external initialization
- [ ] Documentation updated
- [ ] No breaking changes to existing code

---

**Estimated Time Breakdown:**
- Fix google_drive_auth.py: 1 hour
- Find all affected modules: 0.5 hours
- Fix all identified modules: 1.5 hours
- Add tests: 1 hour
- Update documentation: 0.5 hours
- Verification: 0.5 hours
- **Total: 4 hours**
