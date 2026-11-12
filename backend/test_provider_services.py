import sys
from pathlib import Path
from uuid import uuid5

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = Path(__file__).resolve().parent
for directory in (str(REPO_ROOT), str(BACKEND_DIR)):
    if directory not in sys.path:
        sys.path.insert(0, directory)


@pytest.mark.anyio
async def test_gutenberg_catalog_uses_dynamic_provider_results_without_preloading_text(monkeypatch):
    from services import gutenberg

    requested_params = []
    book = {
        "id": 424242,
        "title": "A Provider Catalog Book",
        "authors": [{"name": "Example, Author"}],
        "subjects": ["Historical fiction"],
        "summaries": ["Provider supplied synopsis."],
        "download_count": 731,
        "formats": {
            "image/jpeg": "https://www.gutenberg.org/cache/epub/424242/cover.jpg",
            "text/plain; charset=utf-8": "https://www.gutenberg.org/ebooks/424242.txt.utf-8",
        },
    }

    async def catalog_results(_client, params):
        requested_params.append(params)
        return [book]

    async def unexpected_gutendex_call(_client, _params):
        raise AssertionError("Gutendex should only be used when the official catalog is unavailable")

    monkeypatch.setattr(gutenberg, "_fetch_gutenberg_catalog_books", catalog_results)
    monkeypatch.setattr(gutenberg, "_fetch_gutendex_books", unexpected_gutendex_call)
    stories = await gutenberg.get_gutenberg_stories(topic="fiction")

    assert requested_params == [{"topic": "fiction"}]
    assert len(stories) == 1
    assert stories[0].provider_id == "424242"
    assert stories[0].title == "A Provider Catalog Book"
    assert stories[0].author == "Author Example"
    assert stories[0].genre == "Historical fiction"
    assert stories[0].provider_download_count == 731
    assert stories[0].content == ""
    assert stories[0].chapters is None


@pytest.mark.anyio
async def test_gutenberg_author_search_matches_provider_display_names(monkeypatch):
    from services import gutenberg

    entries = [
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=1342,
            title="Pride and Prejudice",
            authors="Austen, Jane, 1775-1817",
            subjects="Fiction",
            bookshelves="",
            language="en",
        )
    ]

    assert [entry.gutenberg_id for entry in gutenberg._search_gutenberg_catalog(
        entries, {"search": "Jane Austen"}
    )] == [1342]


@pytest.mark.anyio
async def test_gutenberg_authors_and_work_counts_come_from_catalog_entries(monkeypatch):
    from services import gutenberg

    entries = [
        gutenberg.GutenbergCatalogEntry(1342, "Pride and Prejudice", "Austen, Jane, 1775-1817", "Fiction", "", "en"),
        gutenberg.GutenbergCatalogEntry(161, "Sense and Sensibility", "Austen, Jane, 1775-1817", "Fiction", "", "en"),
        gutenberg.GutenbergCatalogEntry(345, "Dracula", "Stoker, Bram, 1847-1912", "Fiction", "", "en"),
    ]

    async def catalog_snapshot(_client):
        return entries

    monkeypatch.setattr(gutenberg, "_load_gutenberg_catalog", catalog_snapshot)
    authors = await gutenberg.get_gutenberg_authors(limit=2)

    assert [(author.name, author.story_count) for author in authors] == [
        ("Jane Austen", 2),
        ("Bram Stoker", 1),
    ]
    assert authors[0].id == uuid5(gutenberg.GUTENBERG_AUTHOR_NAMESPACE, "jane austen")


@pytest.mark.anyio
async def test_top_authors_do_not_use_non_gutenberg_fallback_data(monkeypatch):
    from fastapi import HTTPException
    from services import gutenberg, story_service

    async def unavailable_catalog():
        raise HTTPException(status_code=502, detail="Gutenberg unavailable")

    monkeypatch.setattr(gutenberg, "get_gutenberg_authors", unavailable_catalog)

    assert await story_service.get_top_authors() == []
