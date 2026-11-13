from __future__ import annotations

import os
import sqlite3
from urllib.parse import parse_qs, urlsplit

import psycopg
from psycopg.rows import dict_row

DB_PATH = os.environ.get("FABLE_DB_PATH", "fable.sqlite3")
SCHEMA_VERSION = 4
LEGACY_DEMO_STORY_IDS = (
    "66666666-6666-6666-6666-666666666666",
    "77777777-7777-7777-7777-777777777777",
    "88888888-8888-8888-8888-888888888888",
    "99999999-9999-9999-9999-999999999999",
    "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "cccccccc-cccc-cccc-cccc-cccccccccccc",
    "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
    "ffffffff-ffff-ffff-ffff-ffffffffffff",
    "10101010-1010-1010-1010-101010101010",
    "20202020-2020-2020-2020-202020202020",
    "e1a10001-0000-0000-0000-000000000001",
    "e1a10002-0000-0000-0000-000000000002",
    "e1a10003-0000-0000-0000-000000000003",
    "e1a10004-0000-0000-0000-000000000004",
)


def _postgres_url() -> str | None:
    backend = os.environ.get("FABLE_DATABASE_BACKEND", "auto").strip().lower()
    if backend not in {"auto", "sqlite", "postgres"}:
        raise RuntimeError("FABLE_DATABASE_BACKEND must be auto, sqlite, or postgres.")

    value = os.environ.get("DATABASE_URL", "").strip()
    if backend == "sqlite":
        return None
    if not value:
        if backend == "postgres":
            raise RuntimeError("DATABASE_URL is required when FABLE_DATABASE_BACKEND=postgres.")
        return None
    parsed_url = urlsplit(value)
    if parsed_url.scheme not in {"postgres", "postgresql"}:
        raise RuntimeError("DATABASE_URL must use the PostgreSQL URL scheme.")
    sslmode = parse_qs(parsed_url.query).get("sslmode", [None])[0]
    if sslmode not in {
        "require",
        "verify-ca",
        "verify-full",
    } and os.environ.get("FABLE_ENV", "").strip().lower() not in {
        "development",
        "dev",
        "local",
        "test",
    }:
        raise RuntimeError("DATABASE_URL must require TLS with sslmode=require or stronger.")
    return value


def _postgres_placeholders(statement: str) -> str:
    """Translate SQLite qmark parameters while leaving quoted SQL untouched."""
    output: list[str] = []
    quote: str | None = None
    index = 0
    while index < len(statement):
        character = statement[index]
        if quote:
            output.append(character)
            if character == quote:
                if index + 1 < len(statement) and statement[index + 1] == quote:
                    output.append(statement[index + 1])
                    index += 1
                else:
                    quote = None
        elif character in {"'", '"'}:
            quote = character
            output.append(character)
        elif character == "?":
            output.append("%s")
        else:
            output.append(character)
        index += 1
    return "".join(output)


class PostgresConnection:
    """Expose the small SQLite-style connection surface used by the services."""

    def __init__(self, connection: psycopg.Connection):
        self._connection = connection

    def execute(self, statement: str, parameters=()):
        if statement.strip().upper() == "BEGIN IMMEDIATE":
            statement = "SELECT 1 AS transaction_started"
        else:
            statement = _postgres_placeholders(statement)
        return self._connection.execute(statement, parameters)

    def lock_key(self, key: str) -> None:
        self.execute(
            "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",
            (key,),
        )

    @property
    def in_transaction(self) -> bool:
        from psycopg.pq import TransactionStatus

        return self._connection.info.transaction_status != TransactionStatus.IDLE

    def commit(self) -> None:
        self._connection.commit()

    def rollback(self) -> None:
        self._connection.rollback()

    def close(self) -> None:
        self._connection.close()

    def __enter__(self):
        return self

    def __exit__(self, exception_type, _exception, _traceback):
        if exception_type is None:
            self.commit()
        else:
            self.rollback()


def lock_transaction_key(conn, key: str) -> None:
    """Serialize updates to a logical key on PostgreSQL; SQLite already serializes writers."""
    if isinstance(conn, PostgresConnection):
        conn.lock_key(key)

def get_db():
    postgres_url = _postgres_url()
    if postgres_url:
        return PostgresConnection(
            psycopg.connect(
                postgres_url,
                row_factory=dict_row,
                connect_timeout=10,
                application_name="fable-api",
            )
        )

    # Dynamic lookup so tests can override os.environ["FABLE_DB_PATH"]
    current_db_path = os.environ.get("FABLE_DB_PATH", DB_PATH)
    conn = sqlite3.connect(current_db_path, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    return conn


def _add_column_if_missing(conn, table_name, column_name, column_definition):
    if isinstance(conn, PostgresConnection):
        existing_columns = {
            row["column_name"]
            for row in conn.execute(
                """SELECT column_name FROM information_schema.columns
                   WHERE table_schema = current_schema() AND table_name = ?""",
                (table_name,),
            ).fetchall()
        }
    else:
        existing_columns = {
            row["name"]
            for row in conn.execute(f"PRAGMA table_info({table_name})").fetchall()
        }
    if column_name not in existing_columns:
        conn.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )


