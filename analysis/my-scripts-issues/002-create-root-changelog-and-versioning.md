# Create Root CHANGELOG and Versioning Strategy

## Priority
**HIGH** 🟠

## Background
The My-Scripts repository currently lacks repository-level versioning and change tracking:
- No `CHANGELOG.md` at repository root
- No `VERSION` file
- Only the Videoscreenshot module has a CHANGELOG (v3.0.1)
- Some scripts have internal version comments (FileDistributor 3.5.0)
- No git tags for releases
- Difficult to track breaking changes across the repository

This makes it challenging to:
- Understand what changed between updates
- Communicate breaking changes to users (self and potential future users)
- Roll back to previous working states
- Follow semantic versioning best practices

## Objectives
- Establish repository-level semantic versioning
- Create comprehensive CHANGELOG following Keep a Changelog format
- Document historical changes retroactively (where possible from git history)
- Set up version tracking infrastructure for future releases

## Tasks

### Phase 1: Create Versioning Infrastructure
- [ ] Create `VERSION` file at repository root with initial version `1.0.0`
- [ ] Create `CHANGELOG.md` at repository root following [Keep a Changelog](https://keepachangelog.com/) format
- [ ] Document semantic versioning strategy in `CHANGELOG.md` header:
  - **MAJOR:** Breaking changes to script interfaces or module APIs
  - **MINOR:** New features (new scripts, module enhancements, non-breaking functionality)
  - **PATCH:** Bug fixes, documentation updates, minor corrections

### Phase 2: Retroactive Documentation
- [ ] Review git history to identify major milestones:
  ```bash
  git log --oneline --graph --all --since="2024-01-01"
  ```
- [ ] Document significant changes in CHANGELOG:
  - Addition of Videoscreenshot module (v3.0.1)
  - FileDistributor enhancements (v3.5.0)
  - Logging specification implementation
  - CI/CD pipeline additions (SonarCloud, Dependabot)
  - Major script additions (create_github_issues.sh, etc.)
- [ ] Create initial "Unreleased" section for current work

### Phase 3: CHANGELOG Structure
- [ ] Set up CHANGELOG.md with standard sections:
  ```markdown
  # Changelog

  All notable changes to the My-Scripts repository will be documented in this file.

  The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
  and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

  ## [Unreleased]
  ### Added
  ### Changed
  ### Deprecated
  ### Removed
  ### Fixed
  ### Security

  ## [1.0.0] - YYYY-MM-DD
  ### Added
  - Initial repository structure with language-based organization
  - Videoscreenshot PowerShell module (v3.0.1)
  - Comprehensive logging specification
  - ...
  ```
- [ ] Ensure per-module CHANGELOGs reference root CHANGELOG

### Phase 4: Version Synchronization
- [ ] Update all module manifests with consistent versioning
- [ ] Ensure script header versions align with module versions
- [ ] Document version tracking in `docs/guides/versioning.md`:
  - How to update versions
  - When to bump MAJOR/MINOR/PATCH
  - How version flows: VERSION → modules → scripts

### Phase 5: Git Tagging Strategy
- [ ] Create initial tag for current state: `git tag -a v1.0.0 -m "Initial versioned release"`
- [ ] Document tagging convention:
  - Format: `vMAJOR.MINOR.PATCH` (e.g., `v1.0.0`)
  - Tag on main branch after CHANGELOG update
  - Tag message should reference CHANGELOG section
- [ ] Add tagging instructions to `CONTRIBUTING.md` (when created)

### Phase 6: Automation Preparation
- [ ] Create script to validate VERSION matches latest CHANGELOG entry
- [ ] Add version validation to git hooks (pre-commit)
- [ ] Document version bumping workflow:
  ```bash
  # 1. Update CHANGELOG.md [Unreleased] → [X.Y.Z]
  # 2. Update VERSION file
  # 3. Update module manifests if needed
  # 4. Commit: "chore: release vX.Y.Z"
  # 5. Tag: git tag -a vX.Y.Z -m "Release X.Y.Z"
  # 6. Push: git push origin main --tags
  ```

## Acceptance Criteria
- [x] `VERSION` file exists at repository root with semantic version
- [x] `CHANGELOG.md` exists at repository root
- [x] CHANGELOG follows Keep a Changelog format
- [x] At least one historical version documented (v1.0.0)
- [x] "Unreleased" section present for ongoing work
- [x] Semantic versioning strategy documented in CHANGELOG header
- [x] Initial git tag created (v1.0.0)
- [x] Versioning guide created in `docs/guides/versioning.md`
- [x] Version validation script created

## Related Files
- `VERSION` (to be created)
- `CHANGELOG.md` (to be created)
- `src/powershell/module/Videoscreenshot/CHANGELOG.md` (exists)
- `src/powershell/module/Videoscreenshot/Videoscreenshot.psd1`
- `src/powershell/module/RandomName/RandomName.psd1`
- `docs/guides/versioning.md` (to be created)

## Estimated Effort
**1-2 days** for initial creation, **ongoing** for maintenance

## Dependencies
None (foundational work)

## Example CHANGELOG Entry
```markdown
## [1.0.0] - 2025-11-16
### Added
- Comprehensive repository review and analysis
- Test infrastructure (Pester, pytest)
- Pre-commit framework for linting
- Root CHANGELOG and VERSION files
- Installation guide (INSTALLATION.md)

### Changed
- Standardized naming conventions (PowerShell: Verb-Noun, Python: snake_case)
- Reorganized folder structure by domain
- Activated git hooks for quality enforcement

### Fixed
- SonarCloud coverage reporting integration
- Module deployment configuration for all modules
```

## References
- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Videoscreenshot CHANGELOG Example](../src/powershell/module/Videoscreenshot/CHANGELOG.md)
