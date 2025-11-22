# ISSUE-013: Standardize Version Handling Across Configuration Files

**Priority:** 🟡 MEDIUM
**Category:** Configuration / Build Management
**Estimated Effort:** 4 hours
**Skills Required:** Python, Build Tools, Configuration

---

## Problem Statement

Version information is inconsistent across files:
- `VERSION`: 2.0.0
- `pyproject.toml`: 1.0.0  
- `setup.py`: 0.2.0

This causes confusion and potential build issues.

---

## Acceptance Criteria
- [ ] VERSION file is single source of truth
- [ ] setup.py reads from VERSION
- [ ] pyproject.toml reads from VERSION
- [ ] All version references synchronized
- [ ] Build process verified

---

## Implementation

```python
# setup.py
from pathlib import Path

def get_version():
    return Path('VERSION').read_text().strip()

setup(
    name='my-scripts-logging',
    version=get_version(),
    # ...
)
```

```toml
# pyproject.toml
[project]
name = "my-scripts-logging"
dynamic = ["version"]

[tool.setuptools.dynamic]
version = {file = "VERSION"}
```

---

**Time:** Implementation: 2h, Testing: 1h, Documentation: 1h = **4 hours**
