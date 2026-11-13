from __future__ import annotations

import asyncio
import csv
import gzip
import io
import logging
import os
import re
import tempfile
import time
import weakref
import xml.etree.ElementTree as ET
import zlib
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path
from typing import NamedTuple, Optional, Tuple, List
from uuid import UUID, uuid5

import httpx
from fastapi import HTTPException

from core.database import get_db
from schemas.schemas import ChapterDTO, StoryDTO, WriterDTO
from services.text_parser import extract_chapters_from_text
from services.story_service import row_to_story_dto

logger = logging.getLogger(__name__)
GUTENBERG_CHAPTER_NAMESPACE = UUID("d3675b18-25d3-5aa7-9c4f-65ea90fb89b2")
GUTENBERG_AUTHOR_NAMESPACE = UUID("44ca3de2-17a9-53c4-b0a1-5f739e28b67e")
PROVIDER_HEADERS = {"User-Agent": "FableReader/1.0 (public-domain-text-client)"}
GUTENBERG_CATALOG_URL = "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv.gz"
GUTENBERG_CATALOG_TTL_SECONDS = 7 * 24 * 60 * 60
GUTENBERG_CATALOG_REFRESH_RETRY_SECONDS = 60 * 60
GUTENBERG_CATALOG_MAX_COMPRESSED_BYTES = 12 * 1024 * 1024
GUTENBERG_CATALOG_MAX_UNCOMPRESSED_BYTES = 40 * 1024 * 1024
GUTENBERG_MAX_METADATA_BYTES = 2 * 1024 * 1024
GUTENBERG_MAX_TEXT_BYTES = 8 * 1024 * 1024
GUTENBERG_CHAPTER_CACHE_TTL_SECONDS = 600.0
GUTENBERG_CHAPTER_CACHE_MAX_ENTRIES = 32
GUTENBERG_CHAPTER_CACHE_MAX_BYTES = 16 * 1024 * 1024
GUTENBERG_MAX_CONCURRENT_FETCHES = 4
_GUTENBERG_CHAPTER_CACHE: OrderedDict[int, tuple[float, list[ChapterDTO]]] = OrderedDict()
_LOOP_PRIMITIVES: weakref.WeakKeyDictionary = weakref.WeakKeyDictionary()


def _loop_primitive(key: str, factory):
    loop = asyncio.get_running_loop()
    bucket = _LOOP_PRIMITIVES.setdefault(loop, {})
    if key not in bucket:
        bucket[key] = factory()
    return bucket[key]


def _get_fetch_semaphore() -> asyncio.Semaphore:
    return _loop_primitive(
        "fetch_semaphore",
        lambda: asyncio.Semaphore(GUTENBERG_MAX_CONCURRENT_FETCHES),
    )


def _get_metadata_semaphore() -> asyncio.Semaphore:
    return _loop_primitive(
        "metadata_semaphore",
        lambda: asyncio.Semaphore(GUTENBERG_MAX_CONCURRENT_FETCHES),
    )


def _get_catalog_lock() -> asyncio.Lock:
    return _loop_primitive("catalog_lock", asyncio.Lock)
_GUTENBERG_CATALOG_CACHE: Optional[Tuple[float, List["GutenbergCatalogEntry"]]] = None
_GUTENBERG_CATALOG_STALE_CACHE: Optional[Tuple[float, List["GutenbergCatalogEntry"]]] = None
_GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT = 0.0
GUTENBERG_AUTHORS_CACHE_TTL_SECONDS = 3600.0
_GUTENBERG_AUTHORS_CACHE: Optional[Tuple[float, List["GutenbergCatalogEntry"], List[WriterDTO]]] = None

_RDF_NAMESPACES = {
    "dc": "http://purl.org/dc/terms/",
    "pg": "http://www.gutenberg.org/2009/pgterms/",
    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
}


class GutenbergCatalogEntry(NamedTuple):
    gutenberg_id: int
    title: str
    authors: str
    subjects: str
    bookshelves: str
    language: str


def _gutenberg_catalog_cache_path() -> Path:
    database_path = Path(os.environ.get("FABLE_DB_PATH", "fable.sqlite3"))
    return database_path.with_name("gutenberg-catalog.csv.gz")


