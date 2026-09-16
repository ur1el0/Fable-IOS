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

def test_health_check():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"

def test_get_stories_includes_full_editorial_catalog():
    response = client.get("/api/v1/stories")
    assert response.status_code == 200
    stories = response.json()
    assert len(stories) >= 10
    titles = [s["title"] for s in stories]
    assert "Dracula" in titles
    assert "The Legend of Sleepy Hollow" in titles
    assert "The Metamorphosis" in titles
    assert "The Tell-Tale Heart" in titles
    assert "Frankenstein" in titles
    assert "The Odyssey" in titles

def test_story_dto_camelcase_serialization_contract():
    response = client.get("/api/v1/stories")
    assert response.status_code == 200
    first = response.json()[0]
    # Verify contract parity with Swift JSONDecoder
    assert "readTimeMinutes" in first
    assert "isBookmarked" in first
    assert "isCompleted" in first
    assert "createdAtUtc" in first
    assert "updatedAtUtc" in first
    assert "totalChapters" in first

def test_get_story_chapters():
    response = client.get("/api/v1/stories")
    assert response.status_code == 200
    stories = response.json()
    dracula = next(s for s in stories if s["title"] == "Dracula")
    story_id = dracula["id"]

    # Test single story with chapters
    detail_res = client.get(f"/api/v1/stories/{story_id}")
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert "chapters" in detail
    assert len(detail["chapters"]) >= 3
    assert detail["chapters"][0]["chapterNumber"] == 1
    assert "CHAPTER I" in detail["chapters"][0]["title"]

    # Test chapters endpoint
    ch_res = client.get(f"/api/v1/stories/{story_id}/chapters")
    assert ch_res.status_code == 200
    chapters = ch_res.json()
    assert len(chapters) >= 3

    # Test chapter 1 endpoint
    ch1_res = client.get(f"/api/v1/stories/{story_id}/chapters/1")
    assert ch1_res.status_code == 200
    ch1 = ch1_res.json()
    assert ch1["chapterNumber"] == 1
    assert "Bistritz" in ch1["content"]

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
    response = client.get("/api/v1/genres")
    assert response.status_code == 200
    genres = response.json()
    assert len(genres) >= 4
    names = [g["name"] for g in genres]
    assert "Folklore" in names
    assert "Gothic" in names
    # Verify contract keys matching Swift GenreCategory
    first = genres[0]
    assert "storyCount" in first
    assert "readersCount" in first
    assert "description" in first
    assert "imageName" in first

def test_get_top_authors_endpoint():
    response = client.get("/api/v1/authors/top")
    assert response.status_code == 200
    writers = response.json()
    assert len(writers) >= 1
    first = writers[0]
    assert "name" in first
    assert "storyCount" in first
    assert "avatarImageName" in first
    assert "rating" in first

def test_get_update_feed_endpoint():
    response = client.get("/api/v1/updates")
    assert response.status_code == 200
    feed = response.json()
    assert "taleOfTheDay" in feed
    assert "curatorSpotlight" in feed
    assert "recentSubmissions" in feed
    assert "totalStories" in feed
    assert feed["totalStories"] >= 10



def test_create_story():
    payload = {
        "title": "The Obsidian Tower",
        "author": "Edgar Allan Poe",
        "genre": "Gothic",
        "chapter": "Chapter I",
        "synopsis": "A secluded fortress by the misty mere.",
        "content": "A secluded fortress by the misty mere stood solitary in the gloaming.",
        "read_time_minutes": 5
    }
    response = client.post("/api/v1/stories", json=payload)
    assert response.status_code == 201
    created = response.json()
    assert created["title"] == payload["title"]
    assert created["author"] == payload["author"]

def test_last_write_wins_resolution():
    story_id = str(uuid4())
    now = datetime.now(timezone.utc)
    older_time = (now - timedelta(minutes=10)).isoformat()
    newer_time = (now + timedelta(minutes=5)).isoformat()
    
    # 1. Initial client sync
    initial_sync = {
        "device_id": str(uuid4()),
        "items": [
            {
                "story_id": story_id,
                "reading_progress": 0.4,
                "is_bookmarked": True,
                "is_completed": False,
                "updated_at_utc": now.isoformat()
            }
        ]
    }
    res1 = client.post("/api/v1/shelf/sync", json=initial_sync)
    assert res1.status_code == 200
    assert res1.json()["reconciled_items"][0]["reading_progress"] == 0.4

    # 2. Second client sync with OLDER timestamp -> Server should reject client progress and preserve server's 0.4
    stale_sync = {
        "device_id": str(uuid4()),
        "items": [
            {
                "story_id": story_id,
                "reading_progress": 0.1,
                "is_bookmarked": False,
                "is_completed": False,
                "updated_at_utc": older_time
            }
        ]
    }
    res2 = client.post("/api/v1/shelf/sync", json=stale_sync)
    assert res2.status_code == 200
    assert res2.json()["reconciled_items"][0]["reading_progress"] == 0.4

    # 3. Third client sync with NEWER timestamp -> Server should accept client update
    fresh_sync = {
        "device_id": str(uuid4()),
        "items": [
            {
                "story_id": story_id,
                "reading_progress": 0.9,
                "is_bookmarked": True,
                "is_completed": False,
                "updated_at_utc": newer_time
            }
        ]
    }
    res3 = client.post("/api/v1/shelf/sync", json=fresh_sync)
    assert res3.status_code == 200
    assert res3.json()["reconciled_items"][0]["reading_progress"] == 0.9

def test_package_modularity_imports():
    from core import get_db, init_db, SEED_STORIES
    from models import Story, Chapter, ShelfItem
    from schemas import StoryDTO, ChapterDTO, ShelfSyncPayload
    from services import (
        story_service,
        shelf_sync,
        extract_chapters_from_text,
        ingest_gutenberg_book,
        get_gutenberg_stories
    )
    from api.v1.api import api_router

    assert callable(get_db)
    assert callable(init_db)
    assert len(SEED_STORIES) >= 10
    assert Story is not None
    assert Chapter is not None
    assert ShelfItem is not None
    assert StoryDTO is not None
    assert ChapterDTO is not None
    assert ShelfSyncPayload is not None
    assert callable(story_service.get_stories)
    assert callable(shelf_sync.sync_shelf)
    assert callable(extract_chapters_from_text)
    assert callable(ingest_gutenberg_book)
    assert callable(get_gutenberg_stories)
    assert api_router is not None

def test_get_gutenberg_public_stories():
    response = client.get("/api/v1/public/gutenberg?topic=folklore")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0

