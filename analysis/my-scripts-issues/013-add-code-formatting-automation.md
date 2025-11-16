# Add Code Formatting Automation

## Priority
**LOW** 🟢

## Background
The My-Scripts repository has **no automated code formatting**:

**Current State:**
- PowerShell: Manual formatting, inconsistent styles
- Python: No Black/autopep8 enforcement
- SQL: No SQL formatter
- Mixed indentation (tabs vs spaces)
- Inconsistent line lengths

**Impact:**
- Code review time spent on style debates
- Inconsistent code style across scripts
- Difficult to read diffs (formatting noise)
- Manual formatting burden

## Objectives
- Implement automated formatters for all languages
- Standardize code style across repository
- Integrate formatting into git hooks and CI
- Document code style guidelines

## Tasks

### Phase 1: Python Formatting (Black)
- [ ] Add Black to `requirements.txt`:
  ```txt
  black>=24.1.0
  ```
- [ ] Configure Black in `pyproject.toml`:
  ```toml
  [tool.black]
  line-length = 100
  target-version = ['py311']
  include = '\.pyi?$'
  exclude = '''
  /(
      \.git
    | \.venv
    | build
    | dist
  )/
  '''
  ```
- [ ] Format all Python files:
  ```bash
  black src/python/ tests/python/
  ```
