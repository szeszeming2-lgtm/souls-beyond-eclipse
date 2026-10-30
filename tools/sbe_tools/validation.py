"""Runs every data check in order and returns one report."""

from __future__ import annotations

import difflib
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from . import rules
from .catalog import KIND_NAMES, SHARED_DATA, DataFile, Entity, build_registry, discover
from .schema import Reference, SchemaError, SchemaStore


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    files: list[DataFile] = field(default_factory=list)
    registry: dict[str, Entity] = field(default_factory=dict)
    schema_count: int = 0
    stage_reached: str = ""

    @property
    def ok(self) -> bool:
        return not self.errors

    def status_counts(self) -> dict[str, Counter]:
        """How many entries of each kind are at each dev_status (concept, data_only...)."""
        counts: dict[str, Counter] = defaultdict(Counter)
        for entity in self.registry.values():
            status = entity.obj.get("dev_status")
            if isinstance(status, str):
                counts[KIND_NAMES[entity.kind]][status] += 1
        return dict(sorted(counts.items()))


def _check_references(refs: list[tuple[str, Reference]], registry: dict[str, Entity]) -> list[str]:
    errors = []
    for file_rel, ref in refs:
        target = registry.get(ref.value)
        wanted = " or ".join(KIND_NAMES.get(k, k) for k in ref.kinds)
        if target is None:
            candidates = [i for i, e in registry.items() if e.kind in ref.kinds]
            close = difflib.get_close_matches(ref.value, candidates, n=1)
            hint = f" (did you mean {close[0]!r}?)" if close else ""
            errors.append(f"{file_rel}: {ref.path}: {ref.value!r} is not the id of any {wanted}{hint}")
        elif target.kind not in ref.kinds:
            errors.append(f"{file_rel}: {ref.path}: {ref.value!r} is a {KIND_NAMES[target.kind]}, but a {wanted} is needed here")
    return errors


def validate_all(shared_dir: Path = SHARED_DATA) -> Report:
    report = Report()

    report.stage_reached = "loading schemas"
    try:
        store = SchemaStore(shared_dir / "schemas")
    except SchemaError as exc:
        report.errors.append(f"schema problem: {exc}")
        return report
    report.schema_count = len(store.docs)

    report.stage_reached = "reading data files"
    files, errors = discover(shared_dir)
    report.files = files
    report.errors.extend(errors)

    report.stage_reached = "checking each file against its schema"
    refs: list[tuple[str, Reference]] = []
    for data_file in files:
        result = store.validate(data_file.data, data_file.schema_name)
        report.errors.extend(f"{data_file.rel}: {issue.path}: {issue.message}" for issue in result.errors)
        refs.extend((data_file.rel, ref) for ref in result.refs)
    if report.errors:
        report.errors.append("(cross-file checks were skipped; fix the errors above first)")
        return report

    report.stage_reached = "checking ids and references"
    registry, errors = build_registry(files)
    report.registry = registry
    report.errors.extend(errors)
    report.errors.extend(_check_references(refs, registry))
    if report.errors:
        report.errors.append("(design-rule checks were skipped; fix the errors above first)")
        return report

    report.stage_reached = "checking design rules"
    ctx = rules.Ctx(files=files, registry=registry, store=store)
    for check in rules.RULES:
        check(ctx)
    report.errors.extend(ctx.errors)
    report.warnings.extend(ctx.warnings)
    report.stage_reached = "done"
    return report
