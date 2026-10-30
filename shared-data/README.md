# shared-data

All game content lives here as JSON: names, stats, abilities, enemies, quests, maps,
progression, input bindings. Both the Roblox and PC editions read it. Game code never hard-codes
any of it.

## Files

| File | What it holds |
|---|---|
| `factions.json` | The six playable factions and the enemy faction |
| `archetypes.json` | Fighting styles: kit, weapon classes, skill tree |
| `skill_trees.json` | Skill tree nodes (respec any time) |
| `movesets.json` | Light and heavy combo chains per weapon class |
| `abilities.json` | Weapon specials, style abilities, guard, dodge, ultimates, passives |
| `status_effects.json` | Buffs and debuffs |
| `items/weapons.json` | Weapons, each with 5 upgrade tiers |
| `items/materials.json` | Upgrade and crafting materials |
| `enemies.json` | Enemies and bosses: attacks, tells, phases, rewards |
| `characters.json` | Story characters |
| `quests.json` | Main, side and training quests |
| `regions.json` | The 11 world regions |
| `maps/*.json` | Playable map layouts: blockout, hubs, fast travel, landmarks, spawns, secrets |
| `progression/progression.json` | Level cap, XP curve settings, bands, milestones, fairness rules |
| `progression/xp_table.json` | **Generated** by `tools/xp_sim/xp_sim.py --write-table`. Do not edit |
| `combat.json` | Global combat rules and fairness limits |
| `difficulty.json` | Story, Normal, Hard, Challenge, boss assists, death rules |
| `input_actions.json` | Every input action with keyboard, gamepad and touch bindings |
| `customization.json` | Character-creation options (cosmetic only) |
| `assets.json` | Every art and audio asset: spec, placeholder, source, license |
| `schemas/` | The rules each file must follow |

## Ids

Every entry has an id: a prefix, an underscore, then lowercase words joined by underscores.
Ids are unique across all files.

| Prefix | Kind | Prefix | Kind |
|---|---|---|---|
| `fac_` | faction | `qst_` | quest |
| `arc_` | archetype (style) | `reg_` | region |
| `skt_` | skill tree | `map_` | map |
| `mvs_` | moveset | `bnd_` | level band |
| `abl_` | ability | `hub_` | hub |
| `sts_` | status effect | `ftp_` | fast-travel point |
| `wpn_` | weapon | `lmk_` | landmark |
| `mat_` | material | `spz_` | spawn zone |
| `enm_` | enemy or boss | `arn_` | boss arena |
| `chr_` | character | `sec_` | secret |
| `cos_` | cosmetic option | `ast_` | asset |
| `cur_` | currency | | |

Small ids that only matter inside one entry (an enemy's attack, a skill tree node, a quest
objective) have no prefix, for example `"id": "swipe"`.

## Build status

Every entry has `dev_status`:
- `concept`: idea only; numbers may be missing
- `data_only`: complete data, **not in the game yet**
- `in_progress`: being built
- `playable_placeholder`: works in game with placeholder art
- `final`: shipped quality

## Other conventions
- Distances and positions are in Roblox **studs**; y is up. Map cylinders stand upright.
- Times are in seconds (`_s`), and `_pct` means percent.
- XP and currency in rewards are **level-1 values**; the server scales them by content level.
- Leave optional fields out rather than writing `null`.

## After editing

```bash
python3 tools/validate_data.py
```

```bash
python3 tools/convert_to_luau.py
```

If you changed the XP curve in `progression.json`, also run:

```bash
python3 tools/xp_sim/xp_sim.py --write-table
```

Or run every check at once:

```bash
python3 tools/check_all.py
```
