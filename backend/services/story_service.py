import sqlite3
import httpx
from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import (
    StoryDTO,
    ChapterDTO,
    GenreDTO,
    WriterDTO,
    UpdateFeedDTO,
    CreateStoryRequest
)

GENRE_METADATA = {
    "Folklore": {
        "description": "Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.",
        "image_name": "genre_folklore",
        "default_readers": "18.4k"
    },
    "Mythology": {
        "description": "Epic sagas of deities, ancient heroes, and cosmic origins spanning classical traditions to obscure forgotten pantheons.",
        "image_name": "genre_mythology",
        "default_readers": "12.1k"
    },
    "Gothic": {
        "description": "Atmospheric hauntings, crumbling estates, and romantic dread exploring the psychological depths of human melancholy.",
        "image_name": "genre_gothic",
        "default_readers": "9.8k"
    },
    "Classic Fiction": {
        "description": "Enduring literary cornerstones, psychological inquiries, and philosophical journeys across the centuries.",
        "image_name": "genre_folklore",
        "default_readers": "16.5k"
    },
    "Classic Mystery": {
        "description": "Whodunits, deductive puzzles, and atmospheric investigations through gaslit cobblestones and locked rooms.",
        "image_name": "genre_mystery",
        "default_readers": "14.2k"
    }
}

def row_to_story_dto(r: sqlite3.Row, include_chapters: bool = False, conn: Optional[sqlite3.Connection] = None) -> StoryDTO:
    story_id = UUID(r["id"])
    chapters = None
    if include_chapters and conn:
        ch_rows = conn.execute(
            "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
            (str(story_id),)
        ).fetchall()
        chapters = [
            ChapterDTO(
                id=UUID(ch["id"]),
                story_id=story_id,
                chapter_number=ch["chapter_number"],
                title=ch["title"],
                content=ch["content"],
                word_count=ch["word_count"],
                created_at_utc=datetime.fromisoformat(ch["created_at_utc"])
            )
            for ch in ch_rows
        ]

    keys = r.keys()
    total_chapters = r["total_chapters"] if "total_chapters" in keys and r["total_chapters"] else 1
    return StoryDTO(
        id=story_id,
        title=r["title"],
        author=r["author"],
        genre=r["genre"],
        chapter=r["chapter"],
        synopsis=r["synopsis"],
        content=r["content"],
        read_time_minutes=r["read_time_minutes"],
        is_bookmarked=bool(r["is_bookmarked"]),
        is_completed=bool(r["is_completed"]),
        created_at_utc=datetime.fromisoformat(r["created_at_utc"]),
        updated_at_utc=datetime.fromisoformat(r["updated_at_utc"]),
        cover_image_name=r["cover_image_name"] if "cover_image_name" in keys else None,
        hero_image_name=r["hero_image_name"] if "hero_image_name" in keys else None,
        cover_image_url=r["cover_image_url"] if "cover_image_url" in keys else None,
        total_pages=r["total_pages"] if "total_pages" in keys and r["total_pages"] else 5,
        current_page=r["current_page"] if "current_page" in keys and r["current_page"] else 1,
        progress_percent=r["progress_percent"] if "progress_percent" in keys and r["progress_percent"] is not None else 0,
        rating=r["rating"] if "rating" in keys and r["rating"] else 4.9,
        saves_count=r["saves_count"] if "saves_count" in keys and r["saves_count"] else "1.2k",
        reads_count=r["reads_count"] if "reads_count" in keys and r["reads_count"] else "1.2k",
        is_tale_of_the_day=bool(r["is_tale_of_the_day"]) if "is_tale_of_the_day" in keys else False,
        is_recent_submission=bool(r["is_recent_submission"]) if "is_recent_submission" in keys else False,
        is_curator_spotlight=bool(r["is_curator_spotlight"]) if "is_curator_spotlight" in keys else False,
        badge_text=r["badge_text"] if "badge_text" in keys else None,
        total_chapters=total_chapters,
        chapters=chapters
    )

def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None
) -> list[StoryDTO]:
    conn = get_db()
    query = "SELECT * FROM stories WHERE 1=1"
    params = []

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
    results = [row_to_story_dto(r, include_chapters=False) for r in rows]
    conn.close()
    return results

def get_story_by_id(story_id: UUID) -> StoryDTO:
    conn = get_db()
    row = conn.execute("SELECT * FROM stories WHERE id = ?", (str(story_id),)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Story not found")
    story = row_to_story_dto(row, include_chapters=True, conn=conn)
    conn.close()
    return story

def get_story_chapters(story_id: UUID) -> list[ChapterDTO]:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
        (str(story_id),)
    ).fetchall()
    conn.close()

    if not rows:
        return []

    return [
        ChapterDTO(
            id=UUID(r["id"]),
            story_id=story_id,
            chapter_number=r["chapter_number"],
            title=r["title"],
            content=r["content"],
            word_count=r["word_count"],
            created_at_utc=datetime.fromisoformat(r["created_at_utc"])
        )
        for r in rows
    ]

def get_story_chapter_by_number(story_id: UUID, chapter_number: int) -> ChapterDTO:
    conn = get_db()
    row = conn.execute(
        "SELECT * FROM chapters WHERE story_id = ? AND chapter_number = ?",
        (str(story_id), chapter_number)
    ).fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail=f"Chapter {chapter_number} not found for story")

    return ChapterDTO(
        id=UUID(row["id"]),
        story_id=story_id,
        chapter_number=row["chapter_number"],
        title=row["title"],
        content=row["content"],
        word_count=row["word_count"],
        created_at_utc=datetime.fromisoformat(row["created_at_utc"])
    )

