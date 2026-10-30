# Roadmap

Each phase ends with tests, an updated `PROGRESS.md`, a commit and a plain-language report.
**Work stops after every phase until you approve the next one.**

Content grows by phase: a few fully working, distinct things beat hundreds of placeholders.

## Phase 0: Plan (this phase)
- Inspect the workspace and list what to install.
- Docs: architecture, roadmap, progress, asset licenses, game design, setup.
- `shared-data/` schemas for every data type, with first data entries.
- Tools: validator, Luau converter, XP simulator, asset-doc generator, one-command check, tests.
- **Done when:** `python3 tools/check_all.py` passes, and you have approved the plan and design.

## Phase 1: Roblox playable prototype
Builds: one small region (Akeboshi Harbor District) as blockout, generated from
`map_akeboshi_harbor.json`, and one original character on a placeholder rig.
- Movement and third-person camera; lock-on.
- One weapon (Hearthwick) with the light chain, heavy chain, dodge (Flash Step), guard and
  parry, plus one special ability (Wickflare).
- One enemy (Gloamling) and one boss (Lampeater, 3 phases), with readable tells.
- Health, damage, damage numbers (toggleable), stagger with immunity.
- XP and leveling to 50 (curve already designed). Level-up rewards are granted once.
- HUD: health, spirit, XP bar and level, ability cooldown, boss bar.
- Pause menu and graphics menu (respecting Roblox's quality system).
- Saving and loading with ProfileStore: versioned, validated, with a dev-only reset.
- Unified input: keyboard and mouse, gamepad, touch (virtual stick and big buttons).
- Tests: Lune rules tests (damage, XP and cap, rewards once, equip, inventory, save/load and
  corrupted saves, server rejection of client-claimed XP), plus a Studio smoke-test checklist.
- **Needs from you:** Rokit and the tools installed (`docs/SETUP.md`). For saving in Studio, the
  place published to your Roblox account with Studio API access turned on (Phase 1 explains how).

## Phase 2: Vertical slice
- Short quest chain (Seven Minutes of Night, then Lights Out on the Promenade) and the training
  area (Wick Drills).
- Several enemy types; a complete Lampeater fight with checkpoints and boss assists.
- 5 distinct weapons with working upgrades.
- Character customization with preview and presets.
- Difficulty modes (switchable any time) and assist options.

## Phase 3: Core systems
- Full XP curve to 3000, re-simulated against the real content counts.
- Items, crafting and loadouts; party/style swap and respec.
- Searchable quest log, quest markers, fast travel.

## Phase 4: Content, one level band at a time
Each band gets its maps, quests, bosses and weapons before the next band starts.

| Levels | Arc | Regions |
|---|---|---|
| 1–250 | Seven Minutes of Night | Akeboshi City, Ura-Akeboshi |
| 251–700 | Lanterns in the Mist | Amagiri (Mistbound Capital), The Thousand Stacks |
| 701–1000 | The Silent Bell (side arc) | Shirokane Peaks |
| 1001–1700 | Tide of Ink | The Inverse Tide, Kurogane Caldera |
| 1701–2000 | Two Suns | Tenkyu, the Floating Palace |
| 2001–2700 | Hakumei | The Hakumei Rift, The Sun Below |
| 2701–3000 | Corona (endgame) | The Corona Abyss |

## Phase 5: Multiplayer (Roblox)
- Optional co-op and group bosses. The story never requires multiplayer.
- Server validation, fair reward split, disconnect handling.

## Phase 6: PC edition
- Godot 4.x project using the same `shared-data/`.
- Steam and standalone packaging configs, build scripts, `docs/STEAM_STORE_CHECKLIST.md`.
- Replace every asset that is only licensed for Roblox.
- **Needs from you:** Godot installed; Steamworks partner account and SDK access (only for the
  Steam build).

## Phase 7: Polish
- Performance passes measured on real devices.
- Accessibility audit, balance from simulation results.
- Playtest checklist and an honest known-issues list.

## Things only you can provide (any phase)
3D models, final art, animation, music, sound, voice acting, Steam and console accounts or SDKs,
and money for any licensed assets. Until they exist, the game uses clearly labelled placeholders.
Each one has a written spec in `docs/ASSET_SPECS.md`.
