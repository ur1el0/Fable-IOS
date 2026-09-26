import os
import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from fastapi.testclient import TestClient

# Ensure test uses a separate test database
os.environ["FABLE_DB_PATH"] = "test_fable.sqlite3"
from main import app, init_db

@pytest.fixture(autouse=True)
def setup_teardown_db():
    if os.path.exists("test_fable.sqlite3"):
        os.remove("test_fable.sqlite3")
    init_db()
    yield
    if os.path.exists("test_fable.sqlite3"):
        os.remove("test_fable.sqlite3")

client = TestClient(app)


def auth_headers(name="Test Author"):
    response = client.post("/api/v1/auth/register", json={
        "email": f"{uuid4()}@example.test",
        "password": "secure-password",
        "name": name,
        "handle": name.lower().replace(" ", "")
    })
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['accessToken']}"}

def test_health_check():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"

def test_get_stories_starts_without_embedded_catalog():
    response = client.get("/api/v1/stories")
    assert response.status_code == 200
    assert response.json() == []
    init_db()
    assert client.get("/api/v1/stories").json() == []


def test_story_creation_requires_auth_and_server_owned_author():
    payload = {
        "title": "Owned Story",
        "genre": "Mystery",
        "synopsis": "A server-owned author record.",
        "content": "Story content."
    }
    unauthorized = client.post("/api/v1/stories", json=payload)
    assert unauthorized.status_code == 401

    headers = auth_headers("Verified Writer")
    spoofed = client.post(
        "/api/v1/stories",
        headers=headers,
        json={**payload, "author": "Impersonated Writer"},
    )
    assert spoofed.status_code == 422

    created = client.post("/api/v1/stories", headers=headers, json=payload)
    assert created.status_code == 201
    assert created.json()["author"] == "Verified Writer"


def test_authenticated_story_listing_is_isolated_by_owner():
    first_headers = auth_headers("First Writer")
    second_headers = auth_headers("Second Writer")
    for headers, title in ((first_headers, "First Story"), (second_headers, "Second Story")):
        response = client.post("/api/v1/stories", headers=headers, json={
            "title": title,
            "genre": "Fantasy",
            "synopsis": "An owned story.",
            "content": "Story content."
        })
        assert response.status_code == 201

    first_stories = client.get("/api/v1/auth/me/stories", headers=first_headers)
    second_stories = client.get("/api/v1/auth/me/stories", headers=second_headers)
    assert [story["title"] for story in first_stories.json()] == ["First Story"]
    assert [story["title"] for story in second_stories.json()] == ["Second Story"]
    assert client.get("/api/v1/auth/me/stories").status_code == 401

def test_story_dto_camelcase_serialization_contract():
    response = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Contract Story",
        "genre": "Gothic",
        "synopsis": "A synopsis from the writer.",
        "content": "The actual authored text.",
        "readTimeMinutes": 4
    })
    assert response.status_code == 201
    story = response.json()
    assert "readTimeMinutes" in story
    assert story["isBookmarked"] is False
    assert story["isCompleted"] is False
    assert "createdAtUtc" in story
    assert "updatedAtUtc" in story
    assert "totalChapters" in story
    assert "providerId" in story
    assert "providerDownloadCount" in story
    assert story["rating"] is None
    assert story["savesCount"] == "0"
    assert story["readsCount"] == "0"
    assert story["coverImageName"] is None
    assert story["heroImageName"] is None


def test_get_story_chapters():
    created = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Reader Contract",
        "genre": "Gothic",
        "chapter": "Chapter One",
        "synopsis": "A test synopsis.",
        "content": "Text created through the validated story API.",
        "readTimeMinutes": 3
    })
    assert created.status_code == 201
    story_id = created.json()["id"]

    detail = client.get(f"/api/v1/stories/{story_id}")
    assert detail.status_code == 200
    assert len(detail.json()["chapters"]) == 1

    chapters = client.get(f"/api/v1/stories/{story_id}/chapters")
    assert chapters.status_code == 200
    assert len(chapters.json()) == 1

    chapter = client.get(f"/api/v1/stories/{story_id}/chapters/1")
    assert chapter.status_code == 200
    assert chapter.json()["chapterNumber"] == 1
    assert "validated story API" in chapter.json()["content"]


