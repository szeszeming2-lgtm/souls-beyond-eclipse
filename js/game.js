// The game simulation: player, enemies, boss, combat, progression, saving.
// Single-player in the browser. Uses the shared rules in rules.js and the data in gamedata.js.

import * as R from "./rules.js";
import * as Save from "./save.js";

const PLAYER_RADIUS = 1.6;
const TICK_AI = 0.1;
const HUB_HEAL_PER_S = 0.15;
const RESPAWN_S = 3;
const BOSS_RESPAWN_S = 45;
const AUTOSAVE_S = 30;
const SECRET_REACH = 6;
const SETTINGS_PLATFORM = "pc";

const byId = (list) => Object.fromEntries(list.map((e) => [e.id, e]));
const dist = (ax, az, bx, bz) => Math.hypot(bx - ax, bz - az);
const unit = (x, z) => { const l = Math.hypot(x, z); return l < 1e-6 ? { x: 0, z: -1 } : { x: x / l, z: z / l }; };

export class Game {
  constructor(data) {
    this.data = data;
    this.abilities = byId(data.abilities);
    this.enemyDefs = byId(data.enemies);
    this.statuses = byId(data.statusEffects);
    this.weapons = byId(data.weapons);
    this.materials = byId(data.materials);
    this.movesets = byId(data.movesets);
    this.modes = byId(data.difficulty.modes);
    this.map = data.map;
    this.region = data.regions.find((r) => r.id === data.map.region_id);
    this.C = data.combat;
    this.P = data.progression;
    this.growth = this.P.stat_scaling.growth_per_level;
    this.cap = R.effectiveCap(this.P.content_level_cap, data.xpToNext);
    this.weapon = this.weapons["wpn_hearthwick"];
    this.moveset = this.movesets[this.weapon.moveset_id];
    this.special = this.abilities[this.weapon.special_ability_id];
    this.passive = this.abilities[this.weapon.passive_ability_id];
    this.dodgeAbility = this.abilities["abl_flash_step"];
    this.guardAbility = this.abilities["abl_lantern_guard"];
    this.listeners = {};
    this.buildWorld();
    this.running = false;
  }

  on(kind, fn) { (this.listeners[kind] ||= []).push(fn); }
  emit(kind, ...args) { for (const fn of this.listeners[kind] || []) fn(...args); }

  // ---------------------------------------------------------------- world
  buildWorld() {
    const m = this.map;
    this.bounds = { x0: m.bounds.min[0], z0: m.bounds.min[2], x1: m.bounds.max[0], z1: m.bounds.max[2] };
    this.solids = [];
    this.water = [];
    this.platforms = [];
    this.surfaces = []; // walkable tops (ground, roads, platforms) for 3D heights
    for (const p of m.blockout) {
      const [x, y, z] = p.position, [sx, sy, sz] = p.size;
      const rect = { x0: x - sx / 2, z0: z - sz / 2, x1: x + sx / 2, z1: z + sz / 2, label: p.label };
      const rotated = p.rotation_deg && Math.abs(p.rotation_deg[1]) > 0.1;
      const grounded = y - sy / 2 <= 1 && sy >= 3;
      if (!rotated && grounded && ["building", "wall", "landmark"].includes(p.role) && p.shape !== "cylinder") this.solids.push(rect);
      if (p.role === "water") this.water.push(rect);
      if (p.role === "platform") this.platforms.push(p.shape === "cylinder" ? { cx: x, cz: z, r: sx / 2 } : rect);
      if (["ground", "road", "platform"].includes(p.role) && !rotated) {
        this.surfaces.push(p.shape === "cylinder" ? { cx: x, cz: z, r: sx / 2, top: y + sy / 2 } : { ...rect, top: y + sy / 2 });
      }
    }
    this.spawn = { x: m.player_spawn.position[0], z: m.player_spawn.position[2] };
    this.hub = m.hubs[0];
    this.arena = m.boss_arenas[0];
  }

  // Height of the walkable surface under a point (used to stand characters on walkways in 3D).
  groundHeight(x, z) {
    let top = 0;
    for (const s of this.surfaces) {
      const inside = s.r !== undefined ? dist(x, z, s.cx, s.cz) <= s.r : this.inRect(s, x, z);
      if (inside && s.top > top) top = s.top;
    }
    return top;
  }

  // Camera-relative movement: input x = right, y = forward on screen.
  worldMove(mv) {
    const yaw = this.viewYaw || 0, c = Math.cos(yaw), s = Math.sin(yaw);
    return { x: c * mv.x - s * mv.y, z: -s * mv.x - c * mv.y };
  }

  cameraForward() {
    const yaw = this.viewYaw || 0;
    return { x: -Math.sin(yaw), z: -Math.cos(yaw) };
  }

  inRect(r, x, z, pad = 0) { return x > r.x0 - pad && x < r.x1 + pad && z > r.z0 - pad && z < r.z1 + pad; }

  onPlatform(x, z) {
    return this.platforms.some((p) => (p.r ? dist(x, z, p.cx, p.cz) <= p.r : this.inRect(p, x, z)));
  }

  blocked(x, z, r) {
    if (x - r < this.bounds.x0 || x + r > this.bounds.x1 || z - r < this.bounds.z0 || z + r > this.bounds.z1) return true;
    if (this.solids.some((s) => this.inRect(s, x, z, r))) return true;
    return this.water.some((w) => this.inRect(w, x, z)) && !this.onPlatform(x, z);
  }

  move(e, dx, dz) {
    if (!this.blocked(e.x + dx, e.z, e.r)) e.x += dx;
    if (!this.blocked(e.x, e.z + dz, e.r)) e.z += dz;
  }

