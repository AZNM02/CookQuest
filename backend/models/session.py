from pydantic import BaseModel, Field
from datetime import datetime
from datetime import date as Date
from typing import Optional
from enum import Enum


class CuisineType(str, Enum):
    asian = "asian"
    western = "western"
    mediterranean = "mediterranean"
    middle_eastern = "middle_eastern"
    other = "other"


class SessionCreate(BaseModel):
    dish_name: str
    cuisine_type: CuisineType
    date: Date = Field(default_factory=Date.today)
    self_rating: int = Field(ge=1, le=5)
    difficulty_felt: int = Field(ge=1, le=5)
    technique_ids: list[int] = Field(default_factory=list)
    time_taken_mins: Optional[int] = None
    notes: Optional[str] = None
    photo_url: Optional[str] = None


class SessionResponse(BaseModel):
    id: str
    user_id: str
    dish_name: str
    cuisine_type: str
    date: Date
    self_rating: int
    difficulty_felt: int
    time_taken_mins: Optional[int] = None
    notes: Optional[str] = None
    photo_url: Optional[str] = None
    xp_earned: int
    ai_feedback: Optional[str] = None
    created_at: datetime
    technique_ids: list[int] = Field(default_factory=list)


class BadgeInfo(BaseModel):
    name: str
    icon: str
    description: str


class SessionLogResponse(BaseModel):
    session: SessionResponse
    xp_earned: int
    new_total_xp: int
    new_level: int
    leveled_up: bool
    streak_count: int = 0
    new_badges: list[BadgeInfo] = Field(default_factory=list)
