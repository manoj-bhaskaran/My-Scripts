# Issue #005b: Add Type Hints to Logging Modules

**Parent Issue**: [#005: Missing Python Type Hints](./005-missing-python-type-hints.md)
**Phase**: Phase 2 - Core Modules
**Effort**: 6-8 hours

## Description
Add comprehensive type hints to logging framework modules. High priority because these are used across all scripts.

## Scope
- `src/python/modules/logging/python_logging_framework.py`
- All public functions and classes

## Implementation

### Main Module Functions
```python
# python_logging_framework.py
from typing import Optional, Dict, Any
import logging
from pathlib import Path

def initialise_logger(
    name: str,
    log_dir: Optional[str | Path] = None,
    level: int = logging.INFO
) -> logging.Logger:
    """
    Initialize a logger with structured logging support.

    Args:
        name: Logger name (usually __name__)
        log_dir: Directory for log files. If None, uses default.
        level: Logging level (default: INFO)

    Returns:
        Configured logger instance
    """
    ...

def log_info(
    logger: logging.Logger,
    message: str,
    metadata: Optional[Dict[str, Any]] = None
) -> None:
    """
    Log an info message with optional structured metadata.

    Args:
        logger: Logger instance
        message: Log message
        metadata: Optional dictionary of structured data
    """
    ...

def log_error(
    logger: logging.Logger,
    message: str,
    error: Optional[Exception] = None,
    metadata: Optional[Dict[str, Any]] = None
) -> None:
    """
    Log an error message with optional exception and metadata.

    Args:
        logger: Logger instance
        message: Error message
        error: Optional exception object
        metadata: Optional dictionary of structured data
    """
    ...

def log_debug(
    logger: logging.Logger,
    message: str,
    metadata: Optional[Dict[str, Any]] = None
) -> None:
    """Log a debug message."""
    ...

def log_warning(
    logger: logging.Logger,
    message: str,
    metadata: Optional[Dict[str, Any]] = None
) -> None:
    """Log a warning message."""
    ...

def get_log_file_path(logger: logging.Logger) -> Optional[Path]:
    """
    Get the log file path for a logger.

    Args:
        logger: Logger instance

    Returns:
        Path to log file, or None if logging to console only
    """
    ...
```

### Internal Helper Functions
```python
def _get_default_log_dir() -> Path:
    """Get the default log directory path."""
    ...

def _setup_file_handler(
    logger: logging.Logger,
    log_file: Path,
    level: int
) -> logging.FileHandler:
    """Set up file handler for logger."""
    ...

def _format_metadata(metadata: Dict[str, Any]) -> str:
    """Format metadata dictionary as JSON string."""
    ...
```

## Testing
```bash
# Verify types with mypy
mypy src/python/modules/logging/python_logging_framework.py --strict

# Should pass with no errors
```

## Acceptance Criteria
- [ ] All public functions have type hints
- [ ] All internal functions have type hints
- [ ] Docstrings match type signatures
- [ ] mypy --strict passes for this module
- [ ] IDE autocomplete works correctly

## Benefits
- Clear API documentation
- Better IDE support
- Catch type errors at development time
- Self-documenting code

## Effort
6-8 hours

## Related
- Issue #005c (error handling module types)
- Issue #003e (tests for logging module)