def _parse_gutenberg_catalog_snapshot(compressed_payload: bytes) -> list[GutenbergCatalogEntry]:
    if len(compressed_payload) > GUTENBERG_CATALOG_MAX_COMPRESSED_BYTES:
        raise HTTPException(status_code=502, detail="Gutenberg catalog exceeds the supported download size")
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(compressed_payload)) as catalog_file:
            csv_payload = catalog_file.read(GUTENBERG_CATALOG_MAX_UNCOMPRESSED_BYTES + 1)
        if len(csv_payload) > GUTENBERG_CATALOG_MAX_UNCOMPRESSED_BYTES:
            raise HTTPException(status_code=502, detail="Gutenberg catalog exceeds the supported expanded size")
        catalog_text = csv_payload.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(catalog_text, newline=""))
    except HTTPException:
        raise
    except (OSError, EOFError, UnicodeError, csv.Error, zlib.error) as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog snapshot is invalid") from error

    required_columns = {"Text#", "Type", "Title", "Language", "Authors", "Subjects", "Bookshelves"}
    if not reader.fieldnames or not required_columns.issubset(reader.fieldnames):
        raise HTTPException(status_code=502, detail="Gutenberg catalog snapshot has an unsupported format")

    entries = []
    try:
        for row in reader:
            if (row.get("Type") or "").strip().casefold() != "text":
                continue
            try:
                gutenberg_id = int(row.get("Text#", ""))
            except (TypeError, ValueError):
                continue
            title = (row.get("Title") or "").strip()
            if gutenberg_id < 1 or not title:
                continue
            entries.append(
                GutenbergCatalogEntry(
                    gutenberg_id=gutenberg_id,
                    title=title,
                    authors=(row.get("Authors") or "").strip(),
                    subjects=(row.get("Subjects") or "").strip(),
                    bookshelves=(row.get("Bookshelves") or "").strip(),
                    language=(row.get("Language") or "").strip(),
                )
            )
    except csv.Error as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog snapshot is invalid") from error
    if not entries:
        raise HTTPException(status_code=502, detail="Gutenberg catalog snapshot contained no text books")
    return entries


def _display_catalog_author(value: str) -> str:
    parts = [part.strip() for part in value.split(",") if part.strip()]
    if len(parts) >= 3 and any(character.isdigit() for character in parts[2]):
        parts = parts[:2]
    if len(parts) >= 2:
        return f"{' '.join(parts[1:])} {parts[0]}".strip()
    return parts[0] if parts else ""


def _read_cached_gutenberg_catalog(path: Path) -> Optional[Tuple[List[GutenbergCatalogEntry], float]]:
    try:
        file_stat = path.stat()
        if file_stat.st_size > GUTENBERG_CATALOG_MAX_COMPRESSED_BYTES:
            logger.warning("Ignoring oversized cached Gutenberg catalog snapshot")
            return None
        modified_at = file_stat.st_mtime
        payload = path.read_bytes()
    except OSError:
        return None
    try:
        entries = _parse_gutenberg_catalog_snapshot(payload)
    except HTTPException:
        logger.warning("Ignoring invalid cached Gutenberg catalog snapshot")
        return None
    age_seconds = max(0.0, time.time() - modified_at)
    return entries, age_seconds


