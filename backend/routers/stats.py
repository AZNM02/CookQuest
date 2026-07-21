from fastapi import APIRouter, Depends, HTTPException
from database import get_client
from dependencies import get_current_user
from services.xp_service import get_xp_for_level, get_level_from_xp

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/dashboard")
async def get_dashboard_stats(user_id: str = Depends(get_current_user)):
    client = await get_client()

    profile_resp = await client.table("profiles").select("*").eq("id", user_id).execute()
    if not profile_resp.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    profile = profile_resp.data[0]

    sessions_resp = await (
        client.table("cooking_sessions")
        .select("id, dish_name, cuisine_type, date, self_rating, xp_earned")
        .eq("user_id", user_id)
        .order("date", desc=True)
        .execute()
    )
    all_sessions = sessions_resp.data or []
    total_sessions = len(all_sessions)
    unique_cuisines = len(set(s["cuisine_type"] for s in all_sessions))
    recent_sessions = all_sessions[:5]

    unique_techniques = 0
    if all_sessions:
        session_ids = [s["id"] for s in all_sessions]
        tech_resp = await (
            client.table("session_techniques")
            .select("technique_id")
            .in_("session_id", session_ids)
            .execute()
        )
        unique_techniques = len(set(r["technique_id"] for r in (tech_resp.data or [])))

    level = profile.get("level", 1)
    xp = profile.get("xp", 0)

    return {
        "profile": profile,
        "recent_sessions": recent_sessions,
        "stats": {
            "total_sessions": total_sessions,
            "unique_techniques": unique_techniques,
            "cuisine_count": unique_cuisines,
            "longest_streak": profile.get("longest_streak", 0),
        },
        "xp_progress": {
            "current_xp": xp,
            "level": level,
            "xp_for_current_level": get_xp_for_level(level),
            "xp_for_next_level": get_xp_for_level(level + 1),
        },
    }
