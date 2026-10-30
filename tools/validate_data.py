#!/usr/bin/env python3
"""Check every file in shared-data/ before anything uses it.

Usage:
    python3 tools/validate_data.py            # check, print a report
    python3 tools/validate_data.py --strict   # also fail on warnings

Exit code 0 = all good, 1 = problems found.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sbe_tools.catalog import SHARED_DATA  # noqa: E402
from sbe_tools.validation import validate_all  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, default=SHARED_DATA, help="shared-data folder to check")
    parser.add_argument("--strict", action="store_true", help="treat warnings as errors")
    parser.add_argument("--quiet", action="store_true", help="only print problems and the final line")
    args = parser.parse_args(argv)

    report = validate_all(args.data)

    if not args.quiet:
        print("Souls Beyond: Eclipse - shared-data check")
        print(f"  {len(report.files)} data files, {report.schema_count} schemas, {len(report.registry)} ids")
        counts = report.status_counts()
        if counts:
            print("  Build status of entries (concept = idea only, data_only = not in the game yet):")
            for kind, counter in counts.items():
                summary = ", ".join(f"{status} {n}" for status, n in sorted(counter.items()))
                print(f"    {kind:<17} {summary}")
    for warning in report.warnings:
        print(f"  WARNING  {warning}")
    for error in report.errors:
        print(f"  ERROR    {error}")

    failed = bool(report.errors) or (args.strict and bool(report.warnings))
    verdict = "FAIL" if failed else "PASS"
    print(f"{verdict}: {len(report.errors)} errors, {len(report.warnings)} warnings")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
