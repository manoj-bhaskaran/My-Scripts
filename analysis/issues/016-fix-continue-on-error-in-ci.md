# ISSUE-016: Remove continue-on-error from Critical CI Checks

**Priority:** 🟡 MEDIUM
**Category:** CI/CD / Quality Gates
**Estimated Effort:** 4 hours
**Skills Required:** GitHub Actions, CI/CD

---

## Problem Statement

`.github/workflows/sonarcloud.yml` uses `continue-on-error: true` on critical checks, allowing failures to be ignored.

---

## Acceptance Criteria
- [ ] Remove continue-on-error from pre-commit hooks
- [ ] Remove continue-on-error from linting (pylint, PSScriptAnalyzer)
- [ ] Remove continue-on-error from security scanning
- [ ] Make SonarCloud quality gate blocking
- [ ] Keep continue-on-error only for experimental/informational checks
- [ ] Update CI documentation

---

## Implementation

```yaml
# Before
- name: Run Pre-Commit Hooks
  run: pre-commit run --all-files
  continue-on-error: true  # ← Remove this

# After
- name: Run Pre-Commit Hooks
  run: pre-commit run --all-files
  # No continue-on-error - failures will block merge
```

Checklist:
- [ ] Pre-commit hooks - Should block
- [ ] Linting - Should block
- [ ] Security - Should block
- [ ] SonarCloud quality gate - Should block
- [ ] Code formatting - Should block

---

**Time:** Review workflows: 1h, Update files: 1h, Test changes: 1.5h, Documentation: 0.5h = **4 hours**
