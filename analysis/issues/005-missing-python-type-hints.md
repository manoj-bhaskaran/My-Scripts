# Issue #005: Incomplete Python Type Hints Coverage

## Severity
**Low-Medium** - Affects code maintainability and IDE support

## Category
Code Quality / Documentation / Developer Experience

## Description
Most Python scripts in the repository lack comprehensive type hints despite having Python 3.11 as the target version. While some files like `cloudconvert_utils.py` have partial type hints for function signatures, many critical scripts have no type annotations at all.

Type hints provide:
- **Static analysis**: Catch type errors before runtime
- **IDE support**: Better autocomplete and inline documentation
- **Self-documentation**: Function signatures become clearer
- **Refactoring safety**: Tools can verify type compatibility

## Current State

### Files with Good Type Hints (Partial)
✅ **src/python/cloud/cloudconvert_utils.py**
```python
from typing import Dict, Any, Tuple

def authenticate() -> str:
    ...

def create_upload_task(api_key: str) -> Dict[str, Any]:
    ...

def handle_file_upload(
    file_name: str, upload_url: str, parameters: Dict[str, str]
) -> requests.Response:
    ...
```

### Files with No Type Hints (Critical)
❌ **src/python/data/csv_to_gpx.py**
```python
def csv_to_gpx(input_csv, output_gpx):  # No types specified
    """Convert CSV to GPX file with elevation and pretty print."""
    ...
```

❌ **src/python/media/find_duplicate_images.py**
```python
def load_checkpoint(path):  # No types
    """Loads the checkpoint file if it exists..."""
    ...

def save_checkpoint(path, stage_name, args):  # No types
    """Saves the current pipeline state..."""
    ...
```

❌ **src/python/modules/logging/python_logging_framework.py**
- Core logging module lacks type hints
- Makes it harder to use correctly in typed code

❌ **src/python/modules/utils/error_handling.py**
- Retry decorators lack type hints
- Generic functions need TypeVar annotations

❌ **src/python/modules/utils/file_operations.py**
- File utilities lack type specifications

## Type Hint Coverage Estimate
- **Overall**: ~15-20% of functions have type hints
- **cloudconvert_utils.py**: ~80% coverage (good)
- **csv_to_gpx.py**: 0% coverage
- **find_duplicate_images.py**: 0% coverage
- **google_drive_root_files_delete.py**: ~10% coverage
- **Module packages**: ~5-10% coverage

## Impact

### Current Issues
- **IDE Experience**: Limited autocomplete and type checking
- **Refactoring Risk**: Type changes can break code silently
- **API Clarity**: Unclear what types functions expect/return
- **Bug Detection**: Type errors only discovered at runtime
- **Learning Curve**: New developers need to read implementation to understand interfaces

### Example of Problems Without Type Hints
```python
# Without type hints - what does this function return?
def load_checkpoint(path):
    if not os.path.exists(path):
        return {}
    with open(path, "r") as f:
        return json.load(f)

# Can return dict or possibly None? Is path a string or Path object?
# Have to read the implementation to know.

# With type hints - immediately clear
from pathlib import Path
from typing import Dict, Any, Optional

def load_checkpoint(path: str | Path) -> Dict[str, Any]:
    if not os.path.exists(path):
        return {}
    with open(path, "r") as f:
        return json.load(f)
```

## Tooling Available

### Currently Configured (Unused)
The repository has `mypy.ini` configured but mypy is not installed in requirements.txt:

```ini
# mypy.ini exists but mypy not used
[mypy]
python_version = 3.11
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = False  # Would need to be True eventually
```

### Should Add
1. **mypy** - Static type checker
2. **MonkeyType** - Generate type hints from runtime traces
3. **PyType** - Google's type inferencer

## Recommended Solution

### Phase 1: Infrastructure (Week 1)
1. **Add mypy to requirements.txt**
   ```
   mypy==1.7.1
   ```

2. **Enable mypy in pre-commit**
   ```yaml
   # .pre-commit-config.yaml
   - repo: https://github.com/pre-commit/mirrors-mypy
     rev: v1.7.1
     hooks:
       - id: mypy
         args: [--config-file=mypy.ini]
         additional_dependencies: [types-requests, types-tqdm]
   ```

3. **Add mypy to CI/CD**
   ```yaml
   # .github/workflows/sonarcloud.yml
   - name: Run mypy (Type Checking)
     run: mypy src/python --config-file mypy.ini || true  # Start informational
   ```

### Phase 2: Core Modules (Week 2-3)
Add type hints to shared modules (highest impact):

**Priority 1: Logging Framework**
```python
# src/python/modules/logging/python_logging_framework.py
from typing import Optional, Dict, Any
import logging

def initialise_logger(
    name: str,
    log_dir: Optional[str] = None,
    level: int = logging.INFO
) -> logging.Logger:
    ...

def log_info(
    logger: logging.Logger,
    message: str,
    metadata: Optional[Dict[str, Any]] = None
) -> None:
    ...
```

**Priority 2: Error Handling**
```python
# src/python/modules/utils/error_handling.py
from typing import TypeVar, Callable, Optional, Any
from functools import wraps

T = TypeVar('T')

def retry_on_exception(
    max_retries: int = 3,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: tuple[type[Exception], ...] = (Exception,)
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    ...
```

**Priority 3: File Operations**
```python
# src/python/modules/utils/file_operations.py
from pathlib import Path
from typing import List, Optional

def ensure_directory(path: str | Path) -> Path:
    ...

def find_files(
    directory: str | Path,
    pattern: str = "*",
    recursive: bool = True
) -> List[Path]:
    ...
```

### Phase 3: Data Processing Scripts (Week 4-5)
Add type hints to data processing (data integrity critical):

