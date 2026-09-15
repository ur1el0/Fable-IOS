import sqlite3
import os
from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from schemas import (
    StoryDTO,
    CreateStoryRequest,
    ShelfSyncItemDTO,
    ShelfSyncPayload,
    ShelfSyncResponse,
    HealthResponse
)

DB_PATH = os.environ.get("FABLE_DB_PATH", "fable.sqlite3")

app = FastAPI(
    title="Fable Cloud Synchronization API",
    description="Minimalist, offline-first asynchronous REST pipeline with SQLite and Last-Write-Wins (LWW) conflict resolution.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    with conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS stories (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                genre TEXT NOT NULL,
                chapter TEXT NOT NULL,
                synopsis TEXT NOT NULL,
                content TEXT NOT NULL,
                read_time_minutes INTEGER NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL
            );
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS shelf_items (
                story_id TEXT PRIMARY KEY,
                reading_progress REAL NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                updated_at_utc TEXT NOT NULL
            );
        """)
        
        # Seed initial folklore tale if database is fresh
        cursor = conn.execute("SELECT COUNT(*) as count FROM stories")
        if cursor.fetchone()["count"] == 0:
            now_iso = datetime.now(timezone.utc).isoformat()
            conn.execute("""
                INSERT INTO stories (
                    id, title, author, genre, chapter, synopsis, content,
                    read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                "55555555-5555-5555-5555-555555555555",
                "The Clockmaker of Prague",
                "Roosc Zaño",
                "Folklore",
                "Chapter I",
                "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings.",
                "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings. The councilors came at midnight, their cloaks smelling of damp river fog and sulfur.",
                4,
                1,
                0,
                now_iso,
                now_iso
            ))
    conn.close()

init_db()

@app.get("/api/v1/health", response_model=HealthResponse)
def health_check():
    conn = get_db()
    conn.execute("SELECT 1")
    conn.close()
    return HealthResponse(
        status="healthy",
        database="connected",
        timestamp_utc=datetime.now(timezone.utc)
    )

@app.get("/api/v1/stories", response_model=list[StoryDTO])
def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None
):
    conn = get_db()
    query = "SELECT * FROM stories WHERE 1=1"
    params = []
    
    if genre and genre.lower() != "all":
        query += " AND LOWER(genre) = LOWER(?)"
        params.append(genre)
        
    if search:
        query += " AND (LOWER(title) LIKE ? OR LOWER(synopsis) LIKE ?)"
        term = f"%{search.lower()}%"
        params.extend([term, term])
        
    if since:
        query += " AND updated_at_utc > ?"
        params.append(since.isoformat())
        
    query += " ORDER BY created_at_utc DESC"
    rows = conn.execute(query, params).fetchall()
    conn.close()
    
    results = []
    for r in rows:
        results.append(StoryDTO(
            id=UUID(r["id"]),
            title=r["title"],
            author=r["author"],
            genre=r["genre"],
            chapter=r["chapter"],
            synopsis=r["synopsis"],
            content=r["content"],
            read_time_minutes=r["read_time_minutes"],
            is_bookmarked=bool(r["is_bookmarked"]),
            is_completed=bool(r["is_completed"]),
            created_at_utc=datetime.fromisoformat(r["created_at_utc"]),
            updated_at_utc=datetime.fromisoformat(r["updated_at_utc"])
        ))
    return results

@app.post("/api/v1/stories", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
def create_story(payload: CreateStoryRequest):
    story_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    
    conn = get_db()
    with conn:
        conn.execute("""
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            story_id,
            payload.title,
            payload.author,
            payload.genre,
            payload.chapter or "Chapter I",
            payload.synopsis,
            payload.content,
            payload.read_time_minutes,
            0,
            0,
            now_iso,
            now_iso
        ))
    conn.close()
    
    return StoryDTO(
        id=UUID(story_id),
        title=payload.title,
        author=payload.author,
        genre=payload.genre,
        chapter=payload.chapter or "Chapter I",
        synopsis=payload.synopsis,
        content=payload.content,
        read_time_minutes=payload.read_time_minutes,
        is_bookmarked=False,
        is_completed=False,
        created_at_utc=now,
        updated_at_utc=now
    )

@app.post("/api/v1/shelf/sync", response_model=ShelfSyncResponse)
def sync_shelf(payload: ShelfSyncPayload):
    """
    Bidirectional synchronization with Last-Write-Wins (LWW) conflict resolution.
    Client timestamp (t_client) is compared with Server timestamp (t_server).
    """
    conn = get_db()
    reconciled: list[ShelfSyncItemDTO] = []
    
    with conn:
        for item in payload.items:
            story_id_str = str(item.story_id)
            row = conn.execute(
                "SELECT * FROM shelf_items WHERE story_id = ?",
                (story_id_str,)
            ).fetchone()
            
            if row is None:
                # No server record exists; accept client record
                conn.execute("""
                    INSERT INTO shelf_items (story_id, reading_progress, is_bookmarked, is_completed, updated_at_utc)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    story_id_str,
                    item.reading_progress,
                    1 if item.is_bookmarked else 0,
                    1 if item.is_completed else 0,
                    item.updated_at_utc.isoformat()
                ))
                reconciled.append(item)
            else:
                server_time = datetime.fromisoformat(row["updated_at_utc"])
                client_time = item.updated_at_utc
                
                if client_time > server_time:
                    # Client wins (LWW)
                    conn.execute("""
                        UPDATE shelf_items
                        SET reading_progress = ?, is_bookmarked = ?, is_completed = ?, updated_at_utc = ?
                        WHERE story_id = ?
                    """, (
                        item.reading_progress,
                        1 if item.is_bookmarked else 0,
                        1 if item.is_completed else 0,
                        item.updated_at_utc.isoformat(),
                        story_id_str
                    ))
                    reconciled.append(item)
                else:
                    # Server record is newer or equal; return server state to client
                    reconciled.append(ShelfSyncItemDTO(
                        story_id=UUID(row["story_id"]),
                        reading_progress=row["reading_progress"],
                        is_bookmarked=bool(row["is_bookmarked"]),
                        is_completed=bool(row["is_completed"]),
                        updated_at_utc=server_time
                    ))
    conn.close()
    
    return ShelfSyncResponse(
        status="ok",
        reconciled_items=reconciled,
        server_time_utc=datetime.now(timezone.utc)
    )
