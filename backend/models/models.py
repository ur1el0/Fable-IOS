from dataclasses import dataclass
from typing import Optional
from datetime import datetime
from uuid import UUID

@dataclass
class Chapter:
    id: UUID
    story_id: UUID
    chapter_number: int
    title: str
    content: str
    word_count: int
    created_at_utc: datetime

@dataclass
class Story:
    id: UUID
    title: str
    author: str
    genre: str
    chapter: str
    synopsis: str
    content: str
    read_time_minutes: int
    is_bookmarked: bool
    is_completed: bool
    created_at_utc: datetime
    updated_at_utc: datetime
    cover_image_name: Optional[str] = None
    hero_image_name: Optional[str] = None
    cover_image_url: Optional[str] = None
    total_pages: int = 5
    current_page: int = 1
    progress_percent: int = 0
    rating: float = 4.9
    saves_count: str = "1.2k"
    reads_count: str = "1.2k"
    is_tale_of_the_day: bool = False
    is_recent_submission: bool = False
    is_curator_spotlight: bool = False
    badge_text: Optional[str] = None
    total_chapters: int = 1

@dataclass
class ShelfItem:
    story_id: UUID
    reading_progress: float
    is_bookmarked: bool
    is_completed: bool
    updated_at_utc: datetime
