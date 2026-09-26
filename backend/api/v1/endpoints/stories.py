from datetime import datetime
from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Header, status

from schemas import (
    StoryDTO,
    ChapterDTO,
    GenreDTO,
    WriterDTO,
    UpdateFeedDTO,
    CreateStoryRequest
)
from services import auth_service, story_service

router = APIRouter()

@router.get("/stories", response_model=list[StoryDTO])
def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None
):
    return story_service.get_stories(genre=genre, search=search, since=since)

@router.get("/genres", response_model=list[GenreDTO])
def get_genres():
    return story_service.get_genres()

@router.get("/authors/top", response_model=list[WriterDTO])
async def get_top_authors():
    return await story_service.get_top_authors()

@router.get("/updates", response_model=UpdateFeedDTO)
def get_update_feed():
    return story_service.get_update_feed()

@router.get("/stories/{story_id}", response_model=StoryDTO)
def get_story_by_id(story_id: UUID):
    return story_service.get_story_by_id(story_id)

@router.get("/stories/{story_id}/chapters", response_model=list[ChapterDTO])
def get_story_chapters(story_id: UUID):
    return story_service.get_story_chapters(story_id)

@router.get("/stories/{story_id}/chapters/{chapter_number}", response_model=ChapterDTO)
def get_story_chapter_by_number(story_id: UUID, chapter_number: int):
    return story_service.get_story_chapter_by_number(story_id, chapter_number)

@router.post("/stories", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
def create_story(payload: CreateStoryRequest, authorization: str = Header(None)):
    user = auth_service.get_current_user_from_header(authorization)
    return story_service.create_story(payload, author=user.name, owner_user_id=user.id)
