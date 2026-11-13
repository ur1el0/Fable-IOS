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


def test_gutenberg_fiction_browse_prefers_english_classic_novels_over_recent_shorts():
    from services import gutenberg

    entries = [
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=79931,
            title="Recent Short Story",
            authors="Author, Recent",
            subjects="Fiction; Short stories",
            bookshelves="",
            language="en",
        ),
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=45,
            title="Anne of Green Gables",
            authors="Montgomery, L. M.",
            subjects="Fiction",
            bookshelves="Category: Novels",
            language="en",
        ),
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=20,
            title="Roman Historique",
            authors="Auteur, Autre",
            subjects="Fiction",
            bookshelves="Category: Novels",
            language="fr",
        ),
    ]

    ranked = gutenberg._search_gutenberg_catalog(entries, {"topic": "fiction"})
    assert [entry.gutenberg_id for entry in ranked] == [45, 79931, 20]


def test_standard_ebooks_xhtml_parsers_handle_chapters_parts_and_anthologies():
    from services import standard_ebooks

    listing_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <main>
          <ol>
            <li typeof="schema:Book" about="/ebooks/bram-stoker/dracula">
              <p><a href="/ebooks/bram-stoker/dracula" property="schema:name">Dracula</a></p>
              <p property="schema:author" typeof="schema:Person"><span property="schema:name">Bram Stoker</span></p>
              <img src="/images/covers/bram-stoker_dracula/abc/cover@2x.jpg" alt="Cover"/>
            </li>
          </ol>
        </main>
      </body>
    </html>"""
    cards = standard_ebooks.parse_listing_xhtml(listing_xml)
    assert len(cards) == 1
    assert cards[0]["slug"] == "bram-stoker/dracula"
    assert cards[0]["cover_url"] == "https://standardebooks.org/images/covers/bram-stoker_dracula/abc/cover@2x.jpg"

    detail_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <section id="description" property="schema:description">
          <p>Jonathan Harker travels to Transylvania.</p>
        </section>
        <p>161,105 words (9 hours 46 minutes) with a reading ease of 77.57 (fairly easy).</p>
        <ul class="tags">
          <li><a href="/subjects/fiction">Fiction</a></li>
          <li><a href="/subjects/horror">Horror</a></li>
        </ul>
      </body>
    </html>"""
    synopsis, genre, minutes = standard_ebooks.parse_book_detail_xhtml(detail_xml, "Dracula")
    assert "Transylvania" in synopsis
    assert genre == "Horror"
    assert minutes > 500

    single_page_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <body>
        <main>
          <section id="titlepage" epub:type="frontmatter titlepage"><p>Skip me</p></section>
          <section id="part-1" epub:type="bodymatter part">
            <h2>Part I</h2>
            <section id="chapter-1-1" epub:type="bodymatter chapter">
              <header><h3>I</h3><p epub:type="se:bridgehead">Harker's Journal</p></header>
              <p>Left Munich at dusk.<a href="#n1" epub:type="noteref">1</a></p>
              <p>Crossed the Carpathian pass.</p>
            </section>
          </section>
          <article id="story-2" epub:type="bodymatter se:short-story">
            <h2>A Scandal in Bohemia</h2>
            <section id="s-1"><p>To Sherlock Holmes she is always the woman.</p></section>
            <section id="s-2"><p>I had seen little of Holmes lately.</p></section>
          </article>
          <section id="colophon" epub:type="backmatter colophon"><p>Colophon skip me</p></section>
        </main>
      </body>
    </html>"""
    chapters = standard_ebooks.parse_single_page_chapters(single_page_xml, "bram-stoker/dracula")
    assert len(chapters) == 2
    assert chapters[0].title == "Part I — I: Harker's Journal"
    assert chapters[0].content == "Left Munich at dusk.\n\nCrossed the Carpathian pass."
    assert chapters[1].title == "A Scandal in Bohemia"
    assert "To Sherlock Holmes she is always the woman." in chapters[1].content
    assert "I had seen little of Holmes lately." in chapters[1].content


def test_gutenberg_cleans_marc_title_and_deduplicates_editions():
    from services import gutenberg

    assert gutenberg._clean_gutenberg_title("Peter Pan : $b [Peter and Wendy]") == "Peter Pan: [Peter and Wendy]"

    entries = [
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=42,
            title="Dr. Jekyll and Mr. Hyde",
            authors="Stevenson, Robert Louis",
            subjects="Fiction; Horror",
            bookshelves="Gothic Fiction",
            language="en",
        ),
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=43,
            title="Dr. Jekyll and Mr. Hyde : $b Large Print",
            authors="Stevenson, Robert Louis",
            subjects="Fiction; Horror",
            bookshelves="Gothic Fiction",
            language="en",
        ),
        gutenberg.GutenbergCatalogEntry(
            gutenberg_id=4300,
            title="Dr. Jekyll and Mr. Hyde",
            authors="Stevenson, Robert Louis",
            subjects="Fiction; Horror",
            bookshelves="",
            language="en",
        ),
    ]
    ranked = gutenberg._search_gutenberg_catalog(entries, {"topic": "fiction"})
    assert [entry.gutenberg_id for entry in ranked] == [42, 43]


def test_standard_ebooks_cleans_heading_punctuation_and_omits_duplicate_roman():
    from services import standard_ebooks

    xml_doc = """<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <body>
        <main>
          <section id="part-1" epub:type="bodymatter part">
            <h2>Part I</h2>
            <section id="chapter-1-1" epub:type="chapter">
              <h3>I</h3>
              <p>Raskolnikov\u2060 stepped into the summer street.</p>
            </section>
          </section>
          <section id="chapter-2" epub:type="bodymatter chapter">
            <header><h2>I</h2><p epub:type="se:bridgehead">Harker's Journal.</p><p epub:type="subtitle">(Kept in shorthand.)</p></header>
            <p>Arrived at Bistritz before nightfall.</p>
          </section>
        </main>
      </body>
    </html>""".encode("utf-8")
    chapters = standard_ebooks.parse_single_page_chapters(xml_doc, "fyodor-dostoevsky/crime-and-punishment")
    assert len(chapters) == 2
    assert chapters[0].title == "Part I — I"
    assert chapters[0].content == "Raskolnikov stepped into the summer street."
    assert chapters[1].title == "I: Harker's Journal: (Kept in shorthand.)"
