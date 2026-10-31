# Phase 1 manual smoke test

Build and open the place first:

```bash
python3 tools/check_all.py
```

```bash
open builds/SoulsBeyondEclipse.rbxl
```

In Studio press **Play** (F5) and open **View → Output**. Tick each box.

## Start-up
- [ ] Output shows `[SBE] Server started` and `[SBE] Client started`, with no red errors.
- [ ] The harbor district blockout is there: grey ground, buildings, the tall clocktower, harbor
      water, an orange hub pillar, cyan fast-travel pillars, a faint red ring for the boss arena.

## HUD
- [ ] Top left: level, health bar, spirit bar, XP bar and "XP … (… to level 2)".
- [ ] Top right: minimap with your arrow, and the objective below it.
- [ ] Bottom: Wickflare / Flash Step / Eclipse Form slots with key hints (Q, Shift, F).

## Movement and camera (keyboard and mouse)
- [ ] WASD moves relative to the camera; the mouse turns the camera.
- [ ] Space jumps. Tap Shift = quick dash (Flash Step). Hold Shift while moving = sprint.
- [ ] Tab locks on to the nearest enemy (◇ marker); Tab again unlocks.

## Combat
- [ ] Left click swings (orange arc) and hits a Gloamling: white damage numbers, its bar drops.
- [ ] Right click does a heavier swing.
- [ ] Hold C to guard (you walk slower). Press C just before a hit lands: "PARRY" appears and spirit jumps.
- [ ] Gloamlings show an orange ground marker before attacking; before the pounce a red "!" appears
      (it can't be blocked, so dodge it).
- [ ] With 25+ spirit, Q fires Wickflare (a flame wave); the Q slot shows a cooldown.
- [ ] R / E / F say "not in this build yet".

## Progress and saving
- [ ] Defeating a Gloamling gives XP and sometimes "+1 Gloam Dust".
- [ ] The red DEV panel (Studio only): "+100,000 XP" levels you up, stopping at level 50
      ("Highest level in this build").
- [ ] "Reset save" puts you back to level 1.
- [ ] Saving across sessions: in Studio without API access, ProfileStore uses a temporary store, so
      progress resets when you stop. To test real saving, publish the place and turn on
      **Game Settings → Security → Enable Studio Access to API Services**.

## Boss
- [ ] Walk to the red ring on the promenade (south-east). The boss bar appears at the top.
- [ ] At 60% and 25% health a phase banner appears and the attacks change.
- [ ] If you fall in the arena, you respawn next to it, and after 2 defeats a tip appears.

## Menus
- [ ] P opens the pause menu (Esc is Roblox's own menu). Settings has tabs; changing
      Difficulty or Damage numbers takes effect at once; "Restore defaults" works.
- [ ] Backspace or P goes back / closes.

## Other devices
- [ ] Studio **Test → Device** (phone emulator): touch stick and big buttons appear; the stick moves you,
      Attack/Dodge/Guard/Jump work, and dragging on the right side turns the camera.
- [ ] Gamepad (if you have one): left stick moves, X/Y attack, B dodge, LB guard, View opens the menu,
      D-pad + A/B work in menus.

If anything fails, copy the Output text and tell me which box.
