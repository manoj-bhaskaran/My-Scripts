# Test Scenarios for Sync-MacriumBackups v2.6.0

## Overview
This document outlines test scenarios to verify the refactored interrupted state handling and script version variable implementation.

## Changes in v2.6.0
1. **Refactored Initialize-StateFile**: Eliminated duplicated interrupted state handling logic
2. **Added Mark-InterruptedState helper function**: Consolidates state marking logic
3. **Added $ScriptVersion variable**: Programmatic access to script version
4. **Enhanced state tracking**: State file now includes scriptVersion field

---

## Test Scenario 1: Clean Start (Default Behavior)

### Objective
Verify that the script correctly handles a clean start without AutoResume flag.

### Prerequisites
- Remove any existing state file: `Remove-Item "logs\Sync-MacriumBackups_state.json" -Force -ErrorAction SilentlyContinue`

### Test Steps
1. Run the script without AutoResume:
   ```powershell
   .\Sync-MacriumBackups.ps1
   ```

### Expected Results
- Script logs should show: "Starting Macrium backup sync script (version 2.6.0)"
- State file should be created with:
  - `scriptVersion: "2.6.0"`
  - `status: "InProgress"` (during execution)
  - `status: "Succeeded"` or `"Failed"` (after completion)
- Log should show: "State tracking initialized. Run ID: [guid], Script version: 2.6.0"

---

## Test Scenario 2: Clean Start with Interrupted Previous Run

### Objective
Verify that interrupted state is properly marked before clean start removes it.

### Prerequisites
1. Create a mock interrupted state file:
   ```powershell
   $interruptedState = @{
       lastRunId = "12345678-1234-1234-1234-123456789012"
       scriptVersion = "2.5.1"
       status = "InProgress"
       startTime = "2026-01-15T10:00:00.0000000-05:00"
       endTime = $null
       lastExitCode = $null
       lastStep = "Test-Network"
       syncStartTime = $null
       syncDurationSeconds = $null
   } | ConvertTo-Json

   $interruptedState | Set-Content "logs\Sync-MacriumBackups_state.json"
   ```

### Test Steps
1. Run the script without AutoResume (clean start):
   ```powershell
   .\Sync-MacriumBackups.ps1
   ```

### Expected Results
- Log should show:
  - "Previous run was interrupted (possible reboot/crash)"
  - "Previous run details - Run ID: 12345678-1234-1234-1234-123456789012, Started: 2026-01-15T10:00:00..."
  - "Previous state marked as Interrupted"
  - "Clean start requested. Removing previous state file."
- State file should be briefly marked as `Interrupted` before being removed
- New state file should be created with new run ID and version 2.6.0

---

## Test Scenario 3: Auto-Resume with Interrupted State

### Objective
Verify that AutoResume correctly handles interrupted runs.

### Prerequisites
1. Create a mock interrupted state file (same as Scenario 2)

### Test Steps
1. Run the script with AutoResume:
   ```powershell
   .\Sync-MacriumBackups.ps1 -AutoResume
   ```

### Expected Results
- Log should show:
  - "AutoResume enabled. Checking previous run status..."
  - "Previous run status: InProgress"
  - "Previous run was interrupted (possible reboot/crash). Proceeding with sync to complete."
  - "Previous state marked as Interrupted"
- Script should proceed with sync
- New state file should have new run ID and version 2.6.0

---

## Test Scenario 4: Auto-Resume with Failed State

### Objective
Verify that AutoResume correctly handles failed previous runs.

### Prerequisites
1. Create a mock failed state file:
   ```powershell
   $failedState = @{
       lastRunId = "87654321-4321-4321-4321-210987654321"
       scriptVersion = "2.5.1"
       status = "Failed"
       startTime = "2026-01-15T09:00:00.0000000-05:00"
       endTime = "2026-01-15T09:30:00.0000000-05:00"
       lastExitCode = 1
       lastStep = "Sync-Backups"
       syncStartTime = "2026-01-15T09:15:00.0000000-05:00"
       syncDurationSeconds = 900
   } | ConvertTo-Json

   $failedState | Set-Content "logs\Sync-MacriumBackups_state.json"
   ```

