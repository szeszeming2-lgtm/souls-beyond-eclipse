"""Shared test helpers."""

from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from sbe_tools import jsonio  # noqa: E402
from sbe_tools.validation import Report, validate_all  # noqa: E402

REPO = TOOLS.parent
SHARED = REPO / "shared-data"


class DataSandbox:
    """A temporary copy of shared-data that a test can break without touching the real files."""

    def __enter__(self) -> "DataSandbox":
        self._tmp = tempfile.mkdtemp(prefix="sbe-test-")
        self.root = Path(self._tmp) / "shared-data"
        shutil.copytree(SHARED, self.root)
        return self

    def __exit__(self, *exc: object) -> None:
        shutil.rmtree(self._tmp, ignore_errors=True)

    def load(self, rel: str) -> Any:
        return jsonio.load(self.root / rel)

    def save(self, rel: str, data: Any) -> None:
        (self.root / rel).write_text(jsonio.dumps_pretty(data), encoding="utf-8")

    def edit(self, rel: str, change: Callable[[Any], None]) -> None:
        data = self.load(rel)
        change(data)
        self.save(rel, data)

    def validate(self) -> Report:
        return validate_all(self.root)


def find(entries: list[dict], ident: str) -> dict:
    return next(e for e in entries if e["id"] == ident)
