# Extract Shared Utilities (Error Handling, File Operations)

## Priority
**MODERATE** 🟡

## Background
Many scripts in My-Scripts repository **duplicate common functionality**:

**Duplicated Patterns:**
1. **Error Handling** – Try/catch blocks repeated across scripts
2. **File Operations** – Retry logic for file writes duplicated
3. **Argument Parsing** – Similar parameter validation patterns
4. **Progress Reporting** – Ad-hoc progress indicators
5. **Elevation Checks** – Admin/sudo detection duplicated

**Impact:**
- Code duplication (DRY violation)
- Inconsistent error handling
- Bug fixes must be applied in multiple places
- Harder to maintain

## Objectives
- Extract common patterns into reusable modules
- Create ErrorHandling module for PowerShell
- Create FileOperations module for PowerShell
- Standardize error handling across scripts
- Reduce code duplication by ≥30%

## Tasks

### Phase 1: Identify Common Patterns
- [ ] Audit scripts for duplicated code:
  ```powershell
  # Find try/catch patterns
  Get-ChildItem -Recurse *.ps1 | Select-String -Pattern "try\s*\{" -Context 5

  # Find file operation retry patterns
  Get-ChildItem -Recurse *.ps1 | Select-String -Pattern "while.*retry|Start-Sleep.*retry"
  ```
- [ ] Document common patterns:
  - Error handling (try/catch/finally with logging)
  - File operations with retry
  - Elevation detection
  - Progress reporting
  - Parameter validation

### Phase 2: Create ErrorHandling Module
- [ ] Create `src/powershell/modules/Core/ErrorHandling/ErrorHandling.psm1`:
  ```powershell
  function Invoke-WithErrorHandling {
      <#
      .SYNOPSIS
          Executes script block with standardized error handling

      .PARAMETER ScriptBlock
          Code to execute

      .PARAMETER OnError
          Action to take on error (Stop, Continue, SilentlyContinue)

      .PARAMETER LogError
          Whether to log error (default: $true)

      .EXAMPLE
          Invoke-WithErrorHandling {
              Get-Content "file.txt"
          } -OnError Stop
      #>
      param(
          [Parameter(Mandatory)]
          [scriptblock]$ScriptBlock,

          [ValidateSet('Stop', 'Continue', 'SilentlyContinue')]
          [string]$OnError = 'Stop',

          [bool]$LogError = $true
      )

      try {
          & $ScriptBlock
      }
      catch {
          if ($LogError) {
              Write-Log -Message "Error: $($_.Exception.Message)" -Level ERROR
          }

          switch ($OnError) {
              'Stop' { throw }
              'Continue' { return $null }
              'SilentlyContinue' { return $null }
          }
      }
  }

  function Test-IsElevated {
      <#
      .SYNOPSIS
          Checks if script is running with elevated privileges
      #>
      if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
          $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
          $principal = [Security.Principal.WindowsPrincipal]$identity
          return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
      }
      else {
          return (id -u) -eq 0
      }
  }

  function Assert-Elevated {
      <#
      .SYNOPSIS
          Throws if not elevated
      #>
      if (-not (Test-IsElevated)) {
          throw "This script requires elevated privileges. Run as Administrator (Windows) or with sudo (Linux/macOS)."
      }
  }

  Export-ModuleMember -Function Invoke-WithErrorHandling, Test-IsElevated, Assert-Elevated
  ```
- [ ] Create manifest and documentation