  // ---------------------------------------------------------------- start / save
  start(newGame) {
    const loaded = newGame ? { data: Save.defaultSave(), repaired: [] } : Save.load(this.data.xpToNext, this.cap);
    if (!loaded.data) {
      this.emit("toast", "This save is from a newer version of the game, so it was left untouched.", "bad");
      loaded.data = Save.defaultSave();
      this.saveBlocked = true;
    }
    if (loaded.repaired.length) this.emit("toast", `Some save data was damaged and has been repaired (${loaded.repaired.join(", ")}).`, "dim");
    if (loaded.source === "backup") this.emit("toast", "Your main save was unreadable, so the backup was loaded.", "dim");
    this.save = loaded.data;
    this.save.settings = R.sanitizeSettings(this.save.settings, this.data.settings.settings, SETTINGS_PLATFORM);
    this.t = 0;
    this.timers = [];
    this.fx = [];
    this.enemies = [];
    this.grind = {};
    this.lockTarget = null;
    this.checkpoint = null;
    this.camera = { x: this.spawn.x, z: this.spawn.z, shake: 0 };
    this.aiClock = 0;
    this.saveClock = 0;
    this.makePlayer();
    this.zones = this.map.spawn_zones.map((z) => ({ def: z, slots: Array.from({ length: z.max_alive }, (_, i) => ({ enemy: null, nextSpawn: i * 0.3 })) }));
    this.boss = { live: null, phase: 0, furthest: 0, respawnAt: 0.5, def: this.enemyDefs[this.arena.boss_id], offers: [] };
    this.running = true;
    if (newGame) this.persist();
    this.emit("started");
  }

  persist() {
    if (this.saveBlocked) return false;
    return Save.store(this.save, this.data.xpToNext, this.cap);
  }

  setting(id) { return this.save.settings[id]; }

  setSetting(id, value) {
    const def = this.data.settings.settings.find((d) => d.id === id);
    if (!def) return;
    const [ok, v] = R.coerceSetting(def, value);
    if (ok) { this.save.settings[id] = v; this.emit("setting", id, v); this.persist(); }
  }

  mode() { return this.modes[this.setting("difficulty")] || this.modes[this.data.difficulty.default_mode]; }

  later(delay, fn) { this.timers.push({ at: this.t + delay, fn }); }

  // ---------------------------------------------------------------- player
  stats() {
    const lvl = this.save.level, b = this.P.stat_scaling.player_base;
    return {
      level: lvl,
      maxHp: R.round(R.statAt(b.max_hp, lvl, this.growth)),
      attack: R.statAt(b.attack, lvl, this.growth),
      defense: R.statAt(b.defense, lvl, this.growth),
    };
  }

  makePlayer() {
    const s = this.stats();
    const pos = this.checkpoint || this.spawn;
    this.player = {
      x: pos.x, z: pos.z, r: PLAYER_RADIUS, face: { x: 0, z: -1 },
      hp: s.maxHp, maxHp: s.maxHp, spirit: 0,
      busyUntil: 0, token: 0, queued: null, combo: { light: 0, heavy: 0 }, comboUntil: { light: 0, heavy: 0 },
      cooldowns: {}, guarding: false, guardAt: -Infinity, guardMeter: this.C.guard.guard_meter_max,
      iframesUntil: 0, dodgeAt: -Infinity, dodgeTimes: [], dash: null, knock: null,
      poise: R.newPoise(this.C.poise.player_poise), cc: R.newCc(), stunnedUntil: 0,
      effects: {}, passiveReadyAt: 0, lastHurtAt: -Infinity, dead: false, swing: null, sprinting: false,
    };
  }

  modifiers() { return Object.values(this.player.effects).flatMap((e) => e.mods); }
  gainSpirit(n) { const p = this.player; p.spirit = R.clamp(p.spirit + n, 0, this.P.stat_scaling.spirit_max); }

  setEffect(id, seconds, mods, tickDamage = 0) {
    this.player.effects[id] = { until: this.t + seconds, nextTick: this.t + 1, mods, tickDamage, total: seconds };
  }

  cancelActions() { this.player.token++; this.player.queued = null; }

  staggerPlayer(base) {
    const p = this.player;
    const d = R.ccDuration(p.cc, base, this.t, this.C.crowd_control);
    if (d <= 0) return;
    p.stunnedUntil = Math.max(p.stunnedUntil, this.t + d);
    p.guarding = false;
    this.cancelActions();
    this.setEffect("sts_staggered", d, []);
  }

  // Attack direction: lock-on target, else where the player is aiming.
  aimAssist() {
    const p = this.player;
    if (this.lockTarget?.alive) { p.face = unit(this.lockTarget.x - p.x, this.lockTarget.z - p.z); return; }
    // Aim where the player is looking (camera, or movement when moving), nudged to the nearest enemy in front.
    const moving = this.moveDir && Math.hypot(this.moveDir.x, this.moveDir.z) > 0.2;
    const look = moving ? unit(this.moveDir.x, this.moveDir.z) : this.aimMode === "camera" ? this.cameraForward() : p.face;
    let best = null, bestScore = Infinity;
    for (const e of this.enemies) {
      if (!e.alive) continue;
      const d = dist(p.x, p.z, e.x, e.z);
      if (d > 12) continue;
      const dir = unit(e.x - p.x, e.z - p.z);
      const dot = dir.x * look.x + dir.z * look.z;
      if (dot < 0.35 && d > 4) continue; // only enemies roughly in front (or very close)
      const score = d - dot * 8;
      if (score < bestScore) { best = dir; bestScore = score; }
    }
    p.face = best || look;
  }

  enemiesInArea(area, range, ox, oz, fx, fz) {
    return this.enemies.filter((e) => e.alive && R.hitsArea(area, range, ox, oz, fx, fz, e.x, e.z, e.r));
  }

