import json
import sqlite3
from datetime import datetime, timezone
from typing import Optional
from urllib.parse import urlsplit
from uuid import UUID, uuid4, uuid5

import httpx
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import (
    ChapterDTO,
    CreateStoryRequest,
    GenreDTO,
    StoryDTO,
    UpdateFeedDTO,
    WriterDTO,
)

IDENTIFIER_NAMESPACE = UUID("b28f1a39-ff20-5d3c-9ff0-994df9324c22")


def _is_legacy_demo_image_url(value: str) -> bool:
    try:
        return (urlsplit(value).hostname or "").lower() == "images.unsplash.com"
    except ValueError:
        return False


def _decode_page_urls(value: Optional[str]) -> list[str]:
    if not value:
        return []
    try:
        page_urls = json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return []
    if not isinstance(page_urls, list):
        return []
    return [
        url for url in page_urls
        if isinstance(url, str) and not _is_legacy_demo_image_url(url)
    ]


def _cover_url_without_legacy_demo(value: Optional[str]) -> Optional[str]:
    if value and _is_legacy_demo_image_url(value):
        return None
    return value


def row_to_story_dto(
    row: sqlite3.Row,
    include_chapters: bool = False,
    conn: Optional[sqlite3.Connection] = None,
) -> StoryDTO:
    story_id = UUID(row["id"])
    chapters = None
    if include_chapters and conn:
        chapter_rows = conn.execute(
            "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
            (str(story_id),),
        ).fetchall()
        chapters = [
            ChapterDTO(
                id=UUID(chapter["id"]),
                story_id=story_id,
                chapter_number=chapter["chapter_number"],
                title=chapter["title"],
                content=chapter["content"] if "content" in chapter.keys() else "",
                word_count=chapter["word_count"] if "word_count" in chapter.keys() else 0,
                created_at_utc=datetime.fromisoformat(chapter["created_at_utc"]),
                page_urls=_decode_page_urls(
                    chapter["page_urls"] if "page_urls" in chapter.keys() else None
                ),
            )
            for chapter in chapter_rows
        ]

    saves_count = 0
    reads_count = 0
    if conn:
        shelf_counts = conn.execute(
            """
            SELECT
                COUNT(DISTINCT CASE WHEN is_bookmarked = 1 THEN device_id END) AS saves_count,
                COUNT(DISTINCT CASE WHEN reading_progress > 0 THEN device_id END) AS reads_count
            FROM shelf_items
            WHERE story_id = ?
            """,
            (str(story_id),),
        ).fetchone()
        saves_count = shelf_counts["saves_count"]
        reads_count = shelf_counts["reads_count"]

    keys = row.keys()
    provider_id = row["provider_id"] if "provider_id" in keys else None
    source_provider = row["source_provider"] if "source_provider" in keys else "FABLE_ORIGINAL"
    cover_url = row["cover_image_url"] if "cover_image_url" in keys else None
    if not provider_id or source_provider not in {"GUTENBERG", "MANGADEX", "STANDARD_EBOOKS"}:
        cover_url = None
    return StoryDTO(
        id=story_id,
        title=row["title"],
        author=row["author"],
        genre=row["genre"],
        chapter=row["chapter"],
        synopsis=row["synopsis"],
        content=row["content"],
        read_time_minutes=row["read_time_minutes"],
        is_bookmarked=bool(row["is_bookmarked"]),
        is_completed=bool(row["is_completed"]),
        created_at_utc=datetime.fromisoformat(row["created_at_utc"]),
        updated_at_utc=datetime.fromisoformat(row["updated_at_utc"]),
        cover_image_name=None,
        hero_image_name=None,
        cover_image_url=_cover_url_without_legacy_demo(cover_url),
        total_pages=row["total_pages"] if "total_pages" in keys and row["total_pages"] else 0,
        current_page=row["current_page"] if "current_page" in keys and row["current_page"] else 1,
        progress_percent=row["progress_percent"] if "progress_percent" in keys and row["progress_percent"] is not None else 0,
        rating=None,
        saves_count=str(saves_count),
        reads_count=str(reads_count),
        is_tale_of_the_day=bool(row["is_tale_of_the_day"]) if "is_tale_of_the_day" in keys else False,
        is_recent_submission=bool(row["is_recent_submission"]) if "is_recent_submission" in keys else False,
        is_curator_spotlight=bool(row["is_curator_spotlight"]) if "is_curator_spotlight" in keys else False,
        badge_text=row["badge_text"] if "badge_text" in keys else None,
        total_chapters=row["total_chapters"] if "total_chapters" in keys and row["total_chapters"] else 0,
        content_format=row["content_format"] if "content_format" in keys and row["content_format"] else "PROSE",
        source_provider=source_provider or "FABLE_ORIGINAL",
        provider_id=provider_id,
        provider_download_count=row["provider_download_count"] if "provider_download_count" in keys else None,
        chapters=chapters,
    )


