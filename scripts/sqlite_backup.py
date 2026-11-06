#!/usr/bin/env python3
"""Create, encrypt, verify, and restore consistent SQLite backups."""

from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
import os
import signal
import sqlite3
import struct
import sys
import tempfile
import threading
import time
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


BACKUP_KEY_ENV = "FABLE_BACKUP_ENCRYPTION_KEY_B64"
BACKUP_MAGIC = b"FABLEBK1"
BACKUP_HEADER_SIZE = 28
BACKUP_CHUNK_BYTES = 1024 * 1024
BACKUP_TAG_BYTES = 16
MAX_BACKUP_CHUNKS = 2**32


def load_backup_encryption_key() -> bytes:
    encoded_key = os.environ.get(BACKUP_KEY_ENV, "").strip()
    if not encoded_key:
        raise RuntimeError(f"{BACKUP_KEY_ENV} must contain a base64-encoded 32-byte key.")
    try:
        key = base64.b64decode(encoded_key, validate=True)
    except (binascii.Error, ValueError) as error:
        raise RuntimeError(f"{BACKUP_KEY_ENV} must contain a base64-encoded 32-byte key.") from error
    if len(key) != 32:
        raise RuntimeError(f"{BACKUP_KEY_ENV} must contain a base64-encoded 32-byte key.")
    return key


def _chunk_associated_data(header: bytes, counter: int, plaintext_size: int) -> bytes:
    return header + struct.pack(">IQ", counter, plaintext_size)