  dealToEnemy(e, power, damageType, poiseDamage, knockback, statuses) {
    const p = this.player, s = this.stats();
    const tierBonus = this.save.weapon_tier > 0 ? this.weapon.upgrade_tiers[this.save.weapon_tier - 1].damage_bonus_pct : 0;
    const isCrit = Math.random() < this.C.damage.crit_chance_base;
    const amount = R.damage({
      attack: s.attack, power, defense: e.defense, attackerLevel: s.level, targetLevel: e.level, growth: this.growth,
      weaponDamage: this.weapon.base_stats.damage, weaponBonusPct: tierBonus,
      resistance: e.def.resistances?.[damageType], isCrit,
      bonusMult: R.percentMult(this.modifiers(), "attack") / this.mode().enemy_hp_mult,
    }, this.C.damage);
    if (this.hitEnemy(e, { amount, poiseDamage, knockback, dir: unit(e.x - p.x, e.z - p.z), statuses, sourceAttack: s.attack, isCrit })) {
      this.gainSpirit(this.C.spirit.gain_on_hit);
      this.shake(isCrit ? 0.35 : 0.15);
    }
  }

  melee(chain) {
    const p = this.player, t = this.t;
    if (p.dead || t < p.busyUntil || t < p.stunnedUntil || p.guarding) return;
    const steps = chain === "heavy" ? this.moveset.heavy_chain : this.moveset.light_chain;
    const other = chain === "heavy" ? "light" : "heavy";
    const index = t <= p.comboUntil[chain] ? p.combo[chain] % steps.length : 0;
    const step = steps[index];
    const speed = this.weapon.base_stats.attack_speed;
    const windup = step.timing.windup_s / speed;
    const total = (step.timing.windup_s + step.timing.active_s + step.timing.recovery_s) / speed;
    p.combo[chain] = index + 1;
    p.combo[other] = 0;
    p.comboUntil[chain] = t + total + this.moveset.combo_reset_s;
    p.busyUntil = t + total;
    this.cancelActions();
    this.aimAssist();
    const token = p.token;
    p.swing = { start: t, windup, active: step.timing.active_s / speed, arc: step.arc_deg, range: step.range_studs, heavy: chain === "heavy", flip: index % 2 === 1 };
    this.later(windup, () => {
      if (p.token !== token || this.t < p.stunnedUntil || p.dead) return;
      const area = { shape: "cone", radius_studs: step.range_studs, angle_deg: step.arc_deg };
      for (const e of this.enemiesInArea(area, step.range_studs, p.x, p.z, p.face.x, p.face.z)) {
        this.dealToEnemy(e, step.power * (step.hit_count || 1), step.damage_type, step.poise_damage, step.knockback_studs, null);
      }
    });
  }

  tryMelee(chain) {
    const wait = this.player.busyUntil - this.t;
    if (wait > 0) {
      if (wait <= this.C.recovery.input_buffer_s) this.player.queued = chain; // queued, never dropped
      return;
    }
    this.melee(chain);
  }

  castSpecial() {
    const p = this.player, t = this.t, a = this.special;
    if (p.dead || t < p.busyUntil || t < p.stunnedUntil || p.guarding) return;
    if ((p.cooldowns[a.id] || 0) > t) return;
    const cost = a.cost.resource === "spirit" ? a.cost.amount : 0;
    if (p.spirit < cost) { this.emit("toast", `Not enough spirit (${cost} needed). Land hits or parry to fill it.`, "spirit"); return; }
    this.gainSpirit(-cost);
    p.cooldowns[a.id] = t + a.cooldown_s;
    p.busyUntil = t + a.timing.windup_s + a.timing.active_s + a.timing.recovery_s;
    this.cancelActions();
    this.aimAssist();
    const token = p.token;
    this.fx.push({ type: "cast", t0: t, dur: a.timing.windup_s });
    this.later(a.timing.windup_s, () => {
      if (p.token !== token || p.dead) { this.gainSpirit(cost); p.cooldowns[a.id] = 0; return; } // interrupted: refund
      this.fx.push({ type: "wave", t0: this.t, dur: Math.max(a.timing.active_s, 0.25), x: p.x, z: p.z, fx: p.face.x, fz: p.face.z, len: a.area.length_studs, w: a.area.width_studs });
      for (const e of this.enemiesInArea(a.area, a.range_studs, p.x, p.z, p.face.x, p.face.z)) {
        this.dealToEnemy(e, a.power, a.damage_type, 0, 0, a.status_effects);
      }
    });
  }

  dodge() {
    const p = this.player, t = this.t, d = this.dodgeAbility;
    if (p.dead || t < p.stunnedUntil || (p.cooldowns[d.id] || 0) > t) return;
    const window = this.C.dodge.chain_cooldown_s + d.cooldown_s * this.C.dodge.chain_limit;
    p.dodgeTimes = p.dodgeTimes.filter((x) => t - x < window);
    if (p.dodgeTimes.length >= this.C.dodge.chain_limit) return;
    p.dodgeTimes.push(t);
    p.guarding = false;
    this.cancelActions();
    p.iframesUntil = t + d.iframes_s * this.mode().dodge_window_mult;
    p.dodgeAt = t;
    p.cooldowns[d.id] = t + d.cooldown_s;
    let dir = this.moveDir;
    if (!dir || Math.hypot(dir.x, dir.z) < 0.1) dir = { x: -p.face.x, z: -p.face.z };
    dir = unit(dir.x, dir.z);
    const speed = d.movement.distance_studs / d.movement.duration_s;
    p.dash = { vx: dir.x * speed, vz: dir.z * speed, until: t + d.movement.duration_s };
    p.busyUntil = t + d.movement.duration_s;
    this.fx.push({ type: "dash", t0: t, dur: 0.25, x: p.x, z: p.z });
  }

