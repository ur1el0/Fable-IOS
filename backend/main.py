from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

# Exported symbols for test and backwards compatibility
__all__ = ["app", "init_db", "get_db", "DB_PATH", "extract_chapters_from_text"]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
