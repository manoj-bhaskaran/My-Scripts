"""
Google Drive Storage Monitor Script

This script monitors the storage usage of a Google Drive account and clears the trash
if the usage exceeds a specified threshold. It logs the storage usage details and actions
performed to a log file using the standard cross-platform logging framework.
"""

import os
import sys
from pathlib import Path

# Add module paths to sys.path for imports
script_dir = Path(__file__).resolve().parent
repo_root = script_dir.parent.parent.parent
modules_logging = repo_root / "src" / "python" / "modules" / "logging"
modules_auth = repo_root / "src" / "python" / "modules" / "auth"

sys.path.insert(0, str(modules_logging))
sys.path.insert(0, str(modules_auth))

import argparse
import logging
from googleapiclient.errors import HttpError
from google_drive_auth import authenticate_and_get_drive_service
import python_logging_framework as plog  # Uses standardised logging framework

# Initialize logger for this module
logger = plog.initialise_logger(__name__)


def format_size(bytes_size):
    """
    Converts a size in bytes to a human-readable format.

    Args:
        bytes_size (int): Size in bytes.

    Returns:
        str: Human-readable size with appropriate units.
    """
    units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
    size = bytes_size
    unit_index = 0

    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1

    return f"{size:.2f} {units[unit_index]}"


def get_storage_usage(service):
    """
    Retrieves the storage usage details from Google Drive.

    Args:
        service: Authenticated Google Drive API service instance.

    Returns:
        tuple: (usage_percentage, total_usage, limit) or (None, None, None) in case of an error.
    """
    try:
        about = service.about().get(fields="storageQuota").execute()
        plog.log_debug(logger, f"Storage quota data: {about}")

        usage_in_drive = int(about["storageQuota"].get("usageInDrive", 0))
        usage_in_drive_trash = int(about["storageQuota"].get("usageInDriveTrash", 0))
        total_usage = usage_in_drive + usage_in_drive_trash
        limit = int(about["storageQuota"]["limit"])

        usage_percentage = (total_usage / limit) * 100

        readable_total_usage = format_size(total_usage)
        readable_limit = format_size(limit)

        plog.log_info(
            logger,
            f"Current storage usage: {readable_total_usage} / {readable_limit} ({usage_percentage:.2f}%)",
        )
        return usage_percentage, total_usage, limit
    except HttpError as error:
        plog.log_error(logger, f"An error occurred: {error}")
        return None, None, None


def clear_trash(service):
    """
    Clears the trash in Google Drive.

    Args:
        service: Authenticated Google Drive API service instance.
    """
    try:
        service.files().emptyTrash().execute()
        plog.log_info(logger, "Trash cleared successfully.")
    except HttpError as error:
        plog.log_error(logger, f"An error occurred: {error}")


def main(debug, threshold):
    """
    Main function to monitor storage usage and clear trash if necessary.

    Args:
        debug (bool): If True, enables debug-level logging.
        threshold (float): Threshold percentage for storage usage.
    """
    # Logger already initialized at module level, just update level if needed
    if debug:
        logger.setLevel(logging.DEBUG)
    plog.log_info(logger, f"Using threshold: {threshold}%")

    service = authenticate_and_get_drive_service()
    usage_percentage, usage, limit = get_storage_usage(service)

    if usage_percentage is not None:
        readable_total_usage = format_size(usage)
        readable_limit = format_size(limit)

        if usage_percentage > threshold:
            plog.log_info(
                logger,
                f"Storage usage exceeds {threshold}%: {usage_percentage:.2f}% "
                f"({readable_total_usage} of {readable_limit}). Clearing trash.",
            )
            clear_trash(service)

            new_usage_percentage, new_usage, _ = get_storage_usage(service)
            readable_new_usage = format_size(new_usage)
            plog.log_info(
                logger,
                f"Storage usage after trash clearance: {new_usage_percentage:.2f}% "
                f"({readable_new_usage} of {readable_limit}).",
            )
        else:
            plog.log_info(
                logger,
                f"Storage usage is within limits: {usage_percentage:.2f}% "
                f"({readable_total_usage} of {readable_limit}).",
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Google Drive Storage Monitor")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument(
        "--threshold",
        "-t",
        type=float,
        default=90.0,
        help="Threshold percentage for storage usage (default: 90%)",
    )
    args = parser.parse_args()

    if not (0 < args.threshold < 100):
        raise ValueError("Threshold must be a value between 0 and 100 (exclusive).")

    main(args.debug, args.threshold)
