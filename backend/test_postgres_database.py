import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException

from core.database import get_db, init_db
from core.rate_limit import SharedTokenBucketRateLimiter
from schemas.schemas import ReadingSessionRequest, ShelfSyncItemDTO, ShelfSyncPayload
from services.auth_rate_limit import enforce_auth_rate_limit
from services.reading_stats import get_reading_stats, record_reading_session
from services.shelf_sync import get_shelf, sync_shelf
from services.story_service import get_genres, get_stories, get_story_by_id, get_story_chapters


pytestmark = pytest.mark.skipif(
    not os.environ.get("DATABASE_URL")
    or os.environ.get("FABLE_DATABASE_BACKEND") != "postgres",
    reason="PostgreSQL integration checks require a configured Postgres service.",
)


@pytest.fixture(scope="module", autouse=True)
def initialize_postgres_schema():
    init_db()


def test_postgres_schema_initialization_is_repeatable():
    init_db()
    connection = get_db()
    try:
        version = connection.execute(
            "SELECT version FROM fable_schema_version WHERE id = 1"
        ).fetchone()["version"]
        tables = {
            row["table_name"]
            for row in connection.execute(
                """SELECT table_name FROM information_schema.tables
                   WHERE table_schema = current_schema()"""
            ).fetchall()
        }
    finally:
        connection.close()

    assert version == 4
    assert {"stories", "chapters", "users", "password_reset_tokens"} <= tables


def test_postgres_qmark_adapter_preserves_quoted_question_marks_and_commits():
    key = str(uuid4())
    connection = get_db()
    try:
        with connection:
            connection.execute(
                "CREATE TEMP TABLE fable_adapter_check (key TEXT PRIMARY KEY, note TEXT)"
            )
            connection.execute(
                "INSERT INTO fable_adapter_check (key, note) VALUES (?, ?)",
                (key, "a literal question mark: ?"),
            )
            row = connection.execute(
                """SELECT note, '?' AS marker FROM fable_adapter_check
                   WHERE key = ?""",
                (key,),
            ).fetchone()
        assert row["note"] == "a literal question mark: ?"
        assert row["marker"] == "?"
    finally:
        connection.close()


def test_postgres_general_rate_limit_uses_transaction_locks():
    limiter = SharedTokenBucketRateLimiter(
        auth_limit=1,
        auth_window=60,
        general_limit=1,
        general_window=60,
    )

    client_id = f"postgres-{uuid4()}"
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(lambda _index: limiter.is_allowed(client_id), range(8)))

    assert sum(allowed for allowed, _retry_after in results) == 1


def test_postgres_auth_rate_limit_persists_and_rejects_over_limit():
    client_host = f"postgres-{uuid4()}"
    for _ in range(5):
        enforce_auth_rate_limit("register", client_host)

    with pytest.raises(HTTPException) as error:
        enforce_auth_rate_limit("register", client_host)

    assert getattr(error.value, "status_code", None) == 429


def test_postgres_catalog_and_chapter_queries_return_service_models():
    story_id = uuid4()
    chapter_id = uuid4()
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    connection = get_db()
    try:
        with connection:
            connection.execute(
                """INSERT INTO stories
                   (id, title, author, genre, chapter, synopsis, content,
                    read_time_minutes, created_at_utc, updated_at_utc)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    str(story_id),
                    "Neon Database Mystery",
                    "Postgres Author",
                    "Mystery",
                    "Chapter 1",
                    "A database compatibility story.",
                    "Full story text.",
                    3,
                    now,
                    now,
                ),
            )
            connection.execute(
                """INSERT INTO chapters
                   (id, story_id, chapter_number, title, content, word_count, created_at_utc)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (
                    str(chapter_id),
                    str(story_id),
                    1,
                    "The Migration",
                    "The chapter remains readable.",
                    5,
                    now,
                ),
            )
    finally:
        connection.close()

    try:
        stories = get_stories(genre="mystery", search="NEON")
        story = get_story_by_id(story_id)
        chapters = get_story_chapters(story_id)
        genres = get_genres()

        assert [item.id for item in stories] == [story_id]
        assert story.chapters and story.chapters[0].id == chapter_id
        assert chapters[0].content == "The chapter remains readable."
        assert any(item.name == "Mystery" for item in genres)
    finally:
        connection = get_db()
        try:
            with connection:
                connection.execute("DELETE FROM stories WHERE id = ?", (str(story_id),))
        finally:
            connection.close()


def test_postgres_reading_sessions_and_shelf_sync_preserve_idempotency_and_order():
    owner_id = uuid4()
    story_id = uuid4()
    session = ReadingSessionRequest(
        id=uuid4(),
        storyId=story_id,
        secondsRead=119,
        readAtUtc=datetime.now(timezone.utc),
        isCompleted=True,
    )
    record_reading_session(owner_id, session)
    record_reading_session(owner_id, session)
    stats = get_reading_stats(owner_id)
    assert stats.stories_read_count == 1
    assert stats.total_minutes_read == 1

    device_id = uuid4()
    newer_time = datetime.now(timezone.utc)
    newer = ShelfSyncItemDTO(
        storyId=story_id,
        readingProgress=0.75,
        isBookmarked=True,
        isCompleted=False,
        updatedAtUtc=newer_time,
    )
    sync_shelf(ShelfSyncPayload(deviceId=device_id, items=[newer]), owner_id)
    older = newer.model_copy(
        update={"reading_progress": 0.25, "updated_at_utc": newer_time.replace(year=newer_time.year - 1)}
    )
    result = sync_shelf(ShelfSyncPayload(deviceId=device_id, items=[older]), owner_id)

    assert result.reconciled_items[0].reading_progress == 0.75
    assert get_shelf(device_id, owner_id)[0].reading_progress == 0.75
