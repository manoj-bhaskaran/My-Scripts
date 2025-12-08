# Issue: Pre-commit Framework Not Installed

**Priority:** High
**Type:** Dependency
**Component:** Pre-commit Framework

## Description

The repository is configured to use the pre-commit framework (`.pre-commit-config.yaml` exists) but the framework itself is not installed in the environment.

## Evidence

```bash
$ pre-commit --version
bash: pre-commit: command not found
```

Configuration file exists: `.pre-commit-config.yaml`
Installation script exists: `scripts/install-hooks.sh`

## Current Configuration

The `.pre-commit-config.yaml` file defines hooks for:
- **General hooks**: trailing-whitespace, end-of-file-fixer, check-yaml, check-json, check-added-large-files, check-merge-conflict, detect-private-key
- **Python hooks**: black (formatter), pylint (linter), bandit (security), mypy (type checking), safety (dependency scanning)
- **Commit message validation**: commitizen (conventional commits)
- **Disabled hooks**: PSScriptAnalyzer (PowerShell), sqlfluff (SQL)

## Impact

- **Severity:** High
- Modern pre-commit hooks are not running
- Python code is not being auto-formatted (Black)
- Python linting (Pylint) is not running
- Security scanning (Bandit) is not running
- Commit message validation is not enforced
- CI/CD expects pre-commit to be available

## Root Cause

The pre-commit framework is a Python package that must be installed:
```bash
pip install pre-commit
pre-commit install
```

The repository provides `scripts/install-hooks.sh` to automate this, but:
1. Script may not have been run
2. Python/pip may not be available in all environments
3. No verification that installation completed successfully

## Recommended Actions

1. **Add Python dependency documentation** - Clearly state Python 3.7+ and pip are required
2. **Verify installation** - Create a test script to verify pre-commit is installed and working
3. **CI/CD check** - Add workflow step to verify pre-commit configuration is valid
4. **Alternative for non-Python environments** - Consider providing standalone hooks for environments without Python
5. **Update pre-commit versions** - Run `pre-commit autoupdate` to get latest hook versions

## Current Hook Versions

Need updating (from `.pre-commit-config.yaml`):
- pre-commit-hooks: v4.5.0
- black: 24.3.0 (latest is 24.10.0+)
- pylint: v3.0.0
- bandit: 1.7.9
- mypy: v1.7.1
- safety: v1.3.3
- commitizen: v3.12.0

## References

- `.pre-commit-config.yaml`
- `scripts/install-hooks.sh`
- `docs/guides/git-hooks.md`
- [pre-commit.com](https://pre-commit.com)

## Related Issues

- #001: Git Hooks Not Installed
- #003: Dual Hook Management System
- #006: Missing Dependencies (Git LFS, PowerShell)
