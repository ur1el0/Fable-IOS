import sqlite3
import os

DB_PATH = os.environ.get("FABLE_DB_PATH", "fable.sqlite3")
SCHEMA_VERSION = 1
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
)

def get_db():
    # Dynamic lookup so tests can override os.environ["FABLE_DB_PATH"]
    current_db_path = os.environ.get("FABLE_DB_PATH", DB_PATH)
    conn = sqlite3.connect(current_db_path)
    conn.row_factory = sqlite3.Row
    return conn


def _add_column_if_missing(conn, table_name, column_name, column_definition):
    existing_columns = {
        row["name"]
        for row in conn.execute(f"PRAGMA table_info({table_name})").fetchall()
    }
    if column_name not in existing_columns:
        conn.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )


def init_db():
    conn = get_db()
    try:
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

            current_version = conn.execute("PRAGMA user_version").fetchone()[0]
            if current_version > SCHEMA_VERSION:
                raise RuntimeError(
                    f"Database schema version {current_version} is newer than supported version {SCHEMA_VERSION}."
                )

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
                conn.execute("PRAGMA user_version = 1")
    finally:
        conn.close()
