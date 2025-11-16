# Standardize Naming Conventions Across Repository

## Priority
**HIGH** 🟠

## Background
The My-Scripts repository currently has **inconsistent naming conventions** across scripts:

**PowerShell Scripts – THREE conflicting patterns:**
| Pattern | Example | Count | Standard? |
|---------|---------|-------|-----------|
| Verb-Noun (PascalCase) | `Copy-AndroidFiles.ps1` | ~15 | ✅ PowerShell Best Practice |
| kebab-case | `cleanup-git-branches.ps1` | ~8 | ❌ Non-standard |
| camelCase | `logCleanup.ps1` | ~7 | ❌ Non-standard |

**Python Scripts – TWO conflicting patterns:**
| Pattern | Example | Count | Standard? |
|---------|---------|-------|-----------|
| snake_case | `cloudconvert_utils.py` | ~8 | ✅ PEP 8 Compliant |
| kebab-case | `csv-to-gpx.py` | ~3 | ❌ PEP 8 Violation |

This inconsistency:
- Reduces discoverability (users don't know which pattern to search for)
- Violates language best practices (PowerShell Approved Verbs, PEP 8)
- Looks unprofessional
- Confuses tab-completion behavior
- Makes tooling configuration harder

## Objectives
- Standardize all PowerShell scripts to **Verb-Noun (PascalCase)** format
- Standardize all Python scripts to **snake_case** format
- Update all references, imports, and documentation
- Preserve git history during renames
- Document naming standards for future scripts

## Tasks

### Phase 1: Inventory and Planning
- [ ] Create comprehensive list of scripts requiring rename:
  ```bash
  # PowerShell non-Verb-Noun
  find src/powershell -name "*.ps1" -not -path "*/module/*" | grep -E '(^[a-z]|-)'

  # Python non-snake_case
  find src/python -name "*.py" | grep -E '\-'
  ```
- [ ] Generate rename mapping:
  ```
  OLD NAME → NEW NAME (with justification)

  PowerShell:
  cleanup-git-branches.ps1 → Remove-StaleGitBranches.ps1 (Verb: Remove)
  logCleanup.ps1 → Clear-OldLogFiles.ps1 (Verb: Clear)
  picconvert.ps1 → Convert-ImageFormat.ps1 (Verb: Convert)
  post-commit-my-scripts.ps1 → Invoke-PostCommitHook.ps1 (Verb: Invoke)
  post-merge-my-scripts.ps1 → Invoke-PostMergeHook.ps1 (Verb: Invoke)
  ... (complete list in separate doc)

  Python:
  csv-to-gpx.py → csv_to_gpx.py (simple kebab→snake)
  find-duplicate-images.py → find_duplicate_images.py
  ... (complete list)
  ```
- [ ] Identify all references to renamed files (imports, docs, task scheduler, CI)

### Phase 2: PowerShell Verb Selection
- [ ] Review [PowerShell Approved Verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [ ] Map current script functionality to approved verbs:
  - **Common:** Get, Set, New, Remove, Clear, Copy, Move
  - **Data:** Backup, Restore, Export, Import, Convert
  - **Lifecycle:** Start, Stop, Invoke, Wait
  - **Diagnostic:** Test, Debug, Trace
- [ ] Ensure noun is singular (e.g., `Remove-StaleGitBranch` not `Remove-StaleGitBranches`)
- [ ] Document verb choices in rename mapping

### Phase 3: Execute Renames (Preserve History)
- [ ] Use `git mv` to preserve history:
  ```bash
  # PowerShell examples
  git mv src/powershell/cleanup-git-branches.ps1 src/powershell/Remove-StaleGitBranches.ps1
  git mv src/powershell/logCleanup.ps1 src/powershell/Clear-OldLogFiles.ps1
  git mv src/powershell/picconvert.ps1 src/powershell/Convert-ImageFormat.ps1

  # Python examples
  git mv src/python/csv-to-gpx.py src/python/csv_to_gpx.py
  git mv src/python/find-duplicate-images.py src/python/find_duplicate_images.py
  ```
- [ ] Commit renames separately from other changes:
  ```bash
  git commit -m "refactor: standardize PowerShell naming to Verb-Noun convention"
  git commit -m "refactor: standardize Python naming to snake_case convention"
  ```

### Phase 4: Update References
- [ ] Update Windows Task Scheduler XML files:
  ```bash
  grep -r "cleanup-git-branches.ps1" "Windows Task Scheduler/"
  # Replace with new names
  ```
- [ ] Update documentation:
  - `README.md` (if scripts mentioned)
  - Module READMEs (if referencing renamed scripts)
  - `docs/` files
- [ ] Update CI/CD workflows:
  - `.github/workflows/` (if specific scripts called)
- [ ] Update import statements in scripts that call renamed files
- [ ] Update git hook scripts if referencing old names

### Phase 5: Testing and Validation
- [ ] Create test script to verify all references updated:
  ```powershell
  # Check for old names in codebase
  $oldNames = @("cleanup-git-branches", "logCleanup", "csv-to-gpx")
  foreach ($name in $oldNames) {
      $results = Get-ChildItem -Recurse -File | Select-String -Pattern $name
      if ($results) {
          Write-Warning "Found reference to old name: $name"
          $results
      }
  }
  ```
- [ ] Verify Windows Task Scheduler tasks still work (if applicable)
- [ ] Verify git hooks still function
- [ ] Run full test suite (if tests exist)

### Phase 6: Documentation
- [ ] Create `docs/guides/naming-conventions.md`:
  ```markdown
  # Naming Conventions

  ## PowerShell Scripts
  - Format: `Verb-Noun.ps1` (PascalCase)
  - Verb: Must be from [Approved Verbs list]
  - Noun: Singular form, describes the target
  - Examples: `Get-LogFile.ps1`, `Remove-DuplicateFile.ps1`

  ## Python Scripts
  - Format: `module_name.py` (snake_case)
  - Follow PEP 8 naming conventions
  - Examples: `cloudconvert_utils.py`, `find_duplicate_images.py`

  ## Modules
  - PowerShell: PascalCase (e.g., `RandomName`, `Videoscreenshot`)
  - Python: snake_case (e.g., `python_logging_framework`)
  ```
- [ ] Add naming standards to root README.md
- [ ] Document rename mapping in CHANGELOG.md

### Phase 7: Future Enforcement
- [ ] Add linting rule to PSScriptAnalyzer for Verb-Noun validation
- [ ] Add pre-commit hook to validate naming conventions:
  ```yaml
  # .pre-commit-config.yaml
  - repo: local
    hooks:
      - id: powershell-naming
        name: Validate PowerShell Verb-Noun naming
        entry: scripts/validate-ps-naming.ps1
        language: system
        files: \.ps1$
  ```
- [ ] Create validation script `scripts/validate-ps-naming.ps1`
- [ ] Add naming convention check to CI

## Acceptance Criteria
- [x] 100% of PowerShell scripts follow Verb-Noun (PascalCase) convention
- [x] 100% of Python scripts follow snake_case convention
- [x] All PowerShell verbs are from Approved Verbs list
- [x] Git history preserved for all renamed files
- [x] All references updated (docs, CI, task scheduler, imports)
- [x] No broken imports or dead references
- [x] Naming conventions documented in `docs/guides/naming-conventions.md`
- [x] Pre-commit hook enforces naming standards
- [x] CHANGELOG documents all renames

## Breaking Changes
⚠️ **This is a BREAKING CHANGE** for:
- Users with hardcoded script paths
- Windows Task Scheduler tasks referencing old names
- External scripts calling renamed files
- Git hooks using old names

**Mitigation:**
- Document all renames in CHANGELOG
- Create migration guide showing old→new mapping
- Consider creating symlinks/aliases for critical renamed scripts (temporary)
- Bump repository MAJOR version (1.x.x → 2.0.0)

## Rename Mapping Document
Create `docs/RENAME_MAPPING.md`:
```markdown
# Script Rename Mapping (v2.0.0)

The following scripts were renamed to follow standard naming conventions:

## PowerShell (Verb-Noun Convention)
| Old Name | New Name | Reason |
|----------|----------|--------|
| cleanup-git-branches.ps1 | Remove-StaleGitBranches.ps1 | Approved verb "Remove" |
| logCleanup.ps1 | Clear-OldLogFiles.ps1 | Approved verb "Clear" |
| ... | ... | ... |

## Python (snake_case Convention)
| Old Name | New Name | Reason |
|----------|----------|--------|
| csv-to-gpx.py | csv_to_gpx.py | PEP 8 compliance |
| ... | ... | ... |
```

## Related Files
- All `src/powershell/*.ps1` files
- All `src/python/*.py` files
- `Windows Task Scheduler/*.xml`
- `.github/workflows/sonarcloud.yml`
- `README.md`
- `docs/guides/naming-conventions.md` (to be created)

## Estimated Effort
**2-3 days** (inventory, rename, testing, documentation)

## Dependencies
- None (can be done independently)
- Recommended: Complete before folder reorganization (Issue #006)

## References
- [PowerShell Approved Verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [PEP 8 – Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [PowerShell Cmdlet Naming Rules](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
