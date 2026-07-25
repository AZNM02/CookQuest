from fastapi import APIRouter, Depends
from database import get_client
from dependencies import get_current_user
from services.recommendation_service import recommend_recipes

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("")
async def get_recommendations(limit: int = 5, user_id: str = Depends(get_current_user)):
    client = await get_client()
    return await recommend_recipes(client, user_id, limit=limit)
