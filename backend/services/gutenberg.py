import httpx
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid5
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import ChapterDTO, StoryDTO
from services.text_parser import extract_chapters_from_text
from services.story_service import row_to_story_dto

GUTENBERG_CHAPTER_NAMESPACE = UUID("d3675b18-25d3-5aa7-9c4f-65ea90fb89b2")
PROVIDER_HEADERS = {"User-Agent": "FableReader/1.0 (public-domain-text-client)"}


async def _fetch_gutenberg_text(gutenberg_id: int) -> str:
    url = f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, headers=PROVIDER_HEADERS)
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Gutenberg text service is unavailable") from error

    if response.status_code == 404:
        raise HTTPException(status_code=404, detail="Gutenberg book was not found")
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Gutenberg text service returned an error")
    if not response.text.strip():
        raise HTTPException(status_code=422, detail="Gutenberg book has no readable text")
    return response.text


async def get_gutenberg_chapters(gutenberg_id: int) -> list[ChapterDTO]:
    raw_text = await _fetch_gutenberg_text(gutenberg_id)
    parsed_chapters = extract_chapters_from_text(raw_text)
    if not parsed_chapters or not any(chapter["content"].strip() for chapter in parsed_chapters):
        raise HTTPException(status_code=422, detail="Unable to extract readable chapters from Gutenberg text")

    story_id = UUID(int=gutenberg_id)
    now = datetime.now(timezone.utc)
    return [
        ChapterDTO(
            id=uuid5(GUTENBERG_CHAPTER_NAMESPACE, f"{gutenberg_id}:{chapter['chapter_number']}"),
            story_id=story_id,
            chapter_number=chapter["chapter_number"],
            title=chapter["title"],
            content=chapter["content"],
            word_count=chapter["word_count"],
            created_at_utc=now,
        )
        for chapter in parsed_chapters
    ]


