import math


def calculate_xp(
    self_rating: int,
    difficulty_felt: int,
    techniques_used: list[int],
    technique_records: list[dict],
) -> int:
    base_xp = 50
    rating_bonus = (self_rating - 3) * 10      # -20 to +20
    difficulty_bonus = difficulty_felt * 5      # 5 to 25

    technique_xp = 0
    times_used_map = {r["technique_id"]: r["times_used"] for r in technique_records}
    for tid in techniques_used:
        times_used = times_used_map.get(tid, 0)
        if times_used == 0:
            technique_xp += 30    # first time bonus
        elif times_used < 3:
            technique_xp += 15    # still learning
        else:
            technique_xp += 5     # practised

    return max(10, base_xp + rating_bonus + difficulty_bonus + technique_xp)


def get_level_from_xp(xp: int) -> int:
    return max(1, int(1 + math.sqrt(xp / 250)))


def get_xp_for_level(level: int) -> int:
    """Minimum XP required to reach this level."""
    return 250 * (level - 1) ** 2
