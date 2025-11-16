# Implement Test Infrastructure

## Priority
**CRITICAL** 🔴

## Background
The My-Scripts repository currently has **zero test coverage** despite the README.md claiming a `tests/` directory exists. This creates high risk for regressions, makes refactoring dangerous, and reduces confidence in script reliability.

The SonarCloud CI workflow explicitly excludes coverage reporting:
```yaml
-Dsonar.python.coverage.reportPaths=
-Dsonar.coverage.exclusions="**/*"
```

Key scripts that handle financial data (GnuCash backups), personal data (Google Timeline), and critical file operations (FileDistributor, duplicate removal) have no automated validation.

## Objectives
- Create comprehensive test infrastructure for both PowerShell and Python
- Achieve minimum 30% coverage for shared modules (Phase 1 target)
- Integrate test execution and coverage reporting into CI/CD
- Establish testing standards and documentation

## Tasks

### Phase 1: Infrastructure Setup
- [ ] Create `tests/` directory structure:
  ```
  tests/
  ├── powershell/
  │   ├── unit/
  │   ├── integration/
  │   └── fixtures/
  ├── python/
  │   ├── unit/
  │   ├── integration/
  │   └── fixtures/
  ├── conftest.py
  ├── pytest.ini
  └── README.md
  ```
- [ ] Create `pytest.ini` with appropriate settings
- [ ] Create `conftest.py` for shared test fixtures
- [ ] Add test dependencies to `requirements.txt`:
  - pytest
  - pytest-cov
  - pytest-mock
- [ ] Install Pester for PowerShell testing: `Install-Module -Name Pester -Force`

### Phase 2: Write Initial Tests (Quick Wins)
- [ ] `tests/python/unit/test_validators.py` – Test input validation functions
- [ ] `tests/powershell/unit/RandomName.Tests.ps1` – Test filename generation module
- [ ] `tests/python/unit/test_logging_framework.py` – Test logging framework core functions
- [ ] `tests/python/unit/test_csv_to_gpx.py` – Test data transformation logic
- [ ] `tests/powershell/unit/FileDistributor.Tests.ps1` – Test business logic (mocked file ops)

### Phase 3: CI Integration
- [ ] Update `.github/workflows/sonarcloud.yml` to run pytest with coverage:
  ```yaml
  - name: Run Python Tests with Coverage
    run: |
      pip install pytest pytest-cov
      pytest tests/python --cov=src/python --cov-report=xml --cov-report=term
  ```
- [ ] Add PowerShell test execution:
  ```yaml
  - name: Run PowerShell Tests
    shell: pwsh
    run: |
      Install-Module -Name Pester -Force -Scope CurrentUser
      Invoke-Pester -Path tests/powershell -OutputFormat NUnitXml -CodeCoverage src/powershell/**/*.ps1
  ```
- [ ] Update SonarCloud configuration to include coverage:
  ```yaml
  -Dsonar.python.coverage.reportPaths=coverage.xml
  -Dsonar.coverage.exclusions="**/tests/**,**/fixtures/**"
  ```
- [ ] Verify coverage reports appear in SonarCloud dashboard

### Phase 4: Documentation
- [ ] Create `tests/README.md` with:
  - How to run tests locally
  - How to write new tests
  - Coverage targets by script category
  - Mocking strategies for external dependencies
- [ ] Add testing section to root `README.md`
- [ ] Document testing standards in new `docs/guides/testing.md`

## Acceptance Criteria
- [x] `tests/` directory exists with proper structure
- [x] pytest and Pester frameworks installed and configured
- [x] Minimum 5 test files created (3 Python + 2 PowerShell)
- [x] All tests pass in CI pipeline
- [x] Coverage reports generated and visible in SonarCloud
- [x] Shared modules achieve ≥30% coverage
- [x] Testing documentation published
- [x] Test execution time <2 minutes in CI

## Related Files
- `.github/workflows/sonarcloud.yml`
- `requirements.txt`
- `src/python/validators.py`
- `src/powershell/module/RandomName/`
- `src/common/python_logging_framework.py`

## Estimated Effort
**2-3 days** for Phase 1-3, **1 day** for Phase 4

## Dependencies
None (foundational work)

## References
- [pytest Documentation](https://docs.pytest.org/)
- [pytest-cov Plugin](https://pytest-cov.readthedocs.io/)
- [Pester Documentation](https://pester.dev/)
- [SonarCloud Test Coverage](https://docs.sonarcloud.io/enriching/test-coverage/overview/)
