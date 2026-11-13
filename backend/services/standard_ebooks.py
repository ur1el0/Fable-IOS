from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional
from urllib.parse import quote, urlencode
from uuid import UUID, uuid5, NAMESPACE_URL
import asyncio
import logging
import re
import time
import xml.etree.ElementTree as ET

import httpx
from fastapi import HTTPException

from schemas.schemas import ChapterDTO, StoryDTO


logger = logging.getLogger(__name__)

STANDARD_EBOOKS_BASE_URL = "https://standardebooks.org"
STANDARD_EBOOKS_NAMESPACE = uuid5(NAMESPACE_URL, "https://standardebooks.org/ebooks")
STANDARD_EBOOKS_CATALOG_TTL_SECONDS = 1800
STANDARD_EBOOKS_DETAIL_TTL_SECONDS = 3600
STANDARD_EBOOKS_CHAPTER_TTL_SECONDS = 900
STANDARD_EBOOKS_MAX_SINGLE_PAGE_BYTES = 12 * 1024 * 1024
STANDARD_EBOOKS_USER_AGENT = "FableReader/1.0 (+https://standardebooks.org)"

XHTML_NS = "http://www.w3.org/1999/xhtml"
EPUB_NS = "http://www.idpf.org/2007/ops"
EPUB_TYPE_ATTR = f"{{{EPUB_NS}}}type"

_SLUG_PATTERN = re.compile(r"^[a-z0-9-]+(?:/[a-z0-9-]+){1,3}$")
_WORD_COUNT_PATTERN = re.compile(r"([\d,]+)\s+words?\s*\(", re.IGNORECASE)

_NON_STORY_EPUB_TYPES = frozenset({
    "frontmatter",
    "backmatter",
    "titlepage",
    "toc",
    "imprint",
    "colophon",
    "uncopyright",
    "halftitlepage",
    "copyright-page",
    "endnotes",
    "loi",
})

_BLOCK_TAGS = frozenset({"p", "blockquote", "li", "h3", "h4", "h5", "h6"})

_STANDARD_EBOOKS_CATALOG_CACHE: dict[tuple[str, str], tuple[float, list[StoryDTO]]] = {}
_STANDARD_EBOOKS_DETAIL_CACHE: dict[str, tuple[float, tuple[str, str, int]]] = {}
_STANDARD_EBOOKS_CHAPTER_CACHE: dict[str, tuple[float, list[ChapterDTO]]] = {}


def _local_tag(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _normalize_slug(book_id: str) -> str:
    slug = (book_id or "").strip().strip("/")
    if slug.startswith("ebooks/"):
        slug = slug[len("ebooks/"):]
    if not _SLUG_PATTERN.match(slug):
        raise HTTPException(status_code=400, detail="Invalid Standard Ebooks book identifier")
    return slug


def _standard_ebooks_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=httpx.Timeout(25.0, connect=10.0),
        follow_redirects=True,
        headers={
            "User-Agent": STANDARD_EBOOKS_USER_AGENT,
            "Accept": "application/xhtml+xml, application/xml, text/html;q=0.9",
        },
    )


def _collapse_whitespace(text: str) -> str:
    cleaned = (text or "").replace("\u2060", "").replace("\xa0", " ")
    return re.sub(r"\s+", " ", cleaned).strip()


def _parse_word_count_minutes(root: ET.Element) -> int:
    for elem in root.iter():
        if _local_tag(elem.tag) != "p":
            continue
        text = "".join(elem.itertext())
        if "reading ease" not in text.lower():
            continue
        match = _WORD_COUNT_PATTERN.search(text)
        if match:
            try:
                words = int(match.group(1).replace(",", ""))
                return max(1, round(words / 230))
            except ValueError:
                return 0
    return 0


def _pick_genre_from_tags(tags: list[str], fallback: str = "Classics") -> str:
    cleaned = [t.strip() for t in tags if t.strip()]
    specific = [t for t in cleaned if t.casefold() != "fiction"]
    if specific:
        return specific[0]
    if cleaned:
        return cleaned[0]
    return fallback


