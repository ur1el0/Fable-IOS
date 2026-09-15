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

def test_get_stories_includes_seed():
    response = client.get("/api/v1/stories")
    assert response.status_code == 200
    stories = response.json()
    assert len(stories) >= 1
    assert stories[0]["title"] == "The Clockmaker of Prague"

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
