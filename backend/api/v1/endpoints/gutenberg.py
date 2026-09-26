from typing import Optional
from fastapi import APIRouter, Path, Query, status

from schemas import ChapterDTO, StoryDTO
from services import gutenberg as gutenberg_service

router = APIRouter()

@router.post("/stories/ingest/{gutenberg_id}", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
async def ingest_gutenberg_book(
    gutenberg_id: int,
    genre: Optional[str] = Query(default="Folklore")
):
    return await gutenberg_service.ingest_gutenberg_book(gutenberg_id=gutenberg_id, genre=genre)

@router.get("/public/gutenberg", response_model=list[StoryDTO])
async def get_gutenberg_stories(
    topic: Optional[str] = Query(default="folklore", description="Topic or genre filter for Gutenberg"),
    search: Optional[str] = Query(default=None, description="Search term across title and author")
):
    return await gutenberg_service.get_gutenberg_stories(topic=topic, search=search)


@router.get("/public/gutenberg/{gutenberg_id}", response_model=StoryDTO)
async def get_gutenberg_story(gutenberg_id: int = Path(ge=1)):
    return await gutenberg_service.get_gutenberg_story_by_id(gutenberg_id)


@router.get("/public/gutenberg/{gutenberg_id}/chapters", response_model=list[ChapterDTO])
async def get_gutenberg_chapters(gutenberg_id: int = Path(ge=1)):
    return await gutenberg_service.get_gutenberg_chapters(gutenberg_id=gutenberg_id)