def _write_gutenberg_catalog_cache(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f"{path.name}.",
            suffix=".tmp",
            dir=path.parent,
            delete=False,
        ) as cache_file:
            temporary_path = Path(cache_file.name)
            cache_file.write(payload)
            cache_file.flush()
            os.fsync(cache_file.fileno())
        os.replace(temporary_path, path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


async def _download_gutenberg_catalog_snapshot(client: httpx.AsyncClient) -> bytes:
    try:
        async with client.stream(
            "GET",
            GUTENBERG_CATALOG_URL,
            headers={**PROVIDER_HEADERS, "Accept-Encoding": "identity"},
            timeout=60.0,
        ) as response:
            if response.status_code != 200:
                raise HTTPException(status_code=502, detail="Gutenberg catalog service returned an error")

            content_length = response.headers.get("content-length")
            if content_length and content_length.isdigit():
                if int(content_length) > GUTENBERG_CATALOG_MAX_COMPRESSED_BYTES:
                    raise HTTPException(status_code=502, detail="Gutenberg catalog exceeds the supported download size")

            chunks = bytearray()
            async for chunk in response.aiter_bytes():
                if len(chunks) + len(chunk) > GUTENBERG_CATALOG_MAX_COMPRESSED_BYTES:
                    raise HTTPException(status_code=502, detail="Gutenberg catalog exceeds the supported download size")
                chunks.extend(chunk)
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog service is unavailable") from error
    if content_length and content_length.isdigit() and int(content_length) != len(chunks):
        raise HTTPException(status_code=502, detail="Gutenberg catalog download was incomplete")
    payload = bytes(chunks)
    _parse_gutenberg_catalog_snapshot(payload)
    return payload


async def _load_gutenberg_catalog(client: httpx.AsyncClient) -> list[GutenbergCatalogEntry]:
    global _GUTENBERG_CATALOG_CACHE, _GUTENBERG_CATALOG_STALE_CACHE, _GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT

    now = time.monotonic()
    if _GUTENBERG_CATALOG_CACHE and now - _GUTENBERG_CATALOG_CACHE[0] < GUTENBERG_CATALOG_TTL_SECONDS:
        return _GUTENBERG_CATALOG_CACHE[1]
    if (
        _GUTENBERG_CATALOG_STALE_CACHE
        and now - _GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT < GUTENBERG_CATALOG_REFRESH_RETRY_SECONDS
    ):
        return _GUTENBERG_CATALOG_STALE_CACHE[1]

    async with _get_catalog_lock():
        now = time.monotonic()
        if _GUTENBERG_CATALOG_CACHE and now - _GUTENBERG_CATALOG_CACHE[0] < GUTENBERG_CATALOG_TTL_SECONDS:
            return _GUTENBERG_CATALOG_CACHE[1]
        if (
            _GUTENBERG_CATALOG_STALE_CACHE
            and now - _GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT < GUTENBERG_CATALOG_REFRESH_RETRY_SECONDS
        ):
            return _GUTENBERG_CATALOG_STALE_CACHE[1]

        cache_path = _gutenberg_catalog_cache_path()
        disk_cache = _read_cached_gutenberg_catalog(cache_path)
        if disk_cache and disk_cache[1] < GUTENBERG_CATALOG_TTL_SECONDS:
            _GUTENBERG_CATALOG_CACHE = (now, disk_cache[0])
            _GUTENBERG_CATALOG_STALE_CACHE = None
            return disk_cache[0]

        if (
            disk_cache
            and now - _GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT < GUTENBERG_CATALOG_REFRESH_RETRY_SECONDS
        ):
            _GUTENBERG_CATALOG_STALE_CACHE = (now, disk_cache[0])
            return disk_cache[0]

        _GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT = now
        try:
            compressed_payload = await _download_gutenberg_catalog_snapshot(client)
            entries = _parse_gutenberg_catalog_snapshot(compressed_payload)
        except HTTPException:
            if disk_cache:
                logger.warning("Gutenberg catalog refresh failed; serving the cached snapshot")
                _GUTENBERG_CATALOG_STALE_CACHE = (time.monotonic(), disk_cache[0])
                return disk_cache[0]
            raise

        try:
            _write_gutenberg_catalog_cache(cache_path, compressed_payload)
        except OSError:
            logger.warning("Could not persist Gutenberg catalog snapshot; keeping it in memory")
        _GUTENBERG_CATALOG_CACHE = (time.monotonic(), entries)
        _GUTENBERG_CATALOG_STALE_CACHE = None
        return entries


def _clean_gutenberg_title(raw_title: str) -> str:
    cleaned = re.sub(r"\s*:\s*\$[a-z]\b\s*", ": ", raw_title or "", flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*\$[a-z]\b\s*", " ", cleaned, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", cleaned).strip()


_EXCLUDED_CATALOG_AUTHORS = frozenset({"various", "anonymous", "unknown"})

_GUTENBERG_GENRE_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Fables", ("fable",)),
    ("Gothic", ("gothic",)),
    ("Mystery", ("detective", "mystery", "murder")),
    ("Horror", ("horror", "ghost", "vampire", "supernatural")),
    ("Sci-Fi", ("science fiction",)),
    ("Fantasy", ("fantasy", "fairy tale")),
    ("Mythology", ("mythology",)),
    ("Folklore", ("folklore", "folk tale")),
    ("Adventure", ("adventure", "sea stor")),
    ("Historical fiction", ("historical fiction",)),
    ("Romance", ("love stor", "courtship", "romance")),
    ("Drama", ("drama", "traged", "comed")),
    ("Poetry", ("poetry", "poem")),
    ("Philosophy", ("philosophy",)),
    ("Biography", ("biography",)),
    ("History", ("history",)),
)


