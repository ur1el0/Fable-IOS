import json
from datetime import datetime, timezone
from typing import Any, Optional
from urllib.parse import urlsplit
from uuid import UUID, uuid4, uuid5

from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import (
    ChapterDTO,
    CreateStoryRequest,
    GenreDTO,
    StoryDTO,
    UpdateFeedDTO,
    UpdateStoryRequest,
    WriterDTO,
)

IDENTIFIER_NAMESPACE = UUID("b28f1a39-ff20-5d3c-9ff0-994df9324c22")
STORY_SUMMARY_COLUMNS = """stories.id, stories.title, stories.author, stories.genre, stories.chapter, stories.synopsis, '' AS content,
    stories.read_time_minutes, stories.is_bookmarked, stories.is_completed, stories.created_at_utc, stories.updated_at_utc,
    stories.cover_image_name, stories.hero_image_name, stories.cover_image_url, stories.total_pages, stories.current_page,
    stories.progress_percent, stories.rating, stories.saves_count, stories.reads_count, stories.is_tale_of_the_day,
    stories.is_recent_submission, stories.is_curator_spotlight, stories.badge_text, stories.total_chapters,
    stories.content_format, stories.source_provider, stories.provider_id, stories.provider_download_count, stories.owner_user_id"""
STORY_SHELF_COUNTS_JOIN = """
LEFT JOIN (
    SELECT
        story_id,
        COUNT(DISTINCT CASE WHEN is_bookmarked = 1 THEN owner_user_id END) AS computed_saves_count,
        COUNT(DISTINCT CASE WHEN reading_progress > 0 THEN owner_user_id END) AS computed_reads_count
    FROM account_shelf_items
    GROUP BY story_id
) rc ON rc.story_id = stories.id
"""


def invalidate_top_authors_cache() -> None:
    from services import gutenberg

    gutenberg.invalidate_gutenberg_authors_cache()


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
    row: Any,
    include_chapters: bool = False,
    conn: Optional[Any] = None,
    include_content: bool = True,
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

    keys = row.keys()
    saves_count = 0
    reads_count = 0
    if "computed_saves_count" in keys and "computed_reads_count" in keys:
        saves_count = int(row["computed_saves_count"] or 0)
        reads_count = int(row["computed_reads_count"] or 0)
    elif conn:
        shelf_counts = conn.execute(
            """
            SELECT
                COUNT(DISTINCT CASE WHEN is_bookmarked = 1 THEN owner_user_id END) AS saves_count,
                COUNT(DISTINCT CASE WHEN reading_progress > 0 THEN owner_user_id END) AS reads_count
            FROM account_shelf_items
            WHERE story_id = ?
            """,
            (str(story_id),),
        ).fetchone()
        saves_count = shelf_counts["saves_count"]
        reads_count = shelf_counts["reads_count"]

    provider_id = row["provider_id"] if "provider_id" in keys else None
    source_provider = row["source_provider"] if "source_provider" in keys else "FABLE_ORIGINAL"
    cover_url = row["cover_image_url"] if "cover_image_url" in keys else None
    if not provider_id or source_provider not in {"GUTENBERG", "MANGADEX", "STANDARD_EBOOKS"}:
        cover_url = None
    raw_owner_id = row["owner_user_id"] if "owner_user_id" in keys else None
    owner_user_id = UUID(raw_owner_id) if raw_owner_id else None
    return StoryDTO(
        id=story_id,
        title=row["title"],
        author=row["author"],
        genre=row["genre"],
        chapter=row["chapter"],
        synopsis=row["synopsis"],
        content=row["content"] if include_content else "",
        read_time_minutes=row["read_time_minutes"],
        is_bookmarked=False,
        is_completed=False,
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
        owner_user_id=owner_user_id,
        chapters=chapters,
    )


def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None,
    limit: int = 50,
    offset: int = 0,
) -> list[StoryDTO]:
    conn = get_db()
    try:
        query = (
            f"SELECT {STORY_SUMMARY_COLUMNS}, "
            "COALESCE(rc.computed_saves_count, 0) AS computed_saves_count, "
            "COALESCE(rc.computed_reads_count, 0) AS computed_reads_count "
            f"FROM stories {STORY_SHELF_COUNTS_JOIN} WHERE 1=1"
        )
        params: list[object] = []
        if genre and genre.lower() != "all":
            query += " AND LOWER(stories.genre) = LOWER(?)"
            params.append(genre)
        if search:
            query += " AND (LOWER(stories.title) LIKE ? OR LOWER(stories.synopsis) LIKE ? OR LOWER(stories.author) LIKE ?)"
            term = f"%{search.lower()}%"
            params.extend([term, term, term])
        if since:
            query += " AND stories.updated_at_utc > ?"
            params.append(since.isoformat())
        query += " ORDER BY stories.is_tale_of_the_day DESC, stories.created_at_utc DESC, stories.id ASC LIMIT ? OFFSET ?"
        params.extend((limit, offset))
        rows = conn.execute(query, params).fetchall()
        return [row_to_story_dto(row, conn=conn) for row in rows]
    finally:
        conn.close()


def get_story_by_id(story_id: UUID) -> StoryDTO:
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT stories.*, "
            "COALESCE(rc.computed_saves_count, 0) AS computed_saves_count, "
            "COALESCE(rc.computed_reads_count, 0) AS computed_reads_count "
            f"FROM stories {STORY_SHELF_COUNTS_JOIN} WHERE stories.id = ?",
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


def create_story(payload: CreateStoryRequest, author: str, owner_user_id: UUID) -> StoryDTO:
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
                    is_recent_submission, total_chapters, content_format, source_provider, owner_user_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    story_id,
                    payload.title,
                    author,
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
                    str(owner_user_id),
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

    invalidate_top_authors_cache()
    return StoryDTO(
        id=UUID(story_id),
        title=payload.title,
        author=author,
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
        owner_user_id=owner_user_id,
        rating=None,
        saves_count="0",
        reads_count="0",
    )


