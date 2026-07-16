import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.xp_service import calculate_xp, get_level_from_xp


def test_base_xp_with_no_techniques():
    xp = calculate_xp(self_rating=3, difficulty_felt=3, techniques_used=[], technique_records=[])
    # base 50 + rating_bonus 0 + difficulty_bonus 15 = 65
    assert xp == 65


def test_first_time_technique_gives_bonus():
    xp = calculate_xp(
        self_rating=3,
        difficulty_felt=3,
        techniques_used=[1],
        technique_records=[],           # no existing record → times_used = 0
    )
    # 65 base + 30 first-time = 95
    assert xp == 95


def test_practised_technique_gives_small_bonus():
    xp = calculate_xp(
        self_rating=3,
        difficulty_felt=3,
        techniques_used=[1],
        technique_records=[{"technique_id": 1, "times_used": 5}],
    )
    # 65 + 5 = 70
    assert xp == 70


def test_learning_technique_gives_medium_bonus():
    xp = calculate_xp(
        self_rating=3,
        difficulty_felt=3,
        techniques_used=[1],
        technique_records=[{"technique_id": 1, "times_used": 2}],
    )
    # 65 + 15 = 80
    assert xp == 80


def test_high_rating_gives_bonus():
    xp = calculate_xp(self_rating=5, difficulty_felt=3, techniques_used=[], technique_records=[])
    # 50 + 20 + 15 = 85
    assert xp == 85


def test_low_rating_reduces_xp():
    xp = calculate_xp(self_rating=1, difficulty_felt=3, techniques_used=[], technique_records=[])
    # 50 - 20 + 15 = 45
    assert xp == 45


def test_minimum_xp_floor():
    xp = calculate_xp(self_rating=1, difficulty_felt=1, techniques_used=[], technique_records=[])
    # 50 - 20 + 5 = 35, but floor is 10
    assert xp >= 10


def test_multiple_techniques_mix():
    records = [
        {"technique_id": 1, "times_used": 0},   # first time: +30
        {"technique_id": 2, "times_used": 1},   # learning: +15
        {"technique_id": 3, "times_used": 10},  # practised: +5
    ]
    xp = calculate_xp(
        self_rating=3,
        difficulty_felt=3,
        techniques_used=[1, 2, 3],
        technique_records=records,
    )
    # 65 + 30 + 15 + 5 = 115
    assert xp == 115


class TestGetLevelFromXp:
    def test_level_1_at_zero_xp(self):
        assert get_level_from_xp(0) == 1

    def test_level_1_below_threshold(self):
        assert get_level_from_xp(249) == 1

    def test_level_increases_with_xp(self):
        levels = [get_level_from_xp(xp) for xp in [0, 500, 1500, 3500, 7000, 12000]]
        assert levels == sorted(levels), "Levels should be non-decreasing"

    def test_level_2_at_500_xp(self):
        # floor(1 + sqrt(500/250)) = floor(1 + sqrt(2)) = floor(2.41) = 2
        assert get_level_from_xp(500) == 2

    def test_never_below_1(self):
        assert get_level_from_xp(0) >= 1
