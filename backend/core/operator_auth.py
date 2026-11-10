from __future__ import annotations

import hmac
import os
from typing import Optional

from fastapi import Header, HTTPException, status


MINIMUM_INGESTION_KEY_BYTES = 32


def require_ingestion_api_key(
    api_key: Optional[str] = Header(default=None, alias="X-Fable-Ingestion-Key"),
) -> None:
    configured_key = os.environ.get("FABLE_INGESTION_API_KEY", "")
    configured_key_bytes = configured_key.encode("utf-8")
    if len(configured_key_bytes) < MINIMUM_INGESTION_KEY_BYTES:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Provider ingestion is not configured.",
        )

    supplied_key_bytes = (api_key or "").encode("utf-8")
    if not hmac.compare_digest(supplied_key_bytes, configured_key_bytes):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A valid ingestion key is required.",
        )
