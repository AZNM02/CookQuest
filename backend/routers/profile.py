from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from database import get_client
from dependencies import get_current_user
from models.user import ProfileResponse, ProfileUpdate

router = APIRouter(prefix="/profile", tags=["profile"])


class EarnedBadge(BaseModel):
    name: str
    icon: str
    description: str
    earned_at: datetime


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(user_id: str = Depends(get_current_user)):
    client = await get_client()
    response = await client.table("profiles").select("*").eq("id", user_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return response.data[0]


@router.get("/badges", response_model=list[EarnedBadge])
async def get_earned_badges(user_id: str = Depends(get_current_user)):
    client = await get_client()
    earned_resp = await (
        client.table("user_badges")
        .select("badge_id, earned_at")
        .eq("user_id", user_id)
        .order("earned_at", desc=True)
        .execute()
    )
    earned = earned_resp.data or []
    if not earned:
        return []

    badge_ids = [r["badge_id"] for r in earned]
    badges_resp = await (
        client.table("badges")
        .select("id, name, icon, description")
        .in_("id", badge_ids)
        .execute()
    )
    badge_map = {b["id"]: b for b in (badges_resp.data or [])}

    return [
        {
            "name": badge_map[r["badge_id"]]["name"],
            "icon": badge_map[r["badge_id"]]["icon"],
            "description": badge_map[r["badge_id"]]["description"],
            "earned_at": r["earned_at"],
        }
        for r in earned
        if r["badge_id"] in badge_map
    ]


@router.patch("/me", response_model=ProfileResponse)
async def update_my_profile(
    body: ProfileUpdate,
    user_id: str = Depends(get_current_user),
):
    updates = body.model_dump(exclude_none=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    client = await get_client()
    response = await (
        client.table("profiles").update(updates).eq("id", user_id).execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return response.data[0]
