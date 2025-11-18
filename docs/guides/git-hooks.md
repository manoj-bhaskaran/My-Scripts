# Git Hooks Guide

**Version:** 1.0.0
**Last Updated:** 2025-11-18

---

## Overview

This repository uses git hooks to enforce code quality and maintain consistency. Git hooks are scripts that run automatically at specific points in the Git workflow, helping catch issues before they're committed or pushed.

## Active Hooks

### 1. **pre-commit** - Code Quality Validation

Runs before a commit is created. Validates code quality and prevents commits with issues.

**What it checks:**

- **Debug Statements**: Detects debug code that shouldn't be committed
  - `Write-Debug` with TODO comments (PowerShell)
  - `print.*DEBUG` statements (Python)
  - `console.log` statements (JavaScript)
  - `debugger;` statements

- **PowerShell Linting**: Uses PSScriptAnalyzer to check `.ps1` files
  - Checks for syntax errors
  - Enforces PowerShell best practices
  - Detects potential bugs and issues
  - Requires: PowerShell 7+ (`pwsh`)

- **Python Linting**: Uses pylint to check `.py` files
  - Checks for syntax errors
  - Enforces PEP 8 style guidelines
  - Detects potential bugs
  - Falls back to basic syntax checking if pylint is unavailable

- **Large Files**: Warns about files >10MB
  - Suggests using Git LFS for large files
  - Does not block commits (warning only)

**Example output:**

```
Running pre-commit checks...
Linting PowerShell files...
Linting Python files...
Pre-commit checks passed!
```

**Location:** `hooks/pre-commit`

---

### 2. **commit-msg** - Conventional Commits Validation

