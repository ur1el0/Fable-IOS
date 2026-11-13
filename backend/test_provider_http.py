import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = Path(__file__).resolve().parent
for directory in (str(REPO_ROOT), str(BACKEND_DIR)):
    if directory not in sys.path:
        sys.path.insert(0, directory)

os.environ["FABLE_DB_PATH"] = "test_fable.sqlite3"
os.environ["FABLE_ENV"] = "test"
os.environ["FABLE_RATE_LIMIT_ENABLED"] = "false"
from main import app, init_db

@pytest.fixture(autouse=True)
def setup_teardown_provider_http_db():
    db_path = Path("test_fable.sqlite3")
    db_path.unlink(missing_ok=True)
    init_db()
    yield
    db_path.unlink(missing_ok=True)

client = TestClient(app)


def test_top_authors_http_endpoint_returns_catalog_authors_and_real_work_counts(monkeypatch, tmp_path):
    from contextlib import asynccontextmanager
    import csv
    import gzip
    import io
    import httpx
    from services import gutenberg

    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(
        buffer,
        fieldnames=["Text#", "Type", "Title", "Language", "Authors", "Subjects", "Bookshelves"],
    )
    writer.writeheader()
    for gutenberg_id, title, author in (
        (1342, "Pride and Prejudice", "Austen, Jane, 1775-1817"),
        (161, "Sense and Sensibility", "Austen, Jane, 1775-1817"),
        (345, "Dracula", "Stoker, Bram, 1847-1912"),
    ):
        writer.writerow({
            "Text#": gutenberg_id,
            "Type": "Text",
            "Title": title,
            "Language": "en",
            "Authors": author,
            "Subjects": "Fiction",
            "Bookshelves": "",
        })
    snapshot = gzip.compress(buffer.getvalue().encode("utf-8"))

    @asynccontextmanager
    async def mock_stream(self, method, url, headers=None, **kwargs):
        assert method == "GET"
        assert str(url) == gutenberg.GUTENBERG_CATALOG_URL
        yield httpx.Response(
            200,
            content=snapshot,
            headers={"content-length": str(len(snapshot))},
        )

    async def unexpected_get(self, url, params=None, headers=None, **kwargs):
        raise AssertionError(f"Unexpected non-catalog provider request: {url}")

    monkeypatch.setattr(gutenberg, "_GUTENBERG_CATALOG_CACHE", None)
    monkeypatch.setattr(gutenberg, "_GUTENBERG_CATALOG_STALE_CACHE", None)
    monkeypatch.setattr(gutenberg, "_GUTENBERG_CATALOG_LAST_REFRESH_ATTEMPT", 0.0)
    monkeypatch.setattr(gutenberg, "_gutenberg_catalog_cache_path", lambda: tmp_path / "catalog.csv.gz")
    monkeypatch.setattr(httpx.AsyncClient, "stream", mock_stream)
    monkeypatch.setattr(httpx.AsyncClient, "get", unexpected_get)
    response = client.get("/api/v1/authors/top")

    assert response.status_code == 200
    writers = response.json()
    assert {writer["name"]: writer["storyCount"] for writer in writers} == {
        "Jane Austen": 2,
        "Bram Stoker": 1,
    }
    assert all(writer["avatarImageUrl"] is None for writer in writers)


def test_gutenberg_book_detail_http_endpoint_uses_official_rdf_metadata(monkeypatch):
    import httpx

    gutenberg_id = 1342
    rdf = f'''<?xml version="1.0"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/terms/"
             xmlns:pg="http://www.gutenberg.org/2009/pgterms/">
      <pg:ebook rdf:about="ebooks/{gutenberg_id}">
        <dc:title>Pride and Prejudice</dc:title>
        <dc:creator><pg:agent><pg:name>Austen, Jane</pg:name></pg:agent></dc:creator>
        <pg:downloads>12345</pg:downloads>
        <dc:subject><rdf:Description><rdf:value>Fiction</rdf:value></rdf:Description></dc:subject>
        <dc:hasFormat>
          <pg:file rdf:about="https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8">
            <dc:format><rdf:Description><rdf:value>text/plain; charset=utf-8</rdf:value></rdf:Description></dc:format>
          </pg:file>
        </dc:hasFormat>
        <dc:hasFormat>
          <pg:file rdf:about="https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.cover.medium.jpg">
            <dc:format><rdf:Description><rdf:value>image/jpeg</rdf:value></rdf:Description></dc:format>
          </pg:file>
        </dc:hasFormat>
      </pg:ebook>
    </rdf:RDF>'''

    async def mock_get(self, url, params=None, headers=None):
        if "gutendex.com" in str(url):
            raise AssertionError("A valid official Gutenberg RDF record should not need a secondary catalog")
        assert str(url).endswith(f"/cache/epub/{gutenberg_id}/pg{gutenberg_id}.rdf")
        return httpx.Response(200, text=rdf)

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    response = client.get(f"/api/v1/public/gutenberg/{gutenberg_id}")

    assert response.status_code == 200
    book = response.json()
    assert book["title"] == "Pride and Prejudice"
    assert book["author"] == "Jane Austen"
    assert book["providerId"] == str(gutenberg_id)
    assert book["sourceProvider"] == "GUTENBERG"
    assert book["coverImageUrl"].endswith("pg1342.cover.medium.jpg")
    assert book["providerDownloadCount"] == 12345
    assert book["content"] == ""

