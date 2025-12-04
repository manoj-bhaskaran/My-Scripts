# Git Hooks Guide (Pre-Commit Framework)

**Version:** 2.0.0
**Last Updated:** 2025-11-21

---

## Overview

This repository uses the [pre-commit framework](https://pre-commit.com) to enforce code quality and maintain consistency. Pre-commit is a multi-language package manager for pre-commit hooks that helps catch issues before they're committed or pushed.

### Why Pre-Commit Framework?

**Advantages over manual git hooks:**

- ✅ Configuration version-controlled (`.pre-commit-config.yaml`)
- ✅ Automatic hook installation for all team members
- ✅ Multi-language support (Python, PowerShell, SQL)
- ✅ Extensive hook library with 100+ pre-built hooks
- ✅ Automatic updates via CI/CD
- ✅ Per-hook configuration and selective execution
- ✅ Fast execution with caching
- ✅ Easy to add/remove hooks

---

## Installation

### Initial Setup (New Clone)

After cloning the repository, install the hooks:

```bash
# Linux/macOS/Git Bash
./scripts/install-hooks.sh

# Or manually
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

**What this does:**

1. Installs the pre-commit framework (Python package)
2. Installs pre-commit and commit-msg hooks to `.git/hooks/`
3. Runs hooks on all files for validation

### Prerequisites

**Required:**

- Python 3.7+ (for pre-commit framework)
- pip (Python package manager)

**Optional (for specific hooks):**

- PowerShell 7+ (`pwsh`) - For PowerShell linting
- Node.js - For JavaScript/TypeScript linting (if added)

---

## Active Hooks

### General Hooks (Pre-Built)

These hooks run on all commits:

#### **trailing-whitespace**

- Removes trailing whitespace from files
- Auto-fixes issues

#### **end-of-file-fixer**

- Ensures files end with a newline
- Auto-fixes issues

#### **check-yaml**

- Validates YAML syntax
- Prevents commits with broken YAML files

#### **check-json**

- Validates JSON syntax
- Prevents commits with broken JSON files

#### **check-added-large-files**

- Warns about files >5MB
- Configurable via `--maxkb` argument
- Prevents accidental commits of large binaries

#### **check-merge-conflict**

- Detects merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
- Prevents accidental commits of unresolved conflicts

#### **detect-private-key**

- Scans for private keys (SSH, PGP, etc.)
- Prevents accidental credential leaks

---

### Git LFS Hooks (Large File Storage)

The repository includes Git LFS hooks for handling large binary files:

#### **pre-push** (LFS)

- Uploads LFS objects before push operations
- Handles _.sql, _.dump, _.mp4, _.zip files automatically
- Prevents pushing without LFS objects

#### **post-checkout** (LFS)

- Downloads LFS objects after branch checkout
- Ensures large files are available in working directory
- Only runs for branch checkouts, not individual file checkouts

#### **post-merge** (LFS)

- Downloads LFS objects after merge operations
- Keeps large files synchronized after merges

#### **post-commit** (LFS)

- Tracks new LFS objects after commits
- Integrated with existing post-commit PowerShell automation

**Tracked file types:**

- `*.sql` - Database scripts and dumps
- `*.dump` - Binary database dumps
- `*.mp4` - Video files
- `*.zip` - Archive files

See `.gitattributes` for complete LFS configuration.

---

### Python Hooks

#### **Black (Code Formatter)**

- Auto-formats Python code to consistent style
- Line length: 100 characters (configured in `pyproject.toml`)
- Target version: Python 3.11
- **Auto-fixes issues**

**Configuration:** `pyproject.toml`

```toml
[tool.black]
line-length = 100
target-version = ['py311']
```

#### **Pylint (Linter)**

- Checks Python code for errors and style issues
- Configured to show errors only (`--errors-only`)
- Configuration: `.pylintrc`

**Configuration:** `.pylintrc`

```ini
[MASTER]
ignore=tests

[MESSAGES CONTROL]
disable=C0111,R0913

[FORMAT]
max-line-length=100
```

#### **Bandit (Security Scanner)**

- Scans Python code for security issues
- Uses configuration from `pyproject.toml`
- Detects common vulnerabilities (SQL injection, hardcoded passwords, etc.)

**Configuration:** `pyproject.toml`

```toml
[tool.bandit]
exclude_dirs = ["tests", "fixtures"]
```

---

### PowerShell Hooks

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

---

### SQL Hooks

#### **SQLFluff (Linter & Formatter)**

- SQL linting and formatting
- Dialect: PostgreSQL
- Max line length: 120 characters

**Hooks:**

1. `sqlfluff-lint` - Checks SQL style and syntax
2. `sqlfluff-fix` - Auto-fixes SQL formatting issues

**Configuration:** `.sqlfluffrc`

```ini
[sqlfluff]
dialect = postgres
max_line_length = 120
exclude_rules = L003,L010
```

---

### Commit Message Validation

#### **Commitizen**

- Enforces [Conventional Commits](https://www.conventionalcommits.org/) format
- Runs on `commit-msg` hook (after you write the message)

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
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `build`: Build system changes
- `revert`: Reverting commits

**Examples:**

```bash
✅ feat(hooks): add pre-commit framework
✅ fix: resolve database timeout issue
✅ docs: update git hooks guide
✅ chore: update dependencies

❌ Updated readme              # No type
❌ FIX: bug                    # Uppercase type
❌ feat add feature            # Missing colon
```

**Configuration:** `pyproject.toml`

```toml
[tool.commitizen]
name = "cz_conventional_commits"
version = "1.0.0"
tag_format = "v$version"
```

---

### Legacy Hooks (Post-Commit, Post-Merge)

These hooks are not managed by pre-commit framework and still use the manual installation:

#### **post-commit** - Post-Commit Automation

- Calls `src/powershell/Invoke-PostCommitHook.ps1`
- Mirrors committed files to staging directory
- Deploys PowerShell modules per configuration
- Requires PowerShell 7+ (`pwsh`)

**Location:** `hooks/post-commit`

#### **post-merge** - Post-Merge Automation

- Calls `src/powershell/Invoke-PostMergeHook.ps1`
- Updates staging directory with merged changes
- Handles dependency updates
- Requires PowerShell 7+ (`pwsh`)

**Location:** `hooks/post-merge`

---

## Running Hooks Manually

### Run on Staged Files

```bash
# Run all hooks on staged files
pre-commit run

# Run specific hook
pre-commit run black
pre-commit run pylint
```

### Run on All Files

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook on all files
pre-commit run black --all-files
```

### Run on Specific Files

```bash
# Run hooks on specific files
pre-commit run --files src/python/example.py

# Run specific hook on specific files
pre-commit run black --files src/python/*.py
```

---

## Skipping Hooks

**⚠️ Use with caution!** Bypassing hooks should only be done in exceptional circumstances.

### When Bypassing is Acceptable

- **Emergency hotfixes**: Critical production fixes
- **Work in progress commits**: Experimental branches
- **Automated systems**: CI/CD pipelines
- **Temporary issues**: When hooks have false positives (fix afterward!)

### How to Bypass

**Skip all hooks:**

```bash
git commit --no-verify -m "fix: emergency hotfix"
# or shorter
git commit -n -m "fix: emergency hotfix"
```

**Skip specific hook:**

```bash
# Use SKIP environment variable
SKIP=pylint git commit -m "fix: temporary bypass"

# Skip multiple hooks
SKIP=pylint,black git commit -m "fix: bypass multiple"
```

### Best Practices

1. **Document why you bypassed:**

   ```bash
   git commit -n -m "fix: emergency database fix

   Bypassing hooks due to production outage.
   TODO: Run hooks and fix issues in follow-up commit."
   ```

2. **Fix issues promptly**: Address hook failures in follow-up commits
3. **Don't make it a habit**: If bypassing regularly, fix the hooks or workflow

---

## Updating Hooks

### Manual Update

```bash
# Update to latest hook versions
pre-commit autoupdate

# Review changes
git diff .pre-commit-config.yaml

# Commit updates
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

### Automatic Updates (CI/CD)

The repository includes a weekly auto-update workflow:

**Workflow:** `.github/workflows/pre-commit-autoupdate.yml`

- Runs every Sunday at midnight UTC
- Automatically creates PR with hook updates
- Can be triggered manually via GitHub Actions

---

## Configuration Files

### `.pre-commit-config.yaml`

Main configuration file listing all hooks and their versions.

### `.pylintrc`

Pylint configuration (Python linting rules).

### `pyproject.toml`

Configuration for Black, Bandit, and Commitizen.

### `.sqlfluffrc`

SQLFluff configuration (SQL linting rules).

---

## CI/CD Integration

Pre-commit hooks run automatically in CI/CD via `.github/workflows/sonarcloud.yml`:

```yaml
- name: Run Pre-Commit Hooks
  run: |
    pip install pre-commit
    pre-commit run --all-files --show-diff-on-failure
  continue-on-error: true
```

**Features:**

- Runs on every push and pull request
- Shows diffs for failed hooks
- Continues on error (informational only in Phase 1)

---

## Troubleshooting

### Hook Not Running

**Problem:** Hook doesn't execute when expected

**Solutions:**

1. Check if hooks are installed:

   ```bash
   ls -la .git/hooks/
   # Should show pre-commit and commit-msg
   ```

2. Reinstall hooks:

   ```bash
   ./scripts/install-hooks.sh
   # Or manually
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

3. Verify pre-commit is installed:
   ```bash
   pre-commit --version
   ```

---

### Pre-Commit Not Found

**Problem:** `pre-commit: command not found`

**Solution:**

```bash
# Install pre-commit
pip install pre-commit

# Verify installation
pre-commit --version
```

---

### PowerShell Not Found

**Problem:** `pwsh: command not found` when PSScriptAnalyzer runs

**Impact:**

- PowerShell linting will be skipped

**Solution:**

Install PowerShell 7+:

- **Windows:** [https://aka.ms/powershell](https://aka.ms/powershell)
- **Linux:**
  ```bash
  # Ubuntu/Debian
  sudo apt-get install -y powershell
  ```
- **macOS:**
  ```bash
  brew install --cask powershell
  ```

---

### PSScriptAnalyzer Not Found

**Problem:** PowerShell linting fails with module not found error

**Solution:**

```powershell
# Install PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable PSScriptAnalyzer
```

---

### Hook Fails with "No files to check"

**Problem:** Hook reports "no files to check"

**Cause:** No files matching the hook's pattern are staged

**Solution:**
This is normal. The hook only runs on relevant files (e.g., `.py`, `.ps1`, `.sql`).

---

### Commit Message Rejected

**Problem:** `commitizen` rejects commit message

**Solution:**

1. Follow Conventional Commits format: `type(scope): description`
2. Use lowercase for type and scope
3. Ensure description is meaningful (>3 characters)
4. Use approved types: `feat`, `fix`, `docs`, etc.

**Examples:**

```bash
✅ git commit -m "feat(hooks): add pre-commit framework"
✅ git commit -m "fix: resolve timeout issue"
❌ git commit -m "Updated hooks"
```

---

### Black Reformats Code

**Problem:** Black auto-formats code differently than expected

**Solution:**

1. This is expected behavior - Black enforces consistent style
2. Review the changes: `git diff`
3. If needed, adjust Black configuration in `pyproject.toml`
4. To preserve specific formatting, use `# fmt: off` and `# fmt: on`:
   ```python
   # fmt: off
   matrix = [
       [1, 2, 3],
       [4, 5, 6],
   ]
   # fmt: on
   ```

---

### Large Files Warning

**Problem:** `check-added-large-files` warns about large files

**Solution:**

1. **Use Git LFS** for large files:

   ```bash
   git lfs install
   git lfs track "*.mp4"
   git add .gitattributes
   ```

2. **Or increase the limit** in `.pre-commit-config.yaml`:
   ```yaml
   - id: check-added-large-files
     args: ["--maxkb=10000"] # 10MB
   ```

---

### Hook Takes Too Long

**Problem:** Hooks slow down commits

**Solutions:**

1. **Run hooks on staged files only** (default behavior)
2. **Skip slow hooks occasionally**:
   ```bash
   SKIP=pylint git commit -m "wip: work in progress"
   ```
3. **Optimize hook configuration**:
   - Use `--errors-only` for linters
   - Exclude test files from some hooks
   - Use file filters to target specific paths

---

## Testing Hooks

### Test Pre-Commit Hooks

```bash
# Test all hooks
pre-commit run --all-files

# Test specific hook
pre-commit run black --all-files
pre-commit run pylint --all-files

# Test on specific file
pre-commit run --files src/python/example.py
```

### Test Commit Message Validation

```bash
# Invalid format - should fail
git commit --allow-empty -m "Updated stuff"

# Valid format - should succeed
git commit --allow-empty -m "test: verify commit-msg hook"
```

### Test Auto-Fixes

```bash
# Create a file with trailing whitespace
echo "test  " > test.txt
git add test.txt

# Commit (Black will auto-fix)
git commit -m "test: auto-fix test"

# Check the fix
cat test.txt  # Should have trailing whitespace removed
```

---

## Hook Configuration

### Adding New Hooks

1. Edit `.pre-commit-config.yaml`
2. Add new hook entry
3. Update configuration files if needed (`.pylintrc`, `pyproject.toml`, etc.)
4. Test the hook:
   ```bash
   pre-commit run <hook-id> --all-files
   ```
5. Commit changes:
   ```bash
   git add .pre-commit-config.yaml
   git commit -m "chore: add new pre-commit hook"
   ```

### Disabling Hooks Temporarily

**For a single commit:**

```bash
SKIP=hook-id git commit -m "message"
```

**For all commits (not recommended):**

```bash
# Uninstall hooks
pre-commit uninstall

# Re-enable later
pre-commit install
```

---

## FAQ

### Q: Do hooks run on GitHub Actions / CI/CD?

**A:** Yes! The workflow in `.github/workflows/sonarcloud.yml` runs pre-commit hooks on every push and PR.

---

### Q: Can I commit without running hooks?

**A:** Yes, using `git commit --no-verify`. See "Skipping Hooks" section for details and best practices.

---

### Q: Why isn't my hook running?

**A:** Common causes:

1. Hooks not installed (run `./scripts/install-hooks.sh`)
2. Pre-commit not installed (run `pip install pre-commit`)
3. No files matching the hook's pattern are staged
4. You used `--no-verify` flag

---

### Q: How do I update hook versions?

**A:**

- **Manually:** `pre-commit autoupdate`
- **Automatically:** The weekly auto-update workflow creates PRs

---

### Q: Can I use different hooks on different branches?

**A:** No, hooks are repository-wide. However, you can:

- Add branch detection logic within custom hooks
- Skip hooks on specific branches: `SKIP=hook git commit`

---

### Q: What happens if a hook fails?

**A:**

- **pre-commit hooks**: Commit is **aborted**. Fix issues and retry.
- **commit-msg**: Commit is **aborted**. Fix message and retry.
- **Auto-fix hooks** (Black, trailing-whitespace): Files are modified. Review and re-stage.

---

### Q: Do hooks work with GUI Git clients?

**A:** Yes, most GUI clients respect git hooks:

- ✅ GitHub Desktop
- ✅ SourceTree
- ✅ GitKraken
- ✅ VS Code Git integration

---

### Q: How do I exclude files from hooks?

**A:** Use `exclude` in `.pre-commit-config.yaml`:

```yaml
- repo: https://github.com/psf/black
  rev: 24.1.1
  hooks:
    - id: black
      exclude: ^legacy/.*\.py$ # Exclude legacy directory
```

---

## Additional Resources

- **Pre-Commit Framework**: [https://pre-commit.com](https://pre-commit.com)
- **Conventional Commits**: [https://www.conventionalcommits.org/](https://www.conventionalcommits.org/)
- **Supported Hooks**: [https://pre-commit.com/hooks.html](https://pre-commit.com/hooks.html)
- **Black Formatter**: [https://black.readthedocs.io/](https://black.readthedocs.io/)
- **Pylint**: [https://pylint.pycqa.org/](https://pylint.pycqa.org/)
- **Bandit**: [https://bandit.readthedocs.io/](https://bandit.readthedocs.io/)
- **PSScriptAnalyzer**: [https://github.com/PowerShell/PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- **SQLFluff**: [https://sqlfluff.com/](https://sqlfluff.com/)
- **Commitizen**: [https://commitizen-tools.github.io/commitizen/](https://commitizen-tools.github.io/commitizen/)

---

## Support

For issues or questions:

1. Check this documentation
2. Review [pre-commit documentation](https://pre-commit.com)
3. Search existing [GitHub issues](https://github.com/manoj-bhaskaran/My-Scripts/issues)
4. Open a new issue with:
   - Hook name and operation
   - Error message or unexpected behavior
   - System information (OS, Python version, pre-commit version)

---

**Document Version:** 2.0.0
**Last Updated:** 2025-11-21
**Related Issue:** #463