### Test Steps
1. Run the script with AutoResume:
   ```powershell
   .\Sync-MacriumBackups.ps1 -AutoResume
   ```

### Expected Results
- Log should show:
  - "AutoResume enabled. Checking previous run status..."
  - "Previous run status: Failed"
  - "Previous run failed. Proceeding with sync to retry."
  - "Retrying after failed run (ID: 87654321-4321-4321-4321-210987654321)."
- Script should proceed with sync
- New state file should have new run ID and version 2.6.0

---

## Test Scenario 5: Auto-Resume with Succeeded State (No Force)

### Objective
Verify that AutoResume skips execution when previous run succeeded.

### Prerequisites
1. Create a mock succeeded state file:
   ```powershell
   $succeededState = @{
       lastRunId = "11111111-2222-3333-4444-555555555555"
       scriptVersion = "2.5.1"
       status = "Succeeded"
       startTime = "2026-01-15T08:00:00.0000000-05:00"
       endTime = "2026-01-15T08:45:00.0000000-05:00"
       lastExitCode = 0
       lastStep = "Sync-Backups"
       syncStartTime = "2026-01-15T08:10:00.0000000-05:00"
       syncDurationSeconds = 2100
   } | ConvertTo-Json

   $succeededState | Set-Content "logs\Sync-MacriumBackups_state.json"
   ```

### Test Steps
1. Run the script with AutoResume:
   ```powershell
   .\Sync-MacriumBackups.ps1 -AutoResume
   ```

### Expected Results
- Log should show:
  - "AutoResume enabled. Checking previous run status..."
  - "Previous run status: Succeeded"
  - "Previous run succeeded. No action required. Use -Force to override."
  - "Exiting without running sync. Previous run already succeeded."
- Script should exit with code 0 WITHOUT running sync
- State file should remain unchanged

---

## Test Scenario 6: Auto-Resume with Succeeded State (With Force)

### Objective
Verify that AutoResume with Force flag overrides the skip behavior.

### Prerequisites
1. Create a mock succeeded state file (same as Scenario 5)

### Test Steps
1. Run the script with AutoResume and Force:
   ```powershell
   .\Sync-MacriumBackups.ps1 -AutoResume -Force
   ```

### Expected Results
- Log should show:
  - "AutoResume enabled. Checking previous run status..."
  - "Previous run status: Succeeded"
  - "Previous run succeeded, but -Force flag is set. Proceeding with sync."
- Script should proceed with sync
- New state file should have new run ID and version 2.6.0

---

## Verification Checklist

After running each test scenario, verify:

- [ ] Script version is logged at startup: "Starting Macrium backup sync script (version 2.6.0)"
- [ ] State file includes `scriptVersion` field set to "2.6.0"
- [ ] State initialization logs include version: "State tracking initialized. Run ID: [guid], Script version: 2.6.0"
- [ ] Mark-InterruptedState function is called only once per interrupted state (no duplication)
- [ ] Interrupted states are properly marked with:
  - `status: "Interrupted"`
  - `endTime: [timestamp]`
  - `reason: "Previous run ended without completion (possible reboot/crash)"`
- [ ] Clean start removes state file after marking interrupted state
- [ ] AutoResume logic correctly evaluates previous state and makes appropriate decisions

---

## Code Review Points

### Mark-InterruptedState Function (lines 333-357)
- Consolidates interrupted state handling
- Logs warning and previous run details
- Updates state with Interrupted status, endTime, and reason
- Persists state to file
- Logs confirmation

### Initialize-StateFile Function (lines 359-418)
- Calls Mark-InterruptedState once before branching logic (line 379-382)
- Clean start path is simplified (lines 384-391)
- AutoResume path handles failed state logging (lines 393-398)
- New state includes scriptVersion field (line 404)
- Logs include script version (line 415)

### Script Version Usage
- Defined at line 193: `$ScriptVersion = "2.6.0"`
- Used in startup log (line ~966)
- Used in state file (line 404)
- Used in state initialization log (line 415)

---

## Notes
- All tests can be run in a safe environment without actual rclone sync by modifying the script to skip the Sync-Backups step
- State file location: `logs\Sync-MacriumBackups_state.json`
- Framework log location: `logs\Sync-MacriumBackups.ps1_powershell_YYYY-MM-DD.log`
