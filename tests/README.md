# Test Suite

This directory contains the test suite for My-Scripts repository.

## Directory Structure

```
tests/
├── powershell/          # PowerShell script tests
│   ├── unit/           # Unit tests for individual PowerShell functions
│   ├── integration/    # Integration tests for PowerShell scripts
│   └── fixtures/       # Test data and mock files for PowerShell tests
├── python/             # Python script tests
│   ├── unit/          # Unit tests for individual Python functions
│   ├── integration/   # Integration tests for Python scripts
│   └── fixtures/      # Test data and mock files for Python tests
├── conftest.py        # Pytest configuration and shared fixtures
├── pytest.ini         # Pytest settings and options
└── README.md          # This file
```

## Running Tests

### Prerequisites

Install pytest and required dependencies:

```bash
pip install pytest pytest-cov
```

For PowerShell testing, you may also need:
- Pester (PowerShell testing framework)

### Running Python Tests

Run all tests:
```bash
pytest
```

Run specific test categories:
```bash
# Run only unit tests
pytest -m unit

# Run only integration tests
pytest -m integration

# Run only Python tests
pytest tests/python/

# Run only PowerShell-related tests
pytest -m powershell
```

Run with coverage:
```bash
pytest --cov=src --cov-report=html --cov-report=term
```

### Running PowerShell Tests

PowerShell tests should use the Pester framework:

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all PowerShell tests
Invoke-Pester tests/powershell/

# Run specific test files
Invoke-Pester tests/powershell/unit/Test-SpecificScript.Tests.ps1
```

## Writing Tests

### Python Tests

Create test files following the naming convention `test_*.py` or `*_test.py`:

```python
# tests/python/unit/test_example.py
import pytest

def test_example_function():
    """Test description."""
    assert True

@pytest.mark.integration
def test_integration_example():
    """Integration test description."""
    assert True
```

### PowerShell Tests

Create test files following the Pester naming convention `*.Tests.ps1`:

```powershell
# tests/powershell/unit/Test-Example.Tests.ps1
Describe "Example Function Tests" {
    It "Should return expected value" {
        $result = Test-ExampleFunction
        $result | Should -Be $expectedValue
    }
}
```

## Test Markers

Available markers defined in `pytest.ini`:
- `unit` - Unit tests for individual components
- `integration` - Integration tests for multiple components
- `powershell` - Tests related to PowerShell scripts
- `python` - Tests related to Python scripts
- `slow` - Tests that take a long time to run

Use markers to categorize tests:
```python
@pytest.mark.unit
@pytest.mark.python
def test_my_function():
    pass
```

## Fixtures

### Python Fixtures

Common fixtures are defined in `conftest.py`:
- `project_root_dir` - Path to the project root directory
- `test_data_dir` - Path to the test fixtures directory
- `temp_test_dir` - Temporary directory for test operations

Add test-specific fixtures in the `fixtures/` directories.

### PowerShell Test Data

Store PowerShell test fixtures in `tests/powershell/fixtures/`:
- Sample files
- Mock data
- Configuration files

## Best Practices

1. **Isolation**: Each test should be independent and not rely on others
2. **Descriptive Names**: Use clear, descriptive test function names
3. **Arrange-Act-Assert**: Structure tests with setup, execution, and verification
4. **Fixtures**: Use fixtures for common test data and setup
5. **Markers**: Tag tests appropriately for easy filtering
6. **Documentation**: Include docstrings explaining what each test verifies
7. **Clean Up**: Use fixtures and temporary directories to avoid leaving test artifacts

## Contributing

When adding new scripts to the repository:
1. Create corresponding tests in the appropriate directory
2. Add unit tests for individual functions
3. Add integration tests for end-to-end script behavior
4. Include necessary fixtures in the `fixtures/` directory
5. Run tests locally before submitting pull requests

## CI/CD Integration

Tests should be run automatically in CI/CD pipelines:
- On pull requests
- On commits to main branches
- Before releases

See `.github/workflows/` for CI configuration.
