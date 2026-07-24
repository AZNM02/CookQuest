from datetime import date, timedelta


def compute_new_streak(
    current_streak: int,
    longest_streak: int,
    last_cooked_date: str | None,
    session_date: date,
) -> tuple[int, int]:
    """
    Pure function — returns (new_streak_count, new_longest_streak).
    session_date is the date being logged (not necessarily today).
    """
    if last_cooked_date is None:
        new_streak = 1
    else:
        last_date = date.fromisoformat(last_cooked_date)
        if last_date >= session_date:
            # Already cooked on or after this date — no change
            new_streak = current_streak
        elif last_date == session_date - timedelta(days=1):
            # Consecutive day — extend streak
            new_streak = current_streak + 1
        else:
            # Gap — reset
            new_streak = 1

    new_longest = max(longest_streak, new_streak)
    return new_streak, new_longest
