// HUD, notifications, title screen, pause/settings menus and the hub upgrade panel.
// Menus work with mouse, touch, keyboard (arrows/WASD + Enter, Esc to go back) and gamepad.

import * as Save from "./save.js";
import { drawMinimap } from "./minimap.js";

// Settings this browser edition cannot act on yet are hidden instead of pretending to work.
const WEB_UNSUPPORTED = new Set(["master_volume", "music_volume", "sfx_volume", "subtitles"]);
const HIDDEN_ACTIONS = new Set(["jump"]);
const COLORS = { good: "#78d28c", accent: "#f2a33a", boss: "#ff6b80", spirit: "#f2c14e", dim: "#aaa8b4", bad: "#ff8a8a" };

const $ = (sel) => document.querySelector(sel);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
const fmt = (n) => Math.floor(n).toLocaleString("en-US");

export class UI {
  constructor(game, input, renderer) {
    this.game = game;
    this.input = input;
    this.renderer = renderer;
    this.view = null; // null | "title" | "pause" | "settings" | "controls" | "upgrade" | "confirm"
    this.tab = 0;
    this.focusIndex = 0;
    this.hudClock = 0;
    this.mapClock = 0;
    this.buildSlots();
    $("#menu-button").addEventListener("click", () => this.openPause());

    game.on("toast", (text, kind) => this.toast(text, kind));
    game.on("levelup", (level, milestones, atCap) => {
      this.toast(`Level ${level}!${atCap ? "  (highest level in this build)" : ""}`, "accent");
      for (const m of milestones) this.toast(`Milestone: ${m}`, "spirit");
    });
    game.on("died", () => this.toast("You fell. Back in a moment: no progress or items lost.", "dim"));
    game.on("boss_defeated", (def) => this.toast(`${def.name} defeated!`, "accent", 5));
    game.on("assist", (a) => this.assist(a));
    game.on("setting", (id, v) => this.applySetting(id, v));
    game.on("started", () => { for (const [id, v] of Object.entries(game.save.settings)) this.applySetting(id, v); });
    input.on("device", () => this.refreshHints());
  }

  // ---------------------------------------------------------------- HUD
  buildSlots() {
    const g = this.game;
    const slots = $("#slots");
    slots.innerHTML = "";
    this.slots = [
      { action: "ability_1", name: g.special.name, ability: g.special.id },
      { action: "dodge_sprint", name: g.dodgeAbility.name, ability: g.dodgeAbility.id },
      { action: "ultimate", name: `${g.data.abilities.find((a) => a.id === "abl_eclipse_form").name} (later)`, locked: true },
    ].map((s) => {
      const box = el("div", "slot" + (s.locked ? " locked" : ""));
      const key = el("div", "key"), name = el("div", "name", s.name), cover = el("div", "cover"), timer = el("div", "timer");
      box.append(key, name, cover, timer);
      slots.append(box);
      return { ...s, key, cover, timer };
    });
    this.refreshHints();
  }

  refreshHints() {
    for (const s of this.slots || []) s.key.textContent = this.input.hint(s.action) || "-";
    $("#menu-button").textContent = `Menu [${this.input.hint("pause") || "☰"}]`;
  }

