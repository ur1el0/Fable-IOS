import sqlite3
import os
import json
from datetime import datetime, timezone
from uuid import uuid4
from .seed_catalog import SEED_CATALOG

DB_PATH = os.environ.get("FABLE_DB_PATH", "fable.sqlite3")

def get_db():
    # Dynamic lookup so tests can override os.environ["FABLE_DB_PATH"]
    current_db_path = os.environ.get("FABLE_DB_PATH", DB_PATH)
    conn = sqlite3.connect(current_db_path)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
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
                total_pages INTEGER DEFAULT 5,
                current_page INTEGER DEFAULT 1,
                progress_percent INTEGER DEFAULT 0,
                rating REAL DEFAULT 4.9,
                saves_count TEXT DEFAULT '1.2k',
                reads_count TEXT DEFAULT '1.2k',
                is_tale_of_the_day INTEGER DEFAULT 0,
                is_recent_submission INTEGER DEFAULT 0,
                is_curator_spotlight INTEGER DEFAULT 0,
                badge_text TEXT,
                total_chapters INTEGER DEFAULT 1,
                content_format TEXT DEFAULT 'PROSE',
                source_provider TEXT DEFAULT 'FABLE_ORIGINAL'
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
        # Dynamic schema migration for existing databases
        for col_name, col_def in [("content_format", "TEXT DEFAULT 'PROSE'"), ("source_provider", "TEXT DEFAULT 'FABLE_ORIGINAL'")]:
            try:
                conn.execute(f"ALTER TABLE stories ADD COLUMN {col_name} {col_def}")
            except Exception:
                pass
        try:
            conn.execute("ALTER TABLE chapters ADD COLUMN page_urls TEXT DEFAULT '[]'")
        except Exception:
            pass
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
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                name TEXT NOT NULL,
                avatar_image_name TEXT DEFAULT 'avatar_roosc',
                avatar_image_url TEXT,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL
            );
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_chapters_story_id ON chapters (story_id);")

        cursor = conn.execute("SELECT COUNT(*) as count FROM stories")
        if cursor.fetchone()["count"] == 0:
            now_iso = datetime.now(timezone.utc).isoformat()
            
            for s in SEED_CATALOG:
                total_chapters = len(s.get("chapters", []))
                conn.execute("""
                    INSERT INTO stories (
                        id, title, author, genre, chapter, synopsis, content,
                        read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                        cover_image_name, hero_image_name, cover_image_url, is_tale_of_the_day,
                        is_recent_submission, is_curator_spotlight, badge_text, total_chapters,
                        content_format, source_provider
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    s["id"], s["title"], s["author"], s["genre"], s["chapter"],
                    s["synopsis"], s["content"], s["read_time_minutes"], 0, 0,
                    now_iso, now_iso, s.get("cover_image_name"), s.get("hero_image_name"),
                    s.get("cover_image_url"), s.get("is_tale_of_the_day", 0),
                    s.get("is_recent_submission", 0), s.get("is_curator_spotlight", 0),
                    s.get("badge_text"), max(1, total_chapters),
                    s.get("content_format", "PROSE"), s.get("source_provider", "FABLE_ORIGINAL")
                ))

                for ch in s.get("chapters", []):
                    ch_id = str(uuid4())
                    ch_content = ch.get("content", "")
                    words = len(ch_content.split()) if ch_content else 0
                    page_urls_json = json.dumps(ch.get("page_urls", []))
                    conn.execute("""
                        INSERT INTO chapters (
                            id, story_id, chapter_number, title, content, word_count, created_at_utc, page_urls
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        ch_id, s["id"], ch["number"], ch["title"], ch_content, words, now_iso, page_urls_json
                    ))
    conn.close()
