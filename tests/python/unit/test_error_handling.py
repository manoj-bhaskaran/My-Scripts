"""Unit tests for error_handling module."""

import pytest
import time
from unittest.mock import Mock, patch
from src.python.modules.utils.error_handling import (
    with_error_handling,
    with_retry,
    retry_operation,
    is_elevated,
    require_elevated,
    safe_execute,
    ErrorContext,
)

# Constants for exponential backoff validation
# This multiplier validates that the second delay is approximately 2x the first
# (with some tolerance for timing variations in test execution)
EXPONENTIAL_BACKOFF_MULTIPLIER = 1.5


def validate_exponential_backoff(call_times: list) -> bool:
    """
    Validate that delays between calls follow exponential backoff pattern.
    
    Args:
        call_times: List of timestamps when function was called
        
    Returns:
        True if delays increase exponentially (second delay > first delay * 1.5)
    """
    if len(call_times) < 3:
        return False
    
    delays = [call_times[i+1] - call_times[i] for i in range(len(call_times)-1)]
    # Verify second delay is roughly 2x the first (using 1.5 multiplier for tolerance)
    return delays[1] > delays[0] * EXPONENTIAL_BACKOFF_MULTIPLIER


class TestWithErrorHandling:
    """Tests for with_error_handling decorator."""

    def test_successful_execution(self):
        """Test decorator with successful execution."""

        @with_error_handling()
        def successful_func():
            return "success"

        result = successful_func()
        assert result == "success"

    def test_raise_on_error(self):
        """Test raise on error (default behavior)."""

        @with_error_handling(on_error="raise")
        def failing_func():
            raise ValueError("test error")

        with pytest.raises(ValueError, match="test error"):
            failing_func()

    def test_return_none_on_error(self):
        """Test return None on error."""

        @with_error_handling(on_error="return_none")
        def failing_func():
            raise ValueError("test error")

        result = failing_func()
        assert result is None

    def test_continue_on_error(self):
        """Test continue on error."""

        @with_error_handling(on_error="continue")
        def failing_func():
            raise ValueError("test error")

        result = failing_func()
        assert result is None

    def test_custom_error_message(self):
        """Test custom error message."""

        @with_error_handling(on_error="raise", error_message="Custom error")
        def failing_func():
            raise ValueError("test error")

        with pytest.raises(ValueError):
            failing_func()


class TestWithRetry:
    """Tests for with_retry decorator."""

    def test_successful_first_attempt(self):
        """Test successful execution on first attempt."""

        @with_retry(max_retries=3)
        def successful_func():
            return "success"

        result = successful_func()
        assert result == "success"

    def test_retry_and_succeed(self):
        """Test retry logic with eventual success."""
        call_count = 0

        @with_retry(max_retries=3, retry_delay=0.1)
        def retry_func():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ValueError("temporary error")
            return "success"

        result = retry_func()

        assert result == "success"
        assert call_count == 3

    def test_max_retries_exceeded(self):
        """Test failure after max retries."""

        @with_retry(max_retries=2, retry_delay=0.1)
        def always_failing():
            raise ValueError("permanent error")

        with pytest.raises(ValueError, match="permanent error"):
            always_failing()

    def test_specific_exceptions(self):
        """Test retry only on specific exceptions."""

        @with_retry(max_retries=3, exceptions=(IOError,), retry_delay=0.1)
        def func_with_wrong_exception():
            raise ValueError("wrong exception type")

        with pytest.raises(ValueError):
            func_with_wrong_exception()


class TestRetryOperation:
    """Tests for retry_operation function."""

    def test_successful_operation(self):
        """Test successful operation."""
        result = retry_operation(lambda: "success", "Test operation")

        assert result == "success"

    def test_retry_and_succeed(self):
        """Test retry with eventual success."""
        call_count = 0

        def operation():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ValueError("temporary error")
            return "success"

        result = retry_operation(operation, "Test operation", max_retries=5, retry_delay=0.1)

        assert result == "success"
        assert call_count == 3

    def test_max_retries_exceeded(self):
        """Test failure after max retries."""

        def always_failing():
            raise ValueError("permanent error")

        with pytest.raises(ValueError, match="permanent error"):
            retry_operation(always_failing, "Test operation", max_retries=2, retry_delay=0.1)


class TestIsElevated:
    """Tests for is_elevated function."""

    @patch("platform.system")
    @patch("os.geteuid")
    def test_elevated_on_unix(self, mock_geteuid, mock_system):
        """Test elevated check on Unix (root)."""
        mock_system.return_value = "Linux"
        mock_geteuid.return_value = 0

        result = is_elevated()

        assert result is True

    @patch("platform.system")
    @patch("os.geteuid")
    def test_not_elevated_on_unix(self, mock_geteuid, mock_system):
        """Test non-elevated check on Unix (non-root)."""
        mock_system.return_value = "Linux"
        mock_geteuid.return_value = 1000

        result = is_elevated()

        assert result is False


