# ISSUE-014: Pin and Test All Dependency Versions

**Priority:** 🟡 MEDIUM
**Category:** Dependencies / Build Reproducibility
**Estimated Effort:** 5 hours
**Skills Required:** Python, Dependency Management

---

## Problem Statement

`requirements.txt` has unpinned dependencies (e.g., `requests`, `numpy`) causing non-deterministic builds.

---

## Acceptance Criteria
- [ ] All dependencies pinned to specific versions
- [ ] requirements.txt updated with frozen versions
- [ ] Dependency update process documented
- [ ] Tests pass with pinned versions

---

## Implementation

```txt
# requirements.txt (updated)
requests==2.31.0
numpy==1.24.3
pandas==2.0.3
opencv-python==4.8.1.78
pytest==7.4.3
black==24.1.1
```

Create `scripts/update-dependencies.sh`:
```bash
#!/bin/bash
python -m venv .venv-temp
source .venv-temp/bin/activate
pip install --upgrade -r requirements.txt
pip freeze > requirements-frozen.txt
```

---

**Time:** Pin versions: 1h, Test: 2h, Update process: 1h, Documentation: 1h = **5 hours**