def test_story_metrics_are_derived_from_device_shelf_state():
    created = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Metrics Story",
        "genre": "Mystery",
        "synopsis": "",
        "content": "Reader-created text.",
        "readTimeMinutes": 1
    })
    story_id = created.json()["id"]
    initial = client.get("/api/v1/stories").json()[0]
    assert initial["savesCount"] == "0"
    assert initial["readsCount"] == "0"

    sync = client.post("/api/v1/shelf/sync", headers=auth_headers(), json={
        "deviceId": "11111111-1111-1111-1111-111111111111",
        "items": [{
            "storyId": story_id,
            "readingProgress": 0.25,
            "isBookmarked": True,
            "isCompleted": False,
            "updatedAtUtc": datetime.now(timezone.utc).isoformat()
        }]
    })
    assert sync.status_code == 200
    updated = client.get("/api/v1/stories").json()[0]
    assert updated["savesCount"] == "1"
    assert updated["readsCount"] == "1"


def test_extract_chapters_from_text():
    from main import extract_chapters_from_text
    raw_sample = """
*** START OF THE PROJECT GUTENBERG EBOOK SAMPLE ***

PREFACE
Some preamble here.

CHAPTER I. THE BEGINNING
It was a dark and stormy night. The wind howled through the ancient eaves with terrifying ferocity, shaking the foundations of the ancestral manor.

CHAPTER II. THE RETURN
The morning brought no relief. The fog clung tightly to the moors, concealing what lay beneath.

*** END OF THE PROJECT GUTENBERG EBOOK SAMPLE ***
"""
    chapters = extract_chapters_from_text(raw_sample)
    assert len(chapters) == 2
    assert chapters[0]["chapter_number"] == 1
    assert "CHAPTER I" in chapters[0]["title"]
    assert "dark and stormy" in chapters[0]["content"]
    assert chapters[1]["chapter_number"] == 2
    assert "CHAPTER II" in chapters[1]["title"]

def test_get_genres_endpoint():
    created = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Genre Count Story",
        "genre": "Gothic",
        "synopsis": "",
        "content": "A story.",
        "readTimeMinutes": 1
    })
    assert created.status_code == 201
    response = client.get("/api/v1/genres")
    assert response.status_code == 200
    genres = response.json()
    assert len(genres) == 1
    gothic = genres[0]
    assert gothic["name"] == "Gothic"
    assert gothic["storyCount"] == 1
    assert gothic["readersCount"] == "0"
    assert gothic["description"] == ""
    assert gothic["imageName"] == ""
    assert gothic["imageUrl"] is None


def test_get_top_authors_endpoint(monkeypatch):
    import httpx

    async def mock_get(self, url, params=None, headers=None):
        if url.endswith("/trending/daily.json"):
            return httpx.Response(200, json={
                "works": [{"author_name": ["Bram Stoker"]}]
            })
        return httpx.Response(200, json={
            "docs": [{
                "key": "OL123A",
                "name": "Bram Stoker",
                "work_count": 35
            }]
        })

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    response = client.get("/api/v1/authors/top")
    assert response.status_code == 200
    writers = response.json()
    assert len(writers) == 1
    assert writers[0]["name"] == "Bram Stoker"
    assert writers[0]["storyCount"] == 35
    assert writers[0]["avatarImageName"] == ""
    assert writers[0]["avatarImageUrl"] == "https://covers.openlibrary.org/a/olid/OL123A-M.jpg?default=false"
    assert writers[0]["rating"] is None


def test_gutenberg_cover_and_download_count_are_live(monkeypatch):
    import httpx

    async def mock_get(self, url, params=None, headers=None):
        return httpx.Response(200, json={
            "results": [{
                "id": 38269,
                "title": "The Legend of Maria Makiling",
                "authors": [{"name": "Rizal, Jose"}],
                "subjects": ["Folklore"],
                "summaries": ["Provider synopsis"],
                "download_count": 281,
                "formats": {
                    "image/jpeg": "https://www.gutenberg.org/cache/epub/38269/pg38269.cover.medium.jpg"
                }
            }]
        })

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    response = client.get("/api/v1/public/gutenberg?search=Maria")
    assert response.status_code == 200
    story = response.json()[0]
    assert story["providerId"] == "38269"
    assert story["coverImageUrl"] == "https://www.gutenberg.org/cache/epub/38269/pg38269.cover.medium.jpg"
    assert story["providerDownloadCount"] == 281
    assert story["content"] == ""
    assert story["rating"] is None


