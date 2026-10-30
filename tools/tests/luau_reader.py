"""A tiny reader for the subset of Luau that the converter writes.

Used only by tests: it parses a generated module back into Python values, so we
can prove the Luau holds exactly the same data as the JSON. It is strict on
purpose and also checks that every table is wrapped in freeze(...).

This is NOT a full Luau parser and does not prove the code compiles in Roblox.
That is checked separately by Selene / Rojo / Roblox Studio once installed.
"""

from __future__ import annotations

import re

EMPTY = object()  # "{}" in Luau: could have been an empty JSON array or object

_TOKEN = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<comment>--[^\n]*)
  | (?P<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)
  | (?P<string>"(?:[^"\\\n]|\\.)*")
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<punct>[{}()\[\],=.])
    """,
    re.VERBOSE,
)


class LuauReadError(ValueError):
    pass


def _tokens(source: str) -> list[tuple[str, str]]:
    out = []
    pos = 0
    while pos < len(source):
        match = _TOKEN.match(source, pos)
        if not match:
            raise LuauReadError(f"unexpected character {source[pos]!r} at {pos}")
        kind = match.lastgroup
        if kind not in ("ws", "comment"):
            out.append((kind, match.group()))
        pos = match.end()
    return out


def _unescape(literal: str) -> str:
    body = literal[1:-1]
    out = []
    i = 0
    while i < len(body):
        char = body[i]
        if char != "\\":
            out.append(char)
            i += 1
            continue
        nxt = body[i + 1]
        simple = {"\\": "\\", '"': '"', "n": "\n", "r": "\r", "t": "\t"}
        if nxt in simple:
            out.append(simple[nxt])
            i += 2
        elif nxt.isdigit():
            digits = re.match(r"\d{1,3}", body[i + 1:]).group()
            out.append(chr(int(digits)))
            i += 1 + len(digits)
        else:
            raise LuauReadError(f"unsupported escape \\{nxt}")
    return "".join(out)


class _Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.i = 0

    def peek(self, offset=0):
        index = self.i + offset
        return self.tokens[index] if index < len(self.tokens) else ("eof", "")

    def take(self, value=None, kind=None):
        token = self.peek()
        if (value is not None and token[1] != value) or (kind is not None and token[0] != kind):
            raise LuauReadError(f"expected {value or kind}, got {token[1]!r}")
        self.i += 1
        return token

    def expr(self):
        kind, value = self.peek()
        if kind == "name" and value == "freeze":
            self.take("freeze")
            self.take("(")
            table = self.table()
            self.take(")")
            return table
        if kind == "punct" and value == "{":
            raise LuauReadError("found a table that is not wrapped in freeze(...)")
        if kind == "string":
            self.i += 1
            return _unescape(value)
        if kind == "number":
            self.i += 1
            return float(value) if any(c in value for c in ".eE") else int(value)
        if kind == "name" and value in ("true", "false"):
            self.i += 1
            return value == "true"
        raise LuauReadError(f"unexpected {value!r}")

    def table(self):
        self.take("{")
        keyed, positional = {}, []
        while self.peek()[1] != "}":
            kind, value = self.peek()
            if kind == "name" and self.peek(1)[1] == "=" and value not in ("true", "false"):
                self.i += 2
                key = value
            elif value == "[":
                self.take("[")
                key = _unescape(self.take(kind="string")[1])
                self.take("]")
                self.take("=")
            else:
                positional.append(self.expr())
                key = None
            if key is not None:
                if key in keyed:
                    raise LuauReadError(f"duplicate key {key!r}")
                keyed[key] = self.expr()
            if self.peek()[1] == ",":
                self.take(",")
            elif self.peek()[1] != "}":
                raise LuauReadError(f"expected , or }} but got {self.peek()[1]!r}")
        self.take("}")
        if keyed and positional:
            raise LuauReadError("table mixes keys and list items")
        if not keyed and not positional:
            return EMPTY
        return keyed if keyed else positional


def read_module(source: str):
    """Parse a generated module and return the value after `return`."""
    tokens = _tokens(source)
    expected_prelude = [("name", "local"), ("name", "freeze"), ("punct", "="), ("name", "table"), ("punct", "."), ("name", "freeze"), ("name", "return")]
    if tokens[: len(expected_prelude)] != expected_prelude:
        raise LuauReadError("module must start with 'local freeze = table.freeze' then 'return'")
    parser = _Parser(tokens[len(expected_prelude):])
    value = parser.expr()
    if parser.peek()[0] != "eof":
        raise LuauReadError(f"unexpected text after the returned value: {parser.peek()[1]!r}")
    return value


def same_data(luau_value, json_value) -> bool:
    """Deep comparison. An empty Luau table matches an empty JSON array or object."""
    if luau_value is EMPTY:
        return json_value == [] or json_value == {}
    if isinstance(json_value, bool) or isinstance(luau_value, bool):
        return isinstance(json_value, bool) and isinstance(luau_value, bool) and json_value == luau_value
    if isinstance(json_value, (int, float)) and isinstance(luau_value, (int, float)):
        return json_value == luau_value and type(json_value) is type(luau_value)
    if isinstance(json_value, list):
        return isinstance(luau_value, list) and len(luau_value) == len(json_value) and all(
            same_data(a, b) for a, b in zip(luau_value, json_value)
        )
    if isinstance(json_value, dict):
        return isinstance(luau_value, dict) and luau_value.keys() == json_value.keys() and all(
            same_data(luau_value[k], json_value[k]) for k in json_value
        )
    return luau_value == json_value
