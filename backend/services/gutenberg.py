import httpx
from datetime import datetime, timezone
from uuid import UUID, uuid4, uuid5
from typing import Optional
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import ChapterDTO, StoryDTO
from services.text_parser import extract_chapters_from_text
from services.story_service import row_to_story_dto, get_stories


GUTENBERG_CHAPTER_NAMESPACE = UUID("d3675b18-25d3-5aa7-9c4f-65ea90fb89b2")


async def _fetch_gutenberg_text(gutenberg_id: int) -> str:
    url = f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8"
    headers = {"User-Agent": "FableReader/1.0 (public-domain-text-client)"}
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, headers=headers)
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
    genre: Optional[str] = "Folklore"
) -> StoryDTO:
    """
    Live Ingestion Engine: Fetches full plain text from Project Gutenberg, parses
    actual chapters, extracts metadata, and stores into Fable database.
    """
    text_url = f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8"
    meta_url = f"https://gutendex.com/books/?ids={gutenberg_id}"

    title = f"Gutenberg Classic #{gutenberg_id}"
    author = "Public Domain"
    cover_url = f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.cover.medium.jpg"
    synopsis = f"Authentic public-domain edition #{gutenberg_id} from Project Gutenberg."

    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            meta_res = await client.get(meta_url, headers=headers)
            if meta_res.status_code == 200:
                results = meta_res.json().get("results", [])
                if results:
                    book_meta = results[0]
                    title = book_meta.get("title", title)
                    authors = book_meta.get("authors", [])
                    if authors:
                        raw_name = authors[0].get("name", author)
                        if ", " in raw_name:
                            p = raw_name.split(", ", 1)
                            author = f"{p[1]} {p[0]}"
                        else:
                            author = raw_name
                    summaries = book_meta.get("summaries", [])
                    if summaries:
                        synopsis = summaries[0]
        except Exception:
            pass

        try:
            txt_res = await client.get(text_url, headers=headers)
            if txt_res.status_code != 200:
                raise HTTPException(status_code=400, detail=f"Failed to fetch text from Gutenberg for ID {gutenberg_id}")
            raw_text = txt_res.text
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"External Gutenberg network error: {str(e)}")

    chapters = extract_chapters_from_text(raw_text)
    if not chapters:
        raise HTTPException(status_code=422, detail="Unable to extract chapters from manuscript text")

    story_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    first_chapter = chapters[0]
    total_words = sum(c["word_count"] for c in chapters)
    read_mins = max(3, total_words // 200)

    conn = get_db()
    with conn:
        conn.execute("""
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                cover_image_url, is_recent_submission, total_chapters, content_format, source_provider
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            story_id, title[:120], author[:80], genre or "Folklore", first_chapter["title"],
            synopsis[:300], first_chapter["content"], read_mins, 0, 0,
            now_iso, now_iso, cover_url, 1, len(chapters), "PROSE", "GUTENBERG"
        ))

        for ch in chapters:
            ch_id = str(uuid4())
            conn.execute("""
                INSERT INTO chapters (
                    id, story_id, chapter_number, title, content, word_count, created_at_utc
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                ch_id, story_id, ch["chapter_number"], ch["title"], ch["content"], ch["word_count"], now_iso
            ))

    row = conn.execute("SELECT * FROM stories WHERE id = ?", (story_id,)).fetchone()
    dto = row_to_story_dto(row, include_chapters=True, conn=conn)
    conn.close()
    return dto

async def get_gutenberg_stories(
    topic: Optional[str] = "folklore",
    search: Optional[str] = None
) -> list[StoryDTO]:
    """
    Public literature gateway: Queries Project Gutenberg via Gutendex REST API,
    normalizes unstructured literary data into Fable's StoryDTO schema with cover URLs.
    """
    url = "https://gutendex.com/books/"
    params = {}
    if topic and topic.lower() != "all":
        params["topic"] = topic.lower()
    if search:
        params["search"] = search

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(url, params=params, headers=headers)
            if resp.status_code == 200:
                payload = resp.json()
                results = payload.get("results", [])
                gutenberg_stories: list[StoryDTO] = []
                now = datetime.now(timezone.utc)

                for book in results[:10]:
                    book_id = book.get("id", 1000)
                    title = book.get("title", "Untitled Classic")
                    authors = book.get("authors", [])
                    author_name = authors[0].get("name", "Classic Author") if authors else "Public Domain"
                    if ", " in author_name:
                        parts = author_name.split(", ", 1)
                        author_name = f"{parts[1]} {parts[0]}"

                    summaries = book.get("summaries", [])
                    synopsis = summaries[0] if summaries else f"Classic public domain edition of {title} from Project Gutenberg."
                    if len(synopsis) > 280:
                        synopsis = synopsis[:277] + "..."

                    formats = book.get("formats", {})
                    cover_url = formats.get("image/jpeg")

                    subjects = book.get("subjects", [])
                    genre = "Folklore"
                    if any("myth" in s.lower() for s in subjects):
                        genre = "Mythology"
                    elif any("gothic" in s.lower() or "horror" in s.lower() for s in subjects):
                        genre = "Gothic"
                    elif any("fiction" in s.lower() for s in subjects):
                        genre = "Classic Fiction"
                    elif topic and topic.lower() != "all":
                        genre = topic.capitalize()

                    story_uuid = UUID(int=int(book_id))

                    gutenberg_stories.append(StoryDTO(
                        id=story_uuid,
                        title=title[:120],
                        author=author_name[:80],
                        genre=genre,
                        chapter="Chapter I",
                        synopsis=synopsis,
                        content="",
                        read_time_minutes=max(3, min(12, len(title.split()) * 2)),
                        is_bookmarked=False,
                        is_completed=False,
                        created_at_utc=now,
                        updated_at_utc=now,
                        cover_image_url=cover_url,
                        total_chapters=1,
                        content_format="PROSE",
                        source_provider="GUTENBERG",
                        provider_id=str(book_id),
                    ))

                if gutenberg_stories:
                    return gutenberg_stories
    except Exception:
        pass

    return get_stories(genre=topic, search=search)
