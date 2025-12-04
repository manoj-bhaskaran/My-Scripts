# Issue #003: Low Test Coverage Across Repository

## Severity
**High** - Impacts code quality, maintainability, and reliability

## Category
Testing / Quality Assurance

## Description
The repository currently has very low test coverage despite having a comprehensive testing infrastructure in place. According to `COVERAGE_ROADMAP.md`, the current coverage is:
- **Python Coverage**: ~1% (TBD baseline)
- **PowerShell Coverage**: 0.37% (21/5,751 commands)
- **Overall Project**: ~1%

While the repository has established a coverage ramp-up plan with phases extending over 9 months, the extremely low baseline poses immediate risks.

## Current State

### Testing Infrastructure (Excellent)
- ✅ 20 test files (7 Python, 8 PowerShell, 5 integration)
- ✅ Codecov integration active
- ✅ Coverage reporting in CI/CD
- ✅ Coverage badges in README
- ✅ pytest and Pester frameworks configured

### Coverage Gaps (Critical)

#### High-Risk Uncovered Components
1. **Database Backup Scripts** (Priority: CRITICAL)
   - `src/powershell/backup/*.ps1` - Financial data (GnuCash)
   - Impact: Data loss risk without test coverage
   - Target: 60% coverage per roadmap

2. **Data Processing Scripts** (Priority: CRITICAL)
   - `src/python/data/csv_to_gpx.py` - GPS data conversion
   - `src/python/data/extract_timeline_locations.py` - Location data
   - Impact: Data integrity issues, silent corruption
   - Target: 50-60% coverage

3. **Cloud Integration Scripts** (Priority: HIGH)
   - `src/python/cloud/google_drive_root_files_delete.py` - Destructive operations
   - `src/python/cloud/gdrive_recover.py` - Data recovery
   - Impact: Accidental data deletion without proper testing
   - Target: 50% coverage

4. **File Management Utilities** (Priority: HIGH)
   - `src/powershell/file-management/FileDistributor.ps1` (2,035 lines)
   - `src/powershell/file-management/Expand-ZipsAndClean.ps1` (744+ lines)
   - Impact: File loss, corruption, or misplacement
   - Target: 40-50% coverage

5. **Shared Modules** (Priority: HIGH)
   - `src/powershell/modules/Core/Logging/PowerShellLoggingFramework/`
   - `src/python/modules/logging/python_logging_framework.py`
   - `src/powershell/modules/Database/PostgresBackup/`
   - Impact: Widespread failures due to shared module bugs
   - Target: 60% coverage per roadmap

## Impact

### Current Risks
- **Data Loss**: Backup and file management scripts lack validation
- **Silent Failures**: No test coverage for error handling paths
- **Regression Risk**: Changes may break existing functionality undetected
- **Difficult Debugging**: No test harness to reproduce issues
- **Integration Failures**: Module interactions not validated

### Business Impact
- Financial data backups (GnuCash) unvalidated
- Personal timeline/location data at risk
- Cloud operations (delete, recovery) untested
- Media processing pipelines unverified

## Root Cause Analysis
1. **Legacy Scripts**: Many scripts predate test infrastructure
2. **Testing Complexity**: File I/O, database, and cloud operations require mocking
3. **Time Investment**: Comprehensive testing requires significant effort
4. **Prioritization**: Feature development prioritized over test coverage
5. **Gradual Improvement**: Roadmap addresses this with 9-month ramp-up plan

## Recommended Solution

### Phase 1: Immediate (Month 1-2) - Focus on Critical Paths
**Target**: 5% coverage minimum

Priority order:
1. **Database backup validation** - `PostgresBackup.psm1`
   - Test backup creation succeeds
   - Test retention policy enforcement
   - Test restore functionality

2. **Data integrity scripts** - `csv_to_gpx.py`, `validators.py`
   - Test data transformation accuracy
   - Test validation rules
   - Test error handling

3. **Destructive operations** - `google_drive_root_files_delete.py`
   - Test file selection logic
   - Test deletion confirmation
   - Test error recovery

### Phase 2: Core Modules (Month 3-4) - 15% Coverage
Following the existing roadmap in `COVERAGE_ROADMAP.md`:
- Shared modules: PowerShellLoggingFramework, python_logging_framework
- PostgresBackup and PurgeLogs modules
- Validators and utility functions

