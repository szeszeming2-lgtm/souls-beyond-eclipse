#!/usr/bin/env python3
"""Convert shared-data JSON into Luau modules for the Roblox edition.

Usage:
    python3 tools/convert_to_luau.py           # validate data, then (re)write the modules
    python3 tools/convert_to_luau.py --check   # only report whether the modules are up to date

Output: roblox-game/src/shared/GameData/ (never edit those files by hand).
The data is always validated first; nothing is written if validation fails.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sbe_tools import luau_convert  # noqa: E402
from sbe_tools.catalog import REPO_ROOT, SHARED_DATA  # noqa: E402
from sbe_tools.luau_writer import LuauWriteError  # noqa: E402
from sbe_tools.validation import validate_all  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="do not write; exit 1 if anything is out of date")
    parser.add_argument("--data", type=Path, default=SHARED_DATA)
    parser.add_argument("--out", type=Path, default=luau_convert.DEFAULT_OUTPUT)
    args = parser.parse_args(argv)

    report = validate_all(args.data)
    if not report.ok:
        for error in report.errors:
            print(f"  ERROR    {error}")
        print("FAIL: shared-data has errors, so no Luau was generated. Run tools/validate_data.py for details.")
        return 1

    try:
        result = luau_convert.plan(report.files, args.out)
    except (luau_convert.ConvertError, LuauWriteError) as exc:
        print(f"FAIL: {exc}")
        return 1

    def show(path: Path) -> str:
        try:
            return str(path.relative_to(REPO_ROOT))
        except ValueError:
            return str(path)

    if args.check:
        problems = (
            [f"out of date: {show(p)}" for p in result.changed]
            + [f"stale generated file: {show(p)}" for p in result.stale]
            + [f"hand-written file inside generated folder: {show(p)}" for p in result.foreign]
        )
        for problem in problems:
            print(f"  {problem}")
        if problems:
            print("FAIL: generated Luau is not up to date. Run: python3 tools/convert_to_luau.py")
            return 1
        print(f"PASS: {len(result.expected)} generated Luau modules are up to date")
        return 0

    try:
        luau_convert.apply(result)
    except luau_convert.ConvertError as exc:
        print(f"FAIL: {exc}")
        return 1
    print(
        f"Wrote {len(result.changed)} changed module(s), removed {len(result.stale)} stale, "
        f"{len(result.expected)} total in {show(result.output_dir)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