- [ ] Add to pre-commit config (from Issue #012)
- [ ] Add to CI:
  ```yaml
  - name: Check Python Formatting
    run: black --check src/python/ tests/python/
  ```

### Phase 2: PowerShell Formatting
- [ ] Install PowerShell formatter:
  ```powershell
  Install-Module -Name PSScriptAnalyzer -Force
  ```
- [ ] Create formatting script `scripts/Format-PowerShellCode.ps1`:
  ```powershell
  <#
  .SYNOPSIS
      Formats all PowerShell scripts using PSScriptAnalyzer
  #>
  param(
      [switch]$Check  # Check only, don't modify
  )

  $settings = @{
      Rules = @{
          PSPlaceOpenBrace = @{
              Enable = $true
              OnSameLine = $true
          }
          PSPlaceCloseBrace = @{
              Enable = $true
              NewLineAfter = $true
          }
          PSUseConsistentIndentation = @{
              Enable = $true
              IndentationSize = 4
              Kind = 'space'
          }
          PSUseConsistentWhitespace = @{
              Enable = $true
          }
      }
  }

  $files = Get-ChildItem -Recurse -Include *.ps1,*.psm1 -Exclude *.Tests.ps1

  foreach ($file in $files) {
      if ($Check) {
          Invoke-ScriptAnalyzer -Path $file -Settings $settings
      } else {
          Invoke-Formatter -ScriptDefinition (Get-Content $file -Raw) -Settings $settings |
              Set-Content $file
      }
  }
  ```
- [ ] Format all PowerShell files
- [ ] Add to pre-commit:
  ```yaml
  - repo: local
    hooks:
      - id: powershell-format
        name: Format PowerShell
        entry: pwsh scripts/Format-PowerShellCode.ps1 -Check
        language: system
        files: \.(ps1|psm1)$
  ```

### Phase 3: SQL Formatting
- [ ] Use SQLFluff for formatting:
  ```bash
  pip install sqlfluff
  ```
- [ ] Configure in `.sqlfluffrc`:
  ```ini
  [sqlfluff]
  dialect = postgres
  templater = raw
  max_line_length = 120

  [sqlfluff:indentation]
  indent_unit = space
  tab_space_size = 4

  [sqlfluff:rules:capitalisation.keywords]
  capitalisation_policy = upper
  ```
- [ ] Format all SQL files:
  ```bash
  sqlfluff fix src/sql/ timeline_data/
  ```
- [ ] Add to pre-commit (already in Issue #012 config)

### Phase 4: Editor Configuration
- [ ] Create `.editorconfig`:
  ```ini
  # EditorConfig: https://editorconfig.org
  root = true

  [*]
  charset = utf-8
  end_of_line = lf
  insert_final_newline = true
  trim_trailing_whitespace = true

  [*.{ps1,psm1,psd1}]
  indent_style = space
  indent_size = 4

  [*.py]
  indent_style = space
  indent_size = 4
  max_line_length = 100

  [*.sql]
  indent_style = space
  indent_size = 4
  max_line_length = 120

  [*.{yml,yaml}]
  indent_style = space
  indent_size = 2

  [*.{json,md}]
  indent_style = space
  indent_size = 2
  ```
- [ ] Update `.vscode/settings.json`:
  ```json
  {
    "editor.formatOnSave": true,
    "python.formatting.provider": "black",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "[powershell]": {
      "editor.formatOnSave": true,
      "editor.tabSize": 4
    },
    "powershell.codeFormatting.preset": "OTBS"
  }
  ```

### Phase 5: Format All Code
- [ ] Create `scripts/format-all.sh`:
  ```bash
  #!/bin/bash
  # Format all code in repository

  echo "Formatting Python code..."
  black src/python/ tests/python/

  echo "Formatting PowerShell code..."
  pwsh scripts/Format-PowerShellCode.ps1

  echo "Formatting SQL code..."
  sqlfluff fix src/sql/ timeline_data/

  echo "All code formatted!"
  ```
- [ ] Run formatter on entire codebase
- [ ] Commit formatting changes:
  ```bash
  git commit -m "style: format all code with automated formatters"
  ```

### Phase 6: CI Enforcement
- [ ] Update CI to enforce formatting:
  ```yaml
  # .github/workflows/sonarcloud.yml
  - name: Check Code Formatting
    run: |
      # Python
      black --check src/python/ tests/python/

      # PowerShell
      pwsh scripts/Format-PowerShellCode.ps1 -Check

      # SQL
      sqlfluff lint src/sql/ timeline_data/
  ```
- [ ] Fail CI if code is not formatted

### Phase 7: Documentation
- [ ] Create `docs/guides/code-style.md`:
  ```markdown
  # Code Style Guide

  ## Overview
  This repository uses automated formatters to maintain consistent code style.

  ## Python (Black)
  - **Formatter**: Black
  - **Line Length**: 100 characters
  - **Target**: Python 3.11

  **Format Code:**
  ```bash
  black src/python/ tests/python/
  ```

  ## PowerShell
  - **Formatter**: PSScriptAnalyzer / Invoke-Formatter
  - **Indentation**: 4 spaces
  - **Brace Style**: OTBS (One True Brace Style)

  **Format Code:**
  ```powershell
  .\scripts\Format-PowerShellCode.ps1
  ```

  ## SQL
  - **Formatter**: SQLFluff
  - **Dialect**: PostgreSQL
  - **Keywords**: UPPERCASE

  **Format Code:**
  ```bash
  sqlfluff fix src/sql/
  ```

  ## Editor Integration
  - Use `.editorconfig` settings
  - Enable "Format on Save" in your editor
  - VS Code settings in `.vscode/settings.json`

  ## Pre-Commit Hooks
  Formatting is automatically checked on commit via pre-commit framework.

  To manually format before commit:
  ```bash
  ./scripts/format-all.sh
  ```
  ```
- [ ] Update README.md with code style section
- [ ] Add to CONTRIBUTING.md (if created)

### Phase 8: Style Enforcement
- [ ] Add formatting badge to README.md:
  ```markdown
  [![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
  ```
- [ ] Document style guide in PR template (if created)

## Acceptance Criteria
- [x] Black configured and applied to all Python code
- [x] PSScriptAnalyzer configured for PowerShell formatting
- [x] SQLFluff configured for SQL formatting
- [x] `.editorconfig` created for editor consistency
- [x] All code formatted with automated tools
- [x] Pre-commit hooks enforce formatting
- [x] CI fails on formatting violations
- [x] `scripts/format-all.sh` script created
- [x] Code style documentation created
- [x] Formatting is consistent across entire codebase

## Breaking Changes
⚠️ **This will reformat all code** – Large diff expected

**Mitigation:**
- Commit formatting changes separately
- Use `git blame --ignore-rev` to skip formatting commits
- Create `.git-blame-ignore-revs` file:
  ```
  # Ignore formatting commits
  <commit-hash-of-formatting-commit>
  ```

## Related Files
- `pyproject.toml` (Black config)
- `.sqlfluffrc` (SQLFluff config)
- `.editorconfig` (to be created)
- `.vscode/settings.json` (to be updated)
- `scripts/Format-PowerShellCode.ps1` (to be created)
- `scripts/format-all.sh` (to be created)
- `docs/guides/code-style.md` (to be created)
- `.pre-commit-config.yaml` (from Issue #012)

## Estimated Effort
**1 day** (configuration, formatting, documentation)

## Dependencies
- Issue #012 (Pre-Commit Framework) – for hook integration

## References
- [Black Formatter](https://black.readthedocs.io/)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [SQLFluff](https://www.sqlfluff.com/)
- [EditorConfig](https://editorconfig.org/)
- [PEP 8](https://peps.python.org/pep-0008/)
