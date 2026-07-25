from anthropic import AsyncAnthropic
from config import settings

_client: AsyncAnthropic | None = None


def get_anthropic_client() -> AsyncAnthropic:
    global _client
    if _client is None:
        _client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    return _client


SYSTEM_PROMPT_TEMPLATE = """You are CookQuest AI, a friendly and encouraging cooking coach embedded in the CookQuest app.

The user's current cooking level is: Level {level} ({xp} XP)
Their strongest techniques: {strong_techniques}
Their weakest techniques / areas to improve: {weak_techniques}
Number of cooking sessions logged: {session_count}

Guidelines:
- Calibrate advice to their exact skill level — don't overwhelm a beginner with advanced technique jargon
- Be encouraging but honest when they rate themselves poorly
- Reference their weak techniques naturally when giving tips
- Keep responses concise and actionable
- Use metric measurements (grams, ml) for quantities"""


async def build_system_prompt(client, user_id: str) -> str:
    """Fetch user context and fill the system prompt template."""
    profile_resp = await client.table("profiles").select("xp, level").eq("id", user_id).execute()
    profile = profile_resp.data[0] if profile_resp.data else {"xp": 0, "level": 1}

    sessions_resp = await (
        client.table("cooking_sessions")
        .select("id")
        .eq("user_id", user_id)
        .execute()
    )
    session_count = len(sessions_resp.data or [])

    prof_resp = await (
        client.table("user_technique_proficiency")
        .select("technique_id, proficiency_score, times_used")
        .eq("user_id", user_id)
        .order("proficiency_score", desc=True)
        .execute()
    )
    prof_records = prof_resp.data or []

    if prof_records:
        tech_ids = [r["technique_id"] for r in prof_records]
        tech_resp = await (
            client.table("techniques").select("id, name").in_("id", tech_ids).execute()
        )
        name_map = {t["id"]: t["name"] for t in (tech_resp.data or [])}

        sorted_by_score = sorted(prof_records, key=lambda r: r["proficiency_score"], reverse=True)
        strong = [name_map[r["technique_id"]] for r in sorted_by_score[:3] if r["technique_id"] in name_map]
        weak = [name_map[r["technique_id"]] for r in sorted_by_score[-3:] if r["technique_id"] in name_map]
    else:
        strong, weak = [], []

    return SYSTEM_PROMPT_TEMPLATE.format(
        level=profile["level"],
        xp=profile["xp"],
        strong_techniques=", ".join(strong) if strong else "None yet",
        weak_techniques=", ".join(weak) if weak else "None yet",
        session_count=session_count,
    )
