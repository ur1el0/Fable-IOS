import os
import time
import threading
import math
from collections import defaultdict, deque
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
    ):
        self.limits = {
            "auth": (auth_limit, auth_window),
            "general": (general_limit, general_window),
        }
        self._history: Dict[str, deque] = defaultdict(deque)
        self._lock = threading.Lock()

    def is_allowed(self, client_id: str, tier: str = "general") -> Tuple[bool, int]:
        limit, window = self.limits.get(tier, self.limits["general"])
        now = time.time()
        bucket_key = f"{client_id}:{tier}"

        with self._lock:
            queue = self._history[bucket_key]
            # Prune outdated timestamps outside the sliding window
            cutoff = now - window
            while queue and queue[0] <= cutoff:
                queue.popleft()

            if len(queue) < limit:
                queue.append(now)
                return True, 0
            else:
                oldest_ts = queue[0]
                retry_after = max(1, int(math.ceil(oldest_ts + window - now)))
                return False, retry_after

    def reset(self):
        with self._lock:
            self._history.clear()


# Shared singleton instance configured via environment variables
limiter = SlidingWindowRateLimiter(
    auth_limit=int(os.environ.get("RATE_LIMIT_AUTH_LIMIT", "10")),
    auth_window=int(os.environ.get("RATE_LIMIT_AUTH_WINDOW", "60")),
    general_limit=int(os.environ.get("RATE_LIMIT_GENERAL_LIMIT", "60")),
    general_window=int(os.environ.get("RATE_LIMIT_GENERAL_WINDOW", "60")),
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

        # Resolve client IP (supporting reverse proxies and load balancers)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            client_ip = forwarded.split(",")[0].strip()
        elif request.client and request.client.host:
            client_ip = request.client.host
        else:
            client_ip = "127.0.0.1"

        # Tier classification: stricter limits for authentication endpoints
        tier = "auth" if path.startswith("/api/v1/auth") else "general"

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
