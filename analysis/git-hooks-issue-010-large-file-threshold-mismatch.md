# Issue: Large File Detection Threshold Mismatch

**Priority:** Low
**Type:** Configuration Inconsistency
**Component:** Git Hooks (pre-commit)

## Description

Large file detection is implemented in two places with **different size thresholds**, creating inconsistent behavior:

1. **Manual pre-commit hook:** Warns at **>10MB**
2. **Pre-commit framework:** Warns at **>5MB** (5000KB)

This inconsistency could cause confusion when one system warns about a file and the other doesn't.

## Evidence

### Manual Hook: 10MB Threshold

**`hooks/pre-commit` (lines 145-162):**
```bash
# 4. Check for large files (>10MB)
log_message "INFO" "Checking for large files..."
LARGE_FILES=$(echo "$STAGED_FILES" | while read file; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        if [ "$size" -gt 10485760 ]; then  # 10MB = 10 * 1024 * 1024
            echo "$file ($(($size / 1048576))MB)"
        fi
    fi
done)

if [ -n "$LARGE_FILES" ]; then
    log_message "WARNING" "Large files detected in commit"
    echo "WARNING: The following large files (>10MB) are being committed:"
    echo "$LARGE_FILES"
    echo ""
    echo "Consider using Git LFS for large files or verify this is intentional."
fi
```

