# CI Checks Investigation Report

**Issue:** #632 - Reduced CI Checks on PRs – Only CodeQL Running
**Date:** 2025-12-06
**Investigator:** Claude Code
**Branch:** `claude/investigate-ci-checks-01Jb8PemxsBEE3HRgTDZfmck`

## Executive Summary

**Finding:** All GitHub Actions workflows are **correctly configured** and should run on pull requests to `main`. The workflows themselves are not the source of the problem.

**Root Cause:** The issue is **NOT in the workflow files**. Based on the investigation, the most likely cause is a change to **GitHub repository settings** (branch protection rules or required status checks) that cannot be verified from the code repository alone.

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

### What This Investigation Rules Out

❌ **NOT** a workflow file configuration issue
❌ **NOT** missing or deleted workflows
❌ **NOT** incorrect trigger conditions
❌ **NOT** workflows in wrong branch
❌ **NOT** YAML syntax errors

### Most Likely Root Cause

✅ **GitHub Repository Settings Changed**

The most probable explanation is that GitHub repository settings were modified, specifically:

1. **Branch Protection Rules** may have been changed to only require CodeQL checks
2. **Required Status Checks** may have been reduced from the full list to only CodeQL
3. **Status Check Configuration** may have been reset or modified

### Why This Is The Most Likely Cause

1. **Workflows are correctly configured** - they should run automatically on PRs to `main`
2. **CodeQL is running** - proves that GitHub Actions is enabled and working
3. **Only CodeQL is running** - suggests other checks are not required/enforced
4. **Cannot verify from code** - branch protection settings are not stored in the repository

## Required Actions

### Immediate Actions (GitHub UI)

The following must be checked and configured in the GitHub repository settings:

#### 1. Verify Branch Protection Rules

Navigate to: **Repository → Settings → Branches → Branch protection rules → `main`**

Check the following:
- [ ] "Require status checks to pass before merging" is enabled
- [ ] The following status checks are selected as **required**:
  - [ ] `SonarCloud` (from sonarcloud.yml)
  - [ ] `Python Dependency Security Scan` (from security-scan.yml)
  - [ ] `Dependency Review` (from security-scan.yml)
  - [ ] `Check Code Formatting` (from code-formatting.yml)
  - [ ] `CodeQL` (from GitHub Code Scanning)

#### 2. Verify GitHub Actions Secrets

Navigate to: **Repository → Settings → Secrets and variables → Actions**

Ensure the following secrets are configured:
- [ ] `SONAR_TOKEN` - SonarCloud authentication token
- [ ] `CODECOV_TOKEN` - Codecov upload token (if used)
- [ ] `GITHUB_TOKEN` - Should be automatically available

Missing secrets will cause workflows to fail (though they should still run).

#### 3. Verify GitHub Actions Permissions

Navigate to: **Repository → Settings → Actions → General**

Check:
- [ ] "Allow all actions and reusable workflows" is selected
- [ ] Workflow permissions are set to "Read and write permissions"

### Testing The Fix

After updating branch protection rules:

1. Create a test PR from a feature branch to `main`
2. Verify all the following checks appear:
   - CodeQL (2 checks: JavaScript/Python)
   - SonarCloud
   - Python Dependency Security Scan
   - Dependency Review (if from a fork or if dependencies changed)
   - Check Code Formatting

3. Checks should be **required** before the PR can be merged

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
