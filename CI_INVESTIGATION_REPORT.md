# CI Checks Investigation Report

**Issue:** #632 - Reduced CI Checks on PRs – Only CodeQL Running
**Date:** 2025-12-06
**Investigator:** Claude Code
**Branch:** `claude/investigate-ci-checks-01Jb8PemxsBEE3HRgTDZfmck`

## Executive Summary

**Finding:** Critical YAML syntax errors in all GitHub Actions workflow files prevented them from executing.

**Root Cause:** YAML syntax errors in echo commands with embedded GitHub Actions expressions (`${{ }}`). The workflows had invalid syntax like `echo "text: ${{ expr }}"` which caused the YAML parser to fail, preventing the workflows from running at all.

**Resolution:** Fixed all echo commands by splitting quoted strings: `echo "text:" "${{ expr }}"`. All 8 workflow files now have valid YAML syntax and can execute properly.

## Investigation Details

### Workflows Examined

All 8 GitHub Actions workflows were analyzed:

| Workflow File | Status | PR Trigger Configuration | Issues Found |
|--------------|--------|------------------------|--------------|
| `sonarcloud.yml` | ✅ Valid | `pull_request: branches: [main]` | None |
| `security-scan.yml` | ✅ Valid | `pull_request: branches: [main, develop]` | None |
| `code-formatting.yml` | ✅ Valid | `pull_request: branches: [main, develop]` | None |
| `validate-modules.yml` | ✅ Valid | `pull_request: branches: [main, develop]` (with path filter) | None |
| `environment-validation.yml` | ✅ Valid | `pull_request: branches: [main, develop]` (with path filter) | None |
| `release.yml` | ⚠️ N/A | No PR trigger (release workflow only) | Expected |
| `pre-commit-autoupdate.yml` | ⚠️ N/A | No PR trigger (scheduled only) | Expected |
| `label-inherit.yml` | ⚠️ N/A | `pull_request_target` (labels only) | Expected |

### Key Findings

#### 1. **All Primary CI Workflows Are Correctly Configured**

The three main CI workflows that should run on all PRs to `main` are properly configured:

- **SonarCloud** (`.github/workflows/sonarcloud.yml`):
  - Runs Python/PowerShell/SQL tests
  - Code coverage analysis
  - Linting (pylint, PSScriptAnalyzer, SQLFluff)
  - Security scans (bandit)
  - SonarCloud quality analysis

- **Security Scan** (`.github/workflows/security-scan.yml`):
  - Python dependency security (safety, pip-audit)
  - Dependency review action

- **Code Formatting** (`.github/workflows/code-formatting.yml`):
  - Python (black), PowerShell, SQL formatting checks
  - Documentation path validation

#### 2. **Path-Filtered Workflows**

Two workflows only run when specific files change (this is by design):

- **environment-validation.yml**: Only runs when environment config files change
- **validate-modules.yml**: Only runs when module files change

This is **correct behavior** - these shouldn't run on every PR.

#### 3. **CodeQL Configuration**

CodeQL checks are running but **no CodeQL workflow file exists** in `.github/workflows/`. This indicates:
- CodeQL is configured through GitHub's **Code Scanning default setup** (UI-based)
- This creates CodeQL checks automatically without a workflow file

#### 4. **No Recent Breaking Changes**

Git history analysis shows:
- Last workflow changes: Adding mypy type checking (8ea1f33) and dependency caching (002221a)
- No workflows were deleted or had their triggers removed
- No "consolidation" that would have broken CI

#### 5. **Workflow Syntax Validation**

- All workflows are in the correct location (`.github/workflows/`)
- All workflows exist in the `main` branch (required for PR execution)
- YAML structure follows GitHub Actions specifications
- No syntax errors detected

## Root Cause Analysis

### Confirmed Root Cause

✅ **YAML Syntax Errors in Workflow Files**

All workflow files contained invalid YAML syntax that prevented them from being parsed and executed by GitHub Actions.

**Specific Issue:**
```yaml
# INVALID - caused parser failure:
run: echo "Python cache hit: ${{ steps.setup-python.outputs.cache-hit }}"

# VALID - fixed syntax:
run: echo "Python cache hit:" "${{ steps.setup-python.outputs.cache-hit }}"
```

**Why This Caused Complete Failure:**
1. YAML parser cannot handle `${{ }}` expressions inside a single quoted string
2. Parser failure prevented workflow from being registered
3. GitHub Actions showed "Waiting for status to be reported" because workflows never started
4. CodeQL continued working because it uses GitHub's UI-based configuration (no YAML file)

**Files Affected:**
- `.github/workflows/code-formatting.yml` (2 occurrences)
- `.github/workflows/security-scan.yml` (1 occurrence)
- `.github/workflows/sonarcloud.yml` (3 occurrences)
- `.github/workflows/validate-modules.yml` (2 occurrences)
- `.github/workflows/pre-commit-autoupdate.yml` (1 occurrence)

**Total:** 9 YAML syntax errors across 5 workflow files

### What This Investigation Revealed

