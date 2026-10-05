import json
import os
from urllib.parse import urlsplit


def load_cors_origins() -> list[str]:
    raw_origins = os.environ.get("CORS_ORIGINS", "[]")
    try:
        origins = json.loads(raw_origins)
    except json.JSONDecodeError as error:
        raise RuntimeError("CORS_ORIGINS must be a JSON array of origins.") from error

    if not isinstance(origins, list) or any(not isinstance(origin, str) for origin in origins):
        raise RuntimeError("CORS_ORIGINS must be a JSON array of origin strings.")

    environment = os.environ.get("FABLE_ENV", "development").strip().lower()
    development_environments = {"development", "dev", "local", "test"}
    cleaned_origins = [origin.strip().rstrip("/") for origin in origins]
    if "*" in cleaned_origins:
        if len(cleaned_origins) != 1 or environment not in development_environments:
            raise RuntimeError("Wildcard CORS is only allowed in development and test environments.")
        return cleaned_origins

    for origin in cleaned_origins:
        parsed = urlsplit(origin)
        try:
            parsed.port
            has_invalid_port = False
        except ValueError:
            has_invalid_port = True
        if (
            not origin
            or parsed.scheme not in {"http", "https"}
            or not parsed.hostname
            or parsed.username
            or parsed.password
            or has_invalid_port
            or parsed.path
            or parsed.query
            or parsed.fragment
        ):
            raise RuntimeError(f"Invalid CORS origin: {origin!r}")
        if environment not in development_environments and parsed.scheme != "https":
            raise RuntimeError("Non-development CORS origins must use HTTPS.")

    return cleaned_origins


def request_body_limit_bytes() -> int:
    raw_value = os.environ.get("FABLE_MAX_REQUEST_BODY_BYTES", "262144")
    try:
        value = int(raw_value)
    except ValueError as error:
        raise RuntimeError("FABLE_MAX_REQUEST_BODY_BYTES must be a positive integer.") from error
    if value < 1024:
        raise RuntimeError("FABLE_MAX_REQUEST_BODY_BYTES must be at least 1024.")
    return value
