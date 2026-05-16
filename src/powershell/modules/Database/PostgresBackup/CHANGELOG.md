# PostgresBackup Module – Changelog

All notable changes to the **PostgresBackup PowerShell module** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.1.2] - 2026-05-16
### Changed
- Refactored `Resolve-PgDumpPath` into four single-purpose helpers
  (`Resolve-PgDumpFromEnvOverride`, `Resolve-PgDumpFromPgBin`,
  `Resolve-PgDumpFromPath`, `Resolve-PgDumpFromInstallRoots`) plus a
  `Get-PgVersionFromName` parser. The entry function is now an ordered
  dispatch loop, reducing its cognitive complexity from 18 to within the
  allowed 15. No behavioural change — resolution order and version
  selection are identical.

## [2.1.1] - 2026-05-16
### Fixed
- `Resolve-PgDumpPath` now collects version directories across **all** Windows
  install roots (`%ProgramFiles%` and `%ProgramFiles(x86)%`) and sorts them
  globally before selecting. Previously the scan returned the newest version
  found under the *first* existing root, which could pick an older `pg_dump`
  when a newer major version was installed only under a later root —
  contradicting the documented "newest major version first" behaviour.

## [2.1.0] - 2026-05-16
### Changed
- `pg_dump` path is no longer hardcoded to `D:\Program Files\PostgreSQL\17\bin\pg_dump.exe`.
  `Private/Config.ps1` now resolves it via `Resolve-PgDumpPath`, which checks, in order:
  the `PGBACKUP_PGDUMP` environment variable, the `PGBIN` environment variable,
  `pg_dump` on `PATH`, and finally the standard Windows install roots
  (`%ProgramFiles%\PostgreSQL\<ver>\bin`, newest major version first). This makes
  the module portable across machines with different drive layouts / PostgreSQL
  versions.

### Added
- `Resolve-PgDumpPath` private helper. Emits a warning when `pg_dump` cannot be
  located so misconfiguration surfaces clearly.

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
