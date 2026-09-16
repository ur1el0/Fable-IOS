from datetime import datetime, timezone
from uuid import UUID
from core.database import get_db
from schemas.schemas import ShelfSyncPayload, ShelfSyncResponse, ShelfSyncItemDTO

def sync_shelf(payload: ShelfSyncPayload) -> ShelfSyncResponse:
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