def test_gutenberg_empty_search_is_a_successful_empty_http_response(monkeypatch):
    from services import gutenberg

    async def no_matches(_client, params):
        assert params == {"search": "No Such Book"}
        return []

    monkeypatch.setattr(gutenberg, "_fetch_gutenberg_catalog_books", no_matches)
    response = client.get("/api/v1/public/gutenberg?search=No%20Such%20Book")

    assert response.status_code == 200
    assert response.json() == []



def test_gutenberg_chapters_http_endpoint_falls_back_and_returns_provider_text(monkeypatch):
    from contextlib import asynccontextmanager
    import httpx
    from collections import OrderedDict
    from services import gutenberg

    gutenberg_id = 271828
    requested_urls = []
    monkeypatch.setattr(gutenberg, "_GUTENBERG_CHAPTER_CACHE", OrderedDict())
    source_text = """
*** START OF THE PROJECT GUTENBERG EBOOK HTTP TEST ***

CHAPTER I. THE OPENING
The chapter text fetched through the HTTP route is returned to readers in the app.

CHAPTER II. THE NEXT PART
The second chapter is also fetched from the provider and serialized in order.
*** END OF THE PROJECT GUTENBERG EBOOK HTTP TEST ***
"""

    @asynccontextmanager
    async def provider_stream(self, method, url, headers=None, **kwargs):
        requested_urls.append(str(url))
        if str(url).endswith(f"/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt"):
            raise httpx.ConnectError("primary Gutenberg text URL unavailable")
        assert str(url).endswith(f"/ebooks/{gutenberg_id}.txt.utf-8")
        yield httpx.Response(200, text=source_text)

    monkeypatch.setattr(httpx.AsyncClient, "stream", provider_stream)
    response = client.get(f"/api/v1/public/gutenberg/{gutenberg_id}/chapters")

    assert response.status_code == 200
    chapters = response.json()
    assert len(chapters) == 2
    assert [chapter["chapterNumber"] for chapter in chapters] == [1, 2]
    assert chapters[0]["title"] == "CHAPTER I. THE OPENING"
    assert "fetched through the HTTP route" in chapters[0]["content"]
    assert "fetched from the provider" in chapters[1]["content"]
    assert requested_urls == [
        f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt",
        f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8",
    ]

def test_gutenberg_chapters_http_endpoint_falls_back_after_upstream_503(monkeypatch):
    from contextlib import asynccontextmanager
    from collections import OrderedDict
    import httpx
    from services import gutenberg

    gutenberg_id = 271829
    requested_urls = []
    monkeypatch.setattr(gutenberg, "_GUTENBERG_CHAPTER_CACHE", OrderedDict())
    source_text = """
*** START OF THE PROJECT GUTENBERG EBOOK STATUS FALLBACK ***

CHAPTER I. THE RESULT
This chapter is delivered by the alternate official Gutenberg endpoint after an upstream error.
*** END OF THE PROJECT GUTENBERG EBOOK STATUS FALLBACK ***
"""

    @asynccontextmanager
    async def provider_stream(self, method, url, headers=None, **kwargs):
        requested_urls.append(str(url))
        if len(requested_urls) == 1:
            yield httpx.Response(503, text="temporary provider error")
            return
        yield httpx.Response(200, text=source_text)

    monkeypatch.setattr(httpx.AsyncClient, "stream", provider_stream)
    response = client.get(f"/api/v1/public/gutenberg/{gutenberg_id}/chapters")

    assert response.status_code == 200
    chapters = response.json()
    assert len(chapters) == 1
    assert chapters[0]["chapterNumber"] == 1
    assert "alternate official Gutenberg endpoint" in chapters[0]["content"]
    assert requested_urls[0].endswith(f"/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt")
    assert requested_urls[1].endswith(f"/ebooks/{gutenberg_id}.txt.utf-8")

