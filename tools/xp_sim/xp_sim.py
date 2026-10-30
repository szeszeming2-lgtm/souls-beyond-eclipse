#!/usr/bin/env python3
"""XP curve simulator for levels 1-3000.

What it does:
  1. Builds the XP table from shared-data/progression/progression.json.
  2. Simulates three play styles and reports how many hours each needs to reach
     key levels.
  3. Checks the design targets from the brief and exits with code 1 if any fail.

Usage:
    python3 tools/xp_sim/xp_sim.py                 # report + target check
    python3 tools/xp_sim/xp_sim.py --write-table   # also regenerate xp_table.json
    python3 tools/xp_sim/xp_sim.py --csv out.csv   # per-level numbers for a spreadsheet

Honest limits of this model (Phase 0 draft):
  - It treats the play-style mix as an average. It does not yet run out of story
    content, which a real player eventually does. Phase 3 replaces the mix with
    real content counts.
  - It ignores the catch-up bonus and level-sync, which only make leveling faster.
"""

from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sbe_tools import jsonio, xp_curve  # noqa: E402
from sbe_tools.catalog import SHARED_DATA  # noqa: E402

PROGRESSION_PATH = SHARED_DATA / "progression" / "progression.json"
TABLE_PATH = SHARED_DATA / "progression" / "xp_table.json"
REPORT_LEVELS = (10, 50, 100, 250, 500, 700, 1000, 1700, 2000, 2700, 3000)

# Design targets from the brief. "about 5 hours" is read as 4-6 hours.
TARGET_HOURS_TO_100 = (4.0, 6.0)
TARGET_MIN_HOURS_TO_CAP = 150.0


@dataclass(frozen=True)
class PlayStyle:
    name: str
    description: str
    mix: dict[str, float]  # share of play time per xp_source kind (sums to 1)
    efficiency: float  # share of time actually earning XP (the rest is travel, menus, deaths)
    same_enemy_grind: bool = False


PLAY_STYLES = (
    PlayStyle(
        "normal",
        "Varied play: story, side quests, exploring, fights, bosses.",
        {
            "story_mission": 0.28, "side_quest": 0.20, "exploration": 0.10, "combat": 0.15,
            "boss": 0.06, "dungeon": 0.08, "training": 0.05, "faction_mission": 0.08,
        },
        efficiency=0.92,
    ),
    PlayStyle(
        "casual",
        "Same mix, but more wandering, menus and retries.",
        {
            "story_mission": 0.28, "side_quest": 0.20, "exploration": 0.10, "combat": 0.15,
            "boss": 0.06, "dungeon": 0.08, "training": 0.05, "faction_mission": 0.08,
        },
        efficiency=0.65,
    ),
    PlayStyle(
        "grinder",
        "Only kills the same field enemy over and over.",
        {"combat": 1.0},
        efficiency=1.0,
        same_enemy_grind=True,
    ),
)


def load_progression() -> dict:
    return jsonio.load(PROGRESSION_PATH)


def kind_rates(progression: dict) -> dict[str, float]:
    """Average XP per minute at level 1 for each source kind."""
    totals: dict[str, list[float]] = {}
    for source in progression["xp_sources"]:
        totals.setdefault(source["kind"], []).append(source["base_xp"] / source["typical_minutes"])
    return {kind: sum(rates) / len(rates) for kind, rates in totals.items()}


def grind_multiplier(progression: dict) -> float:
    """Average XP multiplier for someone who kills the same enemy nonstop (anti-grind rule)."""
    rules = progression["anti_grind"]
    field_enemy = next(s for s in progression["xp_sources"] if s["kind"] == "combat")
    kills_per_window = max(1, int(rules["window_s"] / (field_enemy["typical_minutes"] * 60)))
    total = 0.0
    for kill in range(kills_per_window):
        extra = kill - rules["full_reward_kills"] + 1
        factor = 1.0 if extra <= 0 else max(rules["floor_multiplier"], rules["decay_per_kill"] ** extra)
        total += factor
    return total / kills_per_window


def level1_income(style: PlayStyle, progression: dict) -> float:
    """XP per minute at level 1 for a play style (before the reward scale)."""
    rates = kind_rates(progression)
    missing = [kind for kind in style.mix if kind not in rates]
    if missing:
        raise SystemExit(f"play style {style.name!r} uses source kinds with no xp_sources entry: {missing}")
    income = sum(share * rates[kind] for kind, share in style.mix.items()) * style.efficiency
    if style.same_enemy_grind:
        income *= grind_multiplier(progression)
    return income


def hours_to_levels(style: PlayStyle, progression: dict, table: list[int]) -> list[float]:
    """Cumulative hours to reach each level (index 0 = level 1 = 0 hours)."""
    curve = progression["xp_curve"]
    base_income = level1_income(style, progression)
    hours = [0.0]
    for level, need in enumerate(table, start=1):
        per_minute = base_income * xp_curve.reward_scale(level, curve)
        hours.append(hours[-1] + need / per_minute / 60)
    return hours


