# Testing Standards and Guidelines

This document outlines the testing standards and best practices for the My-Scripts repository.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Organization](#test-organization)
3. [Naming Conventions](#naming-conventions)
4. [Writing Good Tests](#writing-good-tests)
5. [Code Coverage](#code-coverage)
6. [Mocking and Dependencies](#mocking-and-dependencies)
7. [CI/CD Integration](#cicd-integration)

## Testing Philosophy

Our testing approach follows these core principles:

- **Test Early, Test Often**: Write tests as you develop new features
- **Maintainability**: Tests should be easy to understand and maintain
- **Reliability**: Tests should be deterministic and not flaky
- **Speed**: Tests should run quickly to enable rapid feedback
- **Coverage**: Aim for meaningful coverage, not just high percentages

## Test Organization

### Directory Structure

```
tests/
├── python/
│   ├── unit/              # Unit tests for Python modules
│   └── conftest.py        # Shared fixtures and configuration
└── powershell/
    └── unit/              # Unit tests for PowerShell scripts
```

### Test Types

#### Unit Tests
- Test individual functions/methods in isolation
- Mock external dependencies
- Fast execution (< 1 second per test)
- Located in `unit/` directories

#### Integration Tests (Future)
- Test interaction between components
- May use actual file system or databases
- Slower execution
- Will be located in `integration/` directories

## Naming Conventions

### Python Tests

**File Naming**:
- Pattern: `test_<module_name>.py`
- Example: `test_validators.py`

**Class Naming**:
- Pattern: `Test<ClassName>` or `Test<FunctionName>`
- Example: `TestNormalizeExtensionToken`

**Method Naming**:
- Pattern: `test_<what_is_being_tested>`
- Use descriptive names that explain the test purpose
- Example: `test_normalization_removes_leading_dots`

### PowerShell Tests

**File Naming**:
- Pattern: `<ModuleName>.Tests.ps1`
- Example: `RandomName.Tests.ps1`

**Structure**:
- Use `Describe` for the function/module being tested
- Use `Context` to group related test scenarios
- Use `It` for individual test cases

**Example**:
```powershell
Describe "Get-RandomFileName" {
    Context "Length Constraints" {
        It "Should respect default length range" {
            # Test code
        }
    }
}
```

## Writing Good Tests

### Test Structure

Follow the **Arrange-Act-Assert** pattern:

```python
def test_example():
    # Arrange: Set up test data
    input_data = "test input"

    # Act: Execute the code being tested
    result = function_under_test(input_data)

    # Assert: Verify the result
    assert result == expected_output
```

### Test Independence

- Each test should be independent and not rely on other tests
- Use fixtures/setup methods for common initialization
- Clean up after tests (use teardown or context managers)
- Avoid test ordering dependencies

### Test Clarity

- **One assertion per test** (when practical)
- Use descriptive assertion messages
- Keep tests simple and focused
- Avoid complex logic in tests

### Edge Cases and Error Handling

Test the following scenarios:
- Normal/happy path
- Boundary conditions
- Invalid inputs
- Error conditions
- Edge cases specific to your domain

Example:
```python
class TestValidateExtensions:
    def test_valid_extensions(self):
        # Test normal case
        pass

    def test_empty_input(self):
        # Test boundary case
        pass

    def test_invalid_characters(self):
        # Test error condition
        pass
```

## Code Coverage

### Coverage Targets

We are implementing a phased approach to coverage, starting from a low baseline and ramping up over 6 months.

**Current Status (Phase 1):**

| Component | Current | Phase 1 (Now) | Phase 2 (Month 4) | Phase 3 (Month 6) | Target |
|-----------|---------|---------------|-------------------|-------------------|--------|
| Python | ~TBD% | >1% | >15% | >30% | 60% |
| PowerShell | 0.37% | >0% | >15% | >30% | 50% |
| Shared modules | ~TBD% | >1% | >20% | >30% | 60% |
| Overall | ~1% | >1% | >15% | >30% | 50% |

See [Coverage Roadmap](../COVERAGE_ROADMAP.md) for complete ramp-up plan and timeline.

### Coverage Enforcement

Coverage thresholds are automatically enforced in CI/CD, with gradual increases:

**Current Thresholds (Phase 1 - Baseline Establishment):**

- **Python**: Tests fail if coverage drops below 1%
  - Configured in `pytest.ini` via `--cov-fail-under=1`
  - Starting point to prevent regression from baseline
  - Can be overridden locally: `pytest --cov-fail-under=0`

- **PowerShell**: No minimum enforced (0%)
  - Configured in `tests/powershell/Invoke-Tests.ps1` with `-MinimumCoverage 0`
  - Establishes baseline at 0.37% (21/5,751 commands)
  - Adjustable: `.\Invoke-Tests.ps1 -MinimumCoverage <value>`

- **Codecov Integration**:
  - **Informational only** during Phase 1 (doesn't fail builds)
  - Tracks coverage trends with `target: auto`
  - Alerts on coverage drops >5%
  - Provides PR-level coverage diffs
  - Will be switched to enforcing mode in Phase 3

**Planned Threshold Increases:**
- **Month 2** (Phase 1 end): 5% Python, 5% PowerShell
- **Month 4** (Phase 2): 15% Python, 15% PowerShell
- **Month 6** (Phase 3): 30% Python, 30% PowerShell (target achieved)
- **Month 9+** (Phase 4): Maintain and improve toward 50%+

**Rationale:**
Starting from 0.37% PowerShell coverage, we're using a phased approach to:
1. Avoid breaking the build while establishing baseline
2. Allow time to write tests for existing code
3. Gradually increase standards as coverage improves
4. Focus initial efforts on high-value modules

### Coverage Guidelines

- **Quality over quantity**: 100% coverage doesn't guarantee bug-free code
- **Focus on critical paths**: Prioritize testing core business logic
- **Don't test trivial code**: Simple getters/setters may not need tests
- **Test complex logic**: Focus on algorithms, validation, and transformations
- **Exclude appropriately**: Use coverage exclusions for debug code, platform-specific code
- **Track trends**: Monitor coverage over time, not just absolute values

### Viewing Coverage Reports

**Python - Local HTML Reports**:
```bash
# Run tests (automatically generates coverage)
pytest tests/python

# Coverage reports generated at:
# - coverage/python/coverage.xml (machine-readable, for CI)
# - coverage/python/html/index.html (human-readable, for developers)

# Open HTML report
open coverage/python/html/index.html      # macOS
xdg-open coverage/python/html/index.html  # Linux
start coverage/python/html/index.html     # Windows
```

**Python - Terminal Reports**:
```bash
# Terminal report with missing lines
pytest tests/python --cov=src/python --cov=src/common --cov-report=term-missing

# Compact terminal report
pytest tests/python --cov-report=term
```

**PowerShell - Using Helper Script (Recommended)**:
```powershell
# Run with coverage reporting
.\tests\powershell\Invoke-Tests.ps1

# Coverage output includes:
# - Terminal summary with coverage percentage
# - coverage/powershell/coverage.xml (JaCoCo format)

# Customize coverage threshold
.\tests\powershell\Invoke-Tests.ps1 -MinimumCoverage 50
```

**PowerShell - Manual Configuration**:
```powershell
$config = New-PesterConfiguration
$config.Run.Path = 'tests/powershell'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('src/powershell/**/*.ps1', 'src/common/*.ps1')
$config.CodeCoverage.OutputPath = 'coverage/powershell/coverage.xml'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
Invoke-Pester -Configuration $config
```

### Online Coverage Dashboards

**Codecov** (Primary Coverage Tool):
- URL: https://codecov.io/gh/manoj-bhaskaran/My-Scripts
- Features:
  - Coverage trends and graphs
  - File-by-file coverage breakdown
  - PR coverage diffs (shows coverage impact of changes)
  - Language-specific flags (Python, PowerShell)
  - Sunburst visualization of coverage
  - Coverage annotations on GitHub PRs

**SonarCloud** (Code Quality + Coverage):
- URL: https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts
- Features:
  - Coverage as part of quality gate
  - Combined with code smells and security issues
  - Historical trends
  - Maintainability ratings

### Coverage Configuration Files

- **`pytest.ini`**: Python test and coverage configuration
  - Coverage paths: `src/python`, `src/common`
  - Output formats: XML, HTML, terminal
  - Minimum threshold: 30%

- **`codecov.yml`**: Codecov service configuration
  - Coverage targets (30% project, 50% patch)
  - Threshold tolerance (5% drop allowed)
  - Language flags (python, powershell)
  - File exclusions (tests, samples, docs)

- **`sonar-project.properties`**: SonarCloud configuration
  - Coverage report paths
  - Coverage exclusions
  - Quality gate settings

- **`tests/powershell/Invoke-Tests.ps1`**: PowerShell test runner
  - Configurable coverage thresholds
  - Automatic report generation
  - Verbose output options

### Excluding Code from Coverage

**Python - Inline Exclusions**:
```python
def debug_only_function():  # pragma: no cover
    """This function is excluded from coverage"""
    print("Debug information")

if __name__ == "__main__":  # pragma: no cover
    # Script execution code
    main()
```

**Python - Branch Exclusions**:
```python
def cross_platform_function():
    if sys.platform == 'win32':
        # Windows-specific code
        return windows_implementation()
    else:  # pragma: no cover
        # Unix-specific code (excluded on Windows)
        return unix_implementation()
```

**PowerShell - File Exclusions**:
Configure in `tests/powershell/Invoke-Tests.ps1` or use file naming:
- Files ending in `.Debug.ps1`
- Test files (`*.Tests.ps1`)
- Sample/example files

**Global Exclusions** (codecov.yml):
```yaml
ignore:
  - "tests/"
  - "**/*.sample"
  - "fixtures/"
  - "**/test_*.py"
```

### Coverage Best Practices

1. **Write tests before checking coverage**: Don't let coverage drive test design
2. **Use coverage to find gaps**: Identify untested code paths
3. **Don't game the metrics**: Executing a line ≠ testing it properly
4. **Review coverage in PRs**: Check that new code has adequate tests
5. **Maintain coverage trends**: Don't let coverage decrease over time
6. **Focus on critical code**: 80% coverage of critical code > 95% of trivial code

## Mocking and Dependencies

### When to Mock

Mock external dependencies when:
- Accessing file system
- Making network requests
- Calling external APIs
- Interacting with databases
- Using system resources (time, random, etc.)

### Python Mocking Examples

```python
from unittest.mock import patch, MagicMock

# Mock a function
@patch('module.external_function')
def test_with_mock(mock_func):
    mock_func.return_value = "mocked result"
    result = my_function()
    assert result == expected

# Mock file operations
@patch('builtins.open', mock_open(read_data='file content'))
def test_file_reading():
    result = read_file('test.txt')
    assert result == 'file content'
```

### PowerShell Mocking Examples

```powershell
# Mock a cmdlet
Mock Get-ChildItem { return @('file1.txt', 'file2.txt') }

# Mock with parameter filtering
Mock Copy-Item { } -ParameterFilter { $Path -eq 'source.txt' }

# Verify mock was called
Assert-MockCalled Copy-Item -Times 1
```

### Mocking Best Practices

- Mock at the boundary of your system
- Don't over-mock - keep tests meaningful
- Verify mock interactions when important
- Use real objects when simple and fast

## CI/CD Integration

### Automated Testing

Tests run automatically on:
- Every push to any branch
- Every pull request to main
- Scheduled nightly builds (if configured)

### CI Workflow

1. **Checkout code**
2. **Install dependencies**
3. **Run Python tests** with coverage
4. **Run PowerShell tests** with coverage
5. **Upload coverage reports** to SonarCloud
6. **Run linters** (pylint, PSScriptAnalyzer)
7. **Run security scans** (bandit)
8. **Generate reports**

### Test Failure Handling

- **All tests must pass** before merging to main
- Fix failing tests immediately
- Don't disable or skip tests without good reason
- Document skipped tests with clear explanations

### Performance Requirements

- **Total test execution**: < 2 minutes in CI
- **Individual test**: < 5 seconds
- **Test suite startup**: < 10 seconds

If tests exceed these limits:
1. Optimize slow tests
2. Move to integration test suite
3. Consider parallelization

## Continuous Improvement

### Test Maintenance

- **Review tests during code review**
- **Refactor tests when code changes**
- **Remove obsolete tests**
- **Update tests for new requirements**

### Metrics to Track

- Code coverage percentage
- Test execution time
- Test failure rate
- Number of skipped/disabled tests

### Regular Audits

Quarterly review of:
- Test coverage gaps
- Slow running tests
- Flaky tests
- Test code quality

## Resources

- [pytest documentation](https://docs.pytest.org/)
- [Pester documentation](https://pester.dev/)
- [Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
- [Mocking Best Practices](https://martinfowler.com/articles/mocksArentStubs.html)

## Getting Help

- Check [tests/README.md](../../tests/README.md) for running tests
- Review existing tests for examples
- Ask questions in pull request reviews
- Open an issue for testing infrastructure improvements
