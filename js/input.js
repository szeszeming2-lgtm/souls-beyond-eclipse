// One input system for keyboard + mouse, gamepad and touch. The game listens for ACTIONS
// ("light_attack"), never keys. Bindings come from the game data (input_actions).

import { buildInputMap, actionFor, directionFor, hintsFor } from "./rules.js";

const PLATFORM = "pc";
const DEADZONE = 0.2;
const PAD_BUTTONS = [
  "ButtonA", "ButtonB", "ButtonX", "ButtonY", "ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2",
  "ButtonSelect", "ButtonStart", "ButtonL3", "ButtonR3", "DPadUp", "DPadDown", "DPadLeft", "DPadRight",
];
const DIGITS = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"];
const KEYS = {
  Space: "Space", ShiftLeft: "LeftShift", ShiftRight: "RightShift", ControlLeft: "LeftControl",
  ControlRight: "RightControl", AltLeft: "LeftAlt", AltRight: "RightAlt", Tab: "Tab", Escape: "Escape",
  Enter: "Return", Backspace: "Backspace", ArrowUp: "Up", ArrowDown: "Down", ArrowLeft: "Left",
  ArrowRight: "Right", CapsLock: "CapsLock",
};
const SHORT = {
  MouseButton1: "LMB", MouseButton2: "RMB", LeftShift: "Shift", Return: "Enter", Escape: "Esc",
  ButtonL1: "LB", ButtonR1: "RB", ButtonL2: "LT", ButtonR2: "RT", ButtonL3: "L3", ButtonR3: "R3",
  ButtonSelect: "View", ButtonStart: "Menu", DPadUp: "D-pad ↑", DPadDown: "D-pad ↓", DPadLeft: "D-pad ←",
  DPadRight: "D-pad →", Thumbstick1: "Left stick", Thumbstick2: "Right stick", "Composite:WASD": "WASD",
  "Composite:Arrows": "Arrows", "Composite:DPad": "D-pad",
};

export function inputLabel(name) {
  if (SHORT[name]) return SHORT[name];
  const b = /^Button(\w)$/.exec(name);
  if (b) return b[1];
  const t = /^TouchButton(.+)$/.exec(name);
  if (t) return t[1];
  return name;
}

function keyName(code) {
  if (code.startsWith("Key")) return code.slice(3);
  if (code.startsWith("Digit")) return DIGITS[Number(code.slice(5))];
  if (/^F\d+$/.test(code)) return code;
  return KEYS[code] || null;
}

export class Input {
  constructor(data, canvas) {
    this.data = data;
    this.context = "gameplay";
    this.device = matchMedia("(pointer: coarse)").matches ? "touch" : "keyboard_mouse";
    this.listeners = { pressed: [], released: [], device: [] };
    this.down = new Map(); // actionId -> time pressed
    this.keysHeld = new Map(); // composite key -> [x, y]
    this.leftStick = { x: 0, y: 0 };
    this.rightStick = { x: 0, y: 0 };
    this.touchMove = { x: 0, y: 0 };
    this.mouse = { x: 0, y: 0, active: false };
    this.padPrev = [];
    this.setPresets([]);

    addEventListener("keydown", (e) => {
      if (e.repeat) return;
      const name = keyName(e.code);
      if (!name) return;
      if (["Tab", "Space", "Up", "Down", "Left", "Right", "Backspace"].includes(name)) e.preventDefault();
      this.setDevice("keyboard_mouse");
      this.begin(name, "keyboard_mouse");
    });
    addEventListener("keyup", (e) => {
      const name = keyName(e.code);
      if (name) this.end(name, "keyboard_mouse");
    });
    addEventListener("blur", () => this.releaseAll());
    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
    canvas.addEventListener("pointerdown", (e) => {
      if (e.pointerType !== "mouse") return;
      this.setDevice("keyboard_mouse");
      this.begin(e.button === 2 ? "MouseButton2" : e.button === 1 ? "MouseButton3" : "MouseButton1", "keyboard_mouse");
    });
    addEventListener("pointerup", (e) => {
      if (e.pointerType !== "mouse") return;
      this.end(e.button === 2 ? "MouseButton2" : e.button === 1 ? "MouseButton3" : "MouseButton1", "keyboard_mouse");
    });
    addEventListener("pointermove", (e) => {
      if (e.pointerType !== "mouse") return;
      this.mouse = { x: e.clientX, y: e.clientY, active: true };
    });
  }

  on(kind, fn) { this.listeners[kind].push(fn); }
  emit(kind, ...args) { for (const fn of this.listeners[kind]) fn(...args); }

