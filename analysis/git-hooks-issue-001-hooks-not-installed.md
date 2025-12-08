# Issue: Git Hooks Not Installed

**Priority:** Critical
**Type:** Configuration
**Component:** Git Hooks

## Description

The git hooks defined in the `/hooks` directory are not actually installed in the repository. The `.git/hooks/` directory only contains sample files provided by Git, meaning none of the custom hooks are active.

## Evidence

```bash
$ ls -la .git/hooks/ | grep -v sample
# Returns only sample files - no active hooks
```

The repository has 6 custom hooks in `/hooks`:
- commit-msg
- post-checkout
- post-commit
- post-merge
- pre-commit
- pre-push

However, none of these are installed in `.git/hooks/` where Git expects them.

## Impact

- **Severity:** Critical
- No commit validation is occurring (conventional commits format not enforced)
- No pre-commit linting or validation
- No Git LFS operations are being triggered
- No PowerShell automation scripts are running post-commit/post-merge
- Developers may commit code that violates repository standards

## Root Cause

Hooks need to be either:
1. Copied or symlinked from `/hooks` to `.git/hooks/`, OR
2. Installed via the pre-commit framework using `scripts/install-hooks.sh`

The `.git/hooks/` directory is not tracked by Git (it's in `.gitignore` by default), so hooks must be installed locally by each developer.

## Recommended Actions

1. **Document installation process** - Ensure README or CONTRIBUTING guide clearly states developers must run `scripts/install-hooks.sh` after cloning
2. **Automated verification** - Add a CI check to verify hooks are properly configured
3. **Consider git config** - Use `git config core.hooksPath hooks` to point Git directly to the `/hooks` directory (requires Git 2.9+)
4. **Choose single system** - Decide between manual hooks and pre-commit framework (see issue #003)

## References

- `/hooks` directory
- `scripts/install-hooks.sh`
- `.git/hooks/` directory
- `docs/guides/git-hooks.md`

## Related Issues

- #002: Pre-commit Framework Not Installed
- #003: Dual Hook Management System
- #004: Hook File Permissions Issue
