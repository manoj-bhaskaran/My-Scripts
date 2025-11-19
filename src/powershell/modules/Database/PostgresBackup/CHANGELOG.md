# PostgresBackup Module – Changelog

All notable changes to the **PostgresBackup PowerShell module** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.0.0] - 2024-11-19
### Added
- Comprehensive module documentation (README.md, CHANGELOG.md)
- Module manifest (.psd1) with metadata, tags, and version tracking
- Initial versioned release tracking

### Changed
- Updated documentation to reflect current functionality

## [1.0.0] - (Prior Release)
### Added
- PostgreSQL database backup using `pg_dump` with custom format (`-Fc`)
- Automatic PostgreSQL service management (start/stop based on initial state)
- Dual retention strategy:
  - Age-based retention (configurable days)
  - Count-based retention (minimum recent backups)
- Automatic cleanup of zero-byte backup files
- Standardized logging with `[YYYYMMDD-HHMMSS]` timestamp format
- Task Scheduler compatible exit codes (0=success, 1=failure)
- SecureString password support with .pgpass fallback
- Service startup wait with configurable timeout
- Comprehensive error handling and state restoration

### Features
- **Backup File Format:** `<dbname>_YYYYMMDD_HHMMSS.backup`
- **Service Control:** Automatic start/stop with state preservation
- **Retention Management:** Dual policy (age + minimum count)
- **Authentication:** SecureString password or .pgpass file support
- **Logging:** Timestamped operation logs for audit trail

### Configuration
- PostgreSQL 17+ support with hardcoded paths
- Service name: `postgresql-x64-17`
- Default retention: 90 days
- Default minimum backups: 3
- Service startup wait: 5 seconds
- Maximum wait time: 15 seconds

## [Unreleased]
### Planned
- Configuration file support (remove hardcoded paths)
- Multiple PostgreSQL version support
- Parallel multi-database backup support
- Backup verification (test restore)
- Email notifications on failure
- Backup encryption support
- Compression level configuration
- Remote backup destination support
- Health check endpoint integration

---

For usage examples and detailed documentation, see [README.md](./README.md).
