async def check_and_award_badges(
    client,
    user_id: str,
    new_xp: int,
    new_streak: int,
) -> list[dict]:
    """
    Check all unearned badges against current user stats.
    Inserts newly earned badges and returns their info.
    """
    earned_resp = await (
        client.table("user_badges").select("badge_id").eq("user_id", user_id).execute()
    )
    earned_ids = {r["badge_id"] for r in (earned_resp.data or [])}

    all_badges_resp = await client.table("badges").select("*").execute()
    unearned = [b for b in (all_badges_resp.data or []) if b["id"] not in earned_ids]
    if not unearned:
        return []

    # Cache stats so we don't re-query for each badge of the same type
    cache: dict = {}

    async def session_count() -> int:
        if "session_count" not in cache:
            r = await (
                client.table("cooking_sessions")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .execute()
            )
            cache["session_count"] = r.count or 0
        return cache["session_count"]

    async def cuisine_count() -> int:
        if "cuisine_count" not in cache:
            r = await (
                client.table("cooking_sessions")
                .select("cuisine_type")
                .eq("user_id", user_id)
                .execute()
            )
            cache["cuisine_count"] = len({row["cuisine_type"] for row in (r.data or [])})
        return cache["cuisine_count"]

    async def technique_count(category: str | None = None) -> int:
        key = f"technique_count_{category or '*'}"
        if key not in cache:
            prof_resp = await (
                client.table("user_technique_proficiency")
                .select("technique_id")
                .eq("user_id", user_id)
                .execute()
            )
            used_ids = {r["technique_id"] for r in (prof_resp.data or [])}

            if category:
                cat_resp = await (
                    client.table("techniques").select("id").eq("category", category).execute()
                )
                cat_ids = {t["id"] for t in (cat_resp.data or [])}
                cache[key] = len(used_ids & cat_ids)
            else:
                cache[key] = len(used_ids)
        return cache[key]

    async def used_specific_technique(technique_name: str) -> bool:
        key = f"specific_{technique_name}"
        if key not in cache:
            tech_resp = await (
                client.table("techniques").select("id").eq("name", technique_name).execute()
            )
            if not tech_resp.data:
                cache[key] = False
            else:
                tid = tech_resp.data[0]["id"]
                prof_resp = await (
                    client.table("user_technique_proficiency")
                    .select("times_used")
                    .eq("user_id", user_id)
                    .eq("technique_id", tid)
                    .execute()
                )
                cache[key] = bool(prof_resp.data and prof_resp.data[0]["times_used"] > 0)
        return cache[key]

    newly_earned = []
    for badge in unearned:
        ctype = badge["unlock_condition_type"]
        cvalue = badge["unlock_condition_value"]
        cextra = badge.get("unlock_condition_extra")

        unlocked = False
        if ctype == "xp":
            unlocked = new_xp >= cvalue
        elif ctype == "streak":
            unlocked = new_streak >= cvalue
        elif ctype == "session_count":
            unlocked = await session_count() >= cvalue
        elif ctype == "cuisine_count":
            unlocked = await cuisine_count() >= cvalue
        elif ctype == "technique_count":
            unlocked = await technique_count(cextra) >= cvalue
        elif ctype == "specific_technique" and cextra:
            unlocked = await used_specific_technique(cextra)

        if unlocked:
            await (
                client.table("user_badges")
                .insert({"user_id": user_id, "badge_id": badge["id"]})
                .execute()
            )
            newly_earned.append({
                "name": badge["name"],
                "icon": badge["icon"],
                "description": badge["description"],
            })

    return newly_earned
