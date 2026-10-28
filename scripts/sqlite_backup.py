#!/usr/bin/env python3
"""Create and verify a consistent online backup of a SQLite database."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import os
import signal
import sqlite3
import sys
import tempfile
import threading
import time
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
    file_descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".partial",
        dir=destination.parent,
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_path)
    try:
        with sqlite3.connect(f"{source.as_uri()}?mode=ro", uri=True) as source_connection:
            with sqlite3.connect(temporary_path) as destination_connection:
                source_connection.backup(destination_connection)
        verify_database(temporary_path)
        os.link(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def prune_backups(directory: Path, retention_days: int, now: float | None = None) -> int:
    if retention_days < 1:
        raise ValueError("Backup retention must be at least one day.")
    if not directory.is_dir():
        return 0

    cutoff = (time.time() if now is None else now) - retention_days * 24 * 60 * 60
    removed = 0
    for backup in directory.glob("fable-*.sqlite3"):
        if backup.is_symlink() or not backup.is_file():
            continue
        if backup.stat().st_mtime < cutoff:
            backup.unlink()
            removed += 1
    return removed


def create_scheduled_backup(
    source: Path,
    directory: Path,
    retention_days: int,
    now: datetime | None = None,
) -> Path:
    if retention_days < 1:
        raise ValueError("Backup retention must be at least one day.")
    timestamp = now or datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        raise ValueError("Backup timestamps must include a timezone.")
    destination = directory / f"fable-{timestamp.astimezone(timezone.utc):%Y%m%dT%H%M%S.%fZ}.sqlite3"
    create_backup(source, destination)
    removed = prune_backups(directory, retention_days, timestamp.timestamp())
    print(f"Backup created and verified: {destination}; pruned {removed} expired backup(s)", flush=True)
    return destination


def run_schedule(
    source: Path,
    directory: Path,
    interval_seconds: int,
    retention_days: int,
) -> None:
    if interval_seconds < 60:
        raise ValueError("Backup interval must be at least 60 seconds.")
    if retention_days < 1:
        raise ValueError("Backup retention must be at least one day.")

    stop_event = threading.Event()
    signal.signal(signal.SIGTERM, lambda _signum, _frame: stop_event.set())
    signal.signal(signal.SIGINT, lambda _signum, _frame: stop_event.set())
    while not stop_event.is_set():
        try:
            create_scheduled_backup(source, directory, retention_days)
            retry_delay = interval_seconds
        except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
            print(f"Scheduled database backup failed: {error}", file=sys.stderr, flush=True)
            retry_delay = min(interval_seconds, 300)
        stop_event.wait(retry_delay)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    backup_parser = subparsers.add_parser("backup", help="Create an online database backup")
    backup_parser.add_argument("source", type=Path)
    backup_parser.add_argument("destination", type=Path)

    verify_parser = subparsers.add_parser("verify", help="Check a database backup")
    verify_parser.add_argument("database", type=Path)

    schedule_parser = subparsers.add_parser("schedule", help="Create verified backups on a recurring interval")
    schedule_parser.add_argument("source", type=Path)
    schedule_parser.add_argument("directory", type=Path)
    schedule_parser.add_argument(
        "--interval-seconds",
        type=int,
        default=int(os.environ.get("FABLE_BACKUP_INTERVAL_SECONDS", "86400")),
    )
    schedule_parser.add_argument(
        "--retention-days",
        type=int,
        default=int(os.environ.get("FABLE_BACKUP_RETENTION_DAYS", "30")),
    )

    arguments = parser.parse_args()
    try:
        if arguments.command == "backup":
            create_backup(arguments.source, arguments.destination)
            print(f"Backup created and verified: {arguments.destination}")
        elif arguments.command == "verify":
            verify_database(arguments.database)
            print(f"Database integrity check passed: {arguments.database}")
        else:
            run_schedule(
                arguments.source,
                arguments.directory,
                arguments.interval_seconds,
                arguments.retention_days,
            )
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
        print(f"Database backup operation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
