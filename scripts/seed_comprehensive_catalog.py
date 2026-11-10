#!/usr/bin/env python3
"""
Comprehensive Catalog Ingestion Script for Fable
Applies Option 3 across all formats: Manga, Books, Fables, and Original Stories.
Ensures every title has authentic starting content starting strictly at Chapter 1.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4, uuid5

# Add backend directory to sys.path so we can import services
REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
sys.path.insert(0, str(BACKEND_DIR))

from services.gutenberg import ingest_gutenberg_book, get_gutenberg_chapters

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("seed_catalog")

IDENTIFIER_NAMESPACE = UUID("b28f1a39-ff20-5d3c-9ff0-994df9324c22")
MANGA_NAMESPACE = UUID("e819b12e-84cb-4d9b-a359-52e8964e528b")


# ============================================================================
# 1. Authentic Manga Data
# ============================================================================

MUSHOKU_PROVIDER_ID = "bd6d0982-0091-4945-ad70-c028ed3c0917"
MUSHOKU_STORY_UUID = str(uuid5(MANGA_NAMESPACE, f"mangadex:{MUSHOKU_PROVIDER_ID}"))

MUSHOKU_CHAPTERS = [
    {
        "chapter_number": 1,
        "title": "The Reincarnated In Another World Starts To Work Hard",
        "page_count": 38,
        "pages": [
            f"https://images.mangafreak.me/mangas/mushoku_tensei_isekai_ittara_honki_dasu/mushoku_tensei_isekai_ittara_honki_dasu_1/mushoku_tensei_isekai_ittara_honki_dasu_1_{i}.jpg"
            for i in range(1, 39)
        ],
    },
    {
        "chapter_number": 2,
        "title": "Master",
        "page_count": 42,
        "pages": [
            f"https://images.mangafreak.me/mangas/mushoku_tensei_isekai_ittara_honki_dasu/mushoku_tensei_isekai_ittara_honki_dasu_2/mushoku_tensei_isekai_ittara_honki_dasu_2_{i}.jpg"
            for i in range(1, 43)
        ],
    },
    {
        "chapter_number": 3,
        "title": "Friend",
        "page_count": 22,
        "pages": [
            f"https://images.mangafreak.me/mangas/mushoku_tensei_isekai_ittara_honki_dasu/mushoku_tensei_isekai_ittara_honki_dasu_3/mushoku_tensei_isekai_ittara_honki_dasu_3_{i}.jpg"
            for i in range(1, 23)
        ],
    },
    {
        "chapter_number": 4,
        "title": "Emergency Family Conference",
        "page_count": 26,
        "pages": [
            f"https://images.mangafreak.me/mangas/mushoku_tensei_isekai_ittara_honki_dasu/mushoku_tensei_isekai_ittara_honki_dasu_4/mushoku_tensei_isekai_ittara_honki_dasu_4_{i}.jpg"
            for i in range(1, 27)
        ],
    },
    {
        "chapter_number": 5,
        "title": "Violence of the Young Lady",
        "page_count": 42,
        "pages": [
            f"https://images.mangafreak.me/mangas/mushoku_tensei_isekai_ittara_honki_dasu/mushoku_tensei_isekai_ittara_honki_dasu_5/mushoku_tensei_isekai_ittara_honki_dasu_5_{i}.jpg"
            for i in range(1, 43)
        ],
    },
]


# ============================================================================
# 2. Authentic Classic Fables
# ============================================================================

AESOP_FABLES = [
    {
        "id": "e1a10001-0000-0000-0000-000000000001",
        "title": "The Tortoise and the Hare",
        "author": "Aesop",
        "genre": "Fables",
        "chapter": "Slow and Steady",
        "synopsis": "A boastful hare ridicules a slow-moving tortoise, leading to a legendary race where overconfidence faces patient perseverance.",
        "read_time_minutes": 5,
        "cover_url": "https://images.unsplash.com/photo-1543946207-39bd91e70ca7?w=800&auto=format&fit=crop&q=80",
        "content": (
            "A Hare was one day making fun of the short feet and slow pace of the Tortoise, who replied, laughing: "
            "\"Though you be swift as the wind, I will beat you in a race.\"\n\n"
            "The Hare, believing her assertion to be simply impossible, assented to the proposal; and they agreed that "
            "the Fox should choose the course and fix the goal. On the day appointed for the race the two started together.\n\n"
            "The Tortoise never for a moment stopped, but went on with a slow but steady pace straight to the end of the course. "
            "The Hare, lying down by the wayside, fell fast asleep.\n\n"
            "At last he woke up, and moving as fast as he could, saw the Tortoise had reached the goal, and was comfortably dozing "
            "after her fatigue.\n\n"
            "Moral: Slow and steady wins the race."
        ),
    },
    {
        "id": "e1a10002-0000-0000-0000-000000000002",
        "title": "The Boy Who Cried Wolf",
        "author": "Aesop",
        "genre": "Fables",
        "chapter": "The False Alarm",
        "synopsis": "A lonely shepherd boy repeatedly tricks nearby villagers with false wolf alarms until real danger strikes.",
        "read_time_minutes": 5,
        "cover_url": "https://images.unsplash.com/photo-1564349683136-77e08dba1ef6?w=800&auto=format&fit=crop&q=80",
        "content": (
            "There once was a shepherd boy who was bored as he sat on the hillside watching the village sheep. "
            "To entertain himself he took a great breath and sang out, \"Wolf! Wolf! The Wolf is chasing the sheep!\"\n\n"
            "The villagers came running up the hill to help the boy drive the wolf away. But when they arrived at the top "
            "of the hill, they found no wolf. The boy laughed at the sight of their angry faces.\n\n"
            "\"Don't cry wolf, shepherd boy,\" said the villagers, \"when there's no wolf!\" They went grumbling back down the hill.\n\n"
            "Later, the boy sang out again, \"Wolf! Wolf! The wolf is chasing the sheep!\" To his naughty delight, he watched the "
            "villagers run up the hill to help him once more.\n\n"
            "When the villagers saw no wolf they said sternly, \"Save your frightened song for when there is really something wrong! "
            "Don't cry wolf when there is NO wolf!\"\n\n"
            "Later that evening, a real Wolf came prowling near the flock. Terrified, the boy leaped to his feet and cried out "
            "as loudly as he could, \"Wolf! Wolf!\"\n\n"
            "But the villagers thought he was trying to fool them again, and so they did not come.\n\n"
            "Moral: A liar will not be believed, even when he speaks the truth."
        ),
    },
    {
        "id": "e1a10003-0000-0000-0000-000000000003",
        "title": "The Fox and the Grapes",
        "author": "Aesop",
        "genre": "Fables",
        "chapter": "Sour Grapes",
        "synopsis": "A hungry fox desires luscious grapes dangling out of reach, comforting his ego by disdaining what he cannot have.",
        "read_time_minutes": 4,
        "cover_url": "https://images.unsplash.com/photo-1516934024742-b461fba47600?w=800&auto=format&fit=crop&q=80",
        "content": (
            "One hot summer's day a Fox was strolling through an orchard till he came to a bunch of Grapes just ripening "
            "on a vine which had been trained over a lofty branch.\n\n"
            "\"Just the thing to quench my thirst,\" quoth he. Drawing back a few paces, he took a run and a jump, and just "
            "missed the bunch.\n\n"
            "Turning round again with a One, Two, Three, he jumped up, but with no greater success. Again and again he tried "
            "after the tempting morsel, but at last had to give it up, and walked away with his nose in the air.\n\n"
            "\"I am sure they are sour,\" he said.\n\n"
            "Moral: It is easy to despise what you cannot get."
        ),
    },
    {
        "id": "e1a10004-0000-0000-0000-000000000004",
        "title": "The North Wind and the Sun",
        "author": "Aesop",
        "genre": "Fables",
        "chapter": "Persuasion Over Force",
        "synopsis": "A contest of strength between the howling wind and radiant sun reveals whether force or gentleness prevails.",
        "read_time_minutes": 4,
        "cover_url": "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&auto=format&fit=crop&q=80",
        "content": (
            "The North Wind and the Sun had a dispute as to which of the two was the stronger. While they were talking with "
            "great vehement energy, a traveler came along the road wrapped in a warm cloak.\n\n"
            "\"Let us decide our question by him,\" said the Sun. \"He shall be the winner who can first strip that traveler of his cloak.\"\n\n"
            "\"Agreed,\" said the North Wind; and at once he began to blow a cold, roaring gale. But the harder he blew, the more "
            "closely the traveler wrapped his cloak about him to keep out the chill.\n\n"
            "Then the Sun shone out with all his warmth. The traveler felt the genial rays, and as the heat grew stronger, "
            "he soon threw off his cloak and rested in the welcome shade.\n\n"
            "Moral: Persuasion is better than force."
        ),
    },
]


# ============================================================================
# 3. Database Ingestion Functions
# ============================================================================

def seed_manga(conn: sqlite3.Connection, now_iso: str) -> None:
    logger.info("Seeding authentic Mushoku Tensei Chapters 1-5...")
    title = "Mushoku Tensei: Jobless Reincarnation"
    author = "Rifujin na Magonote"
    synopsis = (
        "A 34-year-old NEET gets killed in a traffic accident and finds himself in a world of magic. "
        "Rather than waking up as a full-grown mage, he gets reincarnated as a newborn baby, retaining "
        "the memories of his previous life."
    )
    cover_url = (
        f"https://uploads.mangadex.org/covers/{MUSHOKU_PROVIDER_ID}/"
        "6a9f3d32-b7bb-478a-9c76-54868276c26f.jpg.256.jpg"
    )

    # Clean old/mismatched chapters first
    conn.execute("DELETE FROM chapters WHERE story_id = ?", (MUSHOKU_STORY_UUID,))

    # Upsert story
    conn.execute(
        """
        INSERT INTO stories (
            id, title, author, genre, chapter, synopsis, content,
            read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
            cover_image_url, is_recent_submission, total_chapters, content_format,
            source_provider, provider_id
        ) VALUES (?, ?, ?, 'Manga', ?, ?, '', 20, 0, 0, ?, ?, ?, 1, ?, 'MANGA', 'MANGADEX', ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            author = excluded.author,
            chapter = excluded.chapter,
            synopsis = excluded.synopsis,
            updated_at_utc = excluded.updated_at_utc,
            cover_image_url = excluded.cover_image_url,
            total_chapters = excluded.total_chapters
        """,
        (
            MUSHOKU_STORY_UUID, title, author, MUSHOKU_CHAPTERS[0]["title"], synopsis,
            now_iso, now_iso, cover_url, len(MUSHOKU_CHAPTERS), MUSHOKU_PROVIDER_ID,
        ),
    )

    # Insert authentic chapters 1 to 5
    for ch in MUSHOKU_CHAPTERS:
        ch_num = ch["chapter_number"]
        ch_title = ch["title"]
        pages = ch["pages"]
        chapter_uuid = str(uuid5(MANGA_NAMESPACE, f"mushoku_authentic_chapter:{ch_num}"))
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
            (chapter_uuid, MUSHOKU_STORY_UUID, ch_num, ch_title, now_iso, json.dumps(pages)),
        )
        logger.info(f"  Inserted Mushoku Tensei Chapter {ch_num}: {ch_title} ({len(pages)} authentic pages)")


def seed_fables(conn: sqlite3.Connection, now_iso: str) -> None:
    logger.info("Seeding classic Aesop fables...")
    for fable in AESOP_FABLES:
        story_id = fable["id"]
        words = len(fable["content"].split())
        chapter_id = str(uuid5(IDENTIFIER_NAMESPACE, f"fable_ch:{story_id}:1"))

        conn.execute(
            """
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                cover_image_url, is_recent_submission, total_chapters, content_format,
                source_provider, provider_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 1, 1, 'PROSE', 'FABLE_ORIGINAL', ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                author = excluded.author,
                genre = excluded.genre,
                chapter = excluded.chapter,
                synopsis = excluded.synopsis,
                content = excluded.content,
                updated_at_utc = excluded.updated_at_utc
            """,
            (
                story_id, fable["title"], fable["author"], fable["genre"], fable["chapter"],
                fable["synopsis"], fable["content"], fable["read_time_minutes"], now_iso, now_iso,
                fable["cover_url"], fable["id"]
            ),
        )

        conn.execute(
            """
            INSERT INTO chapters (
                id, story_id, chapter_number, title, content, word_count, created_at_utc, page_urls
            ) VALUES (?, ?, 1, ?, ?, ?, ?, '[]')
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                content = excluded.content,
                word_count = excluded.word_count
            """,
            (chapter_id, story_id, fable["chapter"], fable["content"], words, now_iso),
        )
        logger.info(f"  Seeded Fable: {fable['title']} (Chapter 1: {fable['chapter']})")


async def seed_gutenberg_classics() -> None:
    logger.info("Ingesting classic Gutenberg books...")
    classic_ids = [
        (11, "Classics"),       # Alice's Adventures in Wonderland
        (1342, "Classics"),     # Pride and Prejudice
        (84, "Classics"),       # Frankenstein
        (1661, "Mystery"),      # The Adventures of Sherlock Holmes
    ]

    for gid, genre in classic_ids:
        try:
            logger.info(f"  Ingesting Gutenberg ID {gid} ({genre})...")
            book = await ingest_gutenberg_book(gid, genre=genre)
            logger.info(f"  Successfully ingested '{book.title}' by {book.author} ({book.total_chapters} chapters)")
        except Exception as e:
            logger.warning(f"  Failed or already ingested Gutenberg {gid}: {e}")


def sync_to_databases() -> None:
    now_iso = datetime.now(timezone.utc).isoformat()
    db_paths = [
        BACKEND_DIR / "fable.sqlite3",
        REPO_ROOT / "fable.sqlite3",
    ]

    for db_path in db_paths:
        logger.info(f"Syncing catalog into {db_path}...")
        conn = sqlite3.connect(db_path)
        try:
            with conn:
                seed_manga(conn, now_iso)
                seed_fables(conn, now_iso)
        finally:
            conn.close()


async def main() -> None:
    # 1. Sync local manga and fables into both databases
    sync_to_databases()

    # 2. Ingest Gutenberg classics via backend service
    await seed_gutenberg_classics()

    # 3. Copy backend/fable.sqlite3 to root fable.sqlite3 to ensure parity
    backend_db = BACKEND_DIR / "fable.sqlite3"
    root_db = REPO_ROOT / "fable.sqlite3"
    if backend_db.exists():
        import shutil
        shutil.copy2(backend_db, root_db)
        logger.info(f"Copied updated {backend_db} to {root_db}")

    logger.info("\n🎉 Comprehensive catalog seeding complete!")
    logger.info("Every manga, book, and fable now starts strictly at Chapter 1 with genuine content.")


if __name__ == "__main__":
    asyncio.run(main())
