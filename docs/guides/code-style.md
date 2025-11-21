# Code Style Guide

## Overview

This repository uses automated formatters to maintain consistent code style across all languages. All code is automatically formatted and enforced through pre-commit hooks and CI/CD pipelines.

## Table of Contents

- [Python](#python)
- [PowerShell](#powershell)
- [SQL](#sql)
- [Editor Integration](#editor-integration)
- [Pre-Commit Hooks](#pre-commit-hooks)
- [CI/CD Enforcement](#cicd-enforcement)
- [Manual Formatting](#manual-formatting)

---

## Python

### Formatter: Black

**Configuration:** [`pyproject.toml`](../../pyproject.toml)

**Settings:**
- **Line Length:** 100 characters
- **Target Version:** Python 3.11
- **Style:** Black default (PEP 8 compliant)

### Format Code

```bash
# Format all Python files
black src/python/ tests/python/

# Check formatting without modifying files
black --check src/python/ tests/python/

# Show diff of formatting changes
black --diff src/python/ tests/python/
```

### Installation

```bash
pip install black>=24.1.0
```

### Example

**Before formatting:**
```python
def calculate_total(items,tax_rate=0.08,discount=None):
    subtotal=sum([item.price for item in items])
    if discount:subtotal-=discount
    total=subtotal*(1+tax_rate)
    return total
```

**After formatting:**
```python
def calculate_total(items, tax_rate=0.08, discount=None):
    subtotal = sum([item.price for item in items])
    if discount:
        subtotal -= discount
    total = subtotal * (1 + tax_rate)
    return total
```

### Key Style Points

- Indentation: 4 spaces
- Line length: 100 characters maximum
- String quotes: Double quotes preferred by Black
- Trailing commas: Added where appropriate
- Import organization: Use `isort` (integrated with Black)

---

## PowerShell

### Formatter: PSScriptAnalyzer / Invoke-Formatter

**Configuration:** [`scripts/Format-PowerShellCode.ps1`](../../scripts/Format-PowerShellCode.ps1)

**Settings:**
- **Indentation:** 4 spaces
- **Brace Style:** OTBS (One True Brace Style)
- **Line Length:** 120 characters (recommended)
- **Casing:** Correct PowerShell cmdlet casing

### Format Code

```bash
# Format all PowerShell files
pwsh ./scripts/Format-PowerShellCode.ps1

# Check formatting without modifying files
pwsh ./scripts/Format-PowerShellCode.ps1 -Check

# Format specific directory
pwsh ./scripts/Format-PowerShellCode.ps1 -Path src/powershell/system
```

### Installation

```powershell
Install-Module -Name PSScriptAnalyzer -Force
```

### Example

**Before formatting:**
```powershell
function Get-UserInfo{
param($Username,$ComputerName="localhost")
if($Username -eq $null){
throw "Username required"}
$user=Get-ADUser -Identity $Username -Properties *
return $user}
```

**After formatting:**
```powershell
function Get-UserInfo {
    param(
        $Username,
        $ComputerName = "localhost"
    )

    if ($Username -eq $null) {
        throw "Username required"
    }

    $user = Get-ADUser -Identity $Username -Properties *
    return $user
}
```

### Key Style Points

- **Indentation:** 4 spaces (no tabs)
- **Opening braces:** Same line as statement
- **Closing braces:** New line after
- **Whitespace:** Spaces around operators and after commas
- **Cmdlet casing:** Correct Pascal case (e.g., `Get-ChildItem`, not `get-childitem`)
- **Parameter alignment:** Align assignment statements in hashtables

---

## SQL

### Formatter: SQLFluff

**Configuration:** [`.sqlfluffrc`](../../.sqlfluffrc)

**Settings:**
- **Dialect:** PostgreSQL
- **Indentation:** 4 spaces
- **Line Length:** 120 characters
- **Keywords:** UPPERCASE
- **Identifiers:** lowercase

### Format Code

```bash
# Format all SQL files
sqlfluff fix src/sql/

# Check formatting without modifying files
sqlfluff lint src/sql/

# Format specific file
sqlfluff fix src/sql/gnucash/schema.sql
```

### Installation

```bash
pip install sqlfluff>=3.0.0
```

### Example

**Before formatting:**
```sql
select user_id,username,email from users where status='active' and created_date>='2024-01-01' order by username;
```

**After formatting:**
```sql
SELECT
    user_id,
    username,
    email
FROM users
WHERE
    status = 'active'
    AND created_date >= '2024-01-01'
ORDER BY username;
```

### Key Style Points

- **Keywords:** UPPERCASE (SELECT, FROM, WHERE, etc.)
- **Identifiers:** lowercase (table names, column names)
- **Functions:** UPPERCASE (COUNT, MAX, SUM, etc.)
- **Indentation:** 4 spaces
- **Line breaks:** One column per line in SELECT statements
- **Alignment:** Consistent alignment of WHERE conditions

---

## Editor Integration

### EditorConfig

The repository includes a [`.editorconfig`](../../.editorconfig) file that configures basic formatting rules for all file types.

**Supported editors:** VS Code, IntelliJ, Sublime Text, Vim, Emacs, and more.

### VS Code

**Settings:** [`.vscode/settings.json`](../../.vscode/settings.json)

**Features:**
- ✅ Format on save (enabled)
- ✅ Auto-organize imports (Python)
- ✅ Language-specific formatters
- ✅ Integrated linting

**Recommended Extensions:**
- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python) - Python language support
- [Black Formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter) - Black integration
- [PowerShell](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell) - PowerShell language support
- [SQLFluff](https://marketplace.visualstudio.com/items?itemName=dorzey.vscode-sqlfluff) - SQL formatting and linting
- [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig) - EditorConfig support

### Manual Configuration

If you're using a different editor, configure it to:
1. Use spaces for indentation
2. Set tab size to 4 for Python/PowerShell/SQL, 2 for YAML/JSON
3. Insert final newline
4. Trim trailing whitespace
5. Use UTF-8 encoding
6. Use LF line endings (Unix-style)

---

## Pre-Commit Hooks

Formatting is automatically checked on commit via the pre-commit framework.

### Installation

```bash
# Install pre-commit
pip install pre-commit

# Install git hooks
pre-commit install
```

### Hooks Configured

1. **Black** - Python code formatting
2. **PSScriptAnalyzer** - PowerShell linting and formatting check
3. **SQLFluff** - SQL formatting and linting

### Manual Run

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run black --all-files

# Run on staged files only
pre-commit run
```

### Bypass Hooks (Not Recommended)

```bash
# Skip pre-commit hooks (use sparingly)
git commit --no-verify -m "message"
```

---

## CI/CD Enforcement

### GitHub Actions Workflow

**Workflow:** [`.github/workflows/code-formatting.yml`](../../.github/workflows/code-formatting.yml)

**Checks:**
- ✅ Python formatting with Black
- ✅ PowerShell formatting
- ✅ SQL formatting with SQLFluff

**Triggers:**
- Push to `main`, `develop`, or `claude/**` branches
- Pull requests to `main` or `develop`

### Viewing Results

1. Navigate to **Actions** tab in GitHub
2. Select **Code Formatting** workflow
3. View detailed results for each language

### Fixing CI Failures

If the CI formatting check fails:

```bash
# Run the formatter locally
./scripts/format-all.sh

# Review changes
git diff

# Commit and push
git add .
git commit -m "style: fix code formatting"
git push
```

---

## Manual Formatting

### Format All Code

Use the convenience script to format all code at once:

```bash
# Format everything
./scripts/format-all.sh
```

This script runs:
1. Black on Python files
2. PowerShell formatter on PowerShell files
3. SQLFluff on SQL files

### Format by Language

**Python:**
```bash
black src/python/ tests/python/
```

**PowerShell:**
```bash
pwsh ./scripts/Format-PowerShellCode.ps1
```

**SQL:**
```bash
sqlfluff fix src/sql/
```

### Check Only (No Changes)

**Python:**
```bash
black --check src/python/ tests/python/
```

**PowerShell:**
```bash
pwsh ./scripts/Format-PowerShellCode.ps1 -Check
```

**SQL:**
```bash
sqlfluff lint src/sql/
```

---

## Best Practices

### 1. Enable Format on Save

Configure your editor to format code automatically when you save files. This ensures code is always properly formatted without manual intervention.

### 2. Run Pre-Commit Hooks

Always run pre-commit hooks before committing code:

```bash
pre-commit run --all-files
```

### 3. Review Formatting Changes

When formatters make changes, review them to ensure they don't alter logic:

```bash
git diff
```

### 4. Commit Formatting Separately

If you're making both functional and formatting changes, commit them separately:

```bash
# First commit: formatting
git add .
git commit -m "style: format code"

# Second commit: functional changes
git add .
git commit -m "feat: add new feature"
```

### 5. Use .git-blame-ignore-revs

To ignore formatting commits in `git blame`, add the commit hash to `.git-blame-ignore-revs`:

```bash
# After committing formatting changes
git rev-parse HEAD >> .git-blame-ignore-revs
```

Then configure git to use it:

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

---

## Troubleshooting

### Black Formatting Errors

**Issue:** Black fails with syntax error

**Solution:** Fix the syntax error first. Black only formats valid Python code.

```bash
# Check for syntax errors
python -m py_compile src/python/your_file.py
```

### PowerShell Formatter Not Found

**Issue:** `PSScriptAnalyzer` module not installed

**Solution:** Install the module:

```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

### SQLFluff Configuration Errors

**Issue:** SQLFluff doesn't recognize PostgreSQL syntax

**Solution:** Ensure `.sqlfluffrc` specifies the correct dialect:

```ini
[sqlfluff]
dialect = postgres
```

### Pre-Commit Hooks Not Running

**Issue:** Hooks don't execute on commit

**Solution:** Reinstall pre-commit hooks:

```bash
pre-commit uninstall
pre-commit install
```

---

## References

- [Black Formatter Documentation](https://black.readthedocs.io/)
- [PSScriptAnalyzer Documentation](https://github.com/PowerShell/PSScriptAnalyzer)
- [SQLFluff Documentation](https://docs.sqlfluff.com/)
- [EditorConfig Documentation](https://editorconfig.org/)
- [PEP 8 – Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [Pre-Commit Framework](https://pre-commit.com/)

---

## Support

For questions or issues with code formatting:

1. Check this documentation first
2. Review the configuration files referenced above
3. Consult the formatter documentation (links above)
4. Open an issue in the repository with details about the formatting problem
