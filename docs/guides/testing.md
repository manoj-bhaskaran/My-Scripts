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

| Component | Minimum Coverage | Target Coverage |
|-----------|-----------------|----------------|
| Shared modules (src/common/) | 30% | 60% |
| Utility modules | 30% | 50% |
| Script-specific code | 20% | 40% |
| Overall project | 25% | 45% |

### Coverage Guidelines

- **Quality over quantity**: 100% coverage doesn't guarantee bug-free code
- **Focus on critical paths**: Prioritize testing core business logic
- **Don't test trivial code**: Simple getters/setters may not need tests
- **Test complex logic**: Focus on algorithms, validation, and transformations

### Viewing Coverage Reports

**Python**:
```bash
# Terminal report
pytest tests/python --cov=src --cov-report=term-missing

# HTML report
pytest tests/python --cov=src --cov-report=html
# Open htmlcov/index.html in browser
```

**PowerShell**:
```powershell
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.OutputFormat = 'JaCoCo'
Invoke-Pester -Configuration $config
```

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