  setGuard(on) {
    const p = this.player;
    if (on) {
      if (p.dead || this.t < p.stunnedUntil) return;
      this.cancelActions();
      p.guarding = true;
      p.guardAt = this.t;
    } else p.guarding = false;
  }

  toggleLock() {
    if (this.lockTarget) { this.lockTarget = null; return; }
    const p = this.player;
    let best = null, bestScore = Infinity;
    for (const e of this.enemies) {
      if (!e.alive) continue;
      const d = dist(p.x, p.z, e.x, e.z);
      if (d > this.C.lock_on.range_studs) continue;
      const dir = unit(e.x - p.x, e.z - p.z);
      const look = this.cameraForward();
      const score = d - (dir.x * look.x + dir.z * look.z) * 15;
      if (score < bestScore) { best = e; bestScore = score; }
    }
    this.lockTarget = best;
  }

  // An enemy attack lands on the player. Returns "dodged" | "parried" | "guarded" | "hit" | "none".
  hurtPlayer(hit) {
    const p = this.player, t = this.t, mode = this.mode();
    if (p.dead) return "none";
    if (t < p.iframesUntil) {
      if (t - p.dodgeAt <= this.C.dodge.perfect_window_s * mode.dodge_window_mult) {
        this.gainSpirit(this.C.spirit.gain_on_perfect_dodge);
        this.text(p.x, p.z, "Perfect dodge", "#8cdcff");
      }
      return "dodged";
    }
    const s = this.stats();
    const toSource = unit(hit.x - p.x, hit.z - p.z);
    const inFront = p.face.x * toSource.x + p.face.z * toSource.z > -0.2;
    const base = {
      attack: hit.attack, power: hit.power, defense: s.defense, attackerLevel: hit.level, targetLevel: s.level,
      growth: this.growth, difficultyMult: mode.enemy_damage_mult, bonusMult: R.percentMult(this.modifiers(), "damage_taken"),
    };
    const guard = this.guardAbility.guard;
    if (p.guarding && !hit.unblockable && inFront) {
      if (t - p.guardAt <= guard.parry_window_s * mode.parry_window_mult) {
        this.gainSpirit(this.C.spirit.gain_on_parry);
        const pa = this.passive.passive;
        if (pa && pa.trigger === "on_parry" && t >= p.passiveReadyAt) {
          p.passiveReadyAt = t + (pa.internal_cooldown_s || 0);
          this.gainSpirit(pa.spirit_gain || 0);
          this.setEffect(this.passive.id, pa.duration_s || 5, pa.effects);
        }
        hit.onParried?.();
        this.text(p.x, p.z, "PARRY", "#ffdc78");
        this.shake(0.3);
        this.emit("vibrate", 0.6, 120);
        return "parried";
      }
      const amount = R.damage({ ...base, guardReduction: guard.damage_reduction }, this.C.damage);
      this.applyHurt(amount);
      p.guardMeter -= hit.poiseDamage;
      if (p.guardMeter <= 0) {
        p.guardMeter = this.C.guard.guard_meter_max;
        this.staggerPlayer(this.C.guard.guard_break_stagger_s);
        this.text(p.x, p.z, "Guard broken", "#ff9a7a");
      }
      return "guarded";
    }
    this.applyHurt(R.damage(base, this.C.damage));
    this.gainSpirit(this.C.spirit.gain_on_hit_taken);
    if (R.poiseHit(p.poise, hit.poiseDamage, t, this.C.poise)) this.staggerPlayer(this.C.poise.stagger_s);
    if (hit.knockback > 0) {
      const push = unit(p.x - hit.x, p.z - hit.z);
      const k = Math.min(hit.knockback, this.C.readability.max_knockback_studs) / 0.18;
      p.knock = { vx: push.x * k, vz: push.z * k, until: t + 0.18 };
    }
    for (const app of hit.statuses || []) {
      const st = this.statuses[app.status_id];
      if (!st || Math.random() >= app.chance) continue;
      this.setEffect(st.id, app.duration_s ?? st.duration_s, st.stat_modifiers, st.tick_power ? hit.attack * st.tick_power : 0);
    }
    return "hit";
  }

  applyHurt(amount) {
    const p = this.player;
    p.hp = Math.max(0, p.hp - amount);
    p.lastHurtAt = this.t;
    this.number(p.x, p.z, amount, "#ff6b6b");
    this.shake(0.4);
    this.emit("hurt", amount);
    this.emit("vibrate", 0.4, 90);
    if (p.hp <= 0) this.playerDied();
  }

  playerDied() {
    const p = this.player;
    p.dead = true;
    p.respawnAt = this.t + RESPAWN_S;
    this.save.deaths += 1;
    this.lockTarget = null;
    const b = this.boss.live;
    if (b?.alive && b.hp < b.maxHp && dist(p.x, p.z, this.arena.center[0], this.arena.center[2]) <= this.arena.radius_studs + 10) {
      this.bossFailed();
    }
    this.emit("died");
    this.persist();
  }

  respawn() {
    this.makePlayer();
    this.camera.x = this.player.x;
    this.camera.z = this.player.z;
    this.emit("respawned");
  }

  // ---------------------------------------------------------------- progression
  publishLevel(oldLevel) {
    const sv = this.save;
    const names = [];
    for (const level of R.pendingRewardLevels(sv.rewards_granted_through, sv.level)) {
      sv.skill_points += R.skillPointsAt(level, this.P.skill_points.schedule);
      const m = R.milestoneAt(level, this.P.milestones);
      if (m) {
        sv.skill_points += m.reward.skill_points || 0;
        for (const c of m.reward.currency || []) sv.marks += R.scaledReward(c.amount, level, this.growth);
        names.push(m.name);
      }
      sv.rewards_granted_through = level;
    }
    if (sv.level > oldLevel) {
      const s = this.stats();
      this.player.maxHp = s.maxHp;
      this.player.hp = s.maxHp;
      this.emit("levelup", sv.level, names, sv.level >= this.cap);
      this.fx.push({ type: "levelup", t0: this.t, dur: 1.2 });
      this.persist();
    }
  }

