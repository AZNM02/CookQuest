import asyncio
import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from database import get_client
from dependencies import get_current_user

router = APIRouter(prefix="/recipes", tags=["recipes"])

THEMEALDB = "https://www.themealdb.com/api/json/v1/1"

AREA_TO_CUISINE: dict[str, str] = {
    "chinese": "asian", "japanese": "asian", "thai": "asian",
    "indian": "asian", "malaysian": "asian", "vietnamese": "asian",
    "filipino": "asian",
    "american": "western", "british": "western", "canadian": "western",
    "french": "western", "irish": "western", "italian": "western",
    "polish": "western", "portuguese": "western", "russian": "western",
    "spanish": "western", "dutch": "western", "croatian": "western",
    "ukrainian": "western",
    "greek": "mediterranean",
    "moroccan": "middle_eastern", "egyptian": "middle_eastern",
    "tunisian": "middle_eastern", "turkish": "middle_eastern",
}

TECHNIQUE_KEYWORDS: dict[str, list[str]] = {
    "Dice":                        ["diced", " dice "],
    "Julienne":                    ["julienne"],
    "Chiffonade":                  ["chiffonade"],
    "Brunoise":                    ["brunoise"],
    "Sauté":                       ["sauté", "saute", "sautéed", "sauteed"],
    "Stir-fry":                    ["stir-fry", "stir fry", "stir-fried", "stir fried"],
    "Pan-sear":                    ["pan-sear", "pan sear", " sear ", "seared"],
    "Simmer":                      ["simmer"],
    "Blanch":                      ["blanch"],
    "Deglaze":                     ["deglaze"],
    "Flambé":                      ["flambé", "flambe"],
    "Deep-fry":                    ["deep-fry", "deep fry", "deep-fried", "deep fried"],
    "Make a roux":                 ["roux"],
    "Emulsify (vinaigrette)":      ["vinaigrette", "emulsify"],
    "Hollandaise":                 ["hollandaise"],
    "Reduction":                   ["reduction", " reduce "],
    "Cream butter and sugar":      ["cream the butter", "cream butter"],
    "Fold batter":                 ["fold in", "folding"],
    "Laminate dough":              ["laminate"],
    "Temper chocolate":            ["temper chocolate"],
    "Marinate":                    ["marinate", "marinade"],
    "Brine":                       [" brine ", "brined"],
    "Butcher / break down chicken":["butcher", "break down chicken", "joint the chicken"],
    "Make stock":                  ["make stock", "chicken stock", "beef stock"],
}


def _difficulty(instructions: str) -> str:
    n = len(instructions)
    if n < 500:
        return "beginner"
    if n < 1100:
        return "intermediate"
    return "advanced"


async def _detect_technique_ids(instructions: str, db) -> list[int]:
    lower = instructions.lower()
    tech_resp = await db.table("techniques").select("id, name").execute()
    name_to_id = {t["name"]: t["id"] for t in (tech_resp.data or [])}
    ids = []
    for tech_name, keywords in TECHNIQUE_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            if tech_name in name_to_id:
                ids.append(name_to_id[tech_name])
    return ids


class RecipeResponse(BaseModel):
    id: int
    name: str
    cuisine_type: str
    difficulty: str
    estimated_time_mins: Optional[int] = None
    description: Optional[str] = None
    instructions: Optional[str] = None
    technique_names: list[str] = []
    is_favorited: bool = False


class RecipeListResponse(BaseModel):
    recipes: list[RecipeResponse]
    total: int


async def _attach_techniques_and_favorites(
    client, recipes: list[dict], fav_ids: set[int]
) -> list[RecipeResponse]:
    if not recipes:
        return []

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
            is_favorited=r["id"] in fav_ids,
        )
        for r in recipes
    ]


