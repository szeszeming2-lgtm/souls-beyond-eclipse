"""Finds data files and builds the registry of every id in shared-data."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from . import jsonio
from .schema import format_path

REPO_ROOT = Path(__file__).resolve().parents[2]
SHARED_DATA = REPO_ROOT / "shared-data"

# Every id prefix used in shared-data, and what it means.
KIND_NAMES = {
    "fac": "faction",
    "arc": "archetype",
    "skt": "skill tree",
    "mvs": "moveset",
    "abl": "ability",
    "sts": "status effect",
    "wpn": "weapon",
    "mat": "material",
    "enm": "enemy",
    "chr": "character",
    "qst": "quest",
    "reg": "region",
    "map": "map",
    "ast": "asset",
    "cos": "cosmetic",
    "cur": "currency",
    "bnd": "level band",
    "hub": "hub",
    "ftp": "fast-travel point",
    "lmk": "landmark",
    "spz": "spawn zone",
    "arn": "boss arena",
    "sec": "secret",
}

GLOBAL_ID = re.compile(r"^([a-z]{3})_[a-z0-9]+(?:_[a-z0-9]+)*$")


@dataclass
class DataFile:
    path: Path
    rel: str  # path inside shared-data, with forward slashes
    schema_name: str  # e.g. "weapons.schema.json"
    data: Any


@dataclass
class Entity:
    id: str
    kind: str  # the 3-letter prefix
    file: str
    path: str
    obj: dict


def discover(shared_dir: Path) -> tuple[list[DataFile], list[str]]:
    """Load every data file (everything except schemas/) and work out its schema."""
    files: list[DataFile] = []
    errors: list[str] = []
    schema_dir = (shared_dir / "schemas").resolve()
    for path in sorted(shared_dir.rglob("*.json")):
        rel = path.relative_to(shared_dir).as_posix()
        if rel.startswith("schemas/"):
            continue
        try:
            data = jsonio.load(path)
        except jsonio.DataFormatError as exc:
            errors.append(f"{rel}: {exc}")
            continue
        schema_ref = data.get("$schema") if isinstance(data, dict) else None
        if not isinstance(schema_ref, str):
            errors.append(
                f'{rel}: missing "$schema". Every data file must name its schema, '
                f'for example "$schema": "./schemas/factions.schema.json"'
            )
            continue
        target = (path.parent / schema_ref).resolve()
        if target.parent != schema_dir or not target.name.endswith(".schema.json"):
            errors.append(f'{rel}: "$schema" must point into shared-data/schemas/, got {schema_ref!r}')
            continue
        if not target.exists():
            errors.append(f'{rel}: "$schema" points at {schema_ref!r}, which does not exist')
            continue
        files.append(DataFile(path=path, rel=rel, schema_name=target.name, data=data))
    if not files and not errors:
        errors.append(f"no data files found in {shared_dir}")
    return files, errors


def build_registry(files: list[DataFile]) -> tuple[dict[str, Entity], list[str]]:
    """Register every object whose "id" uses a known prefix. Ids must be unique across ALL files."""
    registry: dict[str, Entity] = {}
    errors: list[str] = []

    def walk(node: Any, file: DataFile, path: tuple) -> None:
        if isinstance(node, dict):
            ident = node.get("id")
            if isinstance(ident, str):
                match = GLOBAL_ID.match(ident)
                if match and match.group(1) in KIND_NAMES:
                    where = format_path(path)
                    if ident in registry:
                        first = registry[ident]
                        errors.append(
                            f"{file.rel}: {where}: duplicate id {ident!r} "
                            f"(already used at {first.file}: {first.path})"
                        )
                    else:
                        registry[ident] = Entity(ident, match.group(1), file.rel, where, node)
            for key, value in node.items():
                walk(value, file, path + (key,))
        elif isinstance(node, list):
            for index, value in enumerate(node):
                walk(value, file, path + (index,))

    for data_file in files:
        walk(data_file.data, data_file, ())
    return registry, errors
