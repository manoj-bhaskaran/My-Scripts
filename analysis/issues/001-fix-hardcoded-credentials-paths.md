# ISSUE-001: Fix Hardcoded Credentials Paths

**Priority:** 🔴 CRITICAL
**Category:** Security / Portability
**Estimated Effort:** 4 hours
**Skills Required:** Python, Security Best Practices

---

## Problem Statement

The `google_drive_auth.py` module contains hardcoded credential file paths that expose sensitive information and prevent the code from running on other systems.

### Current Code

```python
# src/python/modules/auth/google_drive_auth.py (Lines 17-18)
TOKEN_FILE = "C:/users/manoj/Documents/Scripts/drive_token.json"
CREDENTIALS_FILE = "C:/Users/manoj/Documents/Scripts/Google Drive JSON/client_secret_616159019059-09mhd30aim0ug4fvim49kjfvjtk3i0dd.json"
```

### Impact

- ⚠️ **Security Risk:** Exposes username and partial credential file names in version control
- 🚫 **Portability:** Code cannot run on other systems or for other users
- 🔧 **Maintainability:** Path changes require code modifications and redeployment

---

## Acceptance Criteria

- [ ] Remove all hardcoded paths from `google_drive_auth.py`
- [ ] Implement environment variable-based configuration
- [ ] Add fallback to default locations using user home directory
- [ ] Create `.env.example` with Google Drive configuration template
- [ ] Update module to validate paths and provide clear error messages
- [ ] Add unit tests for path resolution logic
- [ ] Update documentation with setup instructions
- [ ] Verify module works with environment variables set

---

## Implementation Plan

### Step 1: Update google_drive_auth.py (1.5 hours)

Replace hardcoded paths with environment variable configuration:

```python
# src/python/modules/auth/google_drive_auth.py
import os
from pathlib import Path

# Configuration with environment variable override
def _get_token_file():
    """Get token file path from environment or default location."""
    if 'GDRIVE_TOKEN_PATH' in os.environ:
        return os.environ['GDRIVE_TOKEN_PATH']

    # Default to user's Documents/Scripts directory
    default_path = Path.home() / 'Documents' / 'Scripts' / 'drive_token.json'
    return str(default_path)

def _get_credentials_file():
    """Get credentials file path from environment or default location."""
    if 'GDRIVE_CREDENTIALS_PATH' in os.environ:
        return os.environ['GDRIVE_CREDENTIALS_PATH']

    # Default to user's Documents/Scripts directory
    default_path = Path.home() / 'Documents' / 'Scripts' / 'credentials.json'
    return str(default_path)

TOKEN_FILE = _get_token_file()
CREDENTIALS_FILE = _get_credentials_file()

# Validation function
def validate_credentials():
    """Validate that credential files exist and are accessible."""
    if not Path(CREDENTIALS_FILE).exists():
        raise FileNotFoundError(
            f"Google Drive credentials file not found: {CREDENTIALS_FILE}\n"
            f"Please set GDRIVE_CREDENTIALS_PATH environment variable or "
            f"place credentials.json in {Path.home() / 'Documents' / 'Scripts'}"
        )

    # TOKEN_FILE is created during OAuth flow, so it's OK if it doesn't exist initially
    return True
```

### Step 2: Create .env.example (30 minutes)

```bash
# .env.example

# ==========================================
# Google Drive Integration
# ==========================================
# Path to Google Drive OAuth2 token (created automatically on first auth)
GDRIVE_TOKEN_PATH=/path/to/token.json

# Path to Google Drive API credentials (download from Google Cloud Console)
# Get credentials from: https://console.cloud.google.com/apis/credentials
GDRIVE_CREDENTIALS_PATH=/path/to/credentials.json
```

### Step 3: Create Unit Tests (1.5 hours)

