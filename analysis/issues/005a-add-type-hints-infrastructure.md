# Issue #005a: Setup Type Hints Infrastructure

**Parent Issue**: [#005: Missing Python Type Hints](./005-missing-python-type-hints.md)
**Phase**: Phase 1 - Infrastructure
**Effort**: 3-4 hours

## Description
Install and configure mypy for type checking. Add to development workflow without breaking existing code.

## Implementation

### Add mypy to requirements
```python
# requirements.txt (or requirements-dev.txt)
mypy==1.7.1
types-requests==2.31.0
types-tqdm==4.66.0
```

### Configure mypy.ini
```ini
# mypy.ini (already exists, verify settings)
[mypy]
python_version = 3.11
warn_return_any = True
warn_unused_configs = True

# Start permissive - gradually increase strictness
disallow_untyped_defs = False
check_untyped_defs = True
ignore_missing_imports = True

# Exclude test files initially
[mypy-tests.*]
ignore_errors = True
```

### Add to pre-commit
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.1
    hooks:
      - id: mypy
        args: [--config-file=mypy.ini, --show-error-codes]
        additional_dependencies:
          - types-requests
          - types-tqdm
        pass_filenames: false
        # Start as informational (don't fail on errors)
        verbose: true
```

### Add to CI/CD
```yaml
# .github/workflows/sonarcloud.yml
- name: Run mypy (Type Checking)
  run: |
    pip install mypy types-requests types-tqdm
    mypy src/python --config-file mypy.ini || true  # Informational only
  continue-on-error: true
```

## Testing
```bash
# Test locally
pip install mypy types-requests types-tqdm
mypy src/python --config-file mypy.ini

# Should show type errors but not fail
```

## Acceptance Criteria
- [ ] mypy installed in requirements
- [ ] mypy.ini configured with permissive settings
- [ ] Pre-commit hook added (informational only)
- [ ] CI/CD runs mypy (informational only)
- [ ] Documentation explains how to run mypy locally

## Benefits
- Infrastructure ready for type hints
- Developers see type errors locally
- CI tracks type coverage over time
- No disruption to existing workflow

## Effort
3-4 hours

## Next Steps
After infrastructure is ready:
- Issue #005b: Add type hints to shared modules
- Issue #005c: Add type hints to data processing
