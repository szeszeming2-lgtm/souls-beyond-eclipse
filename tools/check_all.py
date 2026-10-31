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
GAME = REPO / "roblox-game"
PY = sys.executable


def step(name: str, command: list[str], tool: str | None = None, cwd: Path = REPO) -> tuple[str, str]:
    if tool and shutil.which(tool) is None:
        return name, f"SKIPPED ({tool} is not installed; see docs/SETUP.md)"
    print(f"\n=== {name}\n$ {' '.join(command)}", flush=True)
    completed = subprocess.run(command, cwd=cwd)
    return name, "PASS" if completed.returncode == 0 else f"FAIL (exit code {completed.returncode})"


def packages_installed() -> tuple[str, str]:
    name = "Wally packages installed"
    if (GAME / "ServerPackages" / "ProfileStore.lua").exists():
        return name, "PASS"
    print(f"\n=== {name}\nProfileStore is missing. Run: cd roblox-game && wally install", flush=True)
    return name, "FAIL (run: cd roblox-game && wally install)"


def main() -> int:
    results = [
        step("Validate shared-data", [PY, "tools/validate_data.py", "--strict"]),
        step("XP curve design targets", [PY, "tools/xp_sim/xp_sim.py"]),
        step("Generated Luau is up to date", [PY, "tools/convert_to_luau.py", "--check"]),
        step("Asset docs are up to date", [PY, "tools/gen_asset_docs.py", "--check"]),
        step("Tool unit tests", [PY, "tools/run_tests.py"]),
        packages_installed(),
        step("Luau game rules tests (Lune)", ["lune", "run", "roblox-game/tests/run.luau"], tool="lune"),
        step("Luau lint: game (Selene)", ["selene", "roblox-game/src"], tool="selene"),
        step("Luau lint: tests (Selene)", ["selene", "."], tool="selene", cwd=GAME / "tests"),
        step("Luau format check (StyLua)", ["stylua", "--check", "roblox-game/src", "roblox-game/tests"], tool="stylua"),
        step("Rojo sourcemap", ["rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json"], tool="rojo", cwd=GAME),
        step("Luau strict type check (luau-lsp)", [
            "luau-lsp", "analyze", "--platform=roblox",
            "--definitions=@roblox=../tools/luau/globalTypes.d.luau",
            "--sourcemap=sourcemap.json",
            "--ignore=**/ServerPackages/**", "--ignore=**/GameData/**",
            "src",
        ], tool="luau-lsp", cwd=GAME),
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
