# Souls Beyond: Eclipse

An original anime-inspired third-person action RPG. Roblox edition first, then a PC edition
(Steam and standalone).

**Current status: Phase 0 (planning and data foundation).** There is no playable game yet.
See [docs/PROGRESS.md](docs/PROGRESS.md) for exactly what exists.

## Quick start

```bash
python3 tools/check_all.py
```

Install the Roblox tools and playtest in Studio: [docs/SETUP.md](docs/SETUP.md).

## Docs
- [Progress](docs/PROGRESS.md): what works, what is placeholder, tests, next step
- [Roadmap](docs/ROADMAP.md): the phases and what each delivers
- [Architecture](docs/ARCHITECTURE.md): how it is built and why
- [Game design](docs/GAME_DESIGN.md): premise, factions, world, story outline
- [Setup](docs/SETUP.md): what to install, how to sync into Roblox Studio
- [Asset licenses](docs/ASSET_LICENSES.md) and [asset specs](docs/ASSET_SPECS.md)
- [Data guide](shared-data/README.md) and [tools guide](tools/README.md)

## Layout
```
docs/          plans, progress, licenses, checklists
shared-data/   all game content as JSON, plus schemas
tools/         validator, Luau converter, XP simulator, tests
roblox-game/   Roblox edition (Rojo project)
builds/        build outputs (not in git)
pc-game/       PC edition (Phase 6)
```

## Rules
Original content only. No ripped or unlicensed assets. No pay-to-win. Every placeholder is
labelled as one.
