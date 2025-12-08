# Issue: PowerShell Linting Explicitly Disabled in Pre-commit Hook

**Priority:** Medium
**Type:** Code Quality
**Component:** Git Hooks (pre-commit)

## Description

The manual pre-commit hook (`hooks/pre-commit`) contains code to lint PowerShell files with PSScriptAnalyzer, but this functionality is **explicitly disabled** with a comment stating it's skipped due to "temp file issues" and will be "handled by CI".

## Evidence

**`hooks/pre-commit` (lines 77-97):**
```bash
if [ -n "$CHANGED_PS_FILES" ]; then
    log_message "INFO" "Found PowerShell files to lint: $(echo $CHANGED_PS_FILES | wc -l) file(s)"

    if command -v pwsh >/dev/null 2>&1; then
        echo "Linting PowerShell files..."
        log_message "INFO" "Running PSScriptAnalyzer on PowerShell files"

        # Skip PowerShell linting in pre-commit hook due to temp file issues
        # PowerShell linting will be handled by CI workflows
        log_message "INFO" "Skipping PowerShell linting in pre-commit hook (handled by CI)"
        echo "PowerShell linting skipped (will be checked in CI)"
        PS_EXIT_CODE=0

        if [ $PS_EXIT_CODE -ne 0 ]; then
            log_message "ERROR" "PowerShell linting failed"
            echo "ERROR: PowerShell linting failed. Please fix the issues above before committing."
            CHECKS_FAILED=1
        else
            log_message "INFO" "PowerShell linting passed"
        fi
    else
        log_message "WARNING" "PowerShell (pwsh) not found. Skipping PowerShell linting."
        echo "WARNING: PowerShell (pwsh) not found. Skipping PowerShell linting."
    fi
fi
```

**Analysis:**
- Lines 82-84: PowerShell linting is skipped unconditionally
- `PS_EXIT_CODE=0` hardcoded (always success)
- Comment mentions "temp file issues" but provides no details
- Defers to CI workflows for PowerShell validation

## Pre-commit Framework Configuration

**`.pre-commit-config.yaml` (lines 71-86):**
```yaml
# PowerShell hooks - Disabled for pre-commit (environment-specific)
# PowerShell linting still runs in CI via sonarcloud.yml workflow
# - repo: local
#   hooks:
#     - id: psscriptanalyzer
#       name: PSScriptAnalyzer
#       entry: pwsh -Command "Invoke-ScriptAnalyzer -Path"
#       language: system
#       files: \.ps1$
#       args: ['-Severity', 'Error']
#     - id: powershell-format
#       name: Format PowerShell
#       entry: pwsh scripts/Format-PowerShellCode.ps1 -Check
#       language: system
#       files: \.(ps1|psm1)$
#       pass_filenames: false
```

**Analysis:**
- PowerShell hooks are commented out
- Reason: "environment-specific"
- Also defers to CI (sonarcloud.yml)

## Impact

**Positive:**
- Avoids hook failures if PSScriptAnalyzer not installed
- Prevents "temp file issues" (whatever those are)
- Faster local commits

**Negative:**
- PowerShell code quality not validated locally
- Developers find out about issues only after pushing to CI
- Slower feedback loop
- More failed CI builds
- Inconsistent with Python linting (which runs locally)

## Root Cause Analysis

**Possible "temp file issues":**

1. **PSScriptAnalyzer file path handling**: PSScriptAnalyzer may have issues with:
   - Symbolic links
   - Temporary Git staging area files
   - Non-standard file paths during Git operations

2. **Environment-specific installations**: PSScriptAnalyzer module might not be:
   - Installed on all developer machines
   - Available in the same location across platforms
   - Compatible with all PowerShell versions

3. **Performance**: PSScriptAnalyzer can be slow on large files

4. **Git worktree issues**: During pre-commit, Git uses a temporary staging area that may confuse PSScriptAnalyzer

## Documentation References

**`docs/guides/git-hooks.md` (lines 196-220):**
Documents PSScriptAnalyzer hook but acknowledges it's disabled:
```markdown
#### **PSScriptAnalyzer**

- PowerShell linting tool
- Checks for syntax errors and best practices
- Configured to show errors only (`-Severity Error`)
- Requires PowerShell 7+ (`pwsh`)

**Hook definition:**
```yaml
- repo: local
  hooks:
    - id: psscriptanalyzer
      name: PSScriptAnalyzer
      entry: pwsh -Command "Invoke-ScriptAnalyzer -Path"
      language: system
      files: \.ps1$
      args: ["-Severity", "Error"]
```

**Auto-installation:**
The pre-commit hook will attempt to install PSScriptAnalyzer if missing.
```

