# Activate Git Hooks for Quality Enforcement

## Priority
**HIGH** 🟠

## Background
The My-Scripts repository has git hook scripts configured but **none are activated**:

**Current State:**
- `.git/hooks/` contains only sample files (`*.sample`)
- Hook scripts exist in the repository:
  - `src/powershell/post-commit-my-scripts.ps1`
  - `src/powershell/post-merge-my-scripts.ps1`
- No pre-commit hooks for linting enforcement
- No commit-msg hooks for message validation
- Quality checks only run in CI (after push), not locally

**Impact:**
- Code quality issues discovered late (after push)
- No automatic linting before commits
- Inconsistent formatting across commits
- Manual quality checks burden

## Objectives
- Activate existing post-commit and post-merge hooks
- Create pre-commit hook for linting and formatting
- Add commit-msg hook for conventional commits
- Ensure hooks work cross-platform (Windows, Linux, macOS)
- Document hook behavior and bypass procedures

## Tasks

### Phase 1: Activate Existing Hooks
- [ ] Create `.git/hooks/post-commit` from template:
  ```bash
  #!/bin/sh
  # Post-commit hook: Runs post-commit-my-scripts.ps1

  pwsh -NoProfile -ExecutionPolicy Bypass -File "$(git rev-parse --show-toplevel)/src/powershell/post-commit-my-scripts.ps1"
  ```
- [ ] Create `.git/hooks/post-merge` from template:
  ```bash
  #!/bin/sh
  # Post-merge hook: Runs post-merge-my-scripts.ps1

  pwsh -NoProfile -ExecutionPolicy Bypass -File "$(git rev-parse --show-toplevel)/src/powershell/post-merge-my-scripts.ps1"
  ```
- [ ] Make hooks executable:
  ```bash
  chmod +x .git/hooks/post-commit
  chmod +x .git/hooks/post-merge
  ```
- [ ] Test hooks:
  ```bash
  git commit --allow-empty -m "test: verify post-commit hook"
  ```

### Phase 2: Review Existing Hook Scripts
- [ ] Audit `src/powershell/post-commit-my-scripts.ps1`:
  - What does it do?
  - Does it have proper error handling?
  - Does it log execution?
  - Does it exit cleanly?
- [ ] Audit `src/powershell/post-merge-my-scripts.ps1`:
  - Same questions as above
- [ ] Update scripts if needed for robustness
- [ ] Add logging per logging specification

### Phase 3: Create Pre-Commit Hook
- [ ] Create `.git/hooks/pre-commit`:
  ```bash
  #!/bin/sh
  # Pre-commit hook: Linting and validation

  echo "Running pre-commit checks..."

  # 1. Check for debug statements
  if git diff --cached --name-only | xargs grep -l "Write-Debug.*TODO\|print.*DEBUG\|console.log"; then
    echo "ERROR: Debug statements found. Remove before committing."
    exit 1
  fi

  # 2. Run PowerShell linting (PSScriptAnalyzer)
  CHANGED_PS_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.ps1$')
  if [ -n "$CHANGED_PS_FILES" ]; then
    echo "Linting PowerShell files..."
    pwsh -Command "
      Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction SilentlyContinue
      \$results = Invoke-ScriptAnalyzer -Path ($CHANGED_PS_FILES -split '\n') -Severity Error
      if (\$results) {
        \$results | Format-Table
        exit 1
      }
    "
    if [ $? -ne 0 ]; then
      echo "ERROR: PowerShell linting failed. Fix errors before committing."
      exit 1
    fi
  fi

  # 3. Run Python linting (pylint/black)
  CHANGED_PY_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$')
  if [ -n "$CHANGED_PY_FILES" ]; then
    echo "Linting Python files..."
    pylint $CHANGED_PY_FILES --errors-only
    if [ $? -ne 0 ]; then
      echo "ERROR: Python linting failed. Fix errors before committing."
      exit 1
    fi
  fi

  echo "Pre-commit checks passed!"
  exit 0
  ```
- [ ] Make hook executable: `chmod +x .git/hooks/pre-commit`
- [ ] Test pre-commit hook with intentional error

### Phase 4: Create Commit-Msg Hook (Conventional Commits)
- [ ] Create `.git/hooks/commit-msg`:
  ```bash
  #!/bin/sh
  # Commit-msg hook: Validate conventional commit format

  COMMIT_MSG_FILE=$1
  COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

  # Conventional Commits format: type(scope): description
  # Types: feat, fix, docs, style, refactor, test, chore
  PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?: .{1,100}"

  if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
    echo "ERROR: Commit message does not follow Conventional Commits format"
    echo ""
    echo "Format: <type>(<scope>): <description>"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    echo "Example: feat(logging): add structured JSON output"
    echo ""
    exit 1
  fi

  exit 0
  ```
- [ ] Make hook executable: `chmod +x .git/hooks/commit-msg`
- [ ] Test with valid and invalid commit messages

### Phase 5: Hook Distribution Strategy
Git hooks are local (`.git/hooks/` not tracked). Need distribution mechanism:

