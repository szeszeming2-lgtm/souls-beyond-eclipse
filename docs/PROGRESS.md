# Progress

Last updated: 2026-10-30. **Phase 1 code is complete and passes every automated check. The Studio playtest is still pending.**

## Phase 1: Roblox playable prototype (in progress: playtest pending)

### What exists (built, not yet seen running)
- Server: ProfileStore saving (validated before every save; refuses newer-version saves), settings,
  server-only XP with level-sync, catch-up, anti-grind and rate guards, level cap 50 for this build,
  starter weapon, placeholder character and katana, server-authoritative combat (light/heavy chains,
  Flash Step, guard/parry, Wickflare), Gloamling spawns and AI with readable tells and attack tokens,
  the Lampeater boss (3 phases, checkpoints, optional assists), the harbor blockout, Studio-only dev tools.
- Client: one input system for keyboard/mouse, gamepad and touch; camera with lock-on; HUD with XP to
  next level, effects, cooldowns, boss bar and minimap; pause menu with data-driven settings; touch stick
  and buttons with three layouts.

### Tests (all ran and passed)
- `python3 tools/check_all.py`: 13 of 13 steps pass. 104 Python tests and 90 Lune tests pass.
  Selene and StyLua are clean, strict luau-lsp type checking reports 0 errors, and the place builds.
- Covered by tests: XP and level cap (cannot exceed 3000, or 50 in this build), level-up rewards granted
  once, damage math, equip rules, inventory, save load/repair/corruption/newer-version refusal,
  server rejection of client-claimed XP or rewards, and the Studio-only dev-tools gate.

### Not verified yet
- **Nothing has been run inside Roblox Studio yet.** Movement feel, camera, the visuals, enemy behaviour,
  the boss fight, menus and touch controls are written and type-checked, but not seen working.
- Real DataStore saving across sessions needs the place published with Studio API access turned on.

### Placeholders
- All art is placeholder: a blocky body, a parts-built katana and enemies, neon-part effects, grey-box map.
- No sound or music. No custom animations: attacks show an arc flash only.

### Known limits
- Heavy-attack charging, ability upgrades, Cinder Rush, Eclipse Form, interact, fast travel and full
  key remapping are not in this build. Those buttons say "not in this build yet".
- The pause menu cannot stop a shared Roblox server. While it is open, enemies don't start new attacks on you.

### Exact next step
Playtest in Studio with `docs/checklists/PHASE1_SMOKE_TEST.md`, fix whatever it finds, then the Phase 1
report and approval.


## Phase 0: Plan

### What works
- **Data foundation.** 21 schemas, 20 data files and 119 ids in `shared-data/`, covering factions,
  styles, skill trees, movesets, abilities, status effects, weapons, materials, enemies and bosses,
  characters, quests, regions, one map, progression, combat rules, difficulty, input,
  customization and assets.
- **Validator** (`tools/validate_data.py`). It checks each file against its schema, then ids and
  references across files, then 15 groups of design rules from the brief: fair attack tells,
  no stun-locks, 5 upgrade tiers, no level-band gaps, no XP walls, input conflicts, no-stat
  cosmetics, connected world, story not depending on side quests, and more. Messages name the file
  and field and suggest fixes ("did you mean 'common'?").
- **XP curve to level 3000** (`tools/xp_sim/xp_sim.py`). It generates `xp_table.json` and
  simulates three play styles. All 6 design targets pass:
  - level 100 in 4.8 hours of normal play (target: about 5);
  - level 3000 in about 225 hours (target: 150+);
  - grinding one enemy takes about 691 hours, about 3× slower than varied play;
  - no walls: from level 30 on, no level costs more than 5% more than the one before.
- **Luau converter** (`tools/convert_to_luau.py`). It writes 21 read-only (frozen) Luau modules
  into `roblox-game/src/shared/GameData/`. Every module is read back by a test and matches its JSON
  exactly.
- **Asset docs.** `docs/ASSET_LICENSES.md` (table) and `docs/ASSET_SPECS.md` are generated from
  `assets.json`.
- **One-command check.** `python3 tools/check_all.py` runs all of the above plus the tests.
- **Roblox project skeleton.** Rojo project file, pinned toolchain (`rokit.toml`), lint and format
  configs, and two tiny smoke-test scripts that print the data counts in Studio.