def parse_listing_xhtml(xml_bytes: bytes) -> list[dict[str, str]]:
    """Extracts catalog card metadata (slug, title, author, coverUrl) from a Standard Ebooks listing page."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as exc:
        raise HTTPException(status_code=502, detail="Invalid catalog response from Standard Ebooks") from exc

    entries: list[dict[str, str]] = []
    seen_slugs: set[str] = set()

    for item in root.iter():
        typeof_attr = item.attrib.get("typeof", "")
        about_attr = item.attrib.get("about", "")
        if "schema:Book" not in typeof_attr or not about_attr.startswith("/ebooks/"):
            continue
        slug = about_attr[len("/ebooks/"):].strip("/")
        if not _SLUG_PATTERN.match(slug) or slug in seen_slugs:
            continue

        title_el = item.find('.//*[@property="schema:name"]')
        title = _collapse_whitespace("".join(title_el.itertext())) if title_el is not None else ""
        if not title:
            continue

        author_names: list[str] = []
        for author_box in item.findall('.//*[@property="schema:author"]'):
            name_el = author_box.find('.//*[@property="schema:name"]')
            if name_el is not None:
                name = _collapse_whitespace("".join(name_el.itertext()))
                if name:
                    author_names.append(name)
        author = ", ".join(author_names) if author_names else "Standard Ebooks"

        cover_src = ""
        for img_el in item.iter():
            if _local_tag(img_el.tag) == "img":
                cover_src = (img_el.attrib.get("src") or "").strip()
                if cover_src:
                    break
        if cover_src.startswith("/"):
            cover_url = f"{STANDARD_EBOOKS_BASE_URL}{cover_src}"
        elif cover_src.startswith("https://"):
            cover_url = cover_src
        else:
            continue

        seen_slugs.add(slug)
        entries.append({
            "slug": slug,
            "title": title,
            "author": author,
            "cover_url": cover_url,
        })

    return entries


def parse_book_detail_xhtml(xml_bytes: bytes, fallback_title: str = "") -> tuple[str, str, int]:
    """Extracts (synopsis, genre, read_time_minutes) from a Standard Ebooks work page."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        synopsis = f"{fallback_title} — formatted by Standard Ebooks." if fallback_title else ""
        return synopsis, "Classics", 0

    paragraphs: list[str] = []
    desc_el = root.find('.//*[@property="schema:description"]')
    if desc_el is not None:
        for child in desc_el:
            if _local_tag(child.tag) == "p":
                p_text = _collapse_whitespace("".join(child.itertext()))
                if p_text:
                    paragraphs.append(p_text)
        if not paragraphs:
            text = _collapse_whitespace("".join(desc_el.itertext()))
            if text:
                paragraphs.append(text)

    synopsis = "\n\n".join(paragraphs)
    if not synopsis and fallback_title:
        synopsis = f"{fallback_title} — public-domain classic curated by Standard Ebooks."

    tags: list[str] = []
    for elem in root.iter():
        if _local_tag(elem.tag) == "ul" and "tags" in elem.attrib.get("class", "").split():
            for link in elem.iter():
                if _local_tag(link.tag) == "a":
                    tag_text = _collapse_whitespace("".join(link.itertext()))
                    if tag_text:
                        tags.append(tag_text)
            break

    genre = _pick_genre_from_tags(tags)
    read_minutes = _parse_word_count_minutes(root)
    return synopsis, genre, read_minutes


def _epub_types(elem: ET.Element) -> set[str]:
    raw = elem.attrib.get(EPUB_TYPE_ATTR, "") or ""
    return {tok.strip().lower() for tok in raw.split() if tok.strip()}


def _is_bodymatter_element(elem: ET.Element) -> bool:
    types = _epub_types(elem)
    if _local_tag(elem.tag) not in ("section", "article"):
        return False
    if types & _NON_STORY_EPUB_TYPES:
        return False
    if "bodymatter" in types:
        return True
    # Allow explicit chapter/short-story/prologue/epilogue/part nodes if bodymatter wasn't tagged
    return bool(types & {"chapter", "prologue", "epilogue", "part", "se:short-story"})