### Phase 3: Create FileOperations Module
- [ ] Create `src/powershell/modules/Core/FileOperations/FileOperations.psm1`:
  ```powershell
  function Copy-FileWithRetry {
      <#
      .SYNOPSIS
          Copies file with automatic retry on failure

      .PARAMETER Source
          Source file path

      .PARAMETER Destination
          Destination file path

      .PARAMETER MaxRetries
          Maximum retry attempts (default: 3)

      .PARAMETER RetryDelay
          Delay between retries in seconds (default: 2)
      #>
      param(
          [Parameter(Mandatory)]
          [string]$Source,

          [Parameter(Mandatory)]
          [string]$Destination,

          [int]$MaxRetries = 3,

          [int]$RetryDelay = 2
      )

      $attempt = 0
      while ($attempt -lt $MaxRetries) {
          try {
              Copy-Item -Path $Source -Destination $Destination -Force
              return $true
          }
          catch {
              $attempt++
              if ($attempt -ge $MaxRetries) {
                  throw "Failed to copy $Source after $MaxRetries attempts: $_"
              }
              Write-Log -Message "Copy failed (attempt $attempt/$MaxRetries), retrying in ${RetryDelay}s..." -Level WARNING
              Start-Sleep -Seconds $RetryDelay
          }
      }
  }

  function Test-FolderWritable {
      <#
      .SYNOPSIS
          Tests if folder is writable

      .PARAMETER Path
          Folder path to test

      .PARAMETER SkipCreate
          Don't create folder if missing
      #>
      param(
          [Parameter(Mandatory)]
          [string]$Path,

          [switch]$SkipCreate
      )

      if (-not (Test-Path $Path)) {
          if ($SkipCreate) {
              return $false
          }
          New-Item -Path $Path -ItemType Directory -Force | Out-Null
      }

      $testFile = Join-Path $Path ".write_test_$([guid]::NewGuid().ToString('N'))"
      try {
          [IO.File]::WriteAllText($testFile, "test")
          Remove-Item $testFile -Force
          return $true
      }
      catch {
          return $false
      }
  }

  function Add-ContentWithRetry {
      <#
      .SYNOPSIS
          Appends content to file with retry logic (used in logging)
      #>
      param(
          [Parameter(Mandatory)]
          [string]$Path,

          [Parameter(Mandatory)]
          [string]$Value,

          [int]$MaxRetries = 3
      )

      # Implementation with retry and proper file handle management
  }

  Export-ModuleMember -Function Copy-FileWithRetry, Test-FolderWritable, Add-ContentWithRetry
  ```
- [ ] Create manifest and documentation

### Phase 4: Create Progress Module
- [ ] Create `src/powershell/modules/Core/Progress/ProgressReporter.psm1`:
  ```powershell
  function Show-Progress {
      <#
      .SYNOPSIS
          Displays standardized progress indicator
      #>
      param(
          [Parameter(Mandatory)]
          [string]$Activity,

          [Parameter(Mandatory)]
          [int]$PercentComplete,

          [string]$Status,

          [int]$Id = 0
      )

      Write-Progress -Activity $Activity -PercentComplete $PercentComplete -Status $Status -Id $Id
  }

  function Write-ProgressLog {
      <#
      .SYNOPSIS
          Logs progress to both console and log file
      #>
      param(
          [Parameter(Mandatory)]
          [string]$Message,

          [int]$Current,

          [int]$Total
      )

      $percent = if ($Total -gt 0) { [int](($Current / $Total) * 100) } else { 0 }
      Write-Log -Message "$Message ($Current/$Total, ${percent}%)" -Level INFO
      Show-Progress -Activity $Message -PercentComplete $percent
  }

  Export-ModuleMember -Function Show-Progress, Write-ProgressLog
  ```

### Phase 5: Refactor Existing Scripts
- [ ] Identify scripts to refactor (highest duplication):
  - FileDistributor.ps1
  - Database backup scripts
  - File cleanup scripts
  - Copy-AndroidFiles.ps1
- [ ] Refactor to use new modules:
  ```powershell
  # OLD
  try {
      Copy-Item $source $destination -Force
  }
  catch {
      Write-Host "Error: $_" -ForegroundColor Red
      throw
  }

  # NEW
  Import-Module ErrorHandling, FileOperations

  Invoke-WithErrorHandling {
      Copy-FileWithRetry -Source $source -Destination $destination
  } -OnError Stop
  ```
- [ ] Test each refactored script

