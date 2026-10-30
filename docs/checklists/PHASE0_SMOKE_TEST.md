# Phase 0 manual smoke test

Tick each box yourself. Steps 1–4 work right now. Steps 5–7 need the tools from `docs/SETUP.md`.

- [ ] **1. Everything checks out.** Run `python3 tools/check_all.py`. The last line starts with `PASS`.
- [ ] **2. Autocomplete works.** Open `shared-data/items/weapons.json` in VS Code. Inside an entry,
      type a new line `"` and see field suggestions. Hover `rarity` and see its allowed values.
- [ ] **3. Mistakes get caught.** In `weapons.json` change `"rarity": "common"` to `"rarity": "comon"`
      and run `python3 tools/validate_data.py`. It reports the error and suggests `"common"`.
      Undo the change and run it again: `PASS`.
- [ ] **4. XP pacing report.** Run `python3 tools/xp_sim/xp_sim.py`. All 6 targets say `PASS`.
- [ ] **5. Tools installed.** After `rokit install`, `python3 tools/check_all.py` shows no SKIPPED lines.
- [ ] **6. Place builds.** `rojo build roblox-game -o builds/SoulsBeyondEclipse.rbxl` finishes with no errors.
- [ ] **7. Data loads in Roblox.** Open the built place (or use `rojo serve`), press Play. The Output
      window shows `[SBE] Phase 0 smoke test PASSED on the server` and `... on the client`.

If any step fails, copy the message and send it to me.
