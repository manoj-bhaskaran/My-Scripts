# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.6.0] - 2025-12-06

### Added

- **TOML-based Module Deployment Configuration** (#604 Phase 1 of #009)
  - Created `psmodule.toml` - Single source of truth for PowerShell module deployment
  - Created `psmodule.local.toml.example` - Example user-specific configuration overrides
  - **Configuration Consolidation**:
    - Replaced multiple configuration files (deployment.txt, local-deployment-config.json) with single TOML file
    - Reduced configuration complexity from 3 files to 1
    - Supports all 8 PowerShell modules with proper metadata
    - Standard TOML format with comments support
  - **Module Configuration Features**:
    - Auto-detect PowerShell module paths or use custom paths
    - Testing and validation options (test-on-deploy, validate-manifest, import-after-deploy)
    - Module discovery with auto-discover and source-paths configuration
    - Module dependencies support (e.g., PurgeLogs depends on PowerShellLoggingFramework)
    - Per-module settings (auto-deploy, test-on-deploy, description, author)
  - **Implementation Scripts**:
    - `scripts/Read-ModuleConfig.ps1` - TOML parser with Tomlyn.Signed support and fallback
    - `scripts/Migrate-ModuleConfig.ps1` - Migration script from legacy format to TOML
    - Automatic installation of TOML parser (Tomlyn.Signed) if not available
    - Configuration merging for local overrides (psmodule.local.toml)
  - **Configuration Structure**:
    - `[deployment]` section with global deployment settings
    - `[[modules]]` array defining all 8 PowerShell modules:
      - PowerShellLoggingFramework (Core logging framework)
      - ErrorHandling (Standardized error handling with retry logic)
      - FileOperations (Resilient file operations)
      - ProgressReporter (Progress tracking with logging integration)
      - PurgeLogs (Log retention management)
      - PostgresBackup (PostgreSQL backup with retention)
      - RandomName (Windows-safe random filename generation)
      - Videoscreenshot (Video frame capture via VLC or GDI+)
  - **Benefits**:
    - ✅ Single configuration file (reduced from 3 to 1)
    - ✅ Standard TOML format easier to read and edit
    - ✅ Schema validation possible
    - ✅ Comments supported for documentation
    - ✅ Module dependencies explicitly defined
    - ✅ User-specific overrides without modifying shared config
  - **Documentation**:
    - Updated README.md with TOML configuration section
    - Updated .gitignore to exclude psmodule.local.toml
    - Migration guide in Migrate-ModuleConfig.ps1
    - Comprehensive inline documentation in all TOML files

## [2.5.0] - 2025-12-06

### Added

- **FileSystem Core Module** (#601 Phase 1 of #008)
  - Created new `FileSystem` module under `src/powershell/modules/Core/FileSystem/`
  - **Public Functions**:
    - `New-DirectoryIfMissing` - Creates directories with error handling and Force parameter support
    - `Test-FileAccessible` - Tests file accessibility for Read, Write, or ReadWrite operations
    - `Test-PathValid` - Validates paths according to filesystem rules with optional wildcard support
    - `Test-FileLocked` - Detects if a file is locked by another process
  - **Private Functions**:
    - `Get-FileLockInfo` - Internal helper to identify locking processes
  - **Module Features**:
    - Proper error handling with verbose logging
    - PowerShell 5.1+ compatibility
    - Comprehensive parameter validation
    - Follows Public/Private module structure pattern
  - **Testing**:
    - Complete unit test suite in `tests/powershell/unit/FileSystem.Tests.ps1`
    - Tests cover all public functions and edge cases
    - Validates module exports and function isolation
  - **Script Migrations**:
    - Updated `Expand-ZipsAndClean.ps1` to use `New-DirectoryIfMissing` (5 instances)
    - Updated `Remove-EmptyFolders.ps1` to use `New-DirectoryIfMissing`
    - Updated `Remove-DuplicateFiles.ps1` to use `New-DirectoryIfMissing`
  - **Benefits**:
    - ✅ Reusable file system operations across scripts
    - ✅ Consistent error handling and validation
    - ✅ Easier to test and maintain
    - ✅ Reduces code duplication in large scripts
    - ✅ Foundation for further refactoring (Issue #008)

## [2.4.1] - 2025-12-06

### Added

- **Type Hints for Data Processing Scripts** (#005 Phase 3)
  - Added explicit type annotations to `src/python/data/csv_to_gpx.py`, `src/python/data/validators.py`, and `src/python/data/extract_timeline_locations.py`
  - Updated docstrings to reflect typed arguments and return values for CSV, GPX, and timeline data flows
  - Ensured mypy compatibility for critical data-processing paths

- **Type Hints for Error Handling Module** (#596 Phase 2 of #005)
  - Added comprehensive type hints to `src/python/modules/utils/error_handling.py`
  - **New Functions with Full Type Support**:
    - `retry_on_exception()` decorator with generic type preservation using `TypeVar[T]`
    - `error_handler()` context manager with proper Iterator type hints
    - Enhanced `safe_execute()` with generics accepting *args and **kwargs
  - **Improved Existing Functions**:
    - `retry_operation()` now uses generic `TypeVar[T]` for return type preservation
    - `with_retry()` decorator updated with proper tuple type annotations
    - `ErrorContext` class with properly typed `__enter__` and `__exit__` methods
  - **Type Annotations Added**:
    - `retry_on_exception()` with signature: `Callable[[Callable[..., T]], Callable[..., T]]`
    - `retry_operation()` with return type: `T` (preserves operation return type)
    - `safe_execute()` with signature: `Callable[..., T], *args, **kwargs -> Union[T, None]`
    - `error_handler()` with signature: `Iterator[None]` context manager
    - All wrapper functions properly annotated with `*args: Any, **kwargs: Any`
  - **Testing**:
    - Added comprehensive type preservation tests (13 new tests)
    - Tests verify return type preservation for int, str, list, dict types
    - Tests validate decorator behavior with different exception types
    - Tests confirm proper argument passing with *args and **kwargs
  - **Benefits**:
    - ✅ Passes mypy --strict validation
    - ✅ Complete type safety with generic decorators
    - ✅ IDE autocomplete shows correct return types
    - ✅ Type errors caught at development time
    - ✅ Self-documenting code with clear type signatures
    - ✅ Backward compatible with all existing code
  - **Technical Notes**:
    - Used `from __future__ import annotations` for forward reference support
    - Added proper `TypeVar[T]` for return type preservation
    - Used `type: ignore` comments for standard library compatibility issues
    - All 42 unit tests pass successfully

- **Type Hints for Logging Framework Module** (#005b Phase 2 of #005)
  - Added comprehensive type hints to `src/python/modules/logging/python_logging_framework.py`
  - All public functions and classes now have complete type annotations
  - All internal functions have proper type hints
  - Docstrings updated to match type signatures
  - **Type Annotations Added**:
    - `SpecFormatter` class with `format() -> str` return type
    - `JSONFormatter` class with `format() -> str` return type
    - `initialise_logger()` with `Logger` return type and all parameter types including `Union[str, Path]` for `log_dir`
    - `validate_metadata_keys()` with `Dict[str, Any]` parameter and `None` return type
    - `log_debug()`, `log_info()`, `log_warning()`, `log_error()`, `log_critical()` with proper signatures
  - **Benefits**:
    - ✅ Passes mypy --strict validation
    - ✅ Clear API documentation through type signatures
    - ✅ Better IDE support with autocomplete and inline documentation
    - ✅ Type errors caught at development time instead of runtime
    - ✅ Self-documenting code that's easier to maintain
  - **Technical Notes**:
    - Used `# type: ignore` comments to handle local logging package shadowing stdlib
    - Added `from __future__ import annotations` for forward reference support
    - Maintained backward compatibility with all existing code

- **Type Hints Infrastructure Setup** (#594 Phase 1 of #005)
  - Installed mypy 1.7.1 for static type checking
  - Added type stub packages: types-requests 2.31.0, types-tqdm 4.66.0
  - Configured mypy.ini with permissive settings (python 3.11)
  - Added mypy to pre-commit hooks (informational, non-blocking)
  - Integrated mypy into CI/CD pipeline (SonarCloud workflow)
  - **Current Status**: Infrastructure ready, 117 type errors identified across 10 files
  - **Benefits**:
    - ✅ Infrastructure ready for gradual type hint adoption
    - ✅ Developers see type errors locally during development
    - ✅ CI tracks type coverage over time
    - ✅ No disruption to existing workflow (informational only)
  - **Next Steps**: Phase 2 will add type hints to core modules

- **Comprehensive Tests for Shared PowerShell Modules** (#003f Phase 2)
  - Added comprehensive unit tests for critical shared PowerShell infrastructure modules
  - **Priority**: HIGH - High reuse means high impact from bugs
  - **Coverage Achievements**:
    - `PowerShellLoggingFramework`: 50%+ coverage (40 tests)
    - `ProgressReporter`: 50%+ coverage (70 tests total, 55 new)
    - `ErrorHandling`: 80%+ coverage (already existed)
    - `FileOperations`: 60%+ coverage (already existed)
  - **New Test Coverage**:
    - **PowerShellLoggingFramework Tests** (40 new tests):
      - Logger initialization (default settings, custom directory, log levels)
      - All log levels (Debug, Info, Warning, Error, Critical)
      - Plain text and JSON format support
      - Log level filtering (DEBUG, INFO, WARNING, ERROR, CRITICAL)
      - Timezone handling and abbreviation
      - Metadata key validation
      - Error handling and fallback to console
      - Integration tests for full logging workflows
    - **ProgressReporter Enhanced Tests** (55 new tests):
      - Show-Progress with all parameters and edge cases
      - Write-ProgressLog with percentage calculation
      - New-ProgressTracker with edge cases
      - Update-ProgressTracker with update frequency logic
      - Complete-ProgressTracker with various states
      - Write-ProgressStatus with special characters
      - Full workflow integration tests
      - Multiple independent trackers
      - Edge case workflows (zero total, overflow)
  - **Benefits**:
    - ✅ Validates shared PowerShell infrastructure
    - ✅ Prevents widespread failures across scripts
    - ✅ Documents module APIs and expected behavior
    - ✅ Enables safe refactoring with high test coverage
    - ✅ Cross-platform logging validation
    - ✅ Progress tracking reliability for long-running operations
  - **Total**: 110 tests passing, 95 new tests added

- **Comprehensive Tests for Shared Python Modules** (#003e Phase 2)
  - Added comprehensive unit tests for critical shared infrastructure modules
  - **Priority**: HIGH - High reuse means high impact from bugs
  - **Coverage Achievements**:
    - `python_logging_framework.py`: 91% coverage (target: 60%+)
    - `error_handling.py`: 84% coverage (target: 70%+)
    - `file_operations.py`: 63% coverage (target: 60%+)
  - **New Test Coverage**:
    - **Logging Framework Tests** (6 new tests):
      - Logger initialization with custom log directory
      - Logging with structured metadata
      - All log levels (debug, info, warning, error, critical)
      - File handler creation and log persistence
    - **Error Handling Advanced Tests** (5 new tests):
      - Retry decorator with mock functions
      - Max retries enforcement
      - Custom exception filtering
      - Exponential backoff validation
      - Retry operation exponential backoff
    - **File Operations Tests** (4 new tests):
      - Nested directory creation
      - Existing directory handling
      - Parent directory creation for files
      - Unicode encoding support
  - **Benefits**:
    - Validates critical shared infrastructure
    - Prevents bugs in widely-used utilities
    - Enables confident refactoring
    - Documents expected behavior
  - **Total**: 76 tests passing, 17 new tests added

- **Google Drive destructive-operation safeguards** (#003 Phase 1)
  - Added fully mocked unit tests for root-level deletion and trash recovery flows
  - Verifies folder exclusion, pagination, and API error handling to prevent accidental data loss
  - Recovery helper tests ensure trashed items are identified without calling live APIs

- **Comprehensive PostgreSQL Backup Tests** (#003 Phase 1) - Expanded test coverage for database backup scripts
  - **Priority**: HIGH - Critical path testing for financial data (GnuCash) backups
  - **Impact**: Prevents data loss, validates backup reliability, enables confident refactoring
  - **Files Modified**:
    - `tests/powershell/unit/PostgresBackup.Tests.ps1` - Added 21 new test cases (770 → 1320 lines)
  - **New Test Coverage**:
    - **Invalid Database Scenarios** (4 tests):
      - Non-existent database handling
      - Database connection timeout handling
      - Authentication failure handling
      - Insufficient permissions handling
    - **Retention Policy Edge Cases** (6 tests):
      - Exactly min_backups count boundary
      - retention_days=0 edge case
      - min_backups=0 edge case
      - Multiple databases in same folder isolation
      - Very large number of old backups (50+) efficiency
    - **Special Characters and URL Encoding** (4 tests):
      - Password with special characters (@, !, #, $, %, &, *)
      - Password with spaces
      - Database names with underscores and numbers
      - Username with special characters
    - **Additional Error Scenarios** (7 tests):
      - Disk full during backup
      - Permission denied on backup folder
      - pg_dump executable not found
      - pg_dump warnings logging
      - Service stop failure after successful backup
      - Backup creation when zero-byte cleanup fails

- **Data transformation tests for GPS/timeline processing** (#003 Phase 1)
  - Added unit tests for CSV→GPX conversion, geospatial validators, and timeline extraction helpers
  - Validates elevation inclusion, malformed CSV handling, JSON parsing errors, and activity enrichment flows
  - **Test Statistics**:
    - Total test cases: 40 (19 existing + 21 new)
    - Test code lines: 1,320
    - Integration tests: 2 (Test-BackupRestore.Tests.ps1)
    - Test-to-code ratio: 8.1:1 (1,320 test lines / 162 implementation lines)
  - **Benefits**:
    - ✅ Validates financial data backup reliability
    - ✅ Prevents data loss through comprehensive error handling tests
    - ✅ Documents expected behavior for all edge cases
    - ✅ Enables safe refactoring with high test coverage
    - ✅ Tests URL encoding for passwords with special characters
    - ✅ Validates retention policy in complex scenarios

- **Re-enabled Bandit B113 Timeout Check** (#004c) - Enabled security enforcement for HTTP request timeouts

  - **Priority**: MEDIUM-HIGH - Security and code quality enforcement
  - **Impact**: Prevents new code from missing timeouts, enforced in CI/CD pipeline
  - **Files Modified**:
    - `pyproject.toml` - Removed B113 from skips list to enable timeout checking
    - `src/python/modules/utils/README.md` - Updated documentation examples to include timeout parameters
  - **Files Added**:
    - `tests/python/unit/test_security_compliance.py` - Automated regression tests
      - `test_all_requests_have_timeouts()` - Verifies all HTTP requests include timeout parameter
      - `test_bandit_b113_enabled()` - Ensures B113 check is not in skip list
      - `test_security_documentation_examples()` - Validates documentation examples comply with security requirements
  - **CI/CD Integration**: Bandit B113 now enforced in GitHub Actions and pre-commit hooks
  - **Benefits**: Catches timeout violations before merge, maintains code quality standards

- **HTTP Timeout Guidelines Documentation** (#004b) - Comprehensive documentation for HTTP request timeout best practices
  - **Priority**: MEDIUM - Developer education and code quality improvement
  - **Impact**: Improved code reliability, prevents indefinite hangs, establishes timeout standards
  - **Files Modified**:
    - `src/python/modules/utils/error_handling.py` - Fixed example code to include timeout parameters
      - Line 94: Updated `requests.get(url)` to `requests.get(url, timeout=(5, 30))`
      - Line 173: Updated lambda example to include timeout parameter
    - `CONTRIBUTING.md` - Added "HTTP Request Guidelines" section
      - "Always Specify Timeouts" with good/bad examples
      - "Recommended Timeout Values" for different operation types
      - "Handle Timeout Exceptions" with error handling examples
  - **Files Added**:
    - `docs/guides/http-requests.md` - Comprehensive HTTP request best practices guide
      - Timeout configuration and tuple format explanation
      - Guidelines by operation type (API endpoints, file operations, third-party APIs)
      - Dynamic timeout calculation for file uploads/downloads
      - Error handling patterns and examples
      - Testing timeout behavior with pytest examples
      - Common patterns section with complete code examples
      - References to related documentation
  - **Benefits**:
    - ✅ Developers understand timeout requirements
    - ✅ Example code demonstrates correct usage
    - ✅ Consistent timeout values across codebase
    - ✅ Prevents indefinite hangs in HTTP requests
    - ✅ Clear guidelines for different operation types
    - ✅ Dynamic timeout calculation for large files
    - ✅ Comprehensive error handling patterns
  - **Version Impact**: PATCH bump - documentation improvement, no breaking changes

### Changed

- Replaced `Write-Host` usage in system maintenance scripts with the centralized logging framework and structured run outputs for automation (`Invoke-SystemHealthCheck.ps1`, `Install-SystemHealthCheckTask.ps1`, `Remove-DuplicateFiles.ps1`).
- Corrected git hook launchers to call the PowerShell hook implementations from their canonical path under `src/powershell/git`.
- Cached the PowerShell logging module's default log directory at import time to reduce repeated path resolution during logger initialization.
- Removed the tracked `python_logging_framework.egg-info` build artifacts and expanded `.gitignore` to keep egg-info, log, and tmp files out of version control.
- Introduced a hybrid dependency pinning strategy with a reproducible `requirements.lock` alongside range-based `requirements.txt` constraints.

### Added

- **Automated Dependency Security Scanning** (#520) - Comprehensive vulnerability scanning for Python dependencies
  - **Priority**: MEDIUM - Proactive security vulnerability detection and remediation
  - **Impact**: Enhanced security posture, automated vulnerability detection, reduced risk of supply chain attacks
  - **Problem Solved**:
    - No automated vulnerability scanning for dependencies
    - Security issues could go undetected until exploited
    - Manual dependency auditing was time-consuming and error-prone
    - No integration with GitHub security features
  - **Solution Implemented**:
    - **GitHub Actions Workflow**: `.github/workflows/security-scan.yml`
      - Runs on push, pull requests, and weekly schedule (Sundays 2:00 AM UTC)
      - Manual trigger support via workflow_dispatch
      - Multiple security scanning tools for comprehensive coverage
    - **Security Scanning Tools**:
      - **Safety** - Checks dependencies against known vulnerability database
      - **pip-audit** - Python package auditing against OSV and PyPI Advisory databases
      - **Dependency Review Action** - GitHub native dependency vulnerability scanning (PR only)
    - **Pre-commit Hook**: Added python-safety-dependencies-check to `.pre-commit-config.yaml`
      - Scans requirements.txt files before commit
      - Prevents committing known vulnerable dependencies
      - Uses Lucas-C/pre-commit-hooks-safety v1.3.3
    - **CI/CD Integration**:
      - Automated vulnerability reports in GitHub Actions summary
      - Artifact uploads for detailed analysis (30-day retention)
      - Fails build on security vulnerabilities (configurable)
- Git hook integration test suite (`tests/integration/GitHooks.Integration.Tests.ps1`) that provisions a temporary repository, installs hooks, and validates staging mirror updates, deployment targets, and configuration handling for post-commit and post-merge workflows.
  - **Integration Test Coverage**:
    - Added `tests/integration/Test-BackupRestore.Tests.ps1` to validate PostgreSQL backup/restore flows end-to-end
    - Exercises backup creation, restore validation, data integrity checks, and retention cleanup with temporary PostgreSQL instances
      - Dependency review comments on pull requests
  - **Dependencies Added** (requirements.txt):
    - safety==3.2.11 - Python dependency security scanner
    - pip-audit==2.7.3 - PyPI package auditor
  - **Workflow Features**:
    - **Scheduled Scans**: Weekly security audits (cron: '0 2 \* \* 0')
    - **Trigger Events**: push, pull_request, schedule, manual workflow_dispatch
    - **Multi-tool Scanning**: Safety, pip-audit, and GitHub Dependency Review
    - **Detailed Reporting**: Step-by-step results in GitHub Actions summary
    - **Artifact Preservation**: JSON/text reports uploaded for 30 days
    - **Severity Configuration**: Dependency Review fails on moderate+ severity
    - **PR Integration**: Automatic dependency review comments on pull requests
    - **Continue-on-error**: Non-blocking scans with summary at the end
  - **Security Scan Process**:
    1. **On Every Push/PR**: Runs safety and pip-audit checks
    2. **Weekly Schedule**: Automated scans every Sunday at 2:00 AM UTC
    3. **Pre-commit Hook**: Validates dependencies before allowing commits
    4. **Dependency Review**: GitHub native scanning on pull requests
    5. **Reports**: Detailed vulnerability reports in Actions summary and artifacts
  - **Documentation**:
    - Security scanning process documented in README.md
    - GitHub workflow includes inline comments and examples
    - Pre-commit hook configuration with file pattern matching
  - **Benefits**:
    - ✅ Automated detection of known security vulnerabilities
    - ✅ Multi-tool coverage (Safety, pip-audit, GitHub Dependency Review)
    - ✅ Weekly scheduled scans for continuous monitoring
    - ✅ Pre-commit hooks prevent vulnerable dependencies from being committed
    - ✅ Detailed reports with remediation guidance
    - ✅ Integration with GitHub Security features (Dependabot alerts)
    - ✅ Fail-fast CI/CD on security issues
    - ✅ Artifact retention for historical analysis
    - ✅ Manual trigger support for ad-hoc scans
  - **Files Added**:
    - `.github/workflows/security-scan.yml` - Security scanning workflow

## [2.3.1] - 2024-06-07

### Added

- Enabled pip caching across formatting, security scanning, module validation, and SonarCloud workflows with explicit cache hit/miss reporting.
- Added npm cache restoration for `sql-lint` in the SonarCloud workflow, including cache status visibility.
- Cached user-scoped PowerShell modules for linting and deployment jobs with cache status output for each run.

### Changed

- Documented CI/CD caching strategy and cache key management in the README.
  - **Files Modified**:
    - `.pre-commit-config.yaml` - Added python-safety-dependencies-check hook
    - `requirements.txt` - Added safety==3.2.11, pip-audit==2.7.3
    - `README.md` - Documented security scanning process
    - `CHANGELOG.md` - This entry
  - **Version Impact**: MINOR bump - new security infrastructure feature

### Security

### Changed

- Replaced `Write-Host` usage in backup utilities with logging and structured pipeline output to enable automation-friendly captures (Backup-GnuCashDatabase, Backup-TimelineDatabase, Sync-Directory). (#519)

### Changed

- Standardized PowerShell modules to use Public/Private folder structure with loader pattern and refreshed manifests.

- **Fixed Dependency Vulnerabilities** (#520) - Updated vulnerable packages to secure versions
  - **Priority**: HIGH - Security vulnerability remediation
  - **Impact**: Eliminates 5 known security vulnerabilities across 4 packages
  - **Vulnerabilities Fixed**:
    - **requests 2.31.0 → 2.32.4** (2 CVEs fixed)
      - GHSA-9wx4-h78v-vm56: Session certificate verification bypass issue
      - GHSA-9hjg-9r4m-mvj7: Potential .netrc credential leakage to third parties
    - **tqdm 4.66.1 → 4.66.3** (1 CVE fixed)
      - GHSA-g7vv-2v7x-gj9p: Arbitrary code execution via CLI arguments through eval()
    - **black 24.1.1 → 24.3.0** (1 CVE fixed)
      - PYSEC-2024-48: Regular Expression Denial of Service (ReDoS) vulnerability
    - **bandit 1.7.5 → 1.7.9** (1 vulnerability fixed)
      - Safety ID 64484: Missing detection of str.replace SQL injection pattern
  - **Files Modified**:
    - `requirements.txt` - Updated requests, tqdm, black, and bandit to secure versions
    - `.pre-commit-config.yaml` - Updated black and bandit hooks to secure versions
  - **Validation**: Security scan workflow automatically validates fixes
  - **Version Impact**: PATCH bump - security fixes only, backward compatible

### Changed

- **Removed continue-on-error from Critical CI Checks** (#521) - Made quality gates properly blocking

  - **Priority**: MEDIUM - Enforces code quality and security standards
  - **Impact**: Critical checks now properly fail CI builds, preventing merge of problematic code
  - **Problem Solved**:
    - Previously: Critical checks had `continue-on-error: true` or `|| true`, allowing failures to be ignored
    - Pre-commit hooks, linting, security scanning, and SonarCloud quality gates were not blocking merges
    - Failed quality checks could be bypassed, reducing code quality and security
  - **Solution Implemented**:
    - **sonarcloud.yml**:
      - Removed `continue-on-error: true` from Pre-Commit Hooks step
      - Removed `|| true` from Pylint command to make Python linting blocking
      - Removed `|| true` from Bandit command to make security scanning blocking
      - Updated PSScriptAnalyzer to fail on linting errors instead of just reporting
      - Removed `continue-on-error: true` and `|| true` from SonarCloud Scan to make quality gate blocking
    - **security-scan.yml**:
      - Removed `continue-on-error: true` from Safety check step
      - Removed `continue-on-error: true` from pip-audit check step
      - Both security scans now properly fail the build when vulnerabilities are detected
  - **Checks Now Blocking**:
    - ✅ Pre-commit hooks - Will block on formatting/linting violations
    - ✅ Python linting (Pylint) - Will block on code quality issues
    - ✅ PowerShell linting (PSScriptAnalyzer) - Will block on script quality issues
    - ✅ Python security scanning (Bandit) - Will block on security vulnerabilities
    - ✅ Dependency security (Safety, pip-audit) - Will block on vulnerable dependencies
    - ✅ SonarCloud quality gate - Will block on quality/coverage thresholds
  - **Files Modified**:
    - `.github/workflows/sonarcloud.yml` - Removed continue-on-error from 5 critical steps
    - `.github/workflows/security-scan.yml` - Removed continue-on-error from 2 security steps
    - `CHANGELOG.md` - This entry
  - **Benefits**:
    - 🛡️ Enforced code quality standards prevent low-quality code from being merged
    - 🔒 Security vulnerabilities are caught and block merges until resolved
    - 📊 SonarCloud quality gates ensure code meets coverage and quality metrics
    - ✨ Pre-commit hooks ensure consistent formatting and style
    - 🚫 Eliminates ability to merge code with known issues
  - **Version Impact**: PATCH bump - CI/CD improvement, no code changes

- **Pinned All Dependency Versions** (#519) - Ensured reproducible builds with exact version specifications
  - **Priority**: MEDIUM - Prevents non-deterministic builds and version conflicts
  - **Impact**: Improved build reproducibility, eliminated version drift, simplified dependency management
  - **Problem Solved**:
    - Previously: 23 dependencies with unpinned or loosely pinned versions (e.g., `requests`, `numpy`, `pandas>=2.0.0`)
    - Led to non-deterministic builds where different installations could get different package versions
    - Made debugging difficult when issues occurred due to version differences
  - **Solution Implemented**:
    - All 23 dependencies now pinned to exact versions using `==` operator
    - Created dependency update automation script for future maintenance
    - Organized requirements.txt with logical grouping (core, development, code quality)
  - **Pinned Dependencies** (23 total):
    - **Core Dependencies** (16):
      - requests==2.31.0
      - numpy==1.26.4 (Python 3.12 compatible)
      - pandas==2.2.1 (Python 3.12 compatible)
      - opencv-python==4.9.0.80 (Python 3.12 compatible)
      - cloudconvert==2.0.0
      - google-auth==2.23.4
      - google-auth-oauthlib==1.1.0
      - google-auth-httplib2==0.1.1
      - google-api-python-client==2.108.0
      - oauth2client==4.1.3
      - tqdm==4.66.1
      - srtm==1.0.0 (conditional: python_version < "3.11")
      - networkx==3.2.1
      - openpyxl==3.1.2
      - psycopg2==2.9.9
      - pytz==2023.3
    - **Development and Testing** (3):
      - pytest==7.4.3
      - pytest-cov==4.1.0
      - pytest-mock==3.11.1
    - **Code Quality and Formatting** (4):
      - pre-commit==3.5.0
      - black==24.1.1
      - bandit==1.7.5
      - sqlfluff==3.0.0
  - **New Script**: `scripts/update-dependencies.sh` (v1.0.0)
    - Automated dependency update tool using temporary virtual environment
    - Installs and upgrades all dependencies from requirements.txt
    - Generates `requirements-frozen.txt` with all transitive dependencies
    - Includes statistics and comparison of package counts
    - Provides clear next-steps guidance for reviewing and testing updates
    - Features:
      - Temporary virtual environment isolation (.venv-temp)
      - Automatic cleanup on exit
      - Color-coded output with status indicators
      - Comprehensive error handling
      - pip upgrade before dependency installation
  - **Files Modified**:
    - `requirements.txt` - All 23 dependencies pinned with exact versions and logical grouping
  - **Files Added**:
    - `scripts/update-dependencies.sh` - Dependency update automation script (executable)
  - **Documentation**:
    - Script includes comprehensive header documentation
    - Usage instructions, requirements, and output descriptions
    - Next-steps guidance for testing and updating workflow
  - **Benefits**:
    - ✅ Reproducible builds across all environments
    - ✅ Consistent dependency versions for all developers
    - ✅ Easier debugging with known, fixed versions
    - ✅ Simplified CI/CD pipeline with deterministic dependencies
    - ✅ Clear dependency update process via update-dependencies.sh
    - ✅ Reduced risk of breaking changes from automatic updates
    - ✅ Better documentation with logical grouping
  - **Dependency Update Process**:
    1. Run `./scripts/update-dependencies.sh` to generate frozen requirements
    2. Review `requirements-frozen.txt` for changes
    3. Test application with new versions
    4. Update `requirements.txt` with new pinned versions if tests pass
  - **Validation**:
    - All 23 packages verified with exact version pins (==)
    - Zero unpinned dependencies
    - Syntax validation passed
    - No broken package dependencies detected
  - **Version Impact**: PATCH bump - infrastructure improvement, no API changes

### Added

- **Comprehensive Configuration Documentation** (#517) - Created complete configuration guide and validation tools

  - **Priority**: HIGH - Critical for user onboarding and reducing support burden
  - **Impact**: Solves fresh clone setup failures, improves user experience, reduces configuration questions
  - **Files Added**:
    - `config/CONFIG_GUIDE.md` - Comprehensive configuration guide with examples and troubleshooting
    - `scripts/Verify-Configuration.ps1` - Configuration validation script
    - `scripts/Initialize-Configuration.ps1` - Interactive configuration wizard
  - **Documentation Features**:
    - **Quick Start Guide**: Get started in 3 simple steps
    - **Configuration Files Reference**:
      - Local deployment configuration (local-deployment-config.json)
      - Module deployment configuration (deployment.txt)
      - Secrets configuration (encrypted password files)
      - Task Scheduler configuration (Windows)
      - Environment variables reference
    - **Platform-Specific Setup**: Detailed instructions for Windows, Linux, and macOS
    - **Common Scenarios**: 6 practical configuration examples
      - Fresh system setup
      - Disable deployment temporarily
      - Deploy only specific modules
      - Multiple deployment targets
      - Custom deployment locations
      - Configure database backups
    - **Troubleshooting Guide**: Solutions for 10+ common configuration issues
    - **Advanced Configuration**: Module filtering, exclude patterns, environment-specific configs
  - **Validation Script Features**:
    - Validates local deployment configuration (JSON syntax, required fields)
    - Checks staging mirror path exists and is writable
    - Verifies git hooks installation
    - Checks PowerShell module availability
    - Validates environment variables
    - Checks secrets directory and password files
    - Tests required commands (git, pwsh, python3, pip3)
    - Color-coded output with success/error/warning indicators
    - Comprehensive summary with pass/fail counts
    - Exit codes for CI/CD integration
  - **Interactive Wizard Features**:
    - OS detection (Windows, Linux, macOS)
    - Configuration choice menu (deployment, environment, secrets, or full setup)
    - Local deployment configuration:
      - Enable/disable deployment
      - Staging mirror path with platform-appropriate defaults
      - Optional module filter
      - Optional exclude patterns
    - Environment variables setup:
      - MY_SCRIPTS_ROOT configuration
      - PostgreSQL connection settings (PGHOST, PGPORT, PGUSER)
      - Permanent storage (User-level environment variables)
    - PostgreSQL secrets configuration:
      - Interactive encrypted password file creation
      - Windows DPAPI encryption
      - Secure password input
    - Automatic validation after setup
    - Platform-specific next steps guidance
  - **Benefits**:
    - ✅ Fresh clone setup succeeds without manual intervention
    - ✅ Git hooks deploy correctly on first commit
    - ✅ Users know exactly what to configure and how
    - ✅ Troubleshooting guide prevents support requests
    - ✅ Validation ensures configuration correctness
    - ✅ Interactive wizard simplifies complex setup
    - ✅ Platform-specific instructions reduce OS-related issues
    - ✅ Common scenarios provide practical examples
  - **Files Updated**:
    - `INSTALLATION.md` - Added configuration section with links to CONFIG_GUIDE.md
    - `README.md` - Added configuration quick start and links
  - **Version Impact**: MINOR bump - new configuration features and tools

- **Added Comprehensive Tests for ErrorHandling Module** (#516) - Implemented extensive test coverage for error handling and retry utilities

  - **Priority**: HIGH - Critical error handling functionality requires robust testing
  - **Impact**: Enhanced code reliability, verified error handling behavior, comprehensive edge case coverage
  - **Test Coverage Added**:
    - **Invoke-WithErrorHandling**: Successful execution, Stop/Continue/SilentlyContinue actions, logging integration, error message formatting
    - **Invoke-WithRetry**: Successful execution, retry logic, exponential backoff, logging behavior, edge cases
    - **Test-IsElevated**: Return type validation, platform detection, error handling
    - **Assert-Elevated**: Elevated/non-elevated scenarios, message handling, terminating errors
    - **Test-CommandAvailable**: Built-in commands, external commands, edge cases, module commands
    - **Integration Tests**: Combined error handling with retry, privilege checks, command availability
  - **Test Categories**:
    - **Invoke-WithErrorHandling**: Successful execution (3 tests), Stop action (5 tests), Continue action (4 tests), SilentlyContinue action (2 tests), Message formatting (2 tests)
    - **Invoke-WithRetry**: Successful execution (2 tests), Retry logic (4 tests), Exponential backoff (3 tests), Logging behavior (9 tests), Edge cases (3 tests)
    - **Test-IsElevated**: Return type (2 tests), Platform detection (2 tests), Error handling (2 tests)
    - **Assert-Elevated**: Not elevated (4 tests), Elevated (3 tests), Message handling (2 tests)
    - **Test-CommandAvailable**: Built-in commands (3 tests), External commands (3 tests), Edge cases (4 tests), Module commands (1 test)
    - **Integration Tests**: Error handling with retry (2 tests), Privilege checks (2 tests), Command availability (1 test)
  - **Total Tests**: 70+ comprehensive test cases organized in 6 describe blocks with context grouping
  - **Logging Integration Testing**:
    - Verified Write-LogError integration for Stop action
    - Validated Write-LogWarning integration for Continue action
    - Tested Write-LogInfo integration for retry success logging
    - Ensured fallback to built-in Write-Error, Write-Warning, Write-Verbose when logging functions unavailable
    - Validated LogError/LogErrors parameter behavior
  - **Mocking Strategy**:
    - Mock Write-LogError, Write-LogWarning, Write-LogInfo to verify logging behavior
    - Mock Get-Command to test fallback mechanisms
    - Mock Test-IsElevated to test elevation scenarios in Assert-Elevated
    - Module-scoped mocking for accurate testing of internal function calls
  - **Edge Cases Covered**:
    - Empty and whitespace-only strings in Test-CommandAvailable
    - Case-insensitive command detection
    - Platform-specific elevation checks (Windows and Unix)
    - Different error types (InvalidOperationException, etc.)
    - Operations with no return values
    - Nested error handling
    - Combined error handling and retry logic
  - **Benefits**:
    - ✅ >80% code coverage achieved across all functions
    - ✅ Error handling behavior thoroughly tested for all actions
    - ✅ Retry logic with exponential backoff validated
    - ✅ Logging integration and fallback mechanisms verified
    - ✅ Platform-specific elevation detection tested
    - ✅ Edge cases covered (empty strings, nested operations, different error types)
    - ✅ Integration scenarios validated (error handling + retry, privilege checks)
    - ✅ Professional test organization with Context grouping
  - **Files Updated**:
    - `tests/powershell/unit/ErrorHandling.Tests.ps1` - Enhanced from 33 basic tests to 70+ comprehensive tests
  - **Version Impact**: PATCH bump - test coverage improvement, no API changes

- **Added Comprehensive Tests for FileOperations Module** (#515) - Implemented extensive test coverage for file operation utilities
  - **Priority**: HIGH - Critical file operations require robust testing
  - **Impact**: Enhanced code reliability, verified retry logic, comprehensive edge case coverage
  - **Test Coverage Added**:
    - **Copy-FileWithRetry**: Basic functionality, retry logic with mocking, parameter validation, edge cases
    - **Move-FileWithRetry**: File movement, atomic operations, retry logic, content preservation
    - **Remove-FileWithRetry**: File deletion, read-only handling, retry logic, error handling
    - **Rename-FileWithRetry**: File renaming, content preservation, retry logic, special characters
    - **Test-FolderWritable**: Writable folder detection, nested directory creation, cleanup verification
    - **Add-ContentWithRetry**: Content appending, directory creation, retry logic, encoding support
    - **New-DirectoryIfNotExists**: Directory creation, deeply nested paths, error handling
    - **Get-FileSize**: Size calculation, empty files, large files, error handling
  - **Test Categories**:
    - **Basic Functionality**: Core operations and happy path scenarios (31 tests)
    - **Retry Logic**: Invoke-WithRetry integration, parameter passing, fallback mode (11 tests)
    - **Edge Cases**: Nested directories, content preservation, special characters (8 tests)
    - **Error Handling**: Invalid paths, nonexistent files, graceful degradation (5 tests)
  - **Total Tests**: 55 comprehensive test cases organized in 8 describe blocks with context grouping
  - **Retry Logic Testing**:
    - Verified Invoke-WithRetry integration for all retry-enabled functions
    - Validated correct parameter passing (MaxRetries, RetryDelay, MaxBackoff)
    - Tested fallback mode when ErrorHandling module unavailable
    - Ensured operations execute correctly with and without retry framework
  - **Mocking Strategy**:
    - Mock Invoke-WithRetry to verify retry parameters without actual retries
    - Mock Get-Command to test fallback behavior
    - Validate operation scriptblocks execute correctly in both modes
  - **Benefits**:
    - ✅ >80% code coverage achieved across all functions
    - ✅ Retry logic thoroughly tested with configurable attempts
    - ✅ File lock scenarios validated through mocking
    - ✅ Edge cases covered (nested paths, special chars, empty files)
    - ✅ Error handling verified for all failure scenarios
    - ✅ CI/CD integration ensures tests run on all pushes
    - ✅ Professional test organization with Context grouping
  - **Files Updated**:
    - `tests/powershell/unit/FileOperations.Tests.ps1` - Enhanced from 8 basic tests to 55 comprehensive tests
  - **Version Impact**: PATCH bump - test coverage improvement, no API changes

### Changed

- **Standardized Version Handling Across Configuration Files** (#518) - Unified version management with VERSION file as single source of truth
  - **Priority**: MEDIUM - Prevents confusion and potential build issues from version inconsistencies
  - **Impact**: Simplified version management, eliminated version conflicts, improved build reliability
  - **Problem Solved**:
    - VERSION file: 2.2.0
    - pyproject.toml: 1.0.0 (was inconsistent)
    - setup.py: 0.2.0 (was hardcoded)
  - **Solution Implemented**:
    - VERSION file is now the single source of truth (2.2.0)
    - setup.py reads version dynamically from VERSION file using `Path('VERSION').read_text().strip()`
    - All version references now synchronized
  - **Files Modified**:
    - `setup.py` - Added `get_version()` function to read from VERSION file
    - `pyproject.toml` - Updated `[tool.commitizen]` version to match VERSION file (2.2.0)
  - **Benefits**:
    - ✅ Single source of truth for version information
    - ✅ No manual version synchronization needed across files
    - ✅ Build process verified and working correctly
    - ✅ Package metadata correctly reflects VERSION file
    - ✅ Follows modern Python packaging standards
  - **Build Verification**:
    - Tested `python setup.py --version` - correctly returns 2.2.0
    - Tested source distribution build - creates `my-scripts-logging-2.2.0.tar.gz`
    - Verified PKG-INFO metadata contains correct version
  - **Version Impact**: PATCH bump - internal build configuration improvement, no API changes

### Fixed

- **Fixed Hardcoded Paths in Documentation** (#514) - Replaced hardcoded paths with placeholders for portability and clarity

  - **Priority**: HIGH - Documentation quality and usability issue
  - **Impact**: Improved user experience, consistent documentation, professional appearance
  - **Files Fixed**:
    - `CHANGELOG.md` - Replaced hardcoded repository and script paths with `<REPO_PATH>` and `<SCRIPT_ROOT>` placeholders
    - `docs/system-health-check.md` - Added placeholder note and replaced hardcoded paths
    - `docs/conventions/placeholders.md` - Created comprehensive placeholder standards guide (NEW)
  - **Placeholder Standards**:
    - Created `docs/conventions/placeholders.md` with complete placeholder guide
    - Standard placeholders: `<REPO_PATH>`, `<SCRIPT_ROOT>`, `<CONFIG_DIR>`, `<LOG_DIR>`, `<BACKUP_DIR>`, `<USERNAME>`
    - Platform-specific examples for Windows and Linux
    - Environment variable usage examples
  - **Documentation Guidelines**:
    - Updated `CONTRIBUTING.md` with path placeholder section
    - Good/bad examples with clear visual indicators (✅/❌)
    - Platform-specific example guidelines
  - **Automated Checking**:
    - Created `scripts/Check-DocumentationPaths.ps1` to detect hardcoded paths
    - Scans all markdown files for patterns like `C:\Users\`, `D:\`, `/home/username/`
    - Excludes legitimate uses (bad examples in docs, analysis issues)
    - Clear error messages with remediation guidance
  - **CI/CD Integration**:
    - Added documentation path check to `.github/workflows/code-formatting.yml`
    - Fails build if hardcoded paths detected
    - Included in workflow status summary
  - **Benefits**:
    - ✅ Examples now work for all users without modification
    - ✅ Consistent placeholder usage across all documentation
    - ✅ Professional, portable documentation
    - ✅ Automated enforcement prevents regression
    - ✅ Clear guidelines for contributors
  - **Version Impact**: MINOR bump - documentation improvement with new tooling

- **Fixed Hardcoded Paths in PowerShell Scripts and Batch Files** (#513) - Removed hardcoded paths for portability and security

  - **Priority**: HIGH - Security risk with exposed credentials and broken portability
  - **Impact**: Enhanced security, improved portability, better maintainability
  - **Files Fixed**:
    - **Security Critical**:
      - `src/powershell/backup/Backup-GnuCashDatabase.ps1` - Removed hardcoded password file path (v2.0.0)
      - `src/powershell/backup/Backup-TimelineDatabase.ps1` - Removed hardcoded password file path (v2.0.0)
    - **Portability Critical**:
      - `src/powershell/cloud/Invoke-CloudConvert.ps1` - Dynamic Python script path resolution (v3.0.0)
      - `src/batch/RunDeleteOldDownloads.bat` - Relative path to PowerShell script (v4.0.0)
      - `src/powershell/file-management/Restore-FileExtension.ps1` - Dynamic BaseDir resolution (v3.0.0)
      - `src/powershell/file-management/Get-FileHandle.ps1` - Configurable Handle.exe path (v3.0.0)
      - `src/powershell/automation/Update-ScheduledTaskScriptPaths.ps1` - Parameterized script roots (v3.0.0)
  - **Security Improvements**:
    - Created `config/secrets/` directory for sensitive files
    - Added `.gitignore` entries to prevent credential leakage
    - Password files now use environment variables (`PGBACKUP_PASSWORD_FILE`)
    - Comprehensive documentation in `config/secrets/README.md`
  - **Portability Features**:
    - All scripts use `$PSScriptRoot` for relative path resolution
    - Environment variable support for custom paths
    - Path validation with clear error messages
    - Cross-system compatibility (Windows/Linux paths)
  - **New Environment Variables**:
    - `PGBACKUP_PASSWORD_FILE` - PostgreSQL backup password location
    - `HANDLE_EXE_PATH` - Handle.exe utility location
    - `SCRIPTS_OLD_ROOT1`, `SCRIPTS_OLD_ROOT2` - Task scheduler path migration
    - `TASK_SCHEDULER_OUTPUT` - Task scheduler XML output directory
  - **Documentation**:
    - Created `config/secrets/README.md` with setup instructions
    - Password file creation and rotation procedures
    - Troubleshooting guide for common errors
    - Security best practices and file permissions
  - **Benefits**:
    - ✅ No exposed credentials in version control
    - ✅ Scripts work on any system without modification
    - ✅ Clear error messages when files are missing
    - ✅ Secure defaults using repository structure
    - ✅ Support for custom paths via environment variables
  - **Version Impact**: MAJOR version bumps for affected scripts - breaking change to path handling

- **Fixed Logger Initialization in Python Modules** (#511) - Resolved runtime AttributeError in logging framework usage
  - **Issue**: Python modules used `plog.log_info()`, `plog.log_warning()`, etc. without initializing logger first
    - Caused `AttributeError` when modules were used standalone or when calling code didn't initialize logging
    - Inconsistent behavior: modules only worked when caller initialized logging
    - Made modules not self-contained and dependent on external initialization
  - **Solution**: Each module now initializes its own logger at module level
    - Added `logger = plog.initialise_logger(__name__)` to all affected modules
    - Updated all `plog.log_*()` calls to pass logger as first parameter
    - Removed duplicate logger initialization in main/entry point functions
  - **Affected Modules** (10 files):
    - `src/python/modules/auth/google_drive_auth.py`
    - `src/python/modules/auth/elevation.py`
    - `src/python/cloud/cloudconvert_utils.py`
    - `src/python/cloud/drive_space_monitor.py`
    - `src/python/cloud/google_drive_root_files_delete.py`
    - `src/python/data/csv_to_gpx.py`
    - `src/python/data/extract_timeline_locations.py`
    - `src/python/data/seat_assignment.py`
    - `src/python/media/find_duplicate_images.py`
    - `src/python/media/recover_extensions.py`
  - **Testing**: Added comprehensive unit tests for logger initialization
    - File: `tests/python/unit/test_module_logger_initialization.py`
    - Tests verify each module has logger attribute
    - Tests verify logger is properly initialized as logging.Logger instance
    - Tests verify modules work standalone without external initialization
  - **Benefits**:
    - ✅ No more runtime errors when using modules standalone
    - ✅ Consistent behavior across all modules
    - ✅ Self-contained modules with proper encapsulation
    - ✅ Clear, helpful logging with module-specific identification
    - ✅ No breaking changes to module APIs
  - **Version Impact**: PATCH bump (2.1.2 → 2.1.3) - bug fix, no breaking changes

### Security

- **Fixed Hardcoded Credentials Paths in Google Drive Auth** (#506) - Removed security vulnerability and improved portability
  - **Security Fix**: Removed hardcoded credential file paths that exposed username and partial credential filenames
    - Previously: Hardcoded paths like `C:/users/manoj/Documents/Scripts/...`
    - Now: Environment variable-based configuration with secure defaults
  - **Environment Variables**: Added support for `GDRIVE_CREDENTIALS_PATH` and `GDRIVE_TOKEN_PATH`
    - Allows users to specify custom paths for credentials and token files
    - Falls back to secure defaults in user's home directory if not set
    - Default paths: `~/Documents/Scripts/credentials.json` and `~/Documents/Scripts/drive_token.json`
  - **Path Resolution Functions**: New helper functions for credential path management
    - `_get_credentials_file()`: Returns credentials path from environment or default
    - `_get_token_file()`: Returns token path from environment or default
    - Both functions return string paths compatible with existing code
  - **Validation Function**: Added `validate_credentials()` to check file existence
    - Provides clear error messages with troubleshooting guidance
    - Mentions both environment variable and default location options
    - Returns `True` on success, raises `FileNotFoundError` on missing credentials
  - **Testing**: Comprehensive unit tests for path resolution logic
    - Tests environment variable configuration
    - Tests default path fallback
    - Tests validation with missing and existing files
    - Tests error message content and helpfulness
    - File: `tests/python/unit/test_google_drive_auth_paths.py`
  - **Documentation**: Updated `INSTALLATION.md` with detailed Google Drive setup instructions
    - Step-by-step Google Cloud Console configuration
    - Environment variable setup for Windows/Linux/macOS
    - Default location usage instructions
    - Verification examples
  - **Configuration Template**: Created `.env.example` with Google Drive integration variables
  - **Impact**:
    - **Comprehensive environment validation** with cross-platform scripts and CI coverage (#510)

### Added

- **Centralized environment configuration** (#510)

  - New `.env.example` documents every environment variable with defaults and usage notes
  - Added loaders (`scripts/load-environment.sh`, `scripts/Load-Environment.ps1`) for consistent local setup
  - Validation scripts for Bash and PowerShell plus CI workflow to guard required configuration
  - New guide at `docs/guides/environment-variables.md` and updated installation docs
  - Google Drive recovery now honors `GDRIVE_CREDENTIALS_PATH`/`GDRIVE_TOKEN_PATH` in addition to its tool-specific overrides
    - ✅ No hardcoded credentials in version control
    - ✅ Works on any system without code changes
    - ✅ Portable across Windows, Linux, and macOS
    - ✅ Secure defaults using user's home directory
    - ✅ Clear error messages for troubleshooting
  - **Version Impact**: PATCH bump (2.1.1 → 2.1.2) - security fix and backward-compatible improvement

- **Task Scheduler Templates with Placeholders** (#512) - Made scheduled task definitions portable across systems
  - **Problem**: All 8 XML files in `config/tasks/` contained hardcoded paths
    - Made task definitions unusable on other systems
    - Required manual XML editing which was error-prone
    - Prevented automated deployment and testing
  - **Solution**: Created template-based task scheduler installation system
    - **Template Files**: Converted all 9 XML files to `.xml.template` versions with `{{SCRIPT_ROOT}}` placeholder
      - `Monthly System Health Check.xml.template`
      - `Postgres Log Cleanup.xml.template`
      - `Delete Old Downloads.xml.template`
      - `Drive Space Monitor.xml.template`
      - `Clear Old Recycle Bin Items.xml.template`
      - `PostgreSQL Gnucash Backup.xml.template`
      - `PostgreSQL timeline_data Backup.xml.template`
      - `PostgreSQL job_scheduler Backup.xml.template`
      - `Sync Macrium Backups.xml.template`
    - **Installation Script**: `scripts/Install-ScheduledTasks.ps1`
      - Generates actual XMLs from templates with user's script root
      - Validates XML structure before registration
      - Registers tasks in Windows Task Scheduler
      - Supports `-WhatIf` for preview and `-Force` for overwrite
      - Includes comprehensive error handling and logging
    - **Uninstallation Script**: `scripts/Uninstall-ScheduledTasks.ps1`
      - Removes all My-Scripts scheduled tasks by prefix
      - Supports `-Force` and `-WhatIf` parameters
      - Provides summary of removed tasks
    - **Git Configuration**: Updated `.gitignore` to exclude generated XMLs but keep templates
  - **Documentation**: Added comprehensive "Scheduled Tasks Setup" section to `INSTALLATION.md`
    - Installation instructions with multiple examples
    - Table of all 9 scheduled tasks with schedules and descriptions
    - Customization guide for editing templates
    - Task management commands (view, run, check status)
    - Troubleshooting section for common issues
  - **Benefits**:
    - ✅ Portable task definitions work on any Windows system
    - ✅ Automated installation script eliminates manual editing
    - ✅ No XML syntax errors from manual changes
    - ✅ Easy customization through template files
    - ✅ Scriptable deployment for CI/CD
    - ✅ Generated XMLs properly excluded from version control
  - **Version Impact**: MINOR bump - new feature with backward compatibility

### Changed

- **Flexible Template Processing for GitHub Issue Creator** (#504) - Enhanced `create_github_issues.sh` to process all template files
  - **Template File Selection**: Script now processes all files in the issues directory except `README.md`
    - Previously: Only processed files starting with `issue*` prefix
    - Now: Processes all regular files (excluding `README.md`)
    - Maintains full backward compatibility - existing `issue*` templates continue to work
  - **Exclusion Logic**:
    - Explicitly excludes `README.md` (case-sensitive)
    - Skips directories and non-regular files
    - Clear messaging in logs about excluded files
  - **Benefits**:
    - More flexible template naming (e.g., `feature_login.md`, `bugfix-crash.md`)
    - No need to rename existing templates to follow `issue*` pattern
    - Easier to organize templates by type or category
  - **Examples**:
    ```bash
    # All these templates will now be processed:
    # - issue-001-setup.md          (traditional naming)
    # - feature_login.md             (feature template)
    # - bugfix-crash-on-startup.md  (bug template)
    #
    # README.md will be skipped
    ```
  - **Version Impact**: PATCH bump (2.1.0 → 2.1.1) - backward-compatible enhancement

### Added

- **Comprehensive Tests for Git Hooks** (#508) - Added complete test coverage for Git hook automation scripts

  - **Test Files**:
    - `tests/powershell/unit/Invoke-PostCommitHook.Tests.ps1`
    - `tests/powershell/unit/Invoke-PostMergeHook.Tests.ps1`
  - **Coverage**: Comprehensive unit tests for Git hook orchestration, module deployment, and file synchronization
  - **Test Categories**:
    - **Configuration Reading Tests**: Validates parsing of deployment config, JSON config handling, and error cases
    - **Module Version Parsing Tests**: Tests header version extraction, format conversion (x.y → x.y.0), and validation
    - **Module Sanity Check Tests**: Validates PowerShell module syntax checking and function detection
    - **Path Validation Tests**: Tests absolute path validation, wildcard rejection, and security checks
    - **Module Deployment Tests**: Validates deployment to System/User/Alt targets, multi-target deployment, and selective deployment
    - **File Synchronization Tests**: Tests staging mirror updates, gitignore handling, and deleted file removal
    - **Manifest Creation Tests**: Validates PowerShell manifest (.psd1) generation with correct metadata
    - **Error Handling Tests**: Validates graceful handling of missing configs, invalid paths, access denied errors, and malformed data
    - **Merge Detection Tests** (Post-Merge): Tests merge-base detection, unmerged path handling, and fallback strategies
    - **Text Sanitization Tests** (Post-Merge): Validates author/description field sanitization and security
  - **Test Coverage Metrics**:
    - 80+ individual test cases covering all major code paths
    - Tests for successful operations, edge cases, and error conditions
    - Comprehensive mocking of external dependencies (git, file system, logging framework)
    - Platform-agnostic tests that run on Windows and Linux
  - **Functions Tested**:
    - `Get-HeaderVersion` - Module version parsing
    - `Test-ModuleSanity` - PowerShell module validation
    - `Get-SafeAbsolutePath` - Path security validation
    - `New-DirectoryIfMissing` - Directory creation helper
    - `Test-Ignored` - Gitignore integration
    - `New-OrUpdateManifest` - Manifest generation
    - `Deploy-ModuleFromConfig` - Module deployment orchestration
    - `Write-Message` - Logging wrapper
    - `Test-TextSafe` - Input sanitization
  - **Benefits**:
    - ✅ Prevents regressions in critical development automation
    - ✅ Validates module deployment doesn't corrupt PowerShell module paths
    - ✅ Ensures file synchronization respects gitignore rules
    - ✅ Verifies configuration parsing handles malformed data gracefully
    - ✅ Tests security validations (path traversal, wildcards, input sanitization)
    - ✅ Cross-platform CI support (tests run on both Windows and Linux)
    - ✅ No actual git operations or file system changes during testing
  - **CI Integration**: Tests automatically discovered and executed by existing `Invoke-Tests.ps1` runner
  - **Version Impact**: PATCH bump - adds tests only, no functional changes

- **Comprehensive Tests for PostgresBackup Module** (#507) - Added complete test coverage for PostgreSQL backup module

  - **Test File**: `tests/powershell/unit/PostgresBackup.Tests.ps1`
  - **Coverage**: Comprehensive unit tests for the `Backup-PostgresDatabase` function using Pester
  - **Platform**: Windows-specific tests (automatically skipped on Linux/macOS as PostgresBackup uses Windows services)
  - **Test Categories**:
    - **Backup Creation Tests**: Validates backup file naming conventions, directory creation, and logging
    - **Service Management Tests**: Tests PostgreSQL service start/stop behavior and state management
    - **Retention Policy Tests**: Validates old backup cleanup based on retention period and minimum backup count
    - **Zero-Byte Backup Cleanup**: Tests removal of corrupted/empty backup files
    - **Error Handling Tests**: Validates error scenarios including pg_dump failures, service timeouts, and cleanup errors
    - **Password Handling Tests**: Tests both .pgpass authentication and explicit password usage
    - **Custom Format Tests**: Validates pg_dump custom format backup creation
  - **Test Coverage Metrics**:
    - 60+ individual test cases covering all major code paths
    - Tests for successful operations, edge cases, and error conditions
    - Comprehensive mocking of external dependencies (pg_dump, Windows services, file system)
  - **Benefits**:
    - ✅ Prevents regressions in critical backup functionality
    - ✅ Validates backup file retention policies work correctly
    - ✅ Ensures service management doesn't leave PostgreSQL in incorrect state
    - ✅ Verifies error handling and logging behavior
    - ✅ Tests run automatically in CI pipeline without requiring actual PostgreSQL installation
    - ✅ Cross-platform CI support (skips gracefully on non-Windows platforms)
  - **CI Integration**: Tests automatically discovered and executed by existing `Invoke-Tests.ps1` runner
  - **Version Impact**: PATCH bump - adds tests only, no functional changes

- **Parameterized Issues Directory for GitHub Issue Creator** (#500) - Enhanced `create_github_issues.sh` with configurable input folder

  - **New Parameter**: `--issues-dir PATH` - Optional parameter to specify custom directory for issue markdown templates
    - Falls back to default `github_issues/` folder when not specified
    - Maintains full backward compatibility - existing workflows unchanged
  - **Input Validation**: Comprehensive validation of issues directory
    - Verifies directory exists before processing
    - Validates path is actually a directory (not a file)
    - Clear, user-friendly error messages on validation failure
    - Non-zero exit status for invalid paths
  - **Enhanced Logging**: Displays which directory is being used for reading issue templates
  - **Updated Documentation**: Help text includes new parameter with usage examples
  - **Use Cases**:
    - Running script from different repositories or locations
    - Testing with different sets of issue templates
    - Using in CI/CD pipelines with configurable paths
  - **Examples**:

    ```bash
    # Use default issues directory
    ./create_github_issues.sh --repo OWNER/REPO

    # Use custom issues directory
    ./create_github_issues.sh --repo OWNER/REPO --issues-dir ./github_issues/new_batch
    ```

  - **Version Impact**: MINOR bump (2.0.0 → 2.1.0) - new optional feature, backward compatible

- **Directory Sync with Exclusion Support** - Enhanced `Sync-Directory.ps1` (v1.1.0) for repository-to-working-copy synchronization

  - **New Feature**: `ExcludeFromDeletion` parameter - Array of glob patterns to preserve non-repository files
    - Supports exact matches (e.g., `.venv`, `logs`, `temp`)
    - Supports directory matches (preserves all files within excluded directories)
    - Supports wildcard patterns (e.g., `*.log`, `backups/*`)
    - Cross-platform path normalization
  - **Enhanced Preview Mode**: Shows excluded files count summary (not individual files - prevents output flooding)
  - **Improved Output**: Summary displays count of excluded files
  - **Directory Cleanup**: Automatically removes empty directories after file deletion (respects exclusion patterns)
  - **Single Confirmation**: One Y/N prompt for all deletions instead of per-file prompts
  - **Use Case**: Sync Git repository to working directory while preserving logs, virtual environments, configs, and other non-repository files
  - **Documentation**: Comprehensive help with examples and parameter descriptions
  - **Examples**:

    ```powershell
    # Preview sync with exclusions
    .\Sync-Directory.ps1 -Source "<REPO_PATH>" -Destination "<SCRIPT_ROOT>" `
        -ExcludeFromDeletion @(".venv", "venv", "logs", "temp", "*.log", "backups") -PreviewOnly

    # Perform actual sync
    .\Sync-Directory.ps1 -Source "<REPO_PATH>" -Destination "<SCRIPT_ROOT>" `
        -ExcludeFromDeletion @(".venv", "venv", "logs", "temp", "*.log", "backups")
    ```

  - **Script Naming Verification**: Confirmed `Sync-Directory.ps1` follows PowerShell naming conventions
    - `Sync` is an approved PowerShell verb
    - `Directory` is a singular noun in PascalCase
    - Format conforms to `Verb-Noun` pattern
  - **Version**: 1.1.0 (MINOR bump - new feature, backward compatible)

- **Automated Release Workflow** (#465) - Complete automated release system for version management

  - **Release Workflow**
    - New file: `.github/workflows/release.yml` - Automated GitHub Actions release workflow
      - Triggers on version tags (v*.*.\*)
      - Validates version format and CHANGELOG entry
      - Automatically extracts changelog for specific version
      - Creates GitHub Release with release notes
      - Supports manual workflow dispatch
      - Generates release summary in GitHub Actions
      - Optional module publishing (PowerShell Gallery, PyPI) - commented out for future use
  - **Version Bumping Script**
    - New file: `scripts/bump-version.sh` (v1.0.0) - Semantic version bumping automation
      - Supports major, minor, and patch version bumps
      - Validates VERSION file format (MAJOR.MINOR.PATCH)
      - Automatically updates VERSION file
      - Updates CHANGELOG.md with new version section and date
      - Cross-platform support (Linux and macOS)
      - Color-coded output and validation
      - Prevents duplicate version entries
      - Clear next-steps guidance after bumping
  - **Release Documentation**
    - New file: `.github/RELEASE_CHECKLIST.md` - Comprehensive release checklist
      - Pre-release quality checks (tests, code quality, documentation)
      - Step-by-step release process guide
      - Post-release verification tasks
      - Version numbering guidelines (SemVer)
      - Rollback procedures for failed releases
      - Troubleshooting common release issues
      - Manual release instructions (workflow dispatch)
    - New file: `docs/guides/versioning.md` - Complete versioning and release guide
      - Semantic Versioning explanation and examples
      - Automated and manual release processes
      - Version bumping decision tree
      - Changelog management best practices
      - Module versioning guidelines (PowerShell and Python)
      - Pre-release version format (alpha, beta, rc)
      - Best practices and troubleshooting
      - Real-world release examples (patch, minor, major)
  - **README Updates**
    - Updated `README.md` with new "Versioning and Releases" section
      - Current version display
      - Quick release process overview
      - Links to versioning guide and release checklist
      - Reference to GitHub Releases page
  - **Git Blame Integration**
    - Existing file: `.git-blame-ignore-revs` - Already configured for bulk formatting commits
  - **Features**
    - Fully automated release creation on tag push
    - Semantic version validation (MAJOR.MINOR.PATCH)
    - Automatic changelog extraction from CHANGELOG.md
    - GitHub Release with formatted release notes
    - Version bump automation script
    - Comprehensive documentation and checklists
    - Support for pre-release versions (alpha, beta, rc)
    - Cross-platform compatibility (Linux, macOS, Windows)
    - Clear rollback procedures
    - Optional module publishing to registries (future enhancement)

- **Code Formatting Automation** (#464) - Comprehensive automated code formatting for all languages

  - **Python Formatting (Black)**
    - Enhanced `pyproject.toml` with Black configuration (line length 100, Python 3.11, exclude patterns)
    - Added `black>=24.1.0`, `bandit>=1.7.5`, `sqlfluff>=3.0.0` to `requirements.txt`
    - Black already integrated in pre-commit hooks (v24.1.1)
  - **PowerShell Formatting**
    - New file: `scripts/Format-PowerShellCode.ps1` - PowerShell code formatter script
      - Formats all PowerShell files using PSScriptAnalyzer's Invoke-Formatter
      - OTBS (One True Brace Style) formatting
      - 4-space indentation, consistent whitespace
      - Check-only mode for CI/CD validation
      - Detailed summary and error reporting
    - Updated `.pre-commit-config.yaml` - Added PowerShell formatting check hook
  - **SQL Formatting (SQLFluff)**
    - Enhanced `.sqlfluffrc` with comprehensive SQLFluff configuration
      - PostgreSQL dialect, 4-space indentation, 120 character line length
      - Uppercase keywords, lowercase identifiers
      - Detailed indentation and capitalization rules
    - SQLFluff already integrated in pre-commit hooks (v3.0.0)
  - **Editor Configuration**
    - New file: `.editorconfig` - Universal editor configuration
      - Language-specific settings (Python, PowerShell, SQL, YAML, JSON, Markdown, Bash)
      - Consistent indentation, line endings, encoding
      - Whitespace and newline handling
    - Enhanced `.vscode/settings.json` - VS Code formatting configuration
      - Format on save enabled for all languages
      - Black formatter for Python with auto-import organization
      - PowerShell OTBS formatting preset
      - SQLFluff formatter for SQL
      - Language-specific tab sizes and settings
  - **Formatting Scripts**
    - New file: `scripts/format-all.sh` - Universal code formatting script
      - Formats all Python, PowerShell, and SQL code
      - Color-coded output with success/failure indicators
      - Detailed summary and next steps
      - Error handling and graceful degradation
  - **CI/CD Enforcement**
    - New workflow: `.github/workflows/code-formatting.yml` - Code formatting CI workflow
      - Runs on push and PR to main/develop/claude/\*\* branches
      - Checks Python formatting with Black (--check --diff)
      - Checks PowerShell formatting with Format-PowerShellCode.ps1 -Check
      - Checks SQL formatting with SQLFluff lint
      - GitHub Actions summary with formatted results table
      - Fails CI if any formatting violations detected
  - **Documentation**
    - New file: `docs/guides/code-style.md` - Comprehensive code style guide
      - Formatter configurations for Python, PowerShell, SQL
      - Installation instructions for all formatters
      - Before/after formatting examples
      - Editor integration guide (VS Code, general editors)
      - Pre-commit hooks usage
      - CI/CD enforcement details
      - Manual formatting commands
      - Best practices and troubleshooting
      - Reference links to formatter documentation
    - Updated `README.md` - Code style section and formatting badges
      - Added Black code style badge
      - Added Code Formatting workflow badge
      - New "Code Style" section with formatter overview
      - Format commands for all languages
      - Editor integration details
      - Links to comprehensive code style guide
  - **Features**
    - Automated formatting for Python (Black), PowerShell (PSScriptAnalyzer), SQL (SQLFluff)
    - Pre-commit hooks enforce formatting before commit
    - CI/CD pipeline enforces formatting on all PRs and pushes
    - Editor integration with format-on-save support
    - Consistent code style across entire repository
    - Comprehensive documentation and troubleshooting guides

- **Pre-Commit Framework for Multi-Language Linting** (#463) - Comprehensive pre-commit hook system

  - **Pre-Commit Framework Installation**
    - New file: `.pre-commit-config.yaml` - Main configuration with all hooks and versions
    - Added `pre-commit>=3.0.0` to `requirements.txt`
    - Updated `scripts/install-hooks.sh` (v2.0.0) - Automated pre-commit framework installation
      - Installs pre-commit framework via pip
      - Configures pre-commit and commit-msg hooks
      - Runs validation on all files
      - Cross-platform support (Linux, macOS, Windows)
  - **Configuration Files**
    - New file: `.pylintrc` - Pylint configuration (max line length 100, ignores tests)
    - New file: `pyproject.toml` - Black, Bandit, and Commitizen configuration
    - New file: `.sqlfluffrc` - SQLFluff configuration (PostgreSQL dialect, max line 120)
  - **General Hooks** (from pre-commit-hooks v4.5.0)
    - `trailing-whitespace` - Removes trailing whitespace (auto-fix)
    - `end-of-file-fixer` - Ensures files end with newline (auto-fix)
    - `check-yaml` - Validates YAML syntax
    - `check-json` - Validates JSON syntax
    - `check-added-large-files` - Warns about files >5MB
    - `check-merge-conflict` - Detects merge conflict markers
    - `detect-private-key` - Prevents accidental credential leaks
  - **Python Hooks**
    - Black (v24.1.1) - Auto-formats Python code (line length 100, target Python 3.11)
    - Pylint (v3.0.0) - Python linting (errors only)
    - Bandit (v1.7.5) - Security scanning (excludes tests/fixtures)
  - **PowerShell Hooks**
    - PSScriptAnalyzer (local) - PowerShell linting (errors only, requires pwsh)
  - **SQL Hooks**
    - SQLFluff (v3.0.0) - SQL linting and auto-formatting (PostgreSQL dialect)
  - **Commit Message Validation**
    - Commitizen (v3.12.0) - Enforces Conventional Commits format
  - **CI/CD Integration**
    - Updated `.github/workflows/sonarcloud.yml` - Runs pre-commit hooks on all files
    - New workflow: `.github/workflows/pre-commit-autoupdate.yml`
      - Weekly automatic hook updates (Sundays at midnight UTC)
      - Creates PR with updated hook versions
      - Manual trigger support via workflow_dispatch
  - **Documentation**
    - Updated `docs/guides/git-hooks.md` (v2.0.0) - Comprehensive pre-commit framework guide
      - Installation and setup instructions
      - All hook descriptions and configurations
      - Running hooks manually (staged files, all files, specific files)
      - Skipping hooks (--no-verify, SKIP environment variable)
      - Updating hooks (manual and automatic)
      - Configuration files reference
      - CI/CD integration details
      - Comprehensive troubleshooting (14+ common issues)
      - Testing hooks guide
      - FAQ section (10+ questions)
    - Updated `INSTALLATION.md` - Pre-commit framework installation instructions
      - Multi-language hook support details
      - Installation script explanation
      - Link to comprehensive documentation
  - **Features**
    - Configuration version-controlled in `.pre-commit-config.yaml`
    - Automatic hook installation for all team members
    - Multi-language support (Python, PowerShell, SQL)
    - Extensive hook library with 100+ available pre-built hooks
    - Automatic weekly updates via CI/CD
    - Per-hook configuration and selective execution
    - Fast execution with caching
    - Easy to add/remove hooks
    - Backward compatible (post-commit and post-merge hooks retained)
  - **Migration from Manual Hooks**
    - Manual hooks in `hooks/` directory deprecated for pre-commit/commit-msg
    - Post-commit and post-merge hooks remain manual (not supported by pre-commit)
    - Pre-commit handles pre-commit and commit-msg stages
    - Legacy hooks documented in git-hooks.md

- **Architecture Documentation** (#462) - Comprehensive architecture documentation for the repository

  - **Core Architecture Document**
    - New file: `ARCHITECTURE.md` - High-level architecture overview at repository root
      - Design principles (language-based organization, domain categorization, shared infrastructure, cross-platform support)
      - System context with external integrations diagram
      - Component architecture with module relationships
      - 6 key design decisions with rationale (monolithic repo, unified logging, PowerShell 7+, module reusability, retry logic, test coverage)
      - Links to all detailed architecture documents
  - **Database Schemas Documentation**
    - New file: `docs/architecture/database-schemas.md` - Complete database schema documentation
      - ER diagrams for Timeline, GnuCash, and Job Scheduler databases (Mermaid diagrams)
      - Table schemas with column descriptions and indexes
      - Data flow diagrams for timeline processing workflow
      - Database backup strategies and retention policies
      - Access patterns and common queries
      - User permissions and security model
  - **Module Dependencies Documentation**
    - New file: `docs/architecture/module-dependencies.md` - Module dependency analysis
      - Complete PowerShell module dependency graph (8 modules) with Mermaid visualization
      - Complete Python module dependency graph (5 modules) with Mermaid visualization
      - Detailed documentation for each module (purpose, dependencies, dependents, features)
      - External dependencies (PostgreSQL, VLC, Google APIs, CloudConvert)
      - Cross-language dependencies and unified logging specification
      - Module deployment process and configuration
      - Dependency coupling analysis and refactoring opportunities
  - **External Integrations Documentation**
    - New file: `docs/architecture/external-integrations.md` - External service integration guide
      - Google Drive API integration (OAuth2 flow, authentication, API scopes, rate limits)
      - CloudConvert API integration (API key authentication, conversion workflows)
      - PostgreSQL integration (connection methods, backup architecture, service management)
      - VLC Media Player integration (command-line invocation, screenshot capture)
      - Windows Task Scheduler integration (scheduled backups, system maintenance)
      - Git hooks integration (pre-commit, commit-msg, post-commit, post-merge)
      - Security considerations (credential management, API key rotation)
      - Troubleshooting guide for common integration issues
  - **Data Flows Documentation**
    - New file: `docs/architecture/data-flows.md` - Workflow and data flow diagrams
      - 7 comprehensive workflow diagrams (Mermaid sequence diagrams)
        - Database backup workflow (PostgreSQL → Local → Google Drive)
        - Timeline processing workflow (JSON/CSV → PostgreSQL → GPX with elevation)
        - Log management workflow (discovery → age check → purge)
        - File distribution workflow (source → random name → destinations)
        - Video screenshot workflow (VLC capture → optional Python cropping)
        - Git commit workflow (pre-commit → commit-msg → post-commit)
        - Module deployment workflow (configuration → validation → deployment)
      - Critical path analysis with timing estimates
      - Error handling and retry logic documentation
      - Performance considerations and optimization strategies
  - **README Integration**
    - Updated `README.md` with new "Architecture" section linking all architecture documents
    - Positioned after "Repository Structure" and before "Installation"
  - **Benefits**
    - Improved onboarding for contributors and maintainers
    - Clear understanding of system design and component interactions
    - Documented design decisions with rationale for future reference
    - Visual diagrams (15+ Mermaid diagrams) for easier comprehension
    - Troubleshooting guide for external integrations
    - Foundation for future architectural changes and refactoring

- **Shared Utilities Modules** (#461) - Extracted common patterns into reusable modules

  - **PowerShell Core Modules**
    - New module: `ErrorHandling` (v1.0.0) - Standardized error handling and retry logic
      - `Invoke-WithErrorHandling` - Execute script blocks with consistent error handling
      - `Invoke-WithRetry` - Automatic retry with exponential backoff (configurable delay, max retries, backoff cap)
      - `Test-IsElevated` - Cross-platform privilege detection (Windows admin / Linux-macOS root)
      - `Assert-Elevated` - Require elevated privileges with custom messages
      - `Test-CommandAvailable` - Check if command/cmdlet is available
      - Automatic integration with PowerShellLoggingFramework
      - Comprehensive unit tests with Pester
    - New module: `FileOperations` (v1.0.0) - File operations with built-in retry logic
      - `Copy-FileWithRetry` - Resilient file copy with exponential backoff
      - `Move-FileWithRetry` - Resilient file move with retry
      - `Remove-FileWithRetry` - Resilient file deletion with retry
      - `Rename-FileWithRetry` - Resilient file rename with retry
      - `Test-FolderWritable` - Test directory write permissions with optional creation
      - `Add-ContentWithRetry` - Append content with retry (ideal for logging)
      - `New-DirectoryIfNotExists` - Ensure directory exists
      - `Get-FileSize` - Get file size in bytes
      - Depends on ErrorHandling module for retry logic
      - Comprehensive unit tests with Pester
    - New module: `ProgressReporter` (v1.0.0) - Standardized progress reporting
      - `Show-Progress` - Consistent progress bar formatting
      - `Write-ProgressLog` - Combine progress display with logging
      - `New-ProgressTracker` - Create stateful progress tracker with configurable update frequency
      - `Update-ProgressTracker` - Update progress with automatic display throttling
      - `Complete-ProgressTracker` - Mark progress complete and hide bar
      - `Write-ProgressStatus` - Update progress status without changing percentage
      - Support for nested progress bars (via Id parameter)
      - Optional integration with PowerShellLoggingFramework
      - Comprehensive unit tests with Pester
  - **Python Utils Modules**
    - New module: `error_handling` (v1.0.0) - Error handling decorators and utilities
      - `@with_error_handling` - Decorator for standardized error handling
      - `@with_retry` - Decorator for automatic retry with exponential backoff
      - `retry_operation` - Execute operations with retry logic
      - `is_elevated()` - Cross-platform privilege detection (Windows admin / Unix root)
      - `require_elevated()` - Require elevated privileges with custom messages
      - `safe_execute()` - Execute functions with error handling
      - `ErrorContext` - Context manager for error handling with optional retry
      - Integration with Python logging framework
      - Comprehensive unit tests with pytest
    - New module: `file_operations` (v1.0.0) - File operations with retry logic
      - `copy_with_retry()` - Resilient file copy with exponential backoff
      - `move_with_retry()` - Resilient file move with retry
      - `remove_with_retry()` - Resilient file deletion with retry
      - `is_writable()` - Test directory write permissions
      - `ensure_directory()` - Ensure directory exists (creates if needed)
      - `get_file_size()` - Get file size in bytes
      - `safe_write_text()` - Write text safely with optional atomic write
      - `safe_append_text()` - Append text with retry logic
      - Uses exponential backoff for retry operations
      - Integration with Python logging framework
      - Comprehensive unit tests with pytest
  - **Documentation**
    - New guide: `docs/guides/using-shared-utilities.md` - Comprehensive migration guide
      - Before/after examples for all modules
      - Best practices for retry logic and error handling
      - Cross-platform considerations
      - Deployment and testing instructions
    - Module-specific READMEs with detailed API documentation
      - `src/powershell/modules/Core/ErrorHandling/README.md`
      - `src/powershell/modules/Core/FileOperations/README.md`
      - `src/powershell/modules/Core/Progress/README.md`
      - `src/python/modules/utils/README.md`
  - **Testing**
    - PowerShell unit tests (Pester):
      - `tests/powershell/unit/ErrorHandling.Tests.ps1`
      - `tests/powershell/unit/FileOperations.Tests.ps1`
      - `tests/powershell/unit/ProgressReporter.Tests.ps1`
    - Python unit tests (pytest):
      - `tests/python/unit/test_error_handling.py`
      - `tests/python/unit/test_file_operations.py`
    - All modules have ≥70% test coverage
  - **Benefits**
    - Reduced code duplication by ≥30% across scripts
    - Consistent error handling patterns repository-wide
    - Centralized bug fixes benefit all scripts
    - Cross-platform support (Windows, Linux, macOS)
    - Exponential backoff retry logic with configurable limits
    - Integration with existing logging frameworks

- **Test Coverage Reporting Infrastructure** (#459) - Comprehensive coverage tracking and reporting system

  - **Codecov Integration**
    - New file: `codecov.yml` - Codecov service configuration
      - Coverage targets: `auto` (Phase 1 - informational only, will enforce 30% in Phase 3)
      - Threshold tolerance: 5% coverage drop allowed before alerting
      - Language-specific flags for Python and PowerShell
      - Coverage precision: 2 decimal places, range 50-80%
      - Exclusions: tests, samples, fixtures, docs, config files
      - Informational mode during ramp-up (doesn't fail builds)
    - CI/CD integration with Codecov upload actions
      - Python coverage uploaded with `python` flag
      - PowerShell coverage uploaded with `powershell` flag
      - Automatic PR comments with coverage diffs
      - GitHub Checks annotations on changed files
  - **PowerShell Test Coverage Helper**
    - New script: `tests/powershell/Invoke-Tests.ps1` (v1.0.0)
      - Automated Pester test execution with coverage
      - Configurable coverage thresholds (default: 0% in Phase 1, will increase to 30%)
      - JaCoCo format output for SonarCloud/Codecov compatibility
      - Detailed terminal output with coverage summary
      - Exit code enforcement for CI/CD integration
      - Parameters: `-MinimumCoverage`, `-CodeCoverageEnabled`, `-Verbosity`
      - Current baseline: 0.37% coverage (21/5,751 commands)
  - **Python Coverage Configuration**
    - Updated `pytest.ini` with coverage threshold enforcement
      - Added `--cov-fail-under=1` (Phase 1 baseline, will increase to 30% over 6 months)
      - Updated coverage report paths: `coverage/python/coverage.xml`, `coverage/python/html/`
      - Coverage includes both `src/python/` and `src/common/`
  - **CI/CD Workflow Updates** (`.github/workflows/sonarcloud.yml`)
    - Updated Python test step to use new coverage paths
    - Added Codecov upload for Python coverage
    - Replaced inline PowerShell test config with `Invoke-Tests.ps1` call
    - Added Codecov upload for PowerShell coverage
    - Updated SonarCloud scanner with new coverage report paths
    - All coverage reports uploaded as GitHub artifacts
  - **Coverage Path Standardization**
    - Updated `sonar-project.properties` with new coverage paths
      - Python: `coverage/python/coverage.xml`
      - PowerShell: `coverage/powershell/coverage.xml`
    - Updated `.gitignore` with comprehensive coverage exclusions
      - Added `coverage/` directory
      - Added `*.cover`, `.hypothesis/`
      - Added `powershell-coverage.xml`, `powershell-testresults.xml`
  - **Coverage Badges**
    - Added to `README.md`:
      - Overall Codecov badge
      - Python-specific coverage badge (flag: python)
      - PowerShell-specific coverage badge (flag: powershell)
    - Badges link to Codecov and SonarCloud dashboards
  - **Documentation Updates**
    - Updated `README.md` with comprehensive Test Coverage section
      - Coverage targets (30% minimum, 50-60% target)
      - Links to Codecov and SonarCloud dashboards
      - Local coverage generation instructions
      - Platform-specific commands for viewing HTML reports
    - Updated `tests/README.md` with extensive coverage documentation
      - Coverage targets table with minimum and target values
      - Coverage enforcement details (pytest, Pester, Codecov)
      - Viewing coverage reports (online and local)
      - Python HTML report generation and viewing
      - PowerShell coverage using `Invoke-Tests.ps1`
      - Coverage configuration files reference
    - Updated `docs/guides/testing.md` with detailed coverage guide
      - Coverage enforcement mechanisms
      - Coverage guidelines and best practices
      - Comprehensive viewing instructions (local and online)
      - Online dashboard features (Codecov, SonarCloud)
      - Coverage configuration files documentation
      - Code exclusion strategies (Python pragma, PowerShell file patterns)
      - Coverage best practices (6 key principles)
    - New document: `docs/COVERAGE_ROADMAP.md` - Phased coverage ramp-up plan
      - Phase 1 (Months 1-2): Baseline establishment, 1% threshold
      - Phase 2 (Months 3-4): 15% coverage, focus on shared modules
      - Phase 3 (Months 5-6): 30% coverage target achieved
      - Phase 4 (Month 7+): 50%+ long-term goal
      - Component-specific strategies and priorities
      - Threshold adjustment schedule
      - Coverage quality guidelines
  - Features:
    - Automated coverage reporting in CI/CD pipeline
    - Phased threshold enforcement (starting at 1%/0%, ramping to 30% over 6 months)
    - Coverage trends tracked over time via Codecov
    - Language-specific coverage tracking (Python, PowerShell flags)
    - HTML coverage reports for local development
    - PR-level coverage diffs and annotations
    - Integration with existing SonarCloud quality gates
    - Comprehensive documentation including roadmap
    - Current baseline: PowerShell 0.37%, Python TBD%, Overall ~1%
    - Target: 50%+ overall (60% Python, 50% PowerShell) by Month 9

- **Complete Module Deployment Configuration** (#456) - Comprehensive module deployment system for PowerShell and Python

  - **PowerShell Module Manifests** - Created .psd1 manifests for all modules
    - `src/common/PostgresBackup.psd1` (v2.0.0) - PostgreSQL database backup module
    - `src/common/PowerShellLoggingFramework.psd1` (v2.0.0) - Cross-platform structured logging framework
    - `src/common/PurgeLogs.psd1` (v2.0.0) - Log file purging and retention management
    - Existing manifests updated: RandomName (v2.1.0), Videoscreenshot (v3.0.2)
  - **Deployment Scripts**
    - `scripts/Deploy-Modules.ps1` (v1.0.0) - Automated PowerShell module deployment
      - Validates module manifests before deployment
      - Supports multiple deployment targets (System, User, Alt paths)
      - Cross-platform support (Windows, Linux, macOS)
      - Creates version-specific directories for each module
      - Comprehensive error handling and logging
    - `scripts/install-modules.sh` (v1.0.0) - Cross-platform installer for all modules
      - Installs both PowerShell and Python modules
      - Supports selective installation (--powershell-only, --python-only)
      - Automatic detection of pwsh/powershell and pip/pip3
      - Force overwrite option for updates
  - **Module Configuration**
    - Updated `config/module-deployment-config.txt` with all 5 PowerShell modules
    - Pipe-delimited format: ModuleName|SourcePath|Targets|Author|Description
    - Supports System, User, and custom Alt path deployments
  - **Python Module Enhancement**
    - Updated `setup.py` to v0.2.0 for python_logging_framework
    - Changed package name to 'my-scripts-logging' for clarity
    - Added pytz dependency for timezone support
    - Enhanced metadata with classifiers and project URLs
    - Switched from packages to py_modules for single-file module
  - **CI/CD Integration**
    - New workflow: `.github/workflows/validate-modules.yml`
    - Validates all PowerShell manifests on every push
    - Tests module deployment on Ubuntu, Windows, and macOS
    - Verifies module installation and import functionality
    - Validates deployment configuration syntax
    - Runs Python module installation tests
  - **Documentation**
    - New guide: `docs/guides/module-deployment.md` - Comprehensive module deployment documentation
      - Installation instructions (automated and manual)
      - Module configuration format and examples
      - Adding new modules step-by-step guide
      - Versioning strategy
      - Publishing to PowerShell Gallery / PyPI (optional)
      - Troubleshooting common issues
    - New file: `INSTALLATION.md` - Complete installation guide
      - Platform-specific instructions (Windows, Linux, macOS)
      - Prerequisites and requirements
      - Module installation procedures
      - Verification steps
      - Comprehensive troubleshooting
      - Uninstallation procedures
    - Updated `README.md` with Module Installation section
      - Quick start installation instructions
      - List of available modules with versions
      - Usage examples for PowerShell and Python modules
  - **Module Versions Synchronized**
    - Core modules aligned with repository version 2.0.0
    - Independent modules maintain separate versions
    - Python module bumped to 0.2.0
  - Features:
    - Automated module deployment to standard paths
    - No manual path management required
    - Version-specific installations support side-by-side versions
    - Cross-platform compatibility
    - Module validation before deployment
    - Comprehensive error handling and rollback

- **Git Hooks for Quality Enforcement** (#455) - Automated code quality checks and standards enforcement

  - New directory: `hooks/` - Tracked git hook templates for distribution
  - New directory: `scripts/` - Repository automation scripts
  - New hook: `hooks/pre-commit` (v1.0.0) - Validates code quality before commits
    - Checks for debug statements (Write-Debug, console.log, debugger)
    - Runs PowerShell linting with PSScriptAnalyzer
    - Runs Python linting with pylint (falls back to syntax check)
    - Warns about large files (>10MB)
  - New hook: `hooks/commit-msg` (v1.0.0) - Enforces Conventional Commits format
    - Validates commit message structure: `type(scope): description`
    - Supports types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
    - Allows breaking change indicator with `!`
  - New hook: `hooks/post-commit` (v1.0.0) - Executes post-commit automation
    - Calls `Invoke-PostCommitHook.ps1` for file mirroring and module deployment
    - Includes comprehensive logging per logging specification
  - New hook: `hooks/post-merge` (v1.0.0) - Executes post-merge automation
    - Calls `Invoke-PostMergeHook.ps1` for merge-specific operations
    - Includes comprehensive logging per logging specification
  - New script: `scripts/install-hooks.sh` (v1.0.0) - Hook installation utility
    - Copies hooks from `hooks/` to `.git/hooks/`
    - Makes hooks executable automatically
    - Detects and reports installation status with color-coded output
  - New documentation: `docs/guides/git-hooks.md` - Comprehensive git hooks guide
    - Detailed hook behavior and requirements
    - Installation and troubleshooting procedures
    - Testing guidelines and examples
    - Bypass procedures and best practices
    - Cross-platform compatibility notes (Linux, macOS, Windows)
    - FAQ and common issues
  - Features:
    - Cross-platform compatibility (Linux, macOS, Windows)
    - Standardized logging to `logs/git-hooks_YYYY-MM-DD.log`
    - Graceful degradation when optional tools unavailable
    - Bypass capability with `--no-verify` flag
    - Auto-installs PSScriptAnalyzer if missing
    - All hooks follow logging specification format

- Comprehensive testing framework setup for Python and PowerShell code
- Python unit tests using pytest:
  - `tests/python/unit/test_validators.py` - Tests for input validation functions
  - `tests/python/unit/test_logging_framework.py` - Tests for logging framework
  - `tests/python/unit/test_csv_to_gpx.py` - Tests for CSV to GPX conversion
- PowerShell unit tests using Pester:
  - `tests/powershell/unit/RandomName.Tests.ps1` - Tests for RandomName module
  - `tests/powershell/unit/FileDistributor.Tests.ps1` - Tests for FileDistributor script
- Test infrastructure files:
  - `pytest.ini` - pytest configuration
  - `tests/python/conftest.py` - Shared pytest fixtures and configuration
- Testing documentation:
  - `tests/README.md` - Comprehensive guide on running and writing tests
  - `docs/guides/testing.md` - Testing standards and best practices
- Coverage reporting integrated with SonarCloud
- Python dependencies for testing:
  - pytest >= 7.4.0
  - pytest-cov >= 4.1.0
  - pytest-mock >= 3.11.1

### Changed

- Updated `requirements.txt` to include pytest and coverage dependencies
- Enhanced `.github/workflows/sonarcloud.yml` with:
  - Python test execution with coverage reporting
  - PowerShell test execution using Pester with code coverage
  - Coverage report uploads to SonarCloud
  - Updated SonarCloud configuration to include coverage data
- Updated root `README.md` with testing section and instructions

### Infrastructure

- CI/CD pipeline now runs all tests automatically on push and pull requests
- Test execution completes in under 2 minutes
- Coverage reports are generated in XML format for SonarCloud integration
- Automated test result artifacts uploaded for each CI run

### Coverage Targets

- Shared modules (src/common/): ≥30%
- Core utilities: ≥50%
- Overall project: ≥25%

## [Previous Releases]

For changes prior to the testing framework implementation, see the Git commit history.

# My Scripts Collection – Changelog

All notable repository-wide changes are documented here.
This file tracks major features, infrastructure changes, and cross-cutting updates affecting multiple scripts.

The project follows [Semantic Versioning](https://semver.org) at the repository level, and the structure is inspired by [Keep a Changelog](https://keepachangelog.com).

> **Note**: Individual scripts and modules maintain their own version numbers and changelogs. See script headers or module-specific CHANGELOG files (e.g., `src/powershell/module/Videoscreenshot/CHANGELOG.md`) for component-level changes.

---

## [Unreleased]

### Added

- **Naming Conventions Documentation** (#454) - Comprehensive naming standards for all scripts

  - New document: `docs/guides/naming-conventions.md` - Complete naming conventions guide with examples
  - New document: `docs/RENAME_MAPPING.md` - Detailed mapping of all renamed scripts with justifications
  - Establishes PowerShell `Verb-Noun` PascalCase standard using approved verbs
  - Establishes Python `snake_case` standard per PEP 8
  - Includes validation methods, migration guide, and FAQs

- **Monthly System Health Check** (#414) - Automated Windows system maintenance solution
  - New script: `Invoke-SystemHealthCheck.ps1` (v1.0.0) - Runs SFC and DISM operations with comprehensive logging
  - New script: `Install-SystemHealthCheckTask.ps1` (v1.0.0) - Automated setup for scheduled task configuration
  - Task scheduler XML: `Monthly System Health Check.xml` - Pre-configured monthly maintenance task
  - Comprehensive documentation: `docs/system-health-check.md` with installation, usage, and troubleshooting guides
  - Features:
    - Runs monthly on the 1st of each month at 2:00 AM
    - Executes with Administrator privileges automatically
    - Captures timestamped logs for review
    - Validates disk space and provides duration tracking
    - Includes detailed summary reports

### Changed

- **⚠️ BREAKING: Standardized Script Naming Conventions** (#454) - All scripts renamed to follow language best practices

  - **PowerShell Scripts** (19 renamed):
    - `logCleanup.ps1` → `Clear-PostgreSqlLog.ps1`
    - `cleanup-git-branches.ps1` → `Remove-MergedGitBranch.ps1`
    - `picconvert.ps1` → `Convert-ImageFile.ps1`
    - `post-commit-my-scripts.ps1` → `Invoke-PostCommitHook.ps1`
    - `post-merge-my-scripts.ps1` → `Invoke-PostMergeHook.ps1`
    - `DeleteOldDownloads.ps1` → `Remove-OldDownload.ps1`
    - `scrubname.ps1` → `Remove-FilenameString.ps1`
    - `videoscreenshot.ps1` → `Show-VideoscreenshotDeprecation.ps1`
    - `job_scheduler_pg_backup.ps1` → `Backup-JobSchedulerDatabase.ps1`
    - `purge_logs.ps1` → `Clear-LogFile.ps1`
    - `recover-extensions.ps1` → `Restore-FileExtension.ps1`
    - `handle.ps1` → `Get-FileHandle.ps1`
    - `pgconnect.ps1` → `Test-PostgreSqlConnection.ps1`
    - `WLANsvc.ps1` → `Restart-WlanService.ps1`
    - `cloudconvert_driver.ps1` → `Invoke-CloudConvert.ps1`
    - `SelObj.ps1` → `Show-RandomImage.ps1`
    - `gnucash_pg_backup.ps1` → `Backup-GnuCashDatabase.ps1`
    - `pg_backup_common.ps1` → `Backup-PostgreSqlCommon.ps1`
    - `timeline_data_pg_backup.ps1` → `Backup-TimelineDatabase.ps1`
  - **Python Scripts** (2 renamed):
    - `csv-to-gpx.py` → `csv_to_gpx.py`
    - `find-duplicate-images.py` → `find_duplicate_images.py`
  - Updated all references in:
    - Windows Task Scheduler XML files
    - Test files
    - Documentation
    - Batch wrappers
    - Module documentation
  - Git history preserved for all renames using `git mv`
  - See `docs/RENAME_MAPPING.md` for complete mapping and migration guide

- Updated `README.md` to include System Maintenance category in features
- Added Featured Scripts and Tools section to README with links to documentation

---

## Notes on Versioning

This repository contains multiple independent scripts and modules, each with its own version number:

- **Repository-level versions** (this file): Track major infrastructure changes, new script additions, and cross-cutting features
- **Script-level versions**: Individual scripts may include version information in their headers
- **Module-level versions**: PowerShell modules maintain their own CHANGELOG files (e.g., Videoscreenshot module)

When referencing versions:

- For specific script changes, see the script header or module CHANGELOG
- For repository-wide changes affecting multiple scripts, refer to this file

---

## Version History

_This is the initial version of the repository-level CHANGELOG. Previous changes to individual scripts are documented in their respective files or commit history._

---
