# Issue: Missing Runtime Dependencies

**Priority:** High
**Type:** Dependency
**Component:** Git Hooks, Development Environment

## Description

Multiple critical dependencies required by git hooks are not installed in the current environment, preventing hooks from functioning properly.

## Missing Dependencies

### 1. Git LFS (Large File Storage)

**Status:** Not installed
```bash
$ git lfs version
Git LFS not installed
```

**Required By:**
- `hooks/pre-push` (lines 28-46)
- `hooks/post-checkout` (lines 39-59)
- `hooks/post-merge` (lines 27-37)
- `hooks/post-commit` (lines 27-37)

**Configured Files:**
`.gitattributes` tracks these file types with LFS:
- `*.sql`
- `*.dump`
- `*.mp4`
- `*.zip`

**Impact:**
- Large files won't be uploaded/downloaded properly
- Repository size will grow unnecessarily
- Potential push failures for large files
- Missing LFS objects after checkout/merge

### 2. Pre-commit Framework

**Status:** Not installed
```bash
$ pre-commit --version
bash: pre-commit: command not found
```

**Required By:**
- `.pre-commit-config.yaml` (all configured hooks)
- `scripts/install-hooks.sh` (expects to install pre-commit)
- CI/CD workflows (expects pre-commit to run)

**Configured Hooks:**
- Python: black, pylint, bandit, mypy, safety
- General: trailing-whitespace, end-of-file-fixer, check-yaml, check-json, etc.
- Commit validation: commitizen

**Impact:**
- Modern linting and formatting not running
- Python code quality checks bypassed
- Commit message format not validated
- Security scans (bandit) not running

### 3. PowerShell Core (pwsh)

**Status:** Not installed
```bash
$ pwsh --version
bash: pwsh: command not found
```

**Required By:**
- `hooks/post-commit` (lines 39-65)
- `hooks/post-merge` (lines 39-65)
- `hooks/pre-commit` (lines 77-97: PowerShell linting - currently disabled)
- `src/powershell/git/Invoke-PostCommitHook.ps1`
- `src/powershell/git/Invoke-PostMergeHook.ps1`

**Impact:**
- Post-commit automation doesn't run
- Post-merge automation doesn't run
- PowerShell module deployment disabled
- File mirroring to staging directory skipped

### 4. Python Linting Tools

**Status:** Unknown (not verified)

**May Be Missing:**
- `pylint` - Python linting
- `black` - Python formatting
- `bandit` - Security scanning
- `mypy` - Type checking

**Used By:**
- `hooks/pre-commit` (lines 106-143: Python linting)
- Pre-commit framework (when installed)

## Current Hook Behavior (Without Dependencies)

| Hook | Dependency Missing | Behavior |
|------|-------------------|----------|
| pre-commit | pylint, pwsh | Skips linting, shows warnings |
| commit-msg | pre-commit framework | Not running (hook not installed) |
| pre-push | git-lfs | Skips LFS operations, shows warning |
| post-checkout | git-lfs | Skips LFS operations, shows warning |
| post-commit | pwsh, git-lfs | Skips automation, shows warning |
| post-merge | pwsh, git-lfs | Skips automation, shows warning |

All shell hooks gracefully handle missing dependencies with warnings, so they won't fail - they just won't do their job.

## Installation Requirements

### Git LFS

**Linux (Debian/Ubuntu):**
```bash
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
sudo apt-get install git-lfs
git lfs install
```

**macOS:**
```bash
brew install git-lfs
git lfs install
```

**Windows:**
```powershell
# Using Chocolatey
choco install git-lfs
git lfs install
```

### Pre-commit Framework

**All platforms (with Python/pip):**
```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

Or use the provided script:
```bash
./scripts/install-hooks.sh
```

### PowerShell Core

**Linux (Ubuntu):**
```bash
sudo apt-get install -y powershell
```

**macOS:**
```bash
brew install --cask powershell
```

**Windows:**
Already included, or install from: https://aka.ms/powershell

### Python Linting Tools

**Via pip:**
```bash
pip install pylint black bandit mypy
```

**Via pre-commit framework:**
Pre-commit automatically installs these in isolated environments when `pre-commit install` is run.

## Recommended Actions

### 1. Create Comprehensive Setup Script

Create `scripts/setup-dev-environment.sh`:
```bash
#!/bin/bash
set -e

