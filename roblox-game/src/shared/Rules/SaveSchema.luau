--!strict
-- The player save format: defaults, version migrations, validation and repair.
-- Pure: no Roblox APIs, so every rule here is tested in Lune.
--
-- Safety rules:
--   * A save from a NEWER game version is refused, never downgraded (that would lose data).
--   * Invalid values are repaired one field at a time; everything valid is kept. Each repaired
--     value is noted in `quarantine` (capped) instead of silently vanishing.
--   * Missing fields (for example after an update adds a field) are filled from defaults.
--   * The server validates a snapshot before every save and skips the save if it fails, so a
--     broken in-memory state can never overwrite a good save.

local Progression = require(script.Parent.Progression)

local SaveSchema = {}

SaveSchema.VERSION = 1
SaveSchema.MAX_QUARANTINE = 20
local MAX_SAFE = 2 ^ 53

export type WeaponInstance = { uid: string, id: string, tier: number }

export type SaveData = {
	schema_version: number,
	archetype_id: string,
	level: number,
	xp: number,
	total_xp: number,
	rewards_granted_through: number,
	skill_points: number,
	skills: { string },
	appearance: { [string]: any },
	equipment: { weapon_uid: string },
	inventory: { materials: { [string]: number }, weapons: { WeaponInstance } },
	currency: { [string]: number },
	quests: { active: { string }, completed: { string } },
	regions: { discovered: { string }, fast_travel: { string } },
	settings: { [string]: any },
	milestones: { number },
	bosses_defeated: { string },
	boss_failures: { [string]: number },
	flags: { starter_kit_given: boolean },
	stats: { deaths: number, play_seconds: number },
	quarantine: { { field: string, reason: string, summary: string } },
}

export type LoadContext = { xpToNext: { number }, cap: number, appearance: { [string]: any }? }

export type LoadReport = {
	isNew: boolean,
	migratedFrom: number?,
	filled: { string }, -- fields that were missing and got defaults
	repaired: { string }, -- fields that were invalid and got replaced
	refused: string?, -- set when the save must not be used at all
}

-- ---------------------------------------------------------------- small checks
local function isInt(min: number, max: number): (any) -> boolean
	return function(v: any): boolean
		return type(v) == "number" and v == v and v == math.floor(v) and v >= min and v <= max
	end
end

local function isFinite(min: number, max: number): (any) -> boolean
	return function(v: any): boolean
		return type(v) == "number" and v == v and v >= min and v <= max
	end
end

local function isString(maxLen: number, pattern: string?): (any) -> boolean
	return function(v: any): boolean
		return type(v) == "string" and #v <= maxLen and (pattern == nil or string.match(v, pattern) ~= nil)
	end
end

local function isBool(v: any): boolean
	return type(v) == "boolean"
end

