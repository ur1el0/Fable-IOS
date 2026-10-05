from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from core.request_limits import RequestBodySizeLimitMiddleware
from core.settings import load_cors_origins, request_body_limit_bytes

from core.database import init_db, get_db, DB_PATH
from api.v1.api import api_router
from services.text_parser import extract_chapters_from_text

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(
    title="Fable Literary API",
    version="1.0.0",
    description="Offline-first community & Gutenberg reading platform backend",
    lifespan=lifespan
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

app.add_middleware(RequestBodySizeLimitMiddleware, max_bytes=request_body_limit_bytes())
app.add_middleware(
    CORSMiddleware,
    allow_origins=load_cors_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(api_router, prefix="/api/v1")

# Exported symbols for test and backwards compatibility
__all__ = ["app", "init_db", "get_db", "DB_PATH", "extract_chapters_from_text"]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