**csv_to_gpx.py**
```python
from pathlib import Path

def csv_to_gpx(input_csv: str | Path, output_gpx: str | Path) -> None:
    """Convert CSV to GPX file with elevation and pretty print."""
    ...
```

**find_duplicate_images.py**
```python
from pathlib import Path
from typing import Dict, Any, Optional
import argparse

def load_checkpoint(path: str | Path) -> Dict[str, Any]:
    ...

def save_checkpoint(
    path: str | Path,
    stage_name: str,
    args: argparse.Namespace
) -> None:
    ...

def compute_md5(file_path: str | Path) -> Optional[str]:
    ...
```

### Phase 4: Cloud Integration (Week 6)
Complete type hints for cloud operations:

**google_drive_root_files_delete.py**
```python
from typing import Iterator, Dict, Any, List
from googleapiclient.discovery import Resource

def get_root_files(service: Resource) -> Iterator[Dict[str, Any]]:
    ...

def delete_file(
    service: Resource,
    file_id: str,
    file_name: str
) -> bool:
    ...
```

### Phase 5: Gradual Strictness (Week 7+)
Progressively enable stricter mypy checks:

```ini
# mypy.ini - Progressive strictness
[mypy]
python_version = 3.11
warn_return_any = True
warn_unused_configs = True

# Start permissive
disallow_untyped_defs = False
check_untyped_defs = True

# After Phase 3, enable per-module
[mypy-src.python.modules.*]
disallow_untyped_defs = True

# After Phase 5, enable globally
# disallow_untyped_defs = True
```

## Implementation Strategy

### Use MonkeyType for Bootstrap
Generate initial type hints automatically:

```bash
# Install MonkeyType
pip install MonkeyType

# Run with trace
monkeytype run src/python/data/csv_to_gpx.py --input test.csv --output test.gpx

# Generate stub file
monkeytype stub src.python.data.csv_to_gpx

# Apply to source
monkeytype apply src.python.data.csv_to_gpx
```

### Use pyright for Validation
```bash
# Alternative to mypy with better performance
pip install pyright

# Run type checking
pyright src/python
```

## Acceptance Criteria

### Phase 1 (Infrastructure)
- [ ] mypy installed and configured
- [ ] Pre-commit hook for type checking (informational)
- [ ] CI/CD runs mypy (informational)

### Phase 2 (Core Modules)
- [ ] All shared modules have complete type hints
- [ ] mypy passes for modules/* with no errors
- [ ] Type stubs created for external dependencies

### Phase 3 (Data Processing)
- [ ] csv_to_gpx.py fully typed
- [ ] find_duplicate_images.py fully typed
- [ ] validators.py fully typed
- [ ] extract_timeline_locations.py fully typed

### Phase 4 (Cloud Integration)
- [ ] google_drive_*.py files fully typed
- [ ] cloudconvert_utils.py 100% typed (currently ~80%)
- [ ] drive_space_monitor.py fully typed

### Phase 5 (Enforcement)
- [ ] mypy strict mode enabled for modules/
- [ ] CI/CD fails on type errors (not informational)
- [ ] All new code requires type hints (code review rule)

## Benefits

### Immediate Benefits (Phase 1-2)
- Better IDE autocomplete and error detection
- Self-documenting function signatures
- Catch type errors in shared modules

### Long-term Benefits (Phase 3-5)
- Refactoring with confidence
- Easier onboarding for new developers
- Reduced runtime type errors
- Better collaboration (clear contracts between functions)

## Testing Strategy
```python
# Type hints enable better testing
from typing import List
import pytest

def test_csv_to_gpx_types():
    """Type hints allow IDE to catch incorrect usage."""
    csv_to_gpx(123, 456)  # mypy error: Expected str, got int
    csv_to_gpx("input.csv", "output.gpx")  # OK

# Can use type checkers in tests
def test_return_types():
    checkpoint = load_checkpoint("test.json")
    reveal_type(checkpoint)  # mypy: Dict[str, Any]
    assert isinstance(checkpoint, dict)
```

## Related Issues
- Improves issue #003 (test coverage) - types help generate better tests
- Supports issue #006 (documentation) - types are inline documentation
- Enhances issue #002 (code quality) - static analysis catches errors

## Migration Strategy

### Non-Breaking Changes Only
- Add type hints gradually without changing functionality
- Use `# type: ignore` for complex cases initially
- Focus on public APIs first, then internals

### Compatibility
- Type hints are ignored at runtime (no performance impact)
- Compatible with Python 3.7+ (target is 3.11)
- Gradual typing allows mixed codebases

## Effort Estimate
- **Phase 1 (Infrastructure)**: 4-6 hours
- **Phase 2 (Core Modules)**: 16-24 hours (2-3 days)
- **Phase 3 (Data Processing)**: 12-16 hours (1.5-2 days)
- **Phase 4 (Cloud Integration)**: 8-12 hours (1-1.5 days)
- **Phase 5 (Enforcement)**: 4-8 hours

**Total**: ~44-66 hours (1.5-2 weeks)

## Priority
**Low-Medium** - Not urgent but valuable for long-term maintainability. Consider adding to backlog and implementing during refactoring or new feature development.

## References
- [PEP 484 - Type Hints](https://www.python.org/dev/peps/pep-0484/)
- [mypy Documentation](https://mypy.readthedocs.io/)
- [Python typing module](https://docs.python.org/3/library/typing.html)
- [MonkeyType](https://github.com/Instagram/MonkeyType)
- Repository: `mypy.ini` (already configured but unused)

## Notes
- Repository is well-positioned for type hints (Python 3.11 target)
- mypy.ini already exists, just needs activation
- `cloudconvert_utils.py` shows type hints are already understood and valued
- Can be done incrementally without disrupting existing code
- Good pairing opportunity with test coverage improvements