  addXp(amount) {
    const sv = this.save, old = sv.level;
    const r = R.addXp({ level: sv.level, xp: sv.xp, total_xp: sv.total_xp }, amount, this.data.xpToNext, this.cap);
    Object.assign(sv, r.progress);
    this.publishLevel(old);
    return r.added;
  }

  awardXp(base, contentLevel, enemyId) {
    const sv = this.save, P = this.P;
    let amount;
    const areaMax = this.region?.level_range.max ?? contentLevel;
    if (P.level_sync.enabled && sv.level > areaMax + P.level_sync.margin_levels) {
      amount = R.scaledReward(base, sv.level, this.growth) * P.level_sync.synced_reward_multiplier;
    } else amount = R.scaledReward(base, contentLevel, this.growth);
    const below = contentLevel - sv.level;
    if (below >= P.catch_up.below_recommended_by) amount *= 1 + Math.min(P.catch_up.max_bonus, below * P.catch_up.bonus_per_level_below);
    if (enemyId) amount *= R.grindMultiplier(this.grind, enemyId, this.t, P.anti_grind);
    return this.addXp(Math.floor(amount));
  }

  grantDrops(drops) {
    const gained = [];
    for (const d of drops) {
      if (Math.random() >= d.chance) continue;
      const qty = d.qty_min + Math.floor(Math.random() * (d.qty_max - d.qty_min + 1));
      const mat = this.materials[d.item_id];
      if (!mat) continue;
      const have = this.save.materials[mat.id] || 0;
      const added = Math.max(0, Math.min(qty, mat.max_stack - have));
      if (added > 0) { this.save.materials[mat.id] = have + added; gained.push(`+${added} ${mat.name}`); }
    }
    if (gained.length) this.emit("toast", gained.join(", "), "good");
  }

  // ---------------------------------------------------------------- weapon upgrades (at the hub)
  nextUpgrade() {
    const tier = this.save.weapon_tier;
    if (tier >= this.weapon.upgrade_tiers.length) return null;
    const next = this.weapon.upgrade_tiers[tier];
    const missing = [];
    const minLevel = next.min_level ?? this.weapon.level_req;
    if (this.save.level < minLevel) missing.push(`level ${minLevel}`);
    for (const m of next.materials) {
      const have = this.save.materials[m.material_id] || 0;
      if (have < m.qty) missing.push(`${m.qty - have} more ${this.materials[m.material_id].name}`);
    }
    if (this.save.marks < next.currency_cost) missing.push(`${next.currency_cost - this.save.marks} more Marks`);
    return { next, missing };
  }

  upgradeWeapon() {
    const u = this.nextUpgrade();
    if (!u || u.missing.length) return false;
    for (const m of u.next.materials) {
      this.save.materials[m.material_id] -= m.qty;
      if (this.save.materials[m.material_id] <= 0) delete this.save.materials[m.material_id];
    }
    this.save.marks -= u.next.currency_cost;
    this.save.weapon_tier += 1;
    this.persist();
    this.emit("toast", `${this.weapon.name} upgraded to tier ${this.save.weapon_tier} (+${u.next.damage_bonus_pct}% damage)`, "accent");
    return true;
  }

  // ---------------------------------------------------------------- enemies
  spawnEnemy(def, level, x, z, opts = {}) {
    const B = this.P.stat_scaling.enemy_base;
    const maxHp = R.round(R.statAt(B.max_hp, level, this.growth) * def.stats.hp_mult);
    const e = {
      def, level, x, z, r: def.rank === "boss" ? 3.5 : 2, home: { x, z }, face: { x: 0, z: 1 },
      hp: maxHp, maxHp, alive: true, isBoss: def.rank === "boss",
      attack: R.statAt(B.attack, level, this.growth) * def.stats.attack_mult,
      defense: R.statAt(B.defense, level, this.growth) * def.stats.defense_mult,
      leash: opts.leash ?? def.stats.leash_range_studs, aggro: def.stats.aggro_range_studs,
      poise: R.newPoise(def.stats.poise), stunnedUntil: 0, busyUntil: 0, token: 0, hasToken: false,
      attackReady: {}, allowed: opts.allowed ?? null, speedMult: 1, invulnUntil: 0, engaged: false,
      tell: null, flashUntil: 0, burning: null, kv: null, deadAt: 0, decision: { kind: "idle" },
    };
    this.enemies.push(e);
    return e;
  }

  hitEnemy(e, hit) {
    const t = this.t;
    if (!e.alive || t < e.invulnUntil) return false;
    e.hp = Math.max(0, e.hp - hit.amount);
    e.engaged = true;
    e.flashUntil = t + 0.1;
    this.number(e.x, e.z, hit.amount, hit.isCrit ? "#ffe678" : hit.dot ? "#ff9650" : "#ffffff", hit.isCrit);
    if (hit.poiseDamage > 0 && R.poiseHit(e.poise, hit.poiseDamage, t, this.C.poise)) this.staggerEnemy(e, this.C.poise.stagger_s, false);
    if (hit.knockback > 0 && !e.isBoss) {
      const k = hit.knockback / 0.15;
      e.kv = { vx: hit.dir.x * k, vz: hit.dir.z * k, until: t + 0.15 };
    }
    for (const app of hit.statuses || []) {
      const st = this.statuses[app.status_id];
      if (st?.category === "damage_over_time" && Math.random() < app.chance) {
        e.burning = { until: t + (app.duration_s ?? st.duration_s), next: t + st.tick_interval_s, every: st.tick_interval_s, dmg: Math.max(1, R.round(hit.sourceAttack * st.tick_power)) };
      }
    }
    if (e.isBoss) this.bossDamaged(e);
    if (e.hp <= 0) this.enemyDied(e);
    return true;
  }

