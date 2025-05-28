# Cross-Platform Logging Specification

## Objective

To establish a standardised, language-agnostic logging format and framework that ensures consistent, centralised, and maintainable log generation across automation scripts written in **Python**, **PowerShell**, and **Batch**.

---

## 1. Log Message Format

Each log entry MUST follow the format:

```
[YYYY-MM-DD HH:MM:SS[.mmm] TIMEZONE] [LEVEL] [SCRIPT_NAME] [HOST] [PROCESS_ID] [MESSAGE] [key1=value1 key2=value2 ...]
```

**Example**:

```
[2025-05-28 11:52:43.123 IST] [INFO] [sync_backups.ps1] [HOST01] [1234] Backup completed successfully [task=sync run_id=abc123]
```

### Timestamp

- Format: `YYYY-MM-DD HH:MM:SS[.mmm] TIMEZONE` (e.g., IST, UTC)
- Precision up to milliseconds (`.SSS`) is recommended for high-frequency logging scenarios.
- Microseconds (`.SSSSSS`) may be used where forensic accuracy is critical.
- Scripts SHOULD log in IST.

### Fallback

If the primary log destination is unavailable (e.g., file write fails), scripts SHOULD fallback to writing logs to standard output.

---

## 2. Logging Levels

| Level Name | Numeric Value | Description                        |
| ---------- | ------------- | ---------------------------------- |
| DEBUG      | 10            | Detailed diagnostic info           |
| INFO       | 20            | Normal operations, success paths   |
| WARNING    | 30            | Recoverable issues, minor alerts   |
| ERROR      | 40            | Non-recoverable issues, failures   |
| CRITICAL   | 50            | System-wide failures, terminations |

All scripts MUST use only these standard levels.

---

## 3. Metadata Guidelines

### Mandatory Fields

- `SCRIPT_NAME`: Name of the script generating the log (base name with extension)
- `HOST`: Hostname of the machine
- `PROCESS_ID`: OS-level process ID
- `LEVEL`: Logging level as per table
- `TIMESTAMP`: As defined above
- `MESSAGE`: Human-readable description of the event

### Optional Metadata

- `CorrelationId`: Trace ID for workflows spanning multiple scripts
- `User`: Invoking user (if relevant)
- `TaskId`: Sub-task or job identifier
- `FileName`: File being processed
- `Duration`: Time taken (e.g., 4.2s)
- Additional key-value pairs specific to the script context

All metadata fields should follow `key=value` format and be space-separated.

### Structured Format

For enhanced parsing and integration with log aggregation tools, structured logging in JSON format is encouraged. Example:

```json
{
  "timestamp": "2025-05-28T11:52:43.123+05:30",
  "level": "INFO",
  "script": "sync_backups.ps1",
  "host": "HOST01",
  "pid": 1234,
  "message": "Backup completed successfully",
  "metadata": {
    "task": "sync",
    "run_id": "abc123"
  }
}
```

---

## 4. Log File Naming Convention

Log files MUST be named as follows:

```
<script_name>_<language>_<YYYY-MM-DD>.log
```

**Examples**:

- `sync_backups_powershell_2025-05-28.log`
- `upload_tracker_python_2025-05-28.log`
- `run_job_batch_2025-05-28.log`

File names should avoid spaces and use underscores (`_`) as delimiters.

---

## 5. Directory Structure

All log files MUST be written to:

```
<script_root_dir>/logs/
```

Scripts MUST NOT write logs into their source code directories. The logs directory should be created at runtime if it does not exist.

Sub-directories can be created by script type or service (optional).

---

## 6. Log Purge Strategy

A **central purge mechanism** must be defined and invoked via scheduler or during deployments.

### Strategy Types

- **Time-Based Retention**: Delete log files older than **N days** (default: 30).
- **Size-Based Retention**: If `<repo_root>/logs` exceeds a configurable threshold (e.g., 500MB), delete oldest logs first.

> The 30-day default is based on typical operational audit needs and disk usage trade-offs. Increase retention where audit or compliance mandates apply (e.g., financial systems).

### Purge Script Requirements

- Language: PowerShell or Python
- Must support configuration via:
  - Retention period in days
  - Maximum directory size
- Must log purge actions using the same logging specification

### Scheduler Examples

- **Windows**: Use Task Scheduler to run `purge_logs.ps1` weekly on Sundays at 2:00PM.

---

## 7. Compliance and Implementation Notes

- All new scripts must integrate the standard logging module for their language.
- Existing scripts must be refactored during maintenance or enhancement cycles.
- Batch files may use PowerShell invocations for logging if structured logging is not feasible.
- Custom metadata keys must be documented in the corresponding script/module.

### Recommended Libraries

- **Python**: Use `logging`
- **PowerShell**: Use `Write-Output`/`Write-Error` with a wrapper module or consider `PoshLogger`
- **Batch**: Use `echo` or invoke PowerShell logging functions

---

## 8. Security Considerations

- Logs MUST NOT contain sensitive data (e.g., credentials, tokens, PII).
- Log files SHOULD have restricted file permissions (e.g., `chmod 600` or NTFS ACLs).