  updateHud(dt) {
    const g = this.game;
    if (!g.running) return;
    this.hudClock += dt;
    this.mapClock += dt;
    if (this.mapClock > 0.2) { this.mapClock = 0; drawMinimap($("#minimap"), g, g.viewYaw || 0); }
    const capture = this.input.device === "keyboard_mouse" && !this.view && !this.input.locked() && !this.input.lockFailed;
    $("#look-hint").classList.toggle("hidden", !capture);
    if (this.hudClock < 0.1) return;
    this.hudClock = 0;
    const p = g.player, sv = g.save;
    const set = (sel, frac, text) => {
      const bar = $(sel);
      bar.querySelector(".fill").style.width = `${Math.max(0, Math.min(1, frac)) * 100}%`;
      const span = bar.querySelector("span");
      if (span && text !== undefined) span.textContent = text;
    };
    $("#level").textContent = `Lv ${sv.level}`;
    set(".bar.hp", p.hp / p.maxHp, `${fmt(p.hp)} / ${fmt(p.maxHp)}`);
    set(".bar.spirit", p.spirit / g.P.stat_scaling.spirit_max, `Spirit ${Math.floor(p.spirit)} / ${g.P.stat_scaling.spirit_max}`);
    if (sv.level < g.cap) {
      const need = g.data.xpToNext[sv.level - 1];
      set(".bar.xp", sv.xp / need);
      $("#xp-text").textContent = `XP ${fmt(sv.xp)} / ${fmt(need)} · ${fmt(need - sv.xp)} to level ${sv.level + 1}`;
    } else {
      set(".bar.xp", 1);
      $("#xp-text").textContent = `Highest level in this build (${g.cap})`;
    }
    const mats = Object.entries(sv.materials).map(([id, n]) => `${g.materials[id]?.name ?? id} ${n}`);
    $("#marks").textContent = `Marks ${fmt(sv.marks)}${mats.length ? " · " + mats.join(" · ") : ""}`;

    const effects = $("#effects");
    const chips = Object.entries(p.effects).map(([id, e]) => {
      const name = g.statuses[id]?.name ?? g.abilities[id]?.name ?? id;
      return `${name} ${Math.ceil(e.until - g.t)}s`;
    });
    const key = chips.join("|");
    if (key !== this.effectsKey) {
      this.effectsKey = key;
      effects.innerHTML = "";
      for (const c of chips) effects.append(el("div", "chip", c));
    }

    for (const s of this.slots) {
      let frac = 0, remain = 0;
      if (s.locked) frac = 1;
      else if (s.ability) {
        const until = p.cooldowns[s.ability] || 0;
        const total = g.abilities[s.ability].cooldown_s;
        remain = Math.max(0, until - g.t);
        frac = total > 0 ? remain / total : 0;
      }
      s.cover.style.height = `${frac * 100}%`;
      s.timer.textContent = remain > 0.4 ? Math.ceil(remain) : "";
    }

    const b = g.boss.live;
    const showBoss = b && b.alive && g.nearBoss;
    $("#boss").classList.toggle("hidden", !showBoss);
    if (showBoss) {
      const phases = g.boss.def.boss.phases;
      $("#boss-name").textContent = `${g.boss.def.name}, ${g.boss.def.boss.title}`;
      set(".bar.boss-bar", b.hp / b.maxHp, `${fmt(b.hp)} / ${fmt(b.maxHp)}`);
      $("#boss-phase").textContent = `Phase ${g.boss.phase + 1} of ${phases.length}: ${phases[g.boss.phase].name}`;
    }
    $("#lock-text").textContent = g.lockTarget ? `Locked on: ${g.lockTarget.def.name}` : "";
    const hint = $("#hub-hint");
    hint.classList.toggle("hidden", !g.atHub);
    if (g.atHub) hint.textContent = `${g.hub.name}: healing and saved · ${this.input.hint("interact") || "Interact"} to upgrade ${g.weapon.name}`;
  }

  // ---------------------------------------------------------------- toasts and prompts
  toast(text, kind = "", seconds = 3) {
    const t = el("div", "toast", text);
    if (COLORS[kind]) t.style.color = COLORS[kind];
    $("#toasts").append(t);
    while ($("#toasts").children.length > 5) $("#toasts").firstChild.remove();
    setTimeout(() => { t.style.opacity = "0"; setTimeout(() => t.remove(), 300); }, seconds * 1000);
  }

  assist(a) {
    let text = `Tip: ${a.tip}`;
    if (a.offers.includes("suggested_level") && a.suggested) text += ` Suggested level: ${a.suggested}.`;
    if (!a.offers.includes("support_buff")) { this.toast(text, "", 8); return; }
    this.openPanel("confirm", (panel) => {
      panel.append(el("h2", "", "Need a hand?"));
      panel.append(el("p", "", text));
      panel.append(el("p", "dim", `Optional: take ${a.buff.name} for this fight (${a.buff.description}). You can always say no.`));
      const row = el("div", "footer");
      row.append(this.button("Yes, help me", () => { this.game.acceptSupportBuff(); this.closeMenu(); this.toast(`${a.buff.name} active.`, "good"); }, "primary"));
      row.append(this.button("No thanks", () => this.closeMenu()));
      panel.append(row);
    });
  }