  staggerEnemy(e, seconds, forced) {
    if (forced && !R.poiseForce(e.poise, this.t, seconds, this.C.poise)) return false;
    e.stunnedUntil = this.t + seconds;
    e.token++;
    e.tell = null;
    e.busyUntil = 0;
    e.hasToken = false;
    this.text(e.x, e.z, "Staggered", "#ffc878");
    return true;
  }

  enemyDied(e) {
    e.alive = false;
    e.deadAt = this.t;
    e.tell = null;
    e.hasToken = false;
    if (this.lockTarget === e) this.lockTarget = null;
    this.awardXp(e.def.rewards.xp_base, e.level, e.def.id);
    this.save.marks = Math.min(1e12, this.save.marks + R.scaledReward(e.def.rewards.currency_base, e.level, this.growth));
    this.grantDrops(e.def.rewards.drops);
    this.fx.push({ type: "burst", t0: this.t, dur: 0.6, x: e.x, z: e.z, r: e.r, boss: e.isBoss });
    if (e.isBoss) this.bossDefeated(e);
  }

  attackers() { return this.enemies.filter((e) => e.alive && e.hasToken).length; }

  startAttack(e, atk) {
    const p = this.player, t = this.t, mode = this.mode();
    const windup = atk.timing.windup_s * mode.telegraph_time_mult; // speed-ups never shorten tells
    const recovery = atk.timing.recovery_s / e.speedMult;
    e.hasToken = true;
    e.attackReady[atk.id] = t + windup + atk.cooldown_s;
    e.busyUntil = t + windup + atk.timing.active_s + recovery;
    const token = ++e.token;
    e.face = unit(p.x - e.x, p.z - e.z);
    let cx = e.x, cz = e.z;
    if (R.areaCenterDistance(atk.area, atk.range_studs) > 0) {
      const off = { x: p.x - e.x, z: p.z - e.z };
      const l = Math.hypot(off.x, off.z);
      const k = l > atk.range_studs ? atk.range_studs / l : 1;
      cx = e.x + off.x * k; cz = e.z + off.z * k;
    }
    const unblockable = !atk.avoidable_by.includes("guard");
    e.tell = { atk, t0: t, dur: windup, cx, cz, fx: e.face.x, fz: e.face.z, unblockable };
    this.later(windup, () => {
      if (e.token !== token || !e.alive) return;
      e.tell = { ...e.tell, active: true, t0: this.t, dur: Math.max(atk.timing.active_s, 0.12) };
      const tr = atk.area.shape === "cone" ? p.r + e.r : p.r;
      if (!p.dead && R.hitsArea(atk.area, atk.range_studs, cx, cz, e.face.x, e.face.z, p.x, p.z, tr)) {
        this.hurtPlayer({
          attack: e.attack, power: atk.power, level: e.level, poiseDamage: atk.poise_damage, knockback: atk.knockback_studs,
          x: e.x, z: e.z, unblockable, statuses: atk.status_effects, onParried: () => this.staggerEnemy(e, this.C.poise.stagger_s, true),
        });
      }
      this.later(Math.max(atk.timing.active_s, 0.12), () => {
        if (e.token === token) { e.tell = null; e.hasToken = false; }
      });
    });
  }

  thinkEnemy(e) {
    const p = this.player, t = this.t;
    if (!e.alive || t < e.stunnedUntil) return;
    const fromHome = dist(e.x, e.z, e.home.x, e.home.z);
    let targetDist = null;
    if (!p.dead && !this.paused) {
      const d = dist(e.x, e.z, p.x, p.z);
      if (d <= e.aggro || (e.engaged && d <= e.aggro + e.leash)) targetDist = d;
    }
    const options = e.def.attacks
      .filter((a) => !e.allowed || e.allowed.includes(a.id))
      .map((a) => ({ id: a.id, range: a.range_studs + (a.area.shape === "cone" ? e.r : 0), readyAt: e.attackReady[a.id] || 0 }));
    const maxAttackers = this.mode().max_attackers_per_player;
    const hasToken = e.hasToken || this.attackers() < maxAttackers;
    e.decision = R.decide({ now: t, distanceToTarget: targetDist, distanceFromHome: fromHome, leashRange: e.leash, attacks: options, hasToken, busy: t < e.busyUntil });
    if (e.decision.kind === "attack") this.startAttack(e, e.def.attacks.find((a) => a.id === e.decision.attackId));
    if (e.decision.kind === "return" && fromHome < 6) {
      e.engaged = false;
      e.hp = e.isBoss ? Math.max(e.hp, R.resetHp(this.boss.def.boss.phases, this.boss.furthest, e.maxHp, true)) : e.maxHp;
    }
  }

  moveEnemy(e, dt) {
    const t = this.t, p = this.player;
    if (e.kv && t < e.kv.until) { this.move(e, e.kv.vx * dt, e.kv.vz * dt); return; }
    if (!e.alive || t < e.stunnedUntil || t < e.busyUntil) return;
    const speed = e.def.stats.move_speed_studs * e.speedMult * dt;
    let tx = null, tz = null;
    if (e.decision.kind === "chase") { tx = p.x; tz = p.z; }
    else if (e.decision.kind === "return") { tx = e.home.x; tz = e.home.z; }
    else if (e.decision.kind === "wait" && !p.dead) {
      e.face = unit(p.x - e.x, p.z - e.z); // circle at a distance while waiting for a turn to attack
      const side = { x: -e.face.z, z: e.face.x };
      this.move(e, side.x * speed * 0.4, side.z * speed * 0.4);
      return;
    }
    if (tx === null) return;
    const dir = unit(tx - e.x, tz - e.z);
    e.face = dir;
    this.move(e, dir.x * speed, dir.z * speed);
  }