### Phase 6: Python Shared Utilities
- [ ] Create `src/python/modules/utils/file_operations.py`:
  ```python
  """File operations with retry logic."""
  import time
  from pathlib import Path
  from typing import Optional

  def copy_with_retry(
      source: Path,
      destination: Path,
      max_retries: int = 3,
      retry_delay: int = 2
  ) -> bool:
      """Copy file with retry on failure."""
      for attempt in range(max_retries):
          try:
              destination.write_bytes(source.read_bytes())
              return True
          except Exception as e:
              if attempt >= max_retries - 1:
                  raise
              time.sleep(retry_delay)
      return False

  def is_writable(path: Path) -> bool:
      """Check if path is writable."""
      # Implementation
  ```
- [ ] Create `src/python/modules/utils/error_handling.py`:
  ```python
  """Error handling utilities."""
  import functools
  import logging
  from typing import Callable, Any

  def with_error_handling(
      on_error: str = "raise",
      log_errors: bool = True
  ):
      """Decorator for standardized error handling."""
      def decorator(func: Callable) -> Callable:
          @functools.wraps(func)
          def wrapper(*args, **kwargs) -> Any:
              try:
                  return func(*args, **kwargs)
              except Exception as e:
                  if log_errors:
                      logging.error(f"Error in {func.__name__}: {e}")

                  if on_error == "raise":
                      raise
                  elif on_error == "return_none":
                      return None
                  elif on_error == "continue":
                      pass
          return wrapper
      return decorator
  ```

### Phase 7: Documentation
- [ ] Create README for each new module
- [ ] Document migration guide in `docs/guides/using-shared-utilities.md`:
  ```markdown
  # Using Shared Utilities

  ## Overview
  Common functionality extracted into reusable modules.

  ## Available Modules

  ### ErrorHandling (PowerShell)
  - `Invoke-WithErrorHandling` – Standardized try/catch
  - `Test-IsElevated` – Check admin privileges
  - `Assert-Elevated` – Require elevation

  ### FileOperations (PowerShell)
  - `Copy-FileWithRetry` – Resilient file copy
  - `Test-FolderWritable` – Check write permissions
  - `Add-ContentWithRetry` – Append with retry

  ### Progress (PowerShell)
  - `Show-Progress` – Standardized progress bars
  - `Write-ProgressLog` – Progress with logging

  ## Migration Examples
  [Examples of before/after refactoring]
  ```
- [ ] Update affected scripts' documentation

### Phase 8: Testing
- [ ] Create unit tests for new modules:
  - `tests/powershell/unit/ErrorHandling.Tests.ps1`
  - `tests/powershell/unit/FileOperations.Tests.ps1`
  - `tests/python/unit/test_file_operations.py`
  - `tests/python/unit/test_error_handling.py`
- [ ] Verify refactored scripts still work correctly
- [ ] Measure code duplication reduction

## Acceptance Criteria
- [x] 3+ new shared modules created (ErrorHandling, FileOperations, Progress)
- [x] All modules have comprehensive documentation
- [x] All modules have unit tests (≥70% coverage)
- [x] Minimum 5 scripts refactored to use new modules
- [x] Code duplication reduced by ≥30% (measurable via SonarCloud)
- [x] No functionality regressions
- [x] Migration guide documented
- [x] Modules added to deployment configuration

## Related Files
- `src/powershell/modules/Core/ErrorHandling/` (to be created)
- `src/powershell/modules/Core/FileOperations/` (to be created)
- `src/powershell/modules/Core/Progress/` (to be created)
- `src/python/modules/utils/` (to be created)
- `docs/guides/using-shared-utilities.md` (to be created)
- FileDistributor.ps1, backup scripts, cleanup scripts (to be refactored)

## Estimated Effort
**3-4 days** (module creation, refactoring, testing)

## Dependencies
- Issue #001 (Testing) – for unit tests
- Issue #005 (Module Deployment) – for deployment

## References
- [DRY Principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [PowerShell Advanced Functions](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-overview)
