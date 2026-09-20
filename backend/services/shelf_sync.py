from datetime import datetime, timezone
from uuid import UUID
from core.database import get_db
from schemas.schemas import ShelfSyncPayload, ShelfSyncResponse, ShelfSyncItemDTO

def to_utc(dt: datetime) -> datetime:
    """Normalize datetime to timezone-aware UTC to prevent naive vs aware comparison crashes."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

def sync_shelf(payload: ShelfSyncPayload) -> ShelfSyncResponse:
    """Reconcile client shelf state with server using Last-Write-Wins partitioned by device_id."""
    conn = get_db()
    reconciled: list[ShelfSyncItemDTO] = []
    device_id_str = str(payload.device_id)

    with conn:
        for item in payload.items:
            story_id_str = str(item.story_id)
            row = conn.execute(
                "SELECT * FROM shelf_items WHERE device_id = ? AND story_id = ?",
                (device_id_str, story_id_str)
            ).fetchone()

            if row is None:
                conn.execute("""
                    INSERT INTO shelf_items (device_id, story_id, reading_progress, is_bookmarked, is_completed, updated_at_utc)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    device_id_str,
                    story_id_str,
                    item.reading_progress,
                    1 if item.is_bookmarked else 0,
                    1 if item.is_completed else 0,
                    item.updated_at_utc.isoformat()
                ))
                reconciled.append(item)
            else:
                server_time = to_utc(datetime.fromisoformat(row["updated_at_utc"]))
                client_time = to_utc(item.updated_at_utc)

                if client_time > server_time:
                    conn.execute("""
                        UPDATE shelf_items
                        SET reading_progress = ?, is_bookmarked = ?, is_completed = ?, updated_at_utc = ?
                        WHERE device_id = ? AND story_id = ?
                    """, (
                        item.reading_progress,
                        1 if item.is_bookmarked else 0,
                        1 if item.is_completed else 0,
                        item.updated_at_utc.isoformat(),
                        device_id_str,
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

def get_shelf(device_id: UUID) -> list[ShelfSyncItemDTO]:
    """Retrieve all shelf items for a specific client device."""
    conn = get_db()
    cursor = conn.execute(
        "SELECT * FROM shelf_items WHERE device_id = ?",
        (str(device_id),)
    )
    rows = cursor.fetchall()
    conn.close()

    return [
        ShelfSyncItemDTO(
            story_id=UUID(row["story_id"]),
            reading_progress=row["reading_progress"],
            is_bookmarked=bool(row["is_bookmarked"]),
            is_completed=bool(row["is_completed"]),
            updated_at_utc=to_utc(datetime.fromisoformat(row["updated_at_utc"]))
        )
        for row in rows
    ]