def _get_schema_version(conn) -> int:
    if isinstance(conn, PostgresConnection):
        conn.execute(
            """CREATE TABLE IF NOT EXISTS fable_schema_version (
                   id SMALLINT PRIMARY KEY CHECK (id = 1),
                   version INTEGER NOT NULL
               )"""
        )
        conn.execute(
            "INSERT INTO fable_schema_version (id, version) VALUES (1, 0) ON CONFLICT (id) DO NOTHING"
        )
        row = conn.execute(
            "SELECT version FROM fable_schema_version WHERE id = 1"
        ).fetchone()
        return int(row["version"])

    return int(conn.execute("PRAGMA user_version").fetchone()[0])


def _set_schema_version(conn, version: int) -> None:
    if isinstance(conn, PostgresConnection):
        conn.execute(
            "UPDATE fable_schema_version SET version = ? WHERE id = 1",
            (version,),
        )
    else:
        conn.execute(f"PRAGMA user_version = {version}")


def init_db():
    conn = get_db()
    try:
        if isinstance(conn, PostgresConnection):
            conn.execute("SELECT pg_advisory_xact_lock(472993481)")
        else:
            conn.execute("PRAGMA journal_mode = WAL;")
        current_version = _get_schema_version(conn)
        if current_version > SCHEMA_VERSION:
            raise RuntimeError(
                f"Database schema version {current_version} is newer than supported version {SCHEMA_VERSION}."
            )

        with conn:
            conn.execute("""
            CREATE TABLE IF NOT EXISTS stories (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                genre TEXT NOT NULL,
                chapter TEXT NOT NULL,
                synopsis TEXT NOT NULL,
                content TEXT NOT NULL,
                read_time_minutes INTEGER NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL,
                cover_image_name TEXT,
                hero_image_name TEXT,
                cover_image_url TEXT,
                total_pages INTEGER DEFAULT 0,
                current_page INTEGER DEFAULT 1,
                progress_percent INTEGER DEFAULT 0,
                rating REAL DEFAULT NULL,
                saves_count TEXT DEFAULT '0',
                reads_count TEXT DEFAULT '0',
                is_tale_of_the_day INTEGER DEFAULT 0,
                is_recent_submission INTEGER DEFAULT 0,
                is_curator_spotlight INTEGER DEFAULT 0,
                badge_text TEXT,
                total_chapters INTEGER DEFAULT 0,
                content_format TEXT DEFAULT 'PROSE',
                source_provider TEXT DEFAULT 'FABLE_ORIGINAL',
                provider_id TEXT,
                provider_download_count INTEGER,
                owner_user_id TEXT
            );
            """)
            conn.execute("""
            CREATE TABLE IF NOT EXISTS chapters (
                id TEXT PRIMARY KEY,
                story_id TEXT NOT NULL,
                chapter_number INTEGER NOT NULL,
                title TEXT NOT NULL,
                content TEXT DEFAULT '',
                word_count INTEGER NOT NULL DEFAULT 0,
                created_at_utc TEXT NOT NULL,
                page_urls TEXT DEFAULT '[]',
                FOREIGN KEY(story_id) REFERENCES stories(id) ON DELETE CASCADE
            );
            """)
            for column_name, column_definition in (
                ("content_format", "TEXT DEFAULT 'PROSE'"),
                ("source_provider", "TEXT DEFAULT 'FABLE_ORIGINAL'"),
                ("provider_id", "TEXT"),
                ("provider_download_count", "INTEGER"),
                ("owner_user_id", "TEXT"),
            ):
                _add_column_if_missing(conn, "stories", column_name, column_definition)
            _add_column_if_missing(conn, "chapters", "page_urls", "TEXT DEFAULT '[]'")
            conn.execute("""
            CREATE TABLE IF NOT EXISTS shelf_items (
                device_id TEXT NOT NULL,
                story_id TEXT NOT NULL,
                reading_progress REAL NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                updated_at_utc TEXT NOT NULL,
                PRIMARY KEY (device_id, story_id)
            );
            """)
            _add_column_if_missing(
                conn,
                "shelf_items",
                "device_id",
                "TEXT NOT NULL DEFAULT ''",
            )
            conn.execute("CREATE INDEX IF NOT EXISTS idx_shelf_items_device ON shelf_items (device_id);")
            conn.execute("""
            CREATE TABLE IF NOT EXISTS account_shelf_items (
                owner_user_id TEXT NOT NULL,
                device_id TEXT NOT NULL,
                story_id TEXT NOT NULL,
                reading_progress REAL NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                updated_at_utc TEXT NOT NULL,
                PRIMARY KEY (owner_user_id, device_id, story_id)
            );
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_account_shelf_owner_device ON account_shelf_items (owner_user_id, device_id);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_account_shelf_story ON account_shelf_items (story_id);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_stories_owner_created ON stories (owner_user_id, created_at_utc DESC);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_shelf_story_owner ON account_shelf_items (story_id, owner_user_id);")
            conn.execute("""
            CREATE TABLE IF NOT EXISTS reading_sessions (
                owner_user_id TEXT NOT NULL,
                id TEXT NOT NULL,
                story_id TEXT NOT NULL,
                seconds_read INTEGER NOT NULL CHECK (seconds_read >= 3),
                read_at_utc TEXT NOT NULL,
                is_completed INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (owner_user_id, id)
            );
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_reading_sessions_owner_date ON reading_sessions (owner_user_id, read_at_utc);")
            conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                name TEXT NOT NULL,
                handle TEXT NOT NULL DEFAULT '',
                bio TEXT NOT NULL DEFAULT '',
                avatar_image_name TEXT,
                avatar_image_url TEXT,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL
            );
            """)
            _add_column_if_missing(conn, "users", "handle", "TEXT NOT NULL DEFAULT ''")
            _add_column_if_missing(conn, "users", "bio", "TEXT NOT NULL DEFAULT ''")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);")
            duplicate_handles = conn.execute(
                """
                SELECT LOWER(handle) AS lowered_handle
                FROM users
                WHERE handle <> ''
                GROUP BY LOWER(handle)
                HAVING COUNT(*) > 1
                """
            ).fetchall()
            for duplicate in duplicate_handles:
                rows = conn.execute(
                    """
                    SELECT id, handle
                    FROM users
                    WHERE LOWER(handle) = ?
                    ORDER BY created_at_utc ASC, id ASC
                    """,
                    (duplicate["lowered_handle"],),
                ).fetchall()
                for row in rows[1:]:
                    suffix = row["id"].replace("-", "")[:6]
                    base = row["handle"][:33]
                    conn.execute(
                        "UPDATE users SET handle = ? WHERE id = ?",
                        (f"{base}_{suffix}", row["id"]),
                    )
            conn.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_handle_lower ON users (LOWER(handle)) WHERE handle <> '';"
            )
            conn.execute("""
            CREATE TABLE IF NOT EXISTS user_sessions (
                token_hash TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                created_at_utc TEXT NOT NULL,
                expires_at_utc TEXT NOT NULL,
                revoked_at_utc TEXT
            );
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions (user_id);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_chapters_story_id ON chapters (story_id);")
            conn.execute("""
                CREATE TABLE IF NOT EXISTS auth_rate_limits (
                    bucket_key TEXT PRIMARY KEY,
                    window_expires_at INTEGER NOT NULL,
                    request_count INTEGER NOT NULL
                );
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_expiry ON auth_rate_limits (window_expires_at);")

            if current_version < 1:
                placeholders = ", ".join("?" for _ in LEGACY_DEMO_STORY_IDS)
                for table_name in ("shelf_items", "account_shelf_items"):
                    conn.execute(
                        f"DELETE FROM {table_name} WHERE story_id IN ({placeholders})",
                        LEGACY_DEMO_STORY_IDS,
                    )
                conn.execute(
                    f"DELETE FROM reading_sessions WHERE story_id IN ({placeholders})",
                    LEGACY_DEMO_STORY_IDS,
                )
                conn.execute(
                    f"DELETE FROM chapters WHERE story_id IN ({placeholders})",
                    LEGACY_DEMO_STORY_IDS,
                )
                conn.execute(
                    f"DELETE FROM stories WHERE id IN ({placeholders})",
                    LEGACY_DEMO_STORY_IDS,
                )
                _set_schema_version(conn, 1)

            if current_version < 2:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS request_rate_limit_buckets (
                        bucket_key TEXT NOT NULL,
                        available_tokens DOUBLE PRECISION NOT NULL,
                        updated_at DOUBLE PRECISION NOT NULL,
                        PRIMARY KEY (bucket_key)
                    );
                """)
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_request_rate_limit_updated "
                    "ON request_rate_limit_buckets (updated_at)"
                )
                _set_schema_version(conn, 2)

            if current_version < 3:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS password_reset_tokens (
                        token_hash TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        created_at_utc TEXT NOT NULL,
                        expires_at_utc TEXT NOT NULL,
                        consumed_at_utc TEXT,
                        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
                    );
                """)
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_password_reset_user "
                    "ON password_reset_tokens (user_id, expires_at_utc)"
                )
                _set_schema_version(conn, 3)

            if current_version < 4:
                placeholders = ", ".join("?" for _ in LEGACY_DEMO_STORY_IDS)
                for table_name in ("shelf_items", "account_shelf_items"):
                    conn.execute(
                        f"DELETE FROM {table_name} WHERE story_id IN ({placeholders})",
                        LEGACY_DEMO_STORY_IDS,
                    )
                for table_name in ("reading_sessions", "chapters"):
                    conn.execute(
                        f"DELETE FROM {table_name} WHERE story_id IN ({placeholders})",
                        LEGACY_DEMO_STORY_IDS,
                    )
                conn.execute(
                    f"DELETE FROM stories WHERE id IN ({placeholders})",
                    LEGACY_DEMO_STORY_IDS,
                )
                _set_schema_version(conn, 4)
    finally:
        conn.close()