Runs after you write a commit message. Enforces [Conventional Commits](https://www.conventionalcommits.org/) format.

**Required format:**

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Allowed types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring without behavior changes
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `perf`: Performance improvements
- `ci`: CI/CD pipeline changes
- `build`: Build system or external dependency changes
- `revert`: Reverting previous commits

**Scope** (optional): Lowercase with hyphens, describes the area affected (e.g., `logging`, `git-hooks`, `database`)

**Breaking changes**: Add `!` after type/scope:
```
feat(api)!: change authentication method
```

**Valid examples:**

```
feat(logging): add structured JSON output
fix: correct database connection timeout
docs(readme): update installation instructions
refactor(hooks)!: breaking change to hook system
test(validators): add unit tests for input validation
chore: update dependencies
```

**Invalid examples:**

```
Updated readme                    ❌ No type
FIX: bug in parser               ❌ Type must be lowercase
feat add new feature             ❌ Missing colon
feat(HOOKS): new hook            ❌ Scope must be lowercase
feat: x                          ❌ Description too short (<3 chars)
```

**Automatic exceptions:**

- Merge commits (starting with "Merge branch" or "Merge pull request")
- Revert commits (starting with "Revert ")

**Location:** `hooks/commit-msg`

---

### 3. **post-commit** - Post-Commit Automation

Runs after a commit is successfully created. Executes repository-specific automation.

**What it does:**

- Calls `src/powershell/Invoke-PostCommitHook.ps1`
- Mirrors committed files to staging directory
- Deploys PowerShell modules per configuration
- Logs all operations

**Requirements:**

- PowerShell 7+ (`pwsh`) on the system
- Configuration file: `config/module-deployment-config.txt`

**Behavior:**

- If PowerShell is not available, logs a warning and continues (non-blocking)
- If the PowerShell script fails, logs the error but doesn't block

**Location:** `hooks/post-commit`
**PowerShell script:** `src/powershell/Invoke-PostCommitHook.ps1`

---

### 4. **post-merge** - Post-Merge Automation

Runs after a successful merge. Similar to post-commit but for merge operations.

**What it does:**

- Calls `src/powershell/Invoke-PostMergeHook.ps1`
- Updates staging directory with merged changes
- Deploys updated modules
- Handles dependency updates
- Performs log rotation if needed

**Requirements:**

- PowerShell 7+ (`pwsh`) on the system
- Configuration file: `config/module-deployment-config.txt`

**Behavior:**

- Checks for unmerged paths and aborts if conflicts exist
- Uses `merge-base` for accurate change detection
- Falls back gracefully if PowerShell is unavailable

**Location:** `hooks/post-merge`
**PowerShell script:** `src/powershell/Invoke-PostMergeHook.ps1`

---

## Installation

### Initial Setup (New Clone)

After cloning the repository, install the hooks:

```bash
# Linux/macOS/Git Bash
./scripts/install-hooks.sh

# Windows PowerShell (if Bash not available)
pwsh -File scripts/install-hooks.ps1  # (if created)
```

### Updating Hooks

If hooks are updated in the repository, run the install script again:

```bash
./scripts/install-hooks.sh
```

The script will detect changes and update only modified hooks.

### Manual Installation

If the install script doesn't work, you can manually copy hooks:

```bash
# Linux/macOS/Git Bash
cp hooks/* .git/hooks/
chmod +x .git/hooks/*

# Windows
copy hooks\* .git\hooks\
```

---

## Bypassing Hooks

**⚠️ Use with caution!** Bypassing hooks should only be done in exceptional circumstances.

### When Bypassing is Acceptable

- **Emergency hotfixes**: Critical production fixes that need immediate deployment
- **Work in progress commits**: Experimental branches where you want to save work
- **Automated systems**: CI/CD pipelines or automated tools that generate commits
- **Temporary issues**: When linters have false positives (fix the linter afterward!)

### When Bypassing is NOT Acceptable

- ❌ "I don't want to fix the linting errors"
- ❌ "The commit message format is annoying"
- ❌ "I'm in a hurry"
- ❌ Regular development workflow

### How to Bypass

**Bypass pre-commit and commit-msg hooks:**

```bash
git commit --no-verify -m "fix: emergency hotfix"
# or shorter
git commit -n -m "fix: emergency hotfix"
```

**Bypass specific checks:** Not possible without `--no-verify`. The hooks are designed as an all-or-nothing enforcement.

### Best Practices

1. **Document why you bypassed**: Add a comment in the commit message
   ```bash
   git commit -n -m "fix: emergency database fix

   Bypassing hooks due to production outage.
   TODO: Run linters and fix issues in follow-up commit."
   ```

2. **Fix issues promptly**: If you bypass for work-in-progress, fix issues before merging

3. **Don't make it a habit**: If you're regularly bypassing hooks, something is wrong with the hooks or your workflow

---

## Logging

All git hooks log their execution to:

```
logs/git-hooks_YYYY-MM-DD.log
```

**Log format:**

```
[YYYY-MM-DD HH:MM:SS TIMEZONE] [LEVEL] [hook-name] [HOSTNAME] [PID] Message
```

**Example:**

```
[2025-11-18 14:30:45 UTC] [INFO] [pre-commit] [workstation] [12345] Pre-commit hook started
[2025-11-18 14:30:46 UTC] [INFO] [pre-commit] [workstation] [12345] Found PowerShell files to lint: 3 file(s)
[2025-11-18 14:30:48 UTC] [INFO] [pre-commit] [workstation] [12345] PowerShell linting passed
[2025-11-18 14:30:48 UTC] [INFO] [pre-commit] [workstation] [12345] Pre-commit checks passed
```

**Log levels:**

- **INFO**: Normal operations
- **WARNING**: Non-critical issues (e.g., linter not installed)
- **ERROR**: Critical failures (e.g., linting failed, commit blocked)

**Log retention:**

Logs follow the standard retention policy (30 days by default). See `docs/logging_specification.md` for details.

---

## Prerequisites

### Required

- **Git**: Version 2.0 or later
- **Bash/sh**: For running hooks (included with Git on Windows)

### Optional (for full functionality)

- **PowerShell 7+** (`pwsh`): Required for post-commit and post-merge hooks
  - Installation: [https://aka.ms/powershell](https://aka.ms/powershell)
  - Not required for pre-commit or commit-msg hooks

- **PSScriptAnalyzer**: PowerShell linting (auto-installed by pre-commit hook)
  ```powershell
  Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
  ```

- **Python 3+**: For Python linting
  - Linux/macOS: Usually pre-installed
  - Windows: [https://www.python.org/downloads/](https://www.python.org/downloads/)

- **pylint**: Python linting tool
  ```bash
  pip install pylint
  ```

### Cross-Platform Compatibility

All hooks are designed to work on:

- ✅ Linux
- ✅ macOS
- ✅ Windows (Git Bash, WSL, or PowerShell)

**Windows notes:**

- Use Git Bash or WSL for best compatibility
- PowerShell hooks (`post-commit`, `post-merge`) require PowerShell 7+ even on Windows
- Pre-commit and commit-msg hooks work in Git Bash without PowerShell

---

## Troubleshooting

### Hook Not Running

**Problem:** Hook doesn't execute when expected

**Solutions:**

1. Check if hooks are installed:
   ```bash
   ls -la .git/hooks/
   # Should show pre-commit, commit-msg, post-commit, post-merge
   ```

2. Check if hooks are executable:
   ```bash
   # Linux/macOS/Git Bash
   chmod +x .git/hooks/*
   ```

3. Re-run the install script:
   ```bash
   ./scripts/install-hooks.sh
   ```

---

### PowerShell Not Found

**Problem:** `WARNING: PowerShell (pwsh) not found`

**Impact:**

- `pre-commit`: PowerShell file linting will be skipped (warning only)
- `post-commit`/`post-merge`: Hooks will not run (warning logged, not blocking)

**Solution:**

Install PowerShell 7+:

- **Windows:** [https://aka.ms/powershell](https://aka.ms/powershell)
- **Linux:**
  ```bash
  # Ubuntu/Debian
  sudo apt-get install -y powershell

  # RHEL/CentOS
  sudo yum install -y powershell
  ```
- **macOS:**
  ```bash
  brew install --cask powershell
  ```

---

### PSScriptAnalyzer Not Found

**Problem:** PowerShell linting fails with module not found error

**Solution:**

The pre-commit hook attempts to auto-install PSScriptAnalyzer. If this fails:

```powershell
# Install manually
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable PSScriptAnalyzer
```

---

### Pylint Not Found

**Problem:** Python linting fails or falls back to syntax check

**Solution:**

```bash
# Install pylint
pip install pylint

# Verify installation
pylint --version
```

**Alternative:** If you don't want to install pylint, the hook will fall back to basic Python syntax checking using `python -m py_compile`.

---

### Commit Message Rejected

**Problem:** `ERROR: Commit message does not follow Conventional Commits format`

**Solution:**

1. Review your commit message format
2. Ensure it matches: `type(scope): description`
3. Use lowercase for type and scope
4. Ensure description is 3-100 characters
5. Use approved types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`

**Examples:**

```bash
# ✅ Correct
git commit -m "feat(hooks): add pre-commit linting"
git commit -m "fix: resolve database timeout issue"
git commit -m "docs: update git hooks documentation"

# ❌ Incorrect
git commit -m "Updated hooks"                    # Missing type
git commit -m "FIX: database issue"              # Uppercase type
git commit -m "feat(HOOKS): new feature"         # Uppercase scope
git commit -m "feat add hooks"                   # Missing colon
```

---

### Large File Warning

**Problem:** `WARNING: The following large files (>10MB) are being committed`

**This is a warning, not an error.** The commit will proceed.

**Recommendations:**

1. **Use Git LFS** for large files (videos, images, datasets):
   ```bash
   git lfs install
   git lfs track "*.mp4"
   git lfs track "*.zip"
   git add .gitattributes
   ```

2. **Verify intentional**: Make sure you meant to commit the large file

3. **Consider alternatives**: Could the file be:
   - Hosted externally (cloud storage)
   - Generated at build time
   - Excluded via `.gitignore`

---

### Hook Fails on Windows

**Problem:** Hook script errors on Windows

**Common causes:**

1. **Line endings**: Hooks have Unix line endings (LF)
   - Git usually handles this automatically
   - If issues persist, check `.gitattributes`

2. **Bash not available**:
   - Install Git for Windows (includes Git Bash)
   - Or use WSL (Windows Subsystem for Linux)

3. **PowerShell hooks on Windows**:
   - Ensure PowerShell 7+ is installed (not Windows PowerShell 5.1)
   - Run `pwsh --version` to verify

---

### Hook Logs Not Created

**Problem:** No log files in `logs/git-hooks_*.log`

**Solutions:**

1. Check if logs directory exists:
   ```bash
   ls -la logs/
   ```

2. Check permissions:
   ```bash
   # Ensure you have write permissions
   touch logs/test.log
   rm logs/test.log
   ```

3. Check hook execution:
   ```bash
   # Manually test a hook
   .git/hooks/pre-commit
   # Check if log was created
   cat logs/git-hooks_$(date +%Y-%m-%d).log
   ```

---

## Testing Hooks

### Test pre-commit Hook

```bash
# Create a test file with a debug statement
echo "console.log('DEBUG: test');" > test.js
git add test.js
git commit -m "test: debug statement"
# Should fail with error about debug statements

# Fix and retry
echo "console.log('Production ready');" > test.js
git add test.js
git commit -m "test: clean code"
# Should succeed
```

### Test commit-msg Hook

```bash
# Invalid format - should fail
git commit --allow-empty -m "Updated stuff"

# Valid format - should succeed
git commit --allow-empty -m "test: verify commit-msg hook"
```

### Test post-commit Hook

```bash
# Make a commit and check logs
git commit --allow-empty -m "test: verify post-commit hook"

# Check if hook ran
cat logs/git-hooks_$(date +%Y-%m-%d).log | grep post-commit

# If PowerShell is available, check if script executed
cat logs/post-commit-my-scripts_powershell_$(date +%Y-%m-%d).log
```

### Test post-merge Hook

```bash
# Create a test branch
git checkout -b test-merge
echo "test content" > test-merge.txt
git add test-merge.txt
git commit -m "test: add merge test file"

# Merge back
git checkout main
git merge test-merge

# Check if hook ran
cat logs/git-hooks_$(date +%Y-%m-%d).log | grep post-merge

# Cleanup
git branch -d test-merge
git rm test-merge.txt
git commit -m "test: cleanup merge test"
```

---

## Hook Configuration

### Customizing Hooks

Hooks are stored in `hooks/` and can be modified:

1. Edit the hook file in `hooks/` directory
2. Run `./scripts/install-hooks.sh` to update `.git/hooks/`
3. Test the changes

**Important:** Changes to hooks in `.git/hooks/` are **not tracked by Git**. Always edit files in `hooks/` directory and use the install script.

### Disabling Hooks Temporarily

To temporarily disable a hook without uninstalling:

```bash
# Rename the hook in .git/hooks/
mv .git/hooks/pre-commit .git/hooks/pre-commit.disabled

# Re-enable later
mv .git/hooks/pre-commit.disabled .git/hooks/pre-commit
```

Or use `--no-verify` for individual commits (see "Bypassing Hooks" section).

### Disabling Hooks Permanently

To permanently disable hooks (not recommended):

```bash
# Remove the hooks
rm .git/hooks/pre-commit
rm .git/hooks/commit-msg
rm .git/hooks/post-commit
rm .git/hooks/post-merge
```

**Note:** Running `./scripts/install-hooks.sh` will reinstall them.

---

## FAQ

### Q: Do hooks run on GitHub Actions / CI/CD?

**A:** No. Git hooks are local and stored in `.git/hooks/`, which is not tracked by Git. CI/CD systems don't use git hooks.

**Solution:** Replicate checks in CI/CD:
- Run linters in CI (already done via SonarCloud workflow)
- Enforce conventional commits via PR title checks (can be added)

### Q: Can I commit without running hooks?

**A:** Yes, using `git commit --no-verify`. See "Bypassing Hooks" section for details and best practices.

### Q: Why isn't my hook running?

**A:** Common causes:
1. Hooks not installed (run `./scripts/install-hooks.sh`)
2. Hooks not executable (run `chmod +x .git/hooks/*`)
3. You used `--no-verify` flag
4. Wrong hook for the operation (e.g., expecting pre-commit to run on `git push`)

### Q: Can I use different hooks on different branches?

**A:** No, hooks are repository-wide. However, you can:
- Add branch detection logic within the hook script
- Disable hooks on specific branches by checking `git branch --show-current`

### Q: What happens if a hook fails?

**A:**
- **pre-commit**: Commit is **aborted**. Fix issues and retry.
- **commit-msg**: Commit is **aborted**. Fix message and retry.
- **post-commit**: Commit **succeeds** but post-actions fail. Check logs.
- **post-merge**: Merge **succeeds** but post-actions fail. Check logs.

### Q: Can I modify hook behavior for my local workflow?

**A:** Yes, but:
1. **Don't modify `.git/hooks/` directly** (changes are lost on reinstall)
2. **Do modify `hooks/` directory** and reinstall
3. Consider making changes configurable via environment variables
4. Document any local modifications

### Q: Do hooks work with GUI Git clients?

**A:** Yes, most GUI clients respect git hooks:
- ✅ GitHub Desktop
- ✅ SourceTree
- ✅ GitKraken
- ✅ Fork
- ✅ VS Code Git integration

Some older or minimal clients may not support hooks.

---

## Additional Resources

- **Git Hooks Documentation**: [https://git-scm.com/docs/githooks](https://git-scm.com/docs/githooks)
- **Conventional Commits**: [https://www.conventionalcommits.org/](https://www.conventionalcommits.org/)
- **PSScriptAnalyzer**: [https://github.com/PowerShell/PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- **Pylint**: [https://pylint.pycqa.org/](https://pylint.pycqa.org/)
- **Repository Logging Specification**: `docs/logging_specification.md`
- **Contributing Guidelines**: `CONTRIBUTING.md`

---

## Support

If you encounter issues with git hooks:

1. Check this documentation
2. Review hook logs in `logs/git-hooks_*.log`
3. Check PowerShell hook logs in `logs/*_powershell_*.log`
4. Open an issue in the repository with:
   - Hook name and operation (e.g., "pre-commit on Windows")
   - Error message or unexpected behavior
   - Log file contents (if applicable)
   - System information (OS, Git version, PowerShell version)

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-18
**Related Issue:** #455
