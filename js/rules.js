// Pure game rules: no drawing, no input, no browser APIs. Ported from the project's tested
// Luau rules so every edition does the same maths. tests.html checks these in the browser.

// ---------------------------------------------------------------- scaling
export const rewardScale = (level, growth) => 1 + (level - 1) * growth;
export const statAt = (base, level, growth) => base * rewardScale(level, growth);
export const round = (v) => Math.floor(v + 0.5); // half up, same in every engine
export const scaledReward = (base, level, growth) => round(base * rewardScale(level, growth));
export const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

// ---------------------------------------------------------------- damage
export function mitigation(defense, attackerLevel, rules, growth) {
  if (defense <= 0) return 1;
  const k = rules.defense_constant * rewardScale(attackerLevel, growth);
  return 1 - defense / (defense + k);
}

export function levelGap(attackerLevel, targetLevel, rules) {
  return clamp(1 + (attackerLevel - targetLevel) * rules.level_gap_per_level, rules.level_gap_min, rules.level_gap_max);
}

// damage = attack x power x weapon x mitigation x levelGap x difficulty x resistance x (1 - guard) x crit x bonus
export function damage(i, rules) {
  const weapon = ((i.weaponDamage ?? 100) / 100) * (1 + (i.weaponBonusPct ?? 0) / 100);
  const raw = i.attack * i.power * weapon
    * mitigation(i.defense, i.attackerLevel, rules, i.growth)
    * levelGap(i.attackerLevel, i.targetLevel, rules)
    * (i.difficultyMult ?? 1) * (i.resistance ?? 1)
    * (1 - clamp(i.guardReduction ?? 0, 0, 1))
    * (i.isCrit ? rules.crit_multiplier : 1)
    * (i.bonusMult ?? 1);
  if (!Number.isFinite(raw)) return rules.min_damage;
  return Math.max(rules.min_damage, round(raw));
}

export function percentMult(modifiers, stat) {
  let total = 0;
  for (const m of modifiers) if (m.stat === stat && m.mode === "add_percent") total += m.value;
  return Math.max(0, 1 + total / 100);
}

// ---------------------------------------------------------------- XP and levels
export const effectiveCap = (contentCap, xpToNext) => Math.min(contentCap, xpToNext.length + 1);

// xpToNext[level - 1] = XP to go from `level` to `level + 1`.
export function addXp(progress, amount, xpToNext, cap) {
  let { level, xp, total_xp: total } = progress;
  const start = level;
  if (!Number.isFinite(amount) || amount <= 0 || level >= cap) {
    return { progress: { level, xp: level >= cap ? 0 : xp, total_xp: total }, levelsGained: 0, added: 0 };
  }
  let remaining = Math.floor(amount);
  let added = 0;
  while (remaining > 0 && level < cap) {
    const need = xpToNext[level - 1] - xp;
    if (remaining >= need) { remaining -= need; added += need; level += 1; xp = 0; }
    else { xp += remaining; added += remaining; remaining = 0; }
  }
  return { progress: { level, xp: level >= cap ? 0 : xp, total_xp: total + added }, levelsGained: level - start, added };
}

// Levels whose rewards are still owed. Each level's rewards are granted exactly once.
export function pendingRewardLevels(grantedThrough, level) {
  const out = [];
  for (let l = grantedThrough + 1; l <= level; l++) out.push(l);
  return out;
}

export function skillPointsAt(level, schedule) {
  for (const r of schedule) if (level >= r.from && level <= r.to) return (level - r.from) % r.every === 0 ? 1 : 0;
  return 0;
}

export function milestoneAt(level, milestones) {
  if (level % milestones.interval !== 0) return null;
  const major = milestones.major.find((m) => m.level === level);
  return major ? { reward: major.reward, name: major.name } : { reward: milestones.standard_reward, name: `Level ${level} milestone` };
}

// Anti-grind: the same enemy type over and over slowly gives less XP.
export function grindMultiplier(state, enemyId, now, rules) {
  const kept = (state[enemyId] || []).filter((t) => now - t < rules.window_s);
  const extra = kept.length - rules.full_reward_kills + 1;
  kept.push(now);
  state[enemyId] = kept;
  return extra <= 0 ? 1 : Math.max(rules.floor_multiplier, rules.decay_per_kill ** extra);
}

// ---------------------------------------------------------------- stagger and crowd control
export const newPoise = (max) => ({ current: max, max, lastHitAt: -Infinity, immuneUntil: -Infinity });