def _extract_heading_title(container: ET.Element, fallback_number: int) -> str:
    title_parts: list[str] = []
    header_el = None
    for child in container:
        if _local_tag(child.tag) == "header":
            header_el = child
            break

    if header_el is not None:
        for sub in header_el.iter():
            tag = _local_tag(sub.tag)
            if tag in ("h1", "h2", "h3", "h4"):
                txt = _collapse_whitespace("".join(sub.itertext()))
                if txt and txt not in title_parts:
                    title_parts.append(txt)
            elif tag == "p":
                sub_types = _epub_types(sub)
                if sub_types & {"title", "subtitle", "se:bridgehead", "bridgehead"} or "title" in sub.attrib.get("class", "").lower():
                    txt = _collapse_whitespace("".join(sub.itertext()))
                    if txt and txt not in title_parts:
                        title_parts.append(txt)
    else:
        for child in container:
            tag = _local_tag(child.tag)
            if tag == "hgroup":
                for sub in child.iter():
                    if _local_tag(sub.tag) in ("h1", "h2", "h3", "h4", "p"):
                        txt = _collapse_whitespace("".join(sub.itertext()))
                        if txt and txt not in title_parts:
                            title_parts.append(txt)
                break
            if tag in ("h1", "h2", "h3", "h4"):
                txt = _collapse_whitespace("".join(child.itertext()))
                if txt:
                    title_parts.append(txt)
                break

    if title_parts:
        if len(title_parts) > 1:
            normalized = [part.rstrip(".:;") or part for part in title_parts[:-1]] + [title_parts[-1]]
            return ": ".join(normalized)[:160]
        return title_parts[0][:160]
    elem_id = (container.attrib.get("id") or "").replace("-", " ").strip().title()
    return elem_id or f"Chapter {fallback_number}"


def _inline_text_without_noterefs(elem: ET.Element) -> str:
    """Flattens element text while preserving <br/> line breaks and omitting footnote superscripts."""
    chunks: list[str] = []

    def walk(node: ET.Element) -> None:
        tag = _local_tag(node.tag)
        if tag == "a" and "noteref" in _epub_types(node):
            if node.tail:
                chunks.append(node.tail)
            return
        if tag == "br":
            chunks.append("\n")
            if node.tail:
                chunks.append(node.tail)
            return
        if node.text:
            chunks.append(node.text)
        for child in node:
            walk(child)
        if node.tail and node is not elem:
            chunks.append(node.tail)

    walk(elem)
    raw = "".join(chunks).replace("\u2060", "").replace("\xa0", " ")
    lines = [re.sub(r"[ \t\r]+", " ", line).strip() for line in raw.split("\n")]
    return "\n".join(line for line in lines if line)


def _extract_prose_blocks(container: ET.Element) -> str:
    paragraphs: list[str] = []
    skipped_primary_heading = False

    def collect(node: ET.Element) -> None:
        tag = _local_tag(node.tag)
        if tag in ("header", "hgroup", "nav"):
            return
        if tag in ("p", "h3", "h4", "h5", "h6", "li"):
            block_text = _inline_text_without_noterefs(node)
            if block_text:
                paragraphs.append(block_text)
            return
        if tag == "blockquote":
            has_block_children = any(_local_tag(ch.tag) in _BLOCK_TAGS for ch in node)
            if has_block_children:
                for ch in node:
                    collect(ch)
            else:
                block_text = _inline_text_without_noterefs(node)
                if block_text:
                    paragraphs.append(block_text)
            return
        for ch in node:
            collect(ch)

    for child in container:
        tag = _local_tag(child.tag)
        # Skip direct section heading (e.g., <h3>I</h3>) already promoted into chapter.title
        if not skipped_primary_heading and not paragraphs and tag in ("h1", "h2", "h3", "h4"):
            skipped_primary_heading = True
            continue
        collect(child)

    return "\n\n".join(paragraphs)


def _collect_chapter_containers(root: ET.Element) -> list[tuple[Optional[str], ET.Element]]:
    """
    Collects chapter-level <article>/<section> nodes in reading order.
    - Anthologies (<article epub:type="... se:short-story">) yield each story as one chapter.
    - Multi-part novels (<section epub:type="... part">) flatten their child sections, preserving part prefix.
    - Standard novels yield leaf <section> elements under <main>/<body>.
    """
    ns_map = {"x": XHTML_NS}
    main_el = root.find(".//x:main", ns_map) or root.find(".//x:body", ns_map) or root

    items: list[tuple[Optional[str], ET.Element]] = []
    for child in main_el:
        if not _is_bodymatter_element(child):
            continue
        tag = _local_tag(child.tag)
        types = _epub_types(child)
        if tag == "article":
            items.append((None, child))
            continue

        nested_sections = [
            sub for sub in child
            if _is_bodymatter_element(sub)
        ]
        if ("part" in types or "volume" in types or "division" in types) and nested_sections:
            part_title = _extract_heading_title(child, len(items) + 1)
            for sub in nested_sections:
                items.append((part_title, sub))
        else:
            items.append((None, child))

    return items


