from dataclasses import dataclass, field
from typing import Optional, List
from datetime import datetime
from uuid import UUID

@dataclass
class Chapter:
    id: UUID
    story_id: UUID
    chapter_number: int
    title: str
    content: Optional[str] = ""
    word_count: int = 0
    created_at_utc: datetime = datetime.now()
    page_urls: List[str] = field(default_factory=list)

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
    total_pages: int = 0
    current_page: int = 1
    progress_percent: int = 0
    rating: Optional[float] = None
    saves_count: str = "0"
    reads_count: str = "0"
    is_tale_of_the_day: bool = False
    is_recent_submission: bool = False
    is_curator_spotlight: bool = False
    badge_text: Optional[str] = None
    total_chapters: int = 0
    content_format: str = "PROSE"
    source_provider: str = "FABLE_ORIGINAL"

@dataclass
class ShelfItem:
    story_id: UUID
    reading_progress: float
    is_bookmarked: bool
    is_completed: bool
    updated_at_utc: datetime
