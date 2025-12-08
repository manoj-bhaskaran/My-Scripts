# Issue: Conventional Commits Validation Duplicated

**Priority:** Low
**Type:** Duplication
**Component:** Git Hooks (commit-msg)

## Description

Commit message validation for Conventional Commits format is implemented twice:
1. Manual shell script in `hooks/commit-msg`
2. Commitizen hook in `.pre-commit-config.yaml`

Both validate the same format but with slightly different implementations, creating unnecessary duplication.

## Evidence

### Manual Implementation

**`hooks/commit-msg` (lines 36-82):**
```bash
# Skip validation for merge commits
if echo "$COMMIT_SUBJECT" | grep -qE "^Merge (branch|pull request|remote-tracking branch)"; then
    log_message "INFO" "Merge commit detected, skipping validation"
    exit 0
fi

# Skip validation for revert commits
if echo "$COMMIT_SUBJECT" | grep -qE "^Revert "; then
    log_message "INFO" "Revert commit detected, skipping validation"
    exit 0
fi

# Conventional Commits format: type(scope): description
PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([a-z0-9\-]+\))?!?: .{3,100}$"

if echo "$COMMIT_SUBJECT" | grep -qE "$PATTERN"; then
    log_message "INFO" "Commit message validation passed"
    exit 0
else
    log_message "ERROR" "Commit message validation failed: $COMMIT_SUBJECT"
    # ... error message ...
    exit 1
fi
```

**Features:**
- Custom regex pattern
- Skips merge and revert commits
- Custom error messages
- Logging to file
- Checks description length (3-100 characters)
- Supports breaking change marker (`!`)

### Pre-commit Framework Implementation

**`.pre-commit-config.yaml` (lines 98-103):**
```yaml
# Commit message validation
- repo: https://github.com/commitizen-tools/commitizen
  rev: v3.12.0
  hooks:
    - id: commitizen
      stages: [commit-msg]
```

**Features (from commitizen):**
- Standard Conventional Commits parser
- Configurable via `pyproject.toml`
- More extensive validation
- Better error messages
- Supports all Conventional Commits features

## Differences

| Feature | Manual Script | Commitizen |
|---------|---------------|------------|
| Regex Pattern | Custom | Standard |
| Merge commit skip | Yes | Automatic |
| Revert commit skip | Yes | Automatic |
| Breaking change (`!`) | Yes | Yes |
| Scope validation | Lowercase + hyphens | More flexible |
| Description length | 3-100 chars | Configurable |
| Configuration | Hardcoded | `pyproject.toml` |
| Error messages | Custom | Standard |
| Logging | Yes | No (pre-commit handles) |
| Maintenance | Manual | Auto-updates |

## Configuration

**`pyproject.toml` (commitizen config):**
```toml
[tool.commitizen]
name = "cz_conventional_commits"
version = "1.0.0"
tag_format = "v$version"
```

This is minimal configuration. Commitizen uses defaults for:
- Allowed types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
- Scope rules: Optional
- Description rules: Non-empty

## Current Status

**Neither is active** because:
1. Manual hook not installed in `.git/hooks/`
2. Pre-commit framework not installed

If both were installed:
- Both would run on every commit
- Duplicate validation
- Potentially conflicting results if patterns differ
- Performance impact (minimal but unnecessary)

## Impact

- **Severity:** Low (neither is currently running)
- **When active:** Duplicate validation on every commit
- **Maintenance:** Must update two implementations
- **Consistency risk:** Patterns could diverge
- **Confusion:** Which one is authoritative?

## Recommended Actions

### Option 1: Use Commitizen Only (Recommended)

**Remove manual implementation:**
1. Delete `hooks/commit-msg` or remove validation logic
2. Keep only pre-commit framework commitizen hook
3. Configure commitizen in `pyproject.toml` for custom rules

**Benefits:**
- Industry standard tool
- Better maintained
- More features
- Configuration-driven
- Auto-updates via pre-commit

