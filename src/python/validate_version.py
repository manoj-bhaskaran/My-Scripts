#!/usr/bin/env python3
"""
Script: validate_version.py
Description: Validates VERSION file matches CHANGELOG.md and follows semantic versioning
Author: Manoj Bhaskaran
Version: 1.0.0

This script ensures:
1. VERSION file exists and contains valid semantic version
2. CHANGELOG.md exists and is properly formatted
3. Latest version in CHANGELOG matches VERSION file
4. Version links at bottom of CHANGELOG are correct
"""

import re
import sys
from pathlib import Path
from typing import Tuple, Optional


class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_error(message: str) -> None:
    """Print error message in red"""
    print(f"{Colors.RED}✗ ERROR: {message}{Colors.RESET}", file=sys.stderr)


def print_success(message: str) -> None:
    """Print success message in green"""
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")


def print_warning(message: str) -> None:
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠ WARNING: {message}{Colors.RESET}")


def print_info(message: str) -> None:
    """Print info message in blue"""
    print(f"{Colors.BLUE}ℹ {message}{Colors.RESET}")


def get_repo_root() -> Path:
    """Get the repository root directory"""
    # Script is in src/python/, so repo root is two levels up
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent
    return repo_root


def validate_semver(version: str) -> bool:
    """
    Validate that version follows semantic versioning format (MAJOR.MINOR.PATCH)

    Args:
        version: Version string to validate

    Returns:
        True if valid, False otherwise
    """
    semver_pattern = r'^\d+\.\d+\.\d+$'
    return bool(re.match(semver_pattern, version.strip()))


def read_version_file(version_file: Path) -> Optional[str]:
    """
    Read and validate VERSION file

    Args:
        version_file: Path to VERSION file

    Returns:
        Version string if valid, None otherwise
    """
    if not version_file.exists():
        print_error(f"VERSION file not found: {version_file}")
        return None

    try:
        version = version_file.read_text().strip()
    except Exception as e:
        print_error(f"Failed to read VERSION file: {e}")
        return None

    if not version:
        print_error("VERSION file is empty")
        return None

    if not validate_semver(version):
        print_error(f"VERSION file contains invalid semantic version: '{version}'")
        print_info("Expected format: MAJOR.MINOR.PATCH (e.g., 1.0.0)")
        return None

    print_success(f"VERSION file is valid: {version}")
    return version


def extract_latest_version_from_changelog(changelog_file: Path) -> Optional[Tuple[str, str]]:
    """
    Extract the latest version from CHANGELOG.md

    Args:
        changelog_file: Path to CHANGELOG.md

    Returns:
        Tuple of (version, date) if found, None otherwise
    """
    if not changelog_file.exists():
        print_error(f"CHANGELOG.md not found: {changelog_file}")
        return None

    try:
        content = changelog_file.read_text()
    except Exception as e:
        print_error(f"Failed to read CHANGELOG.md: {e}")
        return None

    # Pattern to match version headers like ## [2.0.0] - 2025-11-16
    # Excludes [Unreleased] section
    version_pattern = r'##\s+\[(\d+\.\d+\.\d+)\]\s+-\s+(\d{4}-\d{2}-\d{2})'

    matches = re.findall(version_pattern, content)

    if not matches:
        print_error("No versioned releases found in CHANGELOG.md")
        print_info("Expected format: ## [X.Y.Z] - YYYY-MM-DD")
        return None

    # First match is the latest version (CHANGELOG is in reverse chronological order)
    latest_version, latest_date = matches[0]

    print_success(f"Latest CHANGELOG version: {latest_version} ({latest_date})")
    return latest_version, latest_date


def validate_changelog_links(changelog_file: Path, version: str) -> bool:
    """
    Validate that version links at bottom of CHANGELOG are correct

    Args:
        changelog_file: Path to CHANGELOG.md
        version: Version to check

    Returns:
        True if links are valid, False otherwise
    """
    try:
        content = changelog_file.read_text()
    except Exception as e:
        print_error(f"Failed to read CHANGELOG.md: {e}")
        return False

    # Check for version link
    version_link_pattern = rf'\[{re.escape(version)}\]:\s+https://github\.com/'

    if re.search(version_link_pattern, content):
        print_success(f"Version link found for v{version}")
        return True
    else:
        print_warning(f"Version link not found for v{version} at bottom of CHANGELOG.md")
        print_info("Expected format: [X.Y.Z]: https://github.com/...")
        return True  # Warning, not error


def validate_unreleased_section(changelog_file: Path) -> bool:
    """
    Validate that CHANGELOG has an [Unreleased] section

    Args:
        changelog_file: Path to CHANGELOG.md

    Returns:
        True if section exists, False otherwise
    """
    try:
        content = changelog_file.read_text()
    except Exception as e:
        print_error(f"Failed to read CHANGELOG.md: {e}")
        return False

    unreleased_pattern = r'##\s+\[Unreleased\]'

    if re.search(unreleased_pattern, content):
        print_success("CHANGELOG contains [Unreleased] section")
        return True
    else:
        print_warning("CHANGELOG missing [Unreleased] section")
        return True  # Warning, not error


def main() -> int:
    """
    Main validation function

    Returns:
        0 if validation passes, 1 if validation fails
    """
    print(f"\n{Colors.BOLD}=== Version Validation ==={Colors.RESET}\n")

    repo_root = get_repo_root()
    version_file = repo_root / "VERSION"
    changelog_file = repo_root / "CHANGELOG.md"

    print_info(f"Repository root: {repo_root}")
    print_info(f"VERSION file: {version_file}")
    print_info(f"CHANGELOG file: {changelog_file}\n")

    # Step 1: Read and validate VERSION file
    version = read_version_file(version_file)
    if not version:
        return 1

    # Step 2: Extract latest version from CHANGELOG
    changelog_result = extract_latest_version_from_changelog(changelog_file)
    if not changelog_result:
        return 1

    changelog_version, changelog_date = changelog_result

    # Step 3: Compare versions
    print()
    if version == changelog_version:
        print_success(f"VERSION file matches CHANGELOG.md: {version}")
    else:
        print_error(f"VERSION file ({version}) does not match CHANGELOG.md ({changelog_version})")
        print_info("Please update VERSION file or CHANGELOG.md to match")
        return 1

    # Step 4: Validate CHANGELOG structure
    print()
    validate_unreleased_section(changelog_file)
    validate_changelog_links(changelog_file, version)

    # Success
    print(f"\n{Colors.GREEN}{Colors.BOLD}✓ All validation checks passed!{Colors.RESET}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Validation interrupted by user{Colors.RESET}")
        sys.exit(130)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        sys.exit(1)