def _normalize_gutenberg_genre(subjects: list[str], fallback: str = "Classics") -> str:
    """Resolve raw Gutenberg LCSH subject arrays into a clean literary genre label."""
    cleaned = [str(item).strip() for item in subjects if str(item).strip()]
    if not cleaned:
        return fallback

    standalone = [tag for tag in cleaned if "--" not in tag]
    specific_standalone = [tag for tag in standalone if tag.casefold() != "fiction"]
    if specific_standalone:
        return specific_standalone[0][:50]

    combined = " ".join(cleaned).casefold()
    for canonical, keywords in _GUTENBERG_GENRE_KEYWORDS:
        if any(keyword in combined for keyword in keywords):
            return canonical

    if standalone or "fiction" in combined:
        return "Fiction"
    return fallback


def _search_gutenberg_catalog(
    entries: list[GutenbergCatalogEntry],
    params: dict,
) -> list[GutenbergCatalogEntry]:
    search = str(params.get("search") or "").strip().casefold()
    topic = str(params.get("topic") or "").strip().casefold()
    matching = []
    for entry in entries:
        cleaned_title = _clean_gutenberg_title(entry.title)
        title = cleaned_title.casefold()
        authors = entry.authors.casefold()
        display_authors = " ".join(
            _display_catalog_author(author).casefold()
            for author in entry.authors.split(";")
        )
        subjects = f"{entry.subjects} {entry.bookshelves}".casefold()
        if search and search not in f"{title} {authors} {display_authors}":
            continue
        if topic and topic not in subjects:
            continue

        lang_rank = 0 if entry.language.strip().casefold() == "en" else 1
        if search:
            text_rank = (
                0 if title == search
                else 1 if title.startswith(search)
                else 2 if search in title
                else 3
            )
            sort_key = (text_rank, lang_rank, entry.gutenberg_id)
        else:
            is_short_story = "short stories" in subjects and "short" not in topic
            is_curated_novel = any(
                tag in subjects
                for tag in ("category: novels", "best books ever", "harvard classics")
            )
            browse_tier = 2 if is_short_story else (0 if is_curated_novel else 1)
            sort_key = (lang_rank, browse_tier, entry.gutenberg_id)

        matching.append((sort_key, entry))

    matching.sort(key=lambda item: item[0])
    deduplicated: list[GutenbergCatalogEntry] = []
    seen_works: set[tuple[str, str]] = set()
    for _, entry in matching:
        primary_author = _display_catalog_author(entry.authors.split(";")[0]).casefold()
        work_key = (_clean_gutenberg_title(entry.title).casefold(), primary_author)
        if work_key in seen_works:
            continue
        seen_works.add(work_key)
        deduplicated.append(entry)
        if len(deduplicated) >= 24:
            break
    return deduplicated


def _gutenberg_book_from_rdf(payload: bytes, expected_id: int) -> Optional[dict]:
    if len(payload) > GUTENBERG_MAX_METADATA_BYTES:
        raise HTTPException(status_code=502, detail="Gutenberg metadata exceeds the supported size limit")
    try:
        root = ET.fromstring(payload)
    except ET.ParseError as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog returned invalid metadata") from error

    ebook = root.find("pg:ebook", _RDF_NAMESPACES)
    if ebook is None or ebook.get(f"{{{_RDF_NAMESPACES['rdf']}}}about") != f"ebooks/{expected_id}":
        return None

    title = _clean_gutenberg_title(
        ebook.findtext("dc:title", default="", namespaces=_RDF_NAMESPACES)
    )
    author_name = ebook.findtext(
        "dc:creator/pg:agent/pg:name", default="", namespaces=_RDF_NAMESPACES
    ).strip()
    if not title or not author_name:
        return None

    subjects = [
        value.text.strip()
        for value in ebook.findall("dc:subject/rdf:Description/rdf:value", _RDF_NAMESPACES)
        if value.text and value.text.strip()
    ]
    formats: dict[str, str] = {}
    for file_entry in ebook.findall("dc:hasFormat/pg:file", _RDF_NAMESPACES):
        url = file_entry.get(f"{{{_RDF_NAMESPACES['rdf']}}}about", "").strip()
        if not url.startswith("https://www.gutenberg.org/"):
            continue
        for mime_node in file_entry.findall("dc:format/rdf:Description/rdf:value", _RDF_NAMESPACES):
            mime_type = (mime_node.text or "").strip()
            if mime_type:
                existing_url = formats.get(mime_type, "")
                is_medium_cover = mime_type == "image/jpeg" and "cover.medium.jpg" in url
                existing_is_medium_cover = "cover.medium.jpg" in existing_url
                if not existing_url or (is_medium_cover and not existing_is_medium_cover):
                    formats[mime_type] = url

    try:
        download_count = max(
            0,
            int(ebook.findtext("pg:downloads", default="0", namespaces=_RDF_NAMESPACES)),
        )
    except ValueError:
        download_count = 0

    summaries = [
        node.text.strip()
        for node in ebook.findall("pg:marc520", _RDF_NAMESPACES)
        if node.text and node.text.strip()
    ]
    return {
        "id": expected_id,
        "title": title,
        "authors": [{"name": author_name}],
        "subjects": subjects,
        "summaries": summaries,
        "download_count": download_count,
        "formats": formats,
    }


