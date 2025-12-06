# Testing Framework Documentation

This directory contains the testing infrastructure for the My-Scripts repository.

## Overview

We use a comprehensive testing framework to ensure code quality and reliability:
- **Python**: pytest with coverage reporting
- **PowerShell**: Pester with code coverage

## Directory Structure

```
tests/
├── integration/         # Cross-platform integration tests
├── python/
│   ├── unit/              # Python unit tests
│   │   ├── test_validators.py
│   │   ├── test_logging_framework.py
│   │   ├── test_smoke.py       # Smoke tests for Python entry-point scripts
│   │   └── test_csv_to_gpx.py
│   └── conftest.py        # Pytest configuration and fixtures
├── powershell/
│   ├── unit/              # PowerShell unit tests
│   │   ├── ErrorHandling.Tests.ps1
│   │   ├── FileDistributor.Tests.ps1
│   │   ├── FileOperations.Tests.ps1
│   │   ├── SmokeTests.Tests.ps1      # Smoke tests for PowerShell scripts
│   │   ├── PostgresBackup.Tests.ps1
│   │   ├── ProgressReporter.Tests.ps1
│   │   └── RandomName.Tests.ps1
│   └── Invoke-Tests.ps1   # PowerShell test runner with coverage
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

#### Run with coverage report (terminal)
```bash
pytest tests/python --cov=src/python --cov=src/common --cov-report=term-missing
```

#### Run with HTML coverage report
```bash
pytest tests/python
# Coverage report automatically generated at: coverage/python/html/index.html

# Open the HTML report
open coverage/python/html/index.html      # macOS
xdg-open coverage/python/html/index.html  # Linux
start coverage/python/html/index.html     # Windows (Git Bash)
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

### Integration Tests (PowerShell + PostgreSQL)

These tests spin up a temporary PostgreSQL instance and validate the end-to-end backup/restore process using the `PostgresBackup` module.

#### Prerequisites
- PostgreSQL client and server utilities available on PATH (`initdb`, `pg_ctl`, `psql`, `pg_dump`, `pg_restore`).
- Pester installed (see above).

#### Run integration suite
```powershell
Invoke-Pester -Path tests/integration
```

#### Run with coverage (using helper script - recommended)
```powershell
# Run tests with coverage reporting
.\tests\powershell\Invoke-Tests.ps1

# Run with custom coverage threshold
.\tests\powershell\Invoke-Tests.ps1 -MinimumCoverage 50

# Run without coverage
.\tests\powershell\Invoke-Tests.ps1 -CodeCoverageEnabled $false
```

#### Run with coverage (manual configuration)
```powershell
$config = New-PesterConfiguration
$config.Run.Path = 'tests/powershell'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @(
    'src/powershell/**/*.ps1',
    'src/powershell/**/*.psm1',
    'src/common/*.ps1',
    'src/common/*.psm1'
)
$config.CodeCoverage.OutputPath = 'coverage/powershell/coverage.xml'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
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

## Coverage Targets and Reporting

### Coverage Targets

We are ramping up coverage in phases. See [Coverage Roadmap](../docs/COVERAGE_ROADMAP.md) for details.

**Current Status (Phase 1 - Foundation):**

| Category | Current | Phase 1 | Phase 2 | Phase 3 | Long-term Target |
|----------|---------|---------|---------|---------|------------------|
| Python code | ~TBD% | >1% | >15% | >30% | 60% |
| PowerShell code | 0.37% | >0% | >15% | >30% | 50% |
| Shared modules | ~TBD% | >1% | >20% | >30% | 60% |
| Overall project | ~1% | >1% | >15% | >30% | 50% |

### Coverage Enforcement

**Current Configuration (Phase 1 - Baseline):**
- **Python**: Tests fail if coverage drops below 1% (`--cov-fail-under=1` in pytest.ini)
- **PowerShell**: No minimum threshold enforced (0%) to establish baseline
- **Codecov**: Informational only - tracks trends but doesn't fail builds
- **Strategy**: Prevent regression from baseline, gradually increase thresholds

**Future Enforcement:**
- Month 2: Increase to 5% minimum
- Month 4: Increase to 15% minimum
- Month 6: Achieve 30% target threshold
- See [Coverage Roadmap](../docs/COVERAGE_ROADMAP.md) for complete schedule

### Viewing Coverage Reports

#### Online Dashboards

- **[Codecov Dashboard](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)**: Comprehensive coverage analytics
  - Coverage trends over time
  - File-by-file coverage breakdown
  - PR-level coverage diffs
  - Language-specific flags (Python, PowerShell)

- **[SonarCloud Dashboard](https://sonarcloud.io/project/overview?id=manoj-bhaskaran_My-Scripts)**: Code quality and coverage
  - Overall code quality metrics
  - Coverage as part of quality gate
  - Security and maintainability issues

#### Local Coverage Reports

**Python HTML Reports:**
```bash
# Run tests to generate coverage
pytest tests/python

# Coverage reports are generated at:
# - coverage/python/coverage.xml (machine-readable)
# - coverage/python/html/index.html (human-readable)

# Open HTML report in browser
open coverage/python/html/index.html      # macOS
xdg-open coverage/python/html/index.html  # Linux
start coverage/python/html/index.html     # Windows
```

**PowerShell Coverage:**
```powershell
# Run tests with coverage
.\tests\powershell\Invoke-Tests.ps1

# Coverage output includes:
# - Terminal summary with coverage percentage
# - coverage/powershell/coverage.xml (JaCoCo format)

# View detailed coverage breakdown
cat coverage/powershell/coverage.xml
```

### Coverage Configuration Files

- **`pytest.ini`**: Python coverage configuration (paths, output formats, thresholds)
- **`codecov.yml`**: Codecov service configuration (flags, targets, precision)
- **`sonar-project.properties`**: SonarCloud coverage report paths
- **`tests/powershell/Invoke-Tests.ps1`**: PowerShell coverage test runner

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