echo "Setting up development environment..."

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required"
    exit 1
fi

# Install pre-commit framework
echo "Installing pre-commit framework..."
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg

# Install Git LFS (platform-specific)
if ! command -v git-lfs &> /dev/null; then
    echo "Installing Git LFS..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
        sudo apt-get install git-lfs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git-lfs
    else
        echo "Please install Git LFS manually: https://git-lfs.github.com/"
    fi
    git lfs install
fi

# Install PowerShell (optional)
if ! command -v pwsh &> /dev/null; then
    echo "PowerShell not found. Module deployment will be disabled."
    echo "To install: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
fi

echo "Development environment setup complete!"
echo "Run 'pre-commit run --all-files' to verify hooks work."
```

### 2. Update Documentation

**README.md:**
```markdown
## Development Setup

### Prerequisites
- Git 2.9+
- Python 3.7+
- pip

### Optional (for full functionality)
- Git LFS 2.0+
- PowerShell Core 7.0+

### Installation
```bash
# Run setup script
./scripts/setup-dev-environment.sh

# Or manually
pip install pre-commit
pre-commit install
git lfs install  # If you have Git LFS
```

### 3. Add Dependency Checks to CI

```yaml
# .github/workflows/verify-environment.yml
name: Verify Environment
on: [push, pull_request]

jobs:
  check-dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check Git LFS
        run: |
          git lfs version || echo "::warning::Git LFS not installed"

      - name: Check pre-commit
        run: |
          pip install pre-commit
          pre-commit run --all-files

      - name: Check PowerShell
        run: |
          pwsh -Version || echo "::warning::PowerShell not installed"
```

### 4. Add Requirements File

Create `requirements-dev.txt`:
```txt
# Python development dependencies
pre-commit>=3.5.0
pylint>=3.0.0
black>=24.3.0
bandit>=1.7.5
mypy>=1.7.1
safety>=2.3.0

# Testing
pytest>=7.4.0
pytest-cov>=4.1.0
```

Install with:
```bash
pip install -r requirements-dev.txt
```

### 5. Make PowerShell Optional But Document It

In hook scripts, change:
```bash
# Current
if ! command -v pwsh >/dev/null 2>&1; then
    log_message "WARNING" "PowerShell (pwsh) not found. Skipping..."
    exit 0
fi

# Better
if ! command -v pwsh >/dev/null 2>&1; then
    log_message "WARNING" "PowerShell not found. Module deployment disabled."
    echo "To enable PowerShell automation, install PowerShell Core 7.0+"
    echo "See: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
    exit 0  # Continue gracefully
fi
```

## Dependency Matrix

| Dependency | Required | Version | Purpose | Fallback Behavior |
|------------|----------|---------|---------|-------------------|
| Git | Yes | 2.9+ | Version control | N/A (must have) |
| Python | Yes | 3.7+ | Pre-commit framework | Manual hooks only |
| pip | Yes | Latest | Package installation | N/A |
| Git LFS | Recommended | 2.0+ | Large file handling | Warning, continues |
| PowerShell | Optional | 7.0+ | Module deployment | Skips automation |
| pylint | Optional | 3.0+ | Python linting | Skipped with warning |
| black | Optional | 24.0+ | Python formatting | Not auto-formatted |

## References

- `.gitattributes` (lines 5-8: LFS file types)
- `hooks/pre-push` (lines 28-46: Git LFS)
- `hooks/post-commit` (lines 39-65: PowerShell)
- `scripts/install-hooks.sh`
- `.pre-commit-config.yaml`

## Related Issues

- #001: Git Hooks Not Installed
- #002: Pre-commit Framework Not Installed
- #005: Platform Compatibility Issues
