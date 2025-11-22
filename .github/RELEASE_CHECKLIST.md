# Release Checklist

Use this checklist when preparing a new release of the My-Scripts repository.

## Pre-Release Checks

Before creating a new release, ensure all of the following are complete:

### Code Quality
- [ ] All tests passing (Python and PowerShell)
- [ ] SonarCloud quality gate passing
- [ ] No critical code smells or security issues
- [ ] Code coverage meets minimum thresholds (30% for shared modules)
- [ ] All pre-commit hooks passing
- [ ] Code formatting checks passing (Black, PSScriptAnalyzer, SQLFluff)

### Documentation
- [ ] CHANGELOG.md updated with all changes in this release
  - [ ] All changes categorized (Added, Changed, Fixed, Deprecated, Removed, Security)
  - [ ] Issue numbers referenced where applicable
  - [ ] Breaking changes clearly marked
- [ ] README.md updated if new features added
- [ ] Module documentation updated (if modules changed)
- [ ] Architecture documentation updated (if architecture changed)
- [ ] Version number in README.md matches VERSION file

### Testing
- [ ] Manual testing completed for major changes
- [ ] Integration tests passing (if applicable)
- [ ] No outstanding critical bugs
- [ ] Known issues documented

### Version Management
- [ ] VERSION file exists and contains correct version number
- [ ] Module manifests updated with new version (if modules changed)
  - [ ] PostgresBackup module
  - [ ] PowerShellLoggingFramework module
  - [ ] PurgeLogs module
  - [ ] RandomName module
  - [ ] Videoscreenshot module
- [ ] Python package version updated in setup.py (if applicable)

## Release Process

Follow these steps to create a release:

### 1. Update CHANGELOG

Move all unreleased changes to the new version section:

```bash
# Edit CHANGELOG.md manually or use bump-version.sh (recommended)
./scripts/bump-version.sh [major|minor|patch]
```

The script will:
- Update VERSION file
- Add new version section to CHANGELOG.md with today's date
- Prompt you to review changes

**Manual alternative:**
```markdown
## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD
### Added
- Feature 1
- Feature 2
...
```

### 2. Review Changes

```bash
# Review VERSION file
cat VERSION

# Review CHANGELOG.md
git diff CHANGELOG.md

# Check for any uncommitted changes
git status
```

### 3. Commit and Tag

```bash
# Commit the version bump
git commit -am "chore: release vX.Y.Z"

# Create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# Verify tag
git tag -l vX.Y.Z
git show vX.Y.Z
```

### 4. Push to Repository

```bash
# Push commits
git push origin main

# Push tags (this triggers the release workflow)
git push origin --tags
```

### 5. Monitor Release Workflow

- [ ] Go to [Actions](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/release.yml)
- [ ] Verify release workflow starts and completes successfully
- [ ] Check for any errors in workflow logs

### 6. Verify Release

After the workflow completes:

- [ ] Visit [Releases](https://github.com/manoj-bhaskaran/My-Scripts/releases)
- [ ] Verify new release is created
- [ ] Check release notes are correctly populated from CHANGELOG
- [ ] Verify release assets (if any)
- [ ] Test download links (if applicable)

## Post-Release

### Immediate Actions
- [ ] Verify release appears in GitHub Releases page
- [ ] Check that release notes are accurate and complete
- [ ] Verify git tag exists: `git tag -l vX.Y.Z`
- [ ] (Optional) Test module installation from PowerShell Gallery / PyPI

### Communication
- [ ] Announce release (if applicable)
  - [ ] Update documentation site (if exists)
  - [ ] Notify users/stakeholders (if applicable)
  - [ ] Post on internal communication channels (if applicable)

### GitHub Project Management
- [ ] Close related milestone (if using milestones)
- [ ] Close related issues (if not auto-closed)
- [ ] Update project boards (if using projects)

### Future Planning
- [ ] Review release process - document any improvements needed
- [ ] Update this checklist if any steps were unclear or missing
- [ ] Plan next release milestones

## Version Numbering Guide

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes
  - Incompatible API changes
  - Major refactoring
  - Removal of deprecated features
  - Database schema changes requiring migration

- **MINOR** (x.Y.0): New features (backward-compatible)
  - New scripts or modules
  - New functionality in existing scripts
  - Deprecations (but not removals)
  - Internal improvements

- **PATCH** (x.y.Z): Bug fixes (backward-compatible)
  - Bug fixes
  - Documentation updates
  - Performance improvements
  - Security patches (if non-breaking)

## Rollback Procedure

If you need to rollback a release:

### Delete the Release (GitHub)
1. Go to [Releases](https://github.com/manoj-bhaskaran/My-Scripts/releases)
2. Find the problematic release
3. Click "Delete release" (this does NOT delete the tag)

### Delete the Tag
```bash
# Delete local tag
git tag -d vX.Y.Z

# Delete remote tag
git push origin :refs/tags/vX.Y.Z
```

### Revert VERSION and CHANGELOG
```bash
# Revert the version bump commit
git revert <commit-hash>

# Or manually edit VERSION and CHANGELOG.md
git checkout HEAD~1 VERSION CHANGELOG.md
git commit -m "chore: rollback release vX.Y.Z"
git push origin main
```

## Troubleshooting

### Release workflow fails
- Check workflow logs in Actions tab
- Verify CHANGELOG.md has entry for the version
- Ensure VERSION file format is correct (X.Y.Z)
- Check that tag format is correct (vX.Y.Z)

### Changelog extraction fails
- Ensure version section exists in CHANGELOG.md: `## [X.Y.Z] - YYYY-MM-DD`
- Check for proper markdown formatting
- Verify no special characters breaking the awk command

### Tag already exists
```bash
# Delete and recreate tag
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

## Manual Release (Workflow Dispatch)

To create a release manually without pushing a tag:

1. Go to [Actions > Release](https://github.com/manoj-bhaskaran/My-Scripts/actions/workflows/release.yml)
2. Click "Run workflow"
3. Select the branch
4. Click "Run workflow"

The workflow will:
- Read version from VERSION file
- Extract changelog for that version
- Create release with tag vX.Y.Z

## Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Repository Versioning Guide](../docs/guides/versioning.md)
