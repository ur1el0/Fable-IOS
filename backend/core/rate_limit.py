from __future__ import annotations

import hashlib
import ipaddress
import math
import os
import threading
import time
from collections import deque
from typing import Callable, Dict, Optional, Tuple, Union
from core.database import get_db, lock_transaction_key
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import JSONResponse
from core.settings import load_rate_limit_enabled


def _load_trusted_proxy_networks() -> tuple[ipaddress._BaseNetwork, ...]:
    raw_cidrs = os.environ.get("FABLE_TRUSTED_PROXY_CIDRS", "").strip()
    if not raw_cidrs:
        return ()
    networks: list[ipaddress._BaseNetwork] = []
    for raw_cidr in raw_cidrs.split(","):
        candidate = raw_cidr.strip()
        if not candidate:
            continue
        try:
            networks.append(ipaddress.ip_network(candidate, strict=False))
        except ValueError:
            continue
    return tuple(networks)


def _parse_ip(raw_ip: Optional[str]) -> Optional[ipaddress._BaseAddress]:
    if not raw_ip:
        return None
    candidate = raw_ip.strip()
    if not candidate:
        return None
    # Strip optional port on IPv4 like "203.0.113.1:1234" or bracketed IPv6 "[::1]:1234"
    if candidate.startswith("[") and "]" in candidate:
        candidate = candidate[1:candidate.index("]")]
    elif candidate.count(":") == 1 and "." in candidate:
        candidate = candidate.split(":", 1)[0]
    try:
        return ipaddress.ip_address(candidate)
    except ValueError:
        return None


def _is_trusted_proxy(raw_ip: Optional[str], networks: tuple[ipaddress._BaseNetwork, ...]) -> bool:
    if not networks:
        return False
    parsed = _parse_ip(raw_ip)
    if parsed is None:
        return False
    return any(parsed in network for network in networks)


def extract_client_ip(request: Request) -> str:
    """Resolve the client IP, honoring forwarded headers only from trusted proxy CIDRs."""
    peer_host = request.client.host if request.client and request.client.host else ""
    trusted_networks = _load_trusted_proxy_networks()

    if trusted_networks and _is_trusted_proxy(peer_host, trusted_networks):
        forwarded_for = request.headers.get("x-forwarded-for", "")
        if forwarded_for:
            hops = [part.strip() for part in forwarded_for.split(",") if part.strip()]
            for hop in reversed(hops):
                parsed = _parse_ip(hop)
                if parsed is None:
                    break
                if not any(parsed in network for network in trusted_networks):
                    return str(parsed)
            if hops:
                parsed_first = _parse_ip(hops[0])
                if parsed_first is not None:
                    return str(parsed_first)

        real_ip = _parse_ip(request.headers.get("x-real-ip"))
        if real_ip is not None:
            return str(real_ip)

    return peer_host or "127.0.0.1"


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
    """Database-backed limiter shared by API workers."""

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
        self._reset_hooks: list[Callable[[], None]] = []

    def add_reset_hook(self, hook: Callable[[], None]) -> None:
        self._reset_hooks.append(hook)

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
                lock_transaction_key(connection, "request_rate_limit_buckets:capacity")
                row = connection.execute(
                    "SELECT available_tokens, updated_at FROM request_rate_limit_buckets WHERE bucket_key = ?",
                    (bucket_key,),
                ).fetchone()
            if row is None:
                bucket_count = connection.execute(
                    "SELECT COUNT(*) AS bucket_count FROM request_rate_limit_buckets"
                ).fetchone()["bucket_count"]
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

            lock_transaction_key(connection, bucket_key)
            row = connection.execute(
                "SELECT available_tokens, updated_at FROM request_rate_limit_buckets WHERE bucket_key = ?",
                (bucket_key,),
            ).fetchone()
            if row is None:
                connection.commit()
                return False, 1

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
        for hook in self._reset_hooks:
            hook()


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
    FastAPI / Starlette middleware enforcing rate limiting.
    Uses an in-memory sliding-window fast path for safe read-only requests (GET/HEAD/OPTIONS)
    and the shared database token-bucket limiter for mutating requests.
    Rejects throttled requests with HTTP 429 and standard Retry-After header.
    """
    READ_ONLY_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})

    def __init__(
        self,
        app,
        rate_limiter: Optional[Union[SlidingWindowRateLimiter, SharedTokenBucketRateLimiter]] = None,
        read_rate_limiter: Optional[SlidingWindowRateLimiter] = None,
    ):
        super().__init__(app)
        self.rate_limiter = rate_limiter or limiter
        if read_rate_limiter is not None:
            self.read_rate_limiter = read_rate_limiter
        elif isinstance(self.rate_limiter, SlidingWindowRateLimiter):
            self.read_rate_limiter = self.rate_limiter
        else:
            auth_limit, auth_window = self.rate_limiter.limits.get("auth", (10, 60))
            general_limit, general_window = self.rate_limiter.limits.get("general", (60, 60))
            self.read_rate_limiter = SlidingWindowRateLimiter(
                auth_limit=auth_limit,
                auth_window=auth_window,
                general_limit=general_limit,
                general_window=general_window,
                max_client_buckets=getattr(self.rate_limiter, "_max_client_buckets", 10_000),
            )
            if isinstance(self.rate_limiter, SharedTokenBucketRateLimiter):
                self.rate_limiter.add_reset_hook(self.read_rate_limiter.reset)
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

        client_ip = extract_client_ip(request)

        # Credential checks and durable ingestion writes use the stricter tier.
        sensitive_path = path.startswith(("/api/v1/auth", "/api/v1/stories/ingest"))
        tier = "auth" if sensitive_path else "general"

        is_read_only = request.method.upper() in self.READ_ONLY_METHODS
        if is_read_only:
            if hasattr(self.rate_limiter, "limits"):
                self.read_rate_limiter.limits = dict(self.rate_limiter.limits)
            allowed, retry_after = self.read_rate_limiter.is_allowed(client_ip, tier)
        else:
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