def test_get_update_feed_endpoint():
    response = client.get("/api/v1/updates")
    assert response.status_code == 200
    feed = response.json()
    assert feed["taleOfTheDay"] is None
    assert feed["curatorSpotlight"] is None
    assert feed["recentSubmissions"] == []
    assert feed["totalStories"] == 0


def test_create_story():
    payload = {
        "title": "The Obsidian Tower",
        "genre": "Gothic",
        "chapter": "Chapter I",
        "synopsis": "A secluded fortress by the misty mere.",
        "content": "A secluded fortress by the misty mere stood solitary in the gloaming.",
        "read_time_minutes": 5
    }
    response = client.post("/api/v1/stories", headers=auth_headers("Verified Author"), json=payload)
    assert response.status_code == 201
    created = response.json()
    assert created["title"] == payload["title"]
    assert created["author"] == "Verified Author"

def test_last_write_wins_resolution():
    story_id = str(uuid4())
    device_id = str(uuid4())
    now = datetime.now(timezone.utc)
    older_time = (now - timedelta(minutes=10)).isoformat()
    newer_time = (now + timedelta(minutes=5)).isoformat()
    
    # 1. Initial client sync
    initial_sync = {
        "deviceId": device_id,
        "items": [
            {
                "storyId": story_id,
                "readingProgress": 0.4,
                "isBookmarked": True,
                "isCompleted": False,
                "updatedAtUtc": now.isoformat()
            }
        ]
    }
    headers = auth_headers()
    res1 = client.post("/api/v1/shelf/sync", headers=headers, json=initial_sync)
    assert res1.status_code == 200
    reconciled = res1.json()["reconciledItems"]
    assert len(reconciled) == 1
    assert reconciled[0]["readingProgress"] == 0.4

    # 2. Second client sync with OLDER timestamp -> Server should reject client progress and preserve server's 0.4
    stale_sync = {
        "deviceId": device_id,
        "items": [
            {
                "storyId": story_id,
                "readingProgress": 0.1,
                "isBookmarked": False,
                "isCompleted": False,
                "updatedAtUtc": older_time
            }
        ]
    }
    res2 = client.post("/api/v1/shelf/sync", headers=headers, json=stale_sync)
    assert res2.status_code == 200
    assert res2.json()["reconciledItems"][0]["readingProgress"] == 0.4

    # 3. Third client sync with NEWER timestamp -> Server should accept client update
    fresh_sync = {
        "deviceId": device_id,
        "items": [
            {
                "storyId": story_id,
                "readingProgress": 0.9,
                "isBookmarked": True,
                "isCompleted": False,
                "updatedAtUtc": newer_time
            }
        ]
    }
    res3 = client.post("/api/v1/shelf/sync", headers=headers, json=fresh_sync)
    assert res3.status_code == 200
    assert res3.json()["reconciledItems"][0]["readingProgress"] == 0.9

def test_multi_tenant_device_shelf_isolation():
    story_id = str(uuid4())
    device_a = str(uuid4())
    device_b = str(uuid4())
    now = datetime.now(timezone.utc)

    # Device A syncs progress 0.75
    payload_a = {
        "deviceId": device_a,
        "items": [{
            "storyId": story_id,
            "readingProgress": 0.75,
            "isBookmarked": True,
            "isCompleted": False,
            "updatedAtUtc": now.isoformat()
        }]
    }
    headers_a = auth_headers("Device A Reader")
    headers_b = auth_headers("Device B Reader")
    res_a = client.post("/api/v1/shelf/sync", headers=headers_a, json=payload_a)
    assert res_a.status_code == 200

    # Device B syncs progress 0.20 for the exact same story
    payload_b = {
        "deviceId": device_b,
        "items": [{
            "storyId": story_id,
            "readingProgress": 0.20,
            "isBookmarked": False,
            "isCompleted": False,
            "updatedAtUtc": now.isoformat()
        }]
    }
    res_b = client.post("/api/v1/shelf/sync", headers=headers_b, json=payload_b)
    assert res_b.status_code == 200

    # Query shelf for Device A via GET /api/v1/shelf
    get_a = client.get(f"/api/v1/shelf?deviceId={device_a}", headers=headers_a)
    assert get_a.status_code == 200
    items_a = get_a.json()
    assert len(items_a) == 1
    assert items_a[0]["readingProgress"] == 0.75
    assert items_a[0]["isBookmarked"] is True

    # Query shelf for Device B via GET /api/v1/shelf
    get_b = client.get(f"/api/v1/shelf?deviceId={device_b}", headers=headers_b)
    assert get_b.status_code == 200
    items_b = get_b.json()
    assert len(items_b) == 1
    assert items_b[0]["readingProgress"] == 0.20
    assert items_b[0]["isBookmarked"] is False


