# ISSUE-023: Add Caching to CI/CD Pipelines

**Priority:** 🟡 MEDIUM
**Category:** DevOps / Performance
**Estimated Effort:** 4 hours
**Skills Required:** GitHub Actions, CI/CD

---

## Problem Statement

CI workflows don't cache dependencies, causing slower builds and wasted bandwidth.

---

## Acceptance Criteria
- [ ] Add pip caching for Python dependencies
- [ ] Add npm caching for sql-lint
- [ ] Add PowerShell module caching
- [ ] Verify cache hit/miss in workflows
- [ ] Document caching strategy

---

## Implementation

```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.11'
    cache: 'pip'

- name: Cache npm packages
  uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}
```

**Expected improvement:** 5 min → 3 min builds (40% faster)

---

**Time:** Implementation: 2h, Testing: 1h, Documentation: 1h = **4 hours**
