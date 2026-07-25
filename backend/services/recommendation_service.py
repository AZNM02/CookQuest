DIFFICULTY_ORDER = ["beginner", "intermediate", "advanced"]


def max_difficulty_for_level(level: int) -> str:
    """Return the hardest difficulty tier a user at this level should attempt."""
    if level <= 2:
        return "beginner"
    if level <= 5:
        return "intermediate"
    return "advanced"


async def recommend_recipes(client, user_id: str, limit: int = 5) -> list[dict]:
    """
    Rule-based recipe recommendations:
    1. Identify user's weak techniques (score < 40 or never used)
    2. Fetch all recipes with their required techniques
    3. Score each recipe by how many weak techniques it targets
    4. Filter to difficulty range appropriate for the user's level
    5. Return top `limit` by gap coverage score
    """
    # Get user level
    profile_resp = await (
        client.table("profiles").select("level").eq("id", user_id).execute()
    )
    level = profile_resp.data[0]["level"] if profile_resp.data else 1
    max_diff = max_difficulty_for_level(level)
    allowed_tiers = DIFFICULTY_ORDER[: DIFFICULTY_ORDER.index(max_diff) + 1]

    # Get user proficiency map
    prof_resp = await (
        client.table("user_technique_proficiency")
        .select("technique_id, proficiency_score, times_used")
        .eq("user_id", user_id)
        .execute()
    )
    prof_map = {
        r["technique_id"]: r for r in (prof_resp.data or [])
    }

    # Techniques are "weak" if never tried or proficiency_score < 40
    weak_ids: set[int] = set()
    all_tech_resp = await client.table("techniques").select("id").execute()
    for t in all_tech_resp.data or []:
        p = prof_map.get(t["id"])
        if p is None or p["times_used"] == 0 or p["proficiency_score"] < 40:
            weak_ids.add(t["id"])

    # Get recipes within difficulty range
    recipes_resp = await (
        client.table("recipes")
        .select("*")
        .in_("difficulty", allowed_tiers)
        .execute()
    )
    recipes = recipes_resp.data or []
    if not recipes:
        return []

    # Fetch technique links for all these recipes in one query
    recipe_ids = [r["id"] for r in recipes]
    rt_resp = await (
        client.table("recipe_techniques")
        .select("recipe_id, technique_id")
        .in_("recipe_id", recipe_ids)
        .execute()
    )
    # Build map: recipe_id → list of technique_ids
    recipe_techs: dict[int, list[int]] = {}
    for row in rt_resp.data or []:
        recipe_techs.setdefault(row["recipe_id"], []).append(row["technique_id"])

    # Fetch technique names for weak techniques
    if weak_ids:
        names_resp = await (
            client.table("techniques")
            .select("id, name")
            .in_("id", list(weak_ids))
            .execute()
        )
        weak_names = {r["id"]: r["name"] for r in (names_resp.data or [])}
    else:
        weak_names = {}

    # Score each recipe
    scored = []
    for recipe in recipes:
        required = recipe_techs.get(recipe["id"], [])
        targeted_weak = [tid for tid in required if tid in weak_ids]
        gap_score = len(targeted_weak)
        scored.append({
            **recipe,
            "gap_score": gap_score,
            "weak_techniques_targeted": [weak_names[tid] for tid in targeted_weak if tid in weak_names],
            "technique_ids": required,
        })

    # Sort: gap_score desc, then difficulty asc (easier first on ties)
    scored.sort(
        key=lambda r: (-r["gap_score"], DIFFICULTY_ORDER.index(r["difficulty"]))
    )
    return scored[:limit]