def test_package_modularity_imports():
    from core import get_db, init_db
    from models import Story, Chapter, ShelfItem
    from schemas import (
        StoryDTO,
        ChapterDTO,
        ShelfSyncPayload,
        UserDTO,
        ProfileUpdateRequest,
        RegisterRequest,
        LoginRequest,
        AuthResponse
    )
    from services import (
        story_service,
        shelf_sync,
        extract_chapters_from_text,
        ingest_gutenberg_book,
        get_gutenberg_stories,
        auth_service
    )
    from api.v1.api import api_router

    assert callable(get_db)
    assert callable(init_db)
    assert Story is not None
    assert Chapter is not None
    assert ShelfItem is not None
    assert StoryDTO is not None
    assert ChapterDTO is not None
    assert ShelfSyncPayload is not None
    assert UserDTO is not None
    assert ProfileUpdateRequest is not None
    assert RegisterRequest is not None
    assert LoginRequest is not None
    assert AuthResponse is not None
    assert callable(story_service.get_stories)
    assert callable(shelf_sync.sync_shelf)
    assert callable(shelf_sync.get_shelf)
    assert callable(extract_chapters_from_text)
    assert callable(ingest_gutenberg_book)
    assert callable(get_gutenberg_stories)
    assert callable(auth_service.register_user)
    assert callable(auth_service.login_user)
    assert callable(auth_service.get_current_user)
    assert api_router is not None


def test_get_gutenberg_public_stories(monkeypatch):
    import httpx

    async def mock_get(self, url, params=None, headers=None):
        return httpx.Response(200, json={
            "results": [{
                "id": 84,
                "title": "Frankenstein",
                "authors": [{"name": "Shelley, Mary"}],
                "subjects": ["Science fiction"],
                "summaries": ["Source synopsis"],
                "download_count": 940,
                "formats": {"image/jpeg": "https://www.gutenberg.org/cover.jpg"}
            }]
        })

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    response = client.get("/api/v1/public/gutenberg?topic=fiction")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["sourceProvider"] == "GUTENBERG"
    assert data[0]["providerId"] == "84"
    assert data[0]["providerDownloadCount"] == 940


def test_gutenberg_live_chapters_use_source_text_and_stable_ids(monkeypatch):
    from services import gutenberg as gutenberg_service

    source_text = """
*** START OF THE PROJECT GUTENBERG EBOOK SAMPLE ***

CHAPTER I. THE FIRST CHAPTER
This is the complete source text for the first chapter. It has enough words to be a real chapter.

CHAPTER II. THE SECOND CHAPTER
This is the complete source text for the second chapter. It also has enough words to be a real chapter.
*** END OF THE PROJECT GUTENBERG EBOOK SAMPLE ***
"""

    async def fetch_text(_gutenberg_id):
        return source_text

    monkeypatch.setattr(gutenberg_service, "_fetch_gutenberg_text", fetch_text)
    first_response = client.get("/api/v1/public/gutenberg/1342/chapters")
    second_response = client.get("/api/v1/public/gutenberg/1342/chapters")

    assert first_response.status_code == 200
    chapters = first_response.json()
    assert len(chapters) == 2
    assert chapters[0]["storyId"] == "00000000-0000-0000-0000-00000000053e"
    assert chapters[0]["chapterNumber"] == 1
    assert "complete source text" in chapters[0]["content"]
    assert second_response.status_code == 200
    assert chapters[0]["id"] == second_response.json()[0]["id"]

