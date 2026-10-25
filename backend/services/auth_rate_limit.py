import hashlib
import os
import time
from fastapi import HTTPException

from core.database import get_db


def _positive_int(name: str, default: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError as error:
        raise RuntimeError(f"{name} must be a positive integer.") from error
    if value < 1:
        raise RuntimeError(f"{name} must be a positive integer.")
    return value


WINDOW_SECONDS = _positive_int("FABLE_AUTH_RATE_WINDOW_SECONDS", 900)
REGISTER_LIMIT_PER_IP = _positive_int("FABLE_AUTH_REGISTER_LIMIT_PER_IP", 5)
LOGIN_LIMIT_PER_IP = _positive_int("FABLE_AUTH_LOGIN_LIMIT_PER_IP", 60)
LOGIN_LIMIT_PER_ACCOUNT_IP = _positive_int("FABLE_AUTH_LOGIN_LIMIT_PER_ACCOUNT_IP", 10)


def _bucket_key(action: str, dimension: str, value: str) -> str:
    digest = hashlib.sha256(f"{action}\x1f{dimension}\x1f{value}".encode("utf-8")).hexdigest()
    return f"{action}:{dimension}:{digest}"


def enforce_auth_rate_limit(action: str, client_host: str, identity: str | None = None) -> None:
    now = int(time.time())
    if action == "register":
        buckets = [
            (_bucket_key(action, "ip", client_host), REGISTER_LIMIT_PER_IP),
        ]
    elif action == "login":
        buckets = [
            (_bucket_key(action, "ip", client_host), LOGIN_LIMIT_PER_IP),
        ]
        if identity:
            buckets.append(
                (
                    _bucket_key(action, "account-ip", f"{client_host}\x1f{identity.strip().casefold()}"),
                    LOGIN_LIMIT_PER_ACCOUNT_IP,
                )
            )
    else:
        raise ValueError(f"Unsupported rate-limited auth action: {action}")

    retry_after = 0
    connection = get_db()
    try:
        with connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                "DELETE FROM auth_rate_limits WHERE window_expires_at <= ?",
                (now,),
            )
            for bucket_key, limit in buckets:
                row = connection.execute(
                    "SELECT window_expires_at, request_count FROM auth_rate_limits WHERE bucket_key = ?",
                    (bucket_key,),
                ).fetchone()
                if row is None or row["window_expires_at"] <= now:
                    connection.execute(
                        """INSERT INTO auth_rate_limits
                           (bucket_key, window_expires_at, request_count)
                           VALUES (?, ?, 1)
                           ON CONFLICT(bucket_key) DO UPDATE SET
                               window_expires_at = excluded.window_expires_at,
                               request_count = 1""",
                        (bucket_key, now + WINDOW_SECONDS),
                    )
                    continue

                count = row["request_count"] + 1
                connection.execute(
                    "UPDATE auth_rate_limits SET request_count = ? WHERE bucket_key = ?",
                    (min(count, limit + 1), bucket_key),
                )
                if count > limit:
                    retry_after = max(
                        retry_after,
                        row["window_expires_at"] - now,
                    )
    finally:
        connection.close()

    if retry_after > 0:
        raise HTTPException(
            status_code=429,
            detail="Too many authentication attempts. Try again later.",
            headers={"Retry-After": str(retry_after)},
        )
