import os
import time
import threading
import math
import hashlib
from collections import deque
from typing import Tuple, Dict
from core.database import get_db
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import JSONResponse
from core.settings import load_rate_limit_enabled


class SlidingWindowRateLimiter:
    """
    Thread-safe in-memory sliding window rate limiter.
    Maintains timestamp logs per client key and prunes records older than window size.
    """
    def __init__(
        self,
        auth_limit: int = 10,
        auth_window: int = 60,
        general_limit: int = 60,
        general_window: int = 60,
        max_client_buckets: int = 10_000,
    ):
        if max_client_buckets < 1:
            raise ValueError("max_client_buckets must be positive")
        self.limits = {
            "auth": (auth_limit, auth_window),
            "general": (general_limit, general_window),
        }
        self._history: Dict[str, deque] = {}
        self._max_client_buckets = max_client_buckets
        self._last_capacity_cleanup = 0.0
        self._lock = threading.Lock()

    def is_allowed(self, client_id: str, tier: str = "general") -> Tuple[bool, int]:
        limit, window = self.limits.get(tier, self.limits["general"])
        now = time.time()
        bucket_key = f"{client_id}:{tier}"

        with self._lock:
            queue = self._history.get(bucket_key)
            if queue is None:
                if len(self._history) >= self._max_client_buckets:
                    if now - self._last_capacity_cleanup >= 5.0:
                        self._prune_expired_buckets(now)
                        self._last_capacity_cleanup = now
                    if len(self._history) >= self._max_client_buckets:
                        return False, 1
                queue = deque()
                self._history[bucket_key] = queue
            else:
                cutoff = now - window
                while queue and queue[0] <= cutoff:
                    queue.popleft()
                if not queue:
                    del self._history[bucket_key]
                    queue = deque()
                    self._history[bucket_key] = queue

            if len(queue) < limit:
                queue.append(now)
                return True, 0
            else:
                oldest_ts = queue[0]
                retry_after = max(1, int(math.ceil(oldest_ts + window - now)))
                return False, retry_after

    def _prune_expired_buckets(self, now: float) -> None:
        for bucket_key, queue in list(self._history.items()):
            tier = bucket_key.rsplit(":", 1)[-1]
            _, window = self.limits.get(tier, self.limits["general"])
            cutoff = now - window
            while queue and queue[0] <= cutoff:
                queue.popleft()
            if not queue:
                del self._history[bucket_key]

    def reset(self):
        with self._lock:
            self._history.clear()
            self._last_capacity_cleanup = 0.0


