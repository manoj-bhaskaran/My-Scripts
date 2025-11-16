# Create Architecture Documentation

## Priority
**LOW** 🟢

## Background
The My-Scripts repository lacks **high-level architecture documentation**:

**Missing:**
- Database schema documentation
- Module dependency graph
- System integration diagrams
- Data flow documentation
- Authentication/authorization flows
- External service integrations

**Impact:**
- Difficult to understand system design
- Hard to onboard new contributors (if needed)
- Unclear module boundaries
- Risk of architectural drift

## Objectives
- Create comprehensive `ARCHITECTURE.md`
- Document database schemas
- Create module dependency graph
- Document external integrations
- Explain design decisions

## Tasks

### Phase 1: Create ARCHITECTURE.md
- [ ] Create `ARCHITECTURE.md` at repository root:
  ```markdown
  # My-Scripts Architecture

  ## Overview
  This document describes the high-level architecture and design decisions
  for the My-Scripts repository.

  ## Design Principles
  - **Language-Based Organization**: Scripts grouped by language (PowerShell, Python)
  - **Domain Categorization**: Further grouped by functional domain
  - **Shared Infrastructure**: Reusable modules for cross-cutting concerns
  - **Cross-Platform**: Support Windows (primary) and Linux/macOS (partial)

  ## System Context
  My-Scripts is a personal automation collection that integrates with:
  - PostgreSQL databases (GnuCash, Job Scheduler, Timeline)
  - Google Drive API (OAuth2 authentication)
  - CloudConvert API
  - VLC Media Player
  - Windows Task Scheduler

  ## Component Architecture
  [Diagram showing major components and their relationships]
  ```

### Phase 2: Document Database Schemas
- [ ] Create `docs/architecture/database-schemas.md`:
  ```markdown
  # Database Schemas

  ## Overview
  My-Scripts interacts with multiple PostgreSQL databases for backup and data processing.

  ## GnuCash Database
  **Purpose**: Personal finance tracking

  **Backup Strategy**:
  - Automated daily backups via `gnucash_pg_backup.ps1`
  - Retention: 30 days
  - Storage: Local and Google Drive

  **Schema** (summary):
  - Tables: accounts, transactions, splits, commodities
  - Key relationships: [diagram]

  ## Timeline Database
  **Purpose**: Personal location/timeline data storage

  **Schema** (DDL in `src/sql/timeline/`):
  - `timeline_entries` – Location data with timestamps
  - `timeline_places` – Identified locations
  - [ER Diagram]

  **Processing Scripts**:
  - `extract_timeline_locations.py` – Parse and load data
  - `csv_to_gpx.py` – Export to GPX format

  ## Job Scheduler Database
  **Purpose**: Task scheduling metadata

  **Backup**: Daily automated backups
  ```
- [ ] Include ER diagrams (can use Mermaid or PlantUML)
- [ ] Document database access patterns

### Phase 3: Create Module Dependency Graph
- [ ] Create `docs/architecture/module-dependencies.md`:
  ```markdown
  # Module Dependencies

  ## PowerShell Modules

  ```mermaid
  graph TD
      Scripts[PowerShell Scripts] --> PostgresBackup
      Scripts --> RandomName
      Scripts --> Videoscreenshot
      Scripts --> Logging[PowerShellLoggingFramework]
      Scripts --> PurgeLogs

      PostgresBackup --> Logging
      Videoscreenshot --> RandomName
      Videoscreenshot --> Logging
      FileDistributor --> RandomName
      FileDistributor --> Logging

      PurgeLogs --> Logging
  ```

  ## Python Modules

  ```mermaid
  graph TD
      PyScripts[Python Scripts] --> PyLogging[python_logging_framework]
      PyScripts --> GoogleAuth[google_drive_auth]
      PyScripts --> Elevation[elevation]

      GoogleDriveScripts --> GoogleAuth
      CloudScripts --> PyLogging
  ```

  ## External Dependencies
  - **VLC**: Required by Videoscreenshot module
  - **PostgreSQL Client**: Required by backup scripts
  - **Google OAuth2**: Required by Google Drive scripts
  - **CloudConvert API**: Required by cloudconvert_utils.py
  ```

### Phase 4: Document External Integrations
- [ ] Create `docs/architecture/external-integrations.md`:
  ```markdown
  # External Service Integrations

  ## Google Drive API
  **Purpose**: Backup storage, file recovery

  **Authentication**: OAuth2 (google_drive_auth.py)
  **Credentials**: Stored in `~/.credentials/` (not in repo)

  **Scripts Using Google Drive**:
  - `gdrive_recover.py` – Recover deleted files
  - `google_drive_root_files_delete.py` – Cleanup root folder
  - `drive_space_monitor.py` – Monitor storage usage

  **API Scopes Required**:
  - `drive.file` – Per-file access
  - `drive.metadata.readonly` – List files

  ## CloudConvert API
  **Purpose**: File format conversions

  **Authentication**: API key (environment variable)
  **Scripts**: `cloudconvert_utils.py`

  ## PostgreSQL
  **Purpose**: Database backups

  **Connection**: Environment variables (PGHOST, PGPORT, PGUSER, PGPASSWORD)
  **Databases**: GnuCash, Job Scheduler, Timeline

  ## VLC Media Player
  **Purpose**: Video processing, screenshots

  **Integration**: Command-line invocation
  **Module**: Videoscreenshot
  **Requirements**: VLC on PATH
  ```

