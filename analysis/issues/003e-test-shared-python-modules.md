# Issue #003e: Test Shared Python Modules

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Phase 2 - Core Modules
**Effort**: 8 hours

## Description
Add comprehensive tests for shared Python modules that are used across multiple scripts. High reuse means high impact from bugs.

## Scope
- `src/python/modules/logging/python_logging_framework.py` - Logging infrastructure
- `src/python/modules/utils/error_handling.py` - Retry decorators
- `src/python/modules/utils/file_operations.py` - File utilities

## Implementation

### Logging Framework Tests
```python
# tests/python/unit/test_logging_framework.py (expand existing)

def test_initialise_logger_creates_logger():
    """Test logger initialization."""
    logger = initialise_logger("test_module")
    assert logger.name == "test_module"
    assert isinstance(logger, logging.Logger)

def test_logger_uses_custom_log_dir(tmp_path):
    """Test custom log directory."""
    log_dir = tmp_path / "logs"
    logger = initialise_logger("test", log_dir=str(log_dir))

    # Log something
    log_info(logger, "Test message")

    # Verify log file created in custom dir
    assert log_dir.exists()
    log_files = list(log_dir.glob("*.log"))
    assert len(log_files) > 0

def test_log_with_metadata(tmp_path):
    """Test logging with structured metadata."""
    log_file = tmp_path / "test.log"
    logger = initialise_logger("test", log_dir=str(tmp_path))

    metadata = {"user_id": 123, "action": "delete"}
    log_info(logger, "User action", metadata=metadata)

    # Verify metadata in log file
    content = log_file.read_text()
    assert "user_id" in content
    assert "123" in content
```

### Error Handling Tests
```python
# tests/python/unit/test_error_handling.py (expand existing)

def test_retry_decorator_retries_on_failure():
    """Test retry decorator retries failed operations."""
    mock_func = Mock(side_effect=[ValueError, ValueError, "success"])

    @retry_on_exception(max_retries=3, delay=0.01)
    def failing_func():
        return mock_func()

    result = failing_func()

    assert result == "success"
    assert mock_func.call_count == 3

def test_retry_decorator_respects_max_retries():
    """Test retry decorator stops after max retries."""
    mock_func = Mock(side_effect=ValueError("Always fails"))

    @retry_on_exception(max_retries=3, delay=0.01)
    def failing_func():
        return mock_func()

    with pytest.raises(ValueError):
        failing_func()

    assert mock_func.call_count == 3

def test_retry_decorator_with_custom_exceptions():
    """Test retry only on specific exceptions."""
    @retry_on_exception(max_retries=3, delay=0.01, exceptions=(ValueError,))
    def func():
        raise TypeError("Not retryable")

    with pytest.raises(TypeError):
        func()

    # Should fail immediately, not retry

def test_exponential_backoff():
    """Test exponential backoff between retries."""
    import time

    call_times = []
    def track_time():
        call_times.append(time.time())
        raise ValueError("Fail")

    @retry_on_exception(max_retries=3, delay=0.1, backoff=2.0)
    def failing_func():
        return track_time()

    with pytest.raises(ValueError):
        failing_func()

    # Verify delays increase exponentially
    delays = [call_times[i+1] - call_times[i] for i in range(len(call_times)-1)]
    assert delays[1] > delays[0] * 1.5  # Approximate check
```

### File Operations Tests
```python
# tests/python/unit/test_file_operations.py (expand existing)

def test_ensure_directory_creates_dir(tmp_path):
    """Test directory creation."""
    new_dir = tmp_path / "new" / "nested" / "dir"

    result = ensure_directory(new_dir)

    assert result.exists()
    assert result.is_dir()

def test_ensure_directory_handles_existing(tmp_path):
    """Test handling of existing directory."""
    existing = tmp_path / "existing"
    existing.mkdir()

    result = ensure_directory(existing)

    assert result.exists()
    # Should not raise error

def test_safe_file_read_handles_missing_file(tmp_path):
    """Test safe file read with missing file."""
    missing = tmp_path / "missing.txt"

    content = safe_file_read(missing, default="default content")

    assert content == "default content"

def test_safe_file_write_creates_parent_dirs(tmp_path):
    """Test file write creates parent directories."""
    nested = tmp_path / "a" / "b" / "c" / "file.txt"

    safe_file_write(nested, "content")

    assert nested.exists()
    assert nested.read_text() == "content"
```

## Acceptance Criteria
- [ ] python_logging_framework.py has 60%+ coverage
- [ ] error_handling.py has 70%+ coverage
- [ ] file_operations.py has 60%+ coverage
- [ ] Edge cases tested
- [ ] Concurrency safety tested (if applicable)
- [ ] All public functions documented and tested

## Benefits
- Validates critical shared infrastructure
- Prevents bugs in widely-used utilities
- Enables confident refactoring
- Documents expected behavior
- High impact due to reuse

## Related
- Issue #003f (PowerShell shared module tests)
- Issue #005 (type hints for these modules)
