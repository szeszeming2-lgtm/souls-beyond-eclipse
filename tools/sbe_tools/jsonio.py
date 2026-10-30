"""Strict JSON loading for game data.

Python's json module quietly accepts things that cause bugs later:
- duplicate keys in one object (the last one silently wins),
- NaN and Infinity (not valid JSON, and not valid in Luau or GDScript literals),
- numbers too large to store exactly in a 64-bit float (Luau and GDScript use those).

This module rejects all of them with a readable message.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

# Largest integer a double-precision float stores exactly. Luau numbers are doubles.
MAX_SAFE_INTEGER = 2**53 - 1


class DataFormatError(ValueError):
    """The text is not acceptable game-data JSON."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DataFormatError(f"duplicate key {key!r} in the same object")
        result[key] = value
    return result


def _reject_constant(name: str) -> Any:
    raise DataFormatError(f"{name} is not allowed in game data")


def _check_numbers(value: Any, where: str) -> None:
    if isinstance(value, bool):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise DataFormatError(f"{where or 'value'}: number is too large (not finite)")
        if abs(value) > MAX_SAFE_INTEGER:
            raise DataFormatError(f"{where or 'value'}: number {value} is larger than 2^53")
    elif isinstance(value, int):
        if abs(value) > MAX_SAFE_INTEGER:
            raise DataFormatError(f"{where or 'value'}: integer {value} is larger than 2^53")
    elif isinstance(value, dict):
        for key, child in value.items():
            _check_numbers(child, f"{where}.{key}" if where else key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _check_numbers(child, f"{where}[{index}]")


def loads(text: str) -> Any:
    """Parse JSON text strictly. Raises DataFormatError on any problem."""
    if text.startswith("﻿"):  # tolerate a UTF-8 byte-order mark from some editors
        text = text[1:]
    try:
        data = json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise DataFormatError(
            f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}"
        ) from None
    _check_numbers(data, "")
    return data


def load(path: Path) -> Any:
    """Read and strictly parse a JSON file."""
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        raise DataFormatError("file is not valid UTF-8 text") from None
    return loads(text)


def dumps_pretty(data: Any) -> str:
    """Format JSON the way files in this repo are stored (2-space indent, trailing newline)."""
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"
