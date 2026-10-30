"""A small, strict JSON Schema validator (a subset of draft 2020-12).

Why not the popular `jsonschema` package? These tools use only Python's standard
library, so there is nothing extra to install. The subset below covers every
keyword our schemas use. Any other keyword makes the schema fail to load, so a
typo in a schema can never silently switch a check off.

One extra keyword: "x-ref": ["abl", ...] marks a string as a reference to an id
with one of those prefixes. The validator collects these references so the
cross-file checks can confirm each target exists.
"""

from __future__ import annotations

import difflib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

from . import jsonio

ANNOTATION_KEYWORDS = frozenset(
    {
        "$schema",
        "$id",
        "$comment",
        "title",
        "description",
        "markdownDescription",
        "default",
        "examples",
        "deprecated",
    }
)

VALIDATION_KEYWORDS = frozenset(
    {
        "$ref",
        "$defs",
        "type",
        "enum",
        "const",
        "properties",
        "required",
        "additionalProperties",
        "patternProperties",
        "propertyNames",
        "minProperties",
        "maxProperties",
        "items",
        "minItems",
        "maxItems",
        "uniqueItems",
        "minLength",
        "maxLength",
        "pattern",
        "minimum",
        "maximum",
        "exclusiveMinimum",
        "exclusiveMaximum",
        "multipleOf",
        "allOf",
        "anyOf",
        "oneOf",
        "not",
        "if",
        "then",
        "else",
        "x-ref",
    }
)

JSON_TYPES = frozenset({"object", "array", "string", "integer", "number", "boolean", "null"})
_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class SchemaError(Exception):
    """A schema file itself is broken (unknown keyword, bad $ref, invalid regex...)."""


@dataclass(frozen=True)
class Issue:
    path: str
    message: str


@dataclass(frozen=True)
class Reference:
    """A string value that must be the id of an existing entry."""

    path: str
    value: str
    kinds: tuple[str, ...]


@dataclass
class Result:
    errors: list[Issue] = field(default_factory=list)
    refs: list[Reference] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    def merge(self, other: "Result") -> None:
        self.errors.extend(other.errors)
        self.refs.extend(other.refs)


def format_path(parts: Iterable[str | int]) -> str:
    out = ""
    for part in parts:
        if isinstance(part, int):
            out += f"[{part}]"
        elif _IDENTIFIER.match(part) or part.startswith("$"):
            out += f".{part}" if out else part
        else:
            out += f"[{json.dumps(part)}]"
    return out or "(top level)"