async def _fetch_gutendex_books(client: httpx.AsyncClient, params: dict) -> Optional[list[dict]]:
    try:
        response = await client.get(
            "https://gutendex.com/books/",
            params=params,
            headers=PROVIDER_HEADERS,
        )
        if response.status_code != 200:
            return None
        payload = response.json()
        results = payload.get("results") if isinstance(payload, dict) else None
        if not isinstance(results, list):
            return None
        return [book for book in results if isinstance(book, dict)]
    except (httpx.HTTPError, ValueError):
        return None


async def _fetch_gutenberg_rdf_book(client: httpx.AsyncClient, gutenberg_id: int) -> Optional[dict]:
    metadata_url = f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.rdf"
    try:
        async with _get_metadata_semaphore():
            response = await client.get(metadata_url, headers=PROVIDER_HEADERS)
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Gutenberg catalog service is unavailable") from error
    if response.status_code == 404:
        return None
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Gutenberg catalog service returned an error")
    return _gutenberg_book_from_rdf(response.content, gutenberg_id)


async def _fetch_gutenberg_catalog_books(client: httpx.AsyncClient, params: dict) -> list[dict]:
    catalog = await _load_gutenberg_catalog(client)
    candidates = _search_gutenberg_catalog(catalog, params)

    async def fetch_readable_book(entry: GutenbergCatalogEntry) -> Optional[dict]:
        book = await _fetch_gutenberg_rdf_book(client, entry.gutenberg_id)
        if book is None or not _has_plain_text_format(book):
            return None
        return book

    results = await asyncio.gather(
        *(fetch_readable_book(entry) for entry in candidates),
        return_exceptions=True,
    )
    books = [result for result in results if isinstance(result, dict)]
    errors = [result for result in results if isinstance(result, HTTPException)]
    if errors:
        logger.warning("Gutenberg catalog fallback skipped %d unavailable metadata record(s)", len(errors))
    if not books and errors:
        raise errors[0]
    return books


async def _fetch_gutenberg_book_metadata(client: httpx.AsyncClient, gutenberg_id: int) -> Optional[dict]:
    try:
        book = await _fetch_gutenberg_rdf_book(client, gutenberg_id)
    except HTTPException as official_error:
        books = await _fetch_gutendex_books(client, {"ids": str(gutenberg_id)})
        if books is None:
            raise official_error
        return next((item for item in books if item.get("id") == gutenberg_id), None)
    if book is not None:
        return book
    books = await _fetch_gutendex_books(client, {"ids": str(gutenberg_id)})
    if books is None:
        return None
    return next((item for item in books if item.get("id") == gutenberg_id), None)


def invalidate_gutenberg_authors_cache() -> None:
    global _GUTENBERG_AUTHORS_CACHE
    _GUTENBERG_AUTHORS_CACHE = None


async def get_gutenberg_authors(limit: int = 6) -> list[WriterDTO]:
    """Return authors and book counts from the live Project Gutenberg catalog."""
    global _GUTENBERG_AUTHORS_CACHE
    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        entries = await _load_gutenberg_catalog(client)

    now = time.monotonic()
    if _GUTENBERG_AUTHORS_CACHE is not None:
        cached_at, cached_entries, cached_writers = _GUTENBERG_AUTHORS_CACHE
        if entries is cached_entries and now - cached_at < GUTENBERG_AUTHORS_CACHE_TTL_SECONDS:
            return cached_writers[:max(0, limit)]

    authors: dict[str, tuple[str, int]] = {}
    for entry in entries:
        for raw_author in entry.authors.split(";"):
            name = _display_catalog_author(raw_author)
            key = name.casefold()
            if not name or key in _EXCLUDED_CATALOG_AUTHORS:
                continue
            display_name, count = authors.get(key, (name, 0))
            authors[key] = (display_name, count + 1)

    ranked_authors = sorted(authors.values(), key=lambda author: (-author[1], author[0].casefold()))
    writers = [
        WriterDTO(
            id=uuid5(GUTENBERG_AUTHOR_NAMESPACE, name.casefold()),
            name=name,
            avatar_image_name="",
            avatar_image_url=None,
            story_count=count,
            rating=None,
        )
        for name, count in ranked_authors
    ]
    _GUTENBERG_AUTHORS_CACHE = (now, entries, writers)
    return writers[:max(0, limit)]


