#!/bin/bash
# Format all code in repository
# This script runs all code formatters across Python, PowerShell, and SQL files

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================"
echo "Code Formatting - My-Scripts Repository"
echo "======================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall success
OVERALL_SUCCESS=true

# Change to repository root
cd "${REPO_ROOT}"

# Python formatting with Black
echo -e "${BLUE}[1/3] Formatting Python code with Black...${NC}"
if command -v black &> /dev/null; then
    if black src/python/ tests/python/ 2>&1; then
        echo -e "${GREEN}✓ Python code formatted successfully${NC}"
    else
        echo -e "${RED}✗ Python formatting failed${NC}"
        OVERALL_SUCCESS=false
    fi
else
    echo -e "${YELLOW}⚠ Black not installed. Skipping Python formatting.${NC}"
    echo -e "${YELLOW}  Install with: pip install black${NC}"
fi
echo ""

# PowerShell formatting with PSScriptAnalyzer
echo -e "${BLUE}[2/3] Formatting PowerShell code...${NC}"
if command -v pwsh &> /dev/null; then
    if pwsh -File "${SCRIPT_DIR}/Format-PowerShellCode.ps1" 2>&1; then
        echo -e "${GREEN}✓ PowerShell code formatted successfully${NC}"
    else
        echo -e "${RED}✗ PowerShell formatting failed${NC}"
        OVERALL_SUCCESS=false
    fi
else
    echo -e "${YELLOW}⚠ PowerShell not installed. Skipping PowerShell formatting.${NC}"
    echo -e "${YELLOW}  Install from: https://github.com/PowerShell/PowerShell${NC}"
fi
echo ""

# SQL formatting with SQLFluff
echo -e "${BLUE}[3/3] Formatting SQL code with SQLFluff...${NC}"
if command -v sqlfluff &> /dev/null; then
    # Check if there are SQL files to format
    if find src/sql -name "*.sql" -type f 2>/dev/null | grep -q .; then
        # Run sqlfluff fix with explicit config file
        # Note: Exit code 1 may indicate unfixable violations (which is acceptable)
        if sqlfluff fix --config .sqlfluffrc src/sql/ 2>&1; then
            echo -e "${GREEN}✓ SQL code formatted successfully${NC}"
        else
            # Check if there were only unfixable violations (acceptable)
            if sqlfluff lint --config .sqlfluffrc src/sql/ 2>&1 | grep -q "fixable linting violations"; then
                echo -e "${GREEN}✓ SQL code formatted (some unfixable violations remain)${NC}"
            else
                echo -e "${RED}✗ SQL formatting failed${NC}"
                OVERALL_SUCCESS=false
            fi
        fi
    else
        echo -e "${YELLOW}⚠ No SQL files found to format${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SQLFluff not installed. Skipping SQL formatting.${NC}"
    echo -e "${YELLOW}  Install with: pip install sqlfluff${NC}"
fi
echo ""

# Summary
echo "======================================"
if [ "$OVERALL_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ All code formatted successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes: git diff"
    echo "  2. Stage the changes: git add ."
    echo "  3. Commit: git commit -m 'style: format all code with automated formatters'"
    exit 0
else
    echo -e "${RED}✗ Some formatters failed. Please check the errors above.${NC}"
    exit 1
fi
