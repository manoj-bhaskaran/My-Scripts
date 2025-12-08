# Issue: Dual Hook Management System Creates Confusion

**Priority:** High
**Type:** Architecture
**Component:** Git Hooks

## Description

The repository uses TWO different hook management systems simultaneously, creating confusion, duplication, and potential conflicts:

1. **Manual shell script hooks** in `/hooks` directory
2. **Pre-commit framework** with `.pre-commit-config.yaml`

This dual system makes it unclear which hooks are authoritative and creates maintenance burden.

## Evidence

### Manual Hooks (`/hooks` directory)

**pre-commit** (shell script):
- Debug statement detection
- PowerShell linting (PSScriptAnalyzer) - **BUT EXPLICITLY SKIPPED** (lines 81-84)
- Python linting (pylint)
- Large file detection (>10MB)

### Pre-commit Framework (`.pre-commit-config.yaml`)

**pre-commit** (framework):
- Trailing whitespace
- End-of-file fixer
- YAML/JSON validation
- Large file detection (>5MB, different threshold!)
- Merge conflict detection
- Private key detection
- Black (Python formatter)
- Pylint (Python linter)
- Bandit (Python security)
- Mypy (Python type checking)
- Safety (dependency scanning)

**commit-msg** (framework):
- Commitizen (conventional commits)

### Conflicts and Duplication

1. **Python linting duplicated**: Both systems run pylint
2. **Large file detection duplicated**: Different thresholds (10MB vs 5MB)
3. **PowerShell linting disabled**: Manual pre-commit skips it "due to temp file issues"
4. **Manual commit-msg vs Commitizen**: `/hooks/commit-msg` validates conventional commits manually, `.pre-commit-config.yaml` uses commitizen

## Impact

- **Severity:** High
- **Confusion**: Developers unsure which system is active
- **Maintenance burden**: Must update hooks in two places
- **Performance**: Duplicate checks waste time
- **Inconsistency**: Different thresholds and rules
- **Reliability**: If one system fails, unclear which hooks ran

## Root Cause

The repository transitioned from manual hooks to pre-commit framework but didn't remove the old system. Documentation (`docs/guides/git-hooks.md`) mentions "legacy hooks" but they're still present and could be installed.

## Recommended Actions

### Option 1: Migrate Fully to Pre-commit Framework (Recommended)

**Pros:**
- Industry standard
- Better tooling and community support
- Automatic updates
- Language-agnostic
- Version-controlled configuration

**Steps:**
1. Remove manual hooks from `/hooks` directory (except post-commit/post-merge which call PowerShell)
2. Ensure all validation is in `.pre-commit-config.yaml`
3. Create custom local hooks for PowerShell integration if needed
4. Update documentation to reflect single system
5. Add `.git/hooks/` verification in CI

**PowerShell Hook Integration:**
```yaml
- repo: local
  hooks:
    - id: post-commit-powershell
      name: Post-commit PowerShell automation
      entry: hooks/post-commit.sh
      language: system
      stages: [post-commit]
      always_run: true
      pass_filenames: false
```

### Option 2: Use Manual Hooks Only

**Pros:**
- Simpler for non-Python environments
- No Python dependency
- Direct control

**Cons:**
- Loses pre-commit framework benefits
- More maintenance burden
- No auto-updates
- Reinventing the wheel

**Steps:**
1. Remove `.pre-commit-config.yaml`
2. Enhance manual hooks to include all checks
3. Create installation script to symlink/copy hooks
4. Document manual hook installation clearly

### Option 3: Hybrid (Not Recommended)

Keep both but clearly delineate:
- Pre-commit framework for language-specific linting
- Manual hooks for Git LFS and PowerShell integration

**Cons:**
- Still confusing
- Maintenance burden remains
- Duplication persists

## Proposed Solution

**Migrate to pre-commit framework** with these custom local hooks:

```yaml
# .pre-commit-config.yaml additions
repos:
  # ... existing hooks ...

  # Custom post-commit hook for PowerShell automation
  - repo: local
    hooks:
      - id: post-commit-deploy
        name: Post-commit module deployment
        entry: bash -c 'if command -v pwsh >/dev/null 2>&1; then pwsh -NoProfile -ExecutionPolicy Bypass -File src/powershell/git/Invoke-PostCommitHook.ps1; fi'
        language: system
        stages: [post-commit]
        always_run: true
        pass_filenames: false
        verbose: true
```

**Retain in `/hooks` only:**
- `post-commit` - PowerShell automation (not supported by pre-commit stages)
- `post-merge` - PowerShell automation (not supported by pre-commit stages)

**Remove from `/hooks`:**
- `pre-commit` - Migrate all checks to `.pre-commit-config.yaml`
- `commit-msg` - Already handled by commitizen in pre-commit
- `pre-push` - LFS handled by Git LFS install
- `post-checkout` - LFS handled by Git LFS install

## References

- `/hooks` directory
- `.pre-commit-config.yaml`
- `docs/guides/git-hooks.md` (lines 301-322: "Legacy Hooks" section)
- `hooks/pre-commit` (lines 81-84: PowerShell linting explicitly skipped)

## Related Issues

- #001: Git Hooks Not Installed
- #002: Pre-commit Framework Not Installed
- #007: PowerShell Linting Disabled in Pre-commit Hook
