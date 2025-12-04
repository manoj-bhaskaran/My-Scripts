# Issue #003a: Add Smoke Tests for All Main Scripts

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Immediate (Week 1)
**Effort**: 4-6 hours

## Description
Add basic smoke tests to verify all main entry-point scripts can be imported/executed without errors. This is the quickest way to establish a coverage baseline and catch import errors.

## Scope
Add smoke tests for 20+ main scripts:
- Python scripts in `src/python/`
- PowerShell scripts in `src/powershell/` (non-module scripts)

## Implementation

### Python Smoke Tests
```python
# tests/python/unit/test_smoke.py
import pytest
import importlib

SCRIPTS = [
    'src.python.cloud.google_drive_root_files_delete',
    'src.python.cloud.cloudconvert_utils',
    'src.python.cloud.gdrive_recover',
    'src.python.cloud.drive_space_monitor',
    'src.python.data.csv_to_gpx',
    'src.python.data.validators',
    'src.python.data.extract_timeline_locations',
    'src.python.media.find_duplicate_images',
    'src.python.media.crop_colours',
    'src.python.media.recover_extensions',
]

@pytest.mark.parametrize("module_name", SCRIPTS)
def test_script_imports(module_name):
    """Verify script can be imported without errors."""
    try:
        importlib.import_module(module_name)
    except ImportError as e:
        pytest.fail(f"Failed to import {module_name}: {e}")
```

### PowerShell Smoke Tests
```powershell
# tests/powershell/unit/SmokeTests.Tests.ps1
Describe "Script Smoke Tests" {
    $scripts = Get-ChildItem -Path "src/powershell" -Recurse -Filter "*.ps1" |
        Where-Object { $_.DirectoryName -notlike "*\modules\*" }

    foreach ($script in $scripts) {
        Context $script.Name {
            It "Script syntax is valid" {
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content $script.FullName -Raw), [ref]$errors
                )
                $errors.Count | Should -Be 0
            }
        }
    }
}
```

## Acceptance Criteria
- [ ] Smoke tests created for all Python scripts
- [ ] Smoke tests created for all PowerShell scripts
- [ ] Tests pass in CI/CD
- [ ] Coverage increases from 1% to ~3%
- [ ] Test execution time < 30 seconds

## Benefits
- Quick baseline coverage
- Catch import/syntax errors
- Foundation for deeper testing
- Minimal effort, high value

## Related
- Enables #003b (critical path testing)
- Supports CI/CD validation