local function isSettingValue(v: any): boolean
	return type(v) == "boolean"
		or (type(v) == "number" and v == v and math.abs(v) < MAX_SAFE)
		or (type(v) == "string" and #v <= 32)
end

local ID = "^[a-z][a-z0-9_]*$"
local isLocalId = isString(48, ID)
local isCosmeticId = isString(48, "^cos_[a-z0-9_]+$")
local isWeaponInstance = function(v: any): boolean
	return type(v) == "table"
		and isString(64)(v.uid)
		and v.uid ~= ""
		and isString(48, "^wpn_[a-z0-9_]+$")(v.id)
		and isInt(0, 5)(v.tier)
end

local function isArray(t: { [any]: any }): boolean
	local n = 0
	for k in t do
		if type(k) ~= "number" then
			return false
		end
		n += 1
	end
	for i = 1, n do
		if t[i] == nil then
			return false
		end
	end
	return true
end

local function summary(v: any): string
	local text = if type(v) == "table" then "table" else tostring(v)
	return `{type(v)}: {string.sub(text, 1, 80)}`
end

local function deepCopy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, child in v :: any do
		out[k] = deepCopy(child)
	end
	return out :: any
end
SaveSchema.deepCopy = deepCopy

-- ---------------------------------------------------------------- the save shape
type Node = {
	kind: "value" | "array" | "map" | "record",
	check: ((any) -> boolean)?, -- value
	item: ((any) -> boolean)?, -- array items
	key: ((any) -> boolean)?, -- map keys
	value: ((any) -> boolean)?, -- map values
	max: number?, -- array/map size limit
	fields: { [string]: Node }?, -- record
}

local function value(check: (any) -> boolean): Node
	return { kind = "value", check = check }
end
local function array(item: (any) -> boolean, max: number): Node
	return { kind = "array", item = item, max = max }
end
local function map(key: (any) -> boolean, val: (any) -> boolean, max: number): Node
	return { kind = "map", key = key, value = val, max = max }
end
local function record(fields: { [string]: Node }): Node
	return { kind = "record", fields = fields }
end

local SHAPE: Node = record({
	schema_version = value(isInt(1, 1000)),
	archetype_id = value(isString(48, "^arc_[a-z0-9_]+$")),
	level = value(isInt(1, 3000)),
	xp = value(isInt(0, MAX_SAFE)),
	total_xp = value(isInt(0, MAX_SAFE)),
	rewards_granted_through = value(isInt(1, 3000)),
	skill_points = value(isInt(0, 100000)),
	skills = array(isLocalId, 500),
	appearance = record({
		body_type = value(isCosmeticId),
		face = value(isCosmeticId),
		skin_tone = value(isCosmeticId),
		hair_style = value(isCosmeticId),
		hair_color = value(isCosmeticId),
		eye_color = value(isCosmeticId),
		outfit = value(isCosmeticId),
		aura_color = value(isCosmeticId),
		accessories = array(isCosmeticId, 10),
		name = value(isString(30)),
	}),
	equipment = record({ weapon_uid = value(isString(64)) }),
	inventory = record({
		materials = map(isString(48, "^mat_[a-z0-9_]+$"), isInt(1, 1000000), 500),
		weapons = array(isWeaponInstance, 200),
	}),
	currency = map(isString(48, "^cur_[a-z0-9_]+$"), isInt(0, 1e12), 20),
	quests = record({ active = array(isString(48, "^qst_"), 200), completed = array(isString(48, "^qst_"), 5000) }),
	regions = record({
		discovered = array(isString(48, "^reg_"), 50),
		fast_travel = array(isString(48, "^ftp_"), 500),
	}),
	settings = map(isLocalId, isSettingValue, 100),
	milestones = array(isInt(1, 3000), 100),
	bosses_defeated = array(isString(48, "^enm_"), 500),
	boss_failures = map(isString(48, "^enm_"), isInt(0, 1000000), 500),
	flags = record({ starter_kit_given = value(isBool) }),
	stats = record({ deaths = value(isInt(0, MAX_SAFE)), play_seconds = value(isFinite(0, MAX_SAFE)) }),
	quarantine = array(function(v: any): boolean
		return type(v) == "table" and isString(200)(v.field) and isString(200)(v.reason) and isString(200)(v.summary)
	end, SaveSchema.MAX_QUARANTINE),
})

local DEFAULT_APPEARANCE = {
	body_type = "cos_body_build_a",
	face = "cos_face_calm",
	skin_tone = "cos_skin_tone_3",
	hair_style = "cos_hair_short_swept",
	hair_color = "cos_hair_color_black",
	eye_color = "cos_eye_color_amber",
	outfit = "cos_outfit_courier_jacket",
	aura_color = "cos_aura_lantern_orange",
	accessories = {},
	name = "",
}

function SaveSchema.default(appearance: { [string]: any }?): SaveData
	return {
		schema_version = SaveSchema.VERSION,
		archetype_id = "arc_lanternblade",
		level = 1,
		xp = 0,
		total_xp = 0,
		rewards_granted_through = 1,
		skill_points = 0,
		skills = {},
		appearance = deepCopy(appearance or DEFAULT_APPEARANCE),
		equipment = { weapon_uid = "" },
		inventory = { materials = {}, weapons = {} },
		currency = {},
		quests = { active = {}, completed = {} },
		regions = { discovered = { "reg_akeboshi_city" }, fast_travel = {} },
		settings = {},
		milestones = {},
		bosses_defeated = {},
		boss_failures = {},
		flags = { starter_kit_given = false },
		stats = { deaths = 0, play_seconds = 0 },
		quarantine = {},
	}
end

-- ---------------------------------------------------------------- repair
type RepairLog = {
	filled: { string },
	repaired: { string },
	quarantine: { { field: string, reason: string, summary: string } },
}

local function note(log: RepairLog, path: string, bad: any, reason: string)
	table.insert(log.repaired, path)
	table.insert(log.quarantine, { field = string.sub(path, 1, 200), reason = reason, summary = summary(bad) })
end

local function repair(node: Node, v: any, default: any, path: string, log: RepairLog): any
	if v == nil then
		table.insert(log.filled, path)
		return deepCopy(default)
	end
	if node.kind == "value" then
		if (node.check :: (any) -> boolean)(v) then
			return v
		end
		note(log, path, v, "invalid value")
		return deepCopy(default)
	end
	if type(v) ~= "table" then
		note(log, path, v, "expected a table")
		return deepCopy(default)
	end
	if node.kind == "array" then
		if not isArray(v) then
			note(log, path, v, "expected a list")
			return deepCopy(default)
		end
		local out = {}
		for i, item in v do
			if not (node.item :: (any) -> boolean)(item) then
				note(log, `{path}[{i}]`, item, "invalid list item")
			elseif #out >= (node.max :: number) then
				note(log, `{path}[{i}]`, item, "list too long")
			else
				table.insert(out, item)
			end
		end
		return out
	elseif node.kind == "map" then
		local out = {}
		local count = 0
		for k, item in v do
			if not (node.key :: (any) -> boolean)(k) or not (node.value :: (any) -> boolean)(item) then
				note(log, `{path}.{tostring(k)}`, item, "invalid entry")
			elseif count >= (node.max :: number) then
				note(log, `{path}.{tostring(k)}`, item, "too many entries")
			else
				out[k] = item
				count += 1
			end
		end
		return out
	end
	-- record
	local out = {}
	local fields = node.fields :: { [string]: Node }
	for name, child in fields do
		out[name] = repair(
			child,
			v[name],
			if default then default[name] else nil,
			if path == "" then name else `{path}.{name}`,
			log
		)
	end
	for name in v do
		if fields[name] == nil then
			note(log, if path == "" then tostring(name) else `{path}.{tostring(name)}`, v[name], "unknown field")
		end
	end
	return out
end

-- Fixes that need several fields at once.
local function crossFieldFixes(data: SaveData, ctx: LoadContext, log: RepairLog)
	local fixed =
		Progression.sanitize({ level = data.level, xp = data.xp, total_xp = data.total_xp }, ctx.xpToNext, ctx.cap)
	if fixed.level ~= data.level or fixed.xp ~= data.xp then
		note(log, "level/xp", `{data.level}/{data.xp}`, "progress out of range")
	end
	data.level, data.xp, data.total_xp = fixed.level, fixed.xp, fixed.total_xp
	-- rewards_granted_through is never lowered: lowering it could grant the same rewards twice.
	local uid = data.equipment.weapon_uid
	if uid ~= "" then
		local found = false
		for _, weapon in data.inventory.weapons do
			if weapon.uid == uid then
				found = true
			end
		end
		if not found then
			note(log, "equipment.weapon_uid", uid, "equipped weapon not in inventory")
			data.equipment.weapon_uid = ""
		end
	end
end

-- Version migrations: MIGRATIONS[n] turns a version-n save into version n+1.
local MIGRATIONS: { [number]: (any) -> any } = {}

-- ---------------------------------------------------------------- public API
function SaveSchema.load(raw: any, ctx: LoadContext): (SaveData?, LoadReport)
	local report: LoadReport = { isNew = false, filled = {}, repaired = {} }
	local defaults = SaveSchema.default(ctx.appearance)
	if raw == nil or (type(raw) == "table" and next(raw) == nil) then
		report.isNew = true
		return defaults, report
	end
	local log: RepairLog = { filled = {}, repaired = {}, quarantine = {} }
	local source: any = raw
	if type(raw) ~= "table" then
		note(log, "(whole save)", raw, "save was not a table")
		source = {}
	end
	local version = source.schema_version
	if version == nil then
		version = 1
	end
	if type(version) ~= "number" or version ~= math.floor(version) or version < 1 then
		note(log, "schema_version", version, "invalid version")
		version = 1
	end
	if version > SaveSchema.VERSION then
		report.refused = "newer_version"
		return nil, report
	end
	if version < SaveSchema.VERSION then
		report.migratedFrom = version
		source = deepCopy(source)
		for v = version, SaveSchema.VERSION - 1 do
			local step = MIGRATIONS[v]
			if step == nil then
				report.refused = `no migration from version {v}`
				return nil, report
			end
			source = step(source)
		end
	end
	local previousQuarantine = source.quarantine
	local data: SaveData = repair(SHAPE, source, defaults, "", log)
	data.schema_version = SaveSchema.VERSION
	crossFieldFixes(data, ctx, log)
	-- keep the newest quarantine notes, capped
	local merged = if type(previousQuarantine) == "table" then data.quarantine else {}
	for _, entry in log.quarantine do
		table.insert(merged, entry)
	end
	while #merged > SaveSchema.MAX_QUARANTINE do
		table.remove(merged, 1)
	end
	data.quarantine = merged
	report.filled = log.filled
	report.repaired = log.repaired
	return data, report
end

-- True only if the data needs no repair at all. The server calls this before every save.
function SaveSchema.validate(data: any, ctx: LoadContext): (boolean, { string })
	if type(data) ~= "table" or data.schema_version ~= SaveSchema.VERSION then
		return false, { "schema_version" }
	end
	local log: RepairLog = { filled = {}, repaired = {}, quarantine = {} }
	local copy = repair(SHAPE, data, SaveSchema.default(ctx.appearance), "", log)
	crossFieldFixes(copy, ctx, log)
	local problems = {}
	for _, path in log.filled do
		table.insert(problems, "missing " .. path)
	end
	for _, path in log.repaired do
		table.insert(problems, "invalid " .. path)
	end
	return #problems == 0, problems
end

-- An independent copy for saving, so later changes to the live state can't alter it mid-save.
function SaveSchema.snapshot(data: SaveData): SaveData
	return deepCopy(data)
end

return SaveSchema