class TestRequireElevated:
    """Tests for require_elevated function."""

    @patch("src.python.modules.utils.error_handling.is_elevated")
    def test_elevated_no_error(self, mock_is_elevated):
        """Test no error when elevated."""
        mock_is_elevated.return_value = True

        # Should not raise
        require_elevated()

    @patch("src.python.modules.utils.error_handling.is_elevated")
    def test_not_elevated_raises_error(self, mock_is_elevated):
        """Test raises error when not elevated."""
        mock_is_elevated.return_value = False

        with pytest.raises(PermissionError, match="elevated privileges"):
            require_elevated()

    @patch("src.python.modules.utils.error_handling.is_elevated")
    def test_custom_message(self, mock_is_elevated):
        """Test custom error message."""
        mock_is_elevated.return_value = False

        with pytest.raises(PermissionError, match="Custom message"):
            require_elevated("Custom message")


class TestSafeExecute:
    """Tests for safe_execute function."""

    def test_successful_execution(self):
        """Test successful execution."""
        result = safe_execute(lambda: "success")
        assert result == "success"

    def test_raise_on_error(self):
        """Test raise on error (default)."""
        with pytest.raises(ValueError):
            safe_execute(lambda: (_ for _ in ()).throw(ValueError("error")))

    def test_return_none_on_error(self):
        """Test return None on error."""
        result = safe_execute(lambda: int("not_a_number"), on_error="return_none")
        assert result is None


class TestErrorContext:
    """Tests for ErrorContext context manager."""

    def test_successful_execution(self):
        """Test successful execution in context."""
        with ErrorContext("Test operation"):
            result = "success"

        assert result == "success"

    def test_raise_on_error(self):
        """Test raises error by default."""
        with pytest.raises(ValueError):
            with ErrorContext("Test operation", on_error="raise"):
                raise ValueError("test error")

    def test_continue_on_error(self):
        """Test continue on error."""
        executed = False

        with ErrorContext("Test operation", on_error="continue"):
            executed = True
            raise ValueError("test error")

        assert executed is True

    def test_error_suppression_with_continue(self):
        """Test error suppression with on_error='continue'."""
        # ErrorContext with on_error="continue" should suppress errors
        # Use max_retries=1 to skip retry logic and go straight to error handling
        with ErrorContext("Test operation", max_retries=1, on_error="continue"):
            raise ValueError("test error")

        # Test completes without raising - error was suppressed


class TestRetryDecoratorAdvanced:
    """Advanced tests for retry decorator based on issue requirements."""

    def test_retry_decorator_retries_on_failure(self):
        """Test retry decorator retries failed operations."""
        mock_func = Mock(side_effect=[ValueError, ValueError, "success"])

        @with_retry(max_retries=3, retry_delay=0.01)
        def failing_func():
            return mock_func()

        result = failing_func()

        assert result == "success"
        assert mock_func.call_count == 3

    def test_retry_decorator_respects_max_retries(self):
        """Test retry decorator stops after max retries."""
        mock_func = Mock(side_effect=ValueError("Always fails"))

        @with_retry(max_retries=3, retry_delay=0.01)
        def failing_func():
            return mock_func()

        with pytest.raises(ValueError):
            failing_func()

        assert mock_func.call_count == 3

    def test_retry_decorator_with_custom_exceptions(self):
        """Test retry only on specific exceptions."""
        
        @with_retry(max_retries=3, retry_delay=0.01, exceptions=(ValueError,))
        def func():
            raise TypeError("Not retryable")

        with pytest.raises(TypeError):
            func()

        # Should fail immediately, not retry

    def test_exponential_backoff(self):
        """Test exponential backoff between retries."""
        call_times = []

        def track_time():
            call_times.append(time.time())
            raise ValueError("Fail")

        @with_retry(max_retries=3, retry_delay=0.1, max_backoff=60.0)
        def failing_func():
            return track_time()

        with pytest.raises(ValueError):
            failing_func()

        # Verify delays increase exponentially using helper function
        assert len(call_times) == 3
        assert validate_exponential_backoff(call_times)


class TestRetryOperationAdvanced:
    """Advanced tests for retry_operation function."""

    def test_exponential_backoff_in_retry_operation(self):
        """Test exponential backoff in retry_operation."""
        call_times = []

        def operation():
            call_times.append(time.time())
            raise ValueError("Fail")

        with pytest.raises(ValueError):
            retry_operation(
                operation,
                "Test operation",
                max_retries=3,
                retry_delay=0.1,
                max_backoff=60.0
            )

        # Verify delays increase exponentially using helper function
        assert len(call_times) == 3
        assert validate_exponential_backoff(call_times)