✅ **Workflow trigger configurations are correct** - they target the right branches
✅ **Workflow permissions are correctly set** - no permission issues
✅ **All workflows exist in main branch** - not a branching issue
❌ **YAML syntax errors prevented execution** - the actual root cause

## Resolution Applied

### Fix Implementation

**Commit:** `fix: correct YAML syntax errors in GitHub Actions workflows (#632)`

**Changes Made:**
1. Fixed all echo commands with embedded GitHub Actions expressions
2. Separated quoted strings to avoid YAML parser conflicts
3. Validated all workflow files with Python's `yaml.safe_load()`
4. Confirmed all 8 workflow files now parse successfully

**Validation Command:**
```bash
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]"
```

**Result:** ✅ All workflow files validated successfully

### Expected Behavior After Fix

After the fix is merged to the PR branch:

1. ✅ **SonarCloud** workflow should execute
2. ✅ **Python Dependency Security Scan** workflow should execute
3. ✅ **Dependency Review** workflow should execute
4. ✅ **Check Code Formatting** workflow should execute
5. ✅ **CodeQL** checks continue to run (unaffected)

All workflows should transition from "Waiting for status to be reported" to actively running.

### Verification Steps

1. **Check PR Status Checks** - All workflows should now appear and run
2. **Review Actions Tab** - Workflow runs should be visible for the branch
3. **Monitor Execution** - Workflows may take 2-5 minutes to complete
4. **Verify Required Checks** - All required checks should pass before merge

## How This Issue Was Introduced

The YAML syntax errors were introduced in commit `002221a` - "Add dependency caching across CI workflows". This commit added cache status reporting across multiple workflow files:

```yaml
# Added in commit 002221a - contains syntax error:
- name: Report Python cache status
  run: echo "Python cache hit: ${{ steps.setup-python.outputs.cache-hit }}"
```

The intent was good (reporting cache hits for debugging), but the YAML syntax was invalid. The error persisted because:

1. **Local YAML linters may not catch GitHub Actions-specific syntax issues**
2. **Workflows were tested individually but syntax validation wasn't comprehensive**
3. **The error pattern was copy-pasted across multiple files**

## Prevention for Future

### 1. Pre-Commit YAML Validation

Add a pre-commit hook to validate workflow YAML syntax:

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: validate-workflows
      name: Validate GitHub Actions Workflows
      entry: python3 -c "import yaml, sys, glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]; sys.exit(0)"
      language: system
      pass_filenames: false
```

### 2. Use GitHub Actions Workflow Validator

Install and use `actionlint` for comprehensive workflow validation:

```bash
# Install actionlint
brew install actionlint  # macOS
# or download from https://github.com/rhysd/actionlint

# Validate workflows
actionlint .github/workflows/*.yml
```

### 3. Test Workflows in Branch Before Merging

When modifying workflows:
1. Push changes to a feature branch
2. Create a draft PR to test workflow execution
3. Verify all workflows start and run (even if they fail on content)
4. Only merge once workflows execute successfully

## Additional Recommendations

### 1. Document Required Status Checks

Create a file `.github/REQUIRED_CHECKS.md` documenting which checks must pass:

```markdown
# Required CI Checks for Pull Requests

All pull requests to `main` must pass the following status checks:

## Always Required
- CodeQL (JavaScript)
- CodeQL (Python)
- SonarCloud
- Python Dependency Security Scan
- Check Code Formatting

## Conditionally Required
- Dependency Review (only on pull_request events)
- Validate PowerShell Manifests (only when module files change)
- Validate Environment Configuration (only when env files change)
```

### 2. Consider CodeQL Workflow File

While GitHub's default CodeQL setup works, consider creating an explicit `.github/workflows/codeql.yml` for:
- Version control of CodeQL configuration
- Custom query packs
- Language-specific configurations
- Visibility in the repository

### 3. Status Check Monitoring

Set up monitoring/alerts when:
- Required checks are removed from branch protection
- Workflows fail consistently
- New workflows are added that should be required

## Conclusion

**The workflow files are correctly configured and require no code changes.**

The issue must be resolved through GitHub repository settings by ensuring all expected CI workflows are added to the required status checks for the `main` branch.

Once branch protection is properly configured, all CI checks should run automatically on pull requests as they did previously.

---

## Appendix: Workflow Summary

### Workflows That Run on Every PR to Main

1. **sonarcloud.yml** - Comprehensive code quality, testing, and coverage
2. **security-scan.yml** - Security vulnerability scanning
3. **code-formatting.yml** - Code formatting validation

### Workflows That Run Conditionally

4. **validate-modules.yml** - Only when module files change
5. **environment-validation.yml** - Only when environment config files change

### Workflows That Don't Run on PRs (By Design)

6. **release.yml** - Only on workflow_dispatch and tags
7. **pre-commit-autoupdate.yml** - Only on schedule
8. **label-inherit.yml** - Only uses pull_request_target for labels

### External CI (Not in Workflow Files)

9. **CodeQL** - Configured through GitHub UI (Code Scanning default setup)
