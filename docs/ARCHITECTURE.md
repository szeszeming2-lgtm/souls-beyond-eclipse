# Architecture

How Souls Beyond: Eclipse is put together, and why. Written for a beginner: each decision says
what it means in practice.

## 1. The big picture

```
              you edit                       tools check and convert                 games read
 ┌─────────────────────────────┐      ┌───────────────────────────────┐      ┌──────────────────────────┐
 │ shared-data/*.json          │ ───▶ │ tools/validate_data.py        │      │ Roblox edition           │
 │  weapons, enemies, quests,  │      │  schema + cross-file rules    │      │  roblox-game/            │
 │  maps, progression, input…  │      │ tools/xp_sim/xp_sim.py        │ ───▶ │  GameData/*.luau (gen)   │
 │ shared-data/schemas/        │      │  XP table + pacing targets    │      ├──────────────────────────┤
 │  the rules each file obeys  │      │ tools/convert_to_luau.py      │      │ PC edition (Phase 6)     │
 └─────────────────────────────┘      │  JSON -> frozen Luau modules  │ ───▶ │  pc-game/ reads the same │
                                      └───────────────────────────────┘      │  validated JSON          │
                                                                             └──────────────────────────┘
```

**One source of truth.** Every name, stat, dialogue line, map layout and item list lives in
`shared-data/`. Game code never hard-codes them. Both editions read the same data, so a balance
change is made once.

## 2. Repository layout

| Folder | What lives there |
|---|---|
| `docs/` | Plans, progress, licenses, asset specs, checklists |
| `shared-data/` | Game data (JSON) plus `schemas/` that define what valid data looks like |
| `tools/` | Python tools: validator, XP simulator, Luau converter, asset-doc generator, tests |
| `roblox-game/` | Roblox edition (Rojo project). `src/shared/GameData/` is generated: never edit it |
| `pc-game/` | Godot PC edition, created in Phase 6 |
| `builds/` | Build outputs (ignored by git) |

## 3. Data design

**JSON Schema files.** Each data file starts with `"$schema": "./schemas/<name>.schema.json"`.
VS Code reads that line and gives you autocomplete, hover help and red squiggles while you type,
with no setup.

**Ids.** Every entry has an id with a 3-letter prefix that says what it is: `wpn_hearthwick`,
`enm_lampeater`, `qst_main_seven_minutes`. Ids are unique across *all* files. References are
checked, so a typo like `mvs_lanternblade_katan` is caught, with a suggestion. The full prefix
list is in `shared-data/README.md`.

**Honest build status.** Every entry has `dev_status`: `concept` (idea only), `data_only`
(complete data, not in the game yet), `in_progress`, `playable_placeholder` (works in game with
placeholder art) or `final`. The validator prints a count of each, so data entries are never
mistaken for finished content.

**Design promises become checks.** The validator enforces rules from the brief, for example:
- every enemy attack is avoidable, with a readable wind-up on every difficulty;
- unblockable attacks must be dodgeable and show a special warning;
- hard crowd control is capped (no stun-locks);
- weapons have exactly 5 upgrade tiers in order;
- level bands cover 1–3000 with no gaps, major milestones exist, the XP curve has no walls;
- the main story never requires side content;
- every input action has a keyboard, gamepad *and* touch binding, with no conflicts;
- cosmetics cannot carry stats or be bought with real money;
- the world is one connected graph of regions.

**Units.** Positions and distances are in Roblox studs, y is up. The PC edition converts with
one scale constant.

**Text.** Data holds English source text. A translation layer (Phase 7) will map
`<id>.<field>` to other languages.

**The XP table is stored, not recomputed.** `tools/xp_sim` builds `xp_table.json` (2,999 numbers)
from the curve settings. Both editions read the table, so a level-up costs exactly the same XP on
Roblox and PC, with no floating-point differences between engines.

## 4. The tools (Python, standard library only)

Python 3 is already on your Mac, and the tools need nothing else installed. Each tool has a
`--check` mode for automated checks. Run everything with:

```bash
python3 tools/check_all.py
```

The schema checker is a small, strict subset of JSON Schema written for this project. It refuses
any schema keyword it does not understand, so a typo in a schema can never silently turn a check
off.

The Luau converter writes one ModuleScript per data file, plus `init.luau` as an index. Every
table is wrapped in `table.freeze`, so game code cannot change shared data by accident. The
generated files are committed to git, so Rojo can sync them without running Python first.
`--check` fails if they are stale. The converter never deletes files it did not generate.

## 5. Roblox edition (Phases 1–5)

### Toolchain
- **Rokit** installs exact, pinned versions of the tools listed in `rokit.toml`.
- **Rojo 7.7.1** syncs files on disk into Roblox Studio.
- **Wally 0.3.2** installs Luau packages.
- **Selene** lints Luau and **StyLua** formats it.
- **Lune** runs Luau outside Roblox, for fast tests of pure game rules.