  // ---------------------------------------------------------------- boss
  bossSpawn() {
    const b = this.boss, def = b.def, a = this.arena;
    b.phase = 0;
    b.furthest = 0;
    b.live = this.spawnEnemy(def, def.boss.suggested_level ?? 1, a.center[0], a.center[2], { leash: a.radius_studs + 15, allowed: def.boss.phases[0].attack_ids });
  }

  applyPhase(index, announce) {
    const b = this.boss, e = b.live, phase = b.def.boss.phases[index];
    b.phase = index;
    b.furthest = Math.max(b.furthest, index);
    e.allowed = phase.attack_ids;
    e.speedMult = phase.speed_mult;
    if (announce) {
      e.invulnUntil = this.t + phase.transition_invulnerable_s;
      e.busyUntil = this.t + phase.transition_invulnerable_s;
      e.token++;
      e.tell = null;
      e.hasToken = false;
      this.emit("toast", `${b.def.name}: ${phase.name}`, "boss");
      this.shake(0.6);
    }
  }

  bossDamaged(e) {
    const idx = R.phaseIndexFor(this.boss.def.boss.phases, e.hp / e.maxHp);
    if (idx > this.boss.phase && e.hp > 0) this.applyPhase(idx, true);
  }

  bossFailed() {
    const b = this.boss, def = b.def, sv = this.save;
    sv.boss_failures[def.id] = (sv.boss_failures[def.id] || 0) + 1;
    const e = b.live;
    e.hp = R.resetHp(def.boss.phases, b.furthest, e.maxHp, def.boss.checkpoint_each_phase);
    e.engaged = false;
    e.x = e.home.x; e.z = e.home.z;
    this.applyPhase(R.phaseIndexFor(def.boss.phases, e.hp / e.maxHp), false);
    const failures = sv.boss_failures[def.id];
    const offers = R.assistOffers(failures, this.data.difficulty.boss_assist.offer_after_failures);
    if (offers.length) {
      const tips = def.boss.assist_tips;
      this.emit("assist", { tip: tips[(failures - 1) % tips.length], offers, suggested: def.boss.suggested_level, buff: this.statuses[this.data.difficulty.boss_assist.support_buff_status_id] });
    }
  }

  acceptSupportBuff() {
    const buff = this.statuses[this.data.difficulty.boss_assist.support_buff_status_id];
    this.setEffect(buff.id, buff.duration_s, buff.stat_modifiers);
  }

  bossDefeated() {
    const def = this.boss.def, sv = this.save;
    if (!sv.bosses_defeated.includes(def.id)) sv.bosses_defeated.push(def.id);
    sv.boss_failures[def.id] = 0;
    this.boss.respawnAt = this.t + BOSS_RESPAWN_S;
    this.boss.live = null;
    this.emit("boss_defeated", def);
    this.persist();
  }

  // ---------------------------------------------------------------- effects helpers
  number(x, z, n, color, big = false) {
    if (this.setting("damage_numbers") === false) return;
    this.fx.push({ type: "number", t0: this.t, dur: 0.8, x: x + (Math.random() - 0.5) * 2, z, text: String(n), color, big });
  }
  text(x, z, text, color) { this.fx.push({ type: "number", t0: this.t, dur: 1, x, z, text, color, big: true }); }
  shake(amount) { this.camera.shake = Math.min(1.5, this.camera.shake + amount * (this.setting("camera_shake") ?? 0.6)); }

