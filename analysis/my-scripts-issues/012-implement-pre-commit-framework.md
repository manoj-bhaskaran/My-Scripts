# Implement Pre-Commit Framework for Multi-Language Linting

## Priority
**LOW** 🟢

## Background
The My-Scripts repository uses **manual git hooks** (Issue #004) which:
- Require manual installation after clone
- Are not version-controlled
- Don't support per-hook configuration
- Hard to maintain across multiple languages

**Better Approach**: Use [pre-commit](https://pre-commit.com/) framework:
- Configuration version-controlled (`.pre-commit-config.yaml`)
- Automatic hook installation
- Multi-language support (Python, PowerShell, SQL)
- Extensive hook library
- Automatic updates

## Objectives
- Install and configure pre-commit framework
- Replace manual git hooks with pre-commit
- Add linting/formatting hooks for all languages
- Integrate with CI/CD
- Document usage

## Tasks

### Phase 1: Install Pre-Commit
- [ ] Add to `requirements.txt`:
  ```txt
  pre-commit>=3.0.0
  ```
- [ ] Document installation:
  ```bash
  pip install pre-commit
  pre-commit install
  ```

### Phase 2: Create Configuration
- [ ] Create `.pre-commit-config.yaml`:
  ```yaml
  # Pre-commit hooks configuration
  # See https://pre-commit.com for more information

  repos:
    # General hooks
    - repo: https://github.com/pre-commit/pre-commit-hooks
      rev: v4.5.0
      hooks:
        - id: trailing-whitespace
        - id: end-of-file-fixer
        - id: check-yaml
        - id: check-json
        - id: check-added-large-files
          args: ['--maxkb=5000']
        - id: check-merge-conflict
        - id: detect-private-key

    # Python hooks
    - repo: https://github.com/psf/black
      rev: 24.1.1
      hooks:
        - id: black
          language_version: python3.11

    - repo: https://github.com/PyCQA/pylint
      rev: v3.0.0
      hooks:
        - id: pylint
          args: ['--errors-only']

    - repo: https://github.com/PyCQA/bandit
      rev: 1.7.5
      hooks:
        - id: bandit
          args: ['-c', 'pyproject.toml']
          additional_dependencies: ['bandit[toml]']

    # PowerShell hooks
    - repo: local
      hooks:
        - id: psscriptanalyzer
          name: PSScriptAnalyzer
          entry: pwsh -Command "Invoke-ScriptAnalyzer -Path"
          language: system
          files: \.ps1$
          args: ['-Severity', 'Error']

    # SQL hooks
    - repo: https://github.com/sqlfluff/sqlfluff
      rev: 3.0.0
      hooks:
        - id: sqlfluff-lint
          args: ['--dialect', 'postgres']
        - id: sqlfluff-fix
          args: ['--dialect', 'postgres']

    # Commit message validation
    - repo: https://github.com/commitizen-tools/commitizen
      rev: v3.12.0
      hooks:
        - id: commitizen
          stages: [commit-msg]
  ```

### Phase 3: Configure Linters
- [ ] Create `.pylintrc`:
  ```ini
  [MASTER]
  ignore=tests

  [MESSAGES CONTROL]
  disable=C0111,R0913

  [FORMAT]
  max-line-length=100
  ```
- [ ] Create `pyproject.toml`:
  ```toml
  [tool.black]
  line-length = 100
  target-version = ['py311']

  [tool.bandit]
  exclude_dirs = ["tests", "fixtures"]

  [tool.commitizen]
  name = "cz_conventional_commits"
  version = "1.0.0"
  tag_format = "v$version"
  ```
- [ ] Create `.sqlfluffrc`:
  ```ini
  [sqlfluff]
  dialect = postgres
  max_line_length = 120
  exclude_rules = L003,L010
  ```

### Phase 4: Replace Manual Hooks
- [ ] Remove manual hooks from `hooks/` directory (or mark as legacy)
- [ ] Update `scripts/install-hooks.sh`:
  ```bash
  #!/bin/bash
  # Install pre-commit hooks

  echo "Installing pre-commit framework..."
  pip install pre-commit

  echo "Installing git hooks..."
  pre-commit install
  pre-commit install --hook-type commit-msg

  echo "Running hooks on all files (validation)..."
  pre-commit run --all-files

  echo "Git hooks installed successfully!"
  ```
- [ ] Update documentation to use pre-commit

### Phase 5: CI Integration
- [ ] Update `.github/workflows/sonarcloud.yml`:
  ```yaml
  - name: Run Pre-Commit Hooks
    run: |
      pip install pre-commit
      pre-commit run --all-files --show-diff-on-failure
  ```
- [ ] Ensure CI runs all pre-commit hooks

### Phase 6: Auto-Update Configuration
- [ ] Enable auto-update workflow:
  ```yaml
  # .github/workflows/pre-commit-autoupdate.yml
  name: Pre-Commit Auto-Update
  on:
    schedule:
      - cron: '0 0 * * 0'  # Weekly on Sunday

  jobs:
    auto-update:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: actions/setup-python@v5
        - run: |
            pip install pre-commit
            pre-commit autoupdate
        - uses: peter-evans/create-pull-request@v5
          with:
            title: 'chore: update pre-commit hooks'
            commit-message: 'chore: update pre-commit hooks'
            branch: pre-commit-autoupdate
  ```

### Phase 7: Documentation
- [ ] Update `docs/guides/git-hooks.md`:
  ```markdown
  # Git Hooks (Pre-Commit Framework)

  ## Installation
  ```bash
  # Install pre-commit framework
  pip install pre-commit

  # Install hooks to .git/hooks/
  pre-commit install
  pre-commit install --hook-type commit-msg
  ```

  ## Running Hooks Manually
  ```bash
  # Run on staged files
  pre-commit run

  # Run on all files
  pre-commit run --all-files

  # Run specific hook
  pre-commit run black --all-files
  ```

  ## Skipping Hooks
  ```bash
  # Skip all hooks (use sparingly!)
  git commit --no-verify

  # Skip specific hook via SKIP env variable
  SKIP=pylint git commit
  ```

  ## Updating Hooks
  ```bash
  # Update to latest versions
  pre-commit autoupdate
  ```
  ```
- [ ] Update INSTALLATION.md with pre-commit setup

### Phase 8: Testing
- [ ] Test hook installation on clean environment
- [ ] Test each hook individually
- [ ] Verify hooks run on commit
- [ ] Verify hooks prevent bad commits
- [ ] Test `--no-verify` bypass works

## Acceptance Criteria
- [x] `.pre-commit-config.yaml` created and configured
- [x] Hooks for Python (black, pylint, bandit)
- [x] Hooks for PowerShell (PSScriptAnalyzer)
- [x] Hooks for SQL (sqlfluff)
- [x] General hooks (trailing whitespace, large files, secrets)
- [x] Commit message validation (commitizen)
- [x] CI runs pre-commit hooks
- [x] Auto-update workflow configured
- [x] Documentation updated
- [x] Manual git hooks deprecated

## Related Files
- `.pre-commit-config.yaml` (to be created)
- `pyproject.toml` (to be created)
- `.pylintrc` (to be created)
- `.sqlfluffrc` (to be created)
- `scripts/install-hooks.sh` (to be updated)
- `docs/guides/git-hooks.md` (to be updated)
- `.github/workflows/pre-commit-autoupdate.yml` (to be created)

## Estimated Effort
**1-2 days** (setup, configuration, testing)

## Dependencies
- Issue #004 (Git Hooks) – replaces manual hooks

## Migration from Manual Hooks
- Manual hooks in `hooks/` directory can be deprecated
- Existing hook logic (post-commit, post-merge) can remain if needed
- Pre-commit handles pre-commit and commit-msg only

## References
- [Pre-Commit Framework](https://pre-commit.com/)
- [Supported Hooks](https://pre-commit.com/hooks.html)
- [Black Formatter](https://black.readthedocs.io/)
- [Commitizen](https://commitizen-tools.github.io/commitizen/)