This documentation is **misleading** because:
- It suggests PSScriptAnalyzer runs in pre-commit
- It claims "auto-installation" which doesn't exist in the code
- Doesn't mention it's actually disabled

## CI Implementation

Need to verify if CI actually runs PSScriptAnalyzer:
```bash
$ grep -r "PSScriptAnalyzer" .github/workflows/ 2>/dev/null
# Check sonarcloud.yml or other workflows
```

## Recommended Actions

### Option 1: Fix and Re-enable PowerShell Linting (Recommended)

**Diagnose the issue:**
1. Test PSScriptAnalyzer with Git staged files
2. Identify specific "temp file issues"
3. Implement workaround

**Possible solutions:**
```bash
# Instead of linting staged files directly, copy to temp location
CHANGED_PS_FILES=$(echo "$STAGED_FILES" | grep '\.ps1$' || true)

if [ -n "$CHANGED_PS_FILES" ]; then
    # Create temp directory for linting
    TEMP_DIR=$(mktemp -d)

    # Copy staged versions to temp directory
    for file in $CHANGED_PS_FILES; do
        mkdir -p "$TEMP_DIR/$(dirname "$file")"
        git show ":$file" > "$TEMP_DIR/$file"
    done

    # Lint from temp directory
    cd "$TEMP_DIR"
    pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error"
    EXIT_CODE=$?
    cd -

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ $EXIT_CODE -ne 0 ]; then
        echo "PowerShell linting failed"
        exit 1
    fi
fi
```

**Enable in pre-commit framework:**
```yaml
- repo: local
  hooks:
    - id: psscriptanalyzer
      name: PSScriptAnalyzer
      entry: bash -c 'for file in "$@"; do pwsh -Command "Invoke-ScriptAnalyzer -Path \"$file\" -Severity Error"; done'
      language: system
      files: \.ps1$
      pass_filenames: true
```

### Option 2: Make It Optional But Available

Allow developers to opt-in:
```bash
# Check for environment variable to enable PowerShell linting
if [ "$ENABLE_PS_LINTING" = "1" ]; then
    # Run PSScriptAnalyzer
else
    echo "PowerShell linting disabled (set ENABLE_PS_LINTING=1 to enable)"
fi
```

Developers who want it:
```bash
export ENABLE_PS_LINTING=1
git commit -m "..."
```

### Option 3: Document the Limitation Honestly

Update documentation to clarify:
```markdown
### PowerShell Linting

**Status:** Disabled in local pre-commit hooks due to compatibility issues with Git staging area

**Why disabled:**
- PSScriptAnalyzer has issues with temporary files during Git operations
- Not all developers have PowerShell/PSScriptAnalyzer installed
- Performance impact on large repositories

**Current approach:**
- PowerShell linting runs in CI via GitHub Actions
- Developers are encouraged to run PSScriptAnalyzer manually:
  ```powershell
  Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
  ```

**To enable locally (experimental):**
- Set `ENABLE_PS_LINTING=1` environment variable
- Ensure PSScriptAnalyzer module is installed:
  ```powershell
  Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
  ```
```

### Option 4: Use Pre-commit's Built-in PSScriptAnalyzer Support

Check if there's a pre-commit hook repository for PSScriptAnalyzer:
```yaml
# Research if this exists:
- repo: https://github.com/some-org/pre-commit-powershell
  rev: v1.0.0
  hooks:
    - id: psscriptanalyzer
```

## Inconsistency with Python Linting

**Python linting (pylint)** runs locally in the same pre-commit hook:
- Lines 106-143 in `hooks/pre-commit`
- Full linting with `--errors-only` mode
- Works without "temp file issues"

**Why does Python work but PowerShell doesn't?**

Possible reasons:
- `pylint` accepts file paths directly
- PSScriptAnalyzer may use different file handling
- Different behavior with Git's staging mechanism

**Consistency goal:**
Either both should run locally, or both should defer to CI. Current setup is inconsistent.

## Testing the Fix

```bash
# Create test PowerShell file with intentional error
cat > test.ps1 << 'EOF'
function Test-Function {
    Write-Host "test"  # PSScriptAnalyzer warning
    $unused = "variable"  # Unused variable
}
EOF

# Stage it
git add test.ps1

# Try to commit (should trigger linting if enabled)
git commit -m "test: verify powershell linting"

# Expected: Hook should catch issues
# Actual: Hook skips linting
```

## References

- `hooks/pre-commit` (lines 77-97: PowerShell linting section)
- `.pre-commit-config.yaml` (lines 71-86: Commented PowerShell hooks)
- `docs/guides/git-hooks.md` (lines 196-220: Misleading documentation)

## Related Issues

- #003: Dual Hook Management System
- #005: Platform Compatibility Issues
- #006: Missing Dependencies (PowerShell)
