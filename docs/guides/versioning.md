# Versioning and Releases

This guide explains the versioning strategy and release process for the My-Scripts repository.

## Table of Contents

- [Version Scheme](#version-scheme)
- [Release Process](#release-process)
  - [Automated Release Workflow](#automated-release-workflow)
  - [Manual Release Process](#manual-release-process)
- [Version Bumping](#version-bumping)
- [Changelog Management](#changelog-management)
- [Module Versioning](#module-versioning)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Version Scheme

This repository follows [Semantic Versioning](https://semver.org/) (SemVer):

```
MAJOR.MINOR.PATCH
```

### Version Components

- **MAJOR** (X.0.0): Incompatible API changes or breaking changes
  - Breaking changes to module interfaces
  - Removal of deprecated features
  - Major refactoring that affects usage
  - Database schema changes requiring migration
  - Examples: `1.0.0 → 2.0.0`

- **MINOR** (x.Y.0): New features (backward-compatible)
  - New scripts or modules
  - New functionality in existing scripts
  - New optional parameters
  - Deprecations (but not removals)
  - Examples: `2.0.0 → 2.1.0`

- **PATCH** (x.y.Z): Bug fixes (backward-compatible)
  - Bug fixes
  - Documentation updates
  - Performance improvements
  - Security patches (if non-breaking)
  - Examples: `2.0.0 → 2.0.1`

### Pre-Release Versions

For pre-release versions, use the following format:

```
X.Y.Z-alpha.N    # Alpha releases
X.Y.Z-beta.N     # Beta releases
X.Y.Z-rc.N       # Release candidates
```

Examples:
- `2.1.0-alpha.1` - First alpha of version 2.1.0
- `2.1.0-beta.2` - Second beta of version 2.1.0
- `2.1.0-rc.1` - First release candidate of version 2.1.0

---

## Release Process

### Automated Release Workflow

The repository includes an automated release workflow that triggers on git tags.

#### Quick Release Steps

```bash
# 1. Bump version (updates VERSION and CHANGELOG.md)
./scripts/bump-version.sh [major|minor|patch]

# 2. Review and edit CHANGELOG.md
# Move unreleased items to the new version section

# 3. Commit changes
git commit -am "chore: release vX.Y.Z"

# 4. Create and push tag (triggers release workflow)
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --tags
```

#### What Happens Automatically

When you push a tag (e.g., `v2.1.0`), the GitHub Actions workflow:

1. **Validates** the version format
2. **Extracts** changelog section for this version
3. **Creates** a GitHub Release
4. **Generates** release notes from CHANGELOG.md
5. **Publishes** the release (optional: modules to registries)

View workflow: [.github/workflows/release.yml](../../.github/workflows/release.yml)

### Manual Release Process

If you prefer manual control:

1. **Update VERSION file**
   ```bash
   echo "2.1.0" > VERSION
   ```

2. **Update CHANGELOG.md**
   ```markdown
   ## [Unreleased]

   ## [2.1.0] - 2025-11-22
   ### Added
   - New feature X
   ### Fixed
   - Bug in feature Y
   ```

3. **Commit and tag**
   ```bash
   git commit -am "chore: release v2.1.0"
   git tag -a v2.1.0 -m "Release v2.1.0"
   git push origin main --tags
   ```

---

## Version Bumping

### Using bump-version.sh (Recommended)

The `scripts/bump-version.sh` script automates version bumping:

```bash
# Patch version bump (2.0.0 → 2.0.1)
./scripts/bump-version.sh patch

# Minor version bump (2.0.0 → 2.1.0)
./scripts/bump-version.sh minor

# Major version bump (2.0.0 → 3.0.0)
./scripts/bump-version.sh major
```

#### What the Script Does

1. Reads current version from `VERSION` file
2. Validates version format
3. Increments appropriate version component
4. Updates `VERSION` file
5. Adds new version section to `CHANGELOG.md`
6. Displays next steps

#### Script Output

```
Current version: 2.0.0
New version: 2.1.0
✓ Updated VERSION file
✓ Updated CHANGELOG.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version successfully bumped to 2.1.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next steps:
  1. Review changes in VERSION and CHANGELOG.md
  2. Edit CHANGELOG.md to move unreleased changes to [2.1.0] section
  3. Commit: git commit -am "chore: release v2.1.0"
  4. Tag: git tag -a v2.1.0 -m "Release v2.1.0"
  5. Push: git push origin main --tags
```

### Deciding Which Version to Bump

Use this decision tree:

```
Did you make breaking changes?
├─ Yes → MAJOR version (X.0.0)
└─ No
   └─ Did you add new features?
      ├─ Yes → MINOR version (x.Y.0)
      └─ No → PATCH version (x.y.Z)
```

#### Examples

**Patch Release** (Bug fixes only):
- Fixed infinite loop in `Clear-LogFile.ps1`
- Corrected typo in documentation
- Improved error message clarity

**Minor Release** (New features):
- Added new script `Backup-GnuCashDatabase.ps1`
- New optional parameter `-Verbose` to existing script
- New module `ErrorHandling`

**Major Release** (Breaking changes):
- Renamed required parameter from `-Path` to `-TargetPath`
- Removed deprecated function `Get-OldData`
- Changed module interface (removed public function)

---

## Changelog Management

### Changelog Format

This repository follows [Keep a Changelog](https://keepachangelog.com/) format.

#### Structure

```markdown
# Changelog

## [Unreleased]
### Added
- New features go here

### Changed
- Changes to existing features

### Fixed
- Bug fixes

### Deprecated
- Features marked for removal

### Removed
- Removed features

### Security
- Security fixes

## [2.1.0] - 2025-11-22
### Added
- Feature X (#123)
- Feature Y (#124)

### Fixed
- Bug in Z (#125)

## [2.0.0] - 2025-11-15
...
```

### Categories

Use these standard categories:

- **Added**: New features, scripts, or modules
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for future removal
- **Removed**: Removed features or scripts
- **Fixed**: Bug fixes
- **Security**: Security fixes or updates

### Writing Good Changelog Entries

✅ **Good Examples:**
```markdown
### Added
- **Automated Release Workflow** (#465) - GitHub Actions workflow for automated releases
  - Automatic changelog extraction
  - Git tag creation
  - GitHub Release publishing

### Fixed
- Fixed memory leak in `Backup-PostgreSqlCommon.ps1` (#470)
- Corrected path resolution in Windows batch wrappers (#471)
```

❌ **Bad Examples:**
```markdown
### Added
- Stuff

### Fixed
- Bug
```

### Referencing Issues

Always reference issue numbers when applicable:

```markdown
- Fixed timeout in database backup (#123)
- Added retry logic to file operations (#124, #125)
```

---

## Module Versioning

### PowerShell Modules

PowerShell modules have independent version numbers in their `.psd1` manifests:

```powershell
# src/powershell/modules/Database/PostgresBackup/PostgresBackup.psd1
@{
    ModuleVersion = '2.1.0'
    # ...
}
```

#### When to Update Module Versions

Update module versions when:
- Adding new functions to the module
- Changing existing function behavior
- Fixing bugs in module code

**Important:** Module versions should align with repository version for core modules.

### Python Modules

Python modules use `setup.py` for versioning:

```python
# src/python/modules/logging/setup.py
setup(
    name='my-scripts-logging',
    version='0.2.0',
    # ...
)
```

---

## Best Practices

### Before Releasing

✅ **Pre-Release Checklist:**

1. **All tests pass**
   ```bash
   # Python tests
   pytest

   # PowerShell tests
   pwsh -Command "Invoke-Pester tests/powershell/unit"
   ```

2. **Code quality checks pass**
   - SonarCloud quality gate
   - Pre-commit hooks
   - Code formatting

3. **Documentation is up to date**
   - README.md
   - Module documentation
   - Architecture docs (if changed)

4. **CHANGELOG.md is complete**
   - All changes documented
   - Proper categorization
   - Issue numbers referenced

5. **No outstanding critical bugs**

See [.github/RELEASE_CHECKLIST.md](../../.github/RELEASE_CHECKLIST.md) for full checklist.

### During Development

- **Keep CHANGELOG.md updated**: Add entries to `## [Unreleased]` as you work
- **Document breaking changes**: Clearly mark any breaking changes
- **Reference issues**: Link commits and changelog entries to issues
- **Test thoroughly**: Ensure changes work across platforms

### After Releasing

- **Verify the release**: Check GitHub Releases page
- **Announce if needed**: Communicate to stakeholders
- **Close milestone**: If using GitHub milestones
- **Plan next release**: Start new `[Unreleased]` section

---

## Troubleshooting

### Common Issues

#### 1. Version Already Exists in CHANGELOG

**Error:**
```
WARNING: Version 2.1.0 already exists in CHANGELOG.md
```

**Solution:**
```bash
# Edit CHANGELOG.md to remove duplicate section
# OR continue with bump-version.sh by answering 'y'
```

#### 2. Tag Already Exists

**Error:**
```
fatal: tag 'v2.1.0' already exists
```

**Solution:**
```bash
# Delete local tag
git tag -d v2.1.0

# Delete remote tag (if pushed)
git push origin :refs/tags/v2.1.0

# Recreate tag
git tag -a v2.1.0 -m "Release v2.1.0"
```

#### 3. Release Workflow Fails

**Check these:**

1. **CHANGELOG.md format**
   ```bash
   # Ensure version section exists
   grep "## \[2.1.0\]" CHANGELOG.md
   ```

2. **VERSION file format**
   ```bash
   # Should be: X.Y.Z (no 'v' prefix)
   cat VERSION
   ```

3. **Tag format**
   ```bash
   # Should be: vX.Y.Z (with 'v' prefix)
   git tag -l
   ```

#### 4. Changelog Not Extracted

**Ensure proper format:**
```markdown
## [Unreleased]

## [2.1.0] - 2025-11-22
### Added
- Feature description

## [2.0.0] - 2025-11-15
```

The workflow uses awk to extract between `## [2.1.0]` and the next `## [` heading.

### Getting Help

- Review [.github/RELEASE_CHECKLIST.md](../../.github/RELEASE_CHECKLIST.md)
- Check workflow logs in [Actions](https://github.com/manoj-bhaskaran/My-Scripts/actions)
- Examine [.github/workflows/release.yml](../../.github/workflows/release.yml)
- See [Keep a Changelog](https://keepachangelog.com/) for format details

---

## Examples

### Example 1: Patch Release (Bug Fix)

```bash
# 1. Fix bug in code
# 2. Update CHANGELOG.md under [Unreleased]
## [Unreleased]
### Fixed
- Fixed null reference error in Backup-PostgreSqlCommon.ps1 (#500)

# 3. Bump version
./scripts/bump-version.sh patch

# 4. Review changes
git diff VERSION CHANGELOG.md

# 5. Commit and tag
git commit -am "chore: release v2.0.1"
git tag -a v2.0.1 -m "Release v2.0.1"
git push origin main --tags
```

### Example 2: Minor Release (New Feature)

```bash
# 1. Develop new feature
# 2. Update CHANGELOG.md
## [Unreleased]
### Added
- **New Script: Export-DatabaseSchema.ps1** (#510)
  - Exports PostgreSQL schema to SQL file
  - Supports selective table export

# 3. Bump version
./scripts/bump-version.sh minor

# 4. Commit and tag
git commit -am "chore: release v2.1.0"
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin main --tags
```

### Example 3: Major Release (Breaking Change)

```bash
# 1. Implement breaking changes
# 2. Update CHANGELOG.md
## [Unreleased]
### Changed
- **⚠️ BREAKING:** Renamed all scripts to follow naming conventions (#454)
  - See RENAME_MAPPING.md for migration guide

# 3. Bump version
./scripts/bump-version.sh major

# 4. Commit and tag
git commit -am "chore: release v3.0.0"
git tag -a v3.0.0 -m "Release v3.0.0"
git push origin main --tags
```

---

## Additional Resources

- [Semantic Versioning Specification](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Repository Release Checklist](../../.github/RELEASE_CHECKLIST.md)
- [GitHub Actions Workflows](../../.github/workflows/)

---

## Summary

**Quick Reference:**

```bash
# Automated release (recommended)
./scripts/bump-version.sh [major|minor|patch]
# Review and edit CHANGELOG.md
git commit -am "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --tags

# Manual release
echo "X.Y.Z" > VERSION
# Edit CHANGELOG.md
git commit -am "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --tags
```

**Version Bump Rules:**
- Bug fixes → PATCH (x.y.Z)
- New features → MINOR (x.Y.0)
- Breaking changes → MAJOR (X.0.0)

**Changelog Format:**
- Keep entries under `[Unreleased]` during development
- Use standard categories: Added, Changed, Fixed, Deprecated, Removed, Security
- Reference issue numbers: `(#123)`
- Be specific and clear

For complete details, see the full [Release Checklist](../../.github/RELEASE_CHECKLIST.md).
