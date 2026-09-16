from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from pydantic import BaseModel, Field

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
