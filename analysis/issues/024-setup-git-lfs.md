# ISSUE-024: Configure Git LFS for Large Files

**Priority:** 🟡 MEDIUM
**Category:** Version Control / Performance
**Estimated Effort:** 4 hours
**Skills Required:** Git, Git LFS

---

## Problem Statement

No Git LFS configuration. Large files (videos, DB dumps) slow clones and waste bandwidth.

---

## Acceptance Criteria
- [ ] Install and configure Git LFS
- [ ] Track large file types (*.sql, *.mp4, *.zip, *.dump)
- [ ] Create .gitattributes
- [ ] Migrate existing large files to LFS
- [ ] Update documentation for contributors

---

## Implementation

```bash
git lfs install
git lfs track "*.sql"
git lfs track "*.dump"
git lfs track "*.mp4"
git lfs track "*.zip"
```

```.gitattributes
*.sql filter=lfs diff=lfs merge=lfs -text
*.dump filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text
```

---

**Time:** Setup: 1.5h, Migration: 1.5h, Documentation: 1h = **4 hours**