def parse_single_page_chapters(xml_bytes: bytes, book_slug: str, story_id: Optional[UUID] = None) -> list[ChapterDTO]:
    """Parses Standard Ebooks `/text/single-page` XHTML into ordered `ChapterDTO` objects."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as exc:
        raise HTTPException(status_code=502, detail="Unable to parse Standard Ebooks text document") from exc

    resolved_story_id = story_id or uuid5(STANDARD_EBOOKS_NAMESPACE, f"book:{book_slug}")
    now = datetime.now(timezone.utc)
    containers = _collect_chapter_containers(root)

    chapters: list[ChapterDTO] = []
    chapter_idx = 1
    for part_prefix, container in containers:
        content = _extract_prose_blocks(container)
        word_count = len(content.split())
        if word_count == 0:
            continue

        raw_title = _extract_heading_title(container, chapter_idx)
        if part_prefix and not raw_title.startswith(part_prefix):
            title = f"{part_prefix} — {raw_title}"[:160]
        else:
            title = raw_title[:160]

        chapters.append(
            ChapterDTO(
                id=uuid5(STANDARD_EBOOKS_NAMESPACE, f"book:{book_slug}:chapter:{chapter_idx}"),
                story_id=resolved_story_id,
                chapter_number=chapter_idx,
                title=title,
                content=content,
                word_count=word_count,
                created_at_utc=now,
            )
        )
        chapter_idx += 1

    return chapters


async def _fetch_book_detail_metadata(
    client: httpx.AsyncClient,
    semaphore: asyncio.Semaphore,
    slug: str,
    title: str,
) -> tuple[str, str, int]:
    now = time.monotonic()
    cached = _STANDARD_EBOOKS_DETAIL_CACHE.get(slug)
    if cached and (now - cached[0]) < STANDARD_EBOOKS_DETAIL_TTL_SECONDS:
        return cached[1]

    async with semaphore:
        try:
            response = await client.get(f"{STANDARD_EBOOKS_BASE_URL}/ebooks/{slug}", timeout=8.0)
            if response.status_code != 200:
                fallback = (f"{title} — public-domain classic from Standard Ebooks.", "Classics", 0)
                return fallback
            detail = parse_book_detail_xhtml(response.content, fallback_title=title)
            _STANDARD_EBOOKS_DETAIL_CACHE[slug] = (time.monotonic(), detail)
            return detail
        except httpx.HTTPError:
            return (f"{title} — public-domain classic from Standard Ebooks.", "Classics", 0)


async def get_standard_ebooks_stories(
    topic: Optional[str] = None,
    search: Optional[str] = None,
) -> list[StoryDTO]:
    """Fetches public-domain catalog titles from Standard Ebooks."""
    normalized_topic = (topic or "").strip().lower()
    normalized_search = (search or "").strip()
    cache_key = (normalized_topic, normalized_search.casefold())

    now = time.monotonic()
    cached = _STANDARD_EBOOKS_CATALOG_CACHE.get(cache_key)
    if cached and (now - cached[0]) < STANDARD_EBOOKS_CATALOG_TTL_SECONDS:
        return list(cached[1])

    async with _standard_ebooks_client() as client:
        entries: list[dict[str, str]] = []
        try:
            if normalized_search:
                query = urlencode({"query": normalized_search, "page": 1, "per-page": 12})
                response = await client.get(f"{STANDARD_EBOOKS_BASE_URL}/ebooks?{query}")
                if response.status_code == 200:
                    entries = parse_listing_xhtml(response.content)
            elif normalized_topic:
                slug_topic = quote(normalized_topic.replace(" ", "-"), safe="-")
                response = await client.get(
                    f"{STANDARD_EBOOKS_BASE_URL}/subjects/{slug_topic}?sort=popularity&page=1&per-page=12"
                )
                if response.status_code == 200:
                    entries = parse_listing_xhtml(response.content)
                if not entries:
                    query = urlencode({"query": normalized_topic, "sort": "popularity", "page": 1, "per-page": 12})
                    fallback_resp = await client.get(f"{STANDARD_EBOOKS_BASE_URL}/ebooks?{query}")
                    if fallback_resp.status_code == 200:
                        entries = parse_listing_xhtml(fallback_resp.content)
            else:
                response = await client.get(f"{STANDARD_EBOOKS_BASE_URL}/ebooks?sort=popularity&page=1&per-page=12")
                if response.status_code == 200:
                    entries = parse_listing_xhtml(response.content)
                else:
                    raise HTTPException(status_code=502, detail="Standard Ebooks catalog service is unavailable")
        except HTTPException:
            raise
        except httpx.HTTPError as exc:
            logger.warning("Standard Ebooks catalog fetch failed: %s", exc)
            raise HTTPException(status_code=502, detail="Standard Ebooks catalog service is unavailable") from exc

        entries = entries[:12]
        semaphore = asyncio.Semaphore(6)
        details = await asyncio.gather(
            *(
                _fetch_book_detail_metadata(client, semaphore, entry["slug"], entry["title"])
                for entry in entries
            )
        )

    stories: list[StoryDTO] = []
    timestamp = datetime.now(timezone.utc)
    for entry, (synopsis, genre, read_minutes) in zip(entries, details):
        slug = entry["slug"]
        stories.append(
            StoryDTO(
                id=uuid5(STANDARD_EBOOKS_NAMESPACE, f"book:{slug}"),
                title=entry["title"][:120],
                author=entry["author"][:80],
                genre=genre,
                chapter="",
                synopsis=synopsis,
                content="",
                read_time_minutes=read_minutes,
                is_bookmarked=False,
                is_completed=False,
                created_at_utc=timestamp,
                updated_at_utc=timestamp,
                cover_image_url=entry["cover_url"],
                total_pages=0,
                current_page=1,
                progress_percent=0,
                saves_count="0",
                reads_count="0",
                badge_text=None,
                total_chapters=0,
                content_format="PROSE",
                source_provider="STANDARD_EBOOKS",
                provider_id=slug,
                provider_download_count=None,
                chapters=None,
            )
        )

    _STANDARD_EBOOKS_CATALOG_CACHE[cache_key] = (time.monotonic(), stories)
    return list(stories)


async def get_standard_ebooks_chapters(book_id: str) -> list[ChapterDTO]:
    """Fetches and parses the semantic XHTML chapter tree for a Standard Ebooks work."""
    slug = _normalize_slug(book_id)
    now = time.monotonic()
    cached = _STANDARD_EBOOKS_CHAPTER_CACHE.get(slug)
    if cached and (now - cached[0]) < STANDARD_EBOOKS_CHAPTER_TTL_SECONDS:
        return list(cached[1])

    url = f"{STANDARD_EBOOKS_BASE_URL}/ebooks/{slug}/text/single-page"
    try:
        async with _standard_ebooks_client() as client:
            async with client.stream("GET", url) as response:
                if response.status_code == 404:
                    raise HTTPException(status_code=404, detail="Standard Ebooks title not found")
                if response.status_code != 200:
                    raise HTTPException(status_code=502, detail="Unable to download text from Standard Ebooks")

                chunks: list[bytes] = []
                total_bytes = 0
                async for chunk in response.aiter_bytes():
                    total_bytes += len(chunk)
                    if total_bytes > STANDARD_EBOOKS_MAX_SINGLE_PAGE_BYTES:
                        raise HTTPException(status_code=413, detail="Standard Ebooks document exceeds size limit")
                    chunks.append(chunk)
                payload = b"".join(chunks)
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        logger.warning("Standard Ebooks text fetch failed for %s: %s", slug, exc)
        raise HTTPException(status_code=502, detail="Standard Ebooks text service is unavailable") from exc

    chapters = parse_single_page_chapters(payload, slug)
    if not chapters:
        raise HTTPException(status_code=422, detail="No readable chapters found in Standard Ebooks work")

    _STANDARD_EBOOKS_CHAPTER_CACHE[slug] = (time.monotonic(), chapters)
    return list(chapters)