def test_gutenberg_ingest_uses_live_metadata_and_is_idempotent(monkeypatch):
    import httpx

    source_text = """
*** START OF THE PROJECT GUTENBERG EBOOK SAMPLE ***

CHAPTER I. THE OPENING
The complete chapter comes from the provider text and contains enough words to read.

CHAPTER II. THE CONTINUATION
A second complete chapter also comes from the provider and has sufficient text content.
*** END OF THE PROJECT GUTENBERG EBOOK SAMPLE ***
"""

    async def mock_get(self, url, params=None, headers=None):
        if "gutendex.com" in url:
            return httpx.Response(200, json={"results": [{
                "id": 99,
                "title": "Provider Book",
                "authors": [{"name": "Doe, Jane"}],
                "subjects": ["Live Genre"],
                "summaries": ["Provider summary"],
                "download_count": 73,
                "formats": {"image/jpeg": "https://www.gutenberg.org/cover.jpg"}
            }]})
        return httpx.Response(200, text=source_text)

    monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
    first = client.post("/api/v1/stories/ingest/99")
    second = client.post("/api/v1/stories/ingest/99")

    assert first.status_code == 201
    assert second.status_code == 201
    story = first.json()
    assert story["id"] == second.json()["id"]
    assert story["title"] == "Provider Book"
    assert story["author"] == "Jane Doe"
    assert story["synopsis"] == "Provider summary"
    assert story["providerId"] == "99"
    assert story["providerDownloadCount"] == 73
    assert story["totalChapters"] == 2
    assert "complete chapter comes from the provider" in story["chapters"][0]["content"]
    assert len(second.json()["chapters"]) == 2


def test_gutenberg_catalog_failure_does_not_return_local_catalog(monkeypatch):
    import httpx

    async def unavailable(self, url, params=None, headers=None):
        raise httpx.ConnectError("private transport detail")

    monkeypatch.setattr(httpx.AsyncClient, "get", unavailable)
    response = client.get("/api/v1/public/gutenberg")
    assert response.status_code == 502
    assert response.json()["detail"] == "Gutenberg catalog service is unavailable"


def test_register_and_login_auth_flow():
    reg_payload = {
        "email": "reader@example.test",
        "password": "SecurePassword123!",
        "name": "Test Reader",
        "handle": "test-reader"
    }
    # 1. Register
    reg_res = client.post("/api/v1/auth/register", json=reg_payload)
    assert reg_res.status_code == 201
    reg_data = reg_res.json()
    assert "accessToken" in reg_data
    assert reg_data["tokenType"] == "bearer"
    assert reg_data["user"]["email"] == "reader@example.test"
    assert reg_data["user"]["name"] == "Test Reader"
    assert reg_data["user"]["handle"] == "@test-reader"
    assert reg_data["user"]["bio"] == ""
    assert reg_data["user"]["avatarImageName"] is None
    token = reg_data["accessToken"]

    # 2. Get /auth/me with Bearer token
    me_res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["email"] == "reader@example.test"
    assert me_data["name"] == "Test Reader"
    assert me_data["handle"] == "@test-reader"

    # 3. Login
    login_payload = {
        "email": "reader@example.test",
        "password": "SecurePassword123!"
    }
    login_res = client.post("/api/v1/auth/login", json=login_payload)
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert "accessToken" in login_data
    assert login_data["user"]["email"] == "reader@example.test"
    assert login_data["user"]["handle"] == "@test-reader"

def test_authenticated_profile_update_and_rejection():
    response = client.post("/api/v1/auth/register", json={
        "email": "profile@example.test",
        "password": "ProfilePassword123!",
        "name": "Profile Reader",
        "handle": "reader"
    })
    token = response.json()["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    updated = client.patch("/api/v1/auth/me", headers=headers, json={
        "name": "Updated Reader",
        "handle": "updated-reader",
        "bio": "A profile saved through the authenticated API."
    })
    assert updated.status_code == 200
    assert updated.json()["name"] == "Updated Reader"
    assert updated.json()["handle"] == "@updated-reader"
    assert updated.json()["bio"] == "A profile saved through the authenticated API."

    unauthorized = client.patch("/api/v1/auth/me", json={
        "name": "Intruder",
        "handle": "intruder",
        "bio": ""
    })
    assert unauthorized.status_code == 401