  // ---------------------------------------------------------------- menus (shared)
  button(text, onClick, cls = "") {
    const b = el("button", `btn ${cls}`.trim(), text);
    b.addEventListener("click", onClick);
    return b;
  }

  focusables() {
    const root = this.view === "title" ? $("#title") : $("#panel");
    return [...root.querySelectorAll("button:not(:disabled)")];
  }

  setFocus(index) {
    const items = this.focusables();
    if (!items.length) return;
    this.focusIndex = (index + items.length) % items.length;
    items.forEach((b, i) => b.classList.toggle("focus", i === this.focusIndex && this.input.device !== "touch"));
    items[this.focusIndex].scrollIntoView?.({ block: "nearest" });
  }

  navigate(dir) {
    const items = this.focusables();
    if (!items.length) return;
    const cur = items[this.focusIndex];
    // inside a settings row, left/right press the row's -/+ buttons
    if (dir.x !== 0 && cur?.closest(".setting")) {
      const row = [...cur.closest(".setting").querySelectorAll("button")];
      row[dir.x < 0 ? 0 : row.length - 1]?.click();
      return;
    }
    this.setFocus(this.focusIndex + (dir.y < 0 || dir.x > 0 ? 1 : -1));
  }

  confirm() { this.focusables()[this.focusIndex]?.click(); }

  openPanel(view, build) {
    this.view = view;
    this.openedAt = performance.now();
    this.input.releaseMouse();
    this.game.paused = true;
    this.input.setContext("menu");
    const panel = $("#panel");
    panel.innerHTML = "";
    build(panel);
    $("#overlay").classList.remove("hidden");
    this.focusIndex = 0;
    this.setFocus(0);
  }

  closeMenu() {
    this.view = null;
    $("#overlay").classList.add("hidden");
    this.input.setContext("gameplay");
    this.game.paused = false;
    // Take the mouse back for camera look (allowed because closing came from a click or key press).
    if (this.input.device === "keyboard_mouse" && this.game.running && !this.input.lockFailed) this.input.capture();
  }

  back() {
    if (this.view === "settings" || this.view === "controls") this.openPause();
    else if (this.view === "title" || this.view === "confirm-new") this.showTitle();
    else if (this.view) this.closeMenu();
  }

  // ---------------------------------------------------------------- title
  showTitle() {
    this.view = "title";
    this.game.paused = true;
    this.input.setContext("menu");
    $("#overlay").classList.add("hidden");
    $("#title").classList.remove("hidden");
    $("#hud").classList.add("hidden");
    const box = $("#title-buttons");
    box.innerHTML = "";
    const has = Save.hasSave();
    if (has) box.append(this.button("Continue", () => this.startGame(false), "primary"));
    box.append(this.button("New Game", () => (has ? this.confirmNew() : this.startGame(true)), has ? "" : "primary"));
    box.append(this.button("How to play", () => this.showHowTo()));
    this.focusIndex = 0;
    this.setFocus(0);
  }

  confirmNew() {
    const box = $("#title-buttons");
    box.innerHTML = "";
    box.append(el("p", "", "Start over? Your current save in this browser will be replaced."));
    box.append(this.button("Yes, start a new game", () => this.startGame(true), "primary"));
    box.append(this.button("Back", () => this.showTitle()));
    this.view = "confirm-new";
    this.focusIndex = 0;
    this.setFocus(0);
  }