async def ingest_gutenberg_book(
    gutenberg_id: int,
    genre: Optional[str] = None,
) -> StoryDTO:
    metadata_url = "https://gutendex.com/books/"
    text_url = f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            metadata_response = await client.get(
                metadata_url,
                params={"ids": str(gutenberg_id)},
                headers=PROVIDER_HEADERS,
            )
            if metadata_response.status_code != 200:
                raise HTTPException(status_code=502, detail="Gutenberg catalog service returned an error")
            results = metadata_response.json().get("results", [])
            book = next((item for item in results if item.get("id") == gutenberg_id), None)
            if not book:
                raise HTTPException(status_code=404, detail="Gutenberg book was not found")

            text_response = await client.get(text_url, headers=PROVIDER_HEADERS)
            if text_response.status_code == 404:
                raise HTTPException(status_code=404, detail="Gutenberg text was not found")
            if text_response.status_code != 200:
                raise HTTPException(status_code=502, detail="Gutenberg text service returned an error")
            raw_text = text_response.text
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Gutenberg services are unavailable") from error

    parsed_chapters = extract_chapters_from_text(raw_text)
    if not parsed_chapters or not any(chapter["content"].strip() for chapter in parsed_chapters):
        raise HTTPException(status_code=422, detail="Unable to extract readable chapters from Gutenberg text")

    authors = book.get("authors", [])
    title = str(book.get("title", "")).strip()
    author_name = str(authors[0].get("name", "")).strip() if authors else ""
    if not title or not author_name:
        raise HTTPException(status_code=422, detail="Gutenberg metadata is incomplete")
    if ", " in author_name:
        family_name, given_names = author_name.split(", ", 1)
        author_name = f"{given_names} {family_name}"

    subjects = book.get("subjects", [])
    selected_genre = genre or (subjects[0] if subjects else "")
    summaries = book.get("summaries", [])
    synopsis = str(summaries[0]).strip() if summaries else ""
    cover_url = book.get("formats", {}).get("image/jpeg")
    if not cover_url:
        raise HTTPException(status_code=422, detail="Gutenberg edition has no cover image")
    download_count = max(0, int(book.get("download_count", 0)))
    story_id = UUID(int=gutenberg_id)
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    total_words = sum(chapter["word_count"] for chapter in parsed_chapters)
    read_minutes = max(1, total_words // 200)
    first_chapter = parsed_chapters[0]

    conn = get_db()
    try:
        with conn:
            existing = conn.execute(
                "SELECT id, created_at_utc FROM stories WHERE source_provider = ? AND provider_id = ?",
                ("GUTENBERG", str(gutenberg_id)),
            ).fetchone()
            if existing:
                story_id_value = existing["id"]
                created_at = existing["created_at_utc"]
                conn.execute(
                    """
                    UPDATE stories SET
                        title = ?, author = ?, genre = ?, chapter = ?, synopsis = ?, content = ?,
                        read_time_minutes = ?, updated_at_utc = ?, cover_image_url = ?,
                        total_chapters = ?, content_format = ?, provider_download_count = ?
                    WHERE id = ?
                    """,
                    (
                        title[:120], author_name[:80], selected_genre, first_chapter["title"],
                        synopsis, first_chapter["content"], read_minutes, now_iso, cover_url,
                        len(parsed_chapters), "PROSE", download_count, story_id_value,
                    ),
                )
            else:
                story_id_value = str(story_id)
                created_at = now_iso
                conn.execute(
                    """
                    INSERT INTO stories (
                        id, title, author, genre, chapter, synopsis, content,
                        read_time_minutes, created_at_utc, updated_at_utc, cover_image_url,
                        is_recent_submission, total_chapters, content_format, source_provider,
                        provider_id, provider_download_count
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        story_id_value, title[:120], author_name[:80], selected_genre,
                        first_chapter["title"], synopsis, first_chapter["content"], read_minutes,
                        created_at, now_iso, cover_url, 0, len(parsed_chapters), "PROSE",
                        "GUTENBERG", str(gutenberg_id), download_count,
                    ),
                )

            for chapter in parsed_chapters:
                chapter_id = str(
                    uuid5(GUTENBERG_CHAPTER_NAMESPACE, f"{gutenberg_id}:{chapter['chapter_number']}")
                )
                conn.execute(
                    """
                    INSERT INTO chapters (
                        id, story_id, chapter_number, title, content, word_count, created_at_utc
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        content = excluded.content,
                        word_count = excluded.word_count,
                        created_at_utc = excluded.created_at_utc
                    """,
                    (
                        chapter_id, story_id_value, chapter["chapter_number"], chapter["title"],
                        chapter["content"], chapter["word_count"], now_iso,
                    ),
                )

        row = conn.execute(
            "SELECT * FROM stories WHERE id = ?",
            (story_id_value,),
        ).fetchone()
        return row_to_story_dto(row, include_chapters=True, conn=conn)
    finally:
        conn.close()


async def get_gutenberg_stories(
    topic: Optional[str] = None,
    search: Optional[str] = None,
) -> list[StoryDTO]:
    params = {}
    if topic and topic.lower() != "all":
        params["topic"] = topic.lower()
    if search:
        params["search"] = search

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(
                "https://gutendex.com/books/",
                params=params,
                headers=PROVIDER_HEADERS,
            )
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog service is unavailable") from error
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Gutenberg catalog service returned an error")

    results = response.json().get("results", [])
    now = datetime.now(timezone.utc)
    stories: list[StoryDTO] = []
    for book in results[:20]:
        book_id = book.get("id")
        title = str(book.get("title", "")).strip()
        authors = book.get("authors", [])
        author_name = str(authors[0].get("name", "")).strip() if authors else ""
        if not book_id or not title or not author_name:
            continue
        if ", " in author_name:
            family_name, given_names = author_name.split(", ", 1)
            author_name = f"{given_names} {family_name}"

        subjects = book.get("subjects", [])
        genre = str(subjects[0]).strip() if subjects else (topic or "")
        summaries = book.get("summaries", [])
        synopsis = str(summaries[0]).strip() if summaries else ""
        cover_url = book.get("formats", {}).get("image/jpeg")
        if not cover_url:
            continue
        try:
            provider_download_count = max(0, int(book.get("download_count", 0)))
            story_id = UUID(int=int(book_id))
        except (TypeError, ValueError):
            continue

        stories.append(
            StoryDTO(
                id=story_id,
                title=title[:120],
                author=author_name[:80],
                genre=genre,
                chapter="",
                synopsis=synopsis,
                content="",
                read_time_minutes=0,
                is_bookmarked=False,
                is_completed=False,
                created_at_utc=now,
                updated_at_utc=now,
                cover_image_url=cover_url,
                total_pages=0,
                rating=None,
                saves_count="0",
                reads_count="0",
                total_chapters=0,
                content_format="PROSE",
                source_provider="GUTENBERG",
                provider_id=str(book_id),
                provider_download_count=provider_download_count,
            )
        )
    return stories
