# Issue: Git Hooks Log to Repository Directory

**Priority:** Low
**Type:** Design
**Component:** Git Hooks, Logging

## Description

All git hooks write logs to `$REPO_ROOT/logs/git-hooks_<date>.log`, which places log files inside the repository working directory. This can clutter the repository and may accidentally get committed.

## Evidence

**All hooks create logs in the same location:**

**`hooks/pre-commit` (lines 7-9):**
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/git-hooks_$(date +%Y-%m-%d).log"
```

**Same pattern in:**
- `hooks/commit-msg` (lines 7-9)
- `hooks/pre-push` (lines 7-9)
- `hooks/post-checkout` (lines 7-9)
- `hooks/post-commit` (lines 7-9)
- `hooks/post-merge` (lines 7-9)

**Log file naming:**
```
logs/git-hooks_2025-12-08.log
```
All hooks append to the same daily log file.

## Current Behavior

**On every hook execution:**
1. Creates `logs/` directory if missing (line 14 in each hook)
2. Appends log entry to `git-hooks_<date>.log`
3. Log format: `[timestamp timezone] [level] [hook-name] [hostname] [pid] message`

**Example log entry:**
```
[2025-12-08 18:34:12 UTC] [INFO] [pre-commit] [hostname] [12345] Pre-commit hook started
[2025-12-08 18:34:12 UTC] [INFO] [pre-commit] [hostname] [12345] Checking for debug statements...
[2025-12-08 18:34:13 UTC] [INFO] [pre-commit] [hostname] [12345] Pre-commit checks passed
```

## Issues with Current Approach

### 1. Repository Pollution
- `logs/` directory sits in working tree
- Can be accidentally staged and committed
- Developers may have different log files locally
- Merge conflicts possible if logs are committed

### 2. Git Status Noise
If `logs/` is not in `.gitignore`:
```bash
$ git status
Untracked files:
  logs/git-hooks_2025-12-08.log
```

### 3. No Log Rotation
- Daily log files accumulate indefinitely
- No automatic cleanup
- Can grow large over time
- No size limits enforced

### 4. Mixed Concerns
PowerShell scripts also log, but to different location:
- Shell hooks: `$REPO_ROOT/logs/`
- PowerShell scripts: `$STAGING_MIRROR/logs/` (from config)

## Verification

**Check if logs directory is ignored:**
```bash
$ git check-ignore logs/
# If no output, logs/ is NOT ignored
```

**Check .gitignore:**
```bash
$ grep -r "^logs/$" .gitignore
# Should return matches if properly ignored
```

## Impact

- **Severity:** Low
- Minor inconvenience if logs are ignored
- Potential repository clutter if not ignored
- Inconsistent logging locations
- No centralized log management

## Recommended Actions

### 1. Verify logs/ is in .gitignore

**Check:**
```bash
$ cat .gitignore | grep logs
```

**If missing, add:**
```gitignore
# Git hook logs
logs/
```

### 2. Use System Log Directory (Preferred)

Move logs outside the repository:

**Linux/macOS:**
```bash
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/my-scripts/git-hooks"
LOG_FILE="$LOG_DIR/git-hooks_$(date +%Y-%m-%d).log"
```

**Windows (Git Bash):**
```bash
LOG_DIR="$HOME/AppData/Local/MyScripts/git-hooks"
LOG_FILE="$LOG_DIR/git-hooks_$(date +%Y-%m-%d).log"
```

**Benefits:**
- Logs outside working tree
- Won't clutter repository
- Standard system locations
- Per-user logs

### 3. Make Logging Optional

Add environment variable to disable logging:
```bash
# Only log if explicitly enabled
if [ "${GIT_HOOKS_LOGGING:-0}" = "1" ]; then
    log_message() {
        # ... logging code ...
    }
else
    log_message() { :; }  # No-op
