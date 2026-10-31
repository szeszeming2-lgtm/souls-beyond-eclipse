// Entry point: loads the data, wires input -> game -> screen, runs the frame loop.

import rawData from "./gamedata.js";
import { Game } from "./game.js";
import { Input } from "./input.js";
import { Renderer } from "./render.js";
import { UI } from "./ui.js";
import { Touch } from "./touch.js";

function deepFreeze(o) {
  if (o && typeof o === "object" && !Object.isFrozen(o)) {
    Object.freeze(o);
    for (const v of Object.values(o)) deepFreeze(v);
  }
  return o;
}

const data = deepFreeze(rawData);
const canvas = document.querySelector("#game");
const game = new Game(data);
const input = new Input(data, canvas);
const renderer = new Renderer(canvas, game);
const ui = new UI(game, input, renderer);
new Touch(input, game);

// Actions -> game
const NOT_YET = new Set(["ability_2", "ability_3", "ultimate"]);
input.on("pressed", (id, dir) => {
  if (ui.view) {
    if (id === "menu_navigate") ui.navigate(dir);
    else if (id === "menu_confirm") ui.confirm();
    else if (id === "menu_back" || (id === "pause" && ui.view !== "title")) ui.back();
    else if ((id === "menu_tab_next" || id === "menu_tab_prev") && ui.view === "settings") {
      ui.tab = (ui.tab + (id === "menu_tab_next" ? 1 : -1) + ui.tabCount) % ui.tabCount;
      ui.openSettings();
    }
    return;
  }
  if (!game.running) return;
  switch (id) {
    case "light_attack": game.tryMelee("light"); break;
    case "heavy_attack": game.tryMelee("heavy"); break;
    case "ability_1": game.castSpecial(); break;
    case "dodge_sprint": game.dodge(); break;
    case "guard": game.setGuard(true); break;
    case "lock_on": game.toggleLock(); break;
    case "pause": ui.openPause(); break;
    case "interact": if (game.atHub) ui.openUpgrade(); else ui.toast("Upgrades are at the Ferry Terminal Outpost (orange circle on the map).", "dim"); break;
    default:
      if (NOT_YET.has(id)) {
        const label = data.inputActions.actions.find((a) => a.id === id)?.label ?? id;
        ui.toast(`${label}: not in this build yet`, "dim", 2);
      }
  }
});
input.on("released", (id) => {
  if (id === "guard" && game.running) game.setGuard(false);
});
game.on("vibrate", (strength, ms) => {
  if (game.setting("vibration") !== false) input.vibrate(strength, ms);
});

// Save when the tab is hidden or closed.
addEventListener("visibilitychange", () => {
  if (document.hidden && game.running) {
    game.persist();
    if (!ui.view) ui.openPause();
  }
});
addEventListener("pagehide", () => { if (game.running) game.persist(); });

// Dev-only handle for local testing (never on the live site).
if (["localhost", "127.0.0.1"].includes(location.hostname)) window.__sbe = { game, input, ui, renderer };

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  input.pollGamepad();
  if (game.running && !ui.view) {
    // aiming: mouse position, else right stick, else movement direction
    if (input.device === "keyboard_mouse" && input.mouse.active) {
      game.aimMode = "mouse";
      game.aimPoint = renderer.toWorld(input.mouse.x, input.mouse.y);
    } else if (input.device === "gamepad" && Math.hypot(input.rightStick.x, input.rightStick.y) > 0.3) {
      game.aimMode = "stick";
      game.aimStick = input.rightStick;
    } else {
      game.aimMode = "move";
    }
  }
  game.update(dt, input);
  if (game.running) renderer.draw();
  ui.updateHud(dt);
  requestAnimationFrame(frame);
}

ui.showTitle();
requestAnimationFrame(frame);
