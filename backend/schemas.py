"""
Compatibility shim forwarding to schemas package.
"""
from schemas.schemas import (
    ChapterDTO,
    StoryDTO,
    GenreDTO,
    WriterDTO,
    UpdateFeedDTO,
    CreateStoryRequest,
    ShelfSyncItemDTO,
    ShelfSyncPayload,
    ShelfSyncResponse,
    HealthResponse,
    ReadingSessionRequest,
    ReadingStatsDTO
)

__all__ = [
    "ChapterDTO",
    "StoryDTO",
    "GenreDTO",
    "WriterDTO",
    "UpdateFeedDTO",
    "CreateStoryRequest",
    "ShelfSyncItemDTO",
    "ShelfSyncPayload",
    "ShelfSyncResponse",
    "HealthResponse",
    "ReadingSessionRequest",
    "ReadingStatsDTO"
]
