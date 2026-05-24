# gdrive_recover.py Usage Examples

All commands are invoked via:

```bash
python src/python/cloud/gdrive_recover.py <subcommand> [options]
```

## Dry-run (preview only — no changes made)

```bash
# Preview all recoverable trashed files
python src/python/cloud/gdrive_recover.py dry-run

# Preview trashed JPG and PNG files only
python src/python/cloud/gdrive_recover.py dry-run --extensions jpg png

# Preview specific files by their Drive IDs
python src/python/cloud/gdrive_recover.py dry-run --file-ids FILE_ID_1 FILE_ID_2

# Preview what a folder download would look like
python src/python/cloud/gdrive_recover.py dry-run --folder-id DRIVE_FOLDER_ID --post-restore-policy retain
```

## Recover-only (restore in Drive, no local download)

```bash
python src/python/cloud/gdrive_recover.py recover-only
python src/python/cloud/gdrive_recover.py recover-only --extensions pdf docx --after-date 2024-06-01
python src/python/cloud/gdrive_recover.py recover-only --file-ids FILE_ID_1 FILE_ID_2 --yes
```

## Recover-and-download (restore and download)

```bash
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered --post-restore-policy retain
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered --post-restore-policy delete --yes
```

## Folder-scoped download

```bash
python src/python/cloud/gdrive_recover.py recover-and-download --folder-id DRIVE_FOLDER_ID --download-dir ./my_backup --post-restore-policy retain
```

## Resume, logging, and retries

```bash
# Resume with explicit state file
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered --state-file ./recovery_state.json --yes

# Capture run log and failed items
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered --log-file ./logs/run.log --failed-file ./logs/failed.csv --post-restore-policy retain

# Retry failed items from CSV
python src/python/cloud/gdrive_recover.py recover-and-download --download-dir ./recovered --retry-failed-file ./logs/failed.csv --post-restore-policy retain
```

For full option reference, run:

```bash
python src/python/cloud/gdrive_recover.py --help
python src/python/cloud/gdrive_recover.py dry-run --help
python src/python/cloud/gdrive_recover.py recover-only --help
python src/python/cloud/gdrive_recover.py recover-and-download --help
```
