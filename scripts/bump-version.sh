#!/bin/bash
# Semantic version bumping script
# Version: 1.0.0
#
# Description:
#   Automates semantic version bumping for the My-Scripts repository.
#   Updates VERSION file and CHANGELOG.md with the new version.
#
# Usage:
#   ./scripts/bump-version.sh [major|minor|patch]
#
# Examples:
#   ./scripts/bump-version.sh patch   # 2.0.0 -> 2.0.1
#   ./scripts/bump-version.sh minor   # 2.0.0 -> 2.1.0
#   ./scripts/bump-version.sh major   # 2.0.0 -> 3.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if VERSION file exists
if [ ! -f "VERSION" ]; then
    echo -e "${RED}ERROR: VERSION file not found in repository root${NC}"
    exit 1
fi

# Check if CHANGELOG.md exists
if [ ! -f "CHANGELOG.md" ]; then
    echo -e "${RED}ERROR: CHANGELOG.md file not found in repository root${NC}"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION | tr -d '[:space:]')
echo -e "${GREEN}Current version: ${CURRENT_VERSION}${NC}"

# Parse arguments
BUMP_TYPE=${1:-patch}  # major, minor, patch

# Validate bump type
case $BUMP_TYPE in
  major|minor|patch)
    # Valid bump type
    ;;
  *)
    echo -e "${RED}Invalid bump type: $BUMP_TYPE${NC}"
    echo "Usage: $0 [major|minor|patch]"
    exit 1
    ;;
esac

# Parse current version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"

# Validate version format
if [ ${#VERSION_PARTS[@]} -ne 3 ]; then
    echo -e "${RED}ERROR: Invalid version format in VERSION file: $CURRENT_VERSION${NC}"
    echo "Expected format: MAJOR.MINOR.PATCH (e.g., 2.0.0)"
    exit 1
fi

MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Validate version parts are numeric
if ! [[ "$MAJOR" =~ ^[0-9]+$ ]] || ! [[ "$MINOR" =~ ^[0-9]+$ ]] || ! [[ "$PATCH" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Version parts must be numeric${NC}"
    exit 1
fi

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
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo -e "${GREEN}New version: ${NEW_VERSION}${NC}"

# Check if version already exists in CHANGELOG
if grep -q "## \[$NEW_VERSION\]" CHANGELOG.md; then
    echo -e "${YELLOW}WARNING: Version $NEW_VERSION already exists in CHANGELOG.md${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Update VERSION file
echo "$NEW_VERSION" > VERSION
echo -e "${GREEN}✓ Updated VERSION file${NC}"

# Update CHANGELOG.md (add new version section after Unreleased)
TODAY=$(date +%Y-%m-%d)

# Use different sed syntax for Linux vs macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/## \[Unreleased\]/## [Unreleased]\n\n## [$NEW_VERSION] - $TODAY/" CHANGELOG.md
else
    # Linux
    sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [$NEW_VERSION] - $TODAY/" CHANGELOG.md
fi

echo -e "${GREEN}✓ Updated CHANGELOG.md${NC}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Version successfully bumped to ${NEW_VERSION}${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review changes in VERSION and CHANGELOG.md"
echo "  2. Edit CHANGELOG.md to move unreleased changes to [$NEW_VERSION] section"
echo "  3. Commit: git commit -am \"chore: release v$NEW_VERSION\""
echo "  4. Tag: git tag -a v$NEW_VERSION -m \"Release v$NEW_VERSION\""
echo "  5. Push: git push origin main --tags"
echo ""
echo -e "${YELLOW}The tag push will trigger the automated release workflow.${NC}"