  // ---------------------------------------------------------------- per-frame update
  update(dt, input) {
    if (!this.running || this.paused) return;
    this.t += dt;
    const t = this.t, p = this.player, sv = this.save;
    sv.play_seconds += dt;

    // timers
    if (this.timers.length) {
      const due = this.timers.filter((x) => x.at <= t);
      this.timers = this.timers.filter((x) => x.at > t);
      for (const x of due) x.fn();
    }

    // player
    if (p.dead) {
      if (t >= p.respawnAt) this.respawn();
    } else {
      const mv = input.moveVector();
      this.moveDir = this.worldMove(mv);
      const wm = this.moveDir;
      const stunned = t < p.stunnedUntil;
      if (p.queued && t >= p.busyUntil) { const q = p.queued; p.queued = null; this.melee(q); }
      p.sprinting = input.isDown("dodge_sprint") && t - p.dodgeAt > 0.3 && Math.hypot(mv.x, mv.y) > 0.1;
      const slow = Object.entries(p.effects).reduce((m, [id]) => {
        const cc = this.statuses[id]?.cc;
        return cc?.type === "slow" ? m * (1 - (cc.slow_fraction || 0)) : m;
      }, 1);
      const M = this.C.movement;
      const speed = (p.guarding ? M.guard_walk_speed : p.sprinting ? M.sprint_speed : M.walk_speed) * slow;
      if (p.dash && t < p.dash.until) this.move(p, p.dash.vx * dt, p.dash.vz * dt);
      else if (p.knock && t < p.knock.until) this.move(p, p.knock.vx * dt, p.knock.vz * dt);
      else if (!stunned && t >= p.busyUntil - 0.05) this.move(p, wm.x * speed * dt, wm.z * speed * dt);
      else if (!stunned) this.move(p, wm.x * speed * 0.25 * dt, wm.z * speed * 0.25 * dt);

      // facing
      if (this.lockTarget?.alive) p.face = unit(this.lockTarget.x - p.x, this.lockTarget.z - p.z);
      else if (Math.hypot(wm.x, wm.z) > 0.2 && t >= p.busyUntil) {
        const want = unit(wm.x, wm.z); // turn smoothly toward the movement direction
        const k = Math.min(1, dt * 14);
        p.face = unit(p.face.x + (want.x - p.face.x) * k, p.face.z + (want.z - p.face.z) * k);
      }
      if (this.lockTarget && (!this.lockTarget.alive || dist(p.x, p.z, this.lockTarget.x, this.lockTarget.z) > this.C.lock_on.break_range_studs)) this.lockTarget = null;

      // upkeep
      const max = this.P.stat_scaling.spirit_max;
      if (p.spirit < max) this.gainSpirit(this.C.spirit.regen_per_s * dt);
      if (!p.guarding) p.guardMeter = Math.min(this.C.guard.guard_meter_max, p.guardMeter + this.C.guard.guard_meter_regen_per_s * dt);
      for (const [id, eff] of Object.entries(p.effects)) {
        if (t >= eff.until) delete p.effects[id];
        else if (eff.tickDamage > 0 && t >= eff.nextTick) { eff.nextTick += 1; this.applyHurt(Math.max(1, R.round(eff.tickDamage * this.mode().enemy_damage_mult))); }
      }
      if (!p.dead && p.hp < p.maxHp && t - p.lastHurtAt >= this.C.recovery.out_of_combat_delay_s) {
        p.hp = Math.min(p.maxHp, p.hp + p.maxHp * this.C.recovery.regen_fraction_per_s * dt);
      }
      // hub: heal and save
      this.atHub = dist(p.x, p.z, this.hub.position[0], this.hub.position[2]) <= this.hub.radius_studs;
      if (this.atHub) {
        p.hp = Math.min(p.maxHp, p.hp + p.maxHp * HUB_HEAL_PER_S * dt);
        if (!this.wasAtHub) this.persist();
      }
      this.wasAtHub = this.atHub;
      // boss arena checkpoint
      const da = dist(p.x, p.z, this.arena.center[0], this.arena.center[2]);
      if (da <= this.arena.radius_studs) this.checkpoint = { x: this.arena.checkpoint_position[0], z: this.arena.checkpoint_position[2] };
      else if (da > this.arena.radius_studs + 60) this.checkpoint = null;
      this.nearBoss = da <= this.arena.radius_studs + 40;
      // secrets
      for (const s of this.map.secrets) {
        if (sv.secrets.includes(s.id)) continue;
        const [sx, , sz] = s.position;
        const solid = this.solids.find((r) => this.inRect(r, sx, sz));
        const reach = solid ? this.inRect(solid, p.x, p.z, p.r + 3) && dist(p.x, p.z, sx, sz) < 45 : dist(p.x, p.z, sx, sz) <= SECRET_REACH;
        if (reach) {
          sv.secrets.push(s.id);
          this.emit("toast", `Secret found: ${s.hint}`, "accent");
          if (s.reward?.xp_base) this.addXp(R.scaledReward(s.reward.xp_base, sv.level, this.growth));
          for (const it of s.reward?.items || []) {
            const mat = this.materials[it.item_id];
            if (mat) { sv.materials[mat.id] = Math.min(mat.max_stack, (sv.materials[mat.id] || 0) + it.qty); this.emit("toast", `+${it.qty} ${mat.name}`, "good"); }
          }
          this.persist();
        }
      }
    }

    // spawns
    for (const zone of this.zones) {
      for (const slot of zone.slots) {
        if (slot.enemy && slot.enemy.alive) continue;
        if (slot.enemy && !slot.enemy.alive) { slot.nextSpawn = t + zone.def.respawn_s; slot.enemy = null; }
        if (!slot.enemy && t >= slot.nextSpawn) {
          const z = zone.def;
          const def = this.enemyDefs[z.enemy_ids[Math.floor(Math.random() * z.enemy_ids.length)]];
          for (let tries = 0; tries < 10; tries++) {
            const a = Math.random() * Math.PI * 2, d = Math.random() * z.radius_studs * 0.8;
            const x = z.center[0] + Math.cos(a) * d, zz = z.center[2] + Math.sin(a) * d;
            if (!this.blocked(x, zz, 2) && dist(x, zz, p.x, p.z) > 18) {
              const level = z.level_range.min + Math.floor(Math.random() * (z.level_range.max - z.level_range.min + 1));
              slot.enemy = this.spawnEnemy(def, level, x, zz);
              break;
            }
          }
          if (!slot.enemy) slot.nextSpawn = t + 2;
        }
      }
    }
    if (!this.boss.live && t >= this.boss.respawnAt) this.bossSpawn();

    // enemies
    this.aiClock += dt;
    if (this.aiClock >= TICK_AI) {
      this.aiClock = 0;
      for (const e of this.enemies) this.thinkEnemy(e);
    }
    for (const e of this.enemies) {
      this.moveEnemy(e, dt);
      if (e.alive && e.burning) {
        if (t >= e.burning.until) e.burning = null;
        else if (t >= e.burning.next) { e.burning.next += e.burning.every; this.hitEnemy(e, { amount: e.burning.dmg, poiseDamage: 0, knockback: 0, dir: { x: 0, z: 0 }, dot: true }); }
      }
    }
    this.enemies = this.enemies.filter((e) => e.alive || t - e.deadAt < 0.6);

    // effects, camera, autosave
    this.fx = this.fx.filter((f) => t - f.t0 < f.dur);
    if (p.swing && t - p.swing.start > p.swing.windup + p.swing.active + 0.1) p.swing = null;
    this.camera.x += (p.x - this.camera.x) * Math.min(1, dt * 8);
    this.camera.z += (p.z - this.camera.z) * Math.min(1, dt * 8);
    this.camera.shake *= Math.exp(-dt * 10);
    this.saveClock += dt;
    if (this.saveClock >= AUTOSAVE_S) { this.saveClock = 0; this.persist(); }
  }
}