```python
# tests/python/unit/test_google_drive_auth_paths.py
import os
import pytest
from pathlib import Path
from unittest.mock import patch
from src.python.modules.auth import google_drive_auth

class TestPathConfiguration:
    """Test credential path configuration."""

    def test_token_path_from_environment(self):
        """Test token path is read from environment variable."""
        with patch.dict(os.environ, {'GDRIVE_TOKEN_PATH': '/custom/token.json'}):
            # Reload module to pick up new environment
            import importlib
            importlib.reload(google_drive_auth)
            assert google_drive_auth.TOKEN_FILE == '/custom/token.json'

    def test_token_path_default(self):
        """Test token path defaults to user's Documents/Scripts."""
        with patch.dict(os.environ, {}, clear=True):
            import importlib
            importlib.reload(google_drive_auth)
            expected = str(Path.home() / 'Documents' / 'Scripts' / 'drive_token.json')
            assert google_drive_auth.TOKEN_FILE == expected

    def test_credentials_path_from_environment(self):
        """Test credentials path is read from environment variable."""
        with patch.dict(os.environ, {'GDRIVE_CREDENTIALS_PATH': '/custom/creds.json'}):
            import importlib
            importlib.reload(google_drive_auth)
            assert google_drive_auth.CREDENTIALS_FILE == '/custom/creds.json'

    def test_credentials_path_default(self):
        """Test credentials path defaults to user's Documents/Scripts."""
        with patch.dict(os.environ, {}, clear=True):
            import importlib
            importlib.reload(google_drive_auth)
            expected = str(Path.home() / 'Documents' / 'Scripts' / 'credentials.json')
            assert google_drive_auth.CREDENTIALS_FILE == expected

    def test_validate_credentials_missing_file(self):
        """Test validation fails when credentials file is missing."""
        with patch.object(Path, 'exists', return_value=False):
            with pytest.raises(FileNotFoundError) as exc_info:
                google_drive_auth.validate_credentials()
            assert "credentials file not found" in str(exc_info.value).lower()

    def test_validate_credentials_success(self, tmp_path):
        """Test validation succeeds when credentials file exists."""
        # Create temporary credentials file
        creds_file = tmp_path / "credentials.json"
        creds_file.write_text('{"test": "data"}')

        with patch.dict(os.environ, {'GDRIVE_CREDENTIALS_PATH': str(creds_file)}):
            import importlib
            importlib.reload(google_drive_auth)
            assert google_drive_auth.validate_credentials() is True
```

### Step 4: Update Documentation (30 minutes)

Add to `INSTALLATION.md`:

```markdown
### Google Drive Integration Setup

1. **Get Google Drive API Credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google Drive API
   - Create OAuth 2.0 credentials (Desktop app)
   - Download credentials as JSON file

2. **Configure Environment Variables:**
   ```bash
   # Option 1: Set environment variables
   export GDRIVE_CREDENTIALS_PATH="/path/to/credentials.json"
   export GDRIVE_TOKEN_PATH="/path/to/token.json"

   # Option 2: Use default location
   mkdir -p ~/Documents/Scripts
   cp credentials.json ~/Documents/Scripts/
   # token.json will be created automatically on first auth
   ```

3. **Verify Setup:**
   ```python
   from src.python.modules.auth import google_drive_auth
   google_drive_auth.validate_credentials()
   ```
```

### Step 5: Testing & Validation (30 minutes)

```bash
# Run unit tests
pytest tests/python/unit/test_google_drive_auth_paths.py -v

# Test with environment variables
export GDRIVE_CREDENTIALS_PATH="$HOME/Documents/Scripts/credentials.json"
python -c "from src.python.modules.auth import google_drive_auth; print(google_drive_auth.CREDENTIALS_FILE)"

# Test without environment variables (should use default)
unset GDRIVE_CREDENTIALS_PATH
unset GDRIVE_TOKEN_PATH
python -c "from src.python.modules.auth import google_drive_auth; print(google_drive_auth.CREDENTIALS_FILE)"
```

---

## Testing Strategy

### Unit Tests
- Path resolution from environment variables
- Path resolution using defaults
- Validation with missing files
- Validation with existing files

### Integration Tests
- Full OAuth flow with environment variables
- Google Drive API calls with configured paths

### Manual Testing
1. Test on different operating systems (Windows, Linux, macOS)
2. Test with and without environment variables
3. Test with invalid paths (should show clear error)
4. Test with valid paths (should work)

---

## Related Issues

- ISSUE-005: Create Environment Variable System
- ISSUE-007: Fix Hardcoded Paths in PowerShell Scripts
- ISSUE-008: Fix Hardcoded Paths in Documentation

---

## References

- Python pathlib documentation: https://docs.python.org/3/library/pathlib.html
- Python os.environ documentation: https://docs.python.org/3/library/os.html#os.environ
- Google Drive API Python Quickstart: https://developers.google.com/drive/api/quickstart/python

---

## Success Metrics

- [ ] Zero hardcoded paths in google_drive_auth.py
- [ ] Module works on Windows, Linux, and macOS without code changes
- [ ] Clear error messages when configuration is missing
- [ ] All unit tests passing (>95% coverage for new code)
- [ ] Documentation updated with setup instructions
- [ ] Manual testing completed on at least 2 platforms

---

**Estimated Time Breakdown:**
- Code changes: 1.5 hours
- Configuration templates: 0.5 hours
- Unit tests: 1.5 hours
- Documentation: 0.5 hours
- Testing & validation: 0.5 hours
- **Total: 4 hours**