### Planned code layout (built in Phase 1)
```
roblox-game/src/
  shared/                 (ReplicatedStorage.Shared: client and server can read)
    GameData/             generated data modules
    Rules/                PURE logic, no Roblox APIs, so it can be tested in Lune:
                          DamageMath, XpMath, EquipRules, Inventory, SaveSchema (+ migrations), InputMap
    Net/                  the one place every RemoteEvent is defined, with payload types and rate limits
  server/                 (ServerScriptService: clients cannot see it)
    Services/             PlayerData (ProfileStore), Combat, Progression, Inventory, Enemies, Bosses,
                          World (builds the blockout from map data), later Quests
  client/                 (StarterPlayerScripts)
    Controllers/          Input, Camera, CombatFeel (animations/effects), Hud, Menus, TouchControls
```

### Server authority (never trust the client)
- The client sends **intents only**: "light attack pressed, facing this way, locked on to that
  enemy". It never sends damage, hits, XP, currency, drops or rewards.
- The server checks every intent: cooldowns, spirit cost, range and angle, alive/stunned state,
  and a per-action rate limit. It then decides the result and tells clients.
- Clients play animations and effects immediately so combat feels instant. That is *visual*
  prediction only. Movement abilities (Flash Step) move the client right away, and the server
  checks distance and corrects it if needed.
- XP and rewards are granted only by server-side events (enemy defeated by this player, quest step
  completed). Anti-exploit limits from `progression.json` log and clamp suspicious rates. They
  never auto-ban.
- Each ability's `replication` block in `abilities.json` records what must replicate in multiplayer.

### Saving (ProfileStore)
- **ProfileStore** (`lm-loleris/profilestore@1.0.3` on Wally) is the successor to ProfileService
  from the same author, with the same session locking. Session locking stops two servers from
  writing one player's save at once, which is the classic cause of item duplication and data loss.
  It saves periodically and on leave or shutdown, not on every event.
- The save is **versioned** (`schema_version`) with step-by-step migrations.
- The save is **validated** before every write. If validation fails, the write is skipped and the
  last good save stays.
- The game cannot save until a profile has fully loaded and passed validation, so a half-loaded
  profile can never overwrite a good one.
- **Corruption handling:** load, then validate, then try a migration, then fall back to the
  latest backup snapshot. The broken data is quarantined, never deleted.
- **Contents:** appearance, level, XP, skills, equipment, inventory, quests, regions, settings,
  claimed milestones.
- The **dev-only progress reset** works only inside Roblox Studio. A test confirms it refuses
  everywhere else. No admin cheats ship to players.

### Input
One action map, built from `input_actions.json`. Game code asks "was `light_attack` pressed?",
never "was MouseButton1 pressed?". The last input device used decides which button icons show,
and remapping is saved per player. Input names follow Roblox KeyCode names, and the PC edition
maps the same names to Godot inputs.

### Performance plan (measured, never assumed)
Pooled projectiles, effects and damage numbers. Particle budgets per quality level. Enemy AI
ticks at about 10 Hz, slower when far away. Combat is event-driven, never per-frame on the
server. State updates are batched. StreamingEnabled for large maps. Targets (60 fps on PC, a
stable 30 fps on a 2021 mid-range phone on Low) are only reported as met after measuring with
the MicroProfiler and Developer Console on real devices.

### Testing
- **Tool tests** (now): `python3 tools/run_tests.py`.
- **Rules tests** (Phase 1): Lune runs the pure `Rules/` modules. That covers damage math, XP and
  level cap, rewards granted once, equip rules, inventory, save/load and corrupted saves, and
  rejection of client-claimed XP.
- **In-Studio checks** (Phase 1): the parts that need Roblox (remotes, ProfileStore) are tested
  in Studio, plus a manual smoke-test checklist each phase.

## 6. PC edition (Phase 6, only after the Roblox edition is fun)
- Godot 4.x with GDScript, reading the same validated JSON (copied into `pc-game/data/` at build).
- Steam: Steamworks sits behind an optional integration layer, enabled only in the Steam export
  preset, and added only once you have SDK access.
- Standalone: no Steam dependency, local saves with an export option, Windows installer first.
- Anything licensed only for Roblox (default animations, built-in fonts) gets replaced first.
  `ASSET_LICENSES.md` marks those rows.
- No PlayStation claims: a native release needs Sony's developer program and certification.

## 7. Rules that never bend
- No pay-to-win, no forced ads, no real-money power. The schemas have no field for it.
- No copied or ripped content, and no one-to-one renames of another franchise.
- Placeholders are always labelled as placeholders.

## 8. Decision log

| Decision | Why |
|---|---|
| Python standard library for tools | Already installed; nothing to set up; runs anywhere |
| Own small JSON Schema checker | No packages to install; refuses unknown keywords so checks can't silently switch off |
| `$schema` line in every data file | Free VS Code autocomplete and error highlighting |
| Global ids with type prefixes | Typos and wrong-type references are caught automatically |
| Stored XP table | Identical numbers in both engines |
| Frozen, committed Luau modules | Shared data can't be changed by accident; Rojo works without running Python |
| Rokit with pinned versions | Same tool versions every time |
| ProfileStore instead of ProfileService | Same author, newer, same session locking |
| Roblox KeyCode names for inputs | Roblox ships first; the PC edition maps them later |
