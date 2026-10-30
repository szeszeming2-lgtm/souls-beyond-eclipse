# Setup

What to install, and the exact commands. You are on macOS (Apple silicon).

## Already installed (nothing to do)
- **Git** 2.54
- **Python** 3.14 (all data tools use it; no extra packages needed)
- **Roblox Studio**, **VS Code**, **Homebrew**

## Install now (for Phase 1)

### 1. Rokit (installs the Roblox toolchain at pinned versions)
Open Terminal and run:

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Close Terminal and open it again so the `rokit` command is found.

### 2. The project's tools (Rojo, Wally, Selene, StyLua, Lune)
Go to the project folder. The folder name has a space in it, so keep the quotes:

```bash
cd "/Users/szeming/projects/visition/untitled folder"
```

```bash
rokit install
```

Rokit asks whether to trust each tool the first time. Answer yes. Then check they work:

```bash
rojo --version
```

### 3. The Rojo plugin for Roblox Studio

```bash
rojo plugin install
```

Restart Roblox Studio afterwards.

### 4. VS Code extensions
Open the project folder in VS Code. It will offer the recommended extensions (Luau Language
Server, Rojo, StyLua, Selene). Click **Install All**.

### 5. Check everything
```bash
python3 tools/check_all.py
```
The Selene, StyLua and Rojo steps now run instead of showing SKIPPED.

## Playtest in Roblox Studio (two ways)

**Live sync (best while developing).** Changes on disk appear in Studio instantly.
1. In Terminal, from the project folder:
   ```bash
   rojo serve roblox-game
   ```
   Leave it running.
2. In Roblox Studio, open a new **Baseplate**.
3. **Plugins** tab → **Rojo** → **Connect** (it connects to `localhost:34872`).
4. Press **Play**. Open **View → Output**. In Phase 0 you should see two lines starting with
   `[SBE] Phase 0 smoke test PASSED`.

**Build a place file (one-off).**
```bash
rojo build roblox-game -o builds/SoulsBeyondEclipse.rbxl
```
Then open `builds/SoulsBeyondEclipse.rbxl` in Roblox Studio and press Play.

## Later
- **Phase 1 (saving):** saves only work in Studio once the place is published to your Roblox
  account and **Game Settings → Security → Enable Studio Access to API Services** is on. Phase 1
  walks through it.
- **Phase 6:** Godot 4.x, and a Steamworks partner account for the Steam build.

## Optional: rename the project folder
`untitled folder` has a space in it, so every command needs quotes. You could rename it to
something like `souls-beyond-eclipse` between phases. Close this session first, rename it in
Finder, then reopen the new folder.
