import logging
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from core.database import get_db
from schemas import HealthResponse

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/live")
def liveness_check():
    """Report process availability without waking or querying the database."""
    return {"status": "alive"}


@router.get("/health", response_model=HealthResponse)
def health_check():
    conn = None
    try:
        conn = get_db()
        row = conn.execute("SELECT 1 AS connected").fetchone()
        if not row or row["connected"] != 1:
            raise RuntimeError("Unexpected database ping result")
    except Exception as exc:
        logger.error(
            "Health check database ping failed (exception_type=%s)",
            type(exc).__name__,
        )
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
