// Saves progress in this browser (localStorage). Versioned and validated:
//  * a save is only written if it passes validation, so a broken state never replaces a good save;
//  * the previous good save is kept as a backup and used if the main one is corrupted;
//  * invalid fields are repaired one at a time instead of throwing the whole save away;
//  * a save from a newer version of the game is never overwritten.

export const SAVE_VERSION = 1;
const KEY = "sbe_web_save";
const BACKUP_KEY = "sbe_web_save_backup";

export function defaultSave() {
  return {
    version: SAVE_VERSION,
    level: 1,
    xp: 0,
    total_xp: 0,
    rewards_granted_through: 1,
    skill_points: 0,
    marks: 0,
    materials: {},
    weapon_tier: 0,
    settings: {},
    secrets: [],
    bosses_defeated: [],
    boss_failures: {},
    deaths: 0,
    play_seconds: 0,
  };
}

const isInt = (lo, hi) => (v) => Number.isInteger(v) && v >= lo && v <= hi;
const isNum = (lo, hi) => (v) => typeof v === "number" && Number.isFinite(v) && v >= lo && v <= hi;
const isStrList = (v) => Array.isArray(v) && v.length <= 500 && v.every((s) => typeof s === "string" && s.length <= 64);
const isMap = (valueCheck) => (v) =>
  v !== null && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length <= 500 &&
  Object.entries(v).every(([k, x]) => k.length <= 64 && valueCheck(x));
const isSetting = (v) => typeof v === "boolean" || (typeof v === "number" && Number.isFinite(v)) || (typeof v === "string" && v.length <= 32);

const FIELDS = {
  version: isInt(1, 1000),
  level: isInt(1, 3000),
  xp: isInt(0, 2 ** 53),
  total_xp: isInt(0, 2 ** 53),
  rewards_granted_through: isInt(1, 3000),
  skill_points: isInt(0, 100000),
  marks: isInt(0, 1e12),
  materials: isMap(isInt(1, 1e6)),
  weapon_tier: isInt(0, 5),
  settings: isMap(isSetting),
  secrets: isStrList,
  bosses_defeated: isStrList,
  boss_failures: isMap(isInt(0, 1e6)),
  deaths: isInt(0, 2 ** 53),
  play_seconds: isNum(0, 2 ** 53),
};

// Returns { data, repaired: [field...], refused } ; data is null when refused.
export function repair(raw, xpToNext, cap) {
  const fresh = defaultSave();
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return { data: fresh, repaired: ["(whole save)"] };
  if (Number.isInteger(raw.version) && raw.version > SAVE_VERSION) return { data: null, repaired: [], refused: "newer_version" };
  const data = {}, repaired = [];
  for (const [field, check] of Object.entries(FIELDS)) {
    if (raw[field] === undefined) data[field] = fresh[field];
    else if (check(raw[field])) data[field] = raw[field];
    else { data[field] = fresh[field]; repaired.push(field); }
  }
  data.version = SAVE_VERSION;
  // Progress must fit the XP table; rewards_granted_through is never lowered (no double rewards).
  data.level = Math.min(data.level, cap);
  if (data.level >= cap) data.xp = 0;
  else if (data.xp >= xpToNext[data.level - 1]) { data.xp = xpToNext[data.level - 1] - 1; repaired.push("xp"); }
  return { data, repaired };
}

export function isValid(data, xpToNext, cap) {
  if (!data || data.version !== SAVE_VERSION) return false;
  const { repaired } = repair(data, xpToNext, cap);
  return repaired.length === 0 && Object.keys(FIELDS).every((f) => data[f] !== undefined);
}

function read(key) {
  try {
    const text = localStorage.getItem(key);
    return text ? JSON.parse(text) : undefined;
  } catch {
    return null; // unreadable / corrupted JSON
  }
}

export function hasSave() {
  return read(KEY) !== undefined;
}

// Loads the main save, falling back to the backup if the main one is unusable.
export function load(xpToNext, cap) {
  const main = read(KEY);
  if (main !== undefined) {
    const result = repair(main, xpToNext, cap);
    if (result.data && !result.repaired.includes("(whole save)")) return { ...result, source: "main" };
    const backup = read(BACKUP_KEY);
    if (backup !== undefined) {
      const fromBackup = repair(backup, xpToNext, cap);
      if (fromBackup.data && !fromBackup.repaired.includes("(whole save)")) return { ...fromBackup, source: "backup" };
    }
    if (result.refused) return result;
  }
  return { data: defaultSave(), repaired: [], source: "new" };
}

// Writes only valid data; the previous main save becomes the backup.
export function store(data, xpToNext, cap) {
  if (!isValid(data, xpToNext, cap)) return false;
  try {
    const previous = localStorage.getItem(KEY);
    if (previous) localStorage.setItem(BACKUP_KEY, previous);
    localStorage.setItem(KEY, JSON.stringify(data));
    return true;
  } catch {
    return false; // storage full or blocked (private mode): the game keeps running
  }
}

export function wipe() {
  try {
    localStorage.removeItem(KEY);
    localStorage.removeItem(BACKUP_KEY);
  } catch { /* ignore */ }
}
