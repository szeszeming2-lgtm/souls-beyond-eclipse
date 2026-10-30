# tools

Python 3 tools, using only the standard library (nothing to install). Run them from the project
folder.

| Command | What it does |
|---|---|
| `python3 tools/check_all.py` | Runs **every** check below, plus Selene/StyLua/Rojo if installed. Use before each commit |
| `python3 tools/validate_data.py` | Checks all of `shared-data/` against the schemas and the design rules |
| `python3 tools/convert_to_luau.py` | Validates, then writes `roblox-game/src/shared/GameData/` (`--check` only reports) |
| `python3 tools/xp_sim/xp_sim.py` | Simulates XP pacing to level 3000 and checks the design targets |
| `python3 tools/xp_sim/xp_sim.py --write-table` | Regenerates `shared-data/progression/xp_table.json` |
| `python3 tools/xp_sim/xp_sim.py --csv xp.csv` | Writes per-level numbers for a spreadsheet |
| `python3 tools/gen_asset_docs.py` | Rebuilds `docs/ASSET_LICENSES.md` (table) and `docs/ASSET_SPECS.md` |
| `python3 tools/run_tests.py` | Runs the automated tests (`-v` lists each test) |

## Layout
- `sbe_tools/`: shared code
  - `jsonio.py`: strict JSON loading (rejects duplicate keys, NaN, numbers too big for Luau)
  - `schema.py`: small strict JSON Schema checker
  - `catalog.py`: finds data files and registers every id
  - `rules.py`: cross-file design rules
  - `validation.py`: runs everything in order
  - `xp_curve.py`: XP curve math (single source of truth)
  - `luau_writer.py`, `luau_convert.py`: JSON to Luau
- `xp_sim/`: the XP simulator
- `tests/`: automated tests. `luau_reader.py` reads generated Luau back, to prove it matches the JSON
