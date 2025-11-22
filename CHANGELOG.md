# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
  - **Use Case**: Sync Git repository (`D:\My Scripts`) to working directory (`C:\Users\manoj\Documents\Scripts`)
    while preserving logs, virtual environments, configs, and other non-repository files
  - **Documentation**: Comprehensive help with examples and parameter descriptions
  - **Examples**:
    ```powershell
    # Preview sync with exclusions
    .\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts" `
        -ExcludeFromDeletion @(".venv", "venv", "logs", "temp", "*.log", "backups") -PreviewOnly

    # Perform actual sync
    .\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts" `
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
      - Triggers on version tags (v*.*.*)
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
      - Runs on push and PR to main/develop/claude/** branches
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
