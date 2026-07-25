from datetime import date
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from database import get_client
from dependencies import get_current_user
from services.proficiency_service import compute_proficiency_score

router = APIRouter(prefix="/techniques", tags=["techniques"])


class TechniqueResponse(BaseModel):
    id: int
    name: str
    category: str
    difficulty_tier: str
    description: Optional[str] = None
    xp_reward: int


class TechniqueProficiencyResponse(BaseModel):
    id: int
    name: str
    category: str
    difficulty_tier: str
    description: Optional[str] = None
    xp_reward: int
    times_used: int = 0
    avg_rating: float = 0.0
    last_used: Optional[str] = None
    proficiency_score: float = 0.0


def _live_score(times_used: int, avg_rating: float, last_used: str | None) -> float:
    """Recompute proficiency score with today's recency decay."""
    if not last_used or times_used == 0:
        return 0.0
    days_ago = (date.today() - date.fromisoformat(last_used)).days
    return compute_proficiency_score(times_used, avg_rating, days_ago)


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


@router.get("/proficiency", response_model=list[TechniqueProficiencyResponse])
async def get_proficiency(user_id: str = Depends(get_current_user)):
    """All techniques with the current user's proficiency data merged in."""
    client = await get_client()

    techniques_resp = await (
        client.table("techniques").select("*").order("category").order("name").execute()
    )
    techniques = techniques_resp.data or []

    prof_resp = await (
        client.table("user_technique_proficiency")
        .select("technique_id, times_used, avg_rating, last_used")
        .eq("user_id", user_id)
        .execute()
    )
    prof_map = {r["technique_id"]: r for r in (prof_resp.data or [])}

    result = []
    for t in techniques:
        p = prof_map.get(t["id"])
        if p:
            score = _live_score(p["times_used"], p["avg_rating"] or 0.0, p["last_used"])
            result.append(TechniqueProficiencyResponse(
                **t,
                times_used=p["times_used"],
                avg_rating=p["avg_rating"] or 0.0,
                last_used=p["last_used"],
                proficiency_score=score,
            ))
        else:
            result.append(TechniqueProficiencyResponse(**t))

    return result


@router.get("/gaps", response_model=list[TechniqueProficiencyResponse])
async def get_gaps(limit: int = 10, user_id: str = Depends(get_current_user)):
    """Weakest techniques sorted by proficiency score ascending (score 0 = never tried)."""
    client = await get_client()

    techniques_resp = await (
        client.table("techniques").select("*").execute()
    )
    techniques = techniques_resp.data or []

    prof_resp = await (
        client.table("user_technique_proficiency")
        .select("technique_id, times_used, avg_rating, last_used")
        .eq("user_id", user_id)
        .execute()
    )
    prof_map = {r["technique_id"]: r for r in (prof_resp.data or [])}

    enriched = []
    for t in techniques:
        p = prof_map.get(t["id"])
        if p:
            score = _live_score(p["times_used"], p["avg_rating"] or 0.0, p["last_used"])
            enriched.append(TechniqueProficiencyResponse(
                **t,
                times_used=p["times_used"],
                avg_rating=p["avg_rating"] or 0.0,
                last_used=p["last_used"],
                proficiency_score=score,
            ))
        else:
            enriched.append(TechniqueProficiencyResponse(**t))

    enriched.sort(key=lambda x: x.proficiency_score)
    return enriched[:limit]