export function poiseHit(s, dmg, now, rules) {
  if (s.max <= 0) return false;
  if (now - s.lastHitAt >= rules.poise_regen_delay_s) s.current = s.max;
  s.lastHitAt = now;
  if (now < s.immuneUntil) return false;
  s.current -= Math.max(0, dmg);
  if (s.current <= 0) { s.current = s.max; s.immuneUntil = now + rules.stagger_s + rules.stagger_immunity_s; return true; }
  return false;
}

export function poiseForce(s, now, seconds, rules) {
  if (now < s.immuneUntil) return false;
  s.current = s.max; s.lastHitAt = now; s.immuneUntil = now + seconds + rules.stagger_immunity_s;
  return true;
}

export const newCc = () => ({ count: 0, windowStart: -Infinity, immuneUntil: -Infinity });

export function ccDuration(s, base, now, rules) {
  if (now < s.immuneUntil) return 0;
  if (now - s.windowStart > rules.diminishing_window_s) { s.count = 0; s.windowStart = now; }
  s.count += 1;
  const mult = rules.diminishing_multipliers[s.count - 1];
  if (mult === undefined) { s.immuneUntil = now + rules.immunity_s; s.count = 0; return 0; }
  const d = Math.min(base * mult, rules.max_hard_cc_s);
  if (s.count >= rules.diminishing_multipliers.length) { s.immuneUntil = now + d + rules.immunity_s; s.count = 0; }
  return d;
}

// ---------------------------------------------------------------- hit areas (flat x/z plane)
function norm(x, z) { const l = Math.hypot(x, z); return l < 1e-6 ? [0, 1] : [x / l, z / l]; }

export function inCircle(cx, cz, tx, tz, r, tr) { return Math.hypot(tx - cx, tz - cz) <= r + tr; }
export function inRing(cx, cz, tx, tz, r, w, tr) { return Math.abs(Math.hypot(tx - cx, tz - cz) - r) <= w / 2 + tr; }
export function inCone(ox, oz, fx, fz, tx, tz, r, angleDeg, tr) {
  const dx = tx - ox, dz = tz - oz, d = Math.hypot(dx, dz);
  if (d > r + tr) return false;
  if (d <= tr) return true;
  const [nx, nz] = norm(fx, fz);
  const half = (angleDeg * Math.PI) / 360 + Math.atan(tr / d);
  return (dx * nx + dz * nz) / d >= Math.cos(Math.min(half, Math.PI));
}
export function inLine(ox, oz, fx, fz, tx, tz, len, w, tr) {
  const [nx, nz] = norm(fx, fz);
  const dx = tx - ox, dz = tz - oz;
  const along = dx * nx + dz * nz, side = Math.abs(dx * -nz + dz * nx);
  return along >= -tr && along <= len + tr && side <= w / 2 + tr;
}
export function hitsArea(area, range, ox, oz, fx, fz, tx, tz, tr) {
  switch (area.shape) {
    case "circle": return inCircle(ox, oz, tx, tz, area.radius_studs ?? range, tr);
    case "cone": return inCone(ox, oz, fx, fz, tx, tz, area.radius_studs ?? range, area.angle_deg ?? 90, tr);
    case "line": case "box": return inLine(ox, oz, fx, fz, tx, tz, area.length_studs ?? range, area.width_studs ?? 4, tr);
    case "ring": return inRing(ox, oz, tx, tz, area.radius_studs ?? range, area.width_studs ?? 4, tr);
    default: return inCone(ox, oz, fx, fz, tx, tz, range, 60, tr);
  }
}
// Ranged circle/ring attacks are centred on the target point, melee ones on the attacker.
export const areaCenterDistance = (area, range) =>
  (area.shape === "circle" || area.shape === "ring") && range > (area.radius_studs ?? 0) ? range : 0;

// ---------------------------------------------------------------- enemy decisions
export function pickAttack(options, distance, now) {
  let best = null;
  for (const o of options) if (now >= o.readyAt && distance <= o.range && (!best || o.range < best.range)) best = o;
  return best ? best.id : null;
}

export function decide(i) {
  if (i.busy) return { kind: "wait" };
  if (i.distanceFromHome > i.leashRange) return { kind: "return" };
  if (i.distanceToTarget == null) return i.distanceFromHome > 4 ? { kind: "return" } : { kind: "idle" };
  const id = pickAttack(i.attacks, i.distanceToTarget, i.now);
  if (id) return i.hasToken ? { kind: "attack", attackId: id } : { kind: "wait" };
  return { kind: "chase" };
}

