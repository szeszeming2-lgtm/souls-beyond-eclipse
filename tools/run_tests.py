#!/usr/bin/env python3
"""Run the automated tests for the data tools.

Usage:
    python3 tools/run_tests.py        # all tests
    python3 tools/run_tests.py -v     # list every test as it runs
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))


def main() -> int:
    verbosity = 2 if "-v" in sys.argv[1:] else 1
    suite = unittest.defaultTestLoader.discover(str(TOOLS / "tests"), top_level_dir=str(TOOLS))
    result = unittest.TextTestRunner(verbosity=verbosity).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
