// Entry point: loads the data, wires input -> game -> screen, runs the frame loop.

import rawData from "./gamedata.js";
import { Game } from "./game.js";
import { Input } from "./input.js";
import { Renderer3D } from "./render3d.js";
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
let renderer;
try {
  renderer = new Renderer3D(canvas, game, document.querySelector("#world-ui"));
} catch (err) {
  document.querySelector("#title-buttons").innerHTML =
    "<p>Your browser couldn't start 3D graphics (WebGL). Try another browser, or turn on hardware acceleration.</p>";
  throw err;
}
window.__sbeReady = true;
const ui = new UI(game, input, renderer);
new Touch(input, game);

// Mouse look: clicking the game captures the mouse while playing; Esc frees it and pauses.
input.shouldCapture = () => game.running && !ui.view && input.device === "keyboard_mouse";
document.addEventListener("pointerlockchange", () => {
  if (!input.locked() && game.running && !ui.view) ui.openPause();
});

// Actions -> game
const NOT_YET = new Set(["ability_2", "ability_3", "ultimate"]);
input.on("pressed", (id, dir) => {
  if (ui.view) {
    // Esc that just freed the mouse (and opened the menu) must not also close it.
    if ((id === "menu_back" || id === "pause") && performance.now() - ui.openedAt < 300) return;
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

// Camera turn speeds (radians per pixel for mouse/touch, radians per second for stick/keys).
const MOUSE_TURN = 0.0032, TOUCH_TURN = 0.0065, STICK_TURN = 2.8, KEY_TURN = 2.2;

function steerCamera(dt) {
  const look = input.takeLook();
  if (!game.running || ui.view) return;
  const sens = game.setting("camera_sensitivity") ?? 1;
  const padSens = game.setting("gamepad_sensitivity") ?? 1;
  const invert = game.setting("invert_camera_y") ? -1 : 1;
  const k = (input.device === "touch" ? TOUCH_TURN : MOUSE_TURN) * sens;
  let dx = look.x * k, dy = look.y * k;
  const rs = input.rightStick, keys = input.cameraKeys();
  dx += (rs.x * STICK_TURN * padSens + keys.x * KEY_TURN * sens) * dt;
  dy += (-rs.y * STICK_TURN * 0.6 * padSens - keys.y * KEY_TURN * 0.5 * sens) * dt;
  if (dx || dy) renderer.rotateCamera(dx, dy * invert);
  if (look.zoom) renderer.zoomBy(look.zoom * 1.5);
  renderer.autoFollow = input.device === "touch";
  // Attacks go where the camera looks (nudged to the nearest enemy); on touch, toward the nearest enemy.
  game.aimMode = input.device === "touch" ? "move" : "camera";
}

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  input.pollGamepad();
  steerCamera(dt);
  game.update(dt, input);
  if (game.running) renderer.draw(dt);
  ui.updateHud(dt);
  requestAnimationFrame(frame);
}

ui.showTitle();
requestAnimationFrame(frame);