@router.get("", response_model=RecipeListResponse)
async def get_recipes(
    cuisine_type: Optional[str] = None,
    difficulty: Optional[str] = None,
    search: Optional[str] = None,
    favorites_only: bool = False,
    limit: int = 12,
    offset: int = 0,
    user_id: str = Depends(get_current_user),
):
    client = await get_client()

    fav_resp = await (
        client.table("user_recipe_favorites")
        .select("recipe_id")
        .eq("user_id", user_id)
        .execute()
    )
    fav_ids = {r["recipe_id"] for r in (fav_resp.data or [])}

    if favorites_only and not fav_ids:
        return RecipeListResponse(recipes=[], total=0)

    query = client.table("recipes").select("*", count="exact").order("name")
    if cuisine_type:
        query = query.eq("cuisine_type", cuisine_type)
    if difficulty:
        query = query.eq("difficulty", difficulty)
    if search:
        query = query.ilike("name", f"%{search}%")
    if favorites_only:
        query = query.in_("id", list(fav_ids))

    resp = await query.range(offset, offset + limit - 1).execute()
    recipes = resp.data or []
    total = resp.count or 0

    return RecipeListResponse(
        recipes=await _attach_techniques_and_favorites(client, recipes, fav_ids),
        total=total,
    )


@router.post("/{recipe_id}/favorite", status_code=204)
async def favorite_recipe(recipe_id: int, user_id: str = Depends(get_current_user)):
    client = await get_client()
    await (
        client.table("user_recipe_favorites")
        .upsert({"user_id": user_id, "recipe_id": recipe_id}, on_conflict="user_id,recipe_id")
        .execute()
    )


@router.delete("/{recipe_id}/favorite", status_code=204)
async def unfavorite_recipe(recipe_id: int, user_id: str = Depends(get_current_user)):
    client = await get_client()
    await (
        client.table("user_recipe_favorites")
        .delete()
        .eq("user_id", user_id)
        .eq("recipe_id", recipe_id)
        .execute()
    )


@router.post("/import")
async def import_recipes(
    count: int = 10,
    user_id: str = Depends(get_current_user),
):
    db = await get_client()

    async with httpx.AsyncClient(timeout=20) as http:
        responses = await asyncio.gather(
            *[http.get(f"{THEMEALDB}/random.php") for _ in range(count)],
            return_exceptions=True,
        )

    imported = 0
    seen_ids: set[str] = set()

    for resp in responses:
        if isinstance(resp, Exception):
            continue
        try:
            meals = resp.json().get("meals") or []
        except Exception:
            continue
        if not meals:
            continue
        meal = meals[0]

        meal_id = meal.get("idMeal", "")
        if meal_id in seen_ids:
            continue
        seen_ids.add(meal_id)

        name = (meal.get("strMeal") or "").strip()
        instructions = (meal.get("strInstructions") or "").strip()
        if not name or not instructions:
            continue

        existing = await db.table("recipes").select("id").eq("name", name).execute()
        if existing.data:
            continue

        ingredients = []
        for i in range(1, 21):
            ing = (meal.get(f"strIngredient{i}") or "").strip()
            measure = (meal.get(f"strMeasure{i}") or "").strip()
            if ing:
                ingredients.append(f"{measure} {ing}".strip() if measure else ing)

        full_instructions = instructions
        if ingredients:
            full_instructions = (
                "Ingredients:\n"
                + "\n".join(f"• {x}" for x in ingredients)
                + "\n\nSteps:\n"
                + instructions
            )

        area = (meal.get("strArea") or "").lower()
        cuisine = AREA_TO_CUISINE.get(area, "other")
        difficulty = _difficulty(instructions)
        description = (meal.get("strCategory") or "").strip() or None

        recipe_resp = await db.table("recipes").insert({
            "name": name,
            "cuisine_type": cuisine,
            "difficulty": difficulty,
            "description": description,
            "instructions": full_instructions,
        }).execute()

        if not recipe_resp.data:
            continue

        recipe_id = recipe_resp.data[0]["id"]
        tech_ids = await _detect_technique_ids(instructions, db)
        if tech_ids:
            await (
                db.table("recipe_techniques")
                .upsert(
                    [{"recipe_id": recipe_id, "technique_id": tid} for tid in tech_ids],
                    on_conflict="recipe_id,technique_id",
                )
                .execute()
            )
        imported += 1

    return {"imported": imported}
