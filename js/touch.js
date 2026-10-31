// On-screen controls for phones and tablets: a stick that appears where your thumb lands,
// swipe anywhere else to turn the camera, and large buttons. Layouts: standard, one-handed
// left, one-handed right. Shown only for touch.

const BUTTONS = [
  { action: "light_attack", label: "Attack", size: 112, x: 150, y: 150 },
  { action: "heavy_attack", label: "Heavy", size: 76, x: 278, y: 128 },
  { action: "dodge_sprint", label: "Dodge", size: 76, x: 150, y: 278 },
  { action: "guard", label: "Guard", size: 76, x: 262, y: 236 },
  { action: "ability_1", label: "Wickflare", size: 70, x: 372, y: 178 },
  { action: "lock_on", label: "Lock", size: 58, x: 56, y: 262 },
  { action: "interact", label: "Upgrade", size: 58, x: 56, y: 356 },
  { action: "pause", label: "☰", size: 50, x: 40, y: -1 },
];
const STICK_RADIUS = 60;

export class Touch {
  constructor(input, game) {
    this.input = input;
    this.game = game;
    this.root = document.querySelector("#touch");
    this.zone = document.querySelector("#stick-zone");
    this.camZone = document.querySelector("#cam-zone");
    this.stick = document.querySelector("#stick");
    this.knob = document.querySelector("#stick-knob");
    this.box = document.querySelector("#touch-buttons");
    this.buttons = BUTTONS.map((b) => this.makeButton(b));
    this.stickId = null;

    this.zone.addEventListener("pointerdown", (e) => {
      if (e.pointerType === "mouse" || this.stickId !== null) return;
      this.stickId = e.pointerId;
      this.origin = { x: e.clientX, y: e.clientY };
      this.stick.style.left = `${e.clientX}px`;
      this.stick.style.top = `${e.clientY}px`;
      this.knob.style.transform = "";
      this.stick.classList.remove("hidden");
      try { this.zone.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
      input.setTouchMove(0, 0);
    });
    this.zone.addEventListener("pointermove", (e) => {
      if (e.pointerId !== this.stickId) return;
      let dx = e.clientX - this.origin.x, dy = e.clientY - this.origin.y;
      const l = Math.hypot(dx, dy);
      if (l > STICK_RADIUS) { dx *= STICK_RADIUS / l; dy *= STICK_RADIUS / l; }
      this.knob.style.transform = `translate(${dx}px, ${dy}px)`;
      input.setTouchMove(dx / STICK_RADIUS, -dy / STICK_RADIUS);
    });
    const end = (e) => {
      if (e.pointerId !== this.stickId) return;
      this.stickId = null;
      this.stick.classList.add("hidden");
      input.setTouchMove(0, 0);
    };
    this.zone.addEventListener("pointerup", end);
    this.zone.addEventListener("pointercancel", end);

    // Camera: one finger swiping outside the stick and buttons turns the view.
    this.camId = null;
    this.camZone.addEventListener("pointerdown", (e) => {
      if (e.pointerType === "mouse" || this.camId !== null) return;
      this.camId = e.pointerId;
      this.camLast = { x: e.clientX, y: e.clientY };
      try { this.camZone.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
      input.setDevice("touch");
    });
    this.camZone.addEventListener("pointermove", (e) => {
      if (e.pointerId !== this.camId) return;
      input.addLook(e.clientX - this.camLast.x, e.clientY - this.camLast.y);
      this.camLast = { x: e.clientX, y: e.clientY };
    });
    const camEnd = (e) => { if (e.pointerId === this.camId) this.camId = null; };
    this.camZone.addEventListener("pointerup", camEnd);
    this.camZone.addEventListener("pointercancel", camEnd);
    input.on("device", () => this.refresh());
    game.on("setting", () => this.refresh());
    game.on("started", () => this.refresh());
    addEventListener("resize", () => this.refresh());
    this.refresh();
  }

  makeButton(spec) {
    const b = document.createElement("button");
    b.className = "tbtn";
    b.textContent = spec.label;
    let pointer = null;
    b.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      pointer = e.pointerId;
      try { b.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
      b.classList.add("down");
      this.input.touchPress(spec.action);
    });
    const up = (e) => {
      if (e.pointerId !== pointer) return;
      pointer = null;
      b.classList.remove("down");
      this.input.touchRelease(spec.action);
    };
    b.addEventListener("pointerup", up);
    b.addEventListener("pointercancel", up);
    this.box.append(b);
    return { el: b, spec };
  }

  refresh() {
    const show = this.input.device === "touch" && this.game.running;
    this.root.classList.toggle("hidden", !show);
    document.body.classList.toggle("touch", show);
    const layout = this.game.running ? this.game.setting("touch_layout") || "standard" : "standard";
    const scale = this.game.running ? this.game.setting("touch_ui_scale") || 1 : 1;
    this.root.className = show ? layout : "hidden";
    const onLeft = layout === "one_handed_left";
    const compact = layout !== "standard";
    const small = Math.max(0.6, Math.min(1, innerWidth / 620, innerHeight / 620)); // fit narrow phones
    for (const { el, spec } of this.buttons) {
      const k = scale * small * (compact ? 0.8 : 1);
      const size = spec.size * k;
      el.style.width = el.style.height = `${size}px`;
      el.style.fontSize = `${Math.max(11, size * 0.2)}px`;
      if (spec.y < 0) { // pause: under the health panel, away from the action buttons
        el.style.top = "calc(150px + env(safe-area-inset-top))";
        el.style.bottom = "auto";
        el.style.left = onLeft ? "auto" : "14px";
        el.style.right = onLeft ? "14px" : "auto";
        el.style.marginLeft = "0";
        continue;
      }
      const x = spec.x * k, y = spec.y * k + (compact ? 150 * k : 0);
      el.style.top = "auto";
      el.style.bottom = `${y - size / 2}px`;
      el.style.marginLeft = "0";
      if (onLeft) { el.style.left = `${x - size / 2}px`; el.style.right = "auto"; }
      else { el.style.right = `${x - size / 2}px`; el.style.left = "auto"; }
    }
  }
}