def test_register_duplicate_email_conflict():
    payload = {
        "email": "duplicate@fable.app",
        "password": "Password123!",
        "name": "Original User"
    }
    res1 = client.post("/api/v1/auth/register", json=payload)
    assert res1.status_code == 201

    # Second attempt with same email
    res2 = client.post("/api/v1/auth/register", json=payload)
    assert res2.status_code == 409
    assert "already registered" in res2.json()["detail"].lower()

def test_login_invalid_password():
    payload = {
        "email": "invalid_login@fable.app",
        "password": "CorrectPassword123!",
        "name": "Test Login"
    }
    client.post("/api/v1/auth/register", json=payload)

    # Wrong password
    bad_login = {
        "email": "invalid_login@fable.app",
        "password": "WrongPassword999!"
    }
    res = client.post("/api/v1/auth/login", json=bad_login)
    assert res.status_code == 401
    assert "Invalid email or password" in res.json()["detail"]

def test_auth_me_unauthorized():
    # Missing header
    res1 = client.get("/api/v1/auth/me")
    assert res1.status_code == 401

    # Invalid token
    res2 = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer non_existent_token_12345"})
    assert res2.status_code == 401

def test_multi_format_content_and_provider_serialization():
    response = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Writer Created Graphic Story",
        "genre": "Manga",
        "chapter": "Issue One",
        "synopsis": "A writer-created graphic story.",
        "content": "",
        "readTimeMinutes": 0,
        "contentFormat": "MANGA"
    })
    assert response.status_code == 201
    story = response.json()
    assert story["contentFormat"] == "MANGA"
    assert story["sourceProvider"] == "FABLE_ORIGINAL"
    assert story["title"] == "Writer Created Graphic Story"
    assert story["coverImageUrl"] is None
    assert story["rating"] is None


def test_manga_chapter_page_urls_contract():
    created = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "Writer Created Graphic Story",
        "genre": "Manga",
        "chapter": "Issue One",
        "synopsis": "A writer-created graphic story.",
        "content": "",
        "readTimeMinutes": 0,
        "contentFormat": "MANGA"
    })
    assert created.status_code == 201
    story_id = created.json()["id"]
    response = client.get(f"/api/v1/stories/{story_id}/chapters")
    assert response.status_code == 200
    chapters = response.json()
    assert len(chapters) == 1
    assert chapters[0]["pageUrls"] == []


def test_legacy_demo_manga_images_are_not_exposed():
    from core.database import get_db

    created = client.post("/api/v1/stories", headers=auth_headers(), json={
        "title": "External Media Story",
        "genre": "Manga",
        "chapter": "Chapter 1",
        "synopsis": "",
        "content": "",
        "readTimeMinutes": 0,
        "contentFormat": "MANGA"
    })
    story_id = created.json()["id"]
    connection = get_db()
    with connection:
        connection.execute(
            "UPDATE stories SET cover_image_url = ? WHERE id = ?",
            ("https://images.unsplash.com/photo-demo.jpg", story_id),
        )
        connection.execute(
            "UPDATE chapters SET page_urls = ? WHERE story_id = ?",
            (
                '["https://images.unsplash.com/panel-demo.jpg",'
                '"https://uploads.mangadex.org/covers/demo/cover.jpg"]',
                story_id,
            ),
        )
    connection.close()

    detail = client.get(f"/api/v1/stories/{story_id}").json()
    chapters = client.get(f"/api/v1/stories/{story_id}/chapters").json()
    assert detail["coverImageUrl"] is None
    assert detail["chapters"][0]["pageUrls"] == [
        "https://uploads.mangadex.org/covers/demo/cover.jpg"
    ]
    assert chapters[0]["pageUrls"] == detail["chapters"][0]["pageUrls"]