def _cached_gutenberg_chapters(gutenberg_id: int) -> Optional[list[ChapterDTO]]:
    cached = _GUTENBERG_CHAPTER_CACHE.get(gutenberg_id)
    if cached is None:
        return None
    cached_at, chapters = cached
    if time.monotonic() - cached_at >= GUTENBERG_CHAPTER_CACHE_TTL_SECONDS:
        del _GUTENBERG_CHAPTER_CACHE[gutenberg_id]
        return None
    _GUTENBERG_CHAPTER_CACHE.move_to_end(gutenberg_id)
    return chapters


def _cache_gutenberg_chapters(gutenberg_id: int, chapters: list[ChapterDTO]) -> None:
    now = time.monotonic()
    payload_bytes = sum(len(chapter.content.encode("utf-8")) for chapter in chapters)
    if payload_bytes > GUTENBERG_CHAPTER_CACHE_MAX_BYTES:
        return

    for cached_id, (cached_at, _) in list(_GUTENBERG_CHAPTER_CACHE.items()):
        if now - cached_at >= GUTENBERG_CHAPTER_CACHE_TTL_SECONDS:
            del _GUTENBERG_CHAPTER_CACHE[cached_id]

    _GUTENBERG_CHAPTER_CACHE.pop(gutenberg_id, None)
    current_bytes = sum(
        len(chapter.content.encode("utf-8"))
        for _, cached_chapters in _GUTENBERG_CHAPTER_CACHE.values()
        for chapter in cached_chapters
    )
    while _GUTENBERG_CHAPTER_CACHE and (
        len(_GUTENBERG_CHAPTER_CACHE) >= GUTENBERG_CHAPTER_CACHE_MAX_ENTRIES
        or current_bytes + payload_bytes > GUTENBERG_CHAPTER_CACHE_MAX_BYTES
    ):
        _, (_, evicted_chapters) = _GUTENBERG_CHAPTER_CACHE.popitem(last=False)
        current_bytes -= sum(len(chapter.content.encode("utf-8")) for chapter in evicted_chapters)

    _GUTENBERG_CHAPTER_CACHE[gutenberg_id] = (now, chapters)


def _has_plain_text_format(book: dict) -> bool:
    formats = book.get("formats") or {}
    return any("text/plain" in str(mime).lower() for mime in formats.keys())


def _extract_opening_excerpt(chapters: list[ChapterDTO], max_chars: int = 320) -> str:
    for chapter in chapters:
        paragraphs = [
            p.strip()
            for p in chapter.content.split("\n\n")
            if len(p.strip()) >= 40
        ]
        if paragraphs:
            excerpt = paragraphs[0]
            if len(excerpt) <= max_chars:
                return excerpt
            truncated = excerpt[:max_chars].rsplit(" ", 1)[0].rstrip(",;:")
            return f"{truncated}..."
    return ""


def _resolve_authentic_synopsis(summaries: list, chapters: Optional[list[ChapterDTO]] = None) -> str:
    raw_summary = str(summaries[0]).strip() if summaries else ""
    if "automatically generated summary" in raw_summary.lower():
        raw_summary = ""
    if raw_summary:
        return raw_summary
    if chapters:
        return _extract_opening_excerpt(chapters)
    return ""


