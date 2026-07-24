from datetime import date


def compute_proficiency_score(times_used: int, avg_rating: float, last_used_days_ago: int) -> float:
    recency_decay = max(0.0, 1.0 - (last_used_days_ago / 90))
    volume_score = min(1.0, times_used / 10)
    rating_score = avg_rating / 5.0
    return round((0.4 * volume_score + 0.4 * rating_score + 0.2 * recency_decay) * 100, 1)


async def update_proficiency(
    client,
    user_id: str,
    technique_ids: list[int],
    self_rating: int,
    existing_records: list[dict],
) -> None:
    """Upsert user_technique_proficiency for each technique used in a session."""
    if not technique_ids:
        return

    today = date.today().isoformat()
    existing_map = {r["technique_id"]: r for r in existing_records}

    rows = []
    for tid in technique_ids:
        existing = existing_map.get(tid)
        if existing:
            old_times = existing["times_used"]
            old_avg = existing.get("avg_rating") or 0.0
            times_used = old_times + 1
            avg_rating = (old_avg * old_times + self_rating) / times_used
        else:
            times_used = 1
            avg_rating = float(self_rating)

        rows.append({
            "user_id": user_id,
            "technique_id": tid,
            "times_used": times_used,
            "avg_rating": round(avg_rating, 2),
            "last_used": today,
            "proficiency_score": compute_proficiency_score(times_used, avg_rating, 0),
        })

    await (
        client.table("user_technique_proficiency")
        .upsert(rows, on_conflict="user_id,technique_id")
        .execute()
    )
