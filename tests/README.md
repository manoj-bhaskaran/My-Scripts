# Testing Framework Documentation

This directory contains the testing infrastructure for the My-Scripts repository.

## Overview

We use a comprehensive testing framework to ensure code quality and reliability:
- **Python**: pytest with coverage reporting
- **PowerShell**: Pester with code coverage

## Directory Structure

```
tests/
├── python/
│   ├── unit/              # Python unit tests
│   │   ├── test_validators.py
│   │   ├── test_logging_framework.py
│   │   └── test_csv_to_gpx.py
│   └── conftest.py        # Pytest configuration and fixtures
├── powershell/
│   └── unit/              # PowerShell unit tests
│       ├── RandomName.Tests.ps1
│       └── FileDistributor.Tests.ps1
└── README.md              # This file
```

## Running Tests Locally

### Python Tests

#### Prerequisites
```bash
pip install -r requirements.txt
```

#### Run all Python tests
```bash
pytest tests/python
```

#### Run with coverage report
```bash
pytest tests/python --cov=src/python --cov=src/common --cov-report=term-missing
```

#### Run specific test file
```bash
pytest tests/python/unit/test_validators.py
```

#### Run with verbose output
```bash
pytest tests/python -v
```

### PowerShell Tests

#### Prerequisites
```powershell
Install-Module -Name Pester -Force -Scope CurrentUser
```

#### Run all PowerShell tests
```powershell
Invoke-Pester -Path tests/powershell
```

#### Run with coverage
```powershell
$config = New-PesterConfiguration
$config.Run.Path = 'tests/powershell'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = 'src/powershell/**/*.ps1'
Invoke-Pester -Configuration $config
```

#### Run specific test file
```powershell
Invoke-Pester -Path tests/powershell/unit/RandomName.Tests.ps1
```

## Writing New Tests

### Python Tests

1. Create a new test file in `tests/python/unit/` following the naming convention `test_<module_name>.py`
2. Import the module you want to test
3. Write test classes and methods using pytest conventions
4. Use pytest fixtures for common setup/teardown
5. Follow the existing test structure and patterns

Example:
```python
import pytest
from my_module import my_function

class TestMyFunction:
    def test_basic_functionality(self):
        result = my_function(input_data)
        assert result == expected_output
```

### PowerShell Tests

1. Create a new test file in `tests/powershell/unit/` following the naming convention `<ModuleName>.Tests.ps1`
2. Use Pester's `Describe`, `Context`, and `It` blocks
3. Import the module/script you want to test in `BeforeAll`
4. Write clear, descriptive test names
5. Follow the existing test structure and patterns

Example:
```powershell
BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'powershell' 'MyModule.psm1'
    Import-Module $ModulePath -Force
}

Describe "My-Function" {
    Context "Basic Functionality" {
        It "Should return expected output" {
            $result = My-Function -Parameter "value"
            $result | Should -Be "expected"
        }
    }
}
```

## Coverage Targets

We aim for the following coverage targets:

| Category | Target Coverage |
|----------|----------------|
| Shared modules (src/common/) | ≥30% |
| Core utilities (src/python/validators.py, etc.) | ≥50% |
| PowerShell modules | ≥30% |
| Overall project | ≥25% |

## Mocking Strategies

### Python Mocking
- Use `unittest.mock` for mocking external dependencies
- Mock file I/O operations to avoid creating actual files in tests
- Mock external APIs and services
- Use `@patch` decorator for function-level mocking

### PowerShell Mocking
- Use Pester's `Mock` command for mocking cmdlets and functions
- Use `TestDrive:` for temporary file operations
- Mock external dependencies to isolate unit tests
- Use `Assert-MockCalled` to verify mock interactions

## Continuous Integration

Tests are automatically run on every push and pull request via GitHub Actions. See `.github/workflows/sonarcloud.yml` for the CI configuration.

### CI Pipeline
1. Install dependencies
2. Run Python tests with coverage
3. Run PowerShell tests with coverage
4. Generate coverage reports
5. Upload results to SonarCloud
6. Run linters (pylint, PSScriptAnalyzer)
7. Run security scans (bandit)

## Test Execution Time

Target: All tests should complete in less than 2 minutes in CI.

Current breakdown:
- Python tests: ~30 seconds
- PowerShell tests: ~45 seconds
- Total test execution: ~1.5 minutes

## Troubleshooting

### Python Tests Failing

1. Ensure all dependencies are installed: `pip install -r requirements.txt`
2. Check that `src/python` and `src/common` are in the Python path
3. Verify pytest version: `pytest --version` (should be ≥7.4.0)

### PowerShell Tests Failing

1. Ensure Pester is installed: `Get-Module -ListAvailable Pester`
2. Check Pester version: Should be 5.x or higher
3. Verify module paths are correct in test files
4. Run with `-Verbose` flag for detailed output

### Coverage Not Being Generated

1. Ensure coverage plugins are installed (`pytest-cov` for Python)
2. Check that paths in coverage configuration match your project structure
3. Verify that test files are being discovered

## Additional Resources

- [pytest Documentation](https://docs.pytest.org/)
- [Pester Documentation](https://pester.dev/)
- [Testing Best Practices](../docs/guides/testing.md)
- [SonarCloud Dashboard](https://sonarcloud.io/project/overview?id=manoj-bhaskaran_My-Scripts)