def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None,
) -> list[StoryDTO]:
    conn = get_db()
    try:
        query = "SELECT * FROM stories WHERE 1=1"
        params: list[object] = []
        if genre and genre.lower() != "all":
            query += " AND LOWER(genre) = LOWER(?)"
            params.append(genre)
        if search:
            query += " AND (LOWER(title) LIKE ? OR LOWER(synopsis) LIKE ? OR LOWER(author) LIKE ?)"
            term = f"%{search.lower()}%"
            params.extend([term, term, term])
        if since:
            query += " AND updated_at_utc > ?"
            params.append(since.isoformat())
        query += " ORDER BY is_tale_of_the_day DESC, created_at_utc DESC"
        rows = conn.execute(query, params).fetchall()
        return [row_to_story_dto(row, conn=conn) for row in rows]
    finally:
        conn.close()


def get_story_by_id(story_id: UUID) -> StoryDTO:
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT * FROM stories WHERE id = ?",
            (str(story_id),),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Story not found")
        return row_to_story_dto(row, include_chapters=True, conn=conn)
    finally:
        conn.close()


def get_story_chapters(story_id: UUID) -> list[ChapterDTO]:
    conn = get_db()
    try:
        rows = conn.execute(
            "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
            (str(story_id),),
        ).fetchall()
        return [
            ChapterDTO(
                id=UUID(row["id"]),
                story_id=story_id,
                chapter_number=row["chapter_number"],
                title=row["title"],
                content=row["content"] if "content" in row.keys() else "",
                word_count=row["word_count"] if "word_count" in row.keys() else 0,
                created_at_utc=datetime.fromisoformat(row["created_at_utc"]),
                page_urls=_decode_page_urls(
                    row["page_urls"] if "page_urls" in row.keys() else None
                ),
            )
            for row in rows
        ]
    finally:
        conn.close()


def get_story_chapter_by_number(story_id: UUID, chapter_number: int) -> ChapterDTO:
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT * FROM chapters WHERE story_id = ? AND chapter_number = ?",
            (str(story_id), chapter_number),
        ).fetchone()
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Chapter {chapter_number} not found for story",
            )
        return ChapterDTO(
            id=UUID(row["id"]),
            story_id=story_id,
            chapter_number=row["chapter_number"],
            title=row["title"],
            content=row["content"] if "content" in row.keys() else "",
            word_count=row["word_count"] if "word_count" in row.keys() else 0,
            created_at_utc=datetime.fromisoformat(row["created_at_utc"]),
            page_urls=_decode_page_urls(
                row["page_urls"] if "page_urls" in row.keys() else None
            ),
        )
    finally:
        conn.close()


def create_story(payload: CreateStoryRequest) -> StoryDTO:
    story_id = str(uuid4())
    chapter_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    chapter_title = payload.chapter or ""
    content_format = payload.content_format or "PROSE"
    source_provider = "FABLE_ORIGINAL"

    conn = get_db()
    try:
        with conn:
            conn.execute(
                """
                INSERT INTO stories (
                    id, title, author, genre, chapter, synopsis, content,
                    read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                    is_recent_submission, total_chapters, content_format, source_provider
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    story_id,
                    payload.title,
                    payload.author,
                    payload.genre,
                    chapter_title,
                    payload.synopsis,
                    payload.content,
                    payload.read_time_minutes,
                    0,
                    0,
                    now_iso,
                    now_iso,
                    1,
                    1,
                    content_format,
                    source_provider,
                ),
            )
            words = len(payload.content.split()) if payload.content else 0
            conn.execute(
                """
                INSERT INTO chapters (
                    id, story_id, chapter_number, title, content, word_count, created_at_utc, page_urls
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    chapter_id,
                    story_id,
                    1,
                    chapter_title,
                    payload.content or "",
                    words,
                    now_iso,
                    "[]",
                ),
            )
    finally:
        conn.close()

    return StoryDTO(
        id=UUID(story_id),
        title=payload.title,
        author=payload.author,
        genre=payload.genre,
        chapter=chapter_title,
        synopsis=payload.synopsis,
        content=payload.content,
        read_time_minutes=payload.read_time_minutes,
        is_bookmarked=False,
        is_completed=False,
        created_at_utc=now,
        updated_at_utc=now,
        is_recent_submission=True,
        total_chapters=1,
        content_format=content_format,
        source_provider=source_provider,
        rating=None,
        saves_count="0",
        reads_count="0",
    )