**Behavior:**
- Warning only (doesn't fail commit)
- Threshold: 10,485,760 bytes (10MB)
- Suggests using Git LFS
- Continues with commit

### Pre-commit Framework: 5MB Threshold

**`.pre-commit-config.yaml` (lines 13-14):**
```yaml
- id: check-added-large-files
  args: ["--maxkb=5000"]  # 5000KB = 5MB
```

**Behavior (from pre-commit-hooks):**
- Fails commit by default
- Threshold: 5,000,000 bytes (5MB)
- Standard pre-commit error message
- Prevents commit unless `--no-verify`

## Size Comparison

| Threshold | Bytes | Kilobytes | Megabytes |
|-----------|-------|-----------|-----------|
| Manual hook | 10,485,760 | 10,240 KB | 10 MB |
| Pre-commit framework | 5,120,000 | 5,000 KB | ~4.88 MB |
| **Difference** | **5,365,760** | **5,240 KB** | **~5.12 MB** |

**Gap:** Files between 5MB and 10MB would be:
- **Blocked** by pre-commit framework (if installed)
- **Allowed with warning** by manual hook (if installed)

## Scenarios

### Scenario 1: Both Hooks Active
```bash
# Try to commit a 7MB file
$ git add large-file.bin  # 7MB

$ git commit -m "feat: add large file"

# Pre-commit framework runs first:
ERROR: large-file.bin (7MB) exceeds 5MB limit

# Manual hook never runs (commit already aborted)
```

### Scenario 2: Only Manual Hook Active
```bash
# Try to commit a 7MB file
$ git commit -m "feat: add large file"

# Manual hook runs:
WARNING: The following large files (>10MB) are being committed:
# No output - file is under 10MB

# Commit succeeds with no warning
```

### Scenario 3: Only Pre-commit Framework Active
```bash
# Try to commit a 7MB file
$ git commit -m "feat: add large file"

# Pre-commit framework:
ERROR: large-file.bin (7MB) exceeds 5MB limit
# Commit fails
```

## Current Status

**Neither hook is active**, so no large file detection is currently working:
- Manual hook not installed in `.git/hooks/`
- Pre-commit framework not installed

## Git LFS Configuration

**`.gitattributes` (lines 5-8):**
```
*.sql filter=lfs diff=lfs merge=lfs -text
*.dump filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text
```

**These file types bypass the size check** because they're handled by Git LFS automatically.

## Impact

- **Severity:** Low
- **When active:** Inconsistent developer experience
- **Confusion:** Different warnings depending on which hook system is active
- **Protection gap:** Manual hook is more lenient
- **Documentation mismatch:** Docs should clarify threshold

## Recommended Actions

### Option 1: Align to Same Threshold (Recommended)

**Choose 5MB as standard:**

1. **Reasoning:**
   - More conservative (better protection)
   - GitHub has a 5MB warning anyway
   - Encourages LFS adoption earlier

2. **Update manual hook:**
   ```bash
   # Change line 150 in hooks/pre-commit
   if [ "$size" -gt 5242880 ]; then  # 5MB = 5 * 1024 * 1024
       echo "$file ($(($size / 1048576))MB)"
   fi
   ```

3. **Update warning message:**
   ```bash
   echo "WARNING: The following large files (>5MB) are being committed:"
   ```

4. **Consistency achieved:**
   - Both systems warn at 5MB
   - Clear developer experience
   - Aligns with pre-commit framework

**Alternative: Choose 10MB**
- Update `.pre-commit-config.yaml`: `args: ["--maxkb=10000"]`
- More permissive approach
- Reduces false positives

### Option 2: Make Manual Hook Also Fail (Not Just Warn)

Currently, manual hook warns but allows commit. Make it fail like pre-commit framework:

```bash
if [ -n "$LARGE_FILES" ]; then
    log_message "ERROR" "Large files detected in commit"
    echo "ERROR: The following large files (>5MB) are being committed:"
    echo "$LARGE_FILES"
    echo ""
    echo "Please use Git LFS for large files: git lfs track <pattern>"
    echo "Or bypass with: git commit --no-verify (not recommended)"
    CHECKS_FAILED=1  # This causes commit to fail
fi
```

### Option 3: Different Thresholds for Warning vs Error

**Tiered approach:**
- **5MB:** Warning (manual hook)
- **10MB:** Error (both hooks)

```bash
# Manual hook with tiered warnings
if [ "$size" -gt 10485760 ]; then
    # Over 10MB: Error
    echo "ERROR: $file ($(($size / 1048576))MB) - Exceeds 10MB limit"
    CHECKS_FAILED=1
elif [ "$size" -gt 5242880 ]; then
    # 5-10MB: Warning
    echo "WARNING: $file ($(($size / 1048576))MB) - Consider using Git LFS"
fi
```

Pre-commit framework:
```yaml
- id: check-added-large-files
  args: ["--maxkb=10000", "--enforce-all"]
```

### Option 4: Document the Difference

If keeping different thresholds is intentional, document it clearly:

**`docs/guides/git-hooks.md`:**
```markdown
## Large File Detection

Large files are checked with a tiered approach:

### Pre-commit Framework (Recommended)
- **Threshold:** 5MB (5000KB)
- **Action:** Blocks commit
- **Bypass:** `git commit --no-verify` (not recommended)
- **Reason:** Prevents repository bloat early

### Manual Hook (Fallback)
- **Threshold:** 10MB
- **Action:** Warning only
- **Reason:** More lenient for environments without pre-commit

### Git LFS Integration
Files matching these patterns are automatically handled by Git LFS:
- `*.sql`, `*.dump`, `*.mp4`, `*.zip`

### Best Practice
Use Git LFS for any file over 1MB:
```bash
git lfs track "*.bin"
git add .gitattributes
git commit -m "chore: track binary files with LFS"
```
```

## Comparison to GitHub Limits

**GitHub file size limits:**
- **Warning:** 50MB
- **Block:** 100MB
- **Recommendation:** Use LFS for files over 5MB

**Our limits:**
- Pre-commit: 5MB (matches GitHub recommendation)
- Manual: 10MB (still well under GitHub limits)

Both are well within GitHub's acceptable range.

## Testing

```bash
# Create test files of various sizes
dd if=/dev/zero of=test-4mb.bin bs=1M count=4   # 4MB
dd if=/dev/zero of=test-6mb.bin bs=1M count=6   # 6MB
dd if=/dev/zero of=test-12mb.bin bs=1M count=12 # 12MB

# Stage and try to commit
git add test-*.bin
git commit -m "test: verify large file detection"

# Expected behavior (with pre-commit framework):
# - test-4mb.bin: Pass
# - test-6mb.bin: Fail (over 5MB)
# - test-12mb.bin: Fail (over 5MB)

# Expected behavior (with manual hook only):
# - test-4mb.bin: Pass
# - test-6mb.bin: Pass with no warning (under 10MB)
# - test-12mb.bin: Fail with warning (over 10MB)
```

## Recommended Threshold

**5MB is recommended because:**
1. Aligns with GitHub's LFS recommendation
2. More conservative (prevents problems earlier)
3. Matches pre-commit framework default
4. Encourages LFS adoption
5. Repository stays leaner

## References

- `hooks/pre-commit` (lines 145-162: 10MB threshold)
- `.pre-commit-config.yaml` (lines 13-14: 5MB threshold)
- `.gitattributes` (lines 5-8: LFS file types)
- [GitHub File Size Limits](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)

## Related Issues

- #003: Dual Hook Management System
- #006: Missing Dependencies (Git LFS)