fi
```

Enable with:
```bash
export GIT_HOOKS_LOGGING=1
```

### 4. Implement Log Rotation

Add to hooks:
```bash
# Keep only last 7 days of logs
find "$LOG_DIR" -name "git-hooks_*.log" -mtime +7 -delete 2>/dev/null
```

Or:
```bash
# Keep only last 10 log files
ls -t "$LOG_DIR"/git-hooks_*.log | tail -n +11 | xargs rm -f 2>/dev/null
```

### 5. Centralize Logging Configuration

Create `hooks/lib/logging.sh`:
```bash
#!/bin/bash
# Shared logging configuration for all hooks

# Determine log directory
if [ -n "$GIT_HOOKS_LOG_DIR" ]; then
    LOG_DIR="$GIT_HOOKS_LOG_DIR"
elif [ -w "/var/log" ]; then
    LOG_DIR="/var/log/git-hooks"
else
    LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/my-scripts/git-hooks"
fi

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null

# Log file with rotation
LOG_FILE="$LOG_DIR/git-hooks_$(date +%Y-%m-%d).log"

# Log function
log_message() {
    local level=$1
    local hook=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local timezone=$(date +%Z)
    echo "[$timestamp $timezone] [$level] [$hook] [$(hostname)] [$$] $message" >> "$LOG_FILE"
}

# Rotate old logs (keep 7 days)
find "$LOG_DIR" -name "git-hooks_*.log" -mtime +7 -delete 2>/dev/null
```

**Source in each hook:**
```bash
#!/bin/sh
# Source shared logging configuration
. "$(git rev-parse --show-toplevel)/hooks/lib/logging.sh"

log_message "INFO" "pre-commit" "Hook started"
```

### 6. Use Structured Logging

Consider JSON format for better parsing:
```bash
log_message() {
    local level=$1
    local message=$2
    cat >> "$LOG_FILE" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","level":"$level","hook":"$HOOK_NAME","hostname":"$(hostname)","pid":$$,"message":"$message"}
EOF
}
```

**Benefits:**
- Easy to parse
- Machine-readable
- Structured querying

### 7. Document Logging Behavior

Add to `docs/guides/git-hooks.md`:
```markdown
## Logging

Git hooks write execution logs to track operations and debug issues.

### Log Location

**Default:** `~/.local/state/my-scripts/git-hooks/git-hooks_<date>.log`

**Custom location:**
```bash
export GIT_HOOKS_LOG_DIR="/path/to/logs"
```

**Disable logging:**
```bash
export GIT_HOOKS_LOGGING=0
```

### Log Retention

Logs are automatically rotated, keeping the last 7 days.

### Log Format

```
[timestamp timezone] [level] [hook] [hostname] [pid] message
```

Example:
```
[2025-12-08 18:34:12 UTC] [INFO] [pre-commit] [hostname] [12345] Pre-commit hook started
```
```

## Comparison: Repository vs System Logs

| Location | Pros | Cons |
|----------|------|------|
| `$REPO_ROOT/logs/` | Easy to find, Near code | Clutters repo, In git status, Need .gitignore |
| `~/.local/state/...` | Clean repo, Standard location, Per-user | Harder to find, Need to document |
| `/var/log/...` | System standard, Centralized | Needs permissions, Not per-user |
| Disabled | No clutter, Fastest | No debugging, No audit trail |

## Current Protection Status

**Need to verify:**
```bash
$ git check-ignore logs/
$ cat .gitignore | grep logs
```

If `logs/` is already in `.gitignore`, impact is minimal (low priority).
If not, this is a higher priority issue.

## References

- All hooks in `/hooks` directory (lines 7-9 in each: LOG_DIR definition)
- `src/powershell/git/Invoke-PostCommitHook.ps1` (lines 87-90: Different log location)
- `src/powershell/git/Invoke-PostMergeHook.ps1` (lines 87-90: Different log location)

## Related Issues

- #005: Platform Compatibility (different log paths per platform)
- #010: PowerShell Scripts Use Different Logging Location
