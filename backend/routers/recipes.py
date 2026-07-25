from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from database import get_client

router = APIRouter(prefix="/recipes", tags=["recipes"])


class RecipeResponse(BaseModel):
    id: int
    name: str
    cuisine_type: str
    difficulty: str
    estimated_time_mins: Optional[int] = None
    description: Optional[str] = None
    instructions: Optional[str] = None


@router.get("", response_model=list[RecipeResponse])
async def get_recipes(cuisine_type: Optional[str] = None, difficulty: Optional[str] = None):
    client = await get_client()
    query = client.table("recipes").select("*").order("name")
    if cuisine_type:
        query = query.eq("cuisine_type", cuisine_type)
    if difficulty:
        query = query.eq("difficulty", difficulty)
    resp = await query.execute()
    return resp.data or []
