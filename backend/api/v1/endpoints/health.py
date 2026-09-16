from datetime import datetime, timezone
from fastapi import APIRouter
from core.database import get_db
from schemas import HealthResponse

router = APIRouter()

@router.get("/health", response_model=HealthResponse)
def health_check():
    conn = get_db()
    conn.execute("SELECT 1")
    conn.close()
    return HealthResponse(
        status="healthy",
        database="connected",
        timestamp_utc=datetime.now(timezone.utc)
    )
