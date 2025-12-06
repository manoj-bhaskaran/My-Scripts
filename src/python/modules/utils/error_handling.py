"""Error handling utilities and decorators.

This module provides reusable error handling utilities including retry logic,
decorators, and privilege checking functions.
"""

from __future__ import annotations

import functools
import logging
import os
import platform
import time
from contextlib import contextmanager
from typing import Any, Callable, Iterator, Optional, Tuple, Type, TypeVar, Union

logger: logging.Logger = logging.getLogger(__name__)  # type: ignore[name-defined,attr-defined]

# Type variable for generic function typing (preserves return type)
T = TypeVar("T")

# Type variable for decorator typing (bound to callable)
F = TypeVar("F", bound=Callable[..., Any])


def with_error_handling(
    on_error: str = "raise", log_errors: bool = True, error_message: Optional[str] = None
) -> Callable[[F], F]:
    """Decorator for standardized error handling.

    Args:
        on_error: Action to take on error - "raise", "return_none", or "continue".
        log_errors: Whether to log errors (default: True).
        error_message: Custom error message prefix.

    Returns:
        Decorated function with error handling.

    Example:
        >>> @with_error_handling(on_error="return_none")
        ... def read_config(path):
        ...     with open(path) as f:
        ...         return f.read()

        >>> @with_error_handling(error_message="Failed to process data")
        ... def process_data(data):
        ...     return data.process()
    """

    def decorator(func: F) -> F:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if log_errors:
                    msg = (
                        f"{error_message}: {e}"
                        if error_message
                        else f"Error in {func.__name__}: {e}"
                    )
                    logger.error(msg)

                if on_error == "raise":
                    raise
                elif on_error == "return_none":
                    return None
                elif on_error == "continue":
                    pass
                else:
                    raise ValueError(f"Invalid on_error value: {on_error}")

        return wrapper  # type: ignore

    return decorator


def with_retry(
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
    exceptions: Tuple[Type[Exception], ...] = (Exception,),
    log_errors: bool = True,
) -> Callable[[F], F]:
    """Decorator for automatic retry with exponential backoff.

    Args:
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 2.0).
        max_backoff: Maximum backoff delay in seconds (default: 60.0).
        exceptions: Tuple of exception types to catch and retry (default: (Exception,)).
        log_errors: Whether to log retry attempts (default: True).

    Returns:
        Decorated function with retry logic.

    Example:
        >>> @with_retry(max_retries=5, retry_delay=1.0)
        ... def fetch_data(url):
        ...     return requests.get(url, timeout=(5, 30)).json()

        >>> @with_retry(max_retries=3, exceptions=(IOError, OSError))
        ... def write_file(path, content):
        ...     with open(path, 'w') as f:
        ...         f.write(content)
    """

    def decorator(func: F) -> F:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            attempt = 0

            while True:
                try:
                    result = func(*args, **kwargs)

                    if attempt > 0 and log_errors:
                        logger.info(
                            f"Succeeded calling {func.__name__} after {attempt} retry attempt(s)"
                        )

                    return result

                except exceptions as e:
                    attempt += 1

                    if attempt >= max_retries:
                        if log_errors:
                            logger.error(f"{func.__name__} failed after {attempt} attempt(s): {e}")
                        raise

                    # Calculate exponential backoff delay
                    delay = min(retry_delay * (2 ** (attempt - 1)), max_backoff)

                    if log_errors:
                        logger.warning(
                            f"Attempt {attempt} of {func.__name__} failed: {e}. "
                            f"Retrying in {delay:.1f} second(s)..."
                        )

                    time.sleep(delay)

        return wrapper  # type: ignore

    return decorator


