#!/usr/bin/env python3
"""Run every check in the project and print one summary. Run this before every commit.

Usage:
    python3 tools/check_all.py

Steps that need tools you have not installed yet (Selene, StyLua, Rojo) are reported
as SKIPPED, never as passed.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PY = sys.executable


def step(name: str, command: list[str], tool: str | None = None) -> tuple[str, str]:
    if tool and shutil.which(tool) is None:
        return name, f"SKIPPED ({tool} is not installed; see docs/SETUP.md)"
    print(f"\n=== {name}\n$ {' '.join(command)}", flush=True)
    completed = subprocess.run(command, cwd=REPO)
    return name, "PASS" if completed.returncode == 0 else f"FAIL (exit code {completed.returncode})"


def main() -> int:
    results = [
        step("Validate shared-data", [PY, "tools/validate_data.py", "--strict"]),
        step("XP curve design targets", [PY, "tools/xp_sim/xp_sim.py"]),
        step("Generated Luau is up to date", [PY, "tools/convert_to_luau.py", "--check"]),
        step("Asset docs are up to date", [PY, "tools/gen_asset_docs.py", "--check"]),
        step("Tool unit tests", [PY, "tools/run_tests.py"]),
        step("Luau lint (Selene)", ["selene", "roblox-game/src"], tool="selene"),
        step("Luau format check (StyLua)", ["stylua", "--check", "roblox-game/src"], tool="stylua"),
        step("Roblox place build (Rojo)", ["rojo", "build", "roblox-game", "-o", "builds/SoulsBeyondEclipse.rbxl"], tool="rojo"),
    ]
    print("\n=== Summary")
    width = max(len(name) for name, _ in results)
    for name, outcome in results:
        print(f"  {name:<{width}}  {outcome}")
    failed = [name for name, outcome in results if outcome.startswith("FAIL")]
    skipped = [name for name, outcome in results if outcome.startswith("SKIPPED")]
    if failed:
        print(f"\nFAIL: {len(failed)} step(s) failed.")
        return 1
    note = f" ({len(skipped)} skipped: not checked, not passed)" if skipped else ""
    print(f"\nPASS: every step that ran passed{note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
