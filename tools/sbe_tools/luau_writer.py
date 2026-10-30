"""Turns JSON values into Luau source code.

Rules:
- Objects and arrays become Luau tables wrapped in table.freeze, so game code
  cannot change shared data by accident at runtime.
- JSON arrays become Luau arrays, which count from 1 (JSON counts from 0).
- null is refused: Luau tables cannot hold nil, so data should leave the field out.
- Strings are written as UTF-8 with only the escapes Luau needs.
"""

from __future__ import annotations

import re
from typing import Any

LUAU_RESERVED = frozenset(
    {
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
        "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
        "continue",
    }
)
_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_SIMPLE_ESCAPES = {"\\": "\\\\", '"': '\\"', "\n": "\\n", "\r": "\\r", "\t": "\\t"}
INDENT = "\t"
FREEZE = "freeze"
INLINE_LIMIT = 100  # characters; longer arrays of numbers are wrapped


class LuauWriteError(ValueError):
    pass


def luau_string(text: str) -> str:
    out = ['"']
    for char in text:
        if char in _SIMPLE_ESCAPES:
            out.append(_SIMPLE_ESCAPES[char])
        elif ord(char) < 0x20 or ord(char) == 0x7F:
            out.append(f"\\{ord(char):03d}")
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


def luau_number(value: int | float) -> str:
    if isinstance(value, bool):
        raise LuauWriteError("booleans are not numbers")
    if isinstance(value, int):
        return str(value)
    if value != value or value in (float("inf"), float("-inf")):
        raise LuauWriteError(f"number {value} cannot be written to Luau")
    text = repr(value)  # shortest form that reads back to the same double
    return text


def luau_key(key: str) -> str:
    if _IDENTIFIER.match(key) and key not in LUAU_RESERVED:
        return key
    return f"[{luau_string(key)}]"


def _is_scalar(value: Any) -> bool:
    return isinstance(value, (str, int, float, bool))


def to_luau(value: Any, depth: int = 0, path: str = "") -> str:
    """Luau expression for a JSON value."""
    if value is None:
        raise LuauWriteError(f"{path or 'value'}: null cannot be stored in a Luau table; leave the field out instead")
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return luau_number(value)
    if isinstance(value, str):
        return luau_string(value)
    if isinstance(value, list):
        return _array(value, depth, path)
    if isinstance(value, dict):
        return _object(value, depth, path)
    raise LuauWriteError(f"{path or 'value'}: cannot convert {type(value).__name__}")


def _array(items: list, depth: int, path: str) -> str:
    if not items:
        return f"{FREEZE}({{}})"
    if all(_is_scalar(item) for item in items):
        parts = [to_luau(item, depth + 1, f"{path}[{i}]") for i, item in enumerate(items)]
        inline = f"{FREEZE}({{ {', '.join(parts)} }})"
        if len(inline) + depth * 4 <= INLINE_LIMIT:
            return inline
        # Long lists of numbers (like the XP table): several values per line.
        pad = INDENT * (depth + 1)
        lines, line = [], ""
        for part in parts:
            candidate = f"{line} {part}," if line else f"{part},"
            if len(candidate) + len(pad) * 4 > INLINE_LIMIT and line:
                lines.append(pad + line)
                line = f"{part},"
            else:
                line = candidate
        if line:
            lines.append(pad + line)
        return f"{FREEZE}({{\n" + "\n".join(lines) + f"\n{INDENT * depth}}})"
    pad = INDENT * (depth + 1)
    body = ",\n".join(pad + to_luau(item, depth + 1, f"{path}[{i}]") for i, item in enumerate(items))
    return f"{FREEZE}({{\n{body},\n{INDENT * depth}}})"


def _object(obj: dict, depth: int, path: str) -> str:
    if not obj:
        return f"{FREEZE}({{}})"
    pad = INDENT * (depth + 1)
    lines = []
    for key, val in obj.items():
        child_path = f"{path}.{key}" if path else key
        lines.append(f"{pad}{luau_key(key)} = {to_luau(val, depth + 1, child_path)}")
    return f"{FREEZE}({{\n" + ",\n".join(lines) + f",\n{INDENT * depth}}})"
