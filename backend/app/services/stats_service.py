"""XP and leveling system."""

import math


def xp_for_level(level: int) -> int:
    """Total XP required to reach a given level."""
    # Quadratic scaling: level 1 = 0, level 2 = 100, level 3 = 250, ...
    if level <= 1:
        return 0
    return int(50 * (level - 1) ** 1.5)


def level_from_xp(total_xp: int) -> int:
    """Calculate level from total XP."""
    level = 1
    while xp_for_level(level + 1) <= total_xp:
        level += 1
    return level


def calculate_xp(score: int, total: int) -> int:
    """Calculate XP earned from a quiz attempt."""
    if total == 0:
        return 0
    percentage = score / total
    base_xp = total * 10  # 10 XP per question
    # Score multiplier: 100% = 2x, 50% = 1x, 0% = 0.5x
    multiplier = 0.5 + (percentage * 1.5)
    return int(base_xp * multiplier)
