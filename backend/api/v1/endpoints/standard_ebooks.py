from typing import Optional
from fastapi import APIRouter, Query

from schemas import ChapterDTO, StoryDTO
from services import standard_ebooks as standard_ebooks_service

router = APIRouter()


@router.get("/public/standard-ebooks", response_model=list[StoryDTO])
async def get_standard_ebooks_stories(
    topic: Optional[str] = Query(default=None, max_length=50, description="Filter Standard Ebooks by subject (e.g. fiction, horror)"),
    search: Optional[str] = Query(default=None, max_length=200, description="Search keyword for title or author"),
):
    """Retrieve curated public-domain classics from Standard Ebooks."""
    return await standard_ebooks_service.get_standard_ebooks_stories(topic=topic, search=search)


@router.get("/public/standard-ebooks/story", response_model=StoryDTO)
async def get_standard_ebooks_story(
    book_id: str = Query(..., max_length=120, description="Standard Ebooks slug path (e.g. bram-stoker/dracula)"),
):
    """Retrieve metadata for a specific Standard Ebooks work."""
    return await standard_ebooks_service.get_standard_ebooks_story_by_id(book_id=book_id)


@router.get("/public/standard-ebooks/chapters", response_model=list[ChapterDTO])
async def get_standard_ebooks_chapters(
    book_id: str = Query(..., max_length=120, description="Standard Ebooks slug path (e.g. bram-stoker/dracula)"),
):
    """Retrieve structured semantic XHTML chapters for a Standard Ebooks work."""
    return await standard_ebooks_service.get_standard_ebooks_chapters(book_id=book_id)
