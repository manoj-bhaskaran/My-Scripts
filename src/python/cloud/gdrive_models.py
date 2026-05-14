"""
gdrive_models.py — Data model types for the Google Drive Trash Recovery Tool.

Contains TypedDicts, dataclasses, and the PostRestorePolicy class that define
the type contracts shared across all gdrive_recover subsystems.

All imports are standard-library only; no Google API dependencies.
"""

import re
from typing import Dict, List, Optional, TypedDict
from dataclasses import dataclass


# -------------------- Minimal structural types --------------------
class FileMeta(TypedDict, total=False):
    """Metadata returned by Drive files().get/list we care about."""

    id: str
    name: str
    mimeType: str
    size: int | str
    createdTime: str
    modifiedTime: str
    trashed: bool
    error: str


class LockInfo(TypedDict, total=False):
    pid: str
    run_id: str


@dataclass
class RecoveryItem:
    """Represents a file to be recovered."""

    id: str
    name: str
    size: int
    mime_type: str
    created_time: str
    will_recover: bool = True
    will_download: bool = False
    target_path: str = ""
    relative_path: str = (
        ""  # subfolder path relative to --folder-id root (for hierarchy reconstruction)
    )
    post_restore_action: str = ""
    status: str = "pending"  # pending, recovered, downloaded, failed
    error_message: str = ""
    source_folder_id: str = ""  # Drive ID of the file's parent folder at discovery time

    def __post_init__(self):
        if not self.post_restore_action:
            self.post_restore_action = PostRestorePolicy.TRASH


@dataclass
class RecoveryStateScope:
    """Identifies what a recovery run is doing so resumes are scope-checked.

    Resuming a state file written by one source/command against a different
    invocation produced a silent failure mode in earlier versions (e.g. a
    recover-only run untrashed IDs that a later recover-and-download run then
    skipped without ever downloading). The scope block is compared on load and
    a mismatch refuses to resume.
    """

    source: str = ""  # trash_query | folder_id | file_ids | retry_failed_file
    command: str = ""  # recover_only | recover_and_download
    key: str = ""  # scope-discriminating key (see RecoveryStateManager._derive_scope_from_args)


@dataclass
class RecoveryState:
    """Persistent state for resume capability."""

    schema_version: int = 2  # v1.23.0: v2 adds the `scope` block; v1 files auto-migrate.
    total_found: int = 0
    processed_items: Optional[List[str]] = None  # List of processed file IDs
    start_time: str = ""
    last_checkpoint: str = ""
    run_id: str = ""
    scope: Optional[RecoveryStateScope] = None

    def __post_init__(self):
        if self.processed_items is None:
            self.processed_items = []


class PostRestorePolicy:
    """Post-restore policy options."""

    # Canonical short forms used internally
    RETAIN = "retain"
    TRASH = "trash"
    DELETE = "delete"

    # Back-compat & friendly aliases → canonical
    ALIASES: Dict[str, str] = {
        # canonical
        "retain": RETAIN,
        "trash": TRASH,
        "delete": DELETE,
        # legacy long forms
        "retainondrive": RETAIN,
        "movetodrivetrash": TRASH,
        "removefromdrive": DELETE,
        # friendly
        "keep": RETAIN,
        "keepondrive": RETAIN,
        "move2trash": TRASH,
        "purge": DELETE,
        # common variants
        "move-to-drive-trash": TRASH,
        "move-to-trash": TRASH,
    }

    @staticmethod
    def normalize(token: Optional[str]) -> str:
        if not token:
            return PostRestorePolicy.TRASH
        key = re.sub(r"[\s_-]+", "", token.strip().lower())
        return PostRestorePolicy.ALIASES.get(key, PostRestorePolicy.TRASH)