def create_story(payload: CreateStoryRequest) -> StoryDTO:
    story_id = str(uuid4())
    chapter_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    chapter_title = payload.chapter or "Chapter I"

    conn = get_db()
    with conn:
        conn.execute("""
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                is_recent_submission, total_chapters
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
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
            1
        ))

        words = len(payload.content.split())
        conn.execute("""
            INSERT INTO chapters (
                id, story_id, chapter_number, title, content, word_count, created_at_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            chapter_id, story_id, 1, chapter_title, payload.content, words, now_iso
        ))

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
        total_chapters=1
    )

def get_genres() -> list[GenreDTO]:
    conn = get_db()
    rows = conn.execute("""
        SELECT genre, COUNT(*) as story_count
        FROM stories
        GROUP BY genre
        ORDER BY story_count DESC
    """).fetchall()
    conn.close()

    db_counts = {r["genre"]: r["story_count"] for r in rows}

    genres: list[GenreDTO] = []
    all_genre_names = list(db_counts.keys())
    for name in GENRE_METADATA:
        if name not in all_genre_names:
            all_genre_names.append(name)

    for name in all_genre_names:
        count = db_counts.get(name, 0)
        meta = GENRE_METADATA.get(name, {
            "description": f"Curated collection of {name.lower()} tales and classical literature.",
            "image_name": "genre_folklore",
            "default_readers": f"{max(5, count * 3)}k"
        })
        genre_id = UUID(int=abs(hash(f"fable_genre_{name}")) % (2**128))
        genres.append(GenreDTO(
            id=genre_id,
            name=name,
            story_count=count,
            readers_count=meta["default_readers"],
            description=meta["description"],
            image_name=meta["image_name"]
        ))

    return genres

async def get_top_authors() -> list[WriterDTO]:
    open_library_url = "https://openlibrary.org/trending/daily.json"
    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}

    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            res = await client.get(open_library_url, headers=headers)
            if res.status_code == 200:
                payload = res.json()
                works = payload.get("works", [])

                author_map: dict[str, int] = {}
                for w in works[:25]:
                    authors = w.get("author_name", [])
                    for a in authors:
                        if isinstance(a, str) and len(a) > 2 and not a.startswith("http"):
                            author_map[a] = author_map.get(a, 0) + 1

                top_list = sorted(author_map.items(), key=lambda x: x[1], reverse=True)[:6]
                if top_list:
                    writers: list[WriterDTO] = []
                    for idx, (author_name, work_count) in enumerate(top_list):
                        writer_id = UUID(int=abs(hash(f"author_{author_name}")) % (2**128))
                        avatar_slug = f"author_{author_name.lower().replace(' ', '_').replace('.', '')[:15]}"
                        rating = round(4.7 + (idx % 3) * 0.1, 1)
                        writers.append(WriterDTO(
                            id=writer_id,
                            name=author_name,
                            avatar_image_name=avatar_slug,
                            story_count=max(2, work_count * 3),
                            rating=rating
                        ))
                    return writers
    except Exception:
        pass

    conn = get_db()
    rows = conn.execute("""
        SELECT author, COUNT(*) as story_count, AVG(rating) as avg_rating
        FROM stories
        GROUP BY author
        ORDER BY story_count DESC, avg_rating DESC
        LIMIT 6
    """).fetchall()
    conn.close()

    writers = []
    for r in rows:
        author_name = r["author"]
        writer_id = UUID(int=abs(hash(f"author_{author_name}")) % (2**128))
        avatar_slug = f"author_{author_name.lower().replace(' ', '_').replace('.', '')[:15]}"
        rating = round(r["avg_rating"] if r["avg_rating"] else 4.9, 1)
        writers.append(WriterDTO(
            id=writer_id,
            name=author_name,
            avatar_image_name=avatar_slug,
            story_count=r["story_count"],
            rating=rating
        ))
    return writers

def get_update_feed() -> UpdateFeedDTO:
    conn = get_db()

    totd_row = conn.execute("SELECT * FROM stories WHERE is_tale_of_the_day = 1 ORDER BY created_at_utc DESC LIMIT 1").fetchone()
    if not totd_row:
        totd_row = conn.execute("SELECT * FROM stories ORDER BY created_at_utc DESC LIMIT 1").fetchone()

    curator_row = conn.execute("SELECT * FROM stories WHERE is_curator_spotlight = 1 ORDER BY created_at_utc DESC LIMIT 1").fetchone()
    if not curator_row:
        curator_row = conn.execute("SELECT * FROM stories ORDER BY rating DESC LIMIT 1").fetchone()

    recents_rows = conn.execute("SELECT * FROM stories WHERE is_recent_submission = 1 ORDER BY created_at_utc DESC LIMIT 10").fetchall()
    if not recents_rows:
        recents_rows = conn.execute("SELECT * FROM stories ORDER BY created_at_utc DESC LIMIT 10").fetchall()

    total_count = conn.execute("SELECT COUNT(*) as count FROM stories").fetchone()["count"]

    totd_dto = row_to_story_dto(totd_row, include_chapters=False) if totd_row else None
    curator_dto = row_to_story_dto(curator_row, include_chapters=False) if curator_row else None
    recents_dto = [row_to_story_dto(r, include_chapters=False) for r in recents_rows]

    conn.close()

    return UpdateFeedDTO(
        tale_of_the_day=totd_dto,
        curator_spotlight=curator_dto,
        recent_submissions=recents_dto,
        total_stories=total_count,
        timestamp_utc=datetime.now(timezone.utc)
    )