def write_table(progression: dict) -> list[int]:
    table = xp_curve.build_table(progression["xp_curve"], progression["level_cap"])
    payload = {
        "$schema": "../schemas/xp_table.schema.json",
        "generated_by": "tools/xp_sim/xp_sim.py",
        "level_cap": progression["level_cap"],
        "xp_to_next": table,
    }
    TABLE_PATH.write_text(jsonio.dumps_pretty(payload), encoding="utf-8")
    return table


def run(write: bool, csv_path: Path | None) -> int:
    progression = load_progression()
    curve = progression["xp_curve"]
    cap = progression["level_cap"]
    problems = xp_curve.check_pace_points(curve, cap)
    if problems:
        for problem in problems:
            print(f"ERROR pace_points: {problem}")
        return 1

    table = write_table(progression) if write else xp_curve.build_table(curve, cap)
    if write:
        print(f"Wrote {TABLE_PATH.relative_to(SHARED_DATA.parent)} ({len(table)} level-ups)")

    print("XP curve summary")
    for level in (1, 10, 50, 100, 500, 1000, 2000, 2999):
        print(f"  level {level:>4} -> {level + 1:<4} needs {table[level - 1]:>8,} XP")
    total = xp_curve.total_xp_for_level(table, cap)
    print(f"  total XP to reach {cap}: {total:,}")
    if xp_curve.level_from_total_xp(table, total * 10) != cap:
        print("ERROR: level can exceed the cap")
        return 1

    results = {style.name: hours_to_levels(style, progression, table) for style in PLAY_STYLES}
    print("\nHours of play to reach each level")
    header = "  level " + "".join(f"{s.name:>10}" for s in PLAY_STYLES)
    print(header)
    for level in REPORT_LEVELS:
        print(f"  {level:>5} " + "".join(f"{results[s.name][level - 1]:>10.1f}" for s in PLAY_STYLES))
    for style in PLAY_STYLES:
        print(f"  {style.name}: {style.description} ({level1_income(style, progression):.0f} XP/min at level 1)")

    normal_income = level1_income(PLAY_STYLES[0], progression)
    reference = curve["reference_xp_per_minute"]
    drift = abs(normal_income - reference) / reference

    checks = []
    hours_100 = results["normal"][99]
    checks.append((TARGET_HOURS_TO_100[0] <= hours_100 <= TARGET_HOURS_TO_100[1],
                   f"levels 1-100 take about 5 hours of normal play ({hours_100:.1f} h)"))
    hours_cap = results["normal"][cap - 1]
    checks.append((hours_cap >= TARGET_MIN_HOURS_TO_CAP,
                   f"reaching {cap} takes {TARGET_MIN_HOURS_TO_CAP:.0f}+ hours ({hours_cap:.0f} h)"))
    checks.append((results["grinder"][cap - 1] > hours_cap * 1.5,
                   f"grinding one enemy is clearly slower than varied play "
                   f"({results['grinder'][cap - 1]:.0f} h vs {hours_cap:.0f} h)"))
    checks.append((drift <= 0.10,
                   f"content rewards match the curve's reference income within 10% "
                   f"({normal_income:.0f} vs {reference} XP/min)"))
    minutes = [xp_curve.pace_minutes(level, curve) for level in range(1, cap)]
    checks.append((all(b >= a for a, b in zip(minutes, minutes[1:])),
                   "levels never get faster to complete as you go up"))
    late_ratio = minutes[-1] / minutes[99]
    checks.append((late_ratio <= 1.5,
                   f"late levels slow gradually, no wall (level 2999 takes {late_ratio:.2f}x level 100)"))

    print("\nDesign targets")
    failed = 0
    for ok, text in checks:
        print(f"  {'PASS' if ok else 'FAIL'}  {text}")
        failed += 0 if ok else 1

    if csv_path:
        with csv_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["level", "xp_to_next", "pace_minutes"] + [f"hours_{s.name}" for s in PLAY_STYLES])
            for level in range(1, cap):
                writer.writerow([level, table[level - 1], round(minutes[level - 1], 3)]
                                + [round(results[s.name][level - 1], 3) for s in PLAY_STYLES])
        print(f"\nWrote per-level numbers to {csv_path}")

    print(f"\n{'FAIL' if failed else 'PASS'}: {len(checks) - failed} of {len(checks)} targets met")
    return 1 if failed else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write-table", action="store_true", help="regenerate shared-data/progression/xp_table.json")
    parser.add_argument("--csv", type=Path, help="write per-level numbers to this CSV file")
    args = parser.parse_args(argv)
    return run(args.write_table, args.csv)


if __name__ == "__main__":
    sys.exit(main())
