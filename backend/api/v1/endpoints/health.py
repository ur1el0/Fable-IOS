import logging
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from core.database import get_db
from schemas import HealthResponse

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/health", response_model=HealthResponse)
def health_check():
    conn = None
    try:
        conn = get_db()
        row = conn.execute("SELECT 1").fetchone()
        if not row or row[0] != 1:
            raise RuntimeError("Unexpected database ping result")
    except Exception as exc:
        logger.error("Health check database ping failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database health check failed.",
        )
    finally:
        if conn is not None:
            conn.close()

    return HealthResponse(
        status="healthy",
        database="connected",
        timestamp_utc=datetime.now(timezone.utc)
    )