  showHowTo() {
    const box = $("#title-buttons");
    box.innerHTML = "";
    const p = el("div", "");
    p.style.textAlign = "left";
    p.style.maxWidth = "520px";
    p.innerHTML = `
      <p><b>Goal:</b> clear Gloamlings around the harbor, grow stronger, upgrade your sword at the Ferry Terminal, then defeat the <b>Lampeater</b> on the promenade (the red ring on the map).</p>
      <p><b>Keyboard + mouse:</b> click the game to grab the mouse, then move the mouse to look around (arrow keys work too, wheel zooms) · WASD move · Left click light attack · Right click heavy · Shift dodge (hold to sprint) · C guard, tap just before a hit to <b>parry</b> · Q Wickflare · Tab lock-on · G upgrade at the hub · Esc frees the mouse and pauses.</p>
      <p><b>Gamepad:</b> left stick move · right stick camera · X light · Y heavy · B dodge · LB guard · RB Wickflare · R3 lock-on · Menu button pauses.</p>
      <p><b>Phone/tablet:</b> drag on the left to move, swipe on the right to turn the camera, buttons on the right.</p>
      <p>Attacks go where the camera faces and snap to the nearest enemy in front of you. Lock-on keeps the camera on one enemy.</p>
      <p class="dim">Orange markers on the ground show where an attack will land. A red "!" means it can't be blocked: dodge it.</p>`;
    box.append(p);
    box.append(this.button("Back", () => this.showTitle(), "primary"));
    this.view = "confirm-new";
    this.focusIndex = 0;
    this.setFocus(0);
  }

  startGame(fresh) {
    if (fresh) Save.wipe();
    $("#title").classList.add("hidden");
    $("#hud").classList.remove("hidden");
    this.game.start(fresh);
    this.closeMenu();
    const region = this.game.region;
    this.toast(`${this.game.map.name} · ${region?.name ?? ""}`, "accent", 4);
    if (fresh) this.toast("Defeat Gloamlings, then face the Lampeater on the promenade.", "", 6);
    const boss = this.game.boss.def;
    $("#map-name").textContent = this.game.map.name;
    $("#objective").textContent = `Objective: defeat the ${boss.name}, ${boss.boss.title} (suggested level ${boss.boss.suggested_level})`;
  }

  // ---------------------------------------------------------------- pause, settings, controls
  openPause() {
    this.openPanel("pause", (panel) => {
      panel.append(el("h2", "", "Paused"));
      const list = el("div", "list");
      list.append(this.button("Resume", () => this.closeMenu(), "primary"));
      list.append(this.button("Settings", () => this.openSettings()));
      list.append(this.button("Controls", () => this.openControls()));
      list.append(this.button("Save and quit to title", () => { this.game.persist(); this.game.running = false; this.game.emit("started"); this.showTitle(); }));
      panel.append(list);
      const sv = this.game.save;
      panel.append(el("p", "dim", `Level ${sv.level} · ${this.game.weapon.name} tier ${sv.weapon_tier} · ${Math.floor(sv.play_seconds / 60)} min played · progress saves automatically in this browser.`));
    });
  }

  settingDefs() {
    return this.game.data.settings.settings.filter((d) => d.platforms.includes("pc") && !WEB_UNSUPPORTED.has(d.id));
  }

  openSettings() {
    const tabs = this.game.data.settings.tabs.filter((t) => this.settingDefs().some((d) => d.tab === t.id));
    this.tab = Math.min(this.tab, tabs.length - 1);
    this.openPanel("settings", (panel) => {
      panel.append(el("h2", "", "Settings"));
      const row = el("div", "tabs");
      tabs.forEach((t, i) => row.append(this.button(t.label, () => { this.tab = i; this.openSettings(); }, i === this.tab ? "on" : "")));
      panel.append(row);
      const list = el("div", "list");
      for (const def of this.settingDefs().filter((d) => d.tab === tabs[this.tab].id)) list.append(this.settingRow(def));
      panel.append(list);
      panel.append(el("p", "dim", "Sound and voice come in a later version."));
      const footer = el("div", "footer");
      footer.append(this.button("Restore defaults", () => {
        for (const d of this.settingDefs().filter((x) => x.tab === tabs[this.tab].id)) this.game.setSetting(d.id, d.default);
        this.openSettings();
      }));
      footer.append(this.button("Back", () => this.openPause(), "primary"));
      panel.append(footer);
    });
    this.tabCount = tabs.length;
  }