  setPresets(presets) { this.map = buildInputMap(this.data.inputActions, PLATFORM, presets); }

  setDevice(device) {
    if (device !== this.device) { this.device = device; this.emit("device", device); }
  }

  setContext(ctx) {
    if (ctx === this.context) return;
    this.releaseAll();
    this.context = ctx;
  }

  releaseAll() {
    for (const id of [...this.down.keys()]) this.finish(id);
    this.keysHeld.clear();
    this.touchMove = { x: 0, y: 0 };
  }

  start(id) {
    if (!this.down.has(id)) { this.down.set(id, performance.now()); this.emit("pressed", id); }
  }

  finish(id) {
    const t = this.down.get(id);
    if (t !== undefined) { this.down.delete(id); this.emit("released", id, (performance.now() - t) / 1000); }
  }

  begin(name, device) {
    const dir = directionFor(this.map, this.context, device, name);
    if (dir && (dir[0] === "move" || dir[0] === "menu_navigate")) {
      this.keysHeld.set(name, [dir[1], dir[2]]);
      if (dir[0] === "menu_navigate") this.emit("pressed", "menu_navigate", { x: dir[1], y: dir[2] });
      return;
    }
    const id = actionFor(this.map, this.context, device, name);
    if (id) this.start(id);
  }

  end(name, device) {
    this.keysHeld.delete(name);
    const id = actionFor(this.map, this.context, device, name);
    if (id) this.finish(id);
  }

  isDown(id) { return this.down.has(id); }

  // Movement: x = right, y = up/forward (screen up), length 0..1.
  moveVector() {
    if (this.context !== "gameplay") return { x: 0, y: 0 };
    if (Math.hypot(this.touchMove.x, this.touchMove.y) > 0.05) return this.touchMove;
    if (Math.hypot(this.leftStick.x, this.leftStick.y) > 0) return this.leftStick;
    let x = 0, y = 0;
    for (const [, d] of this.keysHeld) { x += d[0]; y += d[1]; }
    const l = Math.hypot(x, y);
    return l > 1 ? { x: x / l, y: y / l } : { x, y };
  }

  // Touch controls call these.
  touchPress(id) { this.setDevice("touch"); this.start(id); }
  touchRelease(id) { this.finish(id); }
  setTouchMove(x, y) { this.setDevice("touch"); this.touchMove = { x, y }; }

  hint(id) {
    const names = hintsFor(this.map, id, this.device);
    return names.length ? inputLabel(names[0]) : "";
  }

  bindingsText(id, device) {
    return hintsFor(this.map, id, device).map(inputLabel).join(" / ");
  }

  // Called every frame: reads gamepads (the browser has no gamepad events for buttons).
  pollGamepad() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    const pad = [...pads].find((p) => p && p.connected);
    if (!pad) return;
    const stick = (x, y) => (Math.hypot(x, y) < DEADZONE ? { x: 0, y: 0 } : { x, y: -y });
    this.leftStick = stick(pad.axes[0] || 0, pad.axes[1] || 0);
    this.rightStick = stick(pad.axes[2] || 0, pad.axes[3] || 0);
    if (Math.hypot(this.leftStick.x, this.leftStick.y) > 0 || Math.hypot(this.rightStick.x, this.rightStick.y) > 0) {
      this.setDevice("gamepad");
    }
    pad.buttons.forEach((b, i) => {
      const name = PAD_BUTTONS[i];
      const pressed = b.pressed || b.value > 0.5;
      if (!name || pressed === !!this.padPrev[i]) return;
      this.padPrev[i] = pressed;
      if (pressed) { this.setDevice("gamepad"); this.begin(name, "gamepad"); }
      else this.end(name, "gamepad");
    });
    // Left stick also navigates menus.
    if (this.context === "menu") {
      const s = this.leftStick;
      const dir = Math.abs(s.y) > 0.6 ? { x: 0, y: Math.sign(s.y) } : Math.abs(s.x) > 0.6 ? { x: Math.sign(s.x), y: 0 } : null;
      const key = dir ? `${dir.x},${dir.y}` : null;
      if (key && key !== this.stickNav) this.emit("pressed", "menu_navigate", dir);
      this.stickNav = key;
    }
  }

  vibrate(strength, ms) {
    const pad = [...(navigator.getGamepads ? navigator.getGamepads() : [])].find((p) => p && p.connected);
    pad?.vibrationActuator?.playEffect?.("dual-rumble", { duration: ms, strongMagnitude: strength, weakMagnitude: strength })?.catch?.(() => {});
  }
}
