import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.database import init_db, get_db, DB_PATH
from core.rate_limit import RateLimitMiddleware, limiter
from api.v1.api import api_router
from services.text_parser import extract_chapters_from_text

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

default_origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://localhost:5173",
    "capacitor://localhost",
    "ionic://localhost",
]
env_origins = os.environ.get("FABLE_CORS_ORIGINS")
if env_origins:
    allowed_origins = [o.strip() for o in env_origins.split(",") if o.strip()]
else:
    allowed_origins = default_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(RateLimitMiddleware, rate_limiter=limiter)

app.include_router(api_router, prefix="/api/v1")

# Exported symbols for test and backwards compatibility
__all__ = ["app", "init_db", "get_db", "DB_PATH", "extract_chapters_from_text", "limiter"]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

