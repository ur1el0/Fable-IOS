#!/usr/bin/env python3
"""
Ingest opening chapters (Chapters 1-5) for Mushoku Tensei: Jobless Reincarnation
into Fable's SQLite database, ensuring the reader always starts from Chapter 1.
"""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid5


MANGA_NAMESPACE = UUID("e7b8c2d1-4f3a-5b6c-8e9d-1a2b3c4d5e6f")
PROVIDER_ID = "bd6d0982-0091-4945-ad70-c028ed3c0917"
STORY_UUID = str(uuid5(MANGA_NAMESPACE, f"mangadex:{PROVIDER_ID}"))

CHAPTER_METADATA = [
    ("c7f7c676-42bb-4689-b842-bee2a6c9c047", 1, "The Reincarnated In Another World Starts To Work Hard"),
    ("1dd9d5e1-e1ac-40fc-8bcb-df4f49fc374c", 2, "Master"),
    ("6288d5d3-8181-40cf-9937-374d634f503c", 3, "Friend"),
    ("4e419c28-c4cc-4f87-a8ba-1bc6dadcab1f", 4, "Emergency Family Conference"),
    ("cd8a0c75-6a50-47ef-8b67-116337da80cb", 5, "Violence of the Young Lady"),
]


def resolve_chapter_panel_urls(chapter_id: str) -> list[str]:
    cmd = ["/usr/bin/curl", "-s", f"https://api.mangadex.org/at-home/server/{chapter_id}"]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    data = json.loads(res.stdout)
    base_url = data.get("baseUrl", "")
    chapter_info = data.get("chapter", {})
    hash_val = chapter_info.get("hash", "")
    files = chapter_info.get("dataSaver") or chapter_info.get("data") or []
    if base_url and hash_val and files:
        return [f"{base_url}/data-saver/{hash_val}/{file_name}" for file_name in files]
    return []


def ingest_into_database(db_path: Path) -> None:
    if not db_path.exists():
        return

    print(f"Ingesting Mushoku Tensei Chapter 1-5 into: {db_path}")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    now_iso = datetime.now(timezone.utc).isoformat()

    try:
        with conn:
            # 1. Upsert Story record
            existing = conn.execute(
                "SELECT id, created_at_utc FROM stories WHERE source_provider = ? AND provider_id = ?",
                ("MANGADEX", PROVIDER_ID),
            ).fetchone()

            title = "Mushoku Tensei: Jobless Reincarnation"
            author = "Rifujin na Magonote"
            synopsis = (
                "A 34-year-old NEET gets killed in a traffic accident and finds himself in a world of magic. "
                "Rather than waking up as a full-grown mage, he gets reincarnated as a newborn baby, retaining "
                "the memories of his previous life."
            )
            cover_url = (
                f"https://uploads.mangadex.org/covers/{PROVIDER_ID}/"
                "6a9f3d32-b7bb-478a-9c76-54868276c26f.jpg.256.jpg"
            )

            if existing:
                story_id = existing["id"]
                conn.execute(
                    """
                    UPDATE stories SET
                        title = ?, author = ?, genre = 'Manga', chapter = ?, synopsis = ?,
                        read_time_minutes = 20, updated_at_utc = ?, cover_image_url = ?,
                        total_chapters = ?, content_format = 'MANGA', source_provider = 'MANGADEX',
                        provider_id = ?
                    WHERE id = ?
                    """,
                    (
                        title, author, CHAPTER_METADATA[0][2], synopsis,
                        now_iso, cover_url, len(CHAPTER_METADATA), PROVIDER_ID, story_id,
                    ),
                )
            else:
                story_id = STORY_UUID
                conn.execute(
                    """
                    INSERT INTO stories (
                        id, title, author, genre, chapter, synopsis, content,
                        read_time_minutes, created_at_utc, updated_at_utc, cover_image_url,
                        is_recent_submission, total_chapters, content_format, source_provider,
                        provider_id
                    ) VALUES (?, ?, ?, 'Manga', ?, ?, '', 20, ?, ?, ?, 1, ?, 'MANGA', 'MANGADEX', ?)
                    """,
                    (
                        story_id, title, author, CHAPTER_METADATA[0][2], synopsis,
                        now_iso, now_iso, cover_url, len(CHAPTER_METADATA), PROVIDER_ID,
                    ),
                )

            # 2. Ingest Chapters 1 to 5
            for ch_id, ch_num, ch_title in CHAPTER_METADATA:
                print(f"  Resolving Chapter {ch_num}: {ch_title}...")
                urls = resolve_chapter_panel_urls(ch_id)
                if not urls:
                    print(f"  WARNING: No panel URLs returned for Chapter {ch_num}")
                    continue

                chapter_uuid = str(uuid5(MANGA_NAMESPACE, f"mangadex_chapter:{ch_id}"))
                conn.execute(
                    """
                    INSERT INTO chapters (
                        id, story_id, chapter_number, title, content, word_count, created_at_utc, page_urls
                    ) VALUES (?, ?, ?, ?, '', 0, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        chapter_number = excluded.chapter_number,
                        title = excluded.title,
                        page_urls = excluded.page_urls,
                        created_at_utc = excluded.created_at_utc
                    """,
                    (
                        chapter_uuid, story_id, ch_num, ch_title, now_iso, json.dumps(urls),
                    ),
                )
                print(f"  Saved Chapter {ch_num} ({len(urls)} pages) into database.")

    finally:
        conn.close()


def main() -> None:
    root_dir = Path(__file__).resolve().parent.parent
    db_paths = [
        root_dir / "backend" / "fable.sqlite3",
        root_dir / "fable.sqlite3",
    ]
    for p in db_paths:
        ingest_into_database(p)

    print("\nIngestion complete! Mushoku Tensei now starts at Chapter 1.")


if __name__ == "__main__":
    main()
