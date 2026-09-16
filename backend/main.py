import sqlite3
import os
import httpx
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
        
        # Seed initial editorial catalog if database is fresh
        cursor = conn.execute("SELECT COUNT(*) as count FROM stories")
        if cursor.fetchone()["count"] == 0:
            now_iso = datetime.now(timezone.utc).isoformat()
            catalog = [
                (
                    "55555555-5555-5555-5555-555555555555",
                    "The Clockmaker of Prague",
                    "Roosc Zaño",
                    "Folklore",
                    "Chapter I",
                    "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings.",
                    "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings. The councilors came at midnight, their cloaks smelling of damp river fog and sulfur.",
                    4, 1, 0, now_iso, now_iso
                ),
                (
                    "11111111-1111-1111-1111-111111111111",
                    "The Balete Tree of Baler",
                    "Danilo Ramos",
                    "Folklore",
                    "Chapter I",
                    "Centuries-old roots cradle whispers of travelers who wandered past sundown.",
                    "The ancient balete stood at the boundary between the cultivated rice terraces and the untouched canopy of Aurora. Its aerial roots were thicker than church pillars, twisting around a hollow core that emitted a cool, subterranean draft even in the scorching heat of April. Old man Mateo had warned every child in the barrio: 'When the cicadas abruptly cease their song at twilight, do not look into the hollow.' But Joel was seventeen, armed with modern skepticism and a pocket flashlight...",
                    6, 1, 0, now_iso, now_iso
                ),
                (
                    "22222222-2222-2222-2222-222222222222",
                    "The Midnight Jeepney",
                    "Maria Santos",
                    "Urban Legend",
                    "Chapter I",
                    "A commuter boards the last ride through Aurora Boulevard and discovers no one is paying with coins.",
                    "Rain turned Epifanio de los Santos Avenue into a shimmering river of brake lights. It was 1:45 AM when the stainless-steel jeepney rattled to a halt beside the shuttered convenience store. The destination signboard bore no avenue or landmark, merely two words written in fading crimson script: 'SA DULO' (To the End). Sofia hopped onto the rear stirrup, shaking water from her umbrella...",
                    4, 0, 1, now_iso, now_iso
                ),
                (
                    "33333333-3333-3333-3333-333333333333",
                    "Tears of the Diwata",
                    "Alon Cruz",
                    "Mythology",
                    "Chapter I",
                    "When the sacred lake dries, the guardian spirits demand an offering of forgotten songs.",
                    "Before the miners carved terraces into Mount Makiling, the mountain was known to breathe. Its exhalations were mists scented with wild ginger and damp earth. Maria Makiling sat upon the basalt ridge, her long dark tresses trailing into the emerald waters of Lake Alligator...",
                    8, 1, 1, now_iso, now_iso
                ),
                (
                    "44444444-4444-4444-4444-444444444444",
                    "Echoes on the Concrete Span",
                    "R. Zaño",
                    "Horror",
                    "Chapter I",
                    "Every year on the anniversary of the collapse, the radio picks up transmissions from cars that never made it across.",
                    "The bridge connecting the two coastal towns had been completed in record time during the boom years of the late seventies. But local fishermen claimed that beneath the fifth pylon, the water never rippled naturally...",
                    5, 0, 0, now_iso, now_iso
                ),
                (
                    "66666666-6666-6666-6666-666666666666",
                    "Dracula",
                    "Bram Stoker",
                    "Gothic",
                    "Chapter I",
                    "The castle is on the very edge of a terrible precipice. A stone falling from the window would fall a thousand feet without touching anything.",
                    "Before the sun had set, we reached the Bistritz pass. The grey of the evening had begun to fall, and the shadows of the mountains seemed to close in around us with every mile. The horses began to strain against the harness as the road turned sharply upward into the deep pine forests of Transylvania. 'The castle is on the very edge of a terrible precipice,' the driver whispered, crossing himself as the wolves began their low, distant howling down in the valley below. 'A stone falling from the window would fall a thousand feet without touching anything.' The wind grew colder, piercing through my woollen mantle with icy teeth.",
                    4, 1, 0, now_iso, now_iso
                ),
                (
                    "77777777-7777-7777-7777-777777777777",
                    "The Legend of Sleepy Hollow",
                    "Washington Irving",
                    "Folklore",
                    "Chapter I",
                    "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere.",
                    "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere. Some say that the place was bewitched by a High German doctor, during the early days of the settlement; others, that an old Indian chief, the prophet or wizard of his tribe, held his powwows there before the country was discovered by Master Hendrick Hudson. Certain it is, the place still continues under the sway of some bewitching power, that holds a spell over the minds of the good people, causing them to walk in a continual reverie.",
                    4, 1, 0, now_iso, now_iso
                ),
                (
                    "88888888-8888-8888-8888-888888888888",
                    "The Metamorphosis",
                    "Franz Kafka",
                    "Classic Fiction",
                    "Chapter I",
                    "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.",
                    "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin. He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections. The bedding was hardly able to cover it and seemed ready to slide off any moment. His many legs, pitifully thin compared with the size of the rest of him, waved about helplessly as he looked.",
                    5, 1, 0, now_iso, now_iso
                ),
                (
                    "99999999-9999-9999-9999-999999999999",
                    "The Tell-Tale Heart",
                    "Edgar Allan Poe",
                    "Gothic",
                    "Chapter I",
                    "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad?",
                    "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them. Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story.",
                    3, 1, 0, now_iso, now_iso
                ),
                (
                    "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                    "The Legend of Maria Makiling",
                    "Jose Rizal",
                    "Folklore",
                    "Chapter I",
                    "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods...",
                    "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods... Her voice was like the murmur of crystal water over white pebbles, and her step was as light as the dewdrop falling upon a leaf at dawn.",
                    4, 1, 0, now_iso, now_iso
                )
            ]
            conn.executemany("""
                INSERT INTO stories (
                    id, title, author, genre, chapter, synopsis, content,
                    read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, catalog)
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

@app.get("/api/v1/public/gutenberg", response_model=list[StoryDTO])
async def get_gutenberg_stories(
    topic: Optional[str] = Query(default="folklore", description="Topic or genre filter for Gutenberg"),
    search: Optional[str] = Query(default=None, description="Search term across title and author")
):
    """
    Public literature gateway: Queries Project Gutenberg via Gutendex REST API,
    normalizes unstructured literary data into Fable's StoryDTO schema, and falls back
    to internal catalog if the external API is unreachable or network is offline.
    """
    url = "https://gutendex.com/books"
    params = {}
    if topic and topic.lower() != "all":
        params["topic"] = topic.lower()
    if search:
        params["search"] = search

    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 200:
                payload = resp.json()
                results = payload.get("results", [])
                gutenberg_stories: list[StoryDTO] = []
                now = datetime.now(timezone.utc)

                for book in results[:10]:
                    book_id = book.get("id", 1000)
                    title = book.get("title", "Untitled Classic")
                    authors = book.get("authors", [])
                    author_name = authors[0].get("name", "Classic Author") if authors else "Public Domain"
                    if ", " in author_name:
                        parts = author_name.split(", ", 1)
                        author_name = f"{parts[1]} {parts[0]}"

                    summaries = book.get("summaries", [])
                    synopsis = summaries[0] if summaries else f"Classic public domain edition of {title} from Project Gutenberg."
                    if len(synopsis) > 280:
                        synopsis = synopsis[:277] + "..."

                    subjects = book.get("subjects", [])
                    genre = "Folklore"
                    if any("myth" in s.lower() for s in subjects):
                        genre = "Mythology"
                    elif any("gothic" in s.lower() or "horror" in s.lower() for s in subjects):
                        genre = "Gothic"
                    elif any("fiction" in s.lower() for s in subjects):
                        genre = "Classic Fiction"
                    elif topic and topic.lower() != "all":
                        genre = topic.capitalize()

                    story_uuid = UUID(int=int(book_id))

                    gutenberg_stories.append(StoryDTO(
                        id=story_uuid,
                        title=title[:120],
                        author=author_name[:80],
                        genre=genre,
                        chapter="Folio Edition",
                        synopsis=synopsis,
                        content=synopsis,
                        read_time_minutes=max(3, min(12, len(title.split()) * 2)),
                        is_bookmarked=False,
                        is_completed=False,
                        created_at_utc=now,
                        updated_at_utc=now
                    ))

                if gutenberg_stories:
                    return gutenberg_stories
    except Exception:
        # Offline or Gutendex timeout fallback (zero network crashes)
        pass

    return get_stories(genre=topic, search=search)

