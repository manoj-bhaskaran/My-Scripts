"""Regression tests for crop_colours package invocation guidance."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def test_crop_colours_direct_execution_reports_module_invocation() -> None:
    """Running crop_colours.py as a loose script should fail with guidance."""
    repo_root = Path(__file__).resolve().parents[3]
    script = repo_root / "src" / "python" / "media" / "crop_colours.py"

    completed = subprocess.run(
        [sys.executable, str(script), "--help"],
        text=True,
        capture_output=True,
        check=False,
    )

    assert completed.returncode == 2
    assert "python -m media.crop_colours" in completed.stderr
    assert "package" in completed.stderr
