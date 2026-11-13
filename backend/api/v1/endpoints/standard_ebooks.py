from typing import Optional
from fastapi import APIRouter, Query

from schemas import ChapterDTO, StoryDTO
from services import standard_ebooks as standard_ebooks_service

router = APIRouter()


@router.get("/public/standard-ebooks", response_model=list[StoryDTO])
async def get_standard_ebooks_stories(
    topic: Optional[str] = Query(default=None, description="Filter Standard Ebooks by subject (e.g. fiction, horror)"),
    search: Optional[str] = Query(default=None, description="Search keyword for title or author"),
):
    """Retrieve curated public-domain classics from Standard Ebooks."""
    return await standard_ebooks_service.get_standard_ebooks_stories(topic=topic, search=search)


@router.get("/public/standard-ebooks/chapters", response_model=list[ChapterDTO])
async def get_standard_ebooks_chapters(
    book_id: str = Query(..., description="Standard Ebooks slug path (e.g. bram-stoker/dracula)"),
):
    """Retrieve structured semantic XHTML chapters for a Standard Ebooks work."""
    return await standard_ebooks_service.get_standard_ebooks_chapters(book_id=book_id)
