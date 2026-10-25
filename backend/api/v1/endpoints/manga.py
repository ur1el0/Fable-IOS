from typing import Optional
from fastapi import APIRouter, Path, Query, status

from schemas import ChapterDTO, StoryDTO
from services import manga as manga_service

router = APIRouter()


@router.get("/public/manga", response_model=list[StoryDTO])
async def get_manga_stories(
    search: Optional[str] = Query(default=None, description="Search keyword for manga title"),
    limit: int = Query(default=20, ge=1, le=50, description="Maximum number of titles to return"),
    offset: int = Query(default=0, ge=0, description="Offset for pagination")
):
    """
    Search and discover manga titles proxied through the Fable backend with in-memory caching.
    """
    return await manga_service.search_manga(query=search, limit=limit, offset=offset)


@router.get("/public/manga/{manga_id}", response_model=StoryDTO)
async def get_manga_story(
    manga_id: str = Path(..., description="External manga identifier")
):
    """
    Retrieve metadata for a specific manga title.
    """
    return await manga_service.get_manga_by_id(manga_id)


@router.get("/public/manga/{manga_id}/chapters", response_model=list[ChapterDTO])
async def get_manga_chapters(
    manga_id: str = Path(..., description="External manga identifier"),
    limit: int = Query(default=20, ge=1, le=50, description="Maximum number of chapters to return")
):
    """
    Retrieve translated chapters with sequential high-resolution panel URLs for reading.
    """
    return await manga_service.get_manga_chapters(manga_id=manga_id, limit=limit)


@router.post("/stories/ingest/manga/{manga_id}", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
async def ingest_manga_story(
    manga_id: str = Path(..., description="External manga identifier to persist into Fable")
):
    """
    Ingest and persist a manga title and its chapters into the Fable SQLite library.
    """
    return await manga_service.ingest_manga_story(manga_id=manga_id)
