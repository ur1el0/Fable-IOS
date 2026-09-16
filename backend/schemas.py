from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from pydantic import BaseModel, Field

class ChapterDTO(BaseModel):
    id: UUID
    story_id: UUID = Field(..., serialization_alias="storyId")
    chapter_number: int = Field(..., ge=1, serialization_alias="chapterNumber")
    title: str
    content: str
    word_count: int = Field(default=0, serialization_alias="wordCount")
    created_at_utc: datetime = Field(..., serialization_alias="createdAtUtc")

    model_config = {
        "populate_by_name": True
    }

class StoryDTO(BaseModel):
    id: UUID
    title: str = Field(..., min_length=1, max_length=120)
    author: str = Field(..., min_length=1, max_length=80)
    genre: str
    chapter: str = "Chapter I"
    synopsis: str
    content: str
    read_time_minutes: int = Field(default=4, ge=1, serialization_alias="readTimeMinutes")
    is_bookmarked: bool = Field(default=False, serialization_alias="isBookmarked")
    is_completed: bool = Field(default=False, serialization_alias="isCompleted")
    created_at_utc: datetime = Field(..., serialization_alias="createdAtUtc")
    updated_at_utc: datetime = Field(..., serialization_alias="updatedAtUtc")
    cover_image_name: Optional[str] = Field(default=None, serialization_alias="coverImageName")
    hero_image_name: Optional[str] = Field(default=None, serialization_alias="heroImageName")
    cover_image_url: Optional[str] = Field(default=None, serialization_alias="coverImageUrl")
    total_pages: int = Field(default=5, serialization_alias="totalPages")
    current_page: int = Field(default=1, serialization_alias="currentPage")
    progress_percent: int = Field(default=0, serialization_alias="progressPercent")
    rating: float = Field(default=4.9, serialization_alias="rating")
    saves_count: str = Field(default="1.2k", serialization_alias="savesCount")
    reads_count: str = Field(default="1.2k", serialization_alias="readsCount")
    is_tale_of_the_day: bool = Field(default=False, serialization_alias="isTaleOfTheDay")
    is_recent_submission: bool = Field(default=False, serialization_alias="isRecentSubmission")
    is_curator_spotlight: bool = Field(default=False, serialization_alias="isCuratorSpotlight")
    badge_text: Optional[str] = Field(default=None, serialization_alias="badgeText")
    total_chapters: int = Field(default=1, serialization_alias="totalChapters")
    chapters: Optional[list[ChapterDTO]] = None

    model_config = {
        "populate_by_name": True
    }

class GenreDTO(BaseModel):
    id: UUID
    name: str
    story_count: int = Field(default=0, serialization_alias="storyCount")
    readers_count: str = Field(default="10k", serialization_alias="readersCount")
    description: str
    image_name: str = Field(default="genre_folklore", serialization_alias="imageName")

    model_config = {
        "populate_by_name": True
    }

class WriterDTO(BaseModel):
    id: UUID
    name: str
    avatar_image_name: str = Field(default="author_kuang", serialization_alias="avatarImageName")
    story_count: int = Field(default=1, serialization_alias="storyCount")
    rating: float = Field(default=4.9, serialization_alias="rating")

    model_config = {
        "populate_by_name": True
    }

class UpdateFeedDTO(BaseModel):
    tale_of_the_day: Optional[StoryDTO] = Field(default=None, serialization_alias="taleOfTheDay")
    curator_spotlight: Optional[StoryDTO] = Field(default=None, serialization_alias="curatorSpotlight")
    recent_submissions: list[StoryDTO] = Field(default_factory=list, serialization_alias="recentSubmissions")
    total_stories: int = Field(default=0, serialization_alias="totalStories")
    timestamp_utc: datetime = Field(..., serialization_alias="timestampUtc")

    model_config = {
        "populate_by_name": True
    }

class CreateStoryRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    author: str = Field(..., min_length=1, max_length=80)
    genre: str
    chapter: Optional[str] = "Chapter I"
    synopsis: str
    content: str
    read_time_minutes: int = Field(default=4, ge=1, alias="readTimeMinutes")

    model_config = {
        "populate_by_name": True
    }

class ShelfSyncItemDTO(BaseModel):
    story_id: UUID
    reading_progress: float = Field(..., ge=0.0, le=1.0)
    is_bookmarked: bool
    is_completed: bool
    updated_at_utc: datetime

class ShelfSyncPayload(BaseModel):
    device_id: UUID
    items: list[ShelfSyncItemDTO]

class ShelfSyncResponse(BaseModel):
    status: str = "ok"
    reconciled_items: list[ShelfSyncItemDTO]
    server_time_utc: datetime

class HealthResponse(BaseModel):
    status: str = "healthy"
    database: str = "connected"
    timestamp_utc: datetime