def _type_name(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _is_type(value: Any, json_type: str) -> bool:
    if json_type == "object":
        return isinstance(value, dict)
    if json_type == "array":
        return isinstance(value, list)
    if json_type == "string":
        return isinstance(value, str)
    if json_type == "boolean":
        return isinstance(value, bool)
    if json_type == "null":
        return value is None
    if json_type == "number":
        return _is_number(value)
    if json_type == "integer":
        if isinstance(value, bool):
            return False
        if isinstance(value, int):
            return True
        return isinstance(value, float) and value.is_integer()
    raise SchemaError(f"unknown type {json_type!r}")


def json_equal(a: Any, b: Any) -> bool:
    """Equality by JSON rules: true is not 1, but 1 equals 1.0."""
    if isinstance(a, bool) or isinstance(b, bool):
        return isinstance(a, bool) and isinstance(b, bool) and a == b
    if _is_number(a) and _is_number(b):
        return a == b
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(json_equal(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(json_equal(a[k], b[k]) for k in a)
    return type(a) is type(b) and a == b


def _pattern_matches(pattern: str, text: str) -> bool:
    match = re.search(pattern, text)
    if match is None:
        return False
    # Python's "$" also matches just before a trailing newline; JSON Schema's does not.
    if pattern.endswith("$") and not pattern.endswith("\\$"):
        return match.end() == len(text)
    return True


class SchemaStore:
    """Loads every *.schema.json in one folder and validates data against them."""

    def __init__(self, schema_dir: Path):
        self.dir = schema_dir
        self.docs: dict[str, Any] = {}
        paths = sorted(schema_dir.glob("*.schema.json"))
        if not paths:
            raise SchemaError(f"no *.schema.json files found in {schema_dir}")
        for path in paths:
            try:
                self.docs[path.name] = jsonio.load(path)
            except jsonio.DataFormatError as exc:
                raise SchemaError(f"{path.name}: {exc}") from None
        for name, doc in self.docs.items():
            self._check_schema(doc, name, "#")

    # ------------------------------------------------------------------ schema checks
    def _check_schema(self, node: Any, file: str, where: str) -> None:
        if isinstance(node, bool):
            return
        if not isinstance(node, dict):
            raise SchemaError(f"{file} {where}: a schema must be an object or true/false")
        for key in node:
            if key not in ANNOTATION_KEYWORDS and key not in VALIDATION_KEYWORDS:
                raise SchemaError(f"{file} {where}: unsupported schema keyword {key!r}")
        if "type" in node:
            types = [node["type"]] if isinstance(node["type"], str) else node["type"]
            if not isinstance(types, list) or not types:
                raise SchemaError(f"{file} {where}: 'type' must be a string or non-empty list")
            for json_type in types:
                if json_type not in JSON_TYPES:
                    raise SchemaError(f"{file} {where}: unknown type {json_type!r}")
        if "$ref" in node:
            if not isinstance(node["$ref"], str):
                raise SchemaError(f"{file} {where}: $ref must be a string")
            self.resolve(node["$ref"], file)
        for key in ("pattern",):
            if key in node:
                try:
                    re.compile(node[key])
                except re.error as exc:
                    raise SchemaError(f"{file} {where}: bad regex {node[key]!r}: {exc}") from None
        if "required" in node and not (
            isinstance(node["required"], list) and all(isinstance(x, str) for x in node["required"])
        ):
            raise SchemaError(f"{file} {where}: 'required' must be a list of strings")
        if "enum" in node and not (isinstance(node["enum"], list) and node["enum"]):
            raise SchemaError(f"{file} {where}: 'enum' must be a non-empty list")
        if "x-ref" in node and not (
            isinstance(node["x-ref"], list)
            and node["x-ref"]
            and all(isinstance(x, str) for x in node["x-ref"])
        ):
            raise SchemaError(f"{file} {where}: 'x-ref' must be a non-empty list of id prefixes")
        for key in ("properties", "patternProperties", "$defs"):
            if key in node:
                if not isinstance(node[key], dict):
                    raise SchemaError(f"{file} {where}: '{key}' must be an object")
                for child_key, child in node[key].items():
                    if key == "patternProperties":
                        try:
                            re.compile(child_key)
                        except re.error as exc:
                            raise SchemaError(f"{file} {where}: bad regex {child_key!r}: {exc}") from None
                    self._check_schema(child, file, f"{where}/{key}/{child_key}")
        for key in ("additionalProperties", "items", "not", "if", "then", "else", "propertyNames"):
            if key in node:
                self._check_schema(node[key], file, f"{where}/{key}")
        for key in ("allOf", "anyOf", "oneOf"):
            if key in node:
                if not isinstance(node[key], list) or not node[key]:
                    raise SchemaError(f"{file} {where}: '{key}' must be a non-empty list")
                for index, child in enumerate(node[key]):
                    self._check_schema(child, file, f"{where}/{key}/{index}")

    def resolve(self, ref: str, base_file: str) -> tuple[Any, str]:
        """Find the schema a $ref points at. Supports '#/$defs/x' and 'file.schema.json#/$defs/x'."""
        file_part, _, pointer = ref.partition("#")
        file_part = file_part.removeprefix("./")
        target_file = file_part or base_file
        if target_file not in self.docs:
            raise SchemaError(f"{base_file}: $ref {ref!r} names a schema file that does not exist")
        node: Any = self.docs[target_file]
        if pointer:
            if not pointer.startswith("/"):
                raise SchemaError(f"{base_file}: $ref {ref!r} must use a '#/...' pointer")
            for token in pointer[1:].split("/"):
                token = token.replace("~1", "/").replace("~0", "~")
                if isinstance(node, dict) and token in node:
                    node = node[token]
                elif isinstance(node, list) and token.isdigit() and int(token) < len(node):
                    node = node[int(token)]
                else:
                    raise SchemaError(f"{base_file}: $ref {ref!r} points at nothing")
        return node, target_file

    # ------------------------------------------------------------------ validation
    def validate(self, instance: Any, schema_file: str) -> Result:
        if schema_file not in self.docs:
            raise SchemaError(f"no schema named {schema_file!r}")
        result = Result()
        self._validate(instance, self.docs[schema_file], schema_file, (), result)
        return result

    def _trial(self, instance: Any, schema: Any, base: str, path: tuple) -> Result:
        trial = Result()
        self._validate(instance, schema, base, path, trial)
        return trial

    def _error(self, result: Result, path: tuple, message: str) -> None:
        result.errors.append(Issue(format_path(path), message))

    def _validate(self, inst: Any, schema: Any, base: str, path: tuple, result: Result) -> None:
        if schema is True:
            return
        if schema is False:
            self._error(result, path, "no value is allowed here")
            return

        if "$ref" in schema:
            target, target_base = self.resolve(schema["$ref"], base)
            self._validate(inst, target, target_base, path, result)

        if "type" in schema:
            types = [schema["type"]] if isinstance(schema["type"], str) else schema["type"]
            if not any(_is_type(inst, t) for t in types):
                self._error(result, path, f"expected {' or '.join(types)}, got {_type_name(inst)}")
                return

        if "const" in schema and not json_equal(inst, schema["const"]):
            self._error(result, path, f"must be exactly {json.dumps(schema['const'])}")

        if "enum" in schema and not any(json_equal(inst, option) for option in schema["enum"]):
            options = ", ".join(json.dumps(option) for option in schema["enum"])
            message = f"{json.dumps(inst)} is not allowed; choose one of: {options}"
            if isinstance(inst, str):
                close = difflib.get_close_matches(
                    inst, [o for o in schema["enum"] if isinstance(o, str)], n=1
                )
                if close:
                    message = f"{json.dumps(inst)} is not allowed (did you mean {json.dumps(close[0])}?)"
            self._error(result, path, message)

        if isinstance(inst, dict):
            self._validate_object(inst, schema, base, path, result)
        elif isinstance(inst, list):
            self._validate_array(inst, schema, base, path, result)
        elif isinstance(inst, str):
            self._validate_string(inst, schema, path, result)
        elif _is_number(inst):
            self._validate_number(inst, schema, path, result)

        for sub in schema.get("allOf", ()):
            self._validate(inst, sub, base, path, result)

        if "anyOf" in schema:
            trials = [self._trial(inst, sub, base, path) for sub in schema["anyOf"]]
            passing = [t for t in trials if t.ok]
            if passing:
                result.refs.extend(passing[0].refs)
            else:
                best = min(trials, key=lambda t: len(t.errors))
                self._error(result, path, "does not match any of the allowed forms; closest form says:")
                result.errors.extend(best.errors)

        if "oneOf" in schema:
            trials = [self._trial(inst, sub, base, path) for sub in schema["oneOf"]]
            passing = [t for t in trials if t.ok]
            if len(passing) == 1:
                result.refs.extend(passing[0].refs)
            elif not passing:
                best = min(trials, key=lambda t: len(t.errors))
                self._error(result, path, "does not match any of the allowed forms; closest form says:")
                result.errors.extend(best.errors)
            else:
                self._error(result, path, f"matches {len(passing)} forms but must match exactly one")

        if "not" in schema and self._trial(inst, schema["not"], base, path).ok:
            self._error(result, path, "matches a form that is not allowed here")

        if "if" in schema:
            condition = self._trial(inst, schema["if"], base, path)
            branch = schema.get("then") if condition.ok else schema.get("else")
            if branch is not None:
                self._validate(inst, branch, base, path, result)

        if "x-ref" in schema and isinstance(inst, str):
            result.refs.append(Reference(format_path(path), inst, tuple(schema["x-ref"])))

    def _validate_object(self, inst: dict, schema: dict, base: str, path: tuple, result: Result) -> None:
        properties = schema.get("properties", {})
        pattern_properties = schema.get("patternProperties", {})
        for name in schema.get("required", ()):
            if name not in inst:
                self._error(result, path, f"missing required field {name!r}")
        if "minProperties" in schema and len(inst) < schema["minProperties"]:
            self._error(result, path, f"needs at least {schema['minProperties']} fields")
        if "maxProperties" in schema and len(inst) > schema["maxProperties"]:
            self._error(result, path, f"allows at most {schema['maxProperties']} fields")
        if "propertyNames" in schema:
            for key in inst:
                trial = self._trial(key, schema["propertyNames"], base, path)
                if not trial.ok:
                    self._error(result, path, f"field name {key!r} is not allowed: {trial.errors[0].message}")
        additional = schema.get("additionalProperties", True)
        for key, value in inst.items():
            matched = False
            if key in properties:
                self._validate(value, properties[key], base, path + (key,), result)
                matched = True
            for pattern, sub in pattern_properties.items():
                if _pattern_matches(pattern, key):
                    self._validate(value, sub, base, path + (key,), result)
                    matched = True
            if matched:
                continue
            if additional is False:
                close = difflib.get_close_matches(key, list(properties), n=1)
                hint = f" (did you mean {close[0]!r}?)" if close else ""
                self._error(result, path, f"unknown field {key!r}{hint}")
            elif additional is not True:
                self._validate(value, additional, base, path + (key,), result)

    def _validate_array(self, inst: list, schema: dict, base: str, path: tuple, result: Result) -> None:
        if "minItems" in schema and len(inst) < schema["minItems"]:
            self._error(result, path, f"needs at least {schema['minItems']} items, has {len(inst)}")
        if "maxItems" in schema and len(inst) > schema["maxItems"]:
            self._error(result, path, f"allows at most {schema['maxItems']} items, has {len(inst)}")
        if schema.get("uniqueItems"):
            for i in range(len(inst)):
                for j in range(i):
                    if json_equal(inst[i], inst[j]):
                        self._error(result, path + (i,), f"duplicate of item [{j}]")
                        break
        if "items" in schema:
            for index, item in enumerate(inst):
                self._validate(item, schema["items"], base, path + (index,), result)

    def _validate_string(self, inst: str, schema: dict, path: tuple, result: Result) -> None:
        if "minLength" in schema and len(inst) < schema["minLength"]:
            self._error(result, path, f"must be at least {schema['minLength']} characters")
        if "maxLength" in schema and len(inst) > schema["maxLength"]:
            self._error(result, path, f"must be at most {schema['maxLength']} characters")
        if "pattern" in schema and not _pattern_matches(schema["pattern"], inst):
            self._error(result, path, f"{json.dumps(inst)} does not match the pattern {schema['pattern']}")

    def _validate_number(self, inst: float, schema: dict, path: tuple, result: Result) -> None:
        if "minimum" in schema and inst < schema["minimum"]:
            self._error(result, path, f"{inst} is below the minimum {schema['minimum']}")
        if "maximum" in schema and inst > schema["maximum"]:
            self._error(result, path, f"{inst} is above the maximum {schema['maximum']}")
        if "exclusiveMinimum" in schema and inst <= schema["exclusiveMinimum"]:
            self._error(result, path, f"{inst} must be greater than {schema['exclusiveMinimum']}")
        if "exclusiveMaximum" in schema and inst >= schema["exclusiveMaximum"]:
            self._error(result, path, f"{inst} must be less than {schema['exclusiveMaximum']}")
        if "multipleOf" in schema:
            ratio = inst / schema["multipleOf"]
            if abs(ratio - round(ratio)) > 1e-9:
                self._error(result, path, f"{inst} must be a multiple of {schema['multipleOf']}")