def _encrypt_backup_file(source: Path, destination: Path, key: bytes) -> None:
    size = source.stat().st_size
    chunk_count = max(1, (size + BACKUP_CHUNK_BYTES - 1) // BACKUP_CHUNK_BYTES)
    if chunk_count > MAX_BACKUP_CHUNKS:
        raise ValueError("Backup database is too large to encrypt.")

    nonce_base = int.from_bytes(os.urandom(12), "big")
    if nonce_base + chunk_count - 1 >= 2**96:
        raise ValueError("Unable to allocate unique backup encryption nonces.")
    header = BACKUP_MAGIC + nonce_base.to_bytes(12, "big") + size.to_bytes(8, "big")
    file_descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".partial",
        dir=destination.parent,
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_path)
    cipher = AESGCM(key)

    try:
        with source.open("rb") as source_file, temporary_path.open("wb") as output_file:
            output_file.write(header)
            remaining = size
            for counter in range(chunk_count):
                chunk_size = min(BACKUP_CHUNK_BYTES, remaining)
                plaintext = source_file.read(chunk_size)
                if len(plaintext) != chunk_size:
                    raise RuntimeError("SQLite snapshot changed while it was being encrypted.")
                nonce = (nonce_base + counter).to_bytes(12, "big")
                ciphertext = cipher.encrypt(
                    nonce,
                    plaintext,
                    _chunk_associated_data(header, counter, chunk_size),
                )
                output_file.write(ciphertext)
                remaining -= chunk_size
            if source_file.read(1):
                raise RuntimeError("SQLite snapshot changed while it was being encrypted.")
            output_file.flush()
            os.fsync(output_file.fileno())
        os.link(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def _decrypt_backup_file(source: Path, destination: Path, key: bytes) -> None:
    if not source.is_file():
        raise FileNotFoundError(f"Encrypted backup does not exist: {source}")

    cipher = AESGCM(key)
    with source.open("rb") as source_file:
        header = source_file.read(BACKUP_HEADER_SIZE)
        if len(header) != BACKUP_HEADER_SIZE or not header.startswith(BACKUP_MAGIC):
            raise RuntimeError("Backup file has an unsupported or invalid format.")
        nonce_base = int.from_bytes(header[8:20], "big")
        size = int.from_bytes(header[20:28], "big")
        chunk_count = max(1, (size + BACKUP_CHUNK_BYTES - 1) // BACKUP_CHUNK_BYTES)
        if chunk_count > MAX_BACKUP_CHUNKS:
            raise RuntimeError("Backup file declares an unsupported size.")

        with destination.open("wb") as output_file:
            remaining = size
            for counter in range(chunk_count):
                chunk_size = min(BACKUP_CHUNK_BYTES, remaining)
                ciphertext = source_file.read(chunk_size + BACKUP_TAG_BYTES)
                if len(ciphertext) != chunk_size + BACKUP_TAG_BYTES:
                    raise RuntimeError("Backup file is incomplete or corrupted.")
                nonce = (nonce_base + counter).to_bytes(12, "big")
                try:
                    plaintext = cipher.decrypt(
                        nonce,
                        ciphertext,
                        _chunk_associated_data(header, counter, chunk_size),
                    )
                except InvalidTag as error:
                    raise RuntimeError(
                        "Backup authentication failed; the key may be wrong or the file modified."
                    ) from error
                output_file.write(plaintext)
                remaining -= chunk_size
            if source_file.read(1):
                raise RuntimeError("Backup file contains unexpected trailing data.")
            output_file.flush()
            os.fsync(output_file.fileno())


def _temporary_database(directory: Path) -> Path:
    file_descriptor, temporary_path = tempfile.mkstemp(
        prefix=".fable-restore.",
        suffix=".sqlite3.partial",
        dir=directory,
    )
    os.close(file_descriptor)
    return Path(temporary_path)


def verify_database(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Database file does not exist: {path}")
    with sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True) as connection:
        result = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if result != "ok":
        raise RuntimeError(f"SQLite integrity check failed for {path}: {result}")


def create_backup(source: Path, destination: Path, encryption_key: bytes | None = None) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if source == destination:
        raise ValueError("Backup source and destination must be different files.")
    if not source.is_file():
        raise FileNotFoundError(f"Database file does not exist: {source}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    key = encryption_key or load_backup_encryption_key()
    with tempfile.TemporaryDirectory(prefix=".fable-backup-", dir=destination.parent) as temp_directory:
        snapshot = _temporary_database(Path(temp_directory))
        try:
            with sqlite3.connect(f"{source.as_uri()}?mode=ro", uri=True) as source_connection:
                with sqlite3.connect(snapshot) as destination_connection:
                    source_connection.backup(destination_connection)
            verify_database(snapshot)
            _encrypt_backup_file(snapshot, destination, key)
            try:
                verify_backup(destination, key)
            except Exception:
                destination.unlink(missing_ok=True)
                raise
        finally:
            snapshot.unlink(missing_ok=True)


def verify_backup(source: Path, encryption_key: bytes | None = None) -> None:
    key = encryption_key or load_backup_encryption_key()
    with tempfile.TemporaryDirectory(prefix="fable-backup-verify-") as temp_directory:
        snapshot = _temporary_database(Path(temp_directory))
        try:
            _decrypt_backup_file(source, snapshot, key)
            verify_database(snapshot)
        finally:
            snapshot.unlink(missing_ok=True)


def encrypt_existing_backup(
    source: Path,
    destination: Path,
    encryption_key: bytes | None = None,
) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if source == destination:
        raise ValueError("Backup source and destination must be different files.")
    verify_database(source)
    key = encryption_key or load_backup_encryption_key()
    destination.parent.mkdir(parents=True, exist_ok=True)
    _encrypt_backup_file(source, destination, key)
    try:
        verify_backup(destination, key)
    except Exception:
        destination.unlink(missing_ok=True)
        raise


def restore_backup(
    source: Path,
    destination: Path,
    encryption_key: bytes | None = None,
) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if source == destination:
        raise ValueError("Restore source and destination must be different files.")
    if destination.exists():
        raise FileExistsError(f"Restore destination already exists: {destination}")
    key = encryption_key or load_backup_encryption_key()
    destination.parent.mkdir(parents=True, exist_ok=True)
    snapshot = _temporary_database(destination.parent)
    try:
        _decrypt_backup_file(source, snapshot, key)
        verify_database(snapshot)
        os.link(snapshot, destination)
    finally:
        snapshot.unlink(missing_ok=True)


def prune_backups(directory: Path, retention_days: int, now: float | None = None) -> int:
    if retention_days < 1:
        raise ValueError("Backup retention must be at least one day.")
    if not directory.is_dir():
        return 0

    cutoff = (time.time() if now is None else now) - retention_days * 24 * 60 * 60
    removed = 0
    backups = list(directory.glob("fable-*.sqlite3")) + list(directory.glob("fable-*.sqlite3.enc"))
    for backup in backups:
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
    encryption_key: bytes | None = None,
) -> Path:
    if retention_days < 1:
        raise ValueError("Backup retention must be at least one day.")
    timestamp = now or datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        raise ValueError("Backup timestamps must include a timezone.")
    destination = directory / f"fable-{timestamp.astimezone(timezone.utc):%Y%m%dT%H%M%S.%fZ}.sqlite3.enc"
    create_backup(source, destination, encryption_key)
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
    encryption_key = load_backup_encryption_key()

    stop_event = threading.Event()
    signal.signal(signal.SIGTERM, lambda _signum, _frame: stop_event.set())
    signal.signal(signal.SIGINT, lambda _signum, _frame: stop_event.set())
    while not stop_event.is_set():
        try:
            create_scheduled_backup(source, directory, retention_days, encryption_key=encryption_key)
            retry_delay = interval_seconds
        except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
            print(f"Scheduled database backup failed: {error}", file=sys.stderr, flush=True)
            retry_delay = min(interval_seconds, 300)
        stop_event.wait(retry_delay)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    backup_parser = subparsers.add_parser("backup", help="Create an encrypted online database backup")
    backup_parser.add_argument("source", type=Path)
    backup_parser.add_argument("destination", type=Path)

    encrypt_parser = subparsers.add_parser(
        "encrypt",
        help="Encrypt and verify an existing plaintext SQLite backup",
    )
    encrypt_parser.add_argument("source", type=Path)
    encrypt_parser.add_argument("destination", type=Path)

    verify_parser = subparsers.add_parser("verify", help="Authenticate and check an encrypted backup")
    verify_parser.add_argument("backup", type=Path)

    restore_parser = subparsers.add_parser("restore", help="Decrypt and restore a verified backup")
    restore_parser.add_argument("backup", type=Path)
    restore_parser.add_argument("destination", type=Path)

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
            print(f"Encrypted backup created and verified: {arguments.destination}")
        elif arguments.command == "encrypt":
            encrypt_existing_backup(arguments.source, arguments.destination)
            print(f"Existing SQLite backup encrypted and verified: {arguments.destination}")
        elif arguments.command == "verify":
            verify_backup(arguments.backup)
            print(f"Encrypted backup authentication and integrity checks passed: {arguments.backup}")
        elif arguments.command == "restore":
            restore_backup(arguments.backup, arguments.destination)
            print(f"Backup restored and verified: {arguments.destination}")
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