def test_gutenberg_chapters_http_endpoint_sanitizes_failure_after_all_sources_fail(monkeypatch):
    from contextlib import asynccontextmanager
    from collections import OrderedDict
    import httpx
    from services import gutenberg

    gutenberg_id = 271830
    monkeypatch.setattr(gutenberg, "_GUTENBERG_CHAPTER_CACHE", OrderedDict())

    @asynccontextmanager
    async def unavailable_stream(self, method, url, headers=None, **kwargs):
        if str(url).endswith(f"/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt"):
            raise httpx.ConnectError("private primary transport detail")
        raise httpx.ReadTimeout("private fallback transport detail")
        yield  # Keep this an async context manager while both attempts fail.

    monkeypatch.setattr(httpx.AsyncClient, "stream", unavailable_stream)
    response = client.get(f"/api/v1/public/gutenberg/{gutenberg_id}/chapters")

    assert response.status_code == 502
    assert response.json()["detail"] == "Gutenberg text service is unavailable"
    assert "private primary transport detail" not in response.text
    assert "private fallback transport detail" not in response.text


def test_standard_ebooks_http_endpoints_return_catalog_and_chapters(monkeypatch):
    from contextlib import asynccontextmanager
    import httpx
    from services import standard_ebooks

    monkeypatch.setattr(standard_ebooks, "_STANDARD_EBOOKS_CATALOG_CACHE", {})
    monkeypatch.setattr(standard_ebooks, "_STANDARD_EBOOKS_DETAIL_CACHE", {})
    monkeypatch.setattr(standard_ebooks, "_STANDARD_EBOOKS_CHAPTER_CACHE", {})

    listing_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body><main><ol>
        <li typeof="schema:Book" about="/ebooks/mary-shelley/frankenstein">
          <a href="/ebooks/mary-shelley/frankenstein" property="schema:name">Frankenstein</a>
          <p property="schema:author"><span property="schema:name">Mary Shelley</span></p>
          <img src="/images/covers/mary-shelley_frankenstein/hash/cover@2x.jpg" alt="Cover"/>
        </li>
      </ol></main></body>
    </html>"""

    detail_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <div property="schema:description"><p>Victor Frankenstein assembles a creature.</p></div>
        <ul class="tags"><li><a href="/subjects/horror">Horror</a></li></ul>
      </body>
    </html>"""

    single_page_xml = b"""<?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <body><main>
        <section id="letter-1" epub:type="bodymatter z3998:letter">
          <h2>Letter I</h2>
          <p>To Mrs. Saville, England. You will rejoice to hear that no disaster has accompanied me.</p>
        </section>
        <section id="chapter-1" epub:type="bodymatter chapter">
          <h2>Chapter I</h2>
          <p>I am by birth a Genevese, and my family is one of the most distinguished of that republic.</p>
        </section>
      </main></body>
    </html>"""

    async def mock_get(self, url, params=None, headers=None, **kwargs):
        url_str = str(url)
        if url_str.endswith("/subjects/fiction?sort=popularity&page=1&per-page=12"):
            return httpx.Response(200, content=listing_xml)
        if url_str.endswith("/ebooks/mary-shelley/frankenstein"):
            return httpx.Response(200, content=detail_xml)
        return httpx.Response(404, content=b"")

    @asynccontextmanager
    async def mock_stream(self, method, url, headers=None, **kwargs):
        if str(url).endswith("/ebooks/mary-shelley/frankenstein/text/single-page"):
            yield httpx.Response(200, content=single_page_xml)
        else:
            yield httpx.Response(404, content=b"")

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    monkeypatch.setattr(httpx.AsyncClient, "stream", mock_stream)

    catalog_resp = client.get("/api/v1/public/standard-ebooks?topic=fiction")
    assert catalog_resp.status_code == 200
    stories = catalog_resp.json()
    assert len(stories) == 1
    assert stories[0]["sourceProvider"] == "STANDARD_EBOOKS"
    assert stories[0]["providerId"] == "mary-shelley/frankenstein"
    assert stories[0]["genre"] == "Horror"

    chapters_resp = client.get(
        "/api/v1/public/standard-ebooks/chapters",
        params={"book_id": "mary-shelley/frankenstein"},
    )
    assert chapters_resp.status_code == 200
    chapters = chapters_resp.json()
    assert [c["title"] for c in chapters] == ["Letter I", "Chapter I"]

    bad_resp = client.get(
        "/api/v1/public/standard-ebooks/chapters",
        params={"book_id": "../etc/passwd"},
    )
    assert bad_resp.status_code == 400