def update_story(story_id: UUID, payload: UpdateStoryRequest, owner_user_id: UUID) -> StoryDTO:
    now_iso = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        row = conn.execute("SELECT * FROM stories WHERE id = ?", (str(story_id),)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Story not found")
        if row["owner_user_id"] != str(owner_user_id):
            raise HTTPException(status_code=403, detail="You do not have permission to modify this story")

        updates: dict[str, object] = {"updated_at_utc": now_iso}
        if payload.title is not None:
            updates["title"] = payload.title
        if payload.genre is not None:
            updates["genre"] = payload.genre
        if payload.chapter is not None:
            updates["chapter"] = payload.chapter
        if payload.synopsis is not None:
            updates["synopsis"] = payload.synopsis
        if payload.content is not None:
            updates["content"] = payload.content
        if payload.read_time_minutes is not None:
            updates["read_time_minutes"] = payload.read_time_minutes

        assignments = ", ".join(f"{column} = ?" for column in updates)
        params = list(updates.values()) + [str(story_id), str(owner_user_id)]
        with conn:
            conn.execute(
                f"UPDATE stories SET {assignments} WHERE id = ? AND owner_user_id = ?",
                params,
            )
            if payload.content is not None or payload.chapter is not None:
                chapter_row = conn.execute(
                    "SELECT id, title, content FROM chapters WHERE story_id = ? AND chapter_number = 1",
                    (str(story_id),),
                ).fetchone()
                if chapter_row:
                    next_title = payload.chapter if payload.chapter is not None else chapter_row["title"]
                    next_content = payload.content if payload.content is not None else chapter_row["content"]
                    words = len(next_content.split()) if next_content else 0
                    conn.execute(
                        "UPDATE chapters SET title = ?, content = ?, word_count = ? WHERE id = ?",
                        (next_title, next_content, words, chapter_row["id"]),
                    )
    finally:
        conn.close()

    invalidate_top_authors_cache()
    return get_story_by_id(story_id)


def delete_story(story_id: UUID, owner_user_id: UUID) -> None:
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT id, owner_user_id FROM stories WHERE id = ?",
            (str(story_id),),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Story not found")
        if row["owner_user_id"] != str(owner_user_id):
            raise HTTPException(status_code=403, detail="You do not have permission to delete this story")

        with conn:
            conn.execute("DELETE FROM shelf_items WHERE story_id = ?", (str(story_id),))
            conn.execute("DELETE FROM account_shelf_items WHERE story_id = ?", (str(story_id),))
            conn.execute("DELETE FROM reading_sessions WHERE story_id = ?", (str(story_id),))
            conn.execute("DELETE FROM chapters WHERE story_id = ?", (str(story_id),))
            conn.execute(
                "DELETE FROM stories WHERE id = ? AND owner_user_id = ?",
                (str(story_id), str(owner_user_id)),
            )
    finally:
        conn.close()

    invalidate_top_authors_cache()


def get_user_stories(owner_user_id: UUID) -> list[StoryDTO]:
    conn = get_db()
    try:
        rows = conn.execute(
            f"SELECT {STORY_SUMMARY_COLUMNS}, "
            "COALESCE(rc.computed_saves_count, 0) AS computed_saves_count, "
            "COALESCE(rc.computed_reads_count, 0) AS computed_reads_count "
            f"FROM stories {STORY_SHELF_COUNTS_JOIN} "
            "WHERE stories.owner_user_id = ? ORDER BY stories.created_at_utc DESC",
            (str(owner_user_id),),
        ).fetchall()
        return [row_to_story_dto(row, conn=conn) for row in rows]
    finally:
        conn.close()


def get_genres() -> list[GenreDTO]:
    conn = get_db()
    try:
        rows = conn.execute(
            """
            SELECT
                stories.genre,
                COUNT(DISTINCT stories.id) AS story_count,
                COUNT(DISTINCT CASE
                    WHEN account_shelf_items.reading_progress > 0 THEN account_shelf_items.owner_user_id
                END) AS readers_count
            FROM stories
            LEFT JOIN account_shelf_items ON account_shelf_items.story_id = stories.id
            GROUP BY stories.genre
            ORDER BY story_count DESC, LOWER(stories.genre) ASC
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


async def get_top_authors() -> list[WriterDTO]:
    try:
        # Import locally to avoid the Gutenberg service's story serializer
        # creating a module import cycle.
        from services.gutenberg import get_gutenberg_authors

        return await get_gutenberg_authors()
    except HTTPException:
        return []


def get_update_feed() -> UpdateFeedDTO:
    conn = get_db()
    try:
        base_select = (
            f"SELECT {STORY_SUMMARY_COLUMNS}, "
            "COALESCE(rc.computed_saves_count, 0) AS computed_saves_count, "
            "COALESCE(rc.computed_reads_count, 0) AS computed_reads_count "
            f"FROM stories {STORY_SHELF_COUNTS_JOIN}"
        )
        totd_row = conn.execute(
            f"""
            {base_select}
            WHERE stories.is_tale_of_the_day = 1
            ORDER BY stories.created_at_utc DESC LIMIT 1
            """
        ).fetchone()
        curator_row = conn.execute(
            f"""
            {base_select}
            WHERE stories.is_curator_spotlight = 1
            ORDER BY stories.created_at_utc DESC LIMIT 1
            """
        ).fetchone()
        recent_rows = conn.execute(
            f"""
            {base_select}
            WHERE stories.is_recent_submission = 1
            ORDER BY stories.created_at_utc DESC LIMIT 10
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