// ---------------------------------------------------------------- boss phases and assists
export function phaseIndexFor(phases, hpFraction) {
  let index = 0;
  phases.forEach((p, i) => { if (hpFraction <= p.starts_at_hp) index = i; });
  return index;
}
export function resetHp(phases, furthest, maxHp, checkpointEachPhase) {
  if (!checkpointEachPhase) return maxHp;
  return Math.max(1, Math.floor(maxHp * phases[clamp(furthest, 0, phases.length - 1)].starts_at_hp));
}
export function assistOffers(failures, t) {
  const out = [];
  if (failures >= t.tip) out.push("tip");
  if (failures >= t.suggested_level) out.push("suggested_level");
  if (failures >= t.support_buff) out.push("support_buff");
  return out;
}

// ---------------------------------------------------------------- settings
export const forPlatform = (defs, platform) => defs.filter((d) => d.platforms.includes(platform));

export function coerceSetting(def, raw) {
  if (def.kind === "toggle") return typeof raw === "boolean" ? [true, raw] : [false];
  if (def.kind === "slider") {
    if (typeof raw !== "number" || !Number.isFinite(raw)) return [false];
    const snapped = def.min + Math.floor((clamp(raw, def.min, def.max) - def.min) / def.step + 0.5) * def.step;
    return [true, clamp(Math.round(snapped * 1000) / 1000, def.min, def.max)];
  }
  if (def.kind === "choice") return def.options.some((o) => o.value === raw) ? [true, raw] : [false];
  return [false];
}

export function sanitizeSettings(saved, defs, platform) {
  const clean = {};
  for (const def of forPlatform(defs, platform)) {
    const raw = saved ? saved[def.id] : undefined;
    const [ok, v] = raw === undefined ? [false] : coerceSetting(def, raw);
    clean[def.id] = ok ? v : def.default;
  }
  return clean;
}

// ---------------------------------------------------------------- input mapping
export const COMPOSITES = {
  "Composite:WASD": { W: [0, 1], S: [0, -1], A: [-1, 0], D: [1, 0] },
  "Composite:Arrows": { Up: [0, 1], Down: [0, -1], Left: [-1, 0], Right: [1, 0] },
  "Composite:DPad": { DPadUp: [0, 1], DPadDown: [0, -1], DPadLeft: [-1, 0], DPadRight: [1, 0] },
};
const DEVICES = ["keyboard_mouse", "gamepad", "touch"];

export function buildInputMap(data, platform, presetIds) {
  const bindings = {}, actions = {};
  for (const a of data.actions) {
    actions[a.id] = a;
    const per = {};
    for (const d of DEVICES) per[d] = [...(a.bindings[d] || [])];
    Object.assign(per, a.platform_overrides?.[platform] || {});
    bindings[a.id] = per;
  }
  for (const p of data.presets) {
    if (!presetIds.includes(p.id)) continue;
    for (const o of p.overrides) if (bindings[o.action_id]) bindings[o.action_id][o.device] = [...o.bindings];
  }
  const reserved = new Set(data.platform_reserved[platform] || []);
  const lookup = {}, directions = {};
  for (const ctx of ["gameplay", "menu"]) {
    lookup[ctx] = {}; directions[ctx] = {};
    for (const d of DEVICES) { lookup[ctx][d] = {}; directions[ctx][d] = {}; }
  }
  for (const [id, per] of Object.entries(bindings)) {
    const contexts = actions[id].context === "global" ? ["gameplay", "menu"] : [actions[id].context];
    for (const ctx of contexts) for (const [dev, inputs] of Object.entries(per)) for (const name of inputs) {
      const comp = COMPOSITES[name];
      if (comp) { for (const [k, dir] of Object.entries(comp)) if (!reserved.has(k)) directions[ctx][dev][k] = [id, dir[0], dir[1]]; }
      else if (!reserved.has(name)) lookup[ctx][dev][name] = id;
    }
  }
  return { lookup, directions, bindings, actions, reserved };
}

export const actionFor = (map, ctx, dev, name) => map.lookup[ctx]?.[dev]?.[name] ?? null;
export const directionFor = (map, ctx, dev, name) => map.directions[ctx]?.[dev]?.[name] ?? null;
export const hintsFor = (map, id, dev) => (map.bindings[id]?.[dev] || []).filter((n) => !map.reserved.has(n));
