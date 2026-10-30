"""XP curve math. The single source of truth for how xp_table.json is built.

xp_to_next(L) = reference_xp_per_minute * reward_scale(L) * pace_minutes(L), rounded.

- reward_scale(L) grows in a straight line with level. The game multiplies every
  level-1 XP and currency reward by it, so rewards keep pace with the curve.
- pace_minutes(L) is how many minutes of normal play level L should take. It is a
  straight-line blend between the designer's pace_points.

So "minutes per level" is designed directly, and the XP numbers follow from it.
"""

from __future__ import annotations

import math
from typing import Any, Sequence


def reward_scale(level: int, curve: dict[str, Any]) -> float:
    return 1.0 + (level - 1) * curve["reward_growth_per_level"]


def pace_minutes(level: int, curve: dict[str, Any]) -> float:
    points: Sequence[Sequence[float]] = curve["pace_points"]
    if level <= points[0][0]:
        return float(points[0][1])
    for (l0, m0), (l1, m1) in zip(points, points[1:]):
        if level <= l1:
            t = (level - l0) / (l1 - l0)
            return m0 + (m1 - m0) * t
    return float(points[-1][1])


def _round_half_up(value: float, step: int) -> int:
    # Explicit rounding (not Python's banker's rounding) so any engine can reproduce it.
    return int(math.floor(value / step + 0.5)) * step


def xp_to_next(level: int, curve: dict[str, Any]) -> int:
    raw = curve["reference_xp_per_minute"] * reward_scale(level, curve) * pace_minutes(level, curve)
    return max(curve["round_to"], _round_half_up(raw, curve["round_to"]))


def build_table(curve: dict[str, Any], level_cap: int) -> list[int]:
    """XP needed for each level-up: item [0] is level 1 -> 2, the last is (cap-1) -> cap."""
    return [xp_to_next(level, curve) for level in range(1, level_cap)]


def total_xp_for_level(table: Sequence[int], level: int) -> int:
    """Total XP needed to reach `level` from level 1."""
    return sum(table[: level - 1])


def level_from_total_xp(table: Sequence[int], total_xp: int) -> int:
    """Level for a total XP amount. Can never exceed the cap (len(table) + 1)."""
    level = 1
    remaining = max(0, total_xp)
    for need in table:
        if remaining < need:
            break
        remaining -= need
        level += 1
    return level


def check_pace_points(curve: dict[str, Any], level_cap: int) -> list[str]:
    """Problems with the pace points themselves (returned as messages)."""
    problems = []
    points = curve["pace_points"]
    levels = [p[0] for p in points]
    if levels[0] != 1:
        problems.append("pace_points must start at level 1")
    if levels[-1] != level_cap - 1:
        problems.append(f"pace_points must end at level {level_cap - 1} (the last level-up)")
    for a, b in zip(levels, levels[1:]):
        if b <= a:
            problems.append(f"pace_points levels must increase: {a} then {b}")
    for level, minutes in points:
        if level != int(level):
            problems.append(f"pace_points level {level} must be a whole number")
        if minutes <= 0:
            problems.append(f"pace_points minutes at level {level} must be above 0")
    return problems