**Configuration:**
```toml
# pyproject.toml
[tool.commitizen]
name = "cz_conventional_commits"
version = "1.0.0"
tag_format = "v$version"

# Customize rules
[tool.commitizen.customize]
message_template = "{{type}}({{scope}}): {{subject}}\n\n{{body}}\n\n{{footer}}"
schema = """
<type>(<scope>): <subject>

<body>

<footer>
"""

# Custom types (if needed)
[[tool.commitizen.customize.questions]]
type = "list"
name = "type"
message = "Select the type of change you are committing"
choices = [
    {value = "feat", name = "feat: A new feature"},
    {value = "fix", name = "fix: A bug fix"},
    {value = "docs", name = "docs: Documentation changes"},
    {value = "style", name = "style: Code style changes"},
    {value = "refactor", name = "refactor: Code refactoring"},
    {value = "test", name = "test: Adding tests"},
    {value = "chore", name = "chore: Maintenance tasks"},
]
```

### Option 2: Keep Manual Script Only

**Remove commitizen from `.pre-commit-config.yaml`:**
```yaml
# Remove:
- repo: https://github.com/commitizen-tools/commitizen
  rev: v3.12.0
  hooks:
    - id: commitizen
      stages: [commit-msg]
```

**Benefits:**
- No Python dependency for commit-msg validation
- Works in minimal environments
- Direct control over error messages

**Cons:**
- Must maintain custom regex
- Loses commitizen features
- Manual updates
- Reinventing the wheel

### Option 3: Manual Script as Fallback

Keep both but make manual script a fallback:

```bash
#!/bin/sh
# hooks/commit-msg

# Try commitizen first (if pre-commit is installed)
if command -v pre-commit >/dev/null 2>&1; then
    pre-commit run commitizen --hook-stage commit-msg --commit-msg-filename "$1"
    exit $?
fi

# Fallback to manual validation if commitizen not available
# ... existing validation logic ...
```

**Benefits:**
- Uses commitizen when available
- Falls back gracefully
- Works in all environments

**Cons:**
- Still need to maintain two implementations
- More complex logic

## Consistency Check

**Manual pattern:**
```regex
^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([a-z0-9\-]+\))?!?: .{3,100}$
```

**Commitizen pattern (from spec):**
```
^(?P<type>\w+)(\((?P<scope>[\w\-]+)\))?(?P<breaking>!)?:\s+(?P<subject>.+)$
```

**Differences:**
- Manual: Restricts types to specific list
- Commitizen: Any word character sequence (more flexible)
- Manual: Description 3-100 characters
- Commitizen: Any non-empty (configurable)
- Manual: Scope must be lowercase with hyphens
- Commitizen: Scope can be any word character or hyphen

**Which is stricter?**
- Manual script is stricter (limited types, lowercase scope)
- Commitizen more flexible (configurable)

## Migration Path

1. **Document current behavior** in git log:
   ```bash
   git log --oneline | head -50
   # Review commit message formats currently used
   ```

2. **Choose commitizen as standard:**
   ```bash
   # Install and configure
   pip install commitizen
   pre-commit install --hook-type commit-msg
   ```

3. **Test validation:**
   ```bash
   # Valid commit
   git commit --allow-empty -m "feat: test commit message validation"

   # Invalid commit (should fail)
   git commit --allow-empty -m "Invalid commit message"
   ```

4. **Remove manual hook:**
   ```bash
   rm hooks/commit-msg
   # Or keep as fallback with modification
   ```

5. **Update documentation:**
   - `docs/guides/git-hooks.md`: Document commitizen usage
   - Remove references to manual commit-msg validation

## References

- `hooks/commit-msg` (lines 36-82: Manual validation)
- `.pre-commit-config.yaml` (lines 98-103: Commitizen config)
- `pyproject.toml`: Commitizen configuration
- [Conventional Commits Spec](https://www.conventionalcommits.org/)
- [Commitizen Documentation](https://commitizen-tools.github.io/commitizen/)

## Related Issues

- #001: Git Hooks Not Installed (neither validation is active)
- #002: Pre-commit Framework Not Installed (commitizen not available)
- #003: Dual Hook Management System
