"""Opt-in live checks against provider documents. These are skipped by default.

Run with: FABLE_RUN_LIVE_PROVIDER_TESTS=1 python -m pytest backend/test_provider_live.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import httpx
import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = Path(__file__).resolve().parent
for directory in (str(REPO_ROOT), str(BACKEND_DIR)):
    if directory not in sys.path:
        sys.path.insert(0, directory)

from services.standard_ebooks import parse_single_page_chapters
from services.text_parser import extract_chapters_from_text

LIVE_TESTS_ENABLED = os.environ.get("FABLE_RUN_LIVE_PROVIDER_TESTS", "").strip() == "1"
pytestmark = pytest.mark.skipif(
    not LIVE_TESTS_ENABLED,
    reason="Set FABLE_RUN_LIVE_PROVIDER_TESTS=1 to run live provider checks",
)

PROVIDER_HEADERS = {"User-Agent": "FableReader/1.0 (read-only provider validation)"}


def _fetch_bounded_document(url: str, max_bytes: int) -> bytes:
    payload = bytearray()
    timeout = httpx.Timeout(60.0, connect=10.0)
    with httpx.Client(timeout=timeout, follow_redirects=True, headers=PROVIDER_HEADERS) as client:
        with client.stream("GET", url) as response:
            response.raise_for_status()
            content_length = response.headers.get("content-length")
            if content_length and content_length.isdigit():
                assert int(content_length) <= max_bytes, "Provider document exceeds the validation size limit"
            for chunk in response.iter_bytes():
                assert len(payload) + len(chunk) <= max_bytes, "Provider document exceeds the validation size limit"
                payload.extend(chunk)
    return bytes(payload)


@pytest.mark.parametrize(
    ("gutenberg_id", "minimum_chapter_count"),
    ((42, 10), (24, 20)),
    ids=("jekyll-and-hyde-unnumbered-toc", "o-pioneers-nested-parts"),
)
def test_live_gutenberg_classics_parse_into_chapters(gutenberg_id: int, minimum_chapter_count: int):
    url = f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt"
    document = _fetch_bounded_document(url, max_bytes=8 * 1024 * 1024)
    chapters = extract_chapters_from_text(document.decode("utf-8-sig", errors="replace"))

    assert len(chapters) >= minimum_chapter_count
    titles = [chapter["title"].casefold() for chapter in chapters]
    if gutenberg_id == 42:
        assert any("story of the door" in title for title in titles)
        assert any("search for mr. hyde" in title for title in titles)
    else:
        assert titles[0].startswith("part i.")
        assert not any(title == "part v. alexandra" for title in titles)


def test_live_standard_ebooks_dracula_has_semantic_chapters_and_clean_subtitle():
    url = "https://standardebooks.org/ebooks/bram-stoker/dracula/text/single-page"
    document = _fetch_bounded_document(url, max_bytes=12 * 1024 * 1024)
    chapters = parse_single_page_chapters(document, "bram-stoker/dracula")

    assert len(chapters) >= 20
    assert chapters[0].title == "I: Jonathan Harker’s Journal (Kept in shorthand.)"
    assert chapters[0].content
    assert not chapters[0].content.startswith("I\n")


def test_live_standard_ebooks_crime_and_punishment_omits_duplicate_roman_heading():
    book_id = "fyodor-dostoevsky/crime-and-punishment/constance-garnett"
    url = f"https://standardebooks.org/ebooks/{book_id}/text/single-page"
    document = _fetch_bounded_document(url, max_bytes=12 * 1024 * 1024)
    chapters = parse_single_page_chapters(document, book_id)

    assert len(chapters) >= 20
    assert chapters[0].title == "Part I — I"
    assert chapters[0].content.startswith("On an exceptionally hot evening")
    assert not chapters[0].content.startswith("I\n")
