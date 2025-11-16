# Create Automated Release Workflow

## Priority
**LOW** 🟢

## Background
The My-Scripts repository has **no automated release process**:

**Current State:**
- No git tags for releases
- No GitHub Releases
- Manual version bumping
- No release notes generation
- No automated changelog updates

**Impact:**
- Difficult to track versions over time
- No clear release history
- Manual release process error-prone
- Can't easily roll back to previous versions

## Objectives
- Create automated release workflow (GitHub Actions)
- Implement semantic version bumping
- Auto-generate release notes from CHANGELOG
- Create git tags automatically
- Optionally publish modules to registries

## Tasks

### Phase 1: Versioning Strategy
- [ ] Ensure `VERSION` file exists (from Issue #002)
- [ ] Ensure `CHANGELOG.md` follows Keep a Changelog format
- [ ] Define release triggers:
  - **Manual**: Workflow dispatch
  - **Automatic**: On version bump commit to main branch
- [ ] Document versioning workflow in `docs/guides/versioning.md`

### Phase 2: Create Release Workflow
- [ ] Create `.github/workflows/release.yml`:
  ```yaml
  name: Release

  on:
    push:
      tags:
        - 'v*'  # Trigger on version tags (v1.0.0, v2.1.3, etc.)

  permissions:
    contents: write
    pull-requests: write

  jobs:
    release:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4
          with:
            fetch-depth: 0  # Full history for changelog

        - name: Get version from tag
          id: get_version
          run: |
            VERSION=${GITHUB_REF#refs/tags/v}
            echo "version=$VERSION" >> $GITHUB_OUTPUT

        - name: Extract changelog for version
          id: changelog
          run: |
            # Extract section from CHANGELOG.md for this version
            VERSION=${{ steps.get_version.outputs.version }}
            CHANGELOG=$(awk "/## \[$VERSION\]/,/## \[/" CHANGELOG.md | sed '1d;$d')
            echo "changelog<<EOF" >> $GITHUB_OUTPUT
            echo "$CHANGELOG" >> $GITHUB_OUTPUT
            echo "EOF" >> $GITHUB_OUTPUT

        - name: Create GitHub Release
          uses: actions/create-release@v1
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          with:
            tag_name: ${{ github.ref }}
            release_name: Release v${{ steps.get_version.outputs.version }}
            body: ${{ steps.changelog.outputs.changelog }}
            draft: false
            prerelease: false

        - name: Upload release assets (optional)
          # Optional: Package and upload PowerShell modules, etc.
          run: echo "Implement asset packaging if needed"
  ```

### Phase 3: Version Bumping Script
- [ ] Create `scripts/bump-version.sh`:
  ```bash
  #!/bin/bash
  # Semantic version bumping script

  set -e

  CURRENT_VERSION=$(cat VERSION)
  echo "Current version: $CURRENT_VERSION"

  # Parse arguments
  BUMP_TYPE=${1:-patch}  # major, minor, patch

  # Parse current version
  IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
  MAJOR="${VERSION_PARTS[0]}"
  MINOR="${VERSION_PARTS[1]}"
  PATCH="${VERSION_PARTS[2]}"

  # Bump version
  case $BUMP_TYPE in
    major)
      MAJOR=$((MAJOR + 1))
      MINOR=0
      PATCH=0
      ;;
    minor)
      MINOR=$((MINOR + 1))
      PATCH=0
      ;;
    patch)
      PATCH=$((PATCH + 1))
      ;;
    *)
      echo "Invalid bump type: $BUMP_TYPE"
      echo "Usage: $0 [major|minor|patch]"
      exit 1
      ;;
  esac

  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  echo "New version: $NEW_VERSION"

  # Update VERSION file
  echo "$NEW_VERSION" > VERSION

  # Update CHANGELOG.md (move Unreleased to new version)
  TODAY=$(date +%Y-%m-%d)
  sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [$NEW_VERSION] - $TODAY/" CHANGELOG.md

  echo "Version bumped to $NEW_VERSION"
  echo "Next steps:"
  echo "  1. Review changes in VERSION and CHANGELOG.md"
  echo "  2. Commit: git commit -am \"chore: release v$NEW_VERSION\""
  echo "  3. Tag: git tag -a v$NEW_VERSION -m \"Release v$NEW_VERSION\""
  echo "  4. Push: git push origin main --tags"
  ```
- [ ] Make executable: `chmod +x scripts/bump-version.sh`
- [ ] Test version bumping

### Phase 4: PowerShell Module Publishing (Optional)
- [ ] Create `scripts/Publish-Modules.ps1`:
  ```powershell
  <#
  .SYNOPSIS
      Publishes PowerShell modules to PowerShell Gallery

  .PARAMETER ApiKey
      PowerShell Gallery API key
  #>
  param(
      [Parameter(Mandatory)]
      [string]$ApiKey
  )

  $modules = @(
      'src/powershell/modules/Database/PostgresBackup'
      'src/powershell/modules/Utilities/RandomName'
      'src/powershell/modules/Media/Videoscreenshot'
      'src/powershell/modules/Core/Logging/PowerShellLoggingFramework'
      'src/powershell/modules/Core/Logging/PurgeLogs'
  )

  foreach ($modulePath in $modules) {
      Write-Host "Publishing module: $modulePath"

      # Test module manifest
      Test-ModuleManifest (Join-Path $modulePath '*.psd1')

      # Publish to PowerShell Gallery
      Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Verbose
  }
  ```
- [ ] Add to release workflow (optional):
  ```yaml
  - name: Publish PowerShell Modules
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
    env:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
    shell: pwsh
    run: |
      .\scripts\Publish-Modules.ps1 -ApiKey $env:PSGALLERY_API_KEY
  ```

### Phase 5: Python Package Publishing (Optional)
- [ ] Update `src/python/modules/logging/setup.py` for PyPI
- [ ] Create `scripts/publish-python-modules.sh`:
  ```bash
  #!/bin/bash
  # Publish Python modules to PyPI

  pip install build twine

  # Build package
  cd src/python/modules/logging
  python -m build

  # Upload to PyPI
  python -m twine upload dist/*
  ```
- [ ] Add to release workflow (optional):
  ```yaml
  - name: Publish Python Modules
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
    env:
      TWINE_USERNAME: __token__
      TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
    run: |
      ./scripts/publish-python-modules.sh
  ```

### Phase 6: Release Checklist
- [ ] Create `.github/RELEASE_CHECKLIST.md`:
  ```markdown
  # Release Checklist

  Before creating a new release:

  ## Pre-Release
  - [ ] All tests passing
  - [ ] CHANGELOG.md updated with all changes
  - [ ] Version bumped in VERSION file
  - [ ] Module manifests updated (if applicable)
  - [ ] Documentation updated
  - [ ] No outstanding critical bugs

  ## Release Process
  1. **Update CHANGELOG:**
     - Move [Unreleased] items to new version section
     - Add release date

  2. **Bump Version:**
     ```bash
     ./scripts/bump-version.sh [major|minor|patch]
     ```

  3. **Commit and Tag:**
     ```bash
     git commit -am "chore: release vX.Y.Z"
     git tag -a vX.Y.Z -m "Release vX.Y.Z"
     git push origin main --tags
     ```

  4. **Verify Release:**
     - Check GitHub Actions workflow completes
     - Verify GitHub Release created
     - Check release notes accuracy
     - (Optional) Verify modules published to registries

  ## Post-Release
  - [ ] Announce release (if applicable)
  - [ ] Update documentation site (if applicable)
  - [ ] Close milestone (if using milestones)
  ```

### Phase 7: Documentation
- [ ] Update `docs/guides/versioning.md`:
  ```markdown
  # Versioning and Releases

  ## Version Scheme
  This repository follows [Semantic Versioning](https://semver.org/):
  - **MAJOR**: Breaking changes
  - **MINOR**: New features (backward-compatible)
  - **PATCH**: Bug fixes (backward-compatible)

  ## Release Process

  ### 1. Prepare Release
  - Update CHANGELOG.md
  - Ensure all tests pass
  - Review documentation

  ### 2. Bump Version
  ```bash
  ./scripts/bump-version.sh [major|minor|patch]
  ```

  ### 3. Commit and Tag
  ```bash
  git commit -am "chore: release vX.Y.Z"
  git tag -a vX.Y.Z -m "Release vX.Y.Z"
  git push origin main --tags
  ```

  ### 4. Automated Actions
  GitHub Actions will automatically:
  - Extract changelog for version
  - Create GitHub Release
  - (Optional) Publish modules to registries

  ## Manual Release (Workflow Dispatch)
  Alternatively, trigger release manually via GitHub UI:
  1. Go to Actions → Release workflow
  2. Click "Run workflow"
  3. Select branch and version type
  ```
- [ ] Update README.md with release information

### Phase 8: Git Blame Ignore File
- [ ] Create `.git-blame-ignore-revs`:
  ```
  # Ignore formatting commits when using git blame
  # Usage: git config blame.ignoreRevsFile .git-blame-ignore-revs

  # Initial code formatting (Issue #013)
  <commit-hash-of-formatting-commit>

  # Other bulk changes
  ```
- [ ] Document usage in contributing guide

## Acceptance Criteria
- [x] Release workflow created (`.github/workflows/release.yml`)
- [x] Version bumping script created and tested
- [x] Workflow creates GitHub Releases automatically
- [x] Release notes extracted from CHANGELOG
- [x] Git tags created on release
- [x] Release checklist documented
- [x] Versioning guide updated
- [x] (Optional) Module publishing configured
- [x] Workflow tested on pre-release branch

## Testing
- [ ] Create test tag on feature branch:
  ```bash
  git checkout -b test-release
  echo "1.0.0-rc1" > VERSION
  git commit -am "test: release candidate"
  git tag -a v1.0.0-rc1 -m "Release candidate"
  git push origin test-release --tags
  ```
- [ ] Verify workflow runs
- [ ] Verify release draft created
- [ ] Delete test release and tag

## Related Files
- `.github/workflows/release.yml` (to be created)
- `scripts/bump-version.sh` (to be created)
- `scripts/Publish-Modules.ps1` (to be created, optional)
- `scripts/publish-python-modules.sh` (to be created, optional)
- `.github/RELEASE_CHECKLIST.md` (to be created)
- `docs/guides/versioning.md` (to be updated)
- `VERSION` (from Issue #002)
- `CHANGELOG.md` (from Issue #002)

## Estimated Effort
**1-2 days** (workflow creation, testing, documentation)

## Dependencies
- Issue #002 (Versioning) – VERSION and CHANGELOG must exist
- GitHub repository settings (enable Actions, Releases)
- (Optional) PowerShell Gallery account + API key
- (Optional) PyPI account + API token

## Security Considerations
- ⚠️ API keys stored as GitHub Secrets (never in code)
- ✅ Secrets: `PSGALLERY_API_KEY`, `PYPI_API_TOKEN`
- ✅ Use minimal permissions for tokens

## References
- [Semantic Versioning](https://semver.org/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [PowerShell Gallery Publishing](https://learn.microsoft.com/en-us/powershell/gallery/how-to/publishing-packages/publishing-a-package)
- [PyPI Publishing](https://packaging.python.org/en/latest/tutorials/packaging-projects/)