**Option 1: Hook Templates in Repository**
- [ ] Create `hooks/` directory in repository root
- [ ] Copy all hook scripts to `hooks/`:
  ```
  hooks/
  ├── pre-commit
  ├── commit-msg
  ├── post-commit
  └── post-merge
  ```
- [ ] Create `scripts/install-hooks.sh`:
  ```bash
  #!/bin/bash
  # Install git hooks from repository

  REPO_ROOT=$(git rev-parse --show-toplevel)
  HOOKS_DIR="$REPO_ROOT/hooks"
  GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

  for hook in pre-commit commit-msg post-commit post-merge; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
      echo "Installing $hook hook..."
      cp "$HOOKS_DIR/$hook" "$GIT_HOOKS_DIR/$hook"
      chmod +x "$GIT_HOOKS_DIR/$hook"
    fi
  done

  echo "Git hooks installed successfully!"
  ```
- [ ] Document in README.md: "Run `./scripts/install-hooks.sh` after clone"

**Option 2: Git Config Automation**
- [ ] Configure git to use custom hooks directory:
  ```bash
  git config core.hooksPath hooks/
  ```
- [ ] Add to `.gitconfig` or document in installation guide

### Phase 6: Bypass Documentation
- [ ] Document how to bypass hooks when needed:
  ```bash
  # Skip pre-commit and commit-msg hooks
  git commit --no-verify -m "message"

  # Skip specific hook (not possible without --no-verify)
  # Use only when necessary (e.g., emergency hotfix)
  ```
- [ ] Add warning in `docs/guides/git-hooks.md` about when bypassing is acceptable
- [ ] Log hook bypasses (if possible) for audit

### Phase 7: Hook Logging
- [ ] Update hooks to log execution per logging specification:
  ```bash
  LOG_DIR="$(git rev-parse --show-toplevel)/logs"
  LOG_FILE="$LOG_DIR/git-hooks_$(date +%Y-%m-%d).log"
  mkdir -p "$LOG_DIR"

  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] [pre-commit] [$(hostname)] [$$] Hook started" >> "$LOG_FILE"
  ```
- [ ] Ensure logs follow logging specification format
- [ ] Add log purging for git hook logs (include in `PurgeLogs.psm1`)

### Phase 8: Documentation
- [ ] Create `docs/guides/git-hooks.md`:
  - What hooks are active
  - What each hook checks
  - How to install hooks (new clones)
  - How to bypass hooks (when appropriate)
  - Troubleshooting common issues
- [ ] Update README.md with hooks section:
  ```markdown
  ## Git Hooks

  This repository uses git hooks for quality enforcement:
  - **pre-commit**: Linting (PSScriptAnalyzer, pylint)
  - **commit-msg**: Conventional Commits validation
  - **post-commit**: Repository-specific automation
  - **post-merge**: Dependency updates, log rotation

  **Installation:**
  ```bash
  ./scripts/install-hooks.sh
  ```

  See [docs/guides/git-hooks.md](docs/guides/git-hooks.md) for details.
  ```
- [ ] Add hooks to CHANGELOG.md

## Acceptance Criteria
- [x] All git hooks executable and functional
- [x] Pre-commit hook validates PowerShell (PSScriptAnalyzer) and Python (pylint)
- [x] Commit-msg hook enforces Conventional Commits format
- [x] Post-commit and post-merge hooks activated
- [x] Hook installation script (`scripts/install-hooks.sh`) created
- [x] Hook templates stored in repository (`hooks/` directory)
- [x] Hooks log execution per logging specification
- [x] Documentation created (`docs/guides/git-hooks.md`)
- [x] README.md updated with hooks section
- [x] Bypass procedure documented
- [x] Hooks tested on Windows and Linux (if applicable)

## Testing Checklist
- [ ] Pre-commit hook rejects PowerShell errors
- [ ] Pre-commit hook rejects Python errors
- [ ] Pre-commit hook allows clean code
- [ ] Commit-msg hook rejects invalid formats
- [ ] Commit-msg hook allows conventional commits
- [ ] Post-commit hook runs successfully
- [ ] Post-merge hook runs successfully
- [ ] `--no-verify` bypasses pre-commit/commit-msg
- [ ] Hooks work after fresh clone + `install-hooks.sh`
- [ ] Hooks log to `logs/git-hooks_YYYY-MM-DD.log`

## Related Files
- `.git/hooks/` (local, not tracked)
- `hooks/` (to be created, tracked)
- `scripts/install-hooks.sh` (to be created)
- `src/powershell/post-commit-my-scripts.ps1` (exists)
- `src/powershell/post-merge-my-scripts.ps1` (exists)
- `docs/guides/git-hooks.md` (to be created)
- `README.md`

## Estimated Effort
**2 days** (hook creation, testing, documentation)

## Dependencies
- Issue #001 (Test Infrastructure) – for testing hooks
- Issue #003 (Naming Conventions) – hooks will enforce standards

## Security Considerations
- ⚠️ Hooks run arbitrary code – review all hook scripts carefully
- ⚠️ Don't store secrets in hook scripts
- ✅ Hooks are local (not automatically distributed) – prevents malicious hook injection
- ✅ Users must manually install hooks – explicit opt-in

## References
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [Pylint](https://pylint.org/)
