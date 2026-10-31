# Setup

What is installed, how to check everything, and how to playtest. You are on macOS (Apple silicon).

## Installed

| Tool | Version | What it is for |
|---|---|---|
| Git | 2.54 | Version history |
| Python | 3.14 | Data tools (no extra packages needed) |
| Rokit | 1.2.0 | Installs the pinned Roblox tools below (in `~/.rokit`, added to your PATH by `~/.zshenv`) |
| Rojo | 7.7.1 | Syncs/builds the project into Roblox Studio (Studio plugin installed too) |
| Wally | 0.3.2 | Luau packages. Installed: ProfileStore 1.0.3 |
| Selene | 0.32.0 | Luau linter |
| StyLua | 2.6.0 | Luau formatter |
| Lune | 0.10.5 | Runs the game-rules tests outside Roblox |
| luau-lsp | 1.70.1 | Strict Luau type checker (catches Roblox API typos) |
| Roblox Studio, VS Code, Homebrew | | Already on your Mac |

All tool versions are pinned in `rokit.toml`. On a fresh machine, the whole setup is:

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Then reopen Terminal, go to the project folder (keep the quotes, the name has a space):

```bash
cd "/Users/szeming/projects/visition/untitled folder"
```

```bash
rokit install
```

```bash
cd roblox-game && wally install && cd ..
```

```bash
rojo plugin install
```

VS Code: open the project folder and click **Install All** for the recommended extensions.

## Check everything (run before every commit)

```bash
python3 tools/check_all.py
```

It runs 13 steps: data validation, XP targets, generated files, Python tests, Luau tests (Lune),
lint (Selene), formatting (StyLua), strict type checking (luau-lsp) and a place build (Rojo).

After editing anything in `shared-data/`:

```bash
python3 tools/convert_to_luau.py
```

To reformat Luau code:

```bash
stylua roblox-game/src roblox-game/tests
```

## Playtest in Roblox Studio

**Build a place file (simplest).**

```bash
rojo build roblox-game -o builds/SoulsBeyondEclipse.rbxl
```

```bash
open builds/SoulsBeyondEclipse.rbxl
```

In Studio press **Play** (F5) and open **View → Output**. Then follow
[checklists/PHASE1_SMOKE_TEST.md](checklists/PHASE1_SMOKE_TEST.md). After a rebuild, close the
place in Studio (File → Close Place) and open it again.

**Live sync (best while developing).** Changes on disk appear in Studio immediately.

```bash
rojo serve roblox-game
```

Leave it running, open the built place (or any place) in Studio, then **Plugins → Rojo →
Connect**.

**Phones and tablets:** in Studio, **Test → Device** picks a phone or tablet to emulate, so you
can try the touch controls.

## Saving in Studio
Without API access, ProfileStore automatically uses a temporary in-memory store: everything works,
but progress resets when you stop the test. To test real saving:
1. **File → Publish to Roblox** (private is fine).
2. **Game Settings → Security → Enable Studio Access to API Services**.

## Later
- **Phase 6:** Godot 4.x, and a Steamworks partner account for the Steam build.

## Optional: rename the project folder
`untitled folder` has a space in it, so every command needs quotes. You could rename it to
something like `souls-beyond-eclipse` between phases. Close this session first, rename it in
Finder, then reopen the new folder.