def get_genres() -> list[GenreDTO]:
    conn = get_db()
    try:
        rows = conn.execute(
            """
            SELECT
                stories.genre,
                COUNT(DISTINCT stories.id) AS story_count,
                COUNT(DISTINCT CASE
                    WHEN shelf_items.reading_progress > 0 THEN shelf_items.device_id
                END) AS readers_count
            FROM stories
            LEFT JOIN shelf_items ON shelf_items.story_id = stories.id
            GROUP BY stories.genre
            ORDER BY story_count DESC, stories.genre COLLATE NOCASE ASC
            """
        ).fetchall()
        return [
            GenreDTO(
                id=uuid5(IDENTIFIER_NAMESPACE, f"genre:{row['genre'].casefold()}"),
                name=row["genre"],
                story_count=row["story_count"],
                readers_count=str(row["readers_count"]),
                description="",
                image_name="",
                image_url=None,
            )
            for row in rows
        ]
    finally:
        conn.close()


def _local_writers() -> list[WriterDTO]:
    conn = get_db()
    try:
        rows = conn.execute(
            """
            SELECT author, COUNT(*) AS story_count
            FROM stories
            GROUP BY author
            ORDER BY story_count DESC, author COLLATE NOCASE ASC
            LIMIT 6
            """
        ).fetchall()
        return [
            WriterDTO(
                id=uuid5(IDENTIFIER_NAMESPACE, f"fable-author:{row['author'].casefold()}"),
                name=row["author"],
                avatar_image_name="",
                avatar_image_url=None,
                story_count=row["story_count"],
                rating=None,
            )
            for row in rows
        ]
    finally:
        conn.close()


async def get_top_authors() -> list[WriterDTO]:
    headers = {"User-Agent": "Fable/1.0 (author metadata client)"}
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            trending = await client.get(
                "https://openlibrary.org/trending/daily.json",
                headers=headers,
            )
            if trending.status_code != 200:
                return _local_writers()

            works = trending.json().get("works", [])
            names: list[str] = []
            for work in works:
                for name in work.get("author_name", []):
                    if isinstance(name, str) and name.strip() and name not in names:
                        names.append(name.strip())
                    if len(names) == 6:
                        break
                if len(names) == 6:
                    break

            writers: list[WriterDTO] = []
            for name in names:
                response = await client.get(
                    "https://openlibrary.org/search/authors.json",
                    params={"q": name, "limit": 1},
                    headers=headers,
                )
                if response.status_code != 200:
                    continue
                docs = response.json().get("docs", [])
                if not docs:
                    continue
                document = docs[0]
                author_key = document.get("key", "").rsplit("/", 1)[-1]
                if not author_key:
                    continue
                work_count = document.get("work_count", 0)
                writers.append(
                    WriterDTO(
                        id=uuid5(IDENTIFIER_NAMESPACE, f"openlibrary:{author_key}"),
                        name=document.get("name", name),
                        avatar_image_name="",
                        avatar_image_url=(
                            f"https://covers.openlibrary.org/a/olid/{author_key}-M.jpg?default=false"
                        ),
                        story_count=max(0, int(work_count)),
                        rating=None,
                    )
                )
            return writers
    except (httpx.HTTPError, ValueError, TypeError):
        return _local_writers()


def get_update_feed() -> UpdateFeedDTO:
    conn = get_db()
    try:
        totd_row = conn.execute(
            """
            SELECT * FROM stories
            WHERE is_tale_of_the_day = 1
            ORDER BY created_at_utc DESC LIMIT 1
            """
        ).fetchone()
        curator_row = conn.execute(
            """
            SELECT * FROM stories
            WHERE is_curator_spotlight = 1
            ORDER BY created_at_utc DESC LIMIT 1
            """
        ).fetchone()
        recent_rows = conn.execute(
            """
            SELECT * FROM stories
            WHERE is_recent_submission = 1
            ORDER BY created_at_utc DESC LIMIT 10
            """
        ).fetchall()
        total_count = conn.execute(
            "SELECT COUNT(*) AS count FROM stories"
        ).fetchone()["count"]
        return UpdateFeedDTO(
            tale_of_the_day=row_to_story_dto(totd_row, conn=conn) if totd_row else None,
            curator_spotlight=row_to_story_dto(curator_row, conn=conn) if curator_row else None,
            recent_submissions=[
                row_to_story_dto(row, conn=conn) for row in recent_rows
            ],
            total_stories=total_count,
            timestamp_utc=datetime.now(timezone.utc),
        )
    finally:
        conn.close()
