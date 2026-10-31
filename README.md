# Souls Beyond: Eclipse

An original anime-inspired action RPG prototype that runs in your browser: phone, tablet or computer.

**▶ Play:** https://szeszeming2-lgtm.github.io/souls-beyond-eclipse/

At 12:07 the sun went black over Akeboshi City. Everyone slept, except you. Clear the Gloamlings
around the harbor, grow stronger, upgrade your sword at the Ferry Terminal, then defeat the
**Lampeater** on the promenade.

## Controls

| Action | Keyboard + mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD | Left stick | Drag on the left side |
| Aim | Mouse | Right stick | Auto-aims at the nearest enemy |
| Light attack (4-hit combo) | Left click | X | Attack |
| Heavy attack | Right click | Y | Heavy |
| Dodge (tap) / sprint (hold) | Shift | B | Dodge |
| Guard (tap just before a hit to **parry**) | C | LB | Guard |
| Wickflare (costs spirit) | Q | RB | Wickflare |
| Lock on | Tab | R3 | Lock |
| Upgrade sword (at the hub) | G | D-pad down | Upgrade |
| Menu | Esc | Menu | ☰ |

Orange ground markers show where an enemy attack will land. A red **!** means it can't be blocked,
so dodge it. Right-click can be switched to guard in **Settings → Controls**.

## What's in it
- One district (Akeboshi Harbor) built from the map data, with a hub, landmarks and 3 secrets.
- Combat: light/heavy combos, dodge with invulnerability, guard and parry, Wickflare special,
  lock-on, stagger with immunity (no stun-locks), and readable attack warnings.
- Gloamling enemies that take turns attacking (difficulty decides how many at once).
- The Lampeater boss: 3 phases, checkpoints, optional help if you keep losing.
- XP and levels up to 50 (the curve is designed for 3000), milestones, Marks, materials, sword upgrades.
- Difficulty (Story/Normal/Hard/Challenge, change any time), colour-blind tells, text size, camera
  shake, flash intensity, damage numbers, touch layouts.
- Progress saves automatically in your browser (validated, with a backup copy).

**Honest status:** a playable prototype. All art is placeholder shapes, and there's no sound yet.
Ultimate and extra abilities are not in this build.

## Run it locally
Any static file server works, for example:

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000. Rule tests run in the browser at http://localhost:8000/tests.html.

## Project layout
- `index.html`, `css/style.css`: page and look
- `js/gamedata.js`: all game content (names, stats, map, XP curve). Edit numbers here to rebalance
- `js/rules.js`: game rules (damage, XP, stagger, hit areas, input mapping, settings)
- `js/game.js`: the simulation · `js/render.js`: drawing · `js/ui.js`: HUD and menus
- `js/input.js`, `js/touch.js`: keyboard/mouse, gamepad and touch input · `js/save.js`: saving

The earlier Roblox edition and planning docs are kept in this repository's git history.

All characters, places, story and code are original to this project.
