#!/usr/bin/env python3
"""Fail when the encrypted SQLite backup directory has no recent snapshot."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import time


DEFAULT_MAX_AGE_SECONDS = 26 * 60 * 60
MAX_AGE_ENV = "FABLE_BACKUP_HEALTH_MAX_AGE_SECONDS"


def _max_age_from_environment() -> int:
    value = os.environ.get(MAX_AGE_ENV, str(DEFAULT_MAX_AGE_SECONDS)).strip()
    try:
        max_age = int(value)
    except ValueError as error:
        raise ValueError(f"{MAX_AGE_ENV} must be a positive integer.") from error
    if max_age < 60:
        raise ValueError(f"{MAX_AGE_ENV} must be at least 60 seconds.")
    return max_age


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="directory containing encrypted backups")
    parser.add_argument(
        "--max-age-seconds",
        type=int,
        default=None,
        help=f"override {MAX_AGE_ENV}",
    )
    args = parser.parse_args()

    try:
        max_age = args.max_age_seconds if args.max_age_seconds is not None else _max_age_from_environment()
        if max_age < 60:
            raise ValueError("Maximum backup age must be at least 60 seconds.")
        if not args.directory.is_dir():
            raise FileNotFoundError(f"Backup directory does not exist: {args.directory}")

        backups = [
            path
            for path in args.directory.glob("fable-*.sqlite3.enc")
            if path.is_file() and not path.is_symlink()
        ]
        if not backups:
            raise FileNotFoundError(f"No encrypted Fable backups found in {args.directory}")

        newest = max(backups, key=lambda path: path.stat().st_mtime)
        age_seconds = time.time() - newest.stat().st_mtime
        if age_seconds < -300:
            raise RuntimeError(f"Newest backup timestamp is unexpectedly in the future: {newest.name}")
        age_seconds = max(0, int(age_seconds))
        if age_seconds > max_age:
            raise RuntimeError(
                f"Newest encrypted backup is {age_seconds} seconds old; maximum is {max_age} seconds."
            )

        print(f"Backup freshness OK: {newest.name} is {age_seconds} seconds old.")
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Backup freshness check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
