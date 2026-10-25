#!/usr/bin/env python3
"""Create and verify a consistent online backup of a SQLite database."""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path


def verify_database(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Database file does not exist: {path}")
    with sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True) as connection:
        result = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if result != "ok":
        raise RuntimeError(f"SQLite integrity check failed for {path}: {result}")


def create_backup(source: Path, destination: Path) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if source == destination:
        raise ValueError("Backup source and destination must be different files.")
    if not source.is_file():
        raise FileNotFoundError(f"Database file does not exist: {source}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor = os.open(
        destination,
        os.O_CREAT | os.O_EXCL | os.O_WRONLY,
        0o600,
    )
    os.close(file_descriptor)
    try:
        with sqlite3.connect(source) as source_connection:
            with sqlite3.connect(destination) as destination_connection:
                source_connection.backup(destination_connection)
        verify_database(destination)
    except Exception:
        destination.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    backup_parser = subparsers.add_parser("backup", help="Create an online database backup")
    backup_parser.add_argument("source", type=Path)
    backup_parser.add_argument("destination", type=Path)

    verify_parser = subparsers.add_parser("verify", help="Check a database backup")
    verify_parser.add_argument("database", type=Path)

    arguments = parser.parse_args()
    try:
        if arguments.command == "backup":
            create_backup(arguments.source, arguments.destination)
            print(f"Backup created and verified: {arguments.destination}")
        else:
            verify_database(arguments.database)
            print(f"Database integrity check passed: {arguments.database}")
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
        print(f"Database backup operation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
