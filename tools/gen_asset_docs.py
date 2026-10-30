#!/usr/bin/env python3
"""Build the asset docs from shared-data/assets.json, so they can never drift apart.

- docs/ASSET_LICENSES.md: the table between the GENERATED markers is rewritten.
- docs/ASSET_SPECS.md: fully generated list of every asset still needed, with its spec.

Usage:
    python3 tools/gen_asset_docs.py           # rewrite the docs
    python3 tools/gen_asset_docs.py --check   # exit 1 if the docs are out of date
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sbe_tools import jsonio  # noqa: E402
from sbe_tools.catalog import REPO_ROOT, SHARED_DATA  # noqa: E402

LICENSES_DOC = REPO_ROOT / "docs" / "ASSET_LICENSES.md"
SPECS_DOC = REPO_ROOT / "docs" / "ASSET_SPECS.md"
BEGIN = "<!-- BEGIN GENERATED ASSET TABLE (tools/gen_asset_docs.py) -->"
END = "<!-- END GENERATED ASSET TABLE -->"
STATUS_LABEL = {"needed": "NEEDED (nothing yet)", "placeholder": "PLACEHOLDER", "final": "final"}


def _cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def license_table(assets: list[dict]) -> str:
    lines = [
        BEGIN,
        "",
        "| Asset id | Name | Kind | Status | Current source | License |",
        "|---|---|---|---|---|---|",
    ]
    for a in assets:
        lines.append(
            f"| `{a['id']}` | {_cell(a['name'])} | {a['kind']} | {STATUS_LABEL[a['status']]} "
            f"| {_cell(a['source'])} | {_cell(a['license'])} |"
        )
    counts = {s: sum(1 for a in assets if a["status"] == s) for s in ("needed", "placeholder", "final")}
    lines += [
        "",
        f"Totals: {counts['final']} final, {counts['placeholder']} placeholder, {counts['needed']} needed.",
        "",
        END,
    ]
    return "\n".join(lines)


def specs_doc(assets: list[dict]) -> str:
    lines = [
        "# Asset specs",
        "",
        "GENERATED from `shared-data/assets.json` by `tools/gen_asset_docs.py`. Do not edit by hand.",
        "",
        "Each entry is something the game needs that cannot be made from a terminal (3D models, art,",
        "animation, sound, music). Hand these specs to an artist, or use them to search for properly",
        "licensed assets. Every asset that comes in must be logged in `shared-data/assets.json` with its",
        "source and license.",
        "",
    ]
    for status in ("needed", "placeholder"):
        group = [a for a in assets if a["status"] == status]
        if not group:
            continue
        title = "Needed: nothing exists yet" if status == "needed" else "Placeholders in use: final asset still needed"
        lines += [f"## {title} ({len(group)})", ""]
        for a in group:
            lines += [
                f"### {a['name']} (`{a['id']}`)",
                "",
                f"- **Kind:** {a['kind']}",
                f"- **Spec:** {a['spec']}",
                f"- **Shown until then:** {a['placeholder']}",
                "",
            ]
    return "\n".join(lines).rstrip() + "\n"


def render() -> dict[Path, str]:
    assets = jsonio.load(SHARED_DATA / "assets.json")["entries"]
    current = LICENSES_DOC.read_text(encoding="utf-8") if LICENSES_DOC.exists() else ""
    if BEGIN not in current or END not in current:
        raise SystemExit(f"{LICENSES_DOC.relative_to(REPO_ROOT)} is missing the generated-table markers")
    before, rest = current.split(BEGIN, 1)
    _, after = rest.split(END, 1)
    return {LICENSES_DOC: before + license_table(assets) + after, SPECS_DOC: specs_doc(assets)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    outputs = render()
    stale = [p for p, text in outputs.items() if not p.exists() or p.read_text(encoding="utf-8") != text]
    if args.check:
        for path in stale:
            print(f"  out of date: {path.relative_to(REPO_ROOT)}")
        print("FAIL: asset docs are out of date. Run: python3 tools/gen_asset_docs.py" if stale
              else "PASS: asset docs are up to date")
        return 1 if stale else 0
    for path in stale:
        path.write_text(outputs[path], encoding="utf-8")
    print(f"Updated {len(stale)} asset doc(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
