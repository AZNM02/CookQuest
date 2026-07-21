from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from database import get_client

router = APIRouter(prefix="/techniques", tags=["techniques"])


class TechniqueResponse(BaseModel):
    id: int
    name: str
    category: str
    difficulty_tier: str
    description: Optional[str] = None
    xp_reward: int


@router.get("", response_model=list[TechniqueResponse])
async def get_techniques():
    client = await get_client()
    resp = await (
        client.table("techniques")
        .select("*")
        .order("category")
        .order("name")
        .execute()
    )
    return resp.data or []
