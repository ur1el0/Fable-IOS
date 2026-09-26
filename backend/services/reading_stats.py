from datetime import date, datetime, timezone
from uuid import UUID

from core.database import get_db
from schemas.schemas import ReadingSessionRequest, ReadingStatsDTO


def record_reading_session(owner_user_id: UUID, request: ReadingSessionRequest) -> None:
    conn = get_db()
    try:
        with conn:
            conn.execute(
                """INSERT OR IGNORE INTO reading_sessions
                   (owner_user_id, id, story_id, seconds_read, read_at_utc, is_completed)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    str(owner_user_id),
                    str(request.id),
                    str(request.story_id),
                    request.seconds_read,
                    request.read_at_utc.astimezone(timezone.utc).isoformat(),
                    1 if request.is_completed else 0,
                ),
            )
    finally:
        conn.close()


def get_reading_stats(owner_user_id: UUID) -> ReadingStatsDTO:
    conn = get_db()
    try:
        row = conn.execute(
            """SELECT
                   COUNT(DISTINCT CASE WHEN is_completed = 1 THEN story_id END) AS stories_read_count,
                   COALESCE(SUM(seconds_read), 0) AS total_seconds,
                   COUNT(DISTINCT date(read_at_utc)) AS active_days
               FROM reading_sessions
               WHERE owner_user_id = ?""",
            (str(owner_user_id),),
        ).fetchone()
        active_dates = {
            date.fromisoformat(item["read_day"])
            for item in conn.execute(
                """SELECT DISTINCT date(read_at_utc) AS read_day
                   FROM reading_sessions WHERE owner_user_id = ?""",
                (str(owner_user_id),),
            ).fetchall()
        }
    finally:
        conn.close()

    today = datetime.now(timezone.utc).date()
    streak_start = today if today in active_dates else date.fromordinal(today.toordinal() - 1)
    streak_days = 0
    while streak_start in active_dates:
        streak_days += 1
        streak_start = date.fromordinal(streak_start.toordinal() - 1)

    return ReadingStatsDTO(
        stories_read_count=row["stories_read_count"],
        total_minutes_read=row["total_seconds"] // 60,
        streak_days=streak_days,
    )