def retry_on_exception(
    max_retries: int = 3,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: Tuple[Type[Exception], ...] = (Exception,),
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
        @functools.wraps(func)
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


def retry_operation(
    operation: Callable[[], T],
    description: str,
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
    log_errors: bool = True,
) -> T:
    """Execute operation with automatic retry on failure.

    Args:
        operation: Callable to execute (takes no arguments).
        description: Description of the operation for logging.
        max_retries: Maximum number of retry attempts (default: 3).
        retry_delay: Base delay in seconds before first retry (default: 2.0).
        max_backoff: Maximum backoff delay in seconds (default: 60.0).
        log_errors: Whether to log retry attempts (default: True).

    Returns:
        Result of the operation.

    Raises:
        Exception: If operation fails after all retries.

    Example:
        >>> def copy_file():
        ...     shutil.copy("source.txt", "dest.txt")

        >>> retry_operation(copy_file, "Copy file", max_retries=5)

        >>> retry_operation(
        ...     lambda: requests.get(url, timeout=(5, 30)).json(),
        ...     "Fetch data from API",
        ...     max_retries=3
        ... )
    """
    attempt = 0

    while True:
        try:
            result = operation()

            if attempt > 0 and log_errors:
                logger.info(f"Succeeded {description} after {attempt} retry attempt(s)")

            return result

        except Exception as e:
            attempt += 1

            if attempt >= max_retries:
                if log_errors:
                    logger.error(
                        f"Operation failed after {attempt} attempt(s): {description}. Error: {e}"
                    )
                raise

            delay = min(retry_delay * (2 ** (attempt - 1)), max_backoff)

            if log_errors:
                logger.warning(
                    f"Attempt {attempt} failed for {description}: {e}. "
                    f"Retrying in {delay:.1f} second(s)..."
                )

            time.sleep(delay)


def is_elevated() -> bool:
    """Check if script is running with elevated privileges.

    Returns:
        True if running as administrator (Windows) or root (Linux/macOS).

    Example:
        >>> if is_elevated():
        ...     print("Running with admin privileges")
        ... else:
        ...     print("Running as normal user")
    """
    system = platform.system()

    if system == "Windows":
        try:
            import ctypes

            return bool(ctypes.windll.shell32.IsUserAnAdmin() != 0)  # type: ignore[attr-defined]
        except Exception:
            # Fallback: check if we can write to system directory
            try:
                test_file = os.path.join(
                    os.environ.get("SystemRoot", "C:\\Windows"), "temp_admin_test"
                )
                with open(test_file, "w") as f:
                    f.write("test")
                os.remove(test_file)
                return True
            except Exception:
                return False
    else:
        # Linux/macOS: check if UID is 0 (root)
        return os.geteuid() == 0


def require_elevated(custom_message: Optional[str] = None) -> None:
    """Require elevated privileges, raise exception if not elevated.

    Args:
        custom_message: Optional custom error message.

    Raises:
        PermissionError: If not running with elevated privileges.

    Example:
        >>> require_elevated()

        >>> require_elevated("This operation requires administrator rights")
    """
    if not is_elevated():
        default_message = (
            "This script requires elevated privileges. "
            "Run as Administrator (Windows) or with sudo (Linux/macOS)."
        )
        message = custom_message or default_message
        raise PermissionError(message)


def safe_execute(
    func: Callable[..., T],
    *args: Any,
    default: Optional[T] = None,
    log_errors: bool = True,
    **kwargs: Any,
) -> Union[T, None]:
    """Execute function safely, returning default on error.

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
            logger.error(f"Error in {func.__name__}: {e}")
        return default


@contextmanager
def error_handler(
    error_message: str,
    reraise: bool = True,
    log_level: int = logging.ERROR,  # type: ignore[attr-defined]
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
        logger.log(log_level, f"{error_message}: {e}")
        if reraise:
            raise


class ErrorContext:
    """Context manager for error handling.

    Note: Context managers cannot restart the 'with' block, so retry
    parameters are mainly for tracking attempts in manual retry loops.
    For automatic retry, use @with_retry decorator or retry_operation().

    Example:
        >>> with ErrorContext("Processing data", on_error="continue"):
        ...     process_data()

        >>> # For retry, use in a loop
        >>> for attempt in range(3):
        ...     with ErrorContext("Fetch API data", on_error="continue"):
        ...         data = fetch_from_api()
        ...         break  # Exit loop on success
    """

    def __init__(
        self,
        description: str,
        on_error: str = "raise",
        log_errors: bool = True,
        max_retries: int = 1,
        retry_delay: float = 2.0,
    ):
        """Initialize error context.

        Args:
            description: Description of the operation.
            on_error: Action on error - "raise", "return_none", or "continue".
            log_errors: Whether to log errors (default: True).
            max_retries: Maximum retry attempts (default: 1, no retry).
            retry_delay: Base delay between retries in seconds (default: 2.0).
        """
        self.description = description
        self.on_error = on_error
        self.log_errors = log_errors
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.attempt = 0

    def __enter__(self) -> "ErrorContext":
        """Enter context."""
        return self

    def __exit__(
        self,
        exc_type: Optional[Type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Any,
    ) -> bool:
        """Exit context with error handling."""
        if exc_type is None:
            # No exception, success
            if self.attempt > 0 and self.log_errors:
                logger.info(f"Succeeded {self.description} after {self.attempt} retry attempt(s)")
            return True

        self.attempt += 1

        if self.attempt < self.max_retries:
            # Retry
            delay = self.retry_delay * (2 ** (self.attempt - 1))
            if self.log_errors:
                logger.warning(
                    f"Attempt {self.attempt} failed for {self.description}: {exc_val}. "
                    f"Retrying in {delay:.1f} second(s)..."
                )
            time.sleep(delay)
            return False  # Suppress exception, retry

        # Max retries reached or no retry
        if self.log_errors:
            logger.error(f"Error in {self.description}: {exc_val}")

        if self.on_error == "raise":
            return False  # Re-raise exception
        elif self.on_error in ("return_none", "continue"):
            return True  # Suppress exception
        else:
            raise ValueError(f"Invalid on_error value: {self.on_error}")


__all__ = [
    "with_error_handling",
    "with_retry",
    "retry_on_exception",
    "retry_operation",
    "is_elevated",
    "require_elevated",
    "safe_execute",
    "error_handler",
    "ErrorContext",
]
