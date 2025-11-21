#!/bin/bash
# Install pre-commit hooks
# Version: 2.0.0
# Last Updated: 2025-11-21
#
# This script installs the pre-commit framework and configures git hooks
# Run this script after cloning the repository or when hooks are updated.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$REPO_ROOT" ]; then
    echo -e "${RED}ERROR: Not in a git repository${NC}"
    exit 1
fi

cd "$REPO_ROOT"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Pre-Commit Framework Installation${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo -e "${RED}ERROR: Python is not installed${NC}"
    echo "Python 3.7+ is required for pre-commit framework"
    echo "Please install Python and try again"
    exit 1
fi

# Determine Python command
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
else
    PYTHON_CMD="python"
    PIP_CMD="pip"
fi

echo -e "${GREEN}✓ Found Python: $(${PYTHON_CMD} --version)${NC}"
echo ""

# Check if pip is available
if ! command -v ${PIP_CMD} &> /dev/null; then
    echo -e "${RED}ERROR: pip is not installed${NC}"
    echo "Please install pip and try again"
    exit 1
fi

# Install pre-commit framework
echo -e "${BLUE}Installing pre-commit framework...${NC}"
${PIP_CMD} install pre-commit --quiet --upgrade

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pre-commit framework installed successfully${NC}"
else
    echo -e "${RED}✗ Failed to install pre-commit framework${NC}"
    exit 1
fi

echo ""

# Install git hooks
echo -e "${BLUE}Installing git hooks...${NC}"
pre-commit install

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pre-commit hooks installed${NC}"
else
    echo -e "${RED}✗ Failed to install pre-commit hooks${NC}"
    exit 1
fi

# Install commit-msg hook
echo -e "${BLUE}Installing commit-msg hook...${NC}"
pre-commit install --hook-type commit-msg

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Commit-msg hook installed${NC}"
else
    echo -e "${RED}✗ Failed to install commit-msg hook${NC}"
    exit 1
fi

echo ""

# Run hooks on all files for validation
echo -e "${BLUE}Running hooks on all files (validation)...${NC}"
echo -e "${YELLOW}This may take a few minutes on first run...${NC}"
echo ""

pre-commit run --all-files

HOOK_EXIT_CODE=$?

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Installation Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ $HOOK_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All hooks passed successfully!${NC}"
else
    echo -e "${YELLOW}⚠ Some hooks reported issues${NC}"
    echo -e "${YELLOW}This is normal on first installation.${NC}"
    echo -e "${YELLOW}Review the output above and fix any reported issues.${NC}"
fi

echo ""
echo -e "${GREEN}Git hooks installed successfully!${NC}"
echo ""
echo -e "${BLUE}Installed hooks:${NC}"
echo "  ✓ pre-commit (runs on: git commit)"
echo "  ✓ commit-msg (runs on: git commit)"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  • Review and fix any issues reported above"
echo "  • Run 'pre-commit run --all-files' to test all hooks"
echo "  • Run 'pre-commit autoupdate' to update hook versions"
echo "  • Use 'git commit --no-verify' to bypass hooks (use sparingly!)"
echo ""
echo "See docs/guides/git-hooks.md for more information."
echo ""

exit 0
