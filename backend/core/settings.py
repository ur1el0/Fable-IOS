import json
import os
from urllib.parse import urlsplit


def load_cors_origins() -> list[str]:
    raw_origins = os.environ.get("FABLE_CORS_ORIGINS")
    if raw_origins is None:
        raw_origins = os.environ.get("CORS_ORIGINS")

    environment = os.environ.get("FABLE_ENV", "development").strip().lower()
    development_environments = {"development", "dev", "local", "test"}
    if raw_origins is None:
        origins = (
            [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:8000",
                "http://127.0.0.1:8000",
                "http://localhost:5173",
                "capacitor://localhost",
                "ionic://localhost",
            ]
            if environment in development_environments
            else []
        )
    else:
        try:
            origins = json.loads(raw_origins)
        except json.JSONDecodeError as error:
            if raw_origins.lstrip().startswith("["):
                raise RuntimeError(
                    "FABLE_CORS_ORIGINS must be a JSON array or comma-separated origins."
                ) from error
            origins = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]

    if not isinstance(origins, list) or any(not isinstance(origin, str) for origin in origins):
        raise RuntimeError("FABLE_CORS_ORIGINS must contain origin strings.")

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
        is_local_native_origin = (
            environment in development_environments
            and parsed.scheme in {"capacitor", "ionic"}
            and parsed.hostname == "localhost"
        )
        if (
            not origin
            or (parsed.scheme not in {"http", "https"} and not is_local_native_origin)
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
