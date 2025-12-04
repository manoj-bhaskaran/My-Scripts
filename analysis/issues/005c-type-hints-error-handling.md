# Issue #005c: Add Type Hints to Error Handling Module

**Parent Issue**: [#005: Missing Python Type Hints](./005-missing-python-type-hints.md)
**Phase**: Phase 2 - Core Modules
**Effort**: 6-8 hours

## Description
Add type hints to retry decorators and error handling utilities. Requires advanced typing features like TypeVar and generic decorators.

## Scope
- `src/python/modules/utils/error_handling.py`
- Retry decorators
- Error handling helpers

## Implementation

### Retry Decorator with Generics
```python
# error_handling.py
from typing import TypeVar, Callable, Optional, Any, Tuple, Type
from functools import wraps
import time

T = TypeVar('T')  # Return type of decorated function

def retry_on_exception(
    max_retries: int = 3,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: Tuple[Type[Exception], ...] = (Exception,)
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """
    Decorator to retry a function on exception.

    Args:
        max_retries: Maximum number of retry attempts
        delay: Initial delay between retries (seconds)
        backoff: Multiplier for delay after each retry
        exceptions: Tuple of exception types to catch

    Returns:
        Decorated function that retries on failure

    Example:
        @retry_on_exception(max_retries=5, delay=1.0, backoff=2.0)
        def fetch_data(url: str) -> dict:
            return requests.get(url, timeout=(5, 30)).json()
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            current_delay = delay
            last_exception: Optional[Exception] = None

            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        time.sleep(current_delay)
                        current_delay *= backoff
                    continue

            # All retries exhausted
            if last_exception:
                raise last_exception
            raise RuntimeError("Unexpected error in retry logic")

        return wrapper
    return decorator
```

### Safe Execution Helper
```python
from typing import Union, Literal

def safe_execute(
    func: Callable[..., T],
    *args: Any,
    default: Optional[T] = None,
    log_errors: bool = True,
    **kwargs: Any
) -> Union[T, None]:
    """
    Execute function safely, returning default on error.

    Args:
        func: Function to execute
        *args: Positional arguments for function
        default: Value to return on error
        log_errors: Whether to log errors
        **kwargs: Keyword arguments for function

    Returns:
        Function result or default value on error

    Example:
        result = safe_execute(risky_operation, arg1, arg2, default={})
    """
    try:
        return func(*args, **kwargs)
    except Exception as e:
        if log_errors:
            import logging
            logging.error(f"Error in {func.__name__}: {e}")
        return default
```

### Error Context Manager
```python
from typing import Iterator, Optional
from contextlib import contextmanager

@contextmanager
def error_handler(
    error_message: str,
    reraise: bool = True,
    log_level: int = logging.ERROR
) -> Iterator[None]:
    """
    Context manager for standardized error handling.

    Args:
        error_message: Error message to log
        reraise: Whether to re-raise the exception
        log_level: Logging level for errors

    Example:
        with error_handler("Failed to process file", reraise=False):
            process_file(path)
    """
    try:
        yield
    except Exception as e:
        import logging
        logging.log(log_level, f"{error_message}: {e}")
        if reraise:
            raise
```

## Testing

### Type Checking
```bash
# Verify decorator types work correctly
mypy src/python/modules/utils/error_handling.py --strict
```

### Runtime Testing
```python
# tests/python/unit/test_error_handling_types.py
def test_retry_preserves_return_type():
    """Verify retry decorator preserves function return type."""
    @retry_on_exception(max_retries=3)
    def returns_int() -> int:
        return 42

    result = returns_int()
    # mypy should infer result is int
    assert isinstance(result, int)

def test_retry_with_different_types():
    """Test retry with various return types."""
    @retry_on_exception()
    def returns_str() -> str:
        return "hello"

    @retry_on_exception()
    def returns_list() -> list[int]:
        return [1, 2, 3]

    # Type checker should validate these
    s: str = returns_str()
    lst: list[int] = returns_list()
```

## Acceptance Criteria
- [ ] All decorators properly typed with generics
- [ ] TypeVar used for return type preservation
- [ ] mypy --strict passes
- [ ] IDE shows correct types after decoration
- [ ] Example usage in docstrings
- [ ] Tests verify type preservation

## Benefits
- Decorators don't lose type information
- IDE autocomplete works through decorators
- Type checking catches misuse
- Clear API contracts

## Effort
6-8 hours (complex generic typing)

## Related
- Issue #005b (logging module types)
- Issue #003e (error handling tests)