class SharedTokenBucketRateLimiter:
    """SQLite-backed limiter shared by workers using the same database file."""

    def __init__(
        self,
        auth_limit: int = 10,
        auth_window: int = 60,
        general_limit: int = 60,
        general_window: int = 60,
        max_client_buckets: int = 10_000,
    ):
        self.limits = {
            "auth": (auth_limit, auth_window),
            "general": (general_limit, general_window),
        }
        if max_client_buckets < 1:
            raise ValueError("max_client_buckets must be positive")
        if any(limit < 1 or window < 1 for limit, window in self.limits.values()):
            raise ValueError("Rate limits and windows must be positive")
        self._max_client_buckets = max_client_buckets
        self._last_capacity_cleanup = 0.0
        self._cleanup_lock = threading.Lock()

    def is_allowed(self, client_id: str, tier: str = "general") -> Tuple[bool, int]:
        limit, window = self.limits.get(tier, self.limits["general"])
        now = time.time()
        bucket_key = hashlib.sha256(f"{client_id}\x1f{tier}".encode("utf-8")).hexdigest()
        connection = get_db()
        try:
            connection.execute("BEGIN IMMEDIATE")
            with self._cleanup_lock:
                if now - self._last_capacity_cleanup >= 5.0:
                    largest_window = max(value[1] for value in self.limits.values())
                    connection.execute(
                        "DELETE FROM request_rate_limit_buckets WHERE updated_at <= ?",
                        (now - largest_window * 2,),
                    )
                    self._last_capacity_cleanup = now

            row = connection.execute(
                "SELECT available_tokens, updated_at FROM request_rate_limit_buckets WHERE bucket_key = ?",
                (bucket_key,),
            ).fetchone()
            if row is None:
                bucket_count = connection.execute(
                    "SELECT COUNT(*) FROM request_rate_limit_buckets"
                ).fetchone()[0]
                if bucket_count >= self._max_client_buckets:
                    connection.commit()
                    return False, 1
                connection.execute(
                    """INSERT INTO request_rate_limit_buckets
                       (bucket_key, available_tokens, updated_at) VALUES (?, ?, ?)""",
                    (bucket_key, float(limit - 1), now),
                )
                connection.commit()
                return True, 0

            elapsed = max(0.0, now - row["updated_at"])
            available_tokens = min(
                float(limit),
                row["available_tokens"] + elapsed * limit / window,
            )
            if available_tokens >= 1.0:
                connection.execute(
                    "UPDATE request_rate_limit_buckets SET available_tokens = ?, updated_at = ? WHERE bucket_key = ?",
                    (available_tokens - 1.0, now, bucket_key),
                )
                connection.commit()
                return True, 0

            retry_after = max(1, int(math.ceil((1.0 - available_tokens) * window / limit)))
            connection.execute(
                "UPDATE request_rate_limit_buckets SET available_tokens = ?, updated_at = ? WHERE bucket_key = ?",
                (available_tokens, now, bucket_key),
            )
            connection.commit()
            return False, retry_after
        except Exception:
            if connection.in_transaction:
                connection.rollback()
            raise
        finally:
            connection.close()

    def reset(self) -> None:
        connection = get_db()
        try:
            with connection:
                connection.execute("DELETE FROM request_rate_limit_buckets")
            self._last_capacity_cleanup = 0.0
        finally:
            connection.close()


# Shared singleton instance configured via environment variables
limiter = SharedTokenBucketRateLimiter(
    auth_limit=int(os.environ.get("RATE_LIMIT_AUTH_LIMIT", "10")),
    auth_window=int(os.environ.get("RATE_LIMIT_AUTH_WINDOW", "60")),
    general_limit=int(os.environ.get("RATE_LIMIT_GENERAL_LIMIT", "60")),
    general_window=int(os.environ.get("RATE_LIMIT_GENERAL_WINDOW", "60")),
    max_client_buckets=int(os.environ.get("FABLE_RATE_LIMIT_MAX_CLIENT_BUCKETS", "10000")),
)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    FastAPI / Starlette middleware enforcing sliding-window rate limiting.
    Rejects throttled requests with HTTP 429 and standard Retry-After header.
    """
    def __init__(
        self,
        app,
        rate_limiter: SlidingWindowRateLimiter | SharedTokenBucketRateLimiter | None = None,
    ):
        super().__init__(app)
        self.rate_limiter = rate_limiter or limiter
        self.exempt_paths = {
            "/api/v1/health",
            "/docs",
            "/redoc",
            "/openapi.json",
        }

    async def dispatch(self, request: Request, call_next):
        # Configurable master switch (defaults to enabled in production/runtime)
        if not load_rate_limit_enabled():
            return await call_next(request)

        path = request.url.path
        if path in self.exempt_paths:
            return await call_next(request)

        # Uvicorn rewrites request.client only for peers trusted by FORWARDED_ALLOW_IPS.
        # Never use X-Forwarded-For directly because clients can supply it themselves.
        client_ip = request.client.host if request.client and request.client.host else "127.0.0.1"

        # Credential checks and durable ingestion writes use the stricter tier.
        sensitive_path = path.startswith(("/api/v1/auth", "/api/v1/stories/ingest"))
        tier = "auth" if sensitive_path else "general"

        allowed, retry_after = await run_in_threadpool(
            self.rate_limiter.is_allowed,
            client_ip,
            tier,
        )
        if not allowed:
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Too many requests. Please slow down.",
                    "retry_after": retry_after
                },
                headers={"Retry-After": str(retry_after)}
            )

        return await call_next(request)
