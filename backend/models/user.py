from pydantic import BaseModel
from datetime import datetime
from datetime import date as Date
from typing import Optional


class ProfileResponse(BaseModel):
    id: str
    username: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    xp: int = 0
    level: int = 1
    streak_count: int = 0
    longest_streak: int = 0
    last_cooked_date: Optional[Date] = None
    created_at: datetime


class ProfileUpdate(BaseModel):
    username: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