### Phase 3: Domain Scripts (Month 5-6) - 30% Coverage
- File management utilities
- Media processing scripts
- System maintenance scripts

### Phase 4: Comprehensive (Month 7+) - 50% Coverage
- Remaining scripts and edge cases
- Integration tests
- Platform-specific code paths

## Implementation Strategy

### Quick Wins (Start Immediately)
1. **Add smoke tests** for all entry-point scripts:
   ```python
   def test_script_imports():
       """Verify script can be imported without errors."""
       import my_script  # Should not raise
   ```

2. **Test critical functions** in isolation:
   - Validation logic
   - Data transformation
   - Path resolution

3. **Mock external dependencies**:
   - Database connections → Mock PostgreSQL
   - File system → Use pytest tmp_path
   - Google Drive API → Mock HTTP responses
   - Cloud services → Mock API clients

### Testing Patterns to Establish
```python
# Pattern 1: Validator testing
def test_validator_rejects_invalid_input():
    assert not validate_data("invalid")

# Pattern 2: Data transformation
def test_csv_to_gpx_conversion():
    input_csv = "test_data.csv"
    result = convert_csv_to_gpx(input_csv)
    assert result.waypoints == expected_waypoints

# Pattern 3: Error handling
def test_handles_missing_file_gracefully():
    with pytest.raises(FileNotFoundError):
        process_file("nonexistent.txt")
```

```powershell
# PowerShell pattern: Module function testing
Describe "PostgresBackup Module" {
    Context "Backup Creation" {
        It "Creates backup file successfully" {
            Mock Invoke-Command { return 0 }
            $result = Invoke-Backup -Database "test"
            $result | Should -Be $true
        }
    }
}
```

## Acceptance Criteria

### Immediate (2 weeks)
- [ ] Add smoke tests for all main scripts (20+ scripts)
- [ ] Test coverage reaches 3% minimum
- [ ] CI fails on coverage regression below 1%

### Month 2
- [ ] PostgresBackup module has 20%+ coverage
- [ ] Data validation scripts have 30%+ coverage
- [ ] Critical destructive operations have 40%+ coverage
- [ ] Overall coverage reaches 5%

### Month 4 (Per Existing Roadmap)
- [ ] Shared modules have 20%+ coverage
- [ ] Overall coverage reaches 15%
- [ ] Coverage threshold enforcement enabled

### Month 6 (Per Existing Roadmap)
- [ ] High-value scripts have adequate coverage
- [ ] Overall coverage reaches 30%
- [ ] Coverage quality metrics tracked

## Effort Estimate
- **Immediate smoke tests**: 8-16 hours (1-2 days)
- **Phase 1 critical path testing**: 40-60 hours (1-1.5 weeks)
- **Phase 2 core modules**: 80-120 hours (2-3 weeks)
- **Phase 3 domain scripts**: 120-160 hours (3-4 weeks)
- **Phase 4 comprehensive**: 160-240 hours (4-6 weeks)

**Total**: ~400-600 hours over 9 months (aligned with existing roadmap)

## Dependencies
- pytest, pytest-cov, pytest-mock (already installed)
- Pester (already installed)
- Mock libraries for external services
- Test fixtures for databases, files, API responses

## Monitoring
- Weekly review of Codecov dashboard
- Monthly assessment against roadmap milestones
- Coverage trend tracking in CI/CD artifacts

## Related Documents
- `docs/COVERAGE_ROADMAP.md` - Detailed 9-month plan
- `tests/README.md` - Testing guide
- `docs/guides/testing.md` - Testing standards

## Priority
**High** - Critical for data integrity and reliability. Follow the established roadmap but prioritize critical data-handling scripts immediately.

## Notes
- Roadmap is well-designed and realistic
- Infrastructure is already in place
- Main blocker is time investment, not technical barriers
- Should consider pairing coverage improvements with bug fixes and feature additions
- Each new feature should include corresponding tests (TDD approach)

## Success Metrics
- Coverage percentage (tracked in Codecov)
- Number of bugs caught by tests before production
- Regression rate (should decrease as coverage increases)
- Time to identify root cause of issues (should decrease)
- Confidence in refactoring (should increase)
