from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from core.database import DB_PATH, get_db, init_db
from core.rate_limit import RateLimitMiddleware, limiter
from core.request_limits import RequestBodySizeLimitMiddleware
from core.settings import load_cors_origins, request_body_limit_bytes
from api.v1.api import api_router
from services.text_parser import extract_chapters_from_text

logger = logging.getLogger(__name__)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
        response.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        if request.url.path.startswith("/api/"):
            response.headers.setdefault(
                "Content-Security-Policy",
                "default-src 'none'; frame-ancestors 'none'",
            )
        if request.url.path.startswith("/api/v1/auth") or request.url.path.startswith("/api/v1/shelf"):
            response.headers["Cache-Control"] = "no-store"
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="Fable Literary API",
    version="1.0.0",
    description="Offline-first community & Gutenberg reading platform backend",
    lifespan=lifespan,
)


@app.exception_handler(RequestValidationError)
async def sanitized_validation_error_handler(
    _request: Request,
    error: RequestValidationError,
) -> JSONResponse:
    safe_errors = [
        {
            "type": item["type"],
            "loc": item["loc"],
            "msg": item["msg"],
        }
        for item in error.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": safe_errors})


@app.exception_handler(Exception)
async def sanitized_unhandled_exception_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    logger.exception("Unhandled server error on %s %s: %s", request.method, request.url.path, error)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal server error occurred."},
    )


app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RateLimitMiddleware, rate_limiter=limiter)
app.add_middleware(RequestBodySizeLimitMiddleware, max_bytes=request_body_limit_bytes())
app.add_middleware(
    CORSMiddleware,
    allow_origins=load_cors_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(api_router, prefix="/api/v1")

__all__ = ["app", "init_db", "get_db", "DB_PATH", "extract_chapters_from_text", "limiter"]

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
