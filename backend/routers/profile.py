from fastapi import APIRouter, Depends, HTTPException
from database import get_client
from dependencies import get_current_user
from models.user import ProfileResponse, ProfileUpdate

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(user_id: str = Depends(get_current_user)):
    client = await get_client()
    response = await client.table("profiles").select("*").eq("id", user_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return response.data[0]


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