  settingRow(def) {
    const g = this.game;
    const row = el("div", "setting");
    const label = el("div", "label");
    label.append(el("b", "", def.label));
    if (def.help) label.append(el("small", "", def.help));
    const value = el("div", "value");
    const show = () => {
      const v = g.setting(def.id);
      if (def.kind === "toggle") value.textContent = v ? "On" : "Off";
      else if (def.kind === "slider") value.textContent = def.max <= 1 ? `${Math.round(v * 100)}%` : `${v.toFixed(2)}x`;
      else value.textContent = def.options.find((o) => o.value === v)?.label ?? v;
    };
    const change = (dir) => {
      const v = g.setting(def.id);
      if (def.kind === "toggle") g.setSetting(def.id, !v);
      else if (def.kind === "slider") g.setSetting(def.id, v + def.step * dir);
      else {
        const i = def.options.findIndex((o) => o.value === v);
        g.setSetting(def.id, def.options[(i + dir + def.options.length) % def.options.length].value);
      }
      show();
    };
    row.append(label, this.button(def.kind === "slider" ? "−" : "‹", () => change(-1)), value, this.button(def.kind === "slider" ? "+" : "›", () => change(1)));
    show();
    return row;
  }

  openControls() {
    const g = this.game, input = this.input;
    this.openPanel("controls", (panel) => {
      panel.append(el("h2", "", "Controls"));
      const list = el("div", "list");
      const table = el("table", "controls-table");
      table.innerHTML = "<tr><th>Action</th><th>Keyboard + mouse</th><th>Gamepad</th><th>Touch</th></tr>";
      for (const a of g.data.inputActions.actions) {
        if (a.context !== "gameplay" || HIDDEN_ACTIONS.has(a.id)) continue;
        const later = ["ability_2", "ability_3", "ultimate"].includes(a.id) ? " (later)" : "";
        const tr = document.createElement("tr");
        for (const text of [a.label + later, input.bindingsText(a.id, "keyboard_mouse"), input.bindingsText(a.id, "gamepad"), input.bindingsText(a.id, "touch")]) tr.append(el("td", "", text));
        table.append(tr);
      }
      list.append(table);
      list.append(el("p", "dim", "Attacks go where the camera faces. Camera sensitivity and invert Y are in Settings > Controls, where right-click can also switch between heavy attack and guard."));
      panel.append(list);
      const footer = el("div", "footer");
      footer.append(this.button("Back", () => this.openPause(), "primary"));
      panel.append(footer);
    });
  }

  // ---------------------------------------------------------------- hub upgrade
  openUpgrade() {
    const g = this.game;
    this.openPanel("upgrade", (panel) => {
      panel.append(el("h2", "", g.hub.name));
      panel.append(el("p", "", `${g.weapon.name}: tier ${g.save.weapon_tier} of ${g.weapon.upgrade_tiers.length}. ${g.weapon.description}`));
      const u = g.nextUpgrade();
      if (!u) panel.append(el("p", "", "Fully upgraded."));
      else {
        const cost = u.next.materials.map((m) => `${m.qty} ${g.materials[m.material_id].name} (have ${g.save.materials[m.material_id] || 0})`).join(", ");
        panel.append(el("p", "", `Tier ${u.next.tier}: +${u.next.damage_bonus_pct}% damage. Costs ${cost} and ${fmt(u.next.currency_cost)} Marks (have ${fmt(g.save.marks)}).${u.next.min_level ? ` Needs level ${u.next.min_level}.` : ""}`));
        if (u.missing.length) panel.append(el("p", "dim", `Still need: ${u.missing.join(", ")}.`));
      }
      const footer = el("div", "footer");
      const up = this.button("Upgrade", () => { if (g.upgradeWeapon()) this.openUpgrade(); }, "primary");
      up.disabled = !u || u.missing.length > 0;
      footer.append(up, this.button("Close", () => this.closeMenu()));
      panel.append(footer);
    });
  }

  applySetting(id, v) {
    if (id === "text_scale") {
      const base = matchMedia("(max-width: 760px), (max-height: 520px)").matches ? 0.85 : 1;
      document.documentElement.style.setProperty("--ui-scale", String(base * v));
    }
    if (id === "right_click") { this.input.setPresets(v === "guard" ? ["right_click_guard"] : []); this.refreshHints(); }
    if (id === "effects_quality") this.renderer.setQuality(v);
  }
}
