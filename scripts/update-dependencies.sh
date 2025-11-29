#!/bin/bash
#
# update-dependencies.sh
# Version: 1.0.0
#
# Description:
#   Updates Python dependencies to their latest versions and generates a frozen
#   requirements file for reproducible builds. This script creates a temporary
#   virtual environment, upgrades all packages, and outputs a frozen requirements file.
#
# Usage:
#   ./scripts/update-dependencies.sh
#
# Output:
#   - requirements-frozen.txt: Frozen dependency versions with all transitive dependencies
#   - .venv-temp: Temporary virtual environment (automatically cleaned up)
#
# Requirements:
#   - Python 3.7+
#   - pip
#   - Virtual environment support (venv module)
#
# Author: Manoj Bhaskaran
# License: MIT

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# File paths
REQUIREMENTS_FILE="$REPO_ROOT/requirements.txt"
FROZEN_FILE="$REPO_ROOT/requirements-frozen.txt"
VENV_DIR="$REPO_ROOT/.venv-temp"

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    if [ -d "$VENV_DIR" ]; then
        print_info "Cleaning up temporary virtual environment..."
        rm -rf "$VENV_DIR"
        print_success "Cleanup complete"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main script
main() {
    print_info "Python Dependency Update Tool v1.0.0"
    echo ""

    # Check if requirements.txt exists
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        print_error "requirements.txt not found at: $REQUIREMENTS_FILE"
        exit 1
    fi

    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        print_error "python3 is not installed or not in PATH"
        exit 1
    fi

    print_info "Python version: $(python3 --version)"
    echo ""

    # Create temporary virtual environment
    print_info "Creating temporary virtual environment at: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    print_success "Virtual environment created"

    # Activate virtual environment
    print_info "Activating virtual environment..."
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    print_success "Virtual environment activated"

    # Upgrade pip
    print_info "Upgrading pip to latest version..."
    pip install --quiet --upgrade pip
    print_success "pip upgraded"

    # Install and upgrade dependencies from requirements.txt
    print_info "Installing and upgrading dependencies from requirements.txt..."
    pip install --upgrade -r "$REQUIREMENTS_FILE"
    print_success "Dependencies installed and upgraded"
    echo ""

    # Generate frozen requirements
    print_info "Generating frozen requirements file..."
    pip freeze > "$FROZEN_FILE"
    print_success "Frozen requirements saved to: $FROZEN_FILE"
    echo ""

    # Display statistics
    ORIGINAL_COUNT=$(grep -c "^[^#]" "$REQUIREMENTS_FILE" || true)
    FROZEN_COUNT=$(grep -c "^[^#]" "$FROZEN_FILE" || true)

    print_info "Dependency Statistics:"
    echo "  - Original requirements: $ORIGINAL_COUNT packages"
    echo "  - Frozen requirements: $FROZEN_COUNT packages (including transitive dependencies)"
    echo ""

    # Deactivate virtual environment
    deactivate

    # Show next steps
    print_success "Dependency update complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Review the generated requirements-frozen.txt file"
    echo "  2. Compare with current requirements.txt to see what changed"
    echo "  3. Test your application with the new dependencies"
    echo "  4. If everything works, update requirements.txt with new versions"
    echo "  5. Run tests: pytest tests/python"
    echo ""
    print_warning "Note: This script generates requirements-frozen.txt for review only."
    print_warning "      Update requirements.txt manually after testing."
}

# Run main function
main
