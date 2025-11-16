# Batch Script Logging Test Plan

## Overview
This document outlines the testing procedures for the refactored batch scripts with standardized logging (Issue #338).

## Test Environment
- **OS**: Windows 10/11
- **PowerShell**: Windows PowerShell 5.1+ or PowerShell 7+
- **Permissions**: Administrator rights (for printcancel.cmd)

## Scripts Under Test
1. `RunDeleteOldDownloads.bat` (Version 3.0.0)
2. `printcancel.cmd` (Version 2.0.0)

---

## Test Case 1: RunDeleteOldDownloads.bat - Log File Creation

### Objective
Verify that the script creates a log file with the correct naming convention.

### Prerequisites
- PowerShell is installed
- Script path is accessible

### Steps
1. Navigate to `src/batch/`
2. Execute `RunDeleteOldDownloads.bat`
3. Check for creation of `logs` subdirectory
4. Verify log file exists: `logs/RunDeleteOldDownloads_batch_YYYY-MM-DD.log`

### Expected Results
- `logs` directory is created if it doesn't exist
- Log file is created with correct name format
- Log file contains timestamped entries

---

## Test Case 2: RunDeleteOldDownloads.bat - Log Format Validation

### Objective
Verify that log entries conform to the standardized format.

### Steps
1. Execute `RunDeleteOldDownloads.bat`
2. Open the generated log file
3. Examine log entry format

### Expected Results
Each log line should match the format:
```
[YYYY-MM-DD HH:MM:SS.fff TIMEZONE] [LEVEL] [RunDeleteOldDownloads.bat] [HOSTNAME] [PID] Message
```

Example:
```
[2025-11-16 14:30:45.123 Eastern Standard Time] [INFO] [RunDeleteOldDownloads.bat] [WORKSTATION] [12345] Script started - Searching for PowerShell runtime
```

---

## Test Case 3: RunDeleteOldDownloads.bat - PowerShell 7 Detection

### Objective
Verify correct PowerShell runtime detection and logging.

### Test 3a: With PowerShell 7 Installed
1. Ensure PowerShell 7 is installed and in PATH
2. Execute `RunDeleteOldDownloads.bat`
3. Check log file for runtime selection message

**Expected**: Log should indicate "Using PowerShell 7" with path

### Test 3b: Without PowerShell 7
1. Temporarily rename/move PowerShell 7 directory
2. Execute `RunDeleteOldDownloads.bat`
3. Check log file

**Expected**: Log should indicate "Using Windows PowerShell (fallback)"

---

## Test Case 4: RunDeleteOldDownloads.bat - Success Scenario

### Objective
Verify logging of successful execution.

### Prerequisites
- DeleteOldDownloads.ps1 is accessible at the configured path
- Script completes successfully

### Steps
1. Execute `RunDeleteOldDownloads.bat`
2. Wait for completion
3. Review log file

### Expected Results
Log should contain:
- Script started message
- PowerShell runtime selection
- Execution command message
- Success message with exit code 0
- Script completion message

---

## Test Case 5: RunDeleteOldDownloads.bat - Failure Scenario

### Objective
Verify error logging when the PowerShell script fails.

### Steps
1. Modify the PowerShell script path to an invalid location, or
2. Make the PowerShell script return a non-zero exit code
3. Execute `RunDeleteOldDownloads.bat`
4. Review log file

### Expected Results
- Log should contain ERROR level message
- Exit code should be logged
- Message box should be displayed to user
- "Displaying error message to user" logged

---

## Test Case 6: printcancel.cmd - Log File Creation

### Objective
Verify log file creation for printcancel.cmd.

### Prerequisites
- Administrator privileges
- Print Spooler service is running

### Steps
1. Open Command Prompt as Administrator
2. Navigate to `src/batch/`
3. Execute `printcancel.cmd`
4. Check for `logs` subdirectory
5. Verify log file: `logs/printcancel_batch_YYYY-MM-DD.log`

### Expected Results
- `logs` directory created
- Log file exists with correct naming
- All operations are logged

---

## Test Case 7: printcancel.cmd - Log Format Validation

### Objective
Verify log entries conform to standard format.

### Steps
1. Execute `printcancel.cmd` as Administrator
2. Open log file
3. Examine entries

### Expected Results
Format should match:
```
[YYYY-MM-DD HH:MM:SS.fff TIMEZONE] [LEVEL] [printcancel.cmd] [HOSTNAME] [PID] Message
```

Should include INFO, WARNING, and potentially ERROR levels.

---

## Test Case 8: printcancel.cmd - Complete Operation Logging

### Objective
Verify all spooler operations are logged.

### Steps
1. Execute `printcancel.cmd` as Administrator
2. Review log file

### Expected Results
Log should contain entries for:
1. Script started - Beginning printer spooler maintenance
2. Stopping Windows Print Spooler service
3. Print Spooler service stopped successfully
4. Deleting spool header files (.shd)
5. Status of .shd deletion (success or warning)
6. Deleting spool data files (.spl)
7. Status of .spl deletion (success or warning)
8. Starting Windows Print Spooler service
9. Print Spooler service started successfully
10. Printer spooler maintenance completed successfully

---

## Test Case 9: printcancel.cmd - Service Failure Handling

### Objective
Verify error logging when service operations fail.

### Steps
1. Stop Print Spooler service manually
2. Disable the service temporarily
3. Execute `printcancel.cmd`
4. Review log file

### Expected Results
- ERROR level messages for failed operations
- Script should log the error and exit code
- Script should return non-zero exit code

---

## Test Case 10: Log File Append Behavior

### Objective
Verify that running scripts multiple times on the same day appends to existing log file.

### Steps
1. Execute either batch script
2. Note the log file contents
3. Execute the same script again
4. Check log file

### Expected Results
- Same log file is used (not overwritten)
- New entries are appended
- All executions are recorded chronologically

---

## Test Case 11: Timestamp Accuracy

### Objective
Verify timestamps are accurate and include milliseconds.

### Steps
1. Note current system time
2. Execute a batch script
3. Immediately check log file timestamp

### Expected Results
- Timestamp should match system time within 1-2 seconds
- Timestamp should include milliseconds (format: HH:MM:SS.fff)
- Timezone should be correctly identified

---

## Test Case 12: Special Characters in Messages

### Objective
Verify logging handles special characters correctly.

### Steps
1. Review log files for messages containing special characters
2. Check for proper encoding

### Expected Results
- Special characters should be logged correctly
- No encoding issues
- Messages should be readable

---

## Validation Checklist

For each refactored script, verify:

- [ ] Log directory is created automatically
- [ ] Log file naming follows: `<scriptname>_batch_YYYY-MM-DD.log`
- [ ] Log format matches: `[timestamp timezone] [level] [scriptname] [hostname] [pid] message`
- [ ] Timestamps include milliseconds
- [ ] Multiple log levels are used (INFO, WARNING, ERROR)
- [ ] All significant operations are logged
- [ ] Success and failure paths are logged appropriately
- [ ] Exit codes are logged
- [ ] Log files are appended on same-day re-runs
- [ ] Script functionality remains unchanged (only logging added)

---

## Performance Considerations

### Test Case 13: Logging Overhead

### Objective
Measure performance impact of logging.

### Steps
1. Time script execution without logging (use old version)
2. Time script execution with logging (new version)
3. Compare execution times

### Expected Results
- Logging overhead should be minimal (<500ms per log call)
- Overall script performance should not be significantly impacted

---

## Issues to Watch For

1. **WMIC Deprecation**: Windows 11 may deprecate `wmic`. Consider alternative if needed.
2. **PowerShell Availability**: Ensure PowerShell is available for timestamp generation.
3. **File Permissions**: Log directory must be writable.
4. **Long Running Scripts**: Ensure PID remains consistent throughout execution.
5. **Timezone Handling**: Verify timezone abbreviation is correctly captured.

---

## Test Sign-Off

| Test Case | Status | Tester | Date | Notes |
|-----------|--------|--------|------|-------|
| TC1 - Log Creation (RunDeleteOldDownloads) | | | | |
| TC2 - Log Format (RunDeleteOldDownloads) | | | | |
| TC3 - PS7 Detection | | | | |
| TC4 - Success Scenario | | | | |
| TC5 - Failure Scenario | | | | |
| TC6 - Log Creation (printcancel) | | | | |
| TC7 - Log Format (printcancel) | | | | |
| TC8 - Complete Operation Logging | | | | |
| TC9 - Service Failure | | | | |
| TC10 - Append Behavior | | | | |
| TC11 - Timestamp Accuracy | | | | |
| TC12 - Special Characters | | | | |
| TC13 - Performance | | | | |

---

## Post-Test Actions

After successful testing:
1. Document any issues found
2. Update scripts if necessary
3. Re-test failed cases
4. Archive test results
5. Update CHANGELOG with test results reference

---

## Notes

- All tests should be performed on a test system first
- printcancel.cmd requires administrator privileges
- Ensure backups exist before testing
- Test on both Windows 10 and Windows 11 if possible
- Test with both Windows PowerShell 5.1 and PowerShell 7
