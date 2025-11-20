"""Error handling utilities and decorators.

This module provides reusable error handling utilities including retry logic,
decorators, and privilege checking functions.
"""

import functools
import logging
import os
import platform
import time
from typing import Any, Callable, Optional, TypeVar, Union

logger = logging.getLogger(__name__)

# Type variable for generic function typing
F = TypeVar('F', bound=Callable[..., Any])


def with_error_handling(
    on_error: str = "raise",
    log_errors: bool = True,
    error_message: Optional[str] = None
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
        def wrapper(*args, **kwargs) -> Any:
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if log_errors:
                    msg = f"{error_message}: {e}" if error_message else f"Error in {func.__name__}: {e}"
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
    exceptions: tuple = (Exception,),
    log_errors: bool = True
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
        ...     return requests.get(url).json()

        >>> @with_retry(max_retries=3, exceptions=(IOError, OSError))
        ... def write_file(path, content):
        ...     with open(path, 'w') as f:
        ...         f.write(content)
    """
    def decorator(func: F) -> F:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> Any:
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
                            logger.error(
                                f"{func.__name__} failed after {attempt} attempt(s): {e}"
                            )
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


def retry_operation(
    operation: Callable[[], Any],
    description: str,
    max_retries: int = 3,
    retry_delay: float = 2.0,
    max_backoff: float = 60.0,
    log_errors: bool = True
) -> Any:
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
        ...     lambda: requests.get(url).json(),
        ...     "Fetch data from API",
        ...     max_retries=3
        ... )
    """
    attempt = 0

    while True:
        try:
            result = operation()

            if attempt > 0 and log_errors:
                logger.info(
                    f"Succeeded {description} after {attempt} retry attempt(s)"
                )

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
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            # Fallback: check if we can write to system directory
            try:
                test_file = os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "temp_admin_test")
                with open(test_file, 'w') as f:
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
    func: Callable[[], Any],
    on_error: str = "raise",
    error_message: Optional[str] = None,
    log_errors: bool = True
) -> Optional[Any]:
    """Execute function with error handling.

    Args:
        func: Function to execute (takes no arguments).
        on_error: Action on error - "raise", "return_none", or "continue".
        error_message: Custom error message prefix.
        log_errors: Whether to log errors (default: True).

    Returns:
        Result of function, or None if error and on_error != "raise".

    Example:
        >>> result = safe_execute(
        ...     lambda: int("not_a_number"),
        ...     on_error="return_none",
        ...     error_message="Invalid number format"
        ... )
        >>> print(result)
        None

        >>> data = safe_execute(
        ...     lambda: json.load(open("config.json")),
        ...     on_error="raise"
        ... )
    """
    try:
        return func()
    except Exception as e:
        if log_errors:
            msg = f"{error_message}: {e}" if error_message else f"Error: {e}"
            logger.error(msg)

        if on_error == "raise":
            raise
        elif on_error in ("return_none", "continue"):
            return None
        else:
            raise ValueError(f"Invalid on_error value: {on_error}")


class ErrorContext:
    """Context manager for error handling with optional retry.

    Example:
        >>> with ErrorContext("Processing data", on_error="continue"):
        ...     process_data()

        >>> with ErrorContext("Fetch API data", max_retries=3):
        ...     data = fetch_from_api()
    """

    def __init__(
        self,
        description: str,
        on_error: str = "raise",
        log_errors: bool = True,
        max_retries: int = 1,
        retry_delay: float = 2.0
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

    def __enter__(self):
        """Enter context."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit context with error handling."""
        if exc_type is None:
            # No exception, success
            if self.attempt > 0 and self.log_errors:
                logger.info(
                    f"Succeeded {self.description} after {self.attempt} retry attempt(s)"
                )
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
    "retry_operation",
    "is_elevated",
    "require_elevated",
    "safe_execute",
    "ErrorContext",
]
