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
    technique_names: list[str] = []


@router.get("", response_model=list[RecipeResponse])
async def get_recipes(cuisine_type: Optional[str] = None, difficulty: Optional[str] = None):
    client = await get_client()

    query = client.table("recipes").select("*").order("name")
    if cuisine_type:
        query = query.eq("cuisine_type", cuisine_type)
    if difficulty:
        query = query.eq("difficulty", difficulty)
    resp = await query.execute()
    recipes = resp.data or []

    if not recipes:
        return []

    # Attach technique names
    recipe_ids = [r["id"] for r in recipes]
    rt_resp = await (
        client.table("recipe_techniques")
        .select("recipe_id, technique_id")
        .in_("recipe_id", recipe_ids)
        .execute()
    )
    recipe_tech_ids: dict[int, list[int]] = {}
    all_tech_ids: set[int] = set()
    for row in rt_resp.data or []:
        recipe_tech_ids.setdefault(row["recipe_id"], []).append(row["technique_id"])
        all_tech_ids.add(row["technique_id"])

    tech_names: dict[int, str] = {}
    if all_tech_ids:
        names_resp = await (
            client.table("techniques")
            .select("id, name")
            .in_("id", list(all_tech_ids))
            .execute()
        )
        tech_names = {t["id"]: t["name"] for t in (names_resp.data or [])}

    return [
        RecipeResponse(
            **r,
            technique_names=[
                tech_names[tid]
                for tid in recipe_tech_ids.get(r["id"], [])
                if tid in tech_names
            ],
        )
        for r in recipes
    ]