async def _fetch_gutenberg_text(gutenberg_id: int) -> str:
    urls = [
        f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt",
        f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8",
    ]
    last_status = None
    last_error = None
    upstream_failed = False
    empty_response = False
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            for url in urls:
                try:
                    async with client.stream("GET", url, headers=PROVIDER_HEADERS) as response:
                        last_status = response.status_code
                        if response.status_code != 200:
                            if response.status_code != 404:
                                upstream_failed = True
                            # Gutenberg has two public text URL patterns. Treat transient
                            # upstream responses like a failed mirror and try the other one.
                            logger.warning(
                                "Gutenberg text endpoint returned HTTP %d for ebook %d; trying fallback",
                                response.status_code,
                                gutenberg_id,
                            )
                            continue

                        content_length = response.headers.get("content-length")
                        if (
                            content_length
                            and content_length.isdigit()
                            and int(content_length) > GUTENBERG_MAX_TEXT_BYTES
                        ):
                            raise HTTPException(
                                status_code=502,
                                detail="Gutenberg text exceeds the supported size limit",
                            )

                        chunks = bytearray()
                        async for chunk in response.aiter_bytes():
                            if len(chunks) + len(chunk) > GUTENBERG_MAX_TEXT_BYTES:
                                raise HTTPException(
                                    status_code=502,
                                    detail="Gutenberg text exceeds the supported size limit",
                                )
                            chunks.extend(chunk)
                        response_text = chunks.decode(response.encoding or "utf-8", errors="replace")
                        if not response_text.strip():
                            empty_response = True
                            logger.warning(
                                "Gutenberg text endpoint returned an empty response for ebook %d; trying fallback",
                                gutenberg_id,
                            )
                            continue
                        return response_text
                except httpx.HTTPError as error:
                    # A timeout or interrupted stream from one URL should not prevent
                    # attempting Gutenberg's alternate URL for the same ebook.
                    last_error = error
                    upstream_failed = True
                    logger.warning(
                        "Gutenberg text endpoint failed for ebook %d; trying fallback (%s)",
                        gutenberg_id,
                        type(error).__name__,
                    )
                    continue
    except HTTPException:
        raise

    if upstream_failed:
        error = HTTPException(status_code=502, detail="Gutenberg text service is unavailable")
        if last_error is not None:
            raise error from last_error
        raise error
    if last_status == 404:
        raise HTTPException(status_code=404, detail="Gutenberg book was not found")
    if empty_response:
        raise HTTPException(status_code=422, detail="Gutenberg book has no readable text")
    raise HTTPException(status_code=502, detail="Gutenberg text service returned an error")


async def get_gutenberg_chapters(gutenberg_id: int) -> list[ChapterDTO]:
    cached = _cached_gutenberg_chapters(gutenberg_id)
    if cached is not None:
        return cached

    async with _get_fetch_semaphore():
        cached = _cached_gutenberg_chapters(gutenberg_id)
        if cached is not None:
            return cached

        raw_text = await _fetch_gutenberg_text(gutenberg_id)
        parsed_chapters = extract_chapters_from_text(raw_text)
        if not parsed_chapters or not any(chapter["content"].strip() for chapter in parsed_chapters):
            raise HTTPException(status_code=422, detail="Unable to extract readable chapters from Gutenberg text")

        story_id = UUID(int=gutenberg_id)
        now = datetime.now(timezone.utc)
        chapters = [
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
            if chapter["content"].strip()
        ]
        if not chapters:
            raise HTTPException(status_code=422, detail="Unable to extract readable chapters from Gutenberg text")
        _cache_gutenberg_chapters(gutenberg_id, chapters)
        return chapters


async def ingest_gutenberg_book(
    gutenberg_id: int,
    genre: Optional[str] = None,
) -> StoryDTO:
    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        book = await _fetch_gutenberg_book_metadata(client, gutenberg_id)
    if not book:
        raise HTTPException(status_code=404, detail="Gutenberg book was not found")

    raw_text = await _fetch_gutenberg_text(gutenberg_id)

    parsed_chapters = extract_chapters_from_text(raw_text)
    if not parsed_chapters or not any(chapter["content"].strip() for chapter in parsed_chapters):
        raise HTTPException(status_code=422, detail="Unable to extract readable chapters from Gutenberg text")

    authors = book.get("authors", [])
    title = _clean_gutenberg_title(str(book.get("title", "")))
    author_name = str(authors[0].get("name", "")).strip() if authors else ""
    if not title or not author_name:
        raise HTTPException(status_code=422, detail="Gutenberg metadata is incomplete")
    if ", " in author_name:
        family_name, given_names = author_name.split(", ", 1)
        author_name = f"{given_names} {family_name}"

    subjects = book.get("subjects", [])
    selected_genre = genre or _normalize_gutenberg_genre(subjects)
    summaries = book.get("summaries", [])
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
    chapter_dtos = [
        ChapterDTO(
            id=uuid5(GUTENBERG_CHAPTER_NAMESPACE, f"{gutenberg_id}:{ch['chapter_number']}"),
            story_id=story_id,
            chapter_number=ch["chapter_number"],
            title=ch["title"],
            content=ch["content"],
            word_count=ch["word_count"],
            created_at_utc=now,
        )
        for ch in parsed_chapters
    ]
    synopsis = _resolve_authentic_synopsis(summaries, chapter_dtos)

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


