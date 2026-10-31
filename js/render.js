// Draws the game on a canvas: the harbor district from the map data, characters, attack tells
// and effects. Everything is placeholder art made from shapes.

const COLORS = {
  ground: "#2b2d38", road: "#1d1e26", lane: "#3a3b46", water: "#17304a", platform: "#4a3f36",
  building: "#565b6c", buildingTop: "#6a7085", landmark: "#a88a62", wall: "#20222c", window: "#ffd38a",
};
const TELL = {
  none: { normal: "#ff8a3d", unblockable: "#ff2e4d" },
  protanopia: { normal: "#ffd23f", unblockable: "#3d7bff" },
  deuteranopia: { normal: "#ffd23f", unblockable: "#3d7bff" },
  tritanopia: { normal: "#ff8a3d", unblockable: "#dc28a0" },
};

function seeded(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32);
}

export class Renderer {
  constructor(canvas, game) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.game = game;
    this.resize();
    addEventListener("resize", () => this.resize());
    this.prepareMap();
  }

  resize() {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    this.dpr = dpr;
    this.w = innerWidth;
    this.h = innerHeight;
    this.canvas.width = Math.floor(this.w * dpr);
    this.canvas.height = Math.floor(this.h * dpr);
    this.ppu = Math.max(4, Math.min(9, Math.min(this.w, this.h) / 105)); // pixels per stud
  }

  prepareMap() {
    const g = this.game;
    this.pieces = g.map.blockout.map((p, i) => {
      const rand = seeded(i * 97 + 13);
      const windows = [];
      if (p.role === "building") {
        const [sx, , sz] = p.size;
        for (let k = 0; k < Math.floor((sx * sz) / 90); k++) windows.push([rand() - 0.5, rand() - 0.5, rand() > 0.35]);
      }
      return { ...p, windows };
    });
  }

  toScreen(x, z) {
    const c = this.game.camera;
    return [(x - c.x) * this.ppu + this.w / 2 + this.sx, (z - c.z) * this.ppu + this.h / 2 + this.sy];
  }

  toWorld(sx, sy) {
    const c = this.game.camera;
    return { x: (sx - this.w / 2) / this.ppu + c.x, z: (sy - this.h / 2) / this.ppu + c.z };
  }

  draw() {
    const g = this.game, ctx = this.ctx, k = this.ppu;
    const shake = g.camera.shake;
    this.sx = shake > 0.01 ? (Math.random() - 0.5) * shake * 10 : 0;
    this.sy = shake > 0.01 ? (Math.random() - 0.5) * shake * 10 : 0;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.fillStyle = "#0d0f16";
    ctx.fillRect(0, 0, this.w, this.h);

    const [bx0, bz0] = this.toScreen(g.bounds.x0, g.bounds.z0);
    ctx.fillStyle = COLORS.ground;
    ctx.fillRect(bx0, bz0, (g.bounds.x1 - g.bounds.x0) * k, (g.bounds.z1 - g.bounds.z0) * k);
    this.drawGrid();

    const order = ["water", "platform", "road", "prop", "landmark", "building", "wall"];
    const pieces = [...this.pieces].filter((p) => p.role !== "ground").sort((a, b) => order.indexOf(a.role) - order.indexOf(b.role));
    for (const p of pieces) this.drawPiece(p);
    this.drawMarkers();
    for (const e of g.enemies) if (e.tell) this.drawTell(e);
    this.drawSecrets();
    for (const e of g.enemies) this.drawEnemy(e);
    this.drawPlayer();
    this.drawEffects();
    this.drawLabels();
    this.drawVignette();
  }

  drawGrid() {
    const ctx = this.ctx, g = this.game, k = this.ppu, step = 20;
    ctx.strokeStyle = "#ffffff08";
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let x = g.bounds.x0; x <= g.bounds.x1; x += step) {
      const [sx, sy0] = this.toScreen(x, g.bounds.z0);
      ctx.moveTo(sx, sy0); ctx.lineTo(sx, sy0 + (g.bounds.z1 - g.bounds.z0) * k);
    }
    for (let z = g.bounds.z0; z <= g.bounds.z1; z += step) {
      const [sx0, sy] = this.toScreen(g.bounds.x0, z);
      ctx.moveTo(sx0, sy); ctx.lineTo(sx0 + (g.bounds.x1 - g.bounds.x0) * k, sy);
    }
    ctx.stroke();
  }

  drawPiece(p) {
    const ctx = this.ctx, k = this.ppu, t = this.game.t;
    const [x, y, z] = p.position, [sx, sy, sz] = p.size;
    const [cx, cz] = this.toScreen(x, z);
    const w = sx * k, h = sz * k;
    if (cx + w < -50 || cx - w > this.w + 50 || cz + h < -50 || cz - h > this.h + 50) return;
    ctx.save();
    ctx.translate(cx, cz);
    if (p.rotation_deg) ctx.rotate((p.rotation_deg[1] * Math.PI) / 180);
    if (p.shape === "cylinder") {
      ctx.fillStyle = p.role === "platform" ? "#3c3b44" : "#777";
      ctx.beginPath(); ctx.arc(0, 0, w / 2, 0, Math.PI * 2); ctx.fill();
      if (p.role === "platform") {
        ctx.strokeStyle = "#ffffff12"; ctx.lineWidth = 2;
        for (let r = w / 2 - 8; r > 10; r -= 14) { ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.stroke(); }
      }
      ctx.restore();
      return;
    }
    if (p.role === "water") {
      ctx.fillStyle = COLORS.water;
      ctx.fillRect(-w / 2, -h / 2, w, h);
      ctx.strokeStyle = "#5a8cc033"; ctx.lineWidth = 2;
      for (let i = 0; i < 14; i++) {
        const yy = -h / 2 + ((i * 37 + t * 12) % h);
        const xx = -w / 2 + ((i * 113) % w);
        ctx.beginPath(); ctx.moveTo(xx, yy); ctx.lineTo(xx + 30, yy); ctx.stroke();
      }
    } else if (p.role === "road") {
      ctx.fillStyle = COLORS.road; ctx.fillRect(-w / 2, -h / 2, w, h);
      ctx.strokeStyle = COLORS.lane; ctx.setLineDash([12, 12]); ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, -h / 2); ctx.lineTo(0, h / 2); ctx.stroke(); ctx.setLineDash([]);
    } else if (p.role === "platform") {
      ctx.fillStyle = COLORS.platform; ctx.fillRect(-w / 2, -h / 2, w, h);
      ctx.strokeStyle = "#00000033"; ctx.lineWidth = 1;
      for (let xx = -w / 2; xx < w / 2; xx += k * 3) { ctx.beginPath(); ctx.moveTo(xx, -h / 2); ctx.lineTo(xx, h / 2); ctx.stroke(); }
    } else if (p.role === "wall") {
      ctx.fillStyle = COLORS.wall; ctx.fillRect(-w / 2, -h / 2, w, h);
    } else {
      // buildings and landmarks: shadow, walls, roof, lit windows
      const lift = Math.min(sy, 60) * k * 0.08;
      ctx.fillStyle = "#00000055"; ctx.fillRect(-w / 2 + lift, -h / 2 + lift, w, h);
      ctx.fillStyle = p.role === "landmark" ? COLORS.landmark : COLORS.building;
      ctx.fillRect(-w / 2, -h / 2, w, h);
      ctx.fillStyle = p.role === "landmark" ? "#c4a57a" : COLORS.buildingTop;
      ctx.fillRect(-w / 2 + 3, -h / 2 + 3, w - 6, h - 6);
      ctx.fillStyle = COLORS.window;
      for (const [wx, wz, lit] of p.windows) {
        if (!lit) continue;
        ctx.globalAlpha = 0.55 + 0.25 * Math.sin(t * 0.7 + wx * 40);
        ctx.fillRect(wx * (w - 10) - 2, wz * (h - 10) - 2, 4, 4);
      }
      ctx.globalAlpha = 1;
      if (p.label && p.label.includes("Clocktower")) {
        ctx.fillStyle = "#f6e6c4"; ctx.beginPath(); ctx.arc(0, 0, w * 0.32, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = "#3a2a1a"; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -w * 0.26); ctx.moveTo(0, 0); ctx.lineTo(w * 0.07, -w * 0.12); ctx.stroke(); // 12:07
      }
    }
    ctx.restore();
  }

  drawMarkers() {
    const ctx = this.ctx, g = this.game, k = this.ppu, t = g.t;
    const hub = g.hub;
    const [hx, hz] = this.toScreen(hub.position[0], hub.position[2]);
    ctx.strokeStyle = "#ffbe5a55"; ctx.lineWidth = 3; ctx.setLineDash([10, 8]);
    ctx.beginPath(); ctx.arc(hx, hz, hub.radius_studs * k, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
    this.glow(hx, hz, 22 + 4 * Math.sin(t * 2), "#ffbe5a");
    for (const f of g.map.fast_travel) {
      const [fx, fz] = this.toScreen(f.position[0], f.position[2]);
      this.glow(fx, fz, 14, "#6ed2ff");
      ctx.fillStyle = "#9fe6ff"; ctx.beginPath();
      ctx.moveTo(fx, fz - 9); ctx.lineTo(fx + 6, fz); ctx.lineTo(fx, fz + 9); ctx.lineTo(fx - 6, fz); ctx.fill();
    }
    const a = g.arena;
    const [ax, az] = this.toScreen(a.center[0], a.center[2]);
    ctx.strokeStyle = "#c83c5066"; ctx.lineWidth = 4; ctx.setLineDash([16, 10]);
    ctx.beginPath(); ctx.arc(ax, az, a.radius_studs * k, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
  }

  drawSecrets() {
    const ctx = this.ctx, g = this.game;
    for (const s of g.map.secrets) {
      if (g.save.secrets.includes(s.id)) continue;
      const [x, z] = this.toScreen(s.position[0], s.position[2]);
      const pulse = 0.5 + 0.5 * Math.sin(g.t * 3 + x);
      ctx.fillStyle = `rgba(255,250,200,${0.4 + 0.5 * pulse})`;
      ctx.beginPath(); ctx.arc(x, z, 3 + pulse * 2, 0, Math.PI * 2); ctx.fill();
    }
  }

  glow(x, y, r, color) {
    const ctx = this.ctx;
    const grad = ctx.createRadialGradient(x, y, 0, x, y, r);
    grad.addColorStop(0, color + "cc"); grad.addColorStop(1, color + "00");
    ctx.fillStyle = grad; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  }

  drawTell(e) {
    const ctx = this.ctx, g = this.game, k = this.ppu, tell = e.tell, atk = tell.atk;
    const palette = TELL[g.setting("colorblind")] || TELL.none;
    const color = tell.unblockable ? palette.unblockable : palette.normal;
    const progress = Math.min(1, (g.t - tell.t0) / tell.dur);
    const [cx, cz] = this.toScreen(tell.cx, tell.cz);
    const angle = Math.atan2(tell.fz, tell.fx);
    const area = atk.area, r = (area.radius_studs ?? atk.range_studs) * k;
    ctx.save();
    ctx.translate(cx, cz);
    ctx.rotate(angle);
    const draw = (scale) => {
      ctx.beginPath();
      if (area.shape === "cone") {
        const half = ((area.angle_deg ?? 90) * Math.PI) / 360, rr = (r + e.r * k) * scale;
        ctx.moveTo(0, 0); ctx.arc(0, 0, rr, -half, half); ctx.closePath();
      } else if (area.shape === "line" || area.shape === "box") {
        const len = (area.length_studs ?? atk.range_studs) * k, wd = (area.width_studs ?? 4) * k;
        ctx.rect(0, -wd / 2, len * scale, wd);
      } else if (area.shape === "ring") {
        const wd = (area.width_studs ?? 4) * k;
        ctx.arc(0, 0, r + wd / 2, 0, Math.PI * 2); ctx.arc(0, 0, Math.max(1, r - wd / 2), 0, Math.PI * 2, true);
      } else {
        ctx.arc(0, 0, r * (area.shape === "circle" ? scale : 1), 0, Math.PI * 2);
      }
    };
    ctx.globalAlpha = tell.active ? 0.55 : 0.18;
    ctx.fillStyle = color; draw(1); ctx.fill();
    if (!tell.active) {
      ctx.globalAlpha = 0.35; draw(area.shape === "ring" ? 1 : progress); ctx.fill();
      ctx.globalAlpha = 0.9; ctx.strokeStyle = color; ctx.lineWidth = 2; draw(1); ctx.stroke();
    }
    ctx.restore();
    ctx.globalAlpha = 1;
    if (tell.unblockable && !tell.active) {
      const [ex, ez] = this.toScreen(e.x, e.z);
      ctx.fillStyle = color; ctx.font = `900 ${Math.round(14 + e.r * 6)}px sans-serif`; ctx.textAlign = "center";
      ctx.fillText("!", ex, ez - e.r * k - 10);
    }
  }

  drawEnemy(e) {
    const ctx = this.ctx, g = this.game, k = this.ppu;
    const [x, z] = this.toScreen(e.x, e.z);
    if (x < -80 || x > this.w + 80 || z < -80 || z > this.h + 80) return;
    const fade = e.alive ? 1 : Math.max(0, 1 - (g.t - e.deadAt) / 0.6);
    const r = e.r * k * (e.isBoss ? 1.35 : 1.15);
    ctx.globalAlpha = fade;
    if (e.isBoss) {
      this.glow(x, z, r * 2.6, "#ffcc78");
      ctx.fillStyle = "#1e1a26"; ctx.beginPath(); ctx.ellipse(x, z, r * 1.2, r, Math.atan2(e.face.z, e.face.x), 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = "#e0506899"; ctx.lineWidth = 3; ctx.stroke();
      ctx.fillStyle = "#ffd682";
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * Math.PI * 2 + g.t * 0.6;
        ctx.beginPath(); ctx.arc(x + Math.cos(a) * r * 0.5, z + Math.sin(a) * r * 0.5, r * 0.18, 0, Math.PI * 2); ctx.fill();
      }
    } else {
      ctx.fillStyle = "#2b2b33"; ctx.beginPath(); ctx.arc(x, z, r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = "#00000088"; ctx.lineWidth = 2; ctx.stroke();
    }
    // ember eye toward facing
    const ex = x + e.face.x * r * 0.7, ez = z + e.face.z * r * 0.7;
    this.glow(ex, ez, r * 0.7, "#ff8c32");
    ctx.fillStyle = "#ffb060"; ctx.beginPath(); ctx.arc(ex, ez, r * 0.2, 0, Math.PI * 2); ctx.fill();
    if (e.tell && !e.tell.active && e.tell.atk.tell.visual === "body_glow") this.glow(x, z, r * 2, "#ff8a3d");
    if (g.t < e.flashUntil) {
      ctx.globalAlpha = 0.7 * (g.setting("flash_intensity") ?? 1) * fade;
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(x, z, r, 0, Math.PI * 2); ctx.fill();
      ctx.globalAlpha = fade;
    }
    if (e.burning) { ctx.strokeStyle = "#ff9650"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, z, r + 3, 0, Math.PI * 2); ctx.stroke(); }
    if (g.t < e.stunnedUntil) {
      ctx.fillStyle = "#ffd478"; ctx.font = "bold 13px sans-serif"; ctx.textAlign = "center";
      ctx.fillText("✦ ✦", x, z - r - 4);
    }
    // health bar and name (regular enemies; the boss uses the big bar)
    if (!e.isBoss && e.alive) {
      const bw = Math.max(36, r * 2.4), by = z - r - 14;
      ctx.fillStyle = "#00000099"; ctx.fillRect(x - bw / 2, by, bw, 5);
      ctx.fillStyle = "#e5484d"; ctx.fillRect(x - bw / 2, by, (bw * e.hp) / e.maxHp, 5);
      ctx.fillStyle = "#ddd"; ctx.font = "11px sans-serif"; ctx.textAlign = "center";
      ctx.fillText(`${e.def.name} Lv ${e.level}`, x, by - 4);
    }
    if (g.lockTarget === e) {
      ctx.strokeStyle = "#ffdc96"; ctx.lineWidth = 2;
      const s = r + 8 + Math.sin(g.t * 6) * 2;
      ctx.beginPath(); ctx.moveTo(x, z - s); ctx.lineTo(x + s, z); ctx.lineTo(x, z + s); ctx.lineTo(x - s, z); ctx.closePath(); ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  drawPlayer() {
    const ctx = this.ctx, g = this.game, p = g.player, k = this.ppu;
    if (!p || p.dead) return;
    const [x, z] = this.toScreen(p.x, p.z);
    const r = p.r * k * 1.2;
    const t = g.t;
    this.glow(x, z, r * 4.5, "#f2a33a"); // lantern light / aura
    if (t < p.iframesUntil) { ctx.globalAlpha = 0.5; }
    // body
    ctx.fillStyle = "#2e3a59"; ctx.beginPath(); ctx.arc(x, z, r, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "#d19a72"; ctx.lineWidth = 3; ctx.stroke();
    ctx.fillStyle = "#d19a72"; ctx.beginPath(); ctx.arc(x + p.face.x * r * 0.45, z + p.face.z * r * 0.45, r * 0.35, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
    const face = Math.atan2(p.face.z, p.face.x);
    // sword: rests to the side, sweeps through the arc during an attack
    let swordAngle = face + 0.9;
    let reach = 2.6 * k;
    const s = p.swing;
    if (s) {
      const half = (s.arc * Math.PI) / 360;
      const u = (t - s.start - s.windup) / Math.max(s.active, 0.06);
      const from = s.flip ? half : -half, to = s.flip ? -half : half;
      if (u < 0) swordAngle = face + from * 1.15;
      else swordAngle = face + from + (to - from) * Math.min(1, u);
      reach = Math.min(s.range * 0.7, 4.5) * k;
      if (u >= 0 && u <= 1.4) {
        ctx.strokeStyle = s.heavy ? "#ffb347" : "#ffd28a";
        ctx.globalAlpha = 0.55 * (1 - Math.max(0, u - 1) / 0.4);
        ctx.lineWidth = s.heavy ? 10 : 6;
        ctx.beginPath();
        const a0 = face + from, a1 = face + from + (to - from) * Math.min(1, u);
        ctx.arc(x, z, s.range * k * 0.85, Math.min(a0, a1), Math.max(a0, a1));
        ctx.stroke();
        ctx.globalAlpha = 1;
      }
    }
    ctx.strokeStyle = "#ffc478"; ctx.lineWidth = 3; ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(x + Math.cos(swordAngle) * r * 0.6, z + Math.sin(swordAngle) * r * 0.6);
    ctx.lineTo(x + Math.cos(swordAngle) * (r + reach), z + Math.sin(swordAngle) * (r + reach));
    ctx.stroke();
    if (p.guarding) {
      ctx.strokeStyle = t - p.guardAt < 0.2 ? "#fff3c4" : "#9fc4ff"; ctx.lineWidth = 4;
      ctx.beginPath(); ctx.arc(x, z, r + 6, face - 1, face + 1); ctx.stroke();
    }
    if (t < p.stunnedUntil) {
      ctx.fillStyle = "#ffd478"; ctx.font = "bold 13px sans-serif"; ctx.textAlign = "center"; ctx.fillText("✦ ✦", x, z - r - 6);
    }
  }

  drawEffects() {
    const ctx = this.ctx, g = this.game, k = this.ppu;
    for (const f of g.fx) {
      const u = (g.t - f.t0) / f.dur;
      if (f.type === "number") {
        const [x, z] = this.toScreen(f.x, f.z);
        ctx.globalAlpha = 1 - Math.max(0, u - 0.5) * 2;
        ctx.font = `bold ${f.big ? 22 : 17}px sans-serif`; ctx.textAlign = "center";
        ctx.lineWidth = 3; ctx.strokeStyle = "#000"; ctx.strokeText(f.text, x, z - 18 - u * 30);
        ctx.fillStyle = f.color; ctx.fillText(f.text, x, z - 18 - u * 30);
      } else if (f.type === "wave") {
        const along = f.len * Math.min(1, u * 1.1);
        const [x, z] = this.toScreen(f.x + f.fx * along, f.z + f.fz * along);
        ctx.save(); ctx.translate(x, z); ctx.rotate(Math.atan2(f.fz, f.fx));
        ctx.globalAlpha = 0.85 * (1 - u * 0.6);
        const grad = ctx.createLinearGradient(-10, 0, 10, 0);
        grad.addColorStop(0, "#ff7a1a00"); grad.addColorStop(0.6, "#ffaa46"); grad.addColorStop(1, "#fff0c0");
        ctx.fillStyle = grad; ctx.beginPath();
        ctx.ellipse(0, 0, 1.6 * k, (f.w / 2) * k, 0, -Math.PI / 2, Math.PI / 2); ctx.fill();
        ctx.restore();
      } else if (f.type === "cast") {
        const p = g.player;
        const [x, z] = this.toScreen(p.x, p.z);
        this.glow(x, z, 40 * u + 10, "#ffaa46");
      } else if (f.type === "dash") {
        const [x, z] = this.toScreen(f.x, f.z);
        ctx.globalAlpha = 0.4 * (1 - u); ctx.fillStyle = "#9fc4ff";
        ctx.beginPath(); ctx.arc(x, z, g.player.r * k * 1.2, 0, Math.PI * 2); ctx.fill();
      } else if (f.type === "burst") {
        const [x, z] = this.toScreen(f.x, f.z);
        ctx.globalAlpha = 1 - u; ctx.strokeStyle = f.boss ? "#ffd682" : "#8a8a9a"; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(x, z, f.r * k * (1 + u * 2), 0, Math.PI * 2); ctx.stroke();
      } else if (f.type === "levelup") {
        const p = g.player;
        const [x, z] = this.toScreen(p.x, p.z);
        ctx.globalAlpha = 1 - u; ctx.strokeStyle = "#f2c14e"; ctx.lineWidth = 4;
        ctx.beginPath(); ctx.arc(x, z, 10 + u * 70, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
  }

  drawLabels() {
    const ctx = this.ctx, g = this.game;
    ctx.font = "bold 13px sans-serif"; ctx.textAlign = "center";
    const label = (text, x, z, color) => {
      const [sx, sz] = this.toScreen(x, z);
      if (sx < -100 || sx > this.w + 100 || sz < -40 || sz > this.h + 40) return;
      ctx.lineWidth = 3; ctx.strokeStyle = "#000000aa"; ctx.strokeText(text, sx, sz);
      ctx.fillStyle = color; ctx.fillText(text, sx, sz);
    };
    for (const l of g.map.landmarks) label(l.name, l.position[0], l.position[2] - l.size[2] / 2 - 4, "#f6e6c4");
    label(g.hub.name, g.hub.position[0], g.hub.position[2] - g.hub.radius_studs - 2, "#ffd6a0");
    for (const f of g.map.fast_travel) label(f.name, f.position[0], f.position[2] - 4, "#aee8ff");
  }

  drawVignette() {
    const ctx = this.ctx, g = this.game, p = g.player;
    const low = p && !p.dead ? 1 - p.hp / p.maxHp : 0;
    const grad = ctx.createRadialGradient(this.w / 2, this.h / 2, Math.min(this.w, this.h) * 0.35, this.w / 2, this.h / 2, Math.max(this.w, this.h) * 0.75);
    grad.addColorStop(0, "#00000000");
    const flash = g.setting("flash_intensity") ?? 1;
    grad.addColorStop(1, low > 0.65 ? `rgba(120,0,0,${0.35 * flash})` : "#00000066");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, this.w, this.h);
  }

  drawMinimap(canvas) {
    const g = this.game, ctx = canvas.getContext("2d");
    const W = canvas.width, H = canvas.height;
    const sx = W / (g.bounds.x1 - g.bounds.x0), sz = H / (g.bounds.z1 - g.bounds.z0);
    const m = (x, z) => [(x - g.bounds.x0) * sx, (z - g.bounds.z0) * sz];
    ctx.clearRect(0, 0, W, H);
    const colors = { building: "#7a7f92", landmark: "#d2b482", water: "#28507a", platform: "#6e645a", road: "#3a3c48" };
    for (const p of g.map.blockout) {
      const c = colors[p.role];
      if (!c) continue;
      const [x, z] = m(p.position[0], p.position[2]);
      ctx.save(); ctx.translate(x, z);
      if (p.rotation_deg) ctx.rotate((p.rotation_deg[1] * Math.PI) / 180);
      ctx.fillStyle = c;
      if (p.shape === "cylinder") { ctx.beginPath(); ctx.arc(0, 0, (p.size[0] / 2) * sx, 0, Math.PI * 2); ctx.fill(); }
      else ctx.fillRect((-p.size[0] / 2) * sx, (-p.size[2] / 2) * sz, p.size[0] * sx, p.size[2] * sz);
      ctx.restore();
    }
    const dot = (x, z, r, c) => { const [a, b] = m(x, z); ctx.fillStyle = c; ctx.beginPath(); ctx.arc(a, b, r, 0, Math.PI * 2); ctx.fill(); };
    dot(g.hub.position[0], g.hub.position[2], 5, "#ffbe5a");
    for (const f of g.map.fast_travel) dot(f.position[0], f.position[2], 4, "#6ed2ff");
    const [ax, az] = m(g.arena.center[0], g.arena.center[2]);
    ctx.strokeStyle = "#e05068"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(ax, az, g.arena.radius_studs * sx, 0, Math.PI * 2); ctx.stroke();
    for (const e of g.enemies) if (e.alive && e.isBoss) dot(e.x, e.z, 4, "#e05068");
    const p = g.player;
    if (p) {
      const [px, pz] = m(p.x, p.z);
      ctx.save(); ctx.translate(px, pz); ctx.rotate(Math.atan2(p.face.z, p.face.x) + Math.PI / 2);
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.moveTo(0, -7); ctx.lineTo(5, 5); ctx.lineTo(-5, 5); ctx.closePath(); ctx.fill();
      ctx.restore();
    }
  }
}