### Phase 5: Document Data Flows
- [ ] Create `docs/architecture/data-flows.md`:
  ```markdown
  # Data Flows

  ## Backup Workflow
  ```mermaid
  sequenceDiagram
      participant Scheduler as Task Scheduler
      participant Script as Backup Script
      participant PG as PostgreSQL
      participant Local as Local Storage
      participant GDrive as Google Drive

      Scheduler->>Script: Daily trigger (2 AM)
      Script->>PG: pg_dump
      PG-->>Script: SQL backup file
      Script->>Local: Save to backups/
      Script->>GDrive: Upload backup
      Script->>Script: Log completion
  ```

  ## Timeline Processing Workflow
  ```mermaid
  flowchart LR
      Google[Google Takeout] --> Extract[extract_timeline_locations.py]
      Extract --> PG[(Timeline DB)]
      PG --> CSV[csv_to_gpx.py]
      CSV --> GPX[GPX Files]
  ```

  ## Log Management Workflow
  ```mermaid
  flowchart TD
      Scripts[All Scripts] --> Write[Write Logs]
      Write --> LogDir[logs/]
      Scheduler[Task Scheduler] --> Purge[PurgeLogs.psm1]
      Purge --> LogDir
      Purge --> Delete[Delete Old Logs]
  ```
  ```

### Phase 6: Document Design Decisions
- [ ] Add "Design Decisions" section to ARCHITECTURE.md:
  ```markdown
  ## Key Design Decisions

  ### Decision: Monolithic Repository
  **Context**: Multiple scripts across different languages and domains

  **Decision**: Keep as single repository (not split)

  **Rationale**:
  - Single maintainer (no team boundaries)
  - Shared infrastructure (logging, auth, database modules)
  - Unified CI/CD pipeline
  - Cross-script workflows

  **Alternatives Considered**: Separate repos per domain
  **Trade-offs**: May grow unwieldy over time

  ### Decision: Cross-Platform Logging Specification
  **Context**: Scripts in PowerShell and Python need consistent logging

  **Decision**: Standardize log format across languages

  **Rationale**:
  - Easier log aggregation
  - Consistent troubleshooting
  - Centralized log purging

  **Implementation**: `docs/specifications/logging_specification.md`

  ### Decision: PowerShell 7+ for New Scripts
  **Context**: Videoscreenshot module migrated to PowerShell Core

  **Decision**: Prefer PowerShell 7+ for new scripts (cross-platform)

  **Rationale**:
  - Cross-platform support
  - Modern language features
  - Better performance

  **Trade-offs**: Requires PowerShell Core installation
  ```

### Phase 7: Add Diagrams
- [ ] Create diagrams using Mermaid, PlantUML, or draw.io:
  - High-level component diagram
  - Module dependency graph
  - Database ER diagrams
  - Data flow diagrams
- [ ] Embed diagrams in Markdown or link to images
- [ ] Store diagram sources in `docs/architecture/diagrams/`

### Phase 8: Link from README
- [ ] Update README.md:
  ```markdown
  ## Architecture

  For architectural overview and design decisions, see:
  - [ARCHITECTURE.md](ARCHITECTURE.md) – High-level architecture
  - [Database Schemas](docs/architecture/database-schemas.md)
  - [Module Dependencies](docs/architecture/module-dependencies.md)
  - [External Integrations](docs/architecture/external-integrations.md)
  - [Data Flows](docs/architecture/data-flows.md)
  ```

## Acceptance Criteria
- [x] `ARCHITECTURE.md` created at repository root
- [x] Database schemas documented with ER diagrams (minimum 2)
- [x] Module dependency graph created (Mermaid or similar)
- [x] External integrations documented (minimum 4 services)
- [x] Data flow diagrams created (minimum 3 workflows)
- [x] Design decisions documented (minimum 3 decisions)
- [x] All documentation linked from README.md
- [x] Diagrams render correctly in GitHub

## Related Files
- `ARCHITECTURE.md` (to be created)
- `docs/architecture/database-schemas.md` (to be created)
- `docs/architecture/module-dependencies.md` (to be created)
- `docs/architecture/external-integrations.md` (to be created)
- `docs/architecture/data-flows.md` (to be created)
- `docs/architecture/diagrams/` (to be created)
- `README.md` (to be updated)

## Estimated Effort
**2-3 days** (documentation, diagrams, review)

## Dependencies
- Issue #006 (Folder Reorganization) – for accurate module paths

## Tools
- [Mermaid](https://mermaid.js.org/) – Diagramming in Markdown
- [PlantUML](https://plantuml.com/) – Alternative diagramming
- [draw.io](https://draw.io/) – Visual diagram editor
- [dbdiagram.io](https://dbdiagram.io/) – Database schema diagrams

## References
- [C4 Model](https://c4model.com/) – Software architecture diagrams
- [Arc42](https://arc42.org/) – Architecture documentation template
