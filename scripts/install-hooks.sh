#!/bin/bash
# Install git hooks from repository
# Version: 1.0.0
# Last Updated: 2025-11-18
#
# This script installs git hooks from the hooks/ directory to .git/hooks/
# Run this script after cloning the repository or when hooks are updated.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$REPO_ROOT" ]; then
    echo -e "${RED}ERROR: Not in a git repository${NC}"
    exit 1
fi

HOOKS_DIR="$REPO_ROOT/hooks"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Check if hooks directory exists
if [ ! -d "$HOOKS_DIR" ]; then
    echo -e "${RED}ERROR: Hooks directory not found: $HOOKS_DIR${NC}"
    exit 1
fi

# Check if .git/hooks directory exists
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    echo -e "${RED}ERROR: .git/hooks directory not found: $GIT_HOOKS_DIR${NC}"
    echo "Make sure you're in a git repository."
    exit 1
fi

echo "Installing git hooks..."
echo "  Source: $HOOKS_DIR"
echo "  Target: $GIT_HOOKS_DIR"
echo ""

# Array of hooks to install
HOOKS=("pre-commit" "commit-msg" "post-commit" "post-merge")

INSTALLED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for hook in "${HOOKS[@]}"; do
    SOURCE="$HOOKS_DIR/$hook"
    TARGET="$GIT_HOOKS_DIR/$hook"

    if [ ! -f "$SOURCE" ]; then
        echo -e "${YELLOW}⚠ Skipping $hook - source file not found${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    # Check if target exists and is different
    if [ -f "$TARGET" ]; then
        # Compare files
        if cmp -s "$SOURCE" "$TARGET"; then
            echo -e "${GREEN}✓ $hook - already up to date${NC}"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            continue
        else
            echo -e "${YELLOW}⚠ $hook - updating existing hook${NC}"
        fi
    else
        echo -e "${GREEN}✓ Installing $hook hook${NC}"
    fi

    # Copy the hook
    if cp "$SOURCE" "$TARGET"; then
        # Make it executable
        chmod +x "$TARGET"
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    else
        echo -e "${RED}✗ Failed to install $hook${NC}"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done

echo ""
echo "================================================"
echo "Git Hooks Installation Summary"
echo "================================================"
echo -e "Installed/Updated: ${GREEN}$INSTALLED_COUNT${NC}"
echo -e "Skipped:           ${YELLOW}$SKIPPED_COUNT${NC}"
echo -e "Errors:            ${RED}$ERROR_COUNT${NC}"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}Some hooks failed to install. Please check the errors above.${NC}"
    exit 1
fi

if [ $INSTALLED_COUNT -gt 0 ]; then
    echo -e "${GREEN}Git hooks installed successfully!${NC}"
    echo ""
    echo "Active hooks:"
    for hook in "${HOOKS[@]}"; do
        if [ -x "$GIT_HOOKS_DIR/$hook" ]; then
            echo "  ✓ $hook"
        fi
    done
    echo ""
    echo "To bypass hooks when committing, use: git commit --no-verify"
    echo "See docs/guides/git-hooks.md for more information."
else
    echo -e "${YELLOW}All hooks were already up to date.${NC}"
fi

exit 0
