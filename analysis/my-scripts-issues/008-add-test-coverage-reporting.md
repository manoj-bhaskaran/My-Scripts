# Add Test Coverage Reporting to CI/CD

## Priority
**MODERATE** 🟡

## Background
The My-Scripts repository's SonarCloud CI workflow **explicitly excludes coverage reporting**:

```yaml
-Dsonar.python.coverage.reportPaths=
-Dsonar.coverage.exclusions="**/*"
```

Even after implementing test infrastructure (Issue #001), there's **no visibility into test coverage**:
- No coverage reports generated
- No coverage badges
- No coverage trends tracked
- No enforcement of minimum coverage thresholds

**Impact:**
- Cannot track testing progress
- No visibility into untested code
- Risk of coverage regression
- Difficult to identify testing gaps

## Objectives
- Enable coverage reporting for Python (pytest-cov)
- Enable coverage reporting for PowerShell (Pester)
- Integrate coverage reports with SonarCloud
- Add coverage badges to README.md
- Set minimum coverage thresholds
- Track coverage trends over time

## Tasks

### Phase 1: Configure Python Coverage
- [ ] Add pytest-cov to `requirements.txt`:
  ```txt
  pytest>=7.0.0
  pytest-cov>=4.0.0
  pytest-mock>=3.10.0
  ```
- [ ] Create `pytest.ini` (if not exists from Issue #001):
  ```ini
  [pytest]
  testpaths = tests/python
  python_files = test_*.py
  python_classes = Test*
  python_functions = test_*
  addopts =
      --cov=src/python
      --cov-report=term-missing
      --cov-report=html:coverage/python/html
      --cov-report=xml:coverage/python/coverage.xml
      --cov-fail-under=30
  ```
- [ ] Update `.gitignore` to exclude coverage artifacts:
  ```gitignore
  # Coverage
  coverage/
  .coverage
  htmlcov/
  *.cover
  .hypothesis/
  ```

### Phase 2: Configure PowerShell Coverage
- [ ] Install Pester with coverage support:
  ```powershell
  Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
  ```
- [ ] Create PowerShell coverage configuration:
  ```powershell
  # tests/powershell/Invoke-Tests.ps1
  $config = New-PesterConfiguration
  $config.Run.Path = 'tests/powershell'
  $config.CodeCoverage.Enabled = $true
  $config.CodeCoverage.Path = @(
      'src/powershell/**/*.ps1'
      'src/powershell/**/*.psm1'
  )
  $config.CodeCoverage.OutputPath = 'coverage/powershell/coverage.xml'
  $config.CodeCoverage.OutputFormat = 'JaCoCo'  # SonarCloud-compatible
  $config.Output.Verbosity = 'Detailed'

  Invoke-Pester -Configuration $config
  ```

### Phase 3: Update CI Workflow
- [ ] Update `.github/workflows/sonarcloud.yml`:
  ```yaml
  # Add after Python installation
  - name: Run Python Tests with Coverage
    run: |
      pip install pytest pytest-cov pytest-mock
      pytest tests/python \
        --cov=src/python \
        --cov-report=xml:coverage/python/coverage.xml \
        --cov-report=term-missing \
        --cov-fail-under=30

  - name: Upload Python Coverage to Codecov
    uses: codecov/codecov-action@v3
    with:
      files: coverage/python/coverage.xml
      flags: python
      name: python-coverage

  # Add after PowerShell installation
  - name: Run PowerShell Tests with Coverage
    shell: pwsh
    run: |
      Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
      .\tests\powershell\Invoke-Tests.ps1

  - name: Upload PowerShell Coverage to Codecov
    uses: codecov/codecov-action@v3
    with:
      files: coverage/powershell/coverage.xml
      flags: powershell
      name: powershell-coverage

  # Update SonarCloud scanner
  - name: SonarCloud Scan
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    run: |
      sonar-scanner \
        -Dsonar.projectKey=manoj-bhaskaran_My-Scripts \
        -Dsonar.organization=manoj-bhaskaran \
        -Dsonar.sources=src \
        -Dsonar.tests=tests \
        -Dsonar.python.coverage.reportPaths=coverage/python/coverage.xml \
        -Dsonar.powershell.coverage.reportPaths=coverage/powershell/coverage.xml \
        -Dsonar.coverage.exclusions="**/tests/**,**/fixtures/**,**/*.sample" \
        -Dsonar.host.url=https://sonarcloud.io
  ```

### Phase 4: Add Coverage Badges
- [ ] Sign up for Codecov (https://about.codecov.io/) if not already
- [ ] Add `codecov.yml` configuration:
  ```yaml
  coverage:
    status:
      project:
        default:
          target: 30%
          threshold: 5%
      patch:
        default:
          target: 50%
    precision: 2
    round: down
    range: "50...80"

  ignore:
    - "tests/"
    - "**/*.sample"
    - "fixtures/"

  flags:
    python:
      paths:
        - src/python/
    powershell:
      paths:
        - src/powershell/
  ```
- [ ] Add badges to README.md:
  ```markdown
  # My Scripts Collection

  [![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=manoj-bhaskaran_My-Scripts&metric=alert_status)](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)
  [![codecov](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
  [![Python Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=python)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
  [![PowerShell Coverage](https://codecov.io/gh/manoj-bhaskaran/My-Scripts/branch/main/graph/badge.svg?flag=powershell)](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
  ```

### Phase 5: Set Coverage Thresholds
- [ ] Define minimum coverage targets by category:
  ```markdown
  ## Coverage Targets

  | Category | Target | Rationale |
  |----------|--------|-----------|
  | Shared Modules (Core) | 80% | High reuse, critical infrastructure |
  | Data Processing | 70% | Financial/personal data integrity |
  | File Management | 60% | Data safety critical |
  | Database Scripts | 50% | Can use test databases |
  | System Integration | 30% | High mocking overhead |
  ```
- [ ] Configure pytest to fail on insufficient coverage:
  ```ini
  # pytest.ini
  [pytest]
  addopts =
      --cov=src/python
      --cov-fail-under=30  # Start low, increase gradually
  ```
- [ ] Create coverage report in pre-commit hook:
  ```bash
  # .git/hooks/pre-commit (add to existing)
  if [ -n "$CHANGED_PY_FILES" ]; then
    pytest tests/python \
      --cov=src/python \
      --cov-report=term-missing \
      --cov-fail-under=30 \
      -q
  fi
  ```

### Phase 6: Coverage Reporting Locally
- [ ] Document how to generate coverage reports locally:
  ```markdown
  ## Local Coverage Reports

  ### Python Coverage
  ```bash
  # Run tests with coverage
  pytest tests/python --cov=src/python --cov-report=html

  # Open HTML report
  open coverage/python/html/index.html  # macOS
  xdg-open coverage/python/html/index.html  # Linux
  start coverage\python\html\index.html  # Windows
  ```

  ### PowerShell Coverage
  ```powershell
  # Run tests with coverage
  .\tests\powershell\Invoke-Tests.ps1

  # View coverage report
  # (Pester outputs to console; for HTML, use ReportGenerator)
  ```

  ### Combined Coverage Report
  ```bash
  # Install ReportGenerator (optional)
  dotnet tool install -g dotnet-reportgenerator-globaltool

  # Generate combined report
  reportgenerator \
    -reports:"coverage/**/*.xml" \
    -targetdir:"coverage/combined" \
    -reporttypes:"Html;Badges"

  open coverage/combined/index.html
  ```
  ```
- [ ] Add to `docs/guides/testing.md`

### Phase 7: Coverage Trend Tracking
- [ ] Create coverage history tracking:
  - Codecov automatically tracks trends
  - SonarCloud tracks coverage over time
  - Document how to view trends
- [ ] Set up coverage alerts:
  ```yaml
  # codecov.yml
  coverage:
    status:
      project:
        default:
          target: auto
          threshold: 5%  # Alert if coverage drops >5%
          informational: true
  ```

### Phase 8: Coverage Exclusions
- [ ] Define what should be excluded from coverage:
  ```python
  # Python: Use pragma comments
  def debug_only_function():  # pragma: no cover
      print("Debug info")
  ```
  ```powershell
  # PowerShell: Exclude from Pester config
  $config.CodeCoverage.ExcludeTests = $true
  ```
- [ ] Document exclusion patterns in `codecov.yml`:
  ```yaml
  ignore:
    - "tests/"
    - "**/*.sample"
    - "fixtures/"
    - "**/*Debug*.ps1"
    - "**/*[Tt]est*.py"
  ```

### Phase 9: Documentation
- [ ] Update `docs/guides/testing.md`:
  - How coverage is measured
  - How to generate local coverage reports
  - How to view coverage in CI
  - Coverage targets and thresholds
  - How to exclude code from coverage
- [ ] Add coverage section to root README.md:
  ```markdown
  ## Test Coverage

  We maintain test coverage to ensure code quality:
  - **Python**: ≥30% coverage (target: 60%)
  - **PowerShell**: ≥30% coverage (target: 50%)

  View coverage reports:
  - [Codecov Dashboard](https://codecov.io/gh/manoj-bhaskaran/My-Scripts)
  - [SonarCloud Quality Gate](https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts)

  See [Testing Guide](docs/guides/testing.md) for details.
  ```

## Acceptance Criteria
- [x] Python coverage reporting configured (pytest-cov)
- [x] PowerShell coverage reporting configured (Pester 5.0+)
- [x] Coverage reports generated in CI pipeline
- [x] Coverage uploaded to Codecov and SonarCloud
- [x] Coverage badges added to README.md (minimum 2 badges)
- [x] Minimum coverage thresholds enforced (≥30%)
- [x] Coverage exclusions properly configured
- [x] Local coverage report generation documented
- [x] Coverage trends visible in Codecov/SonarCloud
- [x] Coverage documentation added to `docs/guides/testing.md`
- [x] CI fails if coverage drops below threshold

## Testing Checklist
- [ ] Run pytest locally with coverage: `pytest --cov=src/python`
- [ ] Run Pester locally with coverage: `.\tests\powershell\Invoke-Tests.ps1`
- [ ] Verify coverage reports generated in `coverage/` directory
- [ ] Verify coverage uploaded to Codecov (check web UI)
- [ ] Verify coverage visible in SonarCloud (check dashboard)
- [ ] Verify badges display correctly in README.md
- [ ] Test coverage threshold enforcement (artificially lower coverage)
- [ ] Verify HTML coverage reports open and display correctly

## Related Files
- `pytest.ini` (from Issue #001)
- `.github/workflows/sonarcloud.yml` (to be updated)
- `codecov.yml` (to be created)
- `tests/powershell/Invoke-Tests.ps1` (to be created)
- `.gitignore` (to be updated)
- `README.md` (to be updated)
- `docs/guides/testing.md` (to be updated)

## Estimated Effort
**1-2 days** (configuration, testing, documentation)

## Dependencies
- Issue #001 (Test Infrastructure) – must be completed first
- Codecov account setup (free for open source)

## Optional Enhancements
- [ ] Add coverage visualization in PR comments (Codecov feature)
- [ ] Create coverage diff reports (show changed files coverage)
- [ ] Implement coverage ratcheting (prevent coverage decrease)
- [ ] Add coverage per-module breakdown
- [ ] Create coverage improvement goals/roadmap

## References
- [pytest-cov Documentation](https://pytest-cov.readthedocs.io/)
- [Pester Code Coverage](https://pester.dev/docs/usage/code-coverage)
- [Codecov Documentation](https://docs.codecov.com/)
- [SonarCloud Coverage](https://docs.sonarcloud.io/enriching/test-coverage/overview/)
- [JaCoCo Format](https://www.jacoco.org/jacoco/trunk/doc/)