### What is a placeholder, or only data
- **There is no game yet.** Zero gameplay code. The two Roblox scripts only prove the data loads.
- **Content is data only.** Nothing is in the game yet:

  | Kind | concept (idea only) | data_only (complete data, not in game) |
  |---|---|---|
  | Factions | 6 | 1 (Lantern Wardens) |
  | Archetypes (styles) | 5 | 1 (Lanternblade) |
  | Abilities | 1 | 6 |
  | Weapons | – | 1 (Hearthwick) |
  | Enemies / bosses | – | 2 (Gloamling, Lampeater) |
  | Regions | 10 | 1 (Akeboshi City) |
  | Maps | – | 1 (harbor district layout, not built) |
  | Quests | – | 4 |
  | Characters | 3 | – |
  | Cosmetic options | 31 | – |

- **All 15 assets are "needed"** (models, animations, sounds, music, effects). Each has a written
  spec in `docs/ASSET_SPECS.md` and a planned labelled placeholder.
- **Story, factions and world** are an outline for your approval (`docs/GAME_DESIGN.md`).

### Tests
- **Ran and passed:** 100 automated tests (`python3 tools/run_tests.py`):
  - strict JSON loading (8);
  - the schema checker (14);
  - 44 data-rule tests that each break a copy of the data on purpose and confirm the error is caught;
  - Luau output: escaping, round-trip of every data file, and converter safety (15);
  - XP curve and simulator, including "level can never exceed 3000" (13);
  - real data clean and generated files current (6).
- **Ran and passed:** `python3 tools/check_all.py`. 5 steps passed and 3 were skipped.
- **Skipped (not passed):** Selene lint, StyLua format check and Rojo build, because those tools
  aren't installed yet.
- **Not run by me:**
  - nothing has been opened in Roblox Studio;
  - the generated Luau has only been checked by the project's own Luau reader, not by a real Luau
    compiler or linter;
  - VS Code autocomplete from the schemas is expected to work but I have not seen it.

Brief §15 test list, and where each one lands:

| Test | Status |
|---|---|
| XP curve and level cap (cannot exceed 3000) | Done (tools tests) |
| Level-up rewards granted only once | Phase 1 (needs the Luau rules code) |
| Damage math | Phase 1 |
| Item data validation, including duplicate ids | Done |
| Equip rules | Phase 1 (data-side weapon/moveset/ability checks done) |
| Inventory | Phase 1 |
| Save/load and corrupted saves | Phase 1 |
| Server rejection of client-claimed XP or rewards | Phase 1 |

### Known issues and limits
- The generated Luau is unverified by real Luau tooling until you install the tools. `check_all`
  will then lint and build it automatically.
- The XP simulator treats play as an average mix and does not yet "run out" of story content.
  Phase 3 re-simulates it against real content. 225 hours to the cap is well above the 150-hour
  minimum, and I can shorten it if you prefer.
- The project's schema checker and VS Code's are separate programs. They could disagree on rare
  edge cases. The project's checker is the one that counts.
- ProfileStore's Wally listing shows no license, while its GitHub repository says Apache-2.0. Phase 1
  records the license properly before using it.
- The project folder name contains a space (`untitled folder`), so commands need quotes. Renaming
  it is optional; see `docs/SETUP.md`.

### Exact next step
After you approve, Phase 1 starts. First I check that your tool install works (`check_all` with no
SKIPPED lines, Rojo build, the Studio smoke test). Then I build the harbor blockout from the map
data, movement and camera, and the unified input system.

### What I need from you
1. **Approve or change** the plan: `docs/ROADMAP.md` and the design outline in
   `docs/GAME_DESIGN.md` (names, factions, story direction).
2. **Install the tools** in `docs/SETUP.md`: Rokit, then `rokit install`, then `rojo plugin install`.
3. **Run steps 5–7** of `docs/checklists/PHASE0_SMOKE_TEST.md` and tell me what Studio's Output shows.
4. Nothing else yet: no art, audio, accounts or licenses are needed for Phase 1.

## Phase history

| Phase | Status | Date |
|---|---|---|
| 0: Plan | Complete, approved | 2026-10-30 |
| 1: Roblox prototype | Code complete, Studio playtest pending | 2026-10-30 |