def _story_from_gutenberg_metadata(
    book: dict,
    chapters: Optional[list[ChapterDTO]] = None,
) -> Optional[StoryDTO]:
    book_id = book.get("id")
    title = _clean_gutenberg_title(str(book.get("title", "")))
    authors = book.get("authors", [])
    author_name = str(authors[0].get("name", "")).strip() if authors else ""
    if not book_id or not title or not author_name:
        return None
    if ", " in author_name:
        family_name, given_names = author_name.split(", ", 1)
        author_name = f"{given_names} {family_name}"

    subjects = book.get("subjects", [])
    genre = _normalize_gutenberg_genre(subjects)
    summaries = book.get("summaries", [])
    synopsis = _resolve_authentic_synopsis(summaries, chapters)
    cover_url = book.get("formats", {}).get("image/jpeg")
    if not cover_url:
        return None
    try:
        provider_download_count = max(0, int(book.get("download_count", 0)))
        book_id = int(book_id)
        story_id = UUID(int=book_id)
    except (TypeError, ValueError):
        return None

    first_chapter_title = chapters[0].title if chapters else ""
    first_chapter_content = chapters[0].content if chapters else ""
    total_words = sum(c.word_count for c in chapters) if chapters else 0
    read_minutes = max(1, total_words // 200) if total_words > 0 else 0

    now = datetime.now(timezone.utc)
    return StoryDTO(
        id=story_id,
        title=title[:120],
        author=author_name[:80],
        genre=genre,
        chapter=first_chapter_title,
        synopsis=synopsis,
        content=first_chapter_content,
        read_time_minutes=read_minutes,
        is_bookmarked=False,
        is_completed=False,
        created_at_utc=now,
        updated_at_utc=now,
        cover_image_url=cover_url,
        total_pages=0,
        rating=None,
        saves_count="0",
        reads_count="0",
        total_chapters=len(chapters) if chapters else 0,
        content_format="PROSE",
        source_provider="GUTENBERG",
        provider_id=str(book_id),
        provider_download_count=provider_download_count,
        chapters=chapters,
    )


async def get_gutenberg_story_by_id(gutenberg_id: int) -> StoryDTO:
    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        book = await _fetch_gutenberg_book_metadata(client, gutenberg_id)
    if book is None:
        raise HTTPException(status_code=404, detail="Gutenberg book was not found")

    # Keep metadata/detail requests light. The reader loads chapter text only
    # when the user opens a book through the dedicated chapters endpoint.
    if not _has_plain_text_format(book):
        raise HTTPException(status_code=422, detail="Gutenberg book has no readable text")
    story = _story_from_gutenberg_metadata(book)
    if story is None:
        raise HTTPException(status_code=422, detail="Gutenberg metadata is incomplete")
    return story


async def get_gutenberg_stories(
    topic: Optional[str] = None,
    search: Optional[str] = None,
) -> list[StoryDTO]:
    params = {}
    if topic and topic.lower() != "all":
        params["topic"] = topic.lower()
    if search:
        params["search"] = search

    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        try:
            raw_books = await _fetch_gutenberg_catalog_books(client, params)
        except HTTPException as official_error:
            # Keep the catalog available during a Gutenberg feed outage, but
            # always prefer its own CSV/RDF metadata when the official source works.
            raw_books = await _fetch_gutendex_books(client, params)
            if raw_books is None:
                raise official_error
            logger.warning("Official Gutenberg catalog unavailable; used Gutendex fallback metadata")
        if not raw_books:
            # An empty search result is a valid response, not an upstream outage.
            return []
    raw_books = raw_books[:12]

    def _map_book(book: dict) -> Optional[StoryDTO]:
        book_id = book.get("id")
        if not book_id or not _has_plain_text_format(book):
            return None
        return _story_from_gutenberg_metadata(book)

    # Full text is fetched on demand by /public/gutenberg/{id}/chapters.
    return [story for book in raw_books if (story := _map_book(book)) is not None]
