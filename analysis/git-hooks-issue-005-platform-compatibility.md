# Issue: Platform-Specific Code Limits Portability

**Priority:** Medium
**Type:** Compatibility
**Component:** Git Hooks, PowerShell Scripts

## Description

The git hooks and associated PowerShell scripts contain platform-specific code that limits portability across different operating systems (Linux, macOS, Windows).

## Evidence

### 1. Shell Script Issues

**`hooks/pre-commit` (lines 148-149)**
```bash
size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
```

- `stat -f%z` is BSD/macOS syntax
- `stat -c%s` is GNU/Linux syntax
- Fallback works but is fragile

### 2. PowerShell Scripts Are Windows-Centric

**`src/powershell/git/Invoke-PostCommitHook.ps1`**
- Lines 56-57: Converts Unix paths to Windows: `$script:RepoPath = $script:RepoPath -replace '/', '\'`
- Lines 60, 106: Uses Windows path separators: `config\local-deployment-config.json`, `config\modules\deployment.txt`
- Lines 353-354: Hardcoded Windows module paths:
  - `C:\Program Files\WindowsPowerShell\Modules\User`
  - `%USERPROFILE%\Documents\WindowsPowerShell\Modules`

**`src/powershell/git/Invoke-PostMergeHook.ps1`**
- Same Windows-specific path handling
- Lines 321-322: Hardcoded Windows paths for System/User module deployment

### 3. PowerShell Availability

**Shell hooks check for `pwsh`:**
```bash
if ! command -v pwsh >/dev/null 2>&1; then
    log_message "WARNING" "PowerShell (pwsh) not found. Skipping..."
    exit 0
fi
```

- Gracefully handles missing PowerShell
- But post-commit/post-merge automation won't work on systems without PowerShell Core

### 4. Git LFS Compatibility

Git LFS is cross-platform, but:
- Not installed in current environment
- Hooks assume it's available
- No fallback for environments without LFS

## Impact

- **Severity:** Medium
- **Shell scripts**: Mostly portable (with fallbacks)
- **PowerShell scripts**: Windows-only features will fail on Linux/macOS
- **Developer friction**: Contributors on different platforms may have inconsistent experience
- **Module deployment**: Only works on Windows with specific directory structure

## Platform-Specific Features

### Works Cross-Platform
- Git operations (git diff, git status, etc.)
- Logging to files
- Basic file operations (copy, delete)
- Git LFS (when installed)

### Windows-Only
- PowerShell module deployment to Windows module paths
- Windows-specific path handling (`\` separators)
- `WindowsPowerShell\Modules` directory structure

### Platform-Specific Implementations
- `stat` command (different flags per platform)
- File permission handling
- Line endings (CRLF vs LF)

## Recommended Actions

### 1. Document Platform Requirements

Create `docs/platform-requirements.md`:
```markdown
# Platform Requirements

## Full Functionality (All Hooks)
- **OS:** Windows 10/11 or Windows Server
- **PowerShell:** 7.0+ (Core)
- **Git:** 2.9+
- **Git LFS:** 2.0+
- **Python:** 3.7+ (for pre-commit framework)

## Limited Functionality (No Module Deployment)
- **OS:** Linux, macOS, or WSL
- **Git:** 2.9+
- **Python:** 3.7+ (for pre-commit framework)
- **Note:** PowerShell module deployment will be skipped

## Minimum (No Hooks)
- **Git:** Any version
- Commit without hooks using `git commit --no-verify`
```

### 2. Make PowerShell Scripts More Portable

**Option A:** Detect platform and adapt
```powershell
if ($IsWindows) {
    $moduleBasePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
} elseif ($IsLinux -or $IsMacOS) {
    $moduleBasePath = "$HOME/.local/share/powershell/Modules"
}
```

**Option B:** Make module deployment optional
```powershell
# Check if on Windows before attempting Windows-specific deployment
if (-not $IsWindows) {
    Write-Message "Module deployment skipped (Windows-only feature)"
    # Still mirror files to staging directory
}
```

### 3. Improve stat Command Portability

Replace in `hooks/pre-commit`:
```bash
# Current (fragile)
size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)

# Better (use find)
size=$(find "$file" -printf "%s" 2>/dev/null || stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)

# Best (use wc if file is accessible)
if [ -f "$file" ]; then
    size=$(wc -c < "$file" 2>/dev/null || echo 0)
else
    size=0
fi
```

### 4. Add Platform Detection to Hooks

Add to shell script hooks:
```bash
# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
else
    PLATFORM="unknown"
fi

log_message "INFO" "Platform detected: $PLATFORM"
```

### 5. Consider Alternative to Module Deployment

For cross-platform consistency:
- Use a containerized deployment approach
- Deploy modules via package manager (PowerShell Gallery)
- Use symbolic links instead of copying files
- Skip Windows-specific paths on non-Windows systems

### 6. Add Platform-Specific Tests

Create test scripts:
- `tests/hooks/test-linux.sh`
- `tests/hooks/test-macos.sh`
- `tests/hooks/test-windows.sh`

Run in CI for each platform.

## Current Platform Support Matrix

| Feature | Windows | Linux | macOS |
|---------|---------|-------|-------|
| Shell hooks | ✓ | ✓ | ✓ |
| Pre-commit framework | ✓ | ✓ | ✓ |
| Python linting | ✓ | ✓ | ✓ |
| PowerShell linting | ✓ | ✓ | ✓ |
| Git LFS | ✓ | ✓ | ✓ |
| Module deployment | ✓ | ✗ | ✗ |
| File mirroring | ✓ | Partial | Partial |

## References

- `hooks/pre-commit` (line 149: stat command)
- `src/powershell/git/Invoke-PostCommitHook.ps1` (lines 56-57, 353-354)
- `src/powershell/git/Invoke-PostMergeHook.ps1` (lines 321-322)
- `.gitattributes` (lines 3-4: CRLF for PowerShell files)

## Related Issues

- #006: Missing Dependencies (Git LFS, PowerShell)
- #008: PowerShell Scripts Reference Windows-Specific Paths
