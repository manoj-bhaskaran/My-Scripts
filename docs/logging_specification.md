# Cross-Platform Logging Specification

## Objective

To establish a standardised, language-agnostic logging format and framework that ensures consistent, centralised, and maintainable log generation across automation scripts written in **Python**, **PowerShell**, and **Batch**.

---

## 1. Log Message Format

Each log entry MUST follow the format:

```
[YYYY-MM-DD HH:MM:SS TIMEZONE] [LEVEL] [SCRIPT_NAME] [HOST] [PROCESS_ID] [MESSAGE] [key1=value1 key2=value2 ...]
```

**Example**:

```
[2025-05-28 11:52:43 IST] [INFO] [sync_backups.ps1] [HOST01] [1234] Backup completed successfully [task=sync run_id=abc123]
```

### Timestamp

- Format: `YYYY-MM-DD HH:MM:SS TIMEZONE` (e.g., IST, UTC)
- All scripts MUST use local system timezone, explicitly included.

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

- `SCRIPT_NAME`: Name of the script generating the log
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
<repo_root>/logs/
```

Scripts MUST NOT write logs into their source code directories. The logs directory should be created at runtime if it does not exist.

Sub-directories can be created by script type or service (optional).

---

## 6. Log Purge Strategy

A **central purge mechanism** must be defined and invoked via scheduler or during deployments.

### Strategy Types

- **Time-Based Retention**: Delete log files older than **N days** (default: 30).
- **Size-Based Retention**: If `<repo_root>/logs` exceeds a configurable threshold (e.g., 500MB), delete oldest logs first.

### Purge Script Requirements

- Language: PowerShell or Python
- Must support configuration via:
  - Retention period in days
  - Maximum directory size
- Must log purge actions using the same logging specification

---

## 7. Compliance and Implementation Notes

- All new scripts must integrate the standard logging module for their language.
- Existing scripts must be refactored during maintenance or enhancement cycles.
- Batch files may use PowerShell invocations for logging if structured logging is not feasible.
- Custom metadata keys must be documented in the corresponding script/module.
