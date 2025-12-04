# Issue #004c: Re-enable Bandit B113 Timeout Check

**Parent Issue**: [#004: Missing HTTP Timeouts](./004-missing-http-timeouts.md)
**Effort**: 1-2 hours

## Description
Re-enable Bandit security scanner check B113 (requests without timeout) after adding timeouts to all existing code. This prevents new code from missing timeouts.

## Current State
```toml
# pyproject.toml line 27
# B113: requests without timeout (should add timeouts but not blocking)
skips = ["B110", "B311", "B101", "B112", "B405", "B408", "B113", "B318", "B324"]
```

## Implementation

### Step 1: Verify All Timeouts Added
```bash
# Search for requests calls without timeout
grep -rn "requests\.(get|post|put|delete|patch)" src/python/ | \
  grep -v "timeout=" | \
  grep -v "test_" | \
  grep -v "#"

# Should return no results
```

### Step 2: Update pyproject.toml
```toml
# Remove B113 from skips list
skips = ["B110", "B311", "B101", "B112", "B405", "B408", "B318", "B324"]
# B113 now enabled - will fail CI if requests lack timeout
```

### Step 3: Update CI to Enforce
```yaml
# .github/workflows/sonarcloud.yml (line ~82-84)
- name: Run Bandit (Python Security Scan)
  run: |
    bandit -r . -f json -o bandit-report.json -c pyproject.toml
  # Remove continue-on-error if present - should fail on issues
```

### Step 4: Test Locally
```bash
# Run Bandit locally to verify
bandit -r src/python/ -c pyproject.toml

# Should pass with no B113 warnings
```

### Step 5: Add to Pre-commit
```yaml
# .pre-commit-config.yaml
- repo: https://github.com/PyCQA/bandit
  rev: '1.7.9'
  hooks:
    - id: bandit
      args: ['-c', 'pyproject.toml', '-r', 'src/python/']
      # Will catch missing timeouts before commit
```

## Testing

### Add Regression Test
```python
# tests/python/unit/test_security_compliance.py
def test_all_requests_have_timeouts():
    """Verify all HTTP requests include timeout parameter."""
    import ast
    import glob

    violations = []

    for file_path in glob.glob('src/python/**/*.py', recursive=True):
        if 'test_' in file_path:
            continue

        with open(file_path) as f:
            try:
                tree = ast.parse(f.read(), filename=file_path)
            except SyntaxError:
                continue

        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                # Check for requests.method() calls
                if (isinstance(node.func, ast.Attribute) and
                    isinstance(node.func.value, ast.Name) and
                    node.func.value.id == 'requests' and
                    node.func.attr in ['get', 'post', 'put', 'delete', 'patch']):

                    # Check if timeout keyword argument present
                    has_timeout = any(kw.arg == 'timeout' for kw in node.keywords)
                    if not has_timeout:
                        violations.append(f"{file_path}:Line {node.lineno}")

    assert len(violations) == 0, f"Requests without timeout:\n" + "\n".join(violations)
```

## Acceptance Criteria
- [ ] All existing code has timeouts
- [ ] B113 removed from skip list
- [ ] Bandit passes in CI
- [ ] Pre-commit hook enabled
- [ ] Regression test added
- [ ] Documentation updated

## Benefits
- Prevents new timeout-less requests
- Enforced in CI/CD pipeline
- Catches violations before merge
- Maintains code quality standards

## Rollout Plan
1. **Week 1**: Add timeouts (Issues #004a)
2. **Week 2**: Update documentation (#004b)
3. **Week 2**: Re-enable B113 check (#004c)
4. **Monitor**: Watch for false positives

## Effort
1-2 hours (mostly verification and testing)

## Related
- Issue #004a (add CloudConvert timeouts)
- Issue #004b (documentation)
- Complements security scanning infrastructure
