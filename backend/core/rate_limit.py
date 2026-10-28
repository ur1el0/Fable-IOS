import os
import time
import threading
import math
from collections import deque
from typing import Tuple, Dict
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse


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


# Shared singleton instance configured via environment variables
limiter = SlidingWindowRateLimiter(
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
    def __init__(self, app, rate_limiter: SlidingWindowRateLimiter = None):
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
        enabled = os.environ.get("FABLE_RATE_LIMIT_ENABLED", "true").lower() in ("true", "1", "yes")
        if not enabled:
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

        allowed, retry_after = self.rate_limiter.is_allowed(client_ip, tier)
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
