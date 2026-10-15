import asyncio
import json
import time
import urllib.parse
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid5
import httpx
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import ChapterDTO, StoryDTO
from services.story_service import row_to_story_dto

MANGA_NAMESPACE = UUID("e819b12e-84cb-4d9b-a359-52e8964e528b")
PROVIDER_HEADERS = {
    "User-Agent": "FableReader/1.0 (manga-ingestion-proxy; https://github.com/ur1el0/Fable-IOS)"
}

# In-memory TTL cache to protect upstream provider from rate limits (5 req/sec limit)
_CACHE: dict[str, tuple[float, any]] = {}
CACHE_TTL_SECONDS = 600.0  # 10 minutes cache


def _get_from_cache(key: str):
    cached = _CACHE.get(key)
    if cached:
        timestamp, data = cached
        if time.time() - timestamp < CACHE_TTL_SECONDS:
            return data
        del _CACHE[key]
    return None


def _set_in_cache(key: str, data: any):
    _CACHE[key] = (time.time(), data)


async def _fetch_json_with_fallback(url: str, params: Optional[list] = None) -> dict:
    """
    Attempts to fetch upstream JSON via HTTPX. If Python's TLS stack lacks modern
    handshake ciphers (e.g. LibreSSL on macOS), gracefully falls back to system curl.
    """
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(url, params=params, headers=PROVIDER_HEADERS)
            if resp.status_code == 200:
                return resp.json()
            if resp.status_code == 404:
                return {}
    except Exception:
        pass

    try:
        full_url = url
        if params:
            query_str = urllib.parse.urlencode(params)
            full_url = f"{url}?{query_str}"
        proc = await asyncio.create_subprocess_exec(
            "curl", "-s", "--max-time", "15",
            "-H", f"User-Agent: {PROVIDER_HEADERS['User-Agent']}",
            full_url,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        if stdout:
            return json.loads(stdout.decode("utf-8"))
    except Exception as err:
        raise HTTPException(status_code=502, detail="Manga upstream service unavailable") from err

    raise HTTPException(status_code=502, detail="Manga upstream service unavailable")


def _story_from_mangadex_item(item: dict) -> Optional[StoryDTO]:
    manga_id = item.get("id")
    attrs = item.get("attributes", {})
    if not manga_id or not attrs:
        return None

    title_dict = attrs.get("title", {})
    title = title_dict.get("en")
    if not title:
        for alt in attrs.get("altTitles", []):
            if "en" in alt:
                title = alt["en"]
                break
    if not title:
        title = next(iter(title_dict.values())) if title_dict else "Untitled Manga"

    desc_dict = attrs.get("description", {})
    synopsis = desc_dict.get("en", "")

    cover_file_name = None
    author_name = "Manga Artist"
    for rel in item.get("relationships", []):
        rel_type = rel.get("type")
        rel_attrs = rel.get("attributes") or {}
        if rel_type == "cover_art" and "fileName" in rel_attrs:
            cover_file_name = rel_attrs["fileName"]
        elif rel_type == "author" and "name" in rel_attrs:
            if rel_attrs["name"].strip():
                author_name = rel_attrs["name"].strip()

    cover_url = (
        f"https://uploads.mangadex.org/covers/{manga_id}/{cover_file_name}.256.jpg"
        if cover_file_name
        else None
    )

    story_uuid = uuid5(MANGA_NAMESPACE, f"mangadex:{manga_id}")
    now = datetime.now(timezone.utc)

    return StoryDTO(
        id=story_uuid,
        title=title[:120],
        author=author_name[:80],
        genre="Manga",
        chapter="Chapter 1",
        synopsis=synopsis,
        content="",
        read_time_minutes=15,
        created_at_utc=now,
        updated_at_utc=now,
        cover_image_url=cover_url,
        badge_text="MANGA",
        total_chapters=1,
        content_format="MANGA",
        source_provider="MANGADEX",
        provider_id=manga_id,
        is_curator_spotlight=False,
        is_recent_submission=True,
    )


async def search_manga(
    query: Optional[str] = None,
    limit: int = 20,
    offset: int = 0
) -> list[StoryDTO]:
    cache_key = f"manga_search:{query or ''}:{limit}:{offset}"
    cached = _get_from_cache(cache_key)
    if cached is not None:
        return cached

    url = "https://api.mangadex.org/manga"
    params = [
        ("limit", str(min(limit, 50))),
        ("offset", str(offset)),
        ("includes[]", "cover_art"),
        ("includes[]", "author"),
        ("availableTranslatedLanguage[]", "en"),
        ("contentRating[]", "safe"),
        ("contentRating[]", "suggestive"),
    ]

    if query and query.strip():
        params.append(("title", query.strip()))
        params.append(("order[relevance]", "desc"))
    else:
        params.append(("order[followedCount]", "desc"))

    data = await _fetch_json_with_fallback(url, params=params)
    items = data.get("data", [])
    results: list[StoryDTO] = []
    for item in items:
        dto = _story_from_mangadex_item(item)
        if dto:
            results.append(dto)

    _set_in_cache(cache_key, results)
    return results


async def get_manga_by_id(manga_id: str) -> StoryDTO:
    cache_key = f"manga_detail:{manga_id}"
    cached = _get_from_cache(cache_key)
    if cached is not None:
        return cached

    url = f"https://api.mangadex.org/manga/{manga_id}"
    params = [
        ("includes[]", "cover_art"),
        ("includes[]", "author"),
    ]

    data = await _fetch_json_with_fallback(url, params=params)
    item = data.get("data", {})
    dto = _story_from_mangadex_item(item)
    if not dto:
        raise HTTPException(status_code=404, detail="Manga title not found")

    _set_in_cache(cache_key, dto)
    return dto


async def get_manga_chapters(manga_id: str, limit: int = 20) -> list[ChapterDTO]:
    cache_key = f"manga_chapters:{manga_id}:{limit}"
    cached = _get_from_cache(cache_key)
    if cached is not None:
        return cached

    url = f"https://api.mangadex.org/manga/{manga_id}/feed"
    params = [
        ("translatedLanguage[]", "en"),
        ("order[chapter]", "asc"),
        ("limit", str(min(limit, 50))),
    ]

    feed_json = await _fetch_json_with_fallback(url, params=params)
    feed_data = feed_json.get("data", [])
    story_uuid = uuid5(MANGA_NAMESPACE, f"mangadex:{manga_id}")
    now = datetime.now(timezone.utc)
    chapters: list[ChapterDTO] = []

    for idx, ch in enumerate(feed_data):
        ch_id = ch.get("id")
        attrs = ch.get("attributes", {})
        if not ch_id or not attrs:
            continue

        ch_num_str = attrs.get("chapter") or f"{idx + 1}"
        try:
            ch_num = max(0, int(float(ch_num_str)))
        except (ValueError, TypeError):
            ch_num = idx + 1

        raw_title = attrs.get("title") or ""
        display_title = raw_title if raw_title.strip() else f"Chapter {ch_num_str}"
        external_url = attrs.get("externalUrl")

        page_urls: list[str] = []
        if not external_url:
            try:
                ah_url = f"https://api.mangadex.org/at-home/server/{ch_id}"
                ah_data = await _fetch_json_with_fallback(ah_url)
                base_url = ah_data.get("baseUrl")
                chapter_obj = ah_data.get("chapter", {})
                hash_val = chapter_obj.get("hash")
                files = (
                    chapter_obj.get("dataSaver")
                    or chapter_obj.get("data")
                    or []
                )
                if base_url and hash_val and files:
                    page_urls = [
                        f"{base_url}/data-saver/{hash_val}/{file_name}"
                        for file_name in files
                    ]
            except Exception:
                page_urls = []

        chapter_dto = ChapterDTO(
            id=uuid5(MANGA_NAMESPACE, f"mangadex_chapter:{ch_id}"),
            story_id=story_uuid,
            chapter_number=ch_num,
            title=display_title,
            content=external_url or "",
            word_count=0,
            created_at_utc=now,
            page_urls=page_urls,
        )
        chapters.append(chapter_dto)

    _set_in_cache(cache_key, chapters)
    return chapters


async def ingest_manga_story(manga_id: str) -> StoryDTO:
    story = await get_manga_by_id(manga_id)
    chapters = await get_manga_chapters(manga_id, limit=20)

    now_iso = datetime.now(timezone.utc).isoformat()
    story_id_value = str(story.id)

    conn = get_db()
    try:
        with conn:
            existing = conn.execute(
                "SELECT id, created_at_utc FROM stories WHERE source_provider = ? AND provider_id = ?",
                ("MANGADEX", manga_id),
            ).fetchone()

            if existing:
                story_id_value = existing["id"]
                created_at = existing["created_at_utc"]
                conn.execute(
                    """
                    UPDATE stories SET
                        title = ?, author = ?, genre = ?, chapter = ?, synopsis = ?, content = ?,
                        read_time_minutes = ?, updated_at_utc = ?, cover_image_url = ?,
                        total_chapters = ?, content_format = ?, source_provider = ?, provider_id = ?
                    WHERE id = ?
                    """,
                    (
                        story.title[:120], story.author[:80], "Manga",
                        chapters[0].title if chapters else "Chapter 1",
                        story.synopsis, "", story.read_time_minutes, now_iso,
                        story.cover_image_url, len(chapters), "MANGA", "MANGADEX",
                        manga_id, story_id_value,
                    ),
                )
            else:
                created_at = now_iso
                conn.execute(
                    """
                    INSERT INTO stories (
                        id, title, author, genre, chapter, synopsis, content,
                        read_time_minutes, created_at_utc, updated_at_utc, cover_image_url,
                        is_recent_submission, total_chapters, content_format, source_provider,
                        provider_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        story_id_value, story.title[:120], story.author[:80], "Manga",
                        chapters[0].title if chapters else "Chapter 1",
                        story.synopsis, "", story.read_time_minutes, created_at, now_iso,
                        story.cover_image_url, 1, len(chapters), "MANGA", "MANGADEX",
                        manga_id,
                    ),
                )

            for ch in chapters:
                ch_id_str = str(ch.id)
                page_urls_json = json.dumps(ch.page_urls)
                conn.execute(
                    """
                    INSERT INTO chapters (
                        id, story_id, chapter_number, title, content, word_count, created_at_utc, page_urls
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        content = excluded.content,
                        page_urls = excluded.page_urls,
                        created_at_utc = excluded.created_at_utc
                    """,
                    (
                        ch_id_str, story_id_value, ch.chapter_number, ch.title,
                        ch.content or "", ch.word_count, now_iso, page_urls_json,
                    ),
                )

        row = conn.execute("SELECT * FROM stories WHERE id = ?", (story_id_value,)).fetchone()
        return row_to_story_dto(row, include_chapters=True, conn=conn)
    finally:
        conn.close()
