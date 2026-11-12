import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = Path(__file__).resolve().parent
for directory in (str(REPO_ROOT), str(BACKEND_DIR)):
    if directory not in sys.path:
        sys.path.insert(0, directory)


@pytest.mark.anyio
async def test_featured_gutenberg_catalog_uses_fast_metadata_without_preloading_text(monkeypatch):
    from services import gutenberg

    async def unexpected_gutendex_call(_client, _params):
        raise AssertionError("The featured catalog should use Gutenberg RDF metadata directly")

    async def rdf_metadata(_client, book_id):
        return {
            "id": book_id,
            "title": f"Featured Book {book_id}",
            "authors": [{"name": "Author, Jane"}],
            "subjects": ["Fiction"],
            "summaries": [],
            "download_count": 100,
            "formats": {
                "image/jpeg": f"https://www.gutenberg.org/cache/epub/{book_id}/cover.jpg",
                "text/plain; charset=utf-8": f"https://www.gutenberg.org/ebooks/{book_id}.txt.utf-8",
            },
        }

    monkeypatch.setattr(gutenberg, "_fetch_gutendex_books", unexpected_gutendex_call)
    monkeypatch.setattr(gutenberg, "_fetch_gutenberg_rdf_book", rdf_metadata)
    stories = await gutenberg.get_gutenberg_stories(topic="fiction")

    assert [int(story.provider_id) for story in stories] == list(gutenberg.FEATURED_GUTENBERG_IDS)
    assert all(story.cover_image_url.startswith("https://www.gutenberg.org/") for story in stories)
    assert all(story.content == "" and story.chapters is None for story in stories)
