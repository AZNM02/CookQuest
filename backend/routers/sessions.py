from fastapi import APIRouter, Depends, HTTPException
from database import get_client
from dependencies import get_current_user
from models.session import SessionCreate, SessionResponse, SessionLogResponse
from services.xp_service import calculate_xp, get_level_from_xp

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

    # Fetch existing proficiency records for the techniques being used
    proficiency_records: list[dict] = []
    if body.technique_ids:
        prof = await (
            client.table("user_technique_proficiency")
            .select("technique_id, times_used")
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

    # Serialize to dict; use mode='json' so date → ISO string
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

    # Update user XP and level
    profile_resp = await (
        client.table("profiles").select("xp").eq("id", user_id).execute()
    )
    old_xp: int = profile_resp.data[0]["xp"]
    new_xp = old_xp + xp_earned
    old_level = get_level_from_xp(old_xp)
    new_level = get_level_from_xp(new_xp)

    await (
        client.table("profiles")
        .update({"xp": new_xp, "level": new_level})
        .eq("id", user_id)
        .execute()
    )

    return SessionLogResponse(
        session=SessionResponse(**session, technique_ids=body.technique_ids),
        xp_earned=xp_earned,
        new_total_xp=new_xp,
        new_level=new_level,
        leveled_up=new_level > old_level,
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
