# Issue: Incorrect File Permissions on Git Hooks

**Priority:** Medium
**Type:** Configuration
**Component:** Git Hooks

## Description

Some git hook files in the `/hooks` directory lack executable permissions, which would prevent them from running even if properly installed.

## Evidence

```bash
$ ls -la hooks/
-rwxr-xr-x  1 root root 2782 Dec  8 16:35 commit-msg       # Executable ✓
-rw-r--r--  1 root root 1917 Dec  8 16:35 post-checkout    # NOT Executable ✗
-rwxr-xr-x  1 root root 1952 Dec  8 16:35 post-commit      # Executable ✓
-rwxr-xr-x  1 root root 1937 Dec  8 16:35 post-merge       # Executable ✓
-rwxr-xr-x  1 root root 6321 Dec  8 16:35 pre-commit       # Executable ✓
-rw-r--r--  1 root root 1515 Dec  8 16:35 pre-push         # NOT Executable ✗
```

## Affected Hooks

1. **post-checkout** - Missing execute permissions
   - Handles Git LFS post-checkout operations
   - Downloads LFS objects after branch checkout

2. **pre-push** - Missing execute permissions
   - Handles Git LFS pre-push operations
   - Uploads LFS objects before push

## Impact

- **Severity:** Medium
- If these hooks were installed in `.git/hooks/`, they would fail to execute
- Git LFS operations would not run automatically
- Large files might not be uploaded/downloaded properly
- Users would see "permission denied" errors

## Root Cause

Likely causes:
1. Files created/edited on Windows without setting executable bit
2. Files copied without preserving permissions
3. Git configuration not tracking executable bit (unlikely, as this is default)

## Verification

The executable bit IS tracked in Git:
```bash
$ git ls-files -s hooks/
100755 ... hooks/commit-msg
100644 ... hooks/post-checkout    # Should be 100755
100755 ... hooks/post-commit
100755 ... hooks/post-merge
100755 ... hooks/pre-commit
100644 ... hooks/pre-push          # Should be 100755
```

Git stores file mode `100644` (regular file) instead of `100755` (executable).

## Recommended Actions

1. **Add executable permissions:**
   ```bash
   chmod +x hooks/post-checkout
   chmod +x hooks/pre-push
   ```

2. **Commit the permission changes:**
   ```bash
   git add hooks/post-checkout hooks/pre-push
   git commit -m "fix(hooks): add executable permissions to post-checkout and pre-push"
   ```

3. **Verify Git tracks the change:**
   ```bash
   git diff --cached
   # Should show: old mode 100644 / new mode 100755
   ```

4. **Add verification to CI:**
   ```bash
   # .github/workflows/verify-hooks.yml
   - name: Verify hook permissions
     run: |
       for hook in hooks/*; do
         if [ -f "$hook" ] && ! [ -x "$hook" ]; then
           echo "ERROR: Hook $hook is not executable"
           exit 1
         fi
       done
   ```

5. **Update installation script:**
   Ensure `scripts/install-hooks.sh` sets permissions when installing:
   ```bash
   # When copying hooks
   cp hooks/* .git/hooks/
   chmod +x .git/hooks/*
   ```

## Git Configuration Note

Git's `core.fileMode` setting controls whether file permissions are tracked:
```bash
$ git config core.fileMode
true  # Should be true to track executable bit
```

If this is `false`, permissions won't be tracked in the repository.

## References

- `/hooks/post-checkout` (line 1: `#!/bin/sh` shebang present)
- `/hooks/pre-push` (line 1: `#!/bin/sh` shebang present)
- Both files have correct shebang but lack executable bit

## Resolution

**Status:** RESOLVED (as of commit 2c14c5d)

This issue was **automatically resolved** by the migration to the pre-commit framework system (PR #655, addressing issue #647).

### How It Was Resolved

The problematic hooks (`post-checkout` and `pre-push`) were removed entirely when the repository migrated from manual git hooks to the pre-commit framework:

- **Commit:** 874c5d9 - "fix(hooks): migrate to single pre-commit framework system"
- **Merge:** 2c14c5d - Merged via PR #655
- **Date:** December 9, 2025

### Files Removed

The following hooks were deleted (no longer needed with pre-commit framework):
- `hooks/commit-msg` (82 lines removed)
- `hooks/post-checkout` (61 lines removed) - ✓ Had permission issue
- `hooks/pre-commit` (175 lines removed)
- `hooks/pre-push` (49 lines removed) - ✓ Had permission issue

### Current State

- **Remaining hooks:** `post-commit` and `post-merge` (PowerShell automation hooks)
- **Current permissions:** Both have correct executable permissions (755)
- **Git tracking:** Both tracked as executable (100755)
- **Hook management:** Standardized via `.pre-commit-config.yaml`

### Benefits of Migration

1. ✅ Eliminated permission issues (files no longer exist)
2. ✅ Standardized hook management via pre-commit framework
3. ✅ Automatic hook installation and updates
4. ✅ Consistent configuration across all environments
5. ✅ Built-in permission handling by pre-commit framework

## Related Issues

- #001: Git Hooks Not Installed
- #006: Missing Dependencies (Git LFS)
- #647: Dual Hook Management System Creates Confusion (resolved by migration)
