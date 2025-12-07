"""
Security compliance tests for the repository.

This module contains tests that verify security best practices are followed
throughout the codebase, including proper use of timeouts in HTTP requests.
"""

import ast
import glob
import logging
from pathlib import Path

import pytest

# Configure logging for test output
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TestSecurityCompliance:
    """Test suite for security compliance checks."""

    def test_all_requests_have_timeouts(self):
        """
        Verify all HTTP requests include timeout parameter.

        This test ensures that all requests.get, requests.post, requests.put,
        requests.delete, and requests.patch calls include a timeout parameter
        to prevent indefinite hangs and potential denial of service issues.

        Rationale:
        - HTTP requests without timeouts can hang indefinitely
        - This can lead to resource exhaustion and availability issues
        - Bandit B113 check enforces this security requirement
        """
        violations = []
        python_src_dir = Path("src/python")

        # Find all Python files in the source directory
        python_files = list(python_src_dir.rglob("*.py"))

        logger.info(f"Scanning {len(python_files)} Python files for timeout compliance...")

        for file_path in python_files:
            # Skip test files and __pycache__
            if "test_" in file_path.name or "__pycache__" in str(file_path):
                continue

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Parse the Python file into an AST
                tree = ast.parse(content, filename=str(file_path))

            except (SyntaxError, UnicodeDecodeError, FileNotFoundError) as e:
                logger.warning(f"Could not parse {file_path}: {e}")
                continue

            # Walk through all nodes in the AST
            for node in ast.walk(tree):
                if isinstance(node, ast.Call):
                    # Check for requests.method() calls
                    if (
                        isinstance(node.func, ast.Attribute)
                        and isinstance(node.func.value, ast.Name)
                        and node.func.value.id == "requests"
                        and node.func.attr
                        in ["get", "post", "put", "delete", "patch", "head", "options"]
                    ):

                        # Check if timeout keyword argument is present
                        has_timeout = any(kw.arg == "timeout" for kw in node.keywords)

                        if not has_timeout:
                            violation = f"{file_path}:Line {node.lineno} - {node.func.attr}() call missing timeout"
                            violations.append(violation)
                            logger.error(f"Found violation: {violation}")

        # Report results
        if violations:
            logger.error(f"Found {len(violations)} requests without timeout:")
            for violation in violations:
                logger.error(f"  - {violation}")
        else:
            logger.info("✅ All HTTP requests have timeout parameters")

        # Assert no violations found
        assert len(violations) == 0, (
            f"Found {len(violations)} HTTP requests without timeout parameters:\n"
            + "\n".join(f"  - {v}" for v in violations)
            + "\n\nAll requests.* calls must include a timeout parameter to prevent indefinite hangs."
        )

    def test_bandit_b113_enabled(self):
        """
        Verify that Bandit B113 check is enabled in configuration.

        This test ensures that the B113 security check (requests without timeout)
        is not in the skip list, meaning it will be enforced by the security scanner.
        """
        pyproject_path = Path("pyproject.toml")

        if not pyproject_path.exists():
            pytest.skip("pyproject.toml not found")

        with open(pyproject_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Check that B113 is not in the skips list
        assert "B113" not in content, (
            "B113 check should be enabled (not in skips list) in pyproject.toml. "
            "This ensures Bandit will catch requests calls without timeouts."
        )

        logger.info("✅ Bandit B113 check is properly enabled")

    def test_security_documentation_examples(self):
        """
        Verify that documentation examples include timeout parameters.

        This test checks README and documentation files to ensure that
        example code snippets follow security best practices.
        """
        violations = []

        # Check documentation files
        doc_patterns = ["**/*.md", "**/*.rst", "docs/**/*.txt"]

        for pattern in doc_patterns:
            for doc_file in Path(".").glob(pattern):
                if doc_file.is_file():
                    try:
                        with open(doc_file, "r", encoding="utf-8") as f:
                            lines = f.readlines()

                        for line_num, line in enumerate(lines, 1):
                            # Look for requests calls in code blocks or examples
                            if (
                                "requests." in line
                                and any(
                                    method in line
                                    for method in ["get(", "post(", "put(", "delete(", "patch("]
                                )
                                and "timeout=" not in line
                                and "```" not in line
                            ):  # Skip markdown code fence lines

                                violation = f"{doc_file}:Line {line_num} - Example missing timeout"
                                violations.append(violation)

                    except (UnicodeDecodeError, FileNotFoundError):
                        continue

        if violations:
            # This is a warning, not a hard failure, since docs might have simplified examples
            logger.warning(f"Found {len(violations)} documentation examples without timeouts:")
            for violation in violations:
                logger.warning(f"  - {violation}")
            logger.warning("Consider updating documentation examples to include timeout parameters")