def test_create_manga_story_via_api():
    payload = {
        "title": "Cyber Scribe Manga",
        "genre": "Manga",
        "chapter": "Issue #1",
        "synopsis": "A cyberpunk illustrator discovers a quill that draws reality.",
        "content": "",
        "readTimeMinutes": 6,
        "contentFormat": "MANGA"
    }
    res = client.post("/api/v1/stories", headers=auth_headers("Verified Author"), json=payload)
    assert res.status_code == 201
    created = res.json()
    assert created["contentFormat"] == "MANGA"
    assert created["sourceProvider"] == "FABLE_ORIGINAL"
    assert created["title"] == "Cyber Scribe Manga"

def test_internal_health_and_media_invariants(monkeypatch):
    import httpx

    async def empty_provider(self, url, params=None, headers=None):
        return httpx.Response(200, json={"works": []})

    monkeypatch.setattr(httpx.AsyncClient, "get", empty_provider)
    feed = client.get("/api/v1/updates").json()
    assert feed["totalStories"] == 0
    assert feed["taleOfTheDay"] is None
    assert feed["curatorSpotlight"] is None
    assert feed["recentSubmissions"] == []

    genres = client.get("/api/v1/genres").json()
    assert genres == []
    assert client.get("/api/v1/authors/top").json() == []


def test_env_db_path_override(tmp_path, monkeypatch):
    from core.database import get_db

    override_path = tmp_path / "override.sqlite3"
    monkeypatch.setenv("FABLE_DB_PATH", str(override_path))
    connection = get_db()
    try:
        assert override_path.exists()
        database_path = connection.execute("PRAGMA database_list").fetchone()["file"]
        assert database_path == str(override_path)
    finally:
        connection.close()


def test_shelf_sync_requires_authentication_and_isolates_accounts():
    device_id = str(uuid4())
    story_id = str(uuid4())
    payload = {
        "deviceId": device_id,
        "items": [{
            "storyId": story_id,
            "readingProgress": 0.6,
            "isBookmarked": True,
            "isCompleted": False,
            "updatedAtUtc": datetime.now(timezone.utc).isoformat()
        }]
    }
    assert client.post("/api/v1/shelf/sync", json=payload).status_code == 401
    assert client.get(f"/api/v1/shelf?deviceId={device_id}").status_code == 401

    first_user = auth_headers("First Shelf Owner")
    second_user = auth_headers("Second Shelf Owner")
    first_sync = client.post("/api/v1/shelf/sync", headers=first_user, json=payload)
    assert first_sync.status_code == 200

    first_items = client.get(f"/api/v1/shelf?deviceId={device_id}", headers=first_user)
    second_items = client.get(f"/api/v1/shelf?deviceId={device_id}", headers=second_user)
    assert len(first_items.json()) == 1
    assert second_items.json() == []


def test_reading_statistics_are_authenticated_idempotent_and_account_scoped():
    user_a = auth_headers("Reading Stats A")
    user_b = auth_headers("Reading Stats B")
    session_id = str(uuid4())
    request = {
        "id": session_id,
        "storyId": str(uuid4()),
        "secondsRead": 125,
        "readAtUtc": datetime.now(timezone.utc).isoformat(),
        "isCompleted": True,
    }

    assert client.post("/api/v1/auth/me/reading-sessions", json=request).status_code == 401
    first = client.post("/api/v1/auth/me/reading-sessions", headers=user_a, json=request)
    duplicate = client.post("/api/v1/auth/me/reading-sessions", headers=user_a, json=request)
    assert first.status_code == 204
    assert duplicate.status_code == 204

    stats_a = client.get("/api/v1/auth/me/stats", headers=user_a)
    stats_b = client.get("/api/v1/auth/me/stats", headers=user_b)
    assert stats_a.status_code == 200
    assert stats_a.json()["storiesReadCount"] == 1
    assert stats_a.json()["totalMinutesRead"] == 2
    assert stats_a.json()["streakDays"] == 1
    assert stats_b.json() == {
        "storiesReadCount": 0,
        "totalMinutesRead": 0,
        "streakDays": 0,
    }
    assert client.get("/api/v1/auth/me/stats").status_code == 401


def test_bearer_session_survives_process_cache_loss_and_logout_revokes_it():
    import importlib
    from services import auth_service

    headers = auth_headers("Persistent Session Reader")
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200

    # Authentication state is read from SQLite, not process-local memory.
    importlib.reload(auth_service)
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200

    logout = client.post("/api/v1/auth/logout", headers=headers)
    assert logout.status_code == 204
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
