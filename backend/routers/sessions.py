from fastapi import APIRouter, Depends, HTTPException
from database import get_client
from dependencies import get_current_user
from models.session import SessionCreate, SessionResponse, SessionLogResponse
from services.xp_service import calculate_xp, get_level_from_xp
from services.streak_service import compute_new_streak
from services.proficiency_service import update_proficiency
from services.badge_service import check_and_award_badges

router = APIRouter(prefix="/sessions", tags=["sessions"])


async def _attach_technique_ids(client, sessions: list[dict]) -> list[SessionResponse]:
    result = []
    for s in sessions:
        tech = await (
            client.table("session_techniques")
            .select("technique_id")
            .eq("session_id", s["id"])
            .execute()
        )
        technique_ids = [r["technique_id"] for r in (tech.data or [])]
        result.append(SessionResponse(**s, technique_ids=technique_ids))
    return result


@router.post("/log", response_model=SessionLogResponse, status_code=201)
async def log_session(body: SessionCreate, user_id: str = Depends(get_current_user)):
    client = await get_client()

    # Fetch existing proficiency records (for XP calc + proficiency update)
    proficiency_records: list[dict] = []
    if body.technique_ids:
        prof = await (
            client.table("user_technique_proficiency")
            .select("technique_id, times_used, avg_rating")
            .eq("user_id", user_id)
            .in_("technique_id", body.technique_ids)
            .execute()
        )
        proficiency_records = prof.data or []

    xp_earned = calculate_xp(
        self_rating=body.self_rating,
        difficulty_felt=body.difficulty_felt,
        techniques_used=body.technique_ids,
        technique_records=proficiency_records,
    )

    # Insert session
    session_data = body.model_dump(mode="json", exclude={"technique_ids"})
    session_data["user_id"] = user_id
    session_data["xp_earned"] = xp_earned

    session_resp = await client.table("cooking_sessions").insert(session_data).execute()
    if not session_resp.data:
        raise HTTPException(status_code=500, detail="Failed to create session")

    session = session_resp.data[0]
    session_id = session["id"]

    # Insert technique junction rows
    if body.technique_ids:
        junctions = [
            {"session_id": session_id, "technique_id": tid}
            for tid in body.technique_ids
        ]
        await client.table("session_techniques").insert(junctions).execute()

    # Read profile (single read for XP + streak)
    profile_resp = await (
        client.table("profiles")
        .select("xp, streak_count, longest_streak, last_cooked_date")
        .eq("id", user_id)
        .execute()
    )
    profile = profile_resp.data[0]

    # Compute new XP + level
    old_xp: int = profile["xp"]
    new_xp = old_xp + xp_earned
    old_level = get_level_from_xp(old_xp)
    new_level = get_level_from_xp(new_xp)

    # Compute new streak
    new_streak, new_longest = compute_new_streak(
        current_streak=profile["streak_count"] or 0,
        longest_streak=profile["longest_streak"] or 0,
        last_cooked_date=profile["last_cooked_date"],
        session_date=body.date,
    )

    # Single profile update
    await (
        client.table("profiles")
        .update({
            "xp": new_xp,
            "level": new_level,
            "streak_count": new_streak,
            "longest_streak": new_longest,
            "last_cooked_date": body.date.isoformat(),
        })
        .eq("id", user_id)
        .execute()
    )

    # Update technique proficiency records
    await update_proficiency(client, user_id, body.technique_ids, body.self_rating, proficiency_records)

    # Check and award badges
    new_badges = await check_and_award_badges(client, user_id, new_xp, new_streak)

    return SessionLogResponse(
        session=SessionResponse(**session, technique_ids=body.technique_ids),
        xp_earned=xp_earned,
        new_total_xp=new_xp,
        new_level=new_level,
        leveled_up=new_level > old_level,
        streak_count=new_streak,
        new_badges=new_badges,
    )


@router.get("", response_model=list[SessionResponse])
async def get_sessions(
    limit: int = 20,
    offset: int = 0,
    user_id: str = Depends(get_current_user),
):
    client = await get_client()
    resp = await (
        client.table("cooking_sessions")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    return await _attach_technique_ids(client, resp.data or [])


@router.get("/{session_id}", response_model=SessionResponse)
async def get_session(session_id: str, user_id: str = Depends(get_current_user)):
    client = await get_client()
    resp = await (
        client.table("cooking_sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not resp.data:
        raise HTTPException(status_code=404, detail="Session not found")
    sessions = await _attach_technique_ids(client, resp.data)
    return sessions[0]


@router.delete("/{session_id}", status_code=204)
async def delete_session(session_id: str, user_id: str = Depends(get_current_user)):
    client = await get_client()
    exists = await (
        client.table("cooking_sessions")
        .select("id")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not exists.data:
        raise HTTPException(status_code=404, detail="Session not found")
    await (
        client.table("cooking_sessions")
        .delete()
        .eq("id", session_id)
        .execute()
    )
