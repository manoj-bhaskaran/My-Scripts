# Coverage Ramp-Up Roadmap

## Current State (Baseline)

As of 2025-11-19, the My-Scripts repository has established test coverage infrastructure but is starting from a low coverage baseline:

- **Python Coverage**: ~TBD% (baseline to be established in CI)
- **PowerShell Coverage**: 0.37% (21/5,751 commands)
- **Overall Project**: ~1%

## Coverage Goals and Timeline

### Phase 1: Foundation (Current - Month 2)
**Goal**: Establish infrastructure and prevent regression

- **Minimum Thresholds**: 1% (Python), 0% (PowerShell)
- **Target**: Don't decrease coverage from baseline
- **Focus Areas**:
  - Coverage infrastructure fully operational
  - All tests passing in CI/CD
  - Coverage reports generated and visible
  - Developers familiar with coverage tools

**Success Criteria**:
- ✅ Codecov integrated and reporting
- ✅ Coverage badges visible in README
- ✅ Coverage reports generated locally and in CI
- ✅ No coverage regressions from baseline

### Phase 2: Core Modules (Month 3-4)
**Goal**: Achieve 15% overall coverage, focus on shared modules

- **Minimum Thresholds**: 5% (Python), 5% (PowerShell)
- **Target**: 15% overall, 20% for shared modules (src/common/)
- **Focus Areas**:
  - PowerShellLoggingFramework.psm1
  - python_logging_framework.py
  - PostgresBackup.psm1
  - PurgeLogs.psm1
  - Validators and utility functions

**Success Criteria**:
- [ ] Shared modules have >20% coverage
- [ ] Critical utility functions tested
- [ ] Coverage prevents regressions in core modules

### Phase 3: Domain Scripts (Month 5-6)
**Goal**: Achieve 30% overall coverage target

- **Minimum Thresholds**: 15% (Python), 15% (PowerShell)
- **Target**: 30% overall coverage
- **Focus Areas**:
  - High-value scripts (backup, data processing)
  - File management utilities
  - Database scripts
  - Data transformation scripts

**Success Criteria**:
- [ ] 30% overall coverage achieved
- [ ] High-risk scripts have adequate coverage
- [ ] Coverage threshold enforcement enabled (non-informational)

### Phase 4: Comprehensive Coverage (Month 7+)
**Goal**: Achieve 50%+ coverage, maintain quality

- **Minimum Thresholds**: 30% (Python), 30% (PowerShell)
- **Target**: 50%+ overall, 60% Python, 50% PowerShell
- **Focus Areas**:
  - Remaining scripts and modules
  - Edge cases and error handling
  - Integration tests
  - Platform-specific code paths

**Success Criteria**:
- [ ] 50% overall coverage
- [ ] Python >60% coverage
- [ ] PowerShell >50% coverage
- [ ] All critical paths tested
- [ ] Coverage quality metrics tracked

## Coverage Strategy by Component

### Shared Modules (Priority: HIGH)
- **Target**: 60% coverage
- **Rationale**: High reuse, critical infrastructure
- **Modules**:
  - PowerShellLoggingFramework.psm1
  - python_logging_framework.py
  - PostgresBackup.psm1
  - PurgeLogs.psm1
  - RandomName.psm1
  - Videoscreenshot.psm1

### Data Processing Scripts (Priority: HIGH)
- **Target**: 50-60% coverage
- **Rationale**: Financial/personal data integrity critical
- **Scripts**:
  - CSV processing (csv_to_gpx.py, etc.)
  - Timeline data extraction
  - Database backup scripts

### File Management Scripts (Priority: MEDIUM)
- **Target**: 40-50% coverage
- **Rationale**: Data safety important but lower complexity
- **Scripts**:
  - File distributors
  - Cleanup utilities
  - Archive scripts

### System Integration Scripts (Priority: LOW)
- **Target**: 20-30% coverage
- **Rationale**: High mocking overhead, platform-specific
- **Scripts**:
  - System maintenance
  - Service restarts
  - Network utilities

## Threshold Adjustment Schedule

### Current Configuration
```yaml
# pytest.ini
--cov-fail-under=1

# Invoke-Tests.ps1
-MinimumCoverage 0

# codecov.yml
project.target: auto (informational only)
patch.target: 10% (informational only)
```

### Month 2: Enable Basic Enforcement
```yaml
--cov-fail-under=5
-MinimumCoverage 5
project.informational: true (still informational)
```

### Month 4: Increase to 15%
```yaml
--cov-fail-under=15
-MinimumCoverage 15
project.target: 15% (informational: false)
```

### Month 6: Achieve Target Threshold
```yaml
--cov-fail-under=30
-MinimumCoverage 30
project.target: 30%
patch.target: 50%
```

## Monitoring and Reporting

### Weekly Review
- Review coverage trends in Codecov dashboard
- Identify uncovered high-risk code
- Prioritize testing efforts

### Monthly Assessment
- Evaluate progress against roadmap
- Adjust thresholds if needed
- Update team on coverage goals

### Quarterly Goals
- Month 3: 15% coverage milestone
- Month 6: 30% coverage milestone
- Month 9: 50% coverage milestone

## Coverage Quality Guidelines

Coverage percentage is not the only metric. Focus on:

1. **Critical Path Coverage**: Ensure main workflows tested
2. **Error Handling**: Test failure scenarios
3. **Edge Cases**: Test boundary conditions
4. **Integration Points**: Test module interactions
5. **Platform Coverage**: Test cross-platform code paths

## Tools and Resources

- **Codecov Dashboard**: https://codecov.io/gh/manoj-bhaskaran/My-Scripts
- **SonarCloud**: https://sonarcloud.io/dashboard?id=manoj-bhaskaran_My-Scripts
- **Local Reports**:
  - Python: `coverage/python/html/index.html`
  - PowerShell: `coverage/powershell/coverage.xml`

## References

- [Testing Guide](../tests/README.md)
- [Testing Standards](testing.md)
- [pytest-cov Documentation](https://pytest-cov.readthedocs.io/)
- [Pester Code Coverage](https://pester.dev/docs/usage/code-coverage)
