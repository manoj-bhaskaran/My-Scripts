#!/bin/bash
#
# install-modules.sh
# Cross-platform module installation script for My-Scripts repository
#
# This script installs both PowerShell and Python modules:
# - PowerShell modules via Deploy-Modules.ps1
# - Python modules via pip install
#
# Usage:
#   ./scripts/install-modules.sh [--force] [--python-only] [--powershell-only]
#
# Options:
#   --force            Force overwrite of existing modules
#   --python-only      Install only Python modules
#   --powershell-only  Install only PowerShell modules
#   --help             Show this help message
#

set -e  # Exit on error

# Parse command line arguments
FORCE=""
INSTALL_PYTHON=true
INSTALL_POWERSHELL=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE="-Force"
            shift
            ;;
        --python-only)
            INSTALL_POWERSHELL=false
            shift
            ;;
        --powershell-only)
            INSTALL_PYTHON=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Install PowerShell and Python modules for My-Scripts repository"
            echo ""
            echo "Options:"
            echo "  --force            Force overwrite of existing modules"
            echo "  --python-only      Install only Python modules"
            echo "  --powershell-only  Install only PowerShell modules"
            echo "  --help, -h         Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Determine script directory and repository root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "======================================"
echo "My-Scripts Module Installation"
echo "======================================"
echo ""
echo "Repository: $REPO_ROOT"
echo ""

# Install PowerShell modules
if [ "$INSTALL_POWERSHELL" = true ]; then
    echo "Installing PowerShell modules..."
    echo "--------------------------------"

    # Check if pwsh is available
    if command -v pwsh &> /dev/null; then
        PWSH_CMD="pwsh"
    elif command -v powershell &> /dev/null; then
        PWSH_CMD="powershell"
    else
        echo "ERROR: PowerShell (pwsh or powershell) not found in PATH"
        echo "Please install PowerShell: https://github.com/PowerShell/PowerShell"
        exit 1
    fi

    echo "Using PowerShell: $PWSH_CMD"

    # Run Deploy-Modules.ps1
    DEPLOY_SCRIPT="$SCRIPT_DIR/Deploy-Modules.ps1"

    if [ ! -f "$DEPLOY_SCRIPT" ]; then
        echo "ERROR: Deploy-Modules.ps1 not found at $DEPLOY_SCRIPT"
        exit 1
    fi

    if [ -n "$FORCE" ]; then
        echo "Deploying modules with -Force..."
        $PWSH_CMD -NoProfile -ExecutionPolicy Bypass -File "$DEPLOY_SCRIPT" -Force
    else
        echo "Deploying modules..."
        $PWSH_CMD -NoProfile -ExecutionPolicy Bypass -File "$DEPLOY_SCRIPT"
    fi

    echo ""
    echo "PowerShell modules installed successfully!"
    echo ""
fi

# Install Python modules
if [ "$INSTALL_PYTHON" = true ]; then
    echo "Installing Python modules..."
    echo "----------------------------"

    # Check if pip is available
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
    elif command -v pip &> /dev/null; then
        PIP_CMD="pip"
    else
        echo "ERROR: pip not found in PATH"
        echo "Please install Python and pip: https://www.python.org/"
        exit 1
    fi

    echo "Using pip: $PIP_CMD"

    # Check if setup.py exists
    SETUP_PY="$REPO_ROOT/setup.py"

    if [ ! -f "$SETUP_PY" ]; then
        echo "ERROR: setup.py not found at $SETUP_PY"
        exit 1
    fi

    # Install in editable mode
    echo "Installing python_logging_framework in editable mode..."
    cd "$REPO_ROOT"
    $PIP_CMD install -e .

    echo ""
    echo "Python modules installed successfully!"
    echo ""
fi

# Summary
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""

if [ "$INSTALL_POWERSHELL" = true ]; then
    echo "PowerShell modules installed:"
    echo "  - PostgresBackup"
    echo "  - PowerShellLoggingFramework"
    echo "  - PurgeLogs"
    echo "  - RandomName"
    echo "  - Videoscreenshot"
    echo ""
    echo "Verify with:"
    echo "  pwsh -c 'Get-Module -ListAvailable PostgresBackup,PowerShellLoggingFramework,PurgeLogs,RandomName,Videoscreenshot'"
    echo ""
fi

if [ "$INSTALL_PYTHON" = true ]; then
    echo "Python modules installed:"
    echo "  - python_logging_framework (as my-scripts-logging)"
    echo ""
    echo "Verify with:"
    echo "  python3 -c 'import python_logging_framework; print(\"OK\")'"
    echo ""
fi

echo "For more information, see:"
echo "  docs/guides/module-deployment.md"
echo ""
